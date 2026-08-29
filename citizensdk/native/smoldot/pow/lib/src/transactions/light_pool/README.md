# 轻交易池测试说明

`tests.rs` 是上游轻交易池状态机测试模块，与父模块
`src/transactions/light_pool.rs` 配套。轻交易池接收已经编码的 extrinsic，跟踪验证、广播、
区块收录和回滚状态，不读取或保存钱包私钥。

测试源码保持与 CitizenApp 已验证来源逐字节一致；本 README 仅补充安全边界。
