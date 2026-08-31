import { describe, expect, it } from "vitest";
import {
  publishChatKeyPackage,
  resolveChatKeyPackages,
} from "../src/chat/service";
import type { Env, UserRow } from "../src/types";

const ACCOUNT_ID =
  "0x1111111111111111111111111111111111111111111111111111111111111111";
const OWNER_CID = "CN220-CTZN2-198805200-2026";
const RECIPIENT_CID = "CN220-CTZN2-199001010-2026";
const KEY_PACKAGE = {
  cid_number: RECIPIENT_CID,
  device_id: "bob-phone",
  key_package_ref:
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  key_package: "AQIDBA",
  cipher_suite: "MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519",
  not_before: Date.now() - 60_000,
  not_after: Date.now() + 60_000,
  last_resort: true as const,
};

class KeyPackageDb {
  prepare(sql: string): KeyPackageStmt {
    return new KeyPackageStmt(sql);
  }
}

class KeyPackageStmt {
  private values: unknown[] = [];

  constructor(private readonly sql: string) {}

  bind(...values: unknown[]): KeyPackageStmt {
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
    DB: new KeyPackageDb() as unknown as D1Database,
    SQUARE_CACHE: new SessionKv() as unknown as KVNamespace,
    RATE_AUTH: allowRate(),
    RATE_WRITE: allowRate(),
    RATE_READ: allowRate(),
    CHAT: {
      getByName: () => ({
        fetch: async (request: Request) => onInternalRequest(request),
      }),
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

// 中文注释：私聊与群聊共用唯一的 OpenMLS Last Resort KeyPackage 目录。
describe("Chat OpenMLS Last Resort KeyPackage", () => {
  it("publishes the authenticated device package without application HPKE fields", async () => {
    const internalBodies: Promise<unknown>[] = [];
    const ownerPackage = { ...KEY_PACKAGE, cid_number: OWNER_CID };
    const response = await publishChatKeyPackage(
      jsonRequest("/chat/key-package", "PUT", {
        key_package: ownerPackage,
      }),
      env((request) => {
        internalBodies.push(request.json());
        return Response.json({ ok: true });
      }),
    );

    expect(response.status).toBe(200);
    await expect(internalBodies[0]).resolves.toEqual({
      key_package: ownerPackage,
    });
  });

  it("resolves every active recipient device package without consuming it", async () => {
    const secondPackage = {
      ...KEY_PACKAGE,
      device_id: "bob-tablet",
      key_package_ref:
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
    const response = await resolveChatKeyPackages(
      jsonRequest("/chat/key-package/resolve", "POST", {
        recipient_cid_number: RECIPIENT_CID,
      }),
      env(() => Response.json({
        ok: true,
        key_packages: [KEY_PACKAGE, secondPackage],
      })),
    );

    expect(await response.json()).toEqual({
      ok: true,
      key_packages: [KEY_PACKAGE, secondPackage],
    });
  });

  it("rejects removed application HPKE identity fields", async () => {
    await expect(
      publishChatKeyPackage(
        jsonRequest("/chat/key-package", "PUT", {
          key_package: {
            ...KEY_PACKAGE,
            cid_number: OWNER_CID,
            device_public_key_hex:
              "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          },
        }),
        env(() => Response.json({ ok: true })),
      ),
    ).rejects.toMatchObject({ code: "invalid_chat_key_package" });
  });
});
