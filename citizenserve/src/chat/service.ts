import type { Env } from "../types";
import {
  HttpError,
  jsonResponse,
  readJson,
  requireSession,
} from "../shared/http";
import { nowMs } from "../shared/time";
import {
  assertChatCidNumber,
  assertDeviceId,
  assertPositiveMillis,
} from "./codec";
import { relayChatSignal, requireChatRealtimeNamespace } from "./realtime";
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

interface SubmitSignalRequest {
  sender_device_id?: unknown;
  recipient_cid_number?: unknown;
  recipient_device_id?: unknown;
  signal?: unknown;
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

/**
 * WebRTC 建连信令的唯一 HTTP 入口。
 *
 * 只接受严格字段集的 `peer_ready`、offer 和 answer。ICE 候选必须已经收敛在 SDP 中，
 * 禁止逐候选请求触发平台限流。Envelope、KeyPackage、消息 ID、会话 ID、文件信息等字段
 * 没有合法入口，避免“加密后也能发云端”的影子通道。
 */
export async function submitChatSignal(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<SubmitSignalRequest>(request);
  const senderDeviceId = assertDeviceId(body.sender_device_id);
  const recipientCidNumber = assertChatCidNumber(
    body.recipient_cid_number,
    "invalid_recipient_cid_number",
  );
  const recipientDeviceId = optionalDeviceId(body.recipient_device_id);
  const signal = assertConnectionSignal(body.signal);
  const signalBytes = new TextEncoder().encode(
    JSON.stringify(signal),
  ).byteLength;
  if (signalBytes > resourceLimit("chat_signal").max_bytes) {
    throw new HttpError(413, "chat_signal_too_large", "Chat 建连信令超过上限");
  }
  // 同一发件 CID 对单一收件 CID 的建连尝试独立限流，防止遍历目标触发离线推送。
  await enforceEdgeRate(
    env,
    "RATE_AUTH",
    `cid_number:${session.cid_number}:chat_signal_recipient:${recipientCidNumber}`,
  );
  const sent = await relayChatSignal(env, {
    type: "citizen_chat_signal",
    sender_cid_number: session.cid_number,
    sender_device_id: senderDeviceId,
    recipient_cid_number: recipientCidNumber,
    recipient_device_id: recipientDeviceId,
    signal,
  });
  const wakeSent =
    sent === 0
      ? await sendChatWake(env, recipientCidNumber, session.cid_number).catch(
          () => 0,
        )
      : 0;
  return jsonResponse({
    ok: true,
    delivery_state: sent > 0 ? "sent" : "queued",
    recipient_connections: sent,
    wake_sent: wakeSent,
  });
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

function assertConnectionSignal(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "invalid_chat_signal", "Chat 建连信令格式不合法");
  }
  const signal = value as Record<string, unknown>;
  const kind = signal.kind;
  if (kind === "peer_ready") {
    requireExactKeys(signal, ["kind"]);
    return signal;
  }
  if (kind !== "offer" && kind !== "answer") {
    throw new HttpError(
      400,
      "invalid_chat_signal_kind",
      "Chat 只允许 WebRTC 建连信令",
    );
  }
  const control = signal.connection_kind === "control";
  if (control) {
    assertToken(signal.connection_id, "connection_id");
  } else {
    assertToken(signal.transfer_id, "transfer_id");
    if (signal.connection_kind !== undefined) {
      throw new HttpError(
        400,
        "invalid_chat_signal_fields",
        "附件信令字段不合法",
      );
    }
  }
  requireExactKeys(
    signal,
    control
      ? ["kind", "connection_kind", "connection_id", "sdp", "sdp_type"]
      : ["kind", "transfer_id", "sdp", "sdp_type"],
  );
  assertBoundedString(signal.sdp, "sdp", 1, 48_000);
  assertBoundedString(signal.sdp_type, "sdp_type", 1, 16);
  return signal;
}

function requireExactKeys(
  value: Record<string, unknown>,
  expected: string[],
): void {
  const keys = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (
    keys.length !== wanted.length ||
    keys.some((key, index) => key !== wanted[index])
  ) {
    throw new HttpError(
      400,
      "invalid_chat_signal_fields",
      "Chat 建连信令包含未授权字段",
    );
  }
}

function assertToken(value: unknown, field: string): string {
  const token = assertBoundedString(value, field, 3, 220);
  if (!/^[A-Za-z0-9_.:-]+$/.test(token)) {
    throw new HttpError(
      400,
      "invalid_chat_signal_fields",
      `Chat ${field} 格式不合法`,
    );
  }
  return token;
}

function assertBoundedString(
  value: unknown,
  field: string,
  min: number,
  max: number,
): string {
  if (typeof value !== "string" || value.length < min || value.length > max) {
    throw new HttpError(
      400,
      "invalid_chat_signal_fields",
      `Chat ${field} 格式不合法`,
    );
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

function optionalDeviceId(value: unknown): string | null {
  return typeof value === "string" && value.length > 0
    ? assertDeviceId(value)
    : null;
}
