# SS58 公钥地址边界

本目录只包含逐字节复制的 `ss58.rs`，用于公钥地址编码、解码、网络前缀和校验和验证。
保留 `identity::ss58` 路径是为了让上游 JSON-RPC 方法源码保持字节不变，并不建立新的
账户体系或钱包实现。

全节点使用的 `keystore.rs` 与 `seed_phrase.rs` 明确禁止进入 CitizenSDK。助记词、私钥、
派生和签名统一由 `native/signer`、钱包层与平台安全金库负责。
