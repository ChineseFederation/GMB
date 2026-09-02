# 密码学与账户编码

本目录保留从 CitizenApp 复制的 Dart/FFI 差分基线：公民链账户编码、Substrate BIP-39
派生和原生 sr25519 调用。真正的密码学实现位于 `native/signer`，Dart 不实现第二套
sr25519。

助记词、母种子和 child mini-secret 只允许在受控作用域中短暂存在。这里的
`WalletService`/`SecureSeedStore` 仅用于归档差分测试；正式钱包业务必须经 Rust Core 的
typed stores、`SecretVault` 与 `ChainSigner`，不得把原始私钥材料暴露给产品代码。

本目录不再由 `lib/citizen_sdk.dart` 导出，Android、iOS 与 macOS 正式绑定均不可到达。
创建、恢复、派生和签名全部经稳定 CitizenSDK Core ABI 在 Rust 中完成；该旧实现只作为归档
差分测试基线。删除或更新它必须同步审查来源闭集、差分测试与发布门禁，不能静默处理。
