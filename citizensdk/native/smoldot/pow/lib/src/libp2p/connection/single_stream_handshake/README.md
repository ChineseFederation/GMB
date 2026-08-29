# single_stream_handshake 测试说明

`tests.rs` 是上游单流 Noise/Yamux 握手测试模块，与父模块
`src/libp2p/connection/single_stream_handshake.rs` 配套。测试使用固定或随机的连接级传输
密钥，不是钱包、公民账户或管理员私钥。

测试源码保持与 CitizenApp 已验证来源逐字节一致；本 README 仅补充安全边界。
