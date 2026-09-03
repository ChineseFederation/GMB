# CitizenWeb

CitizenWeb 是公民官网的 React、TypeScript 与 Vite 静态站点产品。正式发布由本机
TataConsole 从 GitHub 正式 Release 读取已构建产物，并通过 Cloudflare Pages
Direct Upload API 发布；GitHub 只执行 CI 和 Release，不执行官网发布。

## 本地命令

```bash
npm run dev
npm run build
npm run lint
npm test
```

## 发布契约

- 正式产物位于 `dist/`，必须包含 `index.html`、内容哈希静态资源和
  `citizenweb-release.json`。
- Release 的 `release-manifest.json` 与公开版本标记 `dist/citizenweb-release.json` 必须使用
  `delivery_channel: "web"` 声明 Web 交付渠道；Web 不是宿主操作系统平台，两个正式制品均
  禁止旧 `platform`、新旧字段双写或额外身份字段。
- `release-manifest.json` 与 `SHA256SUMS` 是产物完整性真源，发布器必须逐项复核，并确认公开
  版本标记与 manifest 的产品、渠道、版本、Git SHA 和静态资源摘要完全一致后才能上传。
- Cloudflare Pages 在没有顶层 `404.html` 时原生提供 SPA 路由回退。禁止增加
  `/* /index.html 200` 的 `_redirects`，因为该规则会优先改写真实 JS、CSS 和图片请求。
- TataConsole 使用 Cloudflare 官方 Direct Upload 的 asset store、deployment、状态轮询、
  生产切换和回滚接口；发布后必须确认本次 deployment 已成为最新生产 deployment，并按
  Release SHA-256 验收所有公开文件。

QR_V1、控制台 action、恢复状态与既有发布目标键中的 `platform=web` 属于另一项已签名或持久化
wire 合同。它们必须在 CitizenWeb、TuyuWeb、路由、状态模型和签名端同时就绪后原子迁移，不能
在本 Release 制品字段迁移中局部改名或双写。
