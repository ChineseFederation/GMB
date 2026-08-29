# 公民SDK（CitizenSDK）

CitizenSDK 是公民链面向应用软件的独立 SDK 产品。最终交付范围包括公民链轻节点、
sr25519 本地签名、热钱包生命周期、链上交易，以及 iOS、Android、macOS、Linux、
Windows 的平台集成。

当前仓库已经建立独立产品边界、导入已验证的 sr25519 实现、完成 smoldot FFI 外层净化，
逐字节迁入原生轻节点源码闭包，并建立 Dart/Flutter 公共门面、随包创世锚、轻节点生命周期、
无根热钱包、多账户、任意协议载荷签名和公民链转账服务。Android/iOS 已迁入稳定硬件金库
安全语义、移动持久化适配和中央原生产物注入声明；macOS、Linux、Windows 尚无经批准的
硬件金库实现。

GMB 现有唯一顶层 Workflow 已登记 `公民SDK · CI · SDK` 与
`公民SDK · Release · SDK` 两条分组流水线。二者复用全仓依赖合同、固定工具链、成功 CI
来源复核和统一 GitHub Release 事务；当前正式候选只包含 Android ARM64 与 iOS ARM64。
本步骤没有获准实际运行测试、编译、CI 或 Release，因此这些流程仍是待真实执行验收的源码，
不能据此宣称 SDK 已经生产可用。

## 固定边界

- SDK 内包含公民链能力、钱包能力和产品无关的 sr25519 本地签名能力。
- 聊天、广场、OpenMLS、TUYU 账户签名协议及具体产品业务不属于 CitizenSDK。
- 私钥、助记词和 child mini-secret 只能保存在用户设备安全存储中并在本地签名。
- 新硬件金库产品标识固定为 `citizensdk`，宿主产品不得覆盖。
- 现有 CitizenApp 在 SDK 稳定并完成迁移前保持不变。
- 构建产物必须由 Console 写入中央产物目录，禁止在本目录保存 `target/` 或发布包。
- 公民网下载发布不属于本步骤；Release 仅固化三项正式资产，不直接更新下载指针。

公共接口、钱包模型、架构、来源和安全约束分别见 `docs/DART_API.md`、
`docs/WALLET_MODEL.md`、`docs/ARCHITECTURE.md`、`docs/SOURCE_PROVENANCE.md` 与
`docs/SECURITY.md`。移动平台与原生产物接入另见 `docs/MOBILE_PLATFORM.md` 和
`docs/NATIVE_PACKAGING.md`。
