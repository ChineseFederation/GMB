# 公民链轻节点服务

本目录保留 CitizenApp 已验证的旧 Dart smoldot 生命周期、创世信任锚、动态 bootnode、同步
数据库信封和健康状态，作为归档差分测试基线。它只认识公民链与 P2P，不认识
广场、聊天、Cloudflare 业务模型或任何应用导航。

`CitizenLightClient` 不使用全局单例。宿主应用可以创建一个进程级实例，并注入公开数据
存储与日志回调；私钥和钱包数据不经过本目录。

`CitizenChainAssets` 只从 `assets/citizenchain` 加载随包 manifest、chainspec 和 `#0`
同步状态。它先核对两个文件的 SHA-256，再核对正式 `chain_id`、`protocol_id`、genesis hash
以及 header 中的 state root；任何不一致都在创建 smoldot 链实例前失败关闭。远端启动清单
只能建议 bootnode，不能替换这组三文件信任闭集。

Android、iOS 与 macOS 正式公共 API 均不导出或调用本目录，也不打包 legacy `libsmoldot`。
`CitizenSdkClient` 通过产品 ABI 调用 Rust Engine/smoldot provider。旧测试显式导入内部路径，
只能作为差分基线，不能被误认为新的产品 API；删除时必须同步更新来源与测试闭集。
