import { HttpError } from "../shared/http";
import { assertCidNumber } from "../shared/ids";

const DEVICE_ID_PATTERN = /^[A-Za-z0-9_.:-]{3,128}$/;
const ENVELOPE_ID_PATTERN = /^[A-Za-z0-9_.:-]{8,128}$/;
const BASE64_PATTERN = /^[A-Za-z0-9+/_-]+={0,2}$/;
const CONNECTION_ID_PATTERN = /^[A-Za-z0-9_.:-]{3,220}$/;

export const CHAT_SIGNAL_TYPE = "citizen_chat_signal" as const;

export type ChatSignalKind =
  | "offer"
  | "answer"
  | "ice"
  | "hangup"
  | "ice_restart";

export interface ChatSignalFrame {
  type: typeof CHAT_SIGNAL_TYPE;
  recipient_cid_number: string;
  recipient_device_id: string | null;
  signal_kind: ChatSignalKind;
  connection_id?: string;
  sdp?: string;
  sdp_type?: "offer" | "answer";
  candidate?: string;
  sdp_mid?: string;
  sdp_mline_index?: number;
}

/// 聊天收件/归属寻址单元 = 身份主键 cid_number(严格全称,非账户)。
export function assertChatCidNumber(
  value: unknown,
  code = "invalid_chat_cid_number",
): string {
  try {
    return assertCidNumber(value);
  } catch {
    throw new HttpError(400, code, "聊天身份标识 cid_number 格式不合法");
  }
}

export function assertDeviceId(value: unknown): string {
  if (typeof value !== "string" || !DEVICE_ID_PATTERN.test(value)) {
    throw new HttpError(400, "invalid_device_id", "Chat 设备编号格式不合法");
  }
  return value;
}

export function assertChatEnvelopeId(value: unknown): string {
  if (typeof value !== "string" || !ENVELOPE_ID_PATTERN.test(value)) {
    throw new HttpError(400, "invalid_envelope_id", "Chat 信封唯一标识不合法");
  }
  return value;
}

/** 只验证序列化信封编码；CitizenServe 永不解析其中的 MLS 密文、正文或内容密钥。 */
export function assertEncodedChatEnvelope(value: unknown): string {
  if (typeof value !== "string" || value.length === 0 || !BASE64_PATTERN.test(value)) {
    throw new HttpError(400, "invalid_chat_envelope", "Chat 端到端加密信封不合法");
  }
  try {
    atob(value.replace(/-/g, "+").replace(/_/g, "/"));
  } catch {
    throw new HttpError(400, "invalid_chat_envelope", "Chat 端到端加密信封不合法");
  }
  return value;
}

export function assertPositiveMillis(
  value: unknown,
  code: string,
  message: string,
): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0) {
    throw new HttpError(400, code, message);
  }
  return value;
}

/** WSS 信令只接受建连所需字段；发送身份由服务端 socket 附件注入，客户端不能自报。 */
export function assertChatSignalFrame(value: unknown): ChatSignalFrame {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "invalid_chat_signal", "Chat 建连信令格式不合法");
  }
  const signal = value as Record<string, unknown>;
  if (signal.type !== CHAT_SIGNAL_TYPE) {
    throw new HttpError(400, "invalid_chat_signal_type", "Chat 建连信令类型不合法");
  }
  const recipientCidNumber = assertChatCidNumber(
    signal.recipient_cid_number,
    "invalid_recipient_cid_number",
  );
  const recipientDeviceId = signal.recipient_device_id === undefined
    ? null
    : assertDeviceId(signal.recipient_device_id);
  const signalKind = assertSignalKind(signal.signal_kind);
  const baseKeys = ["type", "recipient_cid_number", "signal_kind"];
  if (signal.recipient_device_id !== undefined) baseKeys.push("recipient_device_id");

  const normalized: ChatSignalFrame = {
    type: CHAT_SIGNAL_TYPE,
    recipient_cid_number: recipientCidNumber,
    recipient_device_id: recipientDeviceId,
    signal_kind: signalKind,
  };
  const connectionId = assertConnectionId(signal.connection_id);
  normalized.connection_id = connectionId;
  if (signalKind === "offer" || signalKind === "answer") {
    requireExactKeys(signal, [...baseKeys, "connection_id", "sdp", "sdp_type"]);
    normalized.sdp = assertBoundedString(signal.sdp, "sdp", 1, 48_000);
    if (signal.sdp_type !== signalKind) {
      throw new HttpError(400, "invalid_chat_sdp_type", "WebRTC 会话描述类型不合法");
    }
    normalized.sdp_type = signalKind;
    return normalized;
  }
  if (signalKind === "ice") {
    const keys = [...baseKeys, "connection_id", "candidate"];
    normalized.candidate = assertBoundedString(signal.candidate, "candidate", 1, 4096);
    if (signal.sdp_mid !== undefined) {
      keys.push("sdp_mid");
      normalized.sdp_mid = assertBoundedString(signal.sdp_mid, "sdp_mid", 1, 256);
    }
    if (signal.sdp_mline_index !== undefined) {
      keys.push("sdp_mline_index");
      if (
        typeof signal.sdp_mline_index !== "number"
        || !Number.isSafeInteger(signal.sdp_mline_index)
        || signal.sdp_mline_index < 0
        || signal.sdp_mline_index > 65_535
      ) {
        throw new HttpError(400, "invalid_chat_signal_fields", "WebRTC 媒体描述行索引不合法");
      }
      normalized.sdp_mline_index = signal.sdp_mline_index;
    }
    if (normalized.sdp_mid === undefined && normalized.sdp_mline_index === undefined) {
      throw new HttpError(400, "invalid_chat_signal_fields", "ICE 候选缺少媒体描述定位");
    }
    requireExactKeys(signal, keys);
    return normalized;
  }

  requireExactKeys(signal, [...baseKeys, "connection_id"]);
  return normalized;
}

function assertSignalKind(value: unknown): ChatSignalKind {
  if (
    value === "offer"
    || value === "answer"
    || value === "ice"
    || value === "hangup"
    || value === "ice_restart"
  ) {
    return value;
  }
  throw new HttpError(400, "invalid_chat_signal_kind", "Chat 建连信令类型不合法");
}

function assertConnectionId(value: unknown): string {
  if (typeof value !== "string" || !CONNECTION_ID_PATTERN.test(value)) {
    throw new HttpError(400, "invalid_chat_connection_id", "Chat 连接唯一标识不合法");
  }
  return value;
}

function assertBoundedString(
  value: unknown,
  field: string,
  min: number,
  max: number,
): string {
  if (typeof value !== "string" || value.length < min || value.length > max) {
    throw new HttpError(400, "invalid_chat_signal_fields", `Chat ${field} 格式不合法`);
  }
  return value;
}

function requireExactKeys(value: Record<string, unknown>, expected: string[]): void {
  const keys = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (keys.length !== wanted.length || keys.some((key, index) => key !== wanted[index])) {
    throw new HttpError(400, "invalid_chat_signal_fields", "Chat 建连信令包含未授权字段");
  }
}
