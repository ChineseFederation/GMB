# smoldot light-base 来源基线

本目录逐字节来自 CitizenApp 内已经验证的 `smoldot/pow/light-base`。它负责轻节点客户端
编排，包括数据库状态、网络连接、JSON-RPC、runtime、同步、交易池和平台抽象。

所有上游 Rust 文件在本阶段保持字节不变。个别注释仍使用历史名称 CitizenApp，记录的是
来源版本当时的集成环境，不构成对 CitizenApp 目录的源码依赖；实际依赖只有
`Cargo.toml` 中的相邻 `../lib`。该依赖目前已补齐链头、终局性、状态 trie、runtime、
轻数据库、JSON-RPC、libp2p、网络、同步与交易池源码，并与本 crate 一起纳入 PoW 内部
workspace；依赖由 PoW workspace 的 `Cargo.lock` 固定，但尚未执行编译验收。

聊天、OpenMLS、TUYU 协议和产品导航不属于该层。后续必须在用户明确批准后，通过 PoW
workspace 和 FFI 契约验证其链同步及交易行为。
