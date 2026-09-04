# CitizenSDK 最终 Dart API

应用只从 `package:citizen_sdk/citizen_sdk.dart` 使用本目录的公开 API。Android、Darwin 与
Linux binding 只是稳定 CitizenSDK Core ABI 的类型化投影，不在 Dart 中重写轻节点、钱包、
sr25519 或交易逻辑。第 7.4 步已把 LinuxARM/LinuxAMD 纳入同版候选合同与默认公开入口，
共用官方 `linux` plugin 注册；不需要注入内部 platform 或增加产品侧包装。

`CitizenSdk.open()` 创建隔离 session；普通读取、签名和长时转账可以并发，分别使用
单调 request sequence。`start`、`stop` 会等待既有请求并独占新的接纳；`close` 关闭接纳并让
原生协调器取消/收口长时请求。事件使用独立且连续的 event sequence。运行中的 session 必须先
等待 `stop()` 完成 checkpoint，再调用 `close()`；后者等待结果释放、destroy 和已接纳 Dart
调用完成，不能用来绕过有序停止。

钱包创建、导入和追加账户只启动 SDK 自有的平台原生安全界面；Linux 复用已有 GTK 钱包流程。
助记词与可选 password 不得进入 Dart；Dart 只接收创建完成后的公开 `CitizenWalletProfile`。
Linux 实际构建和运行证据由后续统一 GitHub CI（增量缓存）/Release（全量构建）验证；源码
注册不代表已发布。同版插件缺失时返回 `unsupported`，不得替换为 Dart 钱包或另一份 Core。
