# GMB

GMB 是公民链、公民移动端、公民服务端、公民钱包和官网的开源产品仓库，公开契约、测试和 CI 均可独立运行，
不依赖私人运维工具或 AI 编程系统。

快速入口：

- 白皮书唯一真源：[`citizenweb/src/whitepaper.md`](citizenweb/src/whitepaper.md)
- 公民宪法唯一真源：链上立法院模块 [`citizenchain/runtime/public/legislation-yuan/`](citizenchain/runtime/public/legislation-yuan/)（`law_id=0`、`tier=宪法`，创世注入 + 立法投票修订；展示端从链上结构化法律重建）
- 统一数据字典：[`shared/data-dictionary.json`](shared/data-dictionary.json)
- 统一二维码协议：[`shared/qr-protocol/`](shared/qr-protocol/)
- 产品与发布边界：[本文件“产品与发布边界”](#产品与发布边界)
- GitHub Actions：[`gmb-repository.yml`](.github/workflows/gmb-repository.yml) 是 GitHub 唯一注册入口；
  22 条产品 CI/Release 仍按产品保存在 `.github/workflows/<product>/`，由该入口按准确路径路由，
  不移动分组文件，也不生成顶层镜像文件。统一仓库门禁同时检查文档、残留、安全边界和新增
  代码的中文注释；单个代码文件新增不少于 12 行时，中文注释也必须出现在本次新增内容中。

## 产品与发布边界

产品目录：

- `citizenchain`：公民链 Node 与 Runtime。
- `citizenapp`：公民 iOS、Android 移动端，不包含服务端实现。
- `citizenserve`：独立部署到 Cloudflare 的公民服务端。
- `citizenwallet`：公民钱包 iOS、Android 离线冷钱包。
- `citizenweb`：公民网 Web 前端，不包含公民服务端。

生产发布授权中的 `platform` 表示产品端，不表示部署供应商：公民网唯一使用
`citizenweb/web`，公民服务端唯一使用 `citizenserve/cloudflare`。Cloudflare Pages 是
公民网的部署实现，不得改写公民网的 `web` 产品端身份。

每个产品、端和动作独立管理。CitizenServe 的 `cloudflare` 端分别使用独立的 CI、Release
逻辑流水线、记录和产物，不与 CitizenApp 或 CitizenWeb 合并计算；生产 Publish 只由本机
CitizenConsole 执行，不属于 GitHub Workflow。

产品目录只保留代码实现、公开配置、测试、脚本与资源文件；私人运维源码、长期记忆、任务卡、
证书和机密不属于本仓库。
