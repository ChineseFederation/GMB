# 密码学与账户编码

本目录仅提供产品无关的公民链账户编码、Substrate BIP-39 派生和原生 sr25519
调用。真正的密码学实现位于 `native/signer`，Dart 不实现第二套 sr25519。

助记词、母种子和 child mini-secret 只允许在受控作用域中短暂存在；钱包业务必须经
`WalletService` 和 `SecureSeedStore`，不得把原始私钥材料暴露给产品代码。
