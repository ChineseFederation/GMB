import { HttpError, jsonResponse } from '../shared/http';
import { nowMs } from '../shared/time';
import type { ChatMailboxItem, Env } from '../types';
import { readUserByCidNumber } from '../account/user_repository';
import { resourceLimit } from '../limits/catalog';
import {
  assertChatSignalFrame,
  CHAT_SIGNAL_TYPE,
  type ChatSignalFrame,
  type ChatSignalKind,
} from './codec';
import { sendChatWake } from './push';

export interface ChatSignalPayload {
  type: typeof CHAT_SIGNAL_TYPE;
  sender_cid_number: string;
  sender_device_id: string;
  recipient_cid_number: string;
  recipient_device_id: string | null;
  /// 仅由 Worker 在投递前按 finalized 注入；客户端不得提供或决定。
  recipient_binding_revision?: number;
  recipient_binding_account_id?: string;
  signal_kind: ChatSignalKind;
  connection_id?: string;
  sdp?: string;
  sdp_type?: 'offer' | 'answer';
  candidate?: string;
  sdp_mid?: string;
  sdp_mline_index?: number;
}

// WebSocket 控制消息类型由 Worker 单源导出，测试锁定精确字面值，禁止另造版本后缀。
export const CHAT_WS_READY_TYPE = 'citizen_chat_ws_ready' as const;
export const CHAT_WS_PONG_TYPE = 'citizen_chat_ws_pong' as const;
export const CHAT_WS_ENVELOPE_TYPE = 'citizen_chat_envelope' as const;
export const CHAT_WS_SIGNAL_RESULT_TYPE = 'citizen_chat_signal_result' as const;

interface RoutedChatMailboxItem extends ChatMailboxItem {
  recipient_binding_revision: number;
  recipient_binding_account_id: string;
}

type ChatMailboxSqlRow = ChatMailboxItem & Record<string, SqlStorageValue>;

interface ChatMailboxUsage extends Record<string, SqlStorageValue> {
  message_count: number;
  envelope_bytes: number;
}

interface ChatSocketAttachment {
  cid_number: string;
  binding_revision: number;
  account_id: string;
  device_id: string;
  connected_at: number;
  ping_window_started_at: number;
  ping_count: number;
  signal_window_started_at: number;
  signal_count: number;
}

const deviceTagPrefix = 'device:';
const CHAT_SOCKET_MAX_COUNT = 8;
const CHAT_SOCKET_MAX_AGE_MS = 24 * 60 * 60 * 1000;
const CHAT_PING_WINDOW_MS = 60 * 1000;
const CHAT_PING_MAX_COUNT = 6;
const CHAT_SIGNAL_WINDOW_MS = 60 * 1000;
const CHAT_SIGNAL_MAX_COUNT = 120;
const CHAT_ENVELOPE_LIMIT = resourceLimit('chat_envelope');
export const CHAT_MAILBOX_MAX_MESSAGES = CHAT_ENVELOPE_LIMIT.max_count ?? 1000;
export const CHAT_MAILBOX_MAX_BYTES = CHAT_ENVELOPE_LIMIT.max_total_bytes ?? 8 * 1024 * 1024;
export const CHAT_MAILBOX_FETCH_BATCH = CHAT_ENVELOPE_LIMIT.max_items ?? 100;

/**
 * CID 级 Chat 实时入口与有界密文邮箱；WebSocket 附件额外绑定 finalized 版本与当前授权账户。
 *
 * SQLite 只暂存序列化后的端到端加密 Envelope，收到设备持久化 ACK 后立即删除；
 * WSS 使用 Cloudflare Hibernation API，空闲期间不靠定时器维持对象常驻。
 */
export class Chat implements DurableObject {
  constructor(
    private readonly state: DurableObjectState,
    private readonly env: Env,
  ) {
    void this.env;
    this.state.storage.sql.exec(`CREATE TABLE IF NOT EXISTS chat_envelopes (
      envelope_id TEXT PRIMARY KEY,
      sender_cid_number TEXT NOT NULL,
      recipient_cid_number TEXT NOT NULL,
      envelope TEXT NOT NULL,
      created_at_millis INTEGER NOT NULL,
      ttl_millis INTEGER NOT NULL
    )`);
  }

  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (request.method === 'POST' && path === '/__signal') {
      const payload = (await request.json()) as ChatSignalPayload;
      return jsonResponse({ ok: true, sent: this.deliver(payload) });
    }
    if (request.method === 'POST' && path === '/__message') {
      const payload = (await request.json()) as RoutedChatMailboxItem;
      this.deleteExpiredEnvelopes();
      const existing = this.state.storage.sql.exec<ChatMailboxSqlRow>(
        `SELECT envelope_id, sender_cid_number, recipient_cid_number, envelope,
                created_at_millis, ttl_millis
           FROM chat_envelopes WHERE envelope_id = ?`,
        payload.envelope_id,
      ).toArray()[0];
      if (existing && !sameStoredEnvelope(existing, payload)) {
        return jsonResponse(
          { ok: false, error_code: 'chat_envelope_id_conflict', message: 'Chat 信封唯一标识冲突' },
          { status: 409 },
        );
      }
      if (!existing) {
        const usage = this.state.storage.sql.exec<ChatMailboxUsage>(
          `SELECT COUNT(*) AS message_count,
                  COALESCE(SUM(LENGTH(envelope)), 0) AS envelope_bytes
             FROM chat_envelopes`,
        ).toArray()[0] ?? { message_count: 0, envelope_bytes: 0 };
        if (
          usage.message_count >= CHAT_MAILBOX_MAX_MESSAGES
          || usage.envelope_bytes + payload.envelope.length > CHAT_MAILBOX_MAX_BYTES
        ) {
          return jsonResponse(
            { ok: false, error_code: 'chat_mailbox_full', message: '接收方临时密文邮箱已满' },
            { status: 429 },
          );
        }
        this.state.storage.sql.exec(
          `INSERT INTO chat_envelopes (
             envelope_id, sender_cid_number, recipient_cid_number, envelope,
             created_at_millis, ttl_millis
           ) VALUES (?, ?, ?, ?, ?, ?)`,
          payload.envelope_id,
          payload.sender_cid_number,
          payload.recipient_cid_number,
          payload.envelope,
          payload.created_at_millis,
          payload.ttl_millis,
        );
      }
      return jsonResponse({
        ok: true,
        stored: !existing,
        sent: this.deliverEnvelope(payload),
      });
    }
    if (request.method === 'GET' && path === '/__messages') {
      this.deleteExpiredEnvelopes();
      const rows = this.state.storage.sql.exec<ChatMailboxSqlRow>(
        `SELECT envelope_id, sender_cid_number, recipient_cid_number, envelope,
                created_at_millis, ttl_millis
           FROM chat_envelopes
          ORDER BY created_at_millis, envelope_id
          LIMIT ?`,
        CHAT_MAILBOX_FETCH_BATCH,
      ).toArray();
      return jsonResponse(rows);
    }
    if (request.method === 'POST' && path === '/__ack') {
      const envelopeIds = (await request.json()) as string[];
      if (envelopeIds.length > 0) {
        const placeholders = envelopeIds.map(() => '?').join(', ');
        this.state.storage.sql.exec(
          `DELETE FROM chat_envelopes WHERE envelope_id IN (${placeholders})`,
          ...envelopeIds,
        );
      }
      return jsonResponse({ ok: true });
    }
    if (request.method === 'POST' && path === '/__close') {
      let closed = 0;
      for (const socket of this.state.getWebSockets()) {
        socket.close(1008, 'account_deleted');
        closed += 1;
      }
      this.state.storage.sql.exec('DELETE FROM chat_envelopes');
      return jsonResponse({ ok: true, closed });
    }
    if (request.method === 'POST' && path === '/__close_stale') {
      const current = (await request.json()) as {
        binding_revision?: unknown;
        account_id?: unknown;
      };
      let closed = 0;
      for (const socket of this.state.getWebSockets()) {
        const attachment = readAttachment(socket);
        if (
          !attachment
          || attachment.binding_revision !== current.binding_revision
          || attachment.account_id !== current.account_id
        ) {
          socket.close(1008, 'cid_binding_changed');
          closed += 1;
        }
      }
      return jsonResponse({ ok: true, closed });
    }
    if (request.headers.get('upgrade')?.toLowerCase() !== 'websocket') {
      return jsonResponse({ ok: false, error_code: 'websocket_required', message: '请使用 WebSocket 连接' }, { status: 426 });
    }

    const cidNumber = request.headers.get('x-chat-cid-number');
    const bindingRevision = Number.parseInt(
      request.headers.get('x-chat-binding-revision') ?? '',
      10,
    );
    const accountId = request.headers.get('x-chat-account-id');
    const deviceId = request.headers.get('x-chat-device');
    if (
      !cidNumber
      || !Number.isSafeInteger(bindingRevision)
      || bindingRevision <= 0
      || !accountId
      || !deviceId
    ) {
      return jsonResponse({ ok: false, error_code: 'chat_connection_invalid', message: 'Chat 连接缺少设备身份' }, { status: 400 });
    }
    const connectedAt = nowMs();
    // 新连接建立时同步清理无效或过期休眠 socket，避免它们占用连接上限。
    for (const existing of this.state.getWebSockets()) {
      const attachment = readAttachment(existing);
      if (!attachment || connectedAt - attachment.connected_at >= CHAT_SOCKET_MAX_AGE_MS) {
        existing.close(1000, 'connection_expired');
      }
    }
    // 同一 CID/device 只保留最新信令 socket；旧连接不计入单 CID 有界连接数。
    for (const existing of this.state.getWebSockets(deviceTag(deviceId))) {
      existing.close(1000, 'replaced_by_current_connection');
    }
    const activeDevices = new Set(
      this.state.getWebSockets()
        .map((socket) => readAttachment(socket)?.device_id)
        .filter((activeDevice): activeDevice is string =>
          Boolean(activeDevice) && activeDevice !== deviceId),
    );
    if (activeDevices.size >= CHAT_SOCKET_MAX_COUNT) {
      return jsonResponse(
        { ok: false, error_code: 'chat_connection_limit_reached', message: 'Chat 连接数已达上限' },
        { status: 429 },
      );
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
    server.serializeAttachment({
      cid_number: cidNumber,
      binding_revision: bindingRevision,
      account_id: accountId,
      device_id: deviceId,
      connected_at: connectedAt,
      ping_window_started_at: connectedAt,
      ping_count: 0,
      signal_window_started_at: connectedAt,
      signal_count: 0,
    } satisfies ChatSocketAttachment);
    this.state.acceptWebSocket(server, [deviceTag(deviceId)]);
    server.send(JSON.stringify({ type: CHAT_WS_READY_TYPE, server_time: nowMs() }));
    return new Response(null, { status: 101, webSocket: client });
  }

  private deliver(payload: ChatSignalPayload): number {
    const sockets = payload.recipient_device_id
      ? this.state.getWebSockets(deviceTag(payload.recipient_device_id))
      : this.state.getWebSockets();
    // 路由绑定只在 Worker 内部使用；接收端只能看到发送身份和严格信令字段。
    const text = JSON.stringify({
      type: payload.type,
      sender_cid_number: payload.sender_cid_number,
      sender_device_id: payload.sender_device_id,
      signal_kind: payload.signal_kind,
      ...(payload.connection_id === undefined ? {} : { connection_id: payload.connection_id }),
      ...(payload.sdp === undefined ? {} : { sdp: payload.sdp }),
      ...(payload.sdp_type === undefined ? {} : { sdp_type: payload.sdp_type }),
      ...(payload.candidate === undefined ? {} : { candidate: payload.candidate }),
      ...(payload.sdp_mid === undefined ? {} : { sdp_mid: payload.sdp_mid }),
      ...(payload.sdp_mline_index === undefined
        ? {}
        : { sdp_mline_index: payload.sdp_mline_index }),
    });
    let sent = 0;
    for (const socket of sockets) {
      const attachment = readAttachment(socket);
      if (
        attachment?.cid_number !== payload.recipient_cid_number
        || attachment.binding_revision !== payload.recipient_binding_revision
        || attachment.account_id !== payload.recipient_binding_account_id
      ) {
        socket.close(1008, 'cid_binding_changed');
        continue;
      }
      try {
        socket.send(text);
        sent += 1;
      } catch {
        socket.close(1011, 'send_failed');
      }
    }
    return sent;
  }

  private deliverEnvelope(payload: RoutedChatMailboxItem): number {
    const text = JSON.stringify({
      type: CHAT_WS_ENVELOPE_TYPE,
      envelope_id: payload.envelope_id,
      sender_cid_number: payload.sender_cid_number,
      envelope: payload.envelope,
      created_at_millis: payload.created_at_millis,
      ttl_millis: payload.ttl_millis,
    });
    let sent = 0;
    for (const socket of this.state.getWebSockets()) {
      const attachment = readAttachment(socket);
      if (
        attachment?.cid_number !== payload.recipient_cid_number
        || attachment.binding_revision !== payload.recipient_binding_revision
        || attachment.account_id !== payload.recipient_binding_account_id
      ) {
        socket.close(1008, 'cid_binding_changed');
        continue;
      }
      try {
        socket.send(text);
        sent += 1;
      } catch {
        socket.close(1011, 'send_failed');
      }
    }
    return sent;
  }

  private deleteExpiredEnvelopes(): void {
    this.state.storage.sql.exec(
      'DELETE FROM chat_envelopes WHERE created_at_millis + ttl_millis <= ?',
      nowMs(),
    );
  }

  async webSocketMessage(socket: WebSocket, message: string | ArrayBuffer) {
    if (typeof message !== 'string') {
      socket.close(1003, 'binary_not_supported');
      return;
    }
    const attachment = readAttachment(socket);
    if (!attachment) {
      socket.close(1008, 'attachment_invalid');
      return;
    }
    const current = nowMs();
    if (current - attachment.connected_at >= CHAT_SOCKET_MAX_AGE_MS) {
      socket.close(1000, 'connection_expired');
      return;
    }
    if (message === 'ping') {
      if (current - attachment.ping_window_started_at >= CHAT_PING_WINDOW_MS) {
        attachment.ping_window_started_at = current;
        attachment.ping_count = 0;
      }
      attachment.ping_count += 1;
      if (attachment.ping_count > CHAT_PING_MAX_COUNT) {
        socket.close(1008, 'ping_rate_exceeded');
        return;
      }
      socket.serializeAttachment(attachment);
      socket.send(JSON.stringify({ type: CHAT_WS_PONG_TYPE, server_time: current }));
      return;
    }
    if (new TextEncoder().encode(message).byteLength > resourceLimit('chat_signal').max_bytes) {
      socket.close(1009, 'signal_too_large');
      return;
    }
    let frame: ChatSignalFrame;
    try {
      frame = assertChatSignalFrame(JSON.parse(message));
    } catch {
      socket.close(1008, 'signal_invalid');
      return;
    }
    if (current - attachment.signal_window_started_at >= CHAT_SIGNAL_WINDOW_MS) {
      attachment.signal_window_started_at = current;
      attachment.signal_count = 0;
    }
    attachment.signal_count += 1;
    if (attachment.signal_count > CHAT_SIGNAL_MAX_COUNT) {
      socket.close(1008, 'signal_rate_exceeded');
      return;
    }
    socket.serializeAttachment(attachment);
    try {
      const delivery = await relayAuthenticatedChatSignal(this.env, attachment, frame);
      socket.send(JSON.stringify({
        type: CHAT_WS_SIGNAL_RESULT_TYPE,
        delivery_state: delivery,
        ...(frame.connection_id === undefined ? {} : { connection_id: frame.connection_id }),
      }));
    } catch {
      socket.close(1011, 'signal_delivery_failed');
    }
  }

  async webSocketClose(socket: WebSocket) {
    socket.close();
  }

  async webSocketError(socket: WebSocket) {
    socket.close(1011, 'socket_error');
  }
}

export async function relayChatSignal(env: Env, payload: ChatSignalPayload): Promise<number> {
  // 转发前读取 finalized 用户投影；旧账户遗留 socket 不得收到任何建连元数据。
  const binding = await readUserByCidNumber(
    env,
    payload.recipient_cid_number,
  );
  if (
    !binding
    || binding.cid_number !== payload.recipient_cid_number
    || binding.binding_revision <= 0
    || !binding.account_id
  ) {
    return 0;
  }
  const routedPayload: ChatSignalPayload = {
    ...payload,
    recipient_binding_revision: binding.binding_revision,
    recipient_binding_account_id: binding.account_id,
  };
  const namespace = requireChatRealtimeNamespace(env);
  const response = await namespace.getByName(payload.recipient_cid_number).fetch(
    new Request('https://chat.internal/__signal', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(routedPayload),
    }),
  );
  if (!response.ok) return 0;
  return ((await response.json()) as { sent?: number }).sent ?? 0;
}

/** 使用已认证 socket 身份发送瞬时信令；离线只触发无内容唤醒，不保存 SDP 或 ICE。 */
export async function relayAuthenticatedChatSignal(
  env: Env,
  sender: Pick<ChatSocketAttachment, 'cid_number' | 'device_id'>,
  frame: ChatSignalFrame,
): Promise<'sent' | 'unavailable'> {
  const sent = await relayChatSignal(env, {
    ...frame,
    sender_cid_number: sender.cid_number,
    sender_device_id: sender.device_id,
  });
  if (sent === 0) {
    await sendChatWake(env, frame.recipient_cid_number, sender.cid_number).catch(() => 0);
  }
  return sent > 0 ? 'sent' : 'unavailable';
}

export interface ChatMailboxDelivery {
  stored: boolean;
  sent: number;
}

/** 按接收 CID 写入唯一有界密文邮箱，并向该 CID 当前在线设备立即推送同一密文。 */
export async function storeChatEnvelope(
  env: Env,
  item: ChatMailboxItem,
): Promise<ChatMailboxDelivery> {
  const binding = await readUserByCidNumber(env, item.recipient_cid_number);
  if (!binding || binding.binding_revision <= 0 || !binding.account_id) {
    throw new HttpError(404, 'chat_recipient_not_found', '接收方公民身份不存在');
  }
  const response = await requireChatRealtimeNamespace(env)
    .getByName(item.recipient_cid_number)
    .fetch(new Request('https://chat.internal/__message', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        ...item,
        recipient_binding_revision: binding.binding_revision,
        recipient_binding_account_id: binding.account_id,
      } satisfies RoutedChatMailboxItem),
    }));
  const body = await response.json() as {
    stored?: boolean;
    sent?: number;
    error_code?: string;
    message?: string;
  };
  if (!response.ok) {
    throw new HttpError(
      response.status,
      body.error_code ?? 'chat_mailbox_write_failed',
      body.message ?? 'Chat 临时密文写入失败',
    );
  }
  return {
    stored: body.stored === true,
    sent: body.sent ?? 0,
  };
}

export async function readChatMailbox(env: Env, cidNumber: string): Promise<ChatMailboxItem[]> {
  const response = await requireChatRealtimeNamespace(env)
    .getByName(cidNumber)
    .fetch(new Request('https://chat.internal/__messages'));
  if (!response.ok) {
    throw new HttpError(response.status, 'chat_mailbox_read_failed', 'Chat 临时密文读取失败');
  }
  const rows = await response.json();
  if (!Array.isArray(rows)) {
    throw new HttpError(502, 'chat_mailbox_response_invalid', 'Chat 临时密文响应不合法');
  }
  return rows as ChatMailboxItem[];
}

export async function acknowledgeChatEnvelopes(
  env: Env,
  cidNumber: string,
  envelopeIds: string[],
): Promise<void> {
  const response = await requireChatRealtimeNamespace(env)
    .getByName(cidNumber)
    .fetch(new Request('https://chat.internal/__ack', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(envelopeIds),
    }));
  if (!response.ok) {
    throw new HttpError(response.status, 'chat_mailbox_ack_failed', 'Chat 临时密文确认失败');
  }
}

/// 只关闭不属于 finalized 当前绑定三元组的连接；新账户同 CID 连接保持在线。
export async function closeStaleChatRealtime(
  env: Env,
  cidNumber: string,
  bindingRevision: number,
  accountId: string,
): Promise<number> {
  const namespace = env.CHAT;
  if (!namespace) return 0;
  const response = await namespace.getByName(cidNumber).fetch(
    new Request('https://chat.internal/__close_stale', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        binding_revision: bindingRevision,
        account_id: accountId,
      }),
    }),
  );
  if (!response.ok) {
    throw new HttpError(
      503,
      'chat_realtime_revoke_failed',
      '此前 Chat 信令连接撤销失败，请重试当前操作',
    );
  }
  return ((await response.json()) as { closed?: number }).closed ?? 0;
}

/// 关闭某身份主键 cid_number 的实时信箱，仅供整身份注销使用。
///
/// 换绑时当前与新账户共享同一 CID/DO，严禁调用本函数，否则会把新账户连接一并踢下线。
export async function closeChatRealtime(env: Env, cidNumber: string): Promise<number> {
  const namespace = env.CHAT;
  if (!namespace) return 0;
  const response = await namespace.getByName(cidNumber).fetch(
    new Request('https://chat.internal/__close', { method: 'POST' }),
  );
  if (!response.ok) return 0;
  return ((await response.json()) as { closed?: number }).closed ?? 0;
}

export function requireChatRealtimeNamespace(env: Env): DurableObjectNamespace {
  if (!env.CHAT) {
    throw new HttpError(503, 'chat_realtime_unavailable', '聊天实时服务未配置');
  }
  return env.CHAT;
}

function deviceTag(deviceId: string): string {
  return `${deviceTagPrefix}${deviceId}`;
}

function sameStoredEnvelope(left: ChatMailboxItem, right: ChatMailboxItem): boolean {
  return left.envelope_id === right.envelope_id
    && left.sender_cid_number === right.sender_cid_number
    && left.recipient_cid_number === right.recipient_cid_number
    && left.envelope === right.envelope
    && left.created_at_millis === right.created_at_millis
    && left.ttl_millis === right.ttl_millis;
}

function readAttachment(socket: WebSocket): ChatSocketAttachment | null {
  const value = socket.deserializeAttachment();
  if (
    value
    && typeof value === 'object'
    && typeof value.cid_number === 'string'
    && typeof value.binding_revision === 'number'
    && typeof value.account_id === 'string'
    && typeof value.device_id === 'string'
    && typeof value.connected_at === 'number'
    && typeof value.ping_window_started_at === 'number'
    && typeof value.ping_count === 'number'
    && typeof value.signal_window_started_at === 'number'
    && typeof value.signal_count === 'number'
  ) {
    return value as ChatSocketAttachment;
  }
  return null;
}
