# CitizenChatServer

Cloudflare 正式资源统一使用小写 `<product>-<resource>`：Worker 为
`citizenchatserver-workers`，D1 为 `citizenchatserver-d1`，R2 为
`citizenchatserver-r2`，正式域名为 `chat.crcfrcn.com`。

CI 只消费 TataChatServer 的正式 Cloudflare Release 并绑定当前 GMB `main` 的实例声明；
Release 只封装准确成功 CI 候选；发布只由 TataConsole 原生发布器消费正式 GMB Release。

CitizenChatServer 是公民产品使用的 TataChatServer Cloudflare 实例。该目录只保存宿主产品声明与资源配置，不复制通用聊天源码，也不保存编译产物、密钥或生产资源编号。

- HTTPS：`https://chat.crcfrcn.com`
- WSS：`wss://chat.crcfrcn.com/realtime`
- 授权签发方：CitizenServe
- 授权受众：`citizenchatserver`
- 通用实现：TATA 仓库的 `tatachatserver`

正式 Worker 由 TataChatServer 的 `cloudflare/assemble.mjs` 在
`TataConsole/target/.work/citizenchatserver-cloudflare/` 中装配。装配器按 TATA 仓库原布局把
TataChatServer 与构建期唯一协议源 TataChatSDK 复制到隔离目录，调用官方锁定版
`worker-build`。TataChatSDK 只提供 OpenMLS/protobuf 规范，不进入最终候选。候选只保留：

- 官方 Worker 运行模块集：`worker/shim.mjs`、`index.js`、WebAssembly、必要 snippets 与 `package.json`。
- `wrangler.jsonc`：CitizenChatServer 独立资源、域名、应用标识和授权合同。
- `schema.sql`：TataChatServer 唯一 D1 最终结构。
- `product.json` 与 `SHA256SUMS`：产品来源和候选闭集验真。

装配必须复制 `worker-build` 的完整现代模块布局，禁止只保留 `worker/` 而遗漏 `shim.mjs`
引用的 `index.js`、WebAssembly 或 snippets；官方构建目录中的 `.gitignore` 不得进入候选。

Cloudflare WASM 构建单独关闭 Release strip，保留 `wasm-bindgen` 运行必需的 `externref` 表；
该设置不改变 LinuxARM 产物规则。

GMB 产品源码目录禁止生成 Worker、Rust `target` 或 `build`。D1 生产资源编号、授权公钥、
APNs 私钥和 FCM 服务账户只在发布事务中注入隔离候选，不写入本目录。当前步骤不部署，
也不切换 CitizenServe 聊天数据面。
