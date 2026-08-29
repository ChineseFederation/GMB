import { describe, expect, it } from "vitest";
import {
  publishChatDeviceKey,
  publishChatGroupKeyPackage,
  resolveChatGroupKeyPackage,
  resolveChatDeviceKey,
} from "../src/chat/service";
import type { Env, UserRow } from "../src/types";

const ACCOUNT_ID =
  "0x1111111111111111111111111111111111111111111111111111111111111111";
const OWNER_CID = "CN220-CTZN2-198805200-2026";
const RECIPIENT_CID = "CN220-CTZN2-199001010-2026";
const DEVICE_KEY =
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const GROUP_KEY_PACKAGE = {
  cid_number: RECIPIENT_CID,
  device_id: "bob-phone",
  device_public_key_hex: DEVICE_KEY,
  key_package_id: "kp-aaaaaaaaaaaaaaaaaaaaaaaa",
  key_package: "AQIDBA",
  cipher_suite: "MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519",
  not_before: Date.now() - 60_000,
  not_after: Date.now() + 60_000,
  last_resort: true,
};

class DeviceKeyDb {
  prepare(sql: string): DeviceKeyStmt {
    return new DeviceKeyStmt(sql);
  }
}

class DeviceKeyStmt {
  private values: unknown[] = [];

  constructor(private readonly sql: string) {}

  bind(...values: unknown[]): DeviceKeyStmt {
    this.values = values;
    return this;
  }

  async first<T>(): Promise<T | null> {
    if (this.sql.includes("FROM square_memberships")) {
      return {
        cid_number: this.values[0],
        account_id: ACCOUNT_ID,
        membership_level: "freedom",
        paid_until: Date.now() + 60_000,
        subscription_status: "active",
      } as T;
    }
    if (this.sql.includes("FROM users")) {
      const cidNumber = this.values[0] as string;
      if (cidNumber !== OWNER_CID && cidNumber !== RECIPIENT_CID) return null;
      return {
        cid_number: cidNumber,
        account_id: ACCOUNT_ID,
        binding_revision: 1,
      } as UserRow as T;
    }
    return null;
  }
}

class SessionKv {
  async get<T>(key: string): Promise<T | null> {
    if (key.startsWith("square_session:")) {
      return {
        cid_number: OWNER_CID,
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

function env(onInternalRequest: (request: Request) => Response): Env {
  return {
    DB: new DeviceKeyDb() as unknown as D1Database,
    SQUARE_CACHE: new SessionKv() as unknown as KVNamespace,
    RATE_AUTH: allowRate(),
    RATE_WRITE: allowRate(),
    RATE_READ: allowRate(),
    CHAT: {
      getByName: () => ({ fetch: async (request: Request) => onInternalRequest(request) }),
    } as unknown as DurableObjectNamespace,
  } as Env;
}

function allowRate(): RateLimit {
  return { limit: async () => ({ success: true }) } as RateLimit;
}

function jsonRequest(path: string, method: string, body: object): Request {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      authorization: "Bearer test-session",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

describe("Chat HPKE device key directory", () => {
  it("publishes exactly one stable public key for the authenticated device", async () => {
    let internalBody: unknown;
    const response = await publishChatDeviceKey(
      jsonRequest("/chat/device-key", "PUT", {
        device_id: "alice-phone",
        device_public_key_hex: DEVICE_KEY,
      }),
      env((request) => {
        internalBody = request.json();
        return Response.json({ ok: true });
      }),
    );
    expect(response.status).toBe(200);
    expect(internalBody).toBeInstanceOf(Promise);
  });

  it("resolves the recipient key without consuming or rotating it", async () => {
    const response = await resolveChatDeviceKey(
      jsonRequest("/chat/device-key/resolve", "POST", {
        recipient_cid_number: RECIPIENT_CID,
      }),
      env(() => Response.json({
        ok: true,
        device_key: {
          device_id: "bob-phone",
          device_public_key_hex: DEVICE_KEY,
        },
      })),
    );
    expect(await response.json()).toEqual({
      ok: true,
      cid_number: RECIPIENT_CID,
      device_id: "bob-phone",
      device_public_key_hex: DEVICE_KEY,
    });
  });

  it("rejects malformed public keys", async () => {
    await expect(
      publishChatDeviceKey(
        jsonRequest("/chat/device-key", "PUT", {
          device_id: "alice-phone",
          device_public_key_hex: "short",
        }),
        env(() => Response.json({ ok: true })),
      ),
    ).rejects.toMatchObject({ code: "invalid_chat_device_key" });
  });
});

describe("OpenMLS group last-resort package", () => {
  it("publishes one group-only package for the authenticated device", async () => {
    const response = await publishChatGroupKeyPackage(
      jsonRequest("/chat/groups/key-package", "PUT", {
        key_package: { ...GROUP_KEY_PACKAGE, cid_number: OWNER_CID },
      }),
      env(() => Response.json({ ok: true })),
    );
    expect(response.status).toBe(200);
  });

  it("resolves the recipient package without consuming it", async () => {
    const response = await resolveChatGroupKeyPackage(
      jsonRequest("/chat/groups/key-package/resolve", "POST", {
        recipient_cid_number: RECIPIENT_CID,
      }),
      env(() => Response.json({ ok: true, key_package: GROUP_KEY_PACKAGE })),
    );
    expect(await response.json()).toEqual({
      ok: true,
      key_package: GROUP_KEY_PACKAGE,
    });
  });
});
