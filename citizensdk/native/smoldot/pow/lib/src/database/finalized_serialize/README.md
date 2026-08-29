# finalized_serialize 子模块说明

`defs.rs` 定义轻节点 finalized database 的序列化结构，与父模块
`src/database/finalized_serialize.rs` 配套使用。该 database 是轻节点可恢复状态的紧凑
序列化数据，不保存用户助记词、私钥或钱包账户。

`defs.rs` 保持与 CitizenApp 已验证来源逐字节一致；本 README 仅补充 CitizenSDK 边界。
