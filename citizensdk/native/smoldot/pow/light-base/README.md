# smoldot light-base 来源基线

本目录的 18 个来源文件逐字节来自 CitizenApp 当前使用的
`smoldot/pow/light-base`，负责 finalized database、网络连接、JSON-RPC、runtime、同步、
交易池和平台编排。

CitizenSDK 只额外增加 README、来源闭集与能力边界测试；来源 Rust 文件和历史注释保持字节
不变。它唯一的本地源码依赖是相邻 `../lib`，不依赖 CitizenApp 路径。

聊天、OpenMLS、TUYU、产品导航和全节点出块不属于该层。
