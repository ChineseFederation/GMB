# CitizenSDK smoldot 原生边界

本目录包含 CitizenSDK 的完整公民链轻节点闭包：

- `provider/`：收口 exact-block、交易观察与状态导入导出的正式 `VerifiedChainClient`；
- `ffi/`：仅供归档 Dart/smoldot macOS `arm64` 差分测试的 legacy `smoldot_*` 与
  `citizen_sr25519_*` C ABI；
- `pow/lib`：PoW + GRANDPA 共识、状态、runtime、网络、同步、交易和验证原语；
- `pow/light-base`：轻节点数据库、网络、JSON-RPC、runtime、同步和交易池编排；
- `include/`：上述 legacy 轻节点 C 头文件。

产品级公共 C 头位于仓库根 `include/`，只公开 `citizensdk_*`；它不包含 legacy
`smoldot.h`。provider 内部允许的固定 JSON-RPC 只是对当前 smoldot typed API 缺口的适配，
不会作为任意 `rpc(method, params)` 向语言绑定或产品公开。

smoldot Dart FFI 绑定已经并入根 `citizen_sdk` 包的 `lib/src/smoldot`，不再形成独立
`path` 依赖，但已经从根公开入口移除，只作为归档差分测试基线。Android 使用产品
`libcitizensdk.so` 与 JNI bridge；Apple 使用同一产品 Core 的 `CitizenSDK.xcframework`。任何
正式绑定和候选都不运行 legacy `libsmoldot`。源码树不保存 `.so`、`.a` 或 Cargo target。

原 smoldot Dart 包的历史说明、包清单和许可证保存在 `docs/smoldot-dart`；迁入的归档绑定与
差分测试仍由逐文件哈希保护。产品 ABI 投影覆盖 Android、iOS 与 macOS；当前 Android ABI
为 `arm64-v8a`，Apple machine slice 架构值为 `arm64`。legacy 宿主 dylib 只允许作为源码树外 macOS `arm64`
差分测试库；其 build-local `LC_ID_DYLIB` 不具分发身份，绝不进入候选。应使用根 README
和 `docs/NATIVE_PACKAGING.md` 的外部目录流程。

聊天、OpenMLS、账户数据加密、TUYU 与产品业务不属于本目录。全节点 `author` 和 identity
私钥入口也被排除；保留的 SS58 代码只处理公钥地址。
