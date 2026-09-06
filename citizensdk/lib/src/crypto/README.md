# 公开账户编码

本目录唯一实现是 `account_codec.dart`，负责公开 AccountId 与 CitizenChain SS58 的
校验、规范化和展示投影；正式 Flutter codec 使用它，不接触助记词或私钥。

钱包输入、BIP39 派生和生命周期只有 `native/engine` 一处实现；sr25519 只调用
`native/signer`。Dart 不实现签名器、秘密存储或第二套钱包。账户编码测试与 Rust 派生
直接消费 `test/wallet` 的同一冻结向量，不复制测试金标。
