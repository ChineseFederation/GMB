# CitizenSDK 移动平台实现

## 支持边界

本阶段只建立 Android 和 iOS 生产安全实现源码。两端均包含公民链轻节点原生产物的 Flutter
打包入口、无根热钱包硬件金库和公开状态持久化适配。macOS、Linux、Windows 没有硬件
金库实现，不能用普通文件或软件密钥冒充支持。

宿主统一使用 `CitizenSdk.mobile()`。这只是装配同一个 CitizenSDK，不是额外的钱包 SDK：

- `CitizenLightClient` 运行并验证公民链轻节点；
- `WalletService` 管理无根热钱包、多账户和本地 sr25519 签名；
- `TransferService` 构造、签名和提交公民链交易；
- 平台层只实现硬件金库与本地公开数据存储。

## 固定产品与通道

所有新硬件信封的产品标识固定为 `citizensdk`。Dart 与原生插件通道固定为
`citizen/sdk/hardware_secretvault`。宿主应用不能传入任何产品名，避免同一个 SDK 在不同
宿主中形成不可迁移的密钥分叉。

AAD 保留稳定格式：

```text
GMB\n<product>\n<wallet-index>\n<account-id>\naccount_mini_secret
```

其中新写入的 `<product>` 恒为 `citizensdk`。通道只接收 `Uint8List`/原生字节缓冲，禁止
把助记词、mini-secret 或私钥转为平台字符串。

## Android

Android 实现固定以下硬件安全语义：

- 2048 位 RSA-OAEP KEK 只接受 StrongBox 或 TEE；
- KEK 由硬件强制每次 `BIOMETRIC_STRONG` 认证；
- 随机 32 字节 AES 密钥使用 AES-256-GCM 与 AAD 加密账户 child mini-secret；
- AES 密钥由 RSA-OAEP 包装，密文信封版本继续为 v1；
- Android 仅声明 `arm64-v8a`，其它 ABI 不进入发布包。

`BiometricPrompt` 需要 `FragmentActivity`。Android 宿主必须让 Flutter 页面 Activity 继承
`FlutterFragmentActivity`（或提供等价的 `FragmentActivity`）；普通 `FlutterActivity`
不能发起本 SDK 的硬件解锁，钱包操作会失败关闭。

## iOS

iOS 实现固定以下硬件安全语义：

- 私钥必须生成在 Secure Enclave；
- Keychain 可访问性为 `WhenUnlockedThisDeviceOnly`；
- 访问控制固定为 `privateKeyUsage + biometryCurrentSet`；
- ECIES `X963SHA256AESGCM` 加密包含 AAD 摘要和明文长度的 v1 信封；
- 生物识别集合变化后旧密钥失败关闭。

## 数据隔离

公开钱包事实、公开链数据库、硬件密文分别使用：

| 数据 | 命名空间 | 是否含私钥材料 |
|---|---|---|
| 钱包 profile/revision/cleanup | `citizensdk.wallet.state.v1` | 否 |
| smoldot finalized database | `citizensdk.smoldot.database.v1` | 否 |
| 账户硬件密文 | `citizensdk.wallet.secret.*` | 只有不可独立解密的密文 |

原生层只接受 `citizensdk` 命名空间，Dart 层也不暴露命名空间选择。SDK 不读取、迁移或删除
其它产品的密文和硬件密钥；产品迁移必须在宿主切换步骤中单独批准，不能成为 SDK 隐式行为。

## 尚未执行的验收

当前只完成源码和测试源码。用户尚未授权测试、Gradle、Xcode/CocoaPods、Flutter 构建或
签名 Release 真机验收，因此不能宣称插件已经构建或硬件门禁已经在 CitizenSDK 包内验证。
