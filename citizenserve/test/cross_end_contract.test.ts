import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";

// 跨端契约锁。
//
// Worker 只承载系统唤醒端点和 WebRTC 建连信令。本文件直接读 Flutter 源码文本，
// 锁住两端共享的控制字段，并确保 Envelope、KeyPackage 与附件内容没有云端入口。
//
// 只锁**跨端 JSON 键名**,不锁实现细节;新增跨端字段时在此补一条。

const FLUTTER_ROOT = join(import.meta.dirname, "../../citizenapp");

function readFlutter(relativePath: string): string {
  return readFileSync(join(FLUTTER_ROOT, relativePath), "utf8");
}

describe("跨端 JSON 契约(Worker ⇔ Flutter 键名一致)", () => {
  const transport = readFlutter("lib/chat/transport/chat_cloud_transport.dart");
  const workerChat = readFileSync(
    join(import.meta.dirname, "../src/chat/service.ts"),
    "utf8",
  );

  it("云端边界不含设备聊天公钥、KeyPackage 或 Envelope", () => {
    for (const forbidden of [
      "device_public_key_hex",
      "key_package",
      "envelope_id",
      "'envelope'",
    ]) {
      expect(workerChat).not.toContain(forbidden);
      expect(transport).not.toContain(forbidden);
    }
  });

  it("WebRTC 信令按身份主键 recipient_cid_number 寻址", () => {
    expect(workerChat).toContain("recipient_cid_number");
    expect(transport).toContain("'recipient_cid_number'");
    expect(transport).not.toContain("'recipient_account_id':");
  });

  it("信令只允许 peer_ready 与已经收齐 ICE 候选的 SDP", () => {
    for (const field of ["connection_kind", "connection_id", "sdp"]) {
      expect(workerChat).toContain(field);
    }
    expect(workerChat).not.toContain("kind !== 'ice'");
    expect(workerChat).not.toContain("['kind', 'transfer_id', 'candidate'");
    expect(transport).toContain("'signal': signal");
  });

  it("推送唤醒发件人按 sender_cid_number", () => {
    const workerPush = readFileSync(
      join(import.meta.dirname, "../src/chat/push.ts"),
      "utf8",
    );
    const flutterPush = readFlutter("lib/chat/chat_push_service.dart");
    expect(workerPush).toContain("sender_cid_number");
    expect(flutterPush).toContain("'sender_cid_number'");
  });

  it("APNs 环境按系统唤醒端点登记，FCM 明确为空", () => {
    const workerPush = readFileSync(
      join(import.meta.dirname, "../src/chat/push.ts"),
      "utf8",
    );
    const schema = readFileSync(
      join(import.meta.dirname, "../schema/citizenserve.sql"),
      "utf8",
    );
    expect(workerChat).toContain("body.apns_environment");
    expect(transport).toContain("'apns_environment'");
    expect(workerPush).toContain("device.apns_environment");
    expect(schema).toContain("CREATE TABLE chat_push_endpoints");
    expect(schema).toContain("apns_environment TEXT CHECK");
    expect(schema).toContain(
      "push_provider = 'apns' AND apns_environment IS NOT NULL",
    );
    expect(schema).toContain(
      "push_provider = 'fcm' AND apns_environment IS NULL",
    );
  });

  it("关注/取关按 followed_cid_number,关注列表响应用 entries", () => {
    const workerFollows = readFileSync(
      join(import.meta.dirname, "../src/feeds/follows.ts"),
      "utf8",
    );
    const workerProfiles = readFileSync(
      join(import.meta.dirname, "../src/profiles/service.ts"),
      "utf8",
    );
    const api = readFlutter("lib/8964/services/square_api_client.dart");
    expect(workerFollows).toContain("followed_cid_number");
    expect(api).toContain("'followed_cid_number'");
    expect(workerProfiles).toContain("entries");
    expect(api).toContain("data['entries']");
    expect(api).not.toContain("data['accounts']");
  });

  it("登录响应下发身份主键 cid_number,客户端必解析", () => {
    const workerAuth = readFileSync(
      join(import.meta.dirname, "../src/auth/service.ts"),
      "utf8",
    );
    const api = readFlutter("lib/8964/services/square_api_client.dart");
    expect(workerAuth).toContain("cid_number: cidNumber");
    expect(api).toContain("session['cid_number']");
  });
});

describe("生产 API 路径契约(Worker ⇔ Flutter 无版本路由一致)", () => {
  const squareApi = readFlutter("lib/8964/services/square_api_client.dart");
  const creatorApi = readFlutter("lib/my/creator/creator_api.dart");
  const chatTransport = readFlutter(
    "lib/chat/transport/chat_cloud_transport.dart",
  );
  const workerRoutes = readFileSync(
    join(import.meta.dirname, "../src/routes.ts"),
    "utf8",
  );
  const routeCatalog = readFileSync(
    join(import.meta.dirname, "../src/limits/catalog.ts"),
    "utf8",
  );

  it("App 只使用同域 /api 部署根，业务路径不携带版本段", () => {
    expect(squareApi).toContain("prodBaseUrl = 'https://www.crcfrcn.com/api'");
    expect(squareApi).toContain("'/square/membership'");
    expect(squareApi).toContain("'/square/contacts?");
    expect(creatorApi).toContain("'/square/creator/plan'");
    expect(chatTransport).toContain("'/chat/push-endpoint'");
    expect(chatTransport).toContain("'/chat/signals'");
    expect(`${squareApi}\n${creatorApi}\n${chatTransport}`).not.toMatch(
      /['"]\/v\d+\//,
    );
  });

  it("Worker 路由分发与资源白名单只登记无版本业务路径", () => {
    expect(workerRoutes).toContain('path === "/chain/bootstrap"');
    expect(workerRoutes).toContain('path === "/square/creator/plan"');
    expect(routeCatalog).toContain("^\\/square\\/contacts$");
    expect(routeCatalog).toContain("^\\/chat\\/push-endpoint$");
    expect(routeCatalog).toContain("^\\/chat\\/signals$");
    expect(`${workerRoutes}\n${routeCatalog}`).not.toMatch(/['"]\/v\d+\//);
  });
});

describe("链上 storage 项名锁(Worker ⇔ citizenchain pallet)", () => {
  // 真实事故:citizenchain 把 WalletAccountByCid/CidByWalletAccount 改名为
  // AccountIdByCid/CidByAccountId,Flutter 跟了、Worker 没跟 —— storage key 拼错
  // 后 state_getStorage 返回 null(不是报错),表现为"所有人都未绑定 CID",
  // 登录/鉴权/主页全线失效且软降级掩盖。此处把名字钉死在 pallet 源码上。
  const identity = readFileSync(
    join(import.meta.dirname, "../src/chain/identity.ts"),
    "utf8",
  );
  const palletPath = join(
    FLUTTER_ROOT,
    "../citizenchain/runtime/misc/citizen-identity/src/lib.rs",
  );

  it("Worker 用的 storage 项名必须存在于 citizen-identity pallet", () => {
    const pallet = readFileSync(palletPath, "utf8");
    for (const storageName of [
      "AccountIdByCid",
      "CidByAccountId",
      "CidRegistry",
      "VotingIdentityByCid",
      "CandidateIdentityByCid",
    ]) {
      expect(identity).toContain(`"${storageName}"`);
      expect(pallet).toContain(`pub type ${storageName}`);
    }
    // 改名前的旧项名不得复活。
    expect(identity).not.toContain("WalletAccountByCid");
    expect(identity).not.toContain("CidByWalletAccount");
  });
});

describe("Cloudflare Workers Paid 成本硬边界", () => {
  // Paid 套餐把三个高频对账任务合并到同一五分钟 Cron，但各任务仍必须保留自身批次硬顶。
  const wrangler = readFileSync(join(import.meta.dirname, "../wrangler.toml"), "utf8");
  const worker = readFileSync(join(import.meta.dirname, "../src/index.ts"), "utf8");
  const media = readFileSync(join(import.meta.dirname, "../src/media/service.ts"), "utf8");
  const cleanup = readFileSync(
    join(import.meta.dirname, "../src/membership/expiration_cleanup.ts"),
    "utf8",
  );

  it("只登记五分钟与每日两条 Cron，并保持各任务批次硬顶", () => {
    const cronConfig = wrangler.match(/crons = (\[[^\n]+\])/);
    expect(cronConfig).not.toBeNull();
    expect(JSON.parse(cronConfig![1])).toEqual([
      "*/5 * * * *",
      "4 3 * * *",
    ]);
    expect(wrangler).not.toContain("[limits]");
    expect(wrangler).not.toContain("cpu_ms");
    expect(wrangler).not.toContain("subrequests =");
    for (const cron of ["*/5 * * * *", "4 3 * * *"]) {
      expect(worker).toContain(`_controller.cron === '${cron}'`);
    }
    for (const removed of ["1-56/5 * * * *", "2-57/5 * * * *", "3-58/5 * * * *"]) {
      expect(worker).not.toContain(`_controller.cron === '${removed}'`);
      expect(wrangler).not.toContain(removed);
    }
    for (const task of [
      "reconcileFinalizedUserProjection(env)",
      "reconcileFinalizedSubscriptionProjection(env)",
    ]) expect(worker).toContain(task);
    expect(worker).not.toContain("reconcileFinalizedMembershipProjection(env)");
    expect(worker).not.toContain("reconcileSubscriptions(env)");
  });

  it("R2、Cache Purge 与每日内容清理均有官方批次硬顶", () => {
    expect(media).toContain("const R2_DELETE_BATCH = 1000");
    expect(media).toContain("const CACHE_PURGE_URL_BATCH = 100");
    expect(cleanup).toContain("const MAX_IDENTITIES_PER_SWEEP = 3");
    expect(cleanup).toContain("const MAX_CONTENT_ITEMS_PER_SWEEP = 4");
  });
});
