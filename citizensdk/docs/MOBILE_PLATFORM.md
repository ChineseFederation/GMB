# CitizenSDK 移动平台实现

## 当前支持边界

当前正式源码与 Release 平台集合只有：

| 平台 | 正式 ABI | 能力 |
|---|---|---|
| Android | `arm64-v8a` | smoldot 轻节点、无根热钱包、硬件金库、sr25519、链上交易 |
| iOS | `arm64` | smoldot 轻节点、无根热钱包、硬件金库、sr25519、链上交易 |

macOS arm64+x86_64 测试动态库只供原生或 Rosetta `flutter_tester` 加载；与 Runner 同架构
的 iOS Simulator 静态库只供 Swift XCTest，二者均不进入 Release。macOS、Linux、Windows
的原生核心可以按同一分层继续
移植，但当前没有正式插件、硬件金库和 Release 资产，不属于已交付平台。

宿主默认使用 `CitizenSdk.mobile()`；它装配同一个 CitizenSDK，不是额外的钱包 SDK。

## 固定产品与通道

所有新硬件信封产品标识固定为 `citizensdk`。Flutter 通道固定为
`citizen/sdk/hardware_secretvault`。宿主不能传入另一个产品名，避免相同 SDK 在不同 App
形成无法审计的密钥分叉。

AAD 结构保持：

```text
GMB
citizensdk
<wallet-index>
<wallet-generation>
<secret-owner>
<account-id>
account_mini_secret
```

硬件 KEK scope 固定为 `citizensdk:<wallet-index>:<wallet-generation>`。`wallet-generation`
与 `secret-owner` 都是 32 位小写十六进制 CSPRNG 身份。通道只接收字节数组；禁止把助记词、
mini-secret 或私钥转成平台字符串。

## Android

- 2048 位 RSA-OAEP KEK 只接受 StrongBox 或 TEE。
- KEK 每次使用必须由硬件强制 `BIOMETRIC_STRONG` 认证。
- 随机 32 字节 AES 密钥以 AES-256-GCM + AAD 加密 child mini-secret，再由 RSA-OAEP 包装。
- 密文信封版本为 v1；硬件别名前缀和命名空间固定为 `citizensdk`。
- 插件只声明 `arm64-v8a`。
- 生产 Kotlin 源码放在 Flutter 插件声明要求的
  `android/src/main/kotlin/org/citizen/sdk/`，JUnit 源码放在镜像路径
  `android/src/test/kotlin/org/citizen/sdk/`。这不是额外实现层，而是
  `pubspec.yaml` 中 `org.citizen.sdk` package 与 `CitizenSdkPlugin` 的官方发现合同；路径各层的
  README 同时记录命名、测试可见性和源码/产物边界，不存在空包装目录。

`BiometricPrompt` 要求 `FragmentActivity`。承载 Flutter 页面的 Activity 必须继承
`FlutterFragmentActivity` 或提供等价能力；普通 `FlutterActivity` 无法完成硬件认证，钱包
操作应失败关闭。

## iOS

- 最低支持版本固定为 iOS 16.0：设备与 Simulator 的 Rust/C 原生对象由
  `ios_deployment_target=16.0` 和显式 `IPHONEOS_DEPLOYMENT_TARGET` 约束，插件 podspec 与宿主也固定
  为 iOS 16.0，不能继承当前 Xcode SDK 的部署版本。
- 私钥生成在 Secure Enclave。
- Keychain 可访问性为 `WhenUnlockedThisDeviceOnly`。
- 访问控制为 `privateKeyUsage + biometryCurrentSet`。
- ECIES `X963SHA256AESGCM` 信封包含 AAD 摘要和明文长度。
- 生物识别集合变化后先前密钥失败关闭。

## 本地数据隔离

| 数据 | 命名空间 | 是否含私钥材料 |
|---|---|---|
| profile/revision/provisioning/cleanup/cleanup queue | `citizensdk.wallet.state.v1` | 否 |
| smoldot finalized database | `citizensdk.smoldot.database.v1` | 否 |
| finalized 流水/pending/cursor | `citizensdk.transactions.state.v1` | 否 |
| 账户硬件密文 | `citizensdk.wallet.secret.<generation>.<owner>.<AccountId>.account_mini_secret` | 不可独立解密的密文 |

SDK 从不读取、导入或删除其它产品的密文和硬件密钥。其它产品采用 CitizenSDK 时必须设计
并单独批准自己的数据切换步骤，不能把其它产品数据读取变成普通钱包读取、导入或删除的隐式
分支。

Preferences 钱包状态的 `cleanup_queue` 是公开的精确补偿计划列表，单项复用
`operation_id/wallet_index/wallet_generation/secret_refs/delete_wallet_key` 字段。标准装配只在
同一 Dart isolate 内串行变更；跨 Flutter engine 使用必须由宿主另外提供强原子仓储与
覆盖整个钱包操作的单写协调。

## 验证记录原则

正式 CI/Release 会在临时 Flutter 宿主中编译 Android/iOS 插件，运行 Android JUnit 与 iOS
Simulator XCTest，并运行 Dart/Flutter、Rust 合同测试。任何历史结果仍不能替代当前准确提交
的流水线；真机硬件门禁结果应在对应发布验收记录中单独留档，不能由模拟器或宿主测试代替。
