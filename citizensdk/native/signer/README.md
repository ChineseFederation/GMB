# CitizenSDK sr25519 signer

本 crate 是 CitizenSDK 内部唯一 sr25519 实现。`Cargo.toml` 与 `src/lib.rs` 的收编基线和
`shared/citizen-signer` 逐字节一致，保留 Substrate 硬派生、`substrate` context、签名、
验签、错误码、panic 捕获与内存清理契约。

它不负责助记词 UI、钱包公开仓储、硬件金库、交易编码、TUYU 或其它业务账户。CitizenSDK
运行时只依赖本目录；`shared/citizen-signer` 继续服务尚未切换 SDK 的 CitizenApp 与
CitizenWallet。同步与回补策略见 `../../docs/SOURCE_PROVENANCE.md`。

Release 把本 crate 的 `Cargo.toml`、两份 README、`src/lib.rs` 和两份 `tests/*.rs` 固定为
完整 6 文件闭集并逐文件校验 SHA-256。新增 `build.rs`、`src/bin` 或任何未登记文件都会改变
Cargo 行为或来源身份，必须在进入 CI/Release 前失败关闭。
