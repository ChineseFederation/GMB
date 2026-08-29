# 公民SDK（CitizenSDK）

CitizenSDK 是 GMB 根目录下的独立公民链客户端产品，向宿主应用提供同一套公民链轻节点、
无根热钱包、sr25519 本地签名和链上交易能力。源码唯一目录是
`/Users/rhett/GMB/citizensdk`，Dart 包名为 `citizen_sdk`，产品 ID 为 `citizensdk`。

当前源码已经收编 CitizenApp 使用的公民链 smoldot PoW 轻节点闭包、Dart smoldot 包、
sr25519 signer、链资产与依赖锁，并在产品无关的 Dart/Flutter 层实现轻节点生命周期、
finalized 数据库、多账户热钱包、硬件金库、任意协议载荷签名和
钱包完整可用性核验、账户改名、用户主动的子账户私钥导出、finalized 单/批余额读取、链上
手续费估算，以及 `OnchainTransaction.transfer_with_remark` 交易提交与执行结果核对。
标准移动装配还提供广播前 pending 持久化、逐账户 finalized 流水、重启游标补扫与明确
`System.ExtrinsicSuccess/Failed` 终态收敛。
CitizenApp 现有功能和
依赖保持不变；只有在 SDK 稳定后，才会另行设计 CitizenApp 的切换步骤。

## 当前交付边界

- 正式 CI/Release 候选只声明 Android `arm64-v8a` 与 iOS `arm64`。
- macOS arm64+x86_64 宿主动态库和同 Runner 架构的 iOS Simulator 静态库只用于自动化
  测试，不是正式分发平台或正式 SDK 资产。
- 原生核心和 Dart 分层可继续适配 macOS、Linux、Windows，但这些桌面平台目前没有完成
  插件、安全金库、打包与发布验收，不能宣称已经交付。
- 聊天、广场、OpenMLS、TUYU 账户签名协议、旅行/生活/商家业务均不属于 CitizenSDK。
- CitizenWallet 冷钱包是独立产品，不属于本 SDK 的能力收编范围。

## 安全边界

- sr25519 context 固定为 `substrate`，密码学实现只使用 SDK 内部 `native/signer`。
- 助记词和母种子不持久化；账户 child mini-secret 只保存为用户设备硬件金库密文并在
  本地解锁、签名。
- 私钥导出只返回用户明确选择账户的 child mini-secret；不可擦除的 Dart `String` 必须由
  宿主在风险确认和防截屏界面即时处理，禁止记录、持久化或上传。
- 新硬件金库产品标识固定为 `citizensdk`，宿主不能用产品名创建另一套 SDK 密钥空间。
- 每只钱包使用 CSPRNG 生成的独占 generation，每个账户秘密使用独占 owner；硬件 KEK、
  密文键与 AAD 都绑定这些身份，迟到清理不能命中随后成功的钱包或同 AccountId 的另一代秘密。
- 公开钱包状态在 secret 写入前保存 provisioning，并保存 active cleanup 与 exact
  cleanup queue。默认 Preferences 装配只承诺同 Dart isolate 内的跨实例单写；跨执行引擎
  必须由宿主同时提供强原子仓储和覆盖整个钱包操作的单写协调。
- SDK 不包含远程签名或通用远程 RPC；公民链交易由设备内 smoldot 轻节点通过 P2P 广播。
- 宿主如果注入 `WalletRepository`、`SecureSeedStore` 等底层接口，就进入受信任宿主边界；
  SDK 无法防止恶意宿主实现复制传入的秘密，产品集成必须审查这些注入点。

## 构建与分发

GMB 的唯一顶层 Workflow 路由 `公民SDK · CI · SDK` 与
`公民SDK · Release · SDK`。Release 会复核指定成功 CI 的 workflow、显示标题、产品目标、
成功状态和准确 `source_sha`，不读取、下载或比较 CI 资产；随后从同一源码提交重新执行依赖
检查、测试、原生构建和候选生成。这是独立重建与重新验证，不把不同 Runner 的归档字节
天然相同作为前提。

正式分发只有 GitHub Release 三项资产：`citizensdk.tgz`、
`citizensdk-release.json`、`SHA256SUMS`。CitizenSDK 不设置独立“发布”按钮、不接入公民网
下载，也不发布到 pub.dev。

本机 Console 只允许把 CitizenSDK 生成记录写入
`/Users/rhett/Only/console/target/citizensdk`。本地打包快照由准确的已提交 Git `HEAD` 导出；
工作区中的未提交修改不会被冒充成该提交。中央目录现有三件套属于其生成时的历史提交，
除非重新完成当前提交的统一构建与核验，否则不得称为当前源码候选。

详细说明见 `docs/ARCHITECTURE.md`、`docs/DART_API.md`、`docs/WALLET_MODEL.md`、
`docs/SECURITY.md`、`docs/SOURCE_PROVENANCE.md`、`docs/MOBILE_PLATFORM.md` 与
`docs/NATIVE_PACKAGING.md`。
