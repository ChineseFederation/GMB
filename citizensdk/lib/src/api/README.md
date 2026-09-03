# CitizenSDK 最终 Dart API

应用只从 `package:citizen_sdk/citizen_sdk.dart` 使用本目录的公开 API。Android 实现只是稳定
CitizenSDK Core ABI 的类型化投影，不在 Dart 中重写轻节点、钱包、sr25519 或交易逻辑。

`CitizenSdk.open()` 创建隔离 session；普通读取、签名和长时转账可以并发，分别使用
单调 request sequence。`start`、`stop` 会等待既有请求并独占新的接纳；`close` 关闭接纳并让
原生协调器取消/收口长时请求。事件使用独立且连续的 event sequence。`close` 只有在原生侧
完成 checkpoint、stop、结果释放和 destroy，且已有 Dart 调用全部完成后才返回。

钱包创建、导入和追加账户只启动 SDK 自有的 Android 安全界面。助记词与可选 password 不得
进入 Dart；Dart 只接收创建完成后的公开 `CitizenWalletProfile`。
