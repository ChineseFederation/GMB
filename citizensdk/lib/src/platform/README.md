# Flutter 平台投影

Android、iOS、macOS、LinuxARM/LinuxAMD 与 Windows 共用 `citizen/sdk/core/v1` MethodChannel 和
`citizen/sdk/events/v1` EventChannel。macOS 产品只称为 macOS；当前 Apple 工具链机器架构值为
`arm64`，不得拼入平台名。
iOS 与 macOS 在 `pubspec.yaml` 中都声明官方 `sharedDarwinSource: true`，由同一份 Apple
binding 实现协议；LinuxARM/LinuxAMD 共用官方 `linux` 注册，Windows 使用官方 `windows`
注册，两者的插件类型均为 `CitizenSdkPlugin`。
Dart 不为平台复制第二套 transport。

全部平台的 Flutter 边界完全相同：22 个方法只允许固定长度、固定位置的 List tuple，并逐层
校验长度、类型、session、request sequence、event sequence 和枚举闭集。协议不接受 Map、
任意 RPC、独立 signed extrinsic、原生 handle、助记词、密码、DEK、child secret 或私钥。
创建、导入和追加账户只触发 SDK-owned 原生安全流程；秘密始终留在 Rust 与平台金库边界内。

`CitizenSdkFlutterSession` 只协调 session、序列、事件和关闭，不实现链、钱包、签名或交易逻辑。
`FlutterCitizenSdkPlatform` 只是原生 facade 的公共 transport。`close` 必须等待原生
checkpoint、stop、结果释放与 destroy 完成；EventChannel cancel 不能替代关闭。平台实现不得
扩展方法闭集、改变 tuple 位置或以 Map 增加兼容旁路。

第 7.2 步 LinuxARM/LinuxAMD adapter 复用 Linux Host 和唯一 Core；第 7.4 步已原子纳入
`pubspec.yaml`、默认 `CitizenSdk.open()` 与同版本 Release 候选合同。尚未执行 Linux 编译或
CTest，真实平台验证留到后续统一 GitHub CI/Release，不把源码注册写成运行或正式发布成功。
它不增加 Linux 专用 Dart transport。Linux 字符串通过官方 StandardMessageCodec 扩展点
保留内嵌 NUL 的完整 UTF-8 字节，线上仍是标准字符串编码，不截断备注或新增 wire 类型。

第 8.2 步 Windows 原生 adapter 源码也遵守同一双通道和 22 方法，使用官方
StandardMethodCodec；身份、路径、HWND 由 Windows 原生层装配。第 8.4 步已同步接入
pubspec 官方注册、默认 `CitizenSdk.open()` 和同版候选/Hosted 运行投影；缺插件仍失败
关闭，WASM、Fuchsia 不开放。Windows 宿主须一次声明 `CITIZENSDK_APPLICATION_ID`，
公开 Dart API 不接收路径或秘密。Windows 实际编译、运行和正式分发仍待统一 GitHub
验收，不把默认入口已接入写成平台实测或 Hosted 已发布。

旧 `citizen/sdk/hardware_secretvault` byte-only channel、Dart
`HardwareBoundSeedStore`、`MobileCitizenSdkComponents` 与通用 secure-blob 装配已经删除。
Android、iOS、macOS、LinuxARM/LinuxAMD 与 Windows 的公开 Flutter 路径都只经产品 C ABI、平台 typed stores 和平台
`SecretVault`。保留的 Preferences 仓储、旧 Dart 链、钱包和交易代码只作为非公开差分输入，
不得重新接回根公开 client，也不能据此声称跨 isolate 或跨进程原子性。
