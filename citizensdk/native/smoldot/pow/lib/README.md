# smoldot 链共识核心来源基线

本目录分批收编 CitizenApp 已验证的 `smoldot/pow/lib`。目前已逐字节导入轻客户端所需的
chain、chain-spec、finality、header、verify、trie、executor、database、json-rpc、
libp2p、network、sync、transactions、util 与 SS58 公钥地址模块，不改上游函数实现、
注释、签名或测试向量。

`Cargo.toml` 和 `src/lib.rs` 已从相同来源建立基线，并只剥离全节点出块、全节点私钥依赖
与模块入口。当前 crate 源码闭包已经形成，并由上层 PoW workspace 的 `Cargo.lock` 固定
依赖，但没有执行编译或测试；只有在用户另行批准并通过验收后才能声明可构建。

`author`、`identity/keystore.rs` 和 `identity/seed_phrase.rs` 明确不在轻客户端产品边界
内。前者属于全节点出块，后两者会形成另一条私钥管理路径；仅保留 JSON-RPC 所需的
`identity::ss58` 公钥地址编解码。CitizenSDK 热钱包只允许通过内部 signer 和后续平台
安全金库管理用户密钥。

libp2p Noise 在内存中处理按连接生成的传输密钥，与钱包密钥完全隔离，不得持久化。
