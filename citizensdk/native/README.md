# CitizenSDK 原生核心

本目录承载同一 CitizenSDK 产品的统一原生核心：`signer` 提供 sr25519，`smoldot` 提供
公民链 PoW + GRANDPA 轻节点、Dart 绑定和稳定 C ABI。

原生轻节点源码闭包、FFI、Dart smoldot 包、来源测试与锁文件已经迁入；当前不存在通过
CitizenApp 或 `shared` 相对路径取得运行时源码的依赖。Android/iOS 平台目录只负责链接、
装载和设备安全能力，不复制链或签名实现。

全节点出块、全节点 identity 私钥、聊天、OpenMLS、TUYU 与产品业务被排除。当前正式发布
平台只包含 Android ARM64 与 iOS ARM64；桌面原生核心可继续适配，但不表示桌面 SDK 已交付。

任何编译状态和原生产物都必须写入调用方指定的源码树外目录。本机唯一允许目录是
`/Users/rhett/Only/console/target/citizensdk`。
