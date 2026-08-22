import { HttpError } from "../shared/http";
import { assertCidNumber } from "../shared/ids";

const DEVICE_ID_PATTERN = /^[A-Za-z0-9_.:-]{3,128}$/;

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
