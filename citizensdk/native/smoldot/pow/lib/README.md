# smoldot 链共识核心来源基线

本目录包含轻客户端所需的 chain、chain-spec、finality、header、verify、trie、executor、
database、JSON-RPC、libp2p、network、sync、transactions、util、SS58、公开夹具和上游测试。

共享来源文件保持 CitizenApp 字节；Cargo/crate/identity 入口仅做轻客户端边界适配。明确不
复制 `author` 六个全节点出块文件与 `identity/keystore.rs`、
`identity/seed_phrase.rs` 两个私钥入口。精确清单见
`../../../../docs/SOURCE_PROVENANCE.md`。

`database/full_sqlite` 按来源和 feature 保留，不是钱包数据库；移动轻节点使用 finalized
database 序列化。Noise 连接密钥与钱包密钥完全隔离并只在内存使用。
