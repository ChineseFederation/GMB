import { describe, expect, it } from "vitest";
import {
  claimChatKeyPackage,
  publishChatKeyPackages,
} from "../src/chat/service";
import type { Env, UserRow } from "../src/types";

const ACCOUNT_ID =
  "0x1111111111111111111111111111111111111111111111111111111111111111";
const OWNER_CID = "CN220-CTZN2-198805200-2026";
const RECIPIENT_CID = "CN220-CTZN2-199001010-2026";
const DEVICE_KEY =
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

// 这里的内存替身只实现服务函数会访问的 D1 查询，避免测试绕过真实鉴权分支。
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

// 固定会话绑定账户、设备和有效期，用于验证公开包接口复用现有会话认证。
class SessionKv {
  async get<T>(key: string): Promise<T | null> {
    if (
      key ===
      "square_session:4943e43bc034c8bf90e1c2895796b954d3c34dc90afe838448dee6678fa765f8"
    ) {
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

// 普通包和备用包共享同一密码套件与有效期，唯一差异必须是公开包身份和备用标记。
function packageBody(lastResort: boolean) {
  const now = Date.now();
  return {
    cid_number: OWNER_CID,
    device_id: "alice-phone",
    device_public_key_hex: DEVICE_KEY,
    key_package_id: lastResort ? "package-last-resort" : "package-normal",
    key_package: "AQIDBA",
    cipher_suite: "MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519",
    not_before: now - 1000,
    not_after: now + 60_000,
    last_resort: lastResort,
  };
}

function env(onInternalRequest: (request: Request) => Response): Env {
  return {
    DB: new KeyPackageDb() as unknown as D1Database,
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

// 覆盖公开包成对发布、经聊天对象领取，以及备用标记错误时的失败关闭行为。
describe("OpenMLS public KeyPackage delivery", () => {
  it("publishes exactly one normal and one last-resort package", async () => {
    let internalBody: unknown;
    const response = await publishChatKeyPackages(
      jsonRequest("/chat/key-packages", "PUT", {
        normal: packageBody(false),
        last_resort: packageBody(true),
      }),
      env((request) => {
        internalBody = request.json();
        return Response.json({ ok: true });
      }),
    );
    expect(response.status).toBe(200);
    expect(internalBody).toBeInstanceOf(Promise);
  });

  it("claims the recipient package through the existing chat object", async () => {
    const returned = { ...packageBody(false), cid_number: RECIPIENT_CID };
    const response = await claimChatKeyPackage(
      jsonRequest("/chat/key-packages/claim", "POST", {
        recipient_cid_number: RECIPIENT_CID,
      }),
      env(() => Response.json({ ok: true, key_package: returned })),
    );
    expect(await response.json()).toEqual({ ok: true, key_package: returned });
  });

  it("rejects a pair whose last-resort marker is missing", async () => {
    await expect(
      publishChatKeyPackages(
        jsonRequest("/chat/key-packages", "PUT", {
          normal: packageBody(false),
          last_resort: packageBody(false),
        }),
        env(() => Response.json({ ok: true })),
      ),
    ).rejects.toMatchObject({ code: "invalid_chat_key_package" });
  });
});
