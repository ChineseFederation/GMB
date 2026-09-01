# CitizenSDK smoldot 原生边界

本目录包含 CitizenSDK 的完整公民链轻节点闭包：

- `ffi/`：`smoldot_*` 与 `citizen_sr25519_*` 的 C ABI；
- `pow/lib`：PoW + GRANDPA 共识、状态、runtime、网络、同步、交易和验证原语；
- `pow/light-base`：轻节点数据库、网络、JSON-RPC、runtime、同步和交易池编排；
- `include/`：公共 C 头文件。

smoldot Dart FFI 绑定已经并入根 `citizen_sdk` 包的 `lib/src/smoldot`，不再形成独立
`path` 依赖。动态库继续使用官方依赖名称 `smoldot`。Android/iOS 从 TataConsole 或
Runner 的外部原生产物目录注入库，源码树不保存 `.so`、`.a` 或 Cargo target。

原 smoldot Dart 包的历史说明、包清单和许可证保存在 `docs/smoldot-dart`；迁移后的生产
绑定和测试仍由逐文件哈希保护。当前正式交付只含 Android ARM64 与 iOS ARM64；
arm64+x86_64 macOS 宿主库和与 Runner 同架构的 iOS Simulator 库只用于测试，也必须写入
源码树外。应使用根 README 和 `docs/NATIVE_PACKAGING.md` 的外部目录流程。

聊天、OpenMLS、账户数据加密、TUYU 与产品业务不属于本目录。全节点 `author` 和 identity
私钥入口也被排除；保留的 SS58 代码只处理公钥地址。
