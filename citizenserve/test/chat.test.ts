import { readFileSync } from "node:fs";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  acknowledgeChatMailbox,
  assertApnsEnvironment,
  fetchChatEnvelopes,
  issueChatIce,
  openChatSignal,
  registerChatPushEndpoint,
  submitChatEnvelope,
} from "../src/chat/service";
import { assertChatSignalFrame, CHAT_SIGNAL_TYPE } from "../src/chat/codec";
import {
  CHAT_MAILBOX_FETCH_BATCH,
  CHAT_MAILBOX_MAX_BYTES,
  CHAT_MAILBOX_MAX_MESSAGES,
  CHAT_WS_ENVELOPE_TYPE,
  CHAT_WS_PONG_TYPE,
  CHAT_WS_READY_TYPE,
  CHAT_WS_SIGNAL_RESULT_TYPE,
  relayAuthenticatedChatSignal,
  relayChatSignal,
} from "../src/chat/realtime";
import { apnsHost, sendChatAlert, sendStorageCleanupAlert } from "../src/chat/push";
import type { Env, UserRow } from "../src/types";

const ACCOUNT_ID =
  "0x1111111111111111111111111111111111111111111111111111111111111111";
const SENDER_CID = "CN220-CTZN2-198805200-2026";
const RECIPIENT_CID = "CN220-CTZN2-199001010-2026";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

function projectedUser(cidNumber: string): UserRow {
  return {
    cid_number: cidNumber,
    account_id: ACCOUNT_ID,
    binding_revision: 1,
    identity_level: "visitor",
    registration_finalized_block_number: 1,
    registration_finalized_block_hash: `0x${"1".repeat(64)}`,
    binding_finalized_block_number: 1,
    binding_finalized_block_hash: `0x${"1".repeat(64)}`,
    identity_finalized_block_number: 1,
    identity_finalized_block_hash: `0x${"1".repeat(64)}`,
    registered_at: 1,
    binding_updated_at: 1,
    identity_updated_at: 1,
  };
}

class ChatDb {
  readonly sql: string[] = [];
  readonly deletedPushTokens: unknown[][] = [];

  constructor(
    readonly pushDevices: Array<{
      push_provider: "apns" | "fcm";
      push_token: string;
      apns_environment: "sandbox" | "production" | null;
    }> = [],
    readonly existingPushEndpoint: {
      binding_revision: number;
      account_id: string;
      push_provider: "apns" | "fcm";
      push_token: string;
      apns_environment: "sandbox" | "production" | null;
      expires_at: number;
    } | null = null,
  ) {}

  prepare(sql: string): ChatStmt {
    this.sql.push(sql);
    return new ChatStmt(this, sql);
  }
}

class ChatStmt {
  private values: unknown[] = [];

  constructor(
    private readonly db: ChatDb,
    private readonly sql: string,
  ) {}

  bind(...values: unknown[]): ChatStmt {
    this.values = values;
    return this;
  }

  async first<T>(): Promise<T | null> {
    if (
      this.sql.includes("SELECT binding_revision") &&
      this.sql.includes("FROM chat_push_endpoints")
    ) {
      return this.db.existingPushEndpoint as T | null;
    }
    if (this.sql.includes("FROM square_memberships")) {
      return {
        cid_number: this.values[0] as string,
        account_id: ACCOUNT_ID,
        membership_level: "freedom",
        started_at: 1,
        last_charged_at: 1,
        last_charged_price_fen: 100,
        paid_until: Date.now() + 86_400_000,
        subscription_status: "active",
        finalized_block_number: 1,
        finalized_block_hash: `0x${"1".repeat(64)}`,
        verified_at: Date.now(),
        entitlement_lapsed_at: null,
        last_tx_hash: `0x${"2".repeat(64)}`,
      } as T;
    }
    if (
      this.sql.includes("FROM users") &&
      this.sql.includes("WHERE cid_number = ?")
    ) {
      const cidNumber = this.values[0] as string;
      return cidNumber === SENDER_CID || cidNumber === RECIPIENT_CID
        ? (projectedUser(cidNumber) as T)
        : null;
    }
    if (this.sql.includes("SELECT COUNT(*)") && this.sql.includes("chat_push_endpoints")) {
      return { n: 0 } as T;
    }
    return null;
  }

  async all<T>(): Promise<{ results: T[] }> {
    if (this.sql.includes("FROM chat_push_endpoints")) {
      return { results: this.db.pushDevices as T[] };
    }
    return { results: [] };
  }

  async run(): Promise<{ meta: { changes: number } }> {
    if (this.sql.includes("DELETE FROM chat_push_endpoints")) {
      this.db.deletedPushTokens.push([...this.values]);
    }
    return { meta: { changes: 1 } };
  }
}

class SessionKv {
  async get<T>(key: string): Promise<T | null> {
    if (
      key ===
      "square_session:4943e43bc034c8bf90e1c2895796b954d3c34dc90afe838448dee6678fa765f8"
    ) {
      return {
        cid_number: SENDER_CID,
        binding_revision: 1,
        account_id: ACCOUNT_ID,
        device_key_hash: "device-key-hash",
        created_at: Date.now(),
        expires_at: Date.now() + 60_000,
      } as T;
    }
    return null;
  }
}

function fakeEnv(
  sent = 1,
  onSignal?: (payload: unknown) => void,
  db = new ChatDb(),
  stored = true,
): Env {
  // stored 独立模拟首次密文入库，sent 只模拟当前 WSS 在线投递数量。
  return {
    DB: db as unknown as D1Database,
    SQUARE_CACHE: new SessionKv() as unknown as KVNamespace,
    RATE_AUTH: allowRate(),
    RATE_WRITE: allowRate(),
    RATE_READ: allowRate(),
    CHAT: {
      getByName: () => ({
        fetch: async (request: Request) => {
          if (new URL(request.url).pathname === "/__signal") {
            onSignal?.(await request.json());
            return Response.json({ ok: true, sent });
          }
          if (new URL(request.url).pathname === "/__message") {
            return Response.json({ ok: true, stored, sent });
          }
          if (new URL(request.url).pathname === "/__messages") {
            return Response.json([]);
          }
          if (new URL(request.url).pathname === "/__ack") {
            return Response.json({ ok: true });
          }
          return Response.json({ ok: true, routed: true });
        },
      }),
    } as unknown as DurableObjectNamespace,
  } as Env;
}

function allowRate(): RateLimit {
  return {
    limit: async () => ({ success: true }),
  } as RateLimit;
}

// 中文注释：测试请求只承载序列化密文和既有路由字段，禁止夹带正文或另造操作编号。
function envelopeRequest(extra: Record<string, unknown> = {}): Request {
  return new Request("https://worker.test/chat/messages", {
    method: "POST",
    headers: {
      authorization: "Bearer test-session",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      envelope_id: "envelope-12345678",
      recipient_cid_number: RECIPIENT_CID,
      conversation_id: `dm:${SENDER_CID}:${RECIPIENT_CID}`,
      envelope: "AQID",
      created_at_millis: Date.now(),
      ttl_millis: 60_000,
      ...extra,
    }),
  });
}

describe("device-only Chat control plane", () => {
  it("routes APNs devices to the endpoint matching the app environment", () => {
    expect(apnsHost("sandbox")).toBe("api.sandbox.push.apple.com");
    expect(apnsHost("production")).toBe("api.push.apple.com");
  });

  it("requires APNs environment and forbids it on FCM endpoints", () => {
    expect(assertApnsEnvironment("apns", "sandbox")).toBe("sandbox");
    expect(assertApnsEnvironment("apns", "production")).toBe("production");
    expect(assertApnsEnvironment("fcm", null)).toBeNull();
    expect(() => assertApnsEnvironment("apns", null)).toThrow(
      "APNs 环境不合法",
    );
    expect(() => assertApnsEnvironment("fcm", "sandbox")).toThrow(
      "FCM 端点不得携带 APNs 环境",
    );
  });

  it("upserts a wake endpoint with a bounded device count and without device-key storage", async () => {
    const db = new ChatDb();
    const response = await registerChatPushEndpoint(
      new Request("https://worker.test/chat/push-endpoint", {
        method: "PUT",
        headers: {
          authorization: "Bearer test-session",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          device_id: "alice-phone",
          push_provider: "fcm",
          push_token: "fcm-token-123456",
          expires_at: Date.now() + 86_400_000,
        }),
      }),
      fakeEnv(1, undefined, db),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ ok: true });
    const sql = db.sql.join("\n");
    expect(sql).toContain("chat_push_endpoints");
    expect(sql).toContain("COUNT(");
    expect(sql).not.toContain("chat_devices");
    expect(sql).not.toContain("device_public_key");
  });

  // 中文注释：令牌和绑定未变化且有效期充足时必须零写返回，防止每次启动放大 D1 写入量。
  it("returns an unchanged push endpoint without any D1 write", async () => {
    const expiresAt = Date.now() + 80 * 86_400_000;
    const db = new ChatDb([], {
      binding_revision: 1,
      account_id: ACCOUNT_ID,
      push_provider: "fcm",
      push_token: "fcm-token-123456",
      apns_environment: null,
      expires_at: expiresAt,
    });
    const response = await registerChatPushEndpoint(
      new Request("https://worker.test/chat/push-endpoint", {
        method: "PUT",
        headers: {
          authorization: "Bearer test-session",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          device_id: "alice-phone",
          push_provider: "fcm",
          push_token: "fcm-token-123456",
          expires_at: expiresAt,
        }),
      }),
      fakeEnv(1, undefined, db),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ ok: true, expires_at: expiresAt });
    expect(db.sql.some((sql) => /\b(?:DELETE|INSERT|UPDATE|REPLACE)\b/.test(sql))).toBe(false);
  });

  it("rejects a push endpoint lifetime longer than the unified 90 day limit", async () => {
    await expect(registerChatPushEndpoint(
      new Request("https://worker.test/chat/push-endpoint", {
        method: "PUT",
        headers: {
          authorization: "Bearer test-session",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          device_id: "alice-phone",
          push_provider: "fcm",
          push_token: "fcm-token-123456",
          expires_at: Date.now() + 91 * 86_400_000,
        }),
      }),
      fakeEnv(),
    )).rejects.toMatchObject({ code: "push_endpoint_ttl_exceeded" });
  });

  it("accepts flat WSS offer and trickle ICE frames with one connection identifier", () => {
    expect(assertChatSignalFrame({
      type: CHAT_SIGNAL_TYPE,
      recipient_cid_number: RECIPIENT_CID,
      signal_kind: "offer",
      connection_id: "media-12345678",
      sdp: "v=0\r\n",
      sdp_type: "offer",
    })).toMatchObject({ signal_kind: "offer", connection_id: "media-12345678" });
    expect(assertChatSignalFrame({
      type: CHAT_SIGNAL_TYPE,
      recipient_cid_number: RECIPIENT_CID,
      signal_kind: "ice",
      connection_id: "media-12345678",
      candidate: "candidate:1 1 udp 1 192.0.2.1 1234 typ host",
      sdp_mid: "0",
      sdp_mline_index: 0,
    })).toMatchObject({ signal_kind: "ice", sdp_mline_index: 0 });
  });

  it("rejects legacy nested signaling and sender identity spoofing", () => {
    expect(() => assertChatSignalFrame({
      type: CHAT_SIGNAL_TYPE,
      recipient_cid_number: RECIPIENT_CID,
      signal_kind: "offer",
      connection_id: "media-12345678",
      sdp: "v=0\r\n",
      sdp_type: "offer",
      sender_cid_number: SENDER_CID,
    })).toThrow("未授权字段");
    expect(() => assertChatSignalFrame({
      type: CHAT_SIGNAL_TYPE,
      recipient_cid_number: RECIPIENT_CID,
      signal: { kind: "offer" },
    })).toThrow("信令类型不合法");
  });

  it("stores one opaque encrypted envelope and treats durable storage as success", async () => {
    // 收集 waitUntil 任务，验证 Worker 可先返回持久化成功再完成系统通知。
    const tasks: Promise<unknown>[] = [];
    const ctx = {
      waitUntil: (task: Promise<unknown>) => tasks.push(task),
    };
    const response = await submitChatEnvelope(envelopeRequest(), fakeEnv(1), ctx);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
    expect(tasks).toHaveLength(1);
    await Promise.all(tasks);
  });

  it("notifies only the first mailbox insert and does not depend on WSS delivery", async () => {
    // 在线设备同样需要系统通知；重复 envelope 已有持久化事实时不得再次通知。
    const onlineTasks: Promise<unknown>[] = [];
    const onlineCtx = {
      waitUntil: (task: Promise<unknown>) => onlineTasks.push(task),
    };
    await submitChatEnvelope(envelopeRequest(), fakeEnv(1), onlineCtx);
    expect(onlineTasks).toHaveLength(1);

    const duplicateTasks: Promise<unknown>[] = [];
    const duplicateCtx = {
      waitUntil: (task: Promise<unknown>) => duplicateTasks.push(task),
    };
    await submitChatEnvelope(
      envelopeRequest(),
      fakeEnv(0, undefined, new ChatDb(), false),
      duplicateCtx,
    );
    expect(duplicateTasks).toHaveLength(0);
    await Promise.all(onlineTasks);
  });

  it("rejects plaintext or undeclared fields on the encrypted mailbox endpoint", async () => {
    await expect(
      submitChatEnvelope(
        envelopeRequest({ text: "forbidden" }),
        fakeEnv(),
        { waitUntil: () => undefined } as unknown as ExecutionContext,
      ),
    ).rejects.toMatchObject({ code: "invalid_chat_envelope_fields" });
  });

  it("fetches and acknowledges encrypted envelopes in bounded batches", async () => {
    const fetched = await fetchChatEnvelopes(
      new Request("https://worker.test/chat/messages", {
        headers: { authorization: "Bearer test-session" },
      }),
      fakeEnv(),
    );
    expect(await fetched.json()).toEqual([]);
    const acknowledged = await acknowledgeChatMailbox(
      new Request("https://worker.test/chat/messages/ack", {
        method: "POST",
        headers: {
          authorization: "Bearer test-session",
          "content-type": "application/json",
        },
        body: JSON.stringify(["envelope-12345678", "envelope-12345678"]),
      }),
      fakeEnv(),
    );
    expect(await acknowledged.json()).toEqual({ ok: true });
  });

  it("orders mailbox recovery by durable insertion order instead of device clocks", () => {
    const source = readFileSync(
      new URL("../src/chat/realtime.ts", import.meta.url),
      "utf8",
    );
    expect(source).toContain("ORDER BY rowid");
    expect(source).not.toContain("ORDER BY created_at_millis, envelope_id");
  });

  it("deletes a rejected APNs token and logs only safe provider diagnostics", async () => {
    const db = new ChatDb([{
      push_provider: "apns",
      push_token: "rejected-device-token",
      apns_environment: "sandbox",
    }]);
    const env = fakeEnv(1, undefined, db);
    // PEM 类型名称在运行时组合，测试夹具不得在公开源码形成真实私钥头部强特征。
    const privateKeyLabel = ["PRIVATE", "KEY"].join(" ");
    Object.assign(env, {
      APNS_KEY: `-----BEGIN ${privateKeyLabel}-----\nAQ==\n-----END ${privateKeyLabel}-----`,
      APNS_KID: "KID",
      APNS_TEAM: "TEAM",
      APNS_TOPIC: "ios.citizenapp",
    });
    vi.stubGlobal("crypto", {
      subtle: {
        importKey: vi.fn(async () => ({})),
        sign: vi.fn(async () => new Uint8Array([1, 2, 3]).buffer),
      },
    });
    const capturedApnsRequests: Request[] = [];
    vi.stubGlobal("fetch", vi.fn(async (...args: Parameters<typeof fetch>) => {
      capturedApnsRequests.push(new Request(args[0], args[1]));
      return Response.json(
        { reason: "BadDeviceToken" },
        { status: 400 },
      );
    }));
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);

    expect(await sendChatAlert(
      env,
      RECIPIENT_CID,
      SENDER_CID,
      `dm:${SENDER_CID}:${RECIPIENT_CID}`,
      "envelope-12345678",
    )).toBe(0);
    expect(db.deletedPushTokens).toEqual([["apns", "rejected-device-token"]]);
    const diagnostic = String(warn.mock.calls[0]?.[0] ?? "");
    expect(diagnostic).toContain('\"provider\":\"apns\"');
    expect(diagnostic).toContain('\"status\":400');
    expect(diagnostic).toContain('\"reason\":\"BadDeviceToken\"');
    expect(diagnostic).not.toContain(RECIPIENT_CID);
    expect(diagnostic).not.toContain("rejected-device-token");
    expect(capturedApnsRequests).toHaveLength(1);
    expect(capturedApnsRequests[0].headers.get("apns-collapse-id")).toBeNull();
  });

  it("reports unavailable without storing an undelivered WSS signal", async () => {
    const state = await relayAuthenticatedChatSignal(
      fakeEnv(0),
      { cid_number: SENDER_CID, device_id: "alice-phone" },
      assertChatSignalFrame({
        type: CHAT_SIGNAL_TYPE,
        recipient_cid_number: RECIPIENT_CID,
        signal_kind: "hangup",
        connection_id: "media-12345678",
      }),
    );
    expect(state).toBe("unavailable");
  });

  it("returns only fixed STUN addresses and never issues TURN credentials", async () => {
    const env = fakeEnv();
    const response = await issueChatIce(new Request("https://worker.test/chat/ice", {
      method: "POST",
      headers: {
        authorization: "Bearer test-session",
        "content-type": "application/json",
      },
      body: "{}",
    }), env);
    expect(await response.json()).toEqual({
      stun_urls: ["stun:stun.cloudflare.com:3478", "stun:stun.cloudflare.com:53"],
    });
  });

  it("routes WSS signal connections from the CID session without a push registration gate", async () => {
    const response = await openChatSignal(
      new Request("https://worker.test/chat/signals", {
        headers: {
          authorization: "Bearer test-session",
          upgrade: "websocket",
          "x-chat-device": "alice-phone",
        },
      }),
      fakeEnv(),
    );
    expect(await response.json()).toMatchObject({ routed: true });
  });

  it("routes a transient signal to the recipient CID object", async () => {
    let routedName = "";
    const env = fakeEnv();
    env.CHAT = {
      getByName: (name: string) => {
        routedName = name;
        return { fetch: async () => Response.json({ ok: true, sent: 1 }) };
      },
    } as unknown as DurableObjectNamespace;

    const sent = await relayChatSignal(env, {
      type: CHAT_SIGNAL_TYPE,
      sender_cid_number: SENDER_CID,
      recipient_cid_number: RECIPIENT_CID,
      recipient_device_id: null,
      sender_device_id: "alice-phone",
      signal_kind: "hangup",
      connection_id: "media-12345678",
    });
    expect(sent).toBe(1);
    expect(routedName).toBe(RECIPIENT_CID);
  });

  it("locks the unversioned WebSocket control message types", () => {
    expect(CHAT_WS_READY_TYPE).toBe("citizen_chat_ws_ready");
    expect(CHAT_WS_PONG_TYPE).toBe("citizen_chat_ws_pong");
    expect(CHAT_WS_ENVELOPE_TYPE).toBe("citizen_chat_envelope");
    expect(CHAT_WS_SIGNAL_RESULT_TYPE).toBe("citizen_chat_signal_result");
    expect(CHAT_MAILBOX_MAX_MESSAGES).toBe(1000);
    expect(CHAT_MAILBOX_MAX_BYTES).toBe(8 * 1024 * 1024);
    expect(CHAT_MAILBOX_FETCH_BATCH).toBe(100);
  });

  it("storage cleanup alert only targets current CID wake endpoints", async () => {
    await expect(
      sendStorageCleanupAlert(
        fakeEnv(),
        RECIPIENT_CID,
        100_000_000_000,
        2_000_000,
      ),
    ).resolves.toBe(0);
  });
});
