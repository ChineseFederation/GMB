# CitizenSDK smoldot 原生边界

本目录包含 CitizenSDK 的完整公民链轻节点闭包：

- `dart/`：根 `citizen_sdk` path dependency 使用的独立 smoldot Dart 包；
- `ffi/`：`smoldot_*` 与 `citizen_sr25519_*` 的 C ABI；
- `pow/lib`：PoW + GRANDPA 共识、状态、runtime、网络、同步、交易和验证原语；
- `pow/light-base`：轻节点数据库、网络、JSON-RPC、runtime、同步和交易池编排；
- `include/`：公共 C 头文件。

当前 Dart 来源路径是 `native/smoldot/dart`，不是旧的 `lib/src/smoldot`。动态库继续使用
官方依赖名称 `smoldot`。Android/iOS 从 Console 或 Runner 的外部原生产物目录注入库，源码
树不保存 `.so`、`.a` 或 Cargo target。

`dart/` 内的 24 个来源文件按哈希冻结，因此其中 CitizenApp 路径、五平台说明与源码树内
`target` 命令只是来源历史文本，不是 CitizenSDK 当前支持矩阵或构建指引。当前正式交付只含
Android ARM64 与 iOS ARM64；arm64+x86_64 macOS 宿主库和与 Runner 同架构的 iOS Simulator
库只用于测试，也必须写入源码树外。应使用根 README 和 `docs/NATIVE_PACKAGING.md` 的外部
目录流程。

聊天、OpenMLS、账户数据加密、TUYU 与产品业务不属于本目录。全节点 `author` 和 identity
私钥入口也被排除；保留的 SS58 代码只处理公钥地址。
