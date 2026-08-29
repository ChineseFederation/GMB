import { describe, expect, it } from "vitest";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

// 跨端契约锁。
//
// Worker 承载系统唤醒、音视频通话信令、HPKE 设备公开钥和有界端到端密文邮箱。
// 本文件直接读 Flutter 源码文本，锁住两端共享的控制字段，并确保明文、私钥与附件字节
// 没有云端消息入口。
//
// 只锁**跨端 JSON 键名**,不锁实现细节;新增跨端字段时在此补一条。

const FLUTTER_ROOT = join(import.meta.dirname, "../../citizenapp");
const WRANGLER_CONFIGURATION = readFileSync(
  join(import.meta.dirname, "../wrangler.toml"),
  "utf8",
);

function readFlutter(relativePath: string): string {
  return readFileSync(join(FLUTTER_ROOT, relativePath), "utf8");
}

describe("跨端 JSON 契约(Worker ⇔ Flutter 键名一致)", () => {
  const transport = readFlutter("lib/chat/transport/chat_cloud_transport.dart");
  const runtime = readFlutter("lib/chat/chat_runtime.dart");
  const removedWebrtcMessageTransport = join(
    FLUTTER_ROOT,
    "lib/chat/transport/chat_webrtc_transport.dart",
  );
  const workerChat = readFileSync(
    join(import.meta.dirname, "../src/chat/service.ts"),
    "utf8",
  );
  const workerSignal = readFileSync(
    join(import.meta.dirname, "../src/chat/codec.ts"),
    "utf8",
  );
  const workerRealtime = readFileSync(
    join(import.meta.dirname, "../src/chat/realtime.ts"),
    "utf8",
  );

  it("云端消息边界只接收序列化 Envelope，不接收明文或私钥字段", () => {
    for (const forbidden of [
      "message_body",
      "plaintext",
      "private_key",
    ]) {
      expect(workerChat).not.toContain(forbidden);
    }
    expect(workerChat).toContain("envelope_id");
    expect(workerChat).toContain("assertEncodedChatEnvelope");
  });

  it("HPKE 设备公开钥只经 HTTPS 幂等登记和读取", () => {
    expect(transport).toContain("'/chat/device-key'");
    expect(transport).toContain("'/chat/device-key/resolve'");
    expect(runtime).toContain("context.transport.resolveDeviceKey(");
    expect(runtime).not.toContain("context.webrtc.requestMessageKey");
    expect(runtime).not.toContain("claimKeyPackage(");
    expect(transport).not.toContain("'/chat/key-packages");
    expect(transport).toContain("'/chat/groups/key-package'");
    expect(transport).toContain("'/chat/groups/key-package/resolve'");
    expect(existsSync(removedWebrtcMessageTransport)).toBe(false);
  });

  it("WebRTC 信令按身份主键 recipient_cid_number 寻址", () => {
    expect(workerChat).toContain("recipient_cid_number");
    expect(transport).toContain("'recipient_cid_number'");
    expect(transport).not.toContain("'recipient_account_id':");
  });

  it("服务端双向 WSS 使用唯一 connection_id 并接受 Trickle ICE", () => {
    for (const field of ["signal_kind", "connection_id", "candidate", "sdp"]) {
      expect(workerSignal).toContain(field);
    }
    expect(transport).toContain("'signal_kind'");
    expect(transport).toContain("'connection_id'");
    expect(workerSignal).not.toContain("connection_kind");
    expect(workerSignal).not.toContain("transfer_id");
    expect(transport).not.toContain("connection_kind");
    expect(transport).not.toContain("transfer_id");
    expect(workerRealtime).toContain("assertChatSignalFrame(JSON.parse(message))");
    expect(workerRealtime).toContain("CHAT_WS_SIGNAL_RESULT_TYPE");
    expect(transport).toContain("socket.add(jsonEncode(frame))");
  });

  it("Flutter 密文走邮箱且普通消息不依赖 WebRTC", () => {
    expect(transport).toContain("'/chat/messages'");
    expect(transport).toContain("'/chat/messages/ack'");
    expect(transport).toContain("ChatTransportType.mailbox");
    expect(runtime).not.toContain("ChatWebrtcTransport");
    expect(runtime).not.toContain("RTCPeerConnection");
  });

  it("在线与离线收件都从序列化 Envelope 读取唯一会话路由", () => {
    expect(workerRealtime).not.toContain("conversation_id: payload.conversation_id");
    expect(transport).toContain("ChatEnvelope.fromBuffer(envelopeBytes)");
    expect(transport).toContain("decodedEnvelope.conversationId");
    expect(transport).toContain("decodedEnvelope.recipientCidNumber != localCidNumber");
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
    expect(schema).toContain("CREATE TABLE IF NOT EXISTS chat_push_endpoints");
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
  const chatService = readFileSync(
    join(import.meta.dirname, "../src/chat/service.ts"),
    "utf8",
  );
  const chatRealtime = readFileSync(
    join(import.meta.dirname, "../src/chat/realtime.ts"),
    "utf8",
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
    expect(workerRoutes).toContain('path === "/chat/messages"');
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
    expect(routeCatalog).toContain("^\\/chat\\/device-key$");
    expect(routeCatalog).toContain("^\\/chat\\/device-key\\/resolve$");
    expect(routeCatalog).toContain("^\\/chat\\/ice$");
    expect(routeCatalog).toContain("^\\/chat\\/messages$");
    expect(workerRoutes).not.toContain('request.method === "POST" && path === "/chat/signals"');
    expect(`${workerRoutes}\n${routeCatalog}`).not.toMatch(/['"]\/v\d+\//);
  });

  it("信令未投递时两端统一使用 unavailable 且不存在虚假队列", () => {
    expect(chatRealtime).toContain("'unavailable'");
    expect(chatTransport).toContain("'chat_signal_unavailable'");
    expect(`${chatService}\n${chatRealtime}`).not.toContain("queued");
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

  it("正式 Release 声明完整的 R2 HTTPS 预签名绑定", () => {
    expect(WRANGLER_CONFIGURATION).toMatch(
      /\[vars\][\s\S]*CF_ACCOUNT_ID = "[0-9a-f]{32}"/u,
    );
    expect(WRANGLER_CONFIGURATION).toMatch(
      /\[secrets\][\s\S]*required = \[[\s\S]*"R2_KEY", "R2_SECRET"[\s\S]*\]/u,
    );
    expect(WRANGLER_CONFIGURATION).toContain('binding = "SQUARE_PRIVATE"');
    expect(WRANGLER_CONFIGURATION).toContain('bucket_name = "citizenapp-private"');
  });
});

describe("CitizenServe 最终结构和定时任务保持单一合同", () => {
  it("最终结构中的表和索引可安全重复执行", async () => {
    const { readFile } = await import("node:fs/promises");
    const { resolve } = await import("node:path");
    const schema = await readFile(resolve(process.cwd(), "schema/citizenserve.sql"), "utf8");

    expect(schema.match(/CREATE TABLE IF NOT EXISTS /g)?.length).toBe(27);
    expect(schema).not.toMatch(/CREATE TABLE (?!IF NOT EXISTS )/);
    expect(schema).not.toMatch(/CREATE (?:UNIQUE )?INDEX (?!IF NOT EXISTS )/);
    expect(schema).toContain("CREATE TABLE IF NOT EXISTS chat_attachments");
    expect(schema).toContain("CREATE TABLE IF NOT EXISTS chat_attachment_recipients");
  });

  it("清理失败不会阻断身份与会员投影启动", async () => {
    const { readFile } = await import("node:fs/promises");
    const { resolve } = await import("node:path");
    const source = await readFile(resolve(process.cwd(), "src/index.ts"), "utf8");

    expect(source).toContain("Promise.allSettled");
    expect(source).toContain("name: 'project-users'");
    expect(source).toContain("name: 'project-subscriptions'");
    expect(source).not.toContain("ctx.waitUntil(job.catch");
  });
});
// CitizenServe 发布契约必须同时固定公开账户标识、机密访问凭据和正式附件桶，避免附件签名配置再次漏项。

// 中文注释：Wrangler 配置新增公开绑定后必须同步生成类型，避免正式 CI 才发现绑定声明过期。
describe("CitizenServe Worker 绑定类型保持同步", () => {
  it("公开 R2 账户标识必须进入生成的 Worker 绑定类型", async () => {
    const { readFile } = await import("node:fs/promises");
    const { resolve } = await import("node:path");
    const types = await readFile(resolve(process.cwd(), "worker-configuration.d.ts"), "utf8");
    expect(types).toMatch(/\bCF_ACCOUNT_ID:/);
  });
});
