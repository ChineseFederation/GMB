# smoldot light-base 来源基线

本目录以 CitizenApp 当前使用的 `smoldot/pow/light-base` 为已验证来源基线，负责 finalized
database、网络连接、JSON-RPC、runtime、同步、交易池和平台编排。17 个生产来源文件保持
逐字节一致；`src/lib.rs` 是单独登记并固定摘要的 CitizenSDK 适配文件：除 typed storage batch
的准确 block number/hash 外，它还提供 exact-best Runtime nonce 快照，以及从同步状态机
verified finalized 锚沿 parent hash 严格验证的 ancestry batch。原有兼容方法仍返回相同的值
列表，CitizenApp 既有调用行为不变。

CitizenSDK 额外增加 README、来源闭集与能力边界测试。finalized ancestry 不读取 best/recent
缓存；独立 proof-derived cache 有界保存已由父链证明的 hash，并在冲突时失败关闭。recent
cache 的订阅重建同时丢弃旧未 finalized 分支，防止把旧 fork 误提升为 canonical。其余来源
Rust 文件和历史注释保持字节不变。它唯一的本地源码依赖是相邻 `../lib`，不依赖 CitizenApp
路径。

聊天、OpenMLS、TUYU、产品导航和全节点出块不属于该层。
