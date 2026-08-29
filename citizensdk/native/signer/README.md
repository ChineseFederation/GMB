# CitizenSDK sr25519 signer

本 crate 是 CitizenSDK 内部唯一 sr25519 密码学实现，初始源码逐字节来自
`shared/citizen-signer`。它只提供硬派生、公钥计算、签名和验签原语，不负责助记词解析、
钱包数据库、硬件金库、交易编码或产品账户体系。

`src/lib.rs` 暂时保留来源版本的历史注释，以确保首个基线可以逐字节核验。SDK 的权威来源
和过渡策略以 `../../docs/SOURCE_PROVENANCE.md` 为准；任何行为修改必须同时更新向量测试、
安全文档和变更记录。
