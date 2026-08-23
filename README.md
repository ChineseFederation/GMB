# GMB

GMB 是公民链、公民移动端、公民服务端、公民钱包和官网的开源产品仓库，公开契约、测试和 CI 均可独立运行，
不依赖私人运维工具或 AI 编程系统。

快速入口：

- 白皮书唯一真源：[`citizenweb/src/whitepaper.md`](citizenweb/src/whitepaper.md)
- 公民宪法唯一真源：链上立法院模块 [`citizenchain/runtime/public/legislation-yuan/`](citizenchain/runtime/public/legislation-yuan/)（`law_id=0`、`tier=宪法`，创世注入 + 立法投票修订；展示端从链上结构化法律重建）
- 统一数据字典：[`shared/data-dictionary.json`](shared/data-dictionary.json)
- 统一二维码协议：[`shared/qr-protocol/`](shared/qr-protocol/)
- 产品与发布边界：[本文件“产品与发布边界”](#产品与发布边界)
- GitHub Actions：[`gmb-repository.yml`](.github/workflows/gmb-repository.yml)

## 产品与发布边界

产品目录：

- `citizenchain`：公民链 Node 与 Runtime。
- `citizenapp`：公民 iOS、Android 移动端，不包含服务端实现。
- `citizenserve`：独立部署到 Cloudflare 的公民服务端。
- `citizenwallet`：公民钱包 iOS、Android 离线冷钱包。
- `citizenweb`：公民网 Web 前端，不包含公民服务端。

每个产品、端和动作独立管理。CitizenServe 的 `cloudflare` 端分别使用独立的 CI、Release、Publish workflow、记录和产物，不与 CitizenApp 或 CitizenWeb 合并计算。

产品目录只保留代码实现、公开配置、测试、脚本与资源文件；私人运维源码、长期记忆、任务卡、
证书和机密不属于本仓库。
