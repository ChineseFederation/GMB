# 最终 Dart API 测试

本目录覆盖 `CitizenSdk` 的 open/start/stop/close 生命周期、严格 session/request/event
序列、类型化链读取、SDK 原生钱包安全流程、高层转账和 finalized 历史。测试 fake 只模拟固定
List tuple transport，不实现第二套链、钱包、签名或交易逻辑。
