import { describe, expect, it } from "vitest";
import {
  assertApnsEnvironment,
  openChatSignal,
  registerChatPushEndpoint,
  submitChatSignal,
} from "../src/chat/service";
import {
  CHAT_WS_PONG_TYPE,
  CHAT_WS_READY_TYPE,
  relayChatSignal,
} from "../src/chat/realtime";
import { apnsHost, sendStorageCleanupAlert } from "../src/chat/push";
import type { Env, UserRow } from "../src/types";

const ACCOUNT_ID =
  "0x1111111111111111111111111111111111111111111111111111111111111111";
const SENDER_CID = "CN220-CTZN2-198805200-2026";
const RECIPIENT_CID = "CN220-CTZN2-199001010-2026";

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
    return { results: [] };
  }

  async run(): Promise<{ meta: { changes: number } }> {
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
): Env {
  return {
    DB: db as unknown as D1Database,
    SQUARE_CACHE: new SessionKv() as unknown as KVNamespace,
    RATE_AUTH: allowRate(),
    CHAT: {
      getByName: () => ({
        fetch: async (request: Request) => {
          if (new URL(request.url).pathname === "/__signal") {
            onSignal?.(await request.json());
            return Response.json({ ok: true, sent });
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

function signalRequest(signal: Record<string, unknown>): Request {
  return new Request("https://worker.test/chat/signals", {
    method: "POST",
    headers: {
      authorization: "Bearer test-session",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      sender_device_id: "alice-phone",
      recipient_cid_number: RECIPIENT_CID,
      signal,
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

  it("relays only a WebRTC control offer and never stores message content", async () => {
    let relayed: unknown;
    const response = await submitChatSignal(
      signalRequest({
        kind: "offer",
        connection_kind: "control",
        connection_id: "control-12345678",
        sdp: "v=0\r\n",
        sdp_type: "offer",
      }),
      fakeEnv(1, (payload) => {
        relayed = payload;
      }),
    );

    expect(await response.json()).toMatchObject({ delivery_state: "sent" });
    expect(relayed).toMatchObject({
      type: "citizen_chat_signal",
      sender_cid_number: SENDER_CID,
      recipient_cid_number: RECIPIENT_CID,
      signal: {
        kind: "offer",
        connection_kind: "control",
        connection_id: "control-12345678",
      },
    });
  });

  it("rejects message envelopes and content fields on the signaling endpoint", async () => {
    await expect(
      submitChatSignal(
        signalRequest({
          kind: "offer",
          connection_kind: "control",
          connection_id: "control-12345678",
          sdp: "v=0\r\n",
          sdp_type: "offer",
          envelope: "AQID",
        }),
        fakeEnv(),
      ),
    ).rejects.toMatchObject({ code: "invalid_chat_signal_fields" });
  });

  it("rejects trickle ICE because candidates must be embedded in the SDP", async () => {
    await expect(
      submitChatSignal(
        signalRequest({
          kind: "ice",
          connection_kind: "control",
          connection_id: "control-12345678",
          candidate: "candidate:1 1 udp 1 192.0.2.1 1234 typ host",
          sdp_mid: "0",
          sdp_mline_index: 0,
        }),
        fakeEnv(),
      ),
    ).rejects.toMatchObject({ code: "invalid_chat_signal_kind" });
  });

  it("keeps a signal queued when the peer has no realtime connection", async () => {
    const response = await submitChatSignal(
      signalRequest({ kind: "peer_ready" }),
      fakeEnv(0),
    );
    expect(await response.json()).toMatchObject({ delivery_state: "queued" });
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
      type: "citizen_chat_signal",
      sender_cid_number: SENDER_CID,
      recipient_cid_number: RECIPIENT_CID,
      recipient_device_id: null,
      sender_device_id: "alice-phone",
      signal: { kind: "peer_ready" },
    });
    expect(sent).toBe(1);
    expect(routedName).toBe(RECIPIENT_CID);
  });

  it("locks the unversioned WebSocket control message types", () => {
    expect(CHAT_WS_READY_TYPE).toBe("citizen_chat_ws_ready");
    expect(CHAT_WS_PONG_TYPE).toBe("citizen_chat_ws_pong");
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
