# CitizenSDK 技术架构

## 产品原则

CitizenSDK 是一个产品、一个版本和一条发布链。内部可以按技术职责分层，但不得拆成
彼此独立演进的“轻节点 SDK”“钱包 SDK”或“签名 SDK”。Flutter/Dart 接口和原生 C ABI
也只是同一产品的不同接入面。

## 依赖方向

规划中的依赖只能从上向下：

1. 产品应用依赖 CitizenSDK 公共接口。
2. 公共接口依赖轻节点、钱包和交易服务。
3. 钱包与交易服务依赖安全金库抽象、sr25519 和轻节点 RPC。
4. 平台实现依赖系统安全能力和统一原生核心。
5. 原生核心依赖收编的 smoldot 快照、`schnorrkel` 等官方实现。

原生核心、钱包或交易代码不得反向依赖 CitizenApp、TuyuLove、TuyuLife、TuyuBooking、
聊天、广场、TUYU 协议或具体产品导航。

## 当前目录与后续平台目录

```text
citizensdk/
├── lib/                 已建立的 Flutter/Dart 公共接口及业务无关实现
├── native/              轻节点、sr25519 和稳定 C ABI
├── android/             已建立的 Android 插件、硬件金库和测试源码
├── ios/                 已建立的 iOS 插件、硬件金库和测试源码
├── assets/              已固定的公民链 chain spec 与 #0 light sync state
├── scripts/             外部产物目录构建入口与确定性 Release 打包器
├── docs/                独立技术文档
└── test/                已建立的 Dart/Flutter 测试源码
```

`macos/`、`linux/`、`windows/` 与 Console 工具目录只有在相应步骤单独批准后才能新增；
当前目录树不伪造这些平台的安全能力。

## 构建与 Release 依赖方向

CitizenSDK 没有第二套 CI/Release 系统。GMB 顶层唯一注册入口
`.github/workflows/gmb-repository.yml` 路由到两份可审查的分组真源：

1. `.github/workflows/citizensdk/ci-sdk.yml` 检查锁定依赖、Dart/Flutter、三个 Rust
   workspace、Android/iOS 原生核心和 Flutter 测试，再生成 CI 候选。
2. `.github/workflows/citizensdk/release-sdk.yml` 用 `ci_run_id` 复核同产品、同目标、
   同 workflow 的成功 CI 与准确 `source_sha`，重建候选后走统一原子 Release 事务。
3. `.github/scripts/citizensdk/*.mjs` 按 GMB 既有规则内嵌逐字一致的公共依赖实现；
   SDK 候选打包实现也内嵌在本产品两条动作入口中，防止 Release 工具跨产品导入。
4. `citizensdk/scripts/build-native.sh` 和 `release.mjs` 只写调用方显式提供的外部目录。
   GitHub 使用 `$RUNNER_TEMP/citizensdk`，Console 本机以后只允许使用
   `/Users/rhett/Only/console/target/citizensdk`。

CI 与 Release 是同一 `citizensdk` 产品、同一个 `sdk` 目标和同一条语义版本线，Tag 前缀
固定为 `citizensdk-v`。宿主 macOS 动态库只供 `flutter_tester` 使用，不进入 Release
平台声明，也不表示已经提供 macOS SDK 适配。

当前已创建 `native/signer`、净化后的 `native/smoldot/ffi`，逐字节迁入
`native/smoldot/pow/light-base`，并在 `native/smoldot/pow/lib` 完成 chain、chain-spec、
finality、header、verify、trie、executor、database、json-rpc、libp2p、network、sync 与
transactions 原生源码闭包。`native/smoldot/pow` 是仅含 `lib` 和 `light-base` 的内部 Cargo
workspace；根 signer workspace、FFI workspace 和 PoW workspace 各自保存固定 `Cargo.lock`，
Dart/Flutter 依赖保存 `pubspec.lock`。锁文件只固定依赖，尚未执行编译或测试验收。

Dart 层使用 `package:citizen_sdk/citizen_sdk.dart` 作为唯一稳定入口：

1. `CitizenSdk` 组合轻节点、钱包、转账和验签。
2. `CitizenLightClient` 管理 smoldot、随包创世锚、bootnode 和 finalized database。
3. `WalletService` 只依赖 `WalletRepository`、`SecureSeedStore` 与原生 signer。
4. `ChainRpc`、`SignedExtrinsicBuilder`、`TransferService` 只依赖轻节点和签名回调。
5. `lib/src/platform` 把 Android/iOS 硬件金库、公开钱包状态与 finalized database
   装配成 `CitizenSdk.mobile()`，不承载任何宿主业务。

smoldot Dart 绑定保留在 `lib/src/smoldot` 内部，不作为第二个可独立版本化的软件包。
现有 CitizenApp 的全局单例、Isar schema、日志、导航和服务端签名交易中继均未迁入。

移动端三类数据严格隔离：`citizensdk.wallet.state.v1` 只保存公开账户事实与清理计划，
`citizensdk.smoldot.database.v1` 只保存公开链同步数据库，硬件密文写入
`citizensdk.wallet.secret.*`。新硬件信封的产品标识恒为 `citizensdk`。

根 `Cargo.toml`、PoW workspace 和 FFI workspace 是同一 CitizenSDK 产品内的构建边界，
不是三个独立 SDK。保留 FFI 独立边界，是为了让其 `panic = "unwind"` 安全策略在最终链接
时覆盖依赖，确保 signer 的 `catch_unwind` 能把 panic 转为错误码。

`pow/lib` 的 `author` 和全节点 identity 私钥管理不属于轻客户端 SDK：出块逻辑不得进入
移动轻节点，全节点 keystore 和 seed phrase 解析也不得成为热钱包之外的第二条私钥路径。
仅保留 JSON-RPC 所需的 `identity::ss58` 公钥地址编解码；用户钱包统一依赖
`native/signer` 与后续平台安全金库。

SDK 从 `/chain/citizensdk/bootstrap` 读取只含链身份、轻节点、bootnode 和安全边界的启动清单，
wire schema 固定为 `citizensdk.chain.bootstrap`。现有宿主产品 bootstrap、广场、聊天、媒体和
交易中继配置不进入 SDK 清单；服务端只复用链身份数据，不形成第二条链状态真源。

libp2p Noise 会使用连接级临时传输密钥。当前稳定实现为每条连接重新生成随机密钥并用
`Zeroizing` 清理；它不是公民账户、钱包、TUYU 账户或商家管理员身份，不得持久化到钱包
数据库或平台金库。

## SDK 外部边界

- TUYU v1 继续由途遇账户体系实现；途遇客户端可以调用 SDK 的本地签名能力。
- 广场和聊天继续由各产品及其服务边界实现。
- CitizenWallet 冷钱包是独立产品，不迁入本 SDK。
- CitizenApp 在 SDK 完成稳定验收前不改代码、不改依赖。
