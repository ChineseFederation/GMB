# CitizenSDK 原生核心

本目录承载同一 CitizenSDK 产品的统一原生核心：`contracts` 固定类型化依赖语义，`engine`
负责产品无关的能力、runtime、状态导入与交易执行协调，`signer` 提供 sr25519，`smoldot`
提供公民链 PoW + GRANDPA 轻节点和当前 Dart 绑定所需的原生入口。

固定依赖方向为：

```text
语言绑定 -> 产品级唯一 C ABI -> engine -> contracts <- smoldot / signer / OS vault / stores
```

第 2 步已经建立 `contracts` 与 `engine`，但产品级唯一 C ABI 要到第 3 步才在 `native/ffi`
和根 `include` 建立。现有 `smoldot/ffi` 仍服务当前 Dart 运行路径，不能被表述为新的完整产品
C ABI；当前 Dart 钱包、交易和秘密处理路径也尚未切换到 Rust Engine。

原生轻节点源码闭包、FFI、Dart smoldot 包、来源测试与锁文件已经迁入；当前不存在通过
CitizenApp 或 `shared` 相对路径取得运行时源码的依赖。Android/iOS 平台目录只负责链接、
装载和设备安全能力，不复制链或签名实现。

`engine` 精确使用官方 `subxt-core = 0.43.0` 解码 metadata 与 `System.Events`，不实现网络
连接或任意 RPC；网络验证只能由实现 `VerifiedChainClient` 的 provider 提供。新增 Rust Core
是 CitizenSDK 自有源码闭包，不修改 `smoldot/SOURCE_SHA256.json` 的既有来源语义。

全节点出块、全节点 identity 私钥、聊天、OpenMLS、TUYU 与产品业务被排除。当前正式发布
平台只包含 Android ARM64 与 iOS ARM64；桌面原生核心可继续适配，但不表示桌面 SDK 已交付。

任何编译状态和原生产物都必须写入调用方指定的源码树外目录。本机唯一允许目录是
`/Users/rhett/Only/tataconsole/target/citizensdk`。
