# CitizenSDK smoldot 原生边界

该目录承载 CitizenSDK 的公民链轻节点原生核心和公共 C ABI。初始实现来自 CitizenApp
已经验证的 smoldot PoW 轻节点，但只保留链同步、RPC、交易提交和 sr25519 所需能力。

当前已经导入并净化 `ffi` 外层，逐字节迁入 `pow/light-base` 编排层，并在 `pow/lib`
完成 chain、chain-spec、finality、header、verify、trie、executor、database、json-rpc、
libp2p、network、sync 与 transactions 源码闭包。PoW 内部 workspace 已建立，但尚未获准
生成锁文件或执行编译，因此不得单独发布或宣称构建可用。

对应 Dart FFI 封装已迁入 `lib/src/smoldot`，由 `CitizenLightClient` 管理生命周期。
动态库名称继续使用官方依赖名 `smoldot`；Dart 层不再搜索 CitizenApp 的开发目录。

Android/iOS Flutter 插件不在源码树保存原生产物。公民控制台分别通过
`CONSOLE_NATIVE_ANDROID_DIR` 和 `CONSOLE_NATIVE_IOS_DIR` 注入已构建的 `smoldot` 库；
iOS 同时读取产物实抽的 `exported_symbols.txt`，以 `-force_load` 和逐符号 `-u` 保证
Release `dead_strip` 不移除 Dart FFI 入口。详见 `docs/NATIVE_PACKAGING.md`。

聊天、OpenMLS、CID 账户数据加密、TUYU 协议及任何具体产品业务不属于本目录。
