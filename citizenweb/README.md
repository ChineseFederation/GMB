# CitizenWeb

CitizenWeb 是公民官网的 React、TypeScript 与 Vite 静态站点产品。正式发布由本机
CitizenConsole 从 GitHub 正式 Release 读取已构建产物，并通过 Cloudflare Pages
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
- Release 的 `release-manifest.json` 与 `SHA256SUMS` 是产物完整性真源，发布器必须逐项
  复核后才能上传。
- Cloudflare Pages 在没有顶层 `404.html` 时原生提供 SPA 路由回退。禁止增加
  `/* /index.html 200` 的 `_redirects`，因为该规则会优先改写真实 JS、CSS 和图片请求。
- CitizenConsole 使用 Cloudflare 官方 Direct Upload 的 asset store、deployment、状态轮询、
  生产切换和回滚接口；发布后必须确认本次 deployment 已成为最新生产 deployment，并按
  Release SHA-256 验收所有公开文件。
