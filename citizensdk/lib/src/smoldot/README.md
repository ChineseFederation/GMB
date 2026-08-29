# smoldot Dart 边界

本目录是 CitizenSDK 内部的 smoldot Dart FFI 封装。`bindings.dart`、`chain.dart`、
`client.dart`、`json_rpc.dart` 与 `types.dart` 从 CitizenApp 已验证版本逐字节迁入；
`platform.dart` 仅允许调整 SDK 自身动态库查找路径和错误信息。

这些类型不是第二个独立 SDK。应用只能通过 `package:citizen_sdk/citizen_sdk.dart`
使用稳定公共接口，避免绑定内部 FFI 生命周期。
