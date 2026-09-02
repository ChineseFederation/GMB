# CitizenSDK sr25519 signer

本 crate 是 CitizenSDK 内部唯一 sr25519 实现。`src/sr25519.rs` 集中保存 schnorrkel
算法口径；`src/lib.rs` 的 legacy 四原语和 `src/chain_signer.rs` 的真实
`citizen_sdk_contracts::ChainSigner` 适配器只调用该实现。它保留已验证的 Substrate
硬派生、`ExpansionMode::Ed25519`、`substrate` context、签名、验签、FFI 错误码、
panic 捕获与内存清理契约。

它不负责助记词 UI、钱包公开仓储、硬件金库、交易编码、TUYU 或其它业务账户。CitizenSDK
运行时只依赖本目录；`shared/citizen-signer` 继续服务尚未切换 SDK 的 CitizenApp 与
CitizenWallet。SDK 不反向依赖 shared 源码；shared 只说明最初行为来源，当前重构文件不再
声明逐字节相同。既有结果通过 frozen vector 与 legacy 双向验签差分守住。同步与回补策略见
`../../docs/SOURCE_PROVENANCE.md`。

秘密边界：`SecretBuffer` 只在同步 Rust 闭包内借用，派生结果由 `Zeroizing` 清除，
不会通过公共 C ABI、Dart、Swift 或 Kotlin 返回。系统 Keystore/StrongBox 等只实现
`SecretVault`，不能被描述成 sr25519 signer。

Android 产品候选只带 `libcitizensdk.so` 与薄 JNI bridge，不打包 legacy `libsmoldot` 或四个
`citizen_sr25519_*` 外部符号。Apple `CitizenSDK.xcframework` 同样只允许根
`include/citizensdk.h` 的 70 个产品符号，并显式拒绝这四个低层入口。它们只可存在于源码树外
的 ARM64 legacy 差分测试宿主库；虽调用本 crate 的同一算法实现，但不属于任何正式候选。

Release 必须把本 crate 的 `Cargo.toml`、两份 README、三个 `src/*.rs` 和四份
`tests/*.rs` 固定为完整 10 文件闭集并逐文件校验 SHA-256。新增 `build.rs`、`src/bin`
或任何未登记文件都会改变 Cargo 行为或来源身份，必须在进入 CI/Release 前失败关闭。
