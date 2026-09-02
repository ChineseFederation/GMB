# Flutter 平台投影

Android、iOS 与 macOS 共用 `citizen/sdk/core/v1` MethodChannel 和
`citizen/sdk/events/v1` EventChannel。macOS 产品只称为 macOS；当前 Apple 工具链机器架构值为
`arm64`，不得拼入平台名。
iOS 与 macOS 在 `pubspec.yaml` 中都声明官方 `sharedDarwinSource: true`，由同一份 Apple
binding 实现协议；Dart 不为 Apple 复制第二套 transport。

三个平台的 Flutter 边界完全相同：22 个方法只允许固定长度、固定位置的 List tuple，并逐层
校验长度、类型、session、request sequence、event sequence 和枚举闭集。协议不接受 Map、
任意 RPC、独立 signed extrinsic、原生 handle、助记词、密码、DEK、child secret 或私钥。
创建、导入和追加账户只触发 SDK-owned 原生安全流程；秘密始终留在 Rust 与平台金库边界内。

`CitizenSdkFlutterSession` 只协调 session、序列、事件和关闭，不实现链、钱包、签名或交易逻辑。
`FlutterCitizenSdkPlatform` 只是三平台原生 facade 的公共 transport。`close` 必须等待原生
checkpoint、stop、结果释放与 destroy 完成；EventChannel cancel 不能替代关闭。平台实现不得
扩展方法闭集、改变 tuple 位置或以 Map 增加兼容旁路。

旧 `citizen/sdk/hardware_secretvault` byte-only channel、Dart
`HardwareBoundSeedStore`、`MobileCitizenSdkComponents` 与通用 secure-blob 装配已经删除。
Android、iOS 与 macOS 的正式 Flutter 路径都只经产品 C ABI、平台 typed stores 和平台
`SecretVault`。保留的 Preferences 仓储、旧 Dart 链、钱包和交易代码只作为非公开差分输入，
不得重新接回根公开 client，也不能据此声称跨 isolate 或跨进程原子性。
