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
import { sendChatAlert } from "./push";
import { resourceLimit } from "../limits/catalog";
import { enforceEdgeRate } from "../security/request_guard";
import { readUserByCidNumber } from "../account/user_repository";
import { requireActiveMembership } from "../membership/service";

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

const CHAT_STUN_URLS = [
  "stun:stun.cloudflare.com:3478",
  "stun:stun.cloudflare.com:53",
] as const;

/** 返回固定 STUN 配置；禁止签发 TURN，直连失败必须由调用方明确失败。 */
export async function issueChatIce(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<Record<string, unknown>>(request);
  if (!body || Array.isArray(body) || Object.keys(body).length !== 0) {
    throw new HttpError(400, "invalid_chat_ice_request", "WebRTC ICE 请求不得携带字段");
  }
  await enforceEdgeRate(env, "RATE_AUTH", `cid_number:${session.cid_number}:chat_ice`);
  return jsonResponse({ stun_urls: CHAT_STUN_URLS });
}

/** 写入一个已序列化的端到端加密 Envelope；HTTP 成功即表示密文已经持久保存。 */
export async function submitChatEnvelope(
  request: Request,
  env: Env,
  ctx?: Pick<ExecutionContext, "waitUntil">,
): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<ChatEnvelopePayload>(request);
  assertExactChatEnvelopeFields(body);
  const envelopeId = assertChatEnvelopeId(body.envelope_id);
  const conversationId = assertChatConversationId(body.conversation_id);
  const recipientCidNumber = assertChatCidNumber(
    body.recipient_cid_number,
    "invalid_recipient_cid_number",
  );
  await requireActiveMembership(env, session.cid_number, session.account_id);
  const recipient = await readUserByCidNumber(env, recipientCidNumber);
  if (!recipient) {
    throw new HttpError(403, "chat_recipient_membership_required", "对方尚未开通会员，无法接收聊天消息");
  }
  try {
    await requireActiveMembership(env, recipient.cid_number, recipient.account_id);
  } catch {
    throw new HttpError(403, "chat_recipient_membership_required", "对方尚未开通会员，无法接收聊天消息");
  }
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
    conversation_id: conversationId,
    envelope,
    created_at_millis: createdAtMillis,
    ttl_millis: ttlMillis,
  };
  const delivery = await storeChatEnvelope(env, item);
  if (delivery.stored) {
    // 系统通知与 WSS 在线投递完全独立。密文首次持久化后立即返回发送成功，
    // APNs/FCM 在 Worker 官方 waitUntil 生命周期内完成，不能拖慢消息提交。
    const alertTask = sendChatAlert(
      env,
      recipientCidNumber,
      session.cid_number,
      conversationId,
      envelopeId,
    ).catch(() => {
        // 禁止输出 CID、Token、envelope_id 或上游响应正文。
        console.error("[chat-push] chat_alert_failed");
      });
    if (ctx == null) {
      // 路由单元测试没有 Worker 生命周期；等待任务可保留完整错误边界。
      await alertTask;
    } else {
      ctx.waitUntil(alertTask);
    }
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
    "conversation_id",
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

function assertChatConversationId(value: unknown): string {
  if (
    typeof value !== "string"
    || value.length < 1
    || value.length > 512
    || /[\u0000-\u001f\u007f]/.test(value)
  ) {
    throw new HttpError(400, "invalid_chat_conversation_id", "Chat 会话编号不合法");
  }
  return value;
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
