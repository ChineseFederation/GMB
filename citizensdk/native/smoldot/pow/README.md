# 公民链 smoldot PoW 快照

该目录逐步收编 CitizenApp 当前已经验证的 smoldot PoW 轻节点快照。导入采用“先逐字节
复制、记录哈希，再在 CitizenSDK 独立演进”的方式，禁止在 Release 或 CI 中回指
CitizenApp 源码。

当前已有 `light-base` 编排层，以及 `lib` 中的 chain、chain-spec、finality、header、
verify、trie、executor、database、json-rpc、libp2p、network、sync 与 transactions
源码闭包。本目录已成为只包含 `lib` 和 `light-base` 的内部 Cargo workspace；没有复制
`full-node` 或 `wasm-node`，并由本目录的 `Cargo.lock` 固定依赖。在用户批准编译验收前
不得发布。

轻客户端 SDK 不收编全节点 `author`、`identity` keystore 或 seed phrase 解析。保留的
`identity::ss58` 只处理公钥地址；用户私钥只允许由 CitizenSDK signer 与平台安全金库
管理。

libp2p Noise 的连接级密钥只用于传输握手，由平台随机源按连接生成并在内存中零化；它
不是钱包或管理员身份密钥，不得持久化。
