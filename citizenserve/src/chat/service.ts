import type { ChatEnvelopePayload, ChatMailboxItem, Env } from "../types";
import {
  HttpError,
  jsonResponse,
  readJson,
  requireSession,
} from "../shared/http";
import { nowMs } from "../shared/time";
import {
  assertChatCidNumber,
  assertChatEnvelopeId,
  assertDeviceId,
  assertEncodedChatEnvelope,
  assertPositiveMillis,
} from "./codec";
import {
  acknowledgeChatEnvelopes,
  readChatMailbox,
  requireChatRealtimeNamespace,
  storeChatEnvelope,
} from "./realtime";
import { sendChatWake } from "./push";
import { resourceLimit } from "../limits/catalog";
import { enforceEdgeRate } from "../security/request_guard";

type PushProvider = "apns" | "fcm";
type ApnsEnvironment = "sandbox" | "production";

interface RegisterPushEndpointRequest {
  device_id?: unknown;
  push_provider?: unknown;
  push_token?: unknown;
  apns_environment?: unknown;
  expires_at?: unknown;
}

/**
 * 幂等登记当前签名会话的操作系统推送端点。
 *
 * 推送端点不是聊天身份，也不保存 OpenMLS 公钥、KeyPackage 或消息信息。同一设备
 * Token 变化时直接覆盖；单 CID 设备数与有效期均由统一资源目录限制，禁止无界累积。
 */
export async function registerChatPushEndpoint(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<RegisterPushEndpointRequest>(request);
  const deviceId = assertDeviceId(body.device_id);
  const pushProvider = assertPushProvider(body.push_provider);
  const pushToken = assertPushToken(body.push_token);
  const apnsEnvironment = assertApnsEnvironment(
    pushProvider,
    body.apns_environment,
  );
  const expiresAt = assertPositiveMillis(
    body.expires_at,
    "invalid_push_endpoint_expires_at",
    "Chat 推送端点过期时间不合法",
  );
  const current = nowMs();
  if (expiresAt <= current) {
    throw new HttpError(400, "expired_push_endpoint", "Chat 推送端点已经过期");
  }
  const endpointLimit = resourceLimit("chat_push_endpoint");
  const maxExpiresAt = current + (endpointLimit.ttl_seconds ?? 1) * 1000;
  if (expiresAt > maxExpiresAt) {
    throw new HttpError(
      400,
      "push_endpoint_ttl_exceeded",
      "Chat 推送端点有效期超过上限",
    );
  }

  const active = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM chat_push_endpoints
      WHERE cid_number = ? AND device_id <> ? AND expires_at > ?`,
  )
    .bind(session.cid_number, deviceId, current)
    .first<{ n: number }>();
  if ((active?.n ?? 0) >= (endpointLimit.max_count ?? 1)) {
    throw new HttpError(
      409,
      "push_endpoint_limit_reached",
      "Chat 推送设备数已达上限",
    );
  }

  // 同一个系统 Token 只能属于一个 finalized 当前会话；重装、换绑和 Token 轮换时
  // 先清除旧归属，再按 (cid_number, device_id) 幂等覆盖，不产生历史名额堆积。
  await env.DB.prepare(
    `DELETE FROM chat_push_endpoints
      WHERE push_provider = ? AND push_token = ?
        AND (cid_number <> ? OR device_id <> ?)`,
  )
    .bind(pushProvider, pushToken, session.cid_number, deviceId)
    .run();
  await env.DB.prepare(
    `INSERT INTO chat_push_endpoints
      (cid_number, binding_revision, account_id, device_id, push_provider,
       push_token, apns_environment, expires_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(cid_number, device_id) DO UPDATE SET
        binding_revision = excluded.binding_revision,
        account_id = excluded.account_id,
        push_provider = excluded.push_provider,
        push_token = excluded.push_token,
        apns_environment = excluded.apns_environment,
        expires_at = excluded.expires_at,
        updated_at = excluded.updated_at`,
  )
    .bind(
      session.cid_number,
      session.binding_revision,
      session.account_id,
      deviceId,
      pushProvider,
      pushToken,
      apnsEnvironment,
      expiresAt,
      current,
    )
    .run();
  return jsonResponse({
    ok: true,
    cid_number: session.cid_number,
    device_id: deviceId,
    push_provider: pushProvider,
    apns_environment: apnsEnvironment,
    expires_at: expiresAt,
  });
}

/** 定时删除过期推送端点，避免无效 Token 持续占用 D1 存储与查询行。 */
export async function cleanupExpiredChatPushEndpoints(
  env: Env,
  current = nowMs(),
): Promise<void> {
  await env.DB.prepare(
    `DELETE FROM chat_push_endpoints WHERE expires_at <= ?`,
  )
    .bind(current)
    .run();
}

/** 打开当前合法 CID 的 WSS 信令连接；推送端点缺失不得阻断前台直连。 */
export async function openChatSignal(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.headers.get("upgrade")?.toLowerCase() !== "websocket") {
    throw new HttpError(426, "websocket_required", "请使用 WebSocket 连接");
  }
  const session = await requireSession(request, env);
  const deviceId = assertDeviceId(request.headers.get("x-chat-device"));
  const internal = new Request("https://chat.internal/connect", request);
  internal.headers.set("x-chat-cid-number", session.cid_number);
  internal.headers.set(
    "x-chat-binding-revision",
    String(session.binding_revision),
  );
  internal.headers.set("x-chat-account-id", session.account_id);
  internal.headers.set("x-chat-device", deviceId);
  return requireChatRealtimeNamespace(env)
    .getByName(session.cid_number)
    .fetch(internal);
}

const TURN_CREDENTIAL_TTL_SECONDS = 60 * 60;
const TURN_KEY_ID_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;
const STUN_URL_PATTERN = /^stun:stun\.cloudflare\.com:(?:3478|53)$/;
const TURN_URL_PATTERN = /^(?:turn|turns):turn\.cloudflare\.com:(?:3478|53|80|443|5349)\?transport=(?:udp|tcp)$/;

interface CloudflareIceServer {
  urls?: unknown;
  username?: unknown;
  credential?: unknown;
}

interface CloudflareIceResponse {
  iceServers?: unknown;
}

/** 为当前合法会话签发一小时 Cloudflare TURN 凭证；长期令牌永不返回手机端。 */
export async function issueChatIce(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<Record<string, unknown>>(request);
  if (!body || Array.isArray(body) || Object.keys(body).length !== 0) {
    throw new HttpError(400, "invalid_chat_ice_request", "WebRTC ICE 凭证请求不得携带字段");
  }
  await enforceEdgeRate(env, "RATE_AUTH", `cid_number:${session.cid_number}:chat_ice`);
  const keyId = env.TURN_KEY_ID?.trim();
  const apiToken = env.TURN_KEY_API_TOKEN?.trim();
  if (!keyId || !TURN_KEY_ID_PATTERN.test(keyId) || !apiToken) {
    throw new HttpError(503, "chat_ice_unavailable", "WebRTC ICE 服务未配置");
  }

  // Cloudflare 官方路径按固定段构造，避免把第三方 API 版本误登记为一方协议版本。
  const turnPath = ["v1", "turn", "keys", keyId, "credentials", "generate-ice-servers"]
    .map(encodeURIComponent)
    .join("/");
  const response = await fetch(
    `https://rtc.live.cloudflare.com/${turnPath}`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${apiToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ ttl: TURN_CREDENTIAL_TTL_SECONDS }),
    },
  );
  if (response.status !== 201) {
    throw new HttpError(503, "chat_ice_unavailable", "WebRTC ICE 服务暂时不可用");
  }
  const text = await response.text();
  if (new TextEncoder().encode(text).byteLength > resourceLimit("chat_signal").max_bytes) {
    throw new HttpError(502, "chat_ice_response_invalid", "WebRTC ICE 服务响应不合法");
  }
  let payload: CloudflareIceResponse;
  try {
    payload = JSON.parse(text) as CloudflareIceResponse;
  } catch {
    throw new HttpError(502, "chat_ice_response_invalid", "WebRTC ICE 服务响应不合法");
  }
  const iceServers = Array.isArray(payload.iceServers)
    ? payload.iceServers as CloudflareIceServer[]
    : [];
  const stunUrls: string[] = [];
  const turnUrls: string[] = [];
  let turnUsername = "";
  let turnCredential = "";
  for (const server of iceServers) {
    const urls = Array.isArray(server?.urls)
      ? server.urls.filter((url): url is string => typeof url === "string")
      : [];
    for (const url of urls) {
      if (STUN_URL_PATTERN.test(url)) stunUrls.push(url);
      else if (TURN_URL_PATTERN.test(url)) turnUrls.push(url);
      else throw new HttpError(502, "chat_ice_response_invalid", "WebRTC ICE 地址不合法");
    }
    if (typeof server?.username === "string" && typeof server?.credential === "string") {
      if (turnUsername || turnCredential) {
        throw new HttpError(502, "chat_ice_response_invalid", "WebRTC TURN 凭证响应重复");
      }
      turnUsername = server.username;
      turnCredential = server.credential;
    }
  }
  if (
    stunUrls.length === 0
    || turnUrls.length === 0
    || turnUsername.length < 8
    || turnUsername.length > 1024
    || turnCredential.length < 8
    || turnCredential.length > 1024
  ) {
    throw new HttpError(502, "chat_ice_response_invalid", "WebRTC ICE 服务响应不完整");
  }
  return jsonResponse({
    stun_urls: [...new Set(stunUrls)],
    turn_urls: [...new Set(turnUrls)],
    turn_username: turnUsername,
    turn_credential: turnCredential,
  });
}

/** 写入一个已序列化的端到端加密 Envelope；HTTP 成功即表示密文已经持久保存。 */
export async function submitChatEnvelope(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<ChatEnvelopePayload>(request);
  assertExactChatEnvelopeFields(body);
  const envelopeId = assertChatEnvelopeId(body.envelope_id);
  const recipientCidNumber = assertChatCidNumber(
    body.recipient_cid_number,
    "invalid_recipient_cid_number",
  );
  const envelope = assertEncodedChatEnvelope(body.envelope);
  if (new TextEncoder().encode(envelope).byteLength > resourceLimit("chat_envelope").max_bytes) {
    throw new HttpError(413, "chat_envelope_too_large", "Chat 端到端加密信封超过上限");
  }
  const createdAtMillis = assertPositiveMillis(
    body.created_at_millis,
    "invalid_chat_created_at",
    "Chat 信封创建时间不合法",
  );
  const ttlMillis = assertPositiveMillis(
    body.ttl_millis,
    "invalid_chat_ttl",
    "Chat 信封存活时间不合法",
  );
  const current = nowMs();
  const maxTtlMillis = (resourceLimit("chat_envelope").ttl_seconds ?? 0) * 1000;
  if (
    ttlMillis > maxTtlMillis
    || !Number.isSafeInteger(createdAtMillis + ttlMillis)
    || createdAtMillis > current + 5 * 60 * 1000
    || createdAtMillis + ttlMillis <= current
  ) {
    throw new HttpError(400, "chat_envelope_expired", "Chat 信封已过期或存活时间超过上限");
  }
  await enforceEdgeRate(
    env,
    "RATE_WRITE",
    `cid_number:${session.cid_number}:chat_message_recipient:${recipientCidNumber}`,
  );
  const item: ChatMailboxItem = {
    envelope_id: envelopeId,
    sender_cid_number: session.cid_number,
    recipient_cid_number: recipientCidNumber,
    envelope,
    created_at_millis: createdAtMillis,
    ttl_millis: ttlMillis,
  };
  const sent = await storeChatEnvelope(env, item);
  if (sent === 0) {
    await sendChatWake(env, recipientCidNumber, session.cid_number).catch(() => 0);
  }
  return jsonResponse({ ok: true });
}

/** 前台连接或系统唤醒后批量读取当前 CID 的未确认密文；返回值不包含任何明文。 */
export async function fetchChatEnvelopes(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  await enforceEdgeRate(env, "RATE_READ", `cid_number:${session.cid_number}:chat_mailbox_read`);
  return jsonResponse(await readChatMailbox(env, session.cid_number));
}

/** 接收端必须先完成解密和本机持久化，再批量确认既有 envelope_id；确认后云端立即删除。 */
export async function acknowledgeChatMailbox(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const raw = await readJson<unknown>(request);
  const maxItems = resourceLimit("chat_ack").max_items ?? 100;
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > maxItems) {
    throw new HttpError(400, "invalid_chat_ack", "Chat 密文确认列表不合法");
  }
  const envelopeIds = [...new Set(raw.map(assertChatEnvelopeId))];
  await enforceEdgeRate(env, "RATE_WRITE", `cid_number:${session.cid_number}:chat_mailbox_ack`);
  await acknowledgeChatEnvelopes(env, session.cid_number, envelopeIds);
  return jsonResponse({ ok: true });
}

function assertExactChatEnvelopeFields(value: ChatEnvelopePayload): void {
  if (!value || typeof value !== "object") {
    throw new HttpError(400, "invalid_chat_envelope_fields", "Chat 信封字段不合法");
  }
  const expected = [
    "created_at_millis",
    "envelope",
    "envelope_id",
    "recipient_cid_number",
    "ttl_millis",
  ];
  const actual = Object.keys(value).sort();
  if (actual.length !== expected.length || actual.some((field, index) => field !== expected[index])) {
    throw new HttpError(400, "invalid_chat_envelope_fields", "Chat 信封字段不合法");
  }
}

function assertPushProvider(value: unknown): PushProvider {
  if (value === "apns" || value === "fcm") return value;
  throw new HttpError(400, "invalid_push_provider", "Chat 推送服务不合法");
}

function assertPushToken(value: unknown): string {
  if (typeof value !== "string" || value.length < 16 || value.length > 4096) {
    throw new HttpError(400, "invalid_push_token", "Chat 推送 Token 不合法");
  }
  return value;
}

export function assertApnsEnvironment(
  pushProvider: PushProvider,
  value: unknown,
): ApnsEnvironment | null {
  if (pushProvider === "apns") {
    if (value === "sandbox" || value === "production") return value;
    throw new HttpError(400, "invalid_apns_environment", "APNs 环境不合法");
  }
  if (value === null || value === undefined) return null;
  throw new HttpError(
    400,
    "unexpected_apns_environment",
    "FCM 端点不得携带 APNs 环境",
  );
}
