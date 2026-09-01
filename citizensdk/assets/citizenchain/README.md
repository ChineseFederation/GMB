# CitizenChain 随包信任资产

本目录只保存 CitizenSDK 随安装包签名分发的 CitizenChain 静态信任资产，不保存轻节点运行
数据库、钱包资料、账户秘密、远端配置或任何构建产物。

- `chainspec.json` 是轻节点链规格，正式 `id` 与 `protocolId` 都是 `citizenchain`。
- `light_sync_state.json` 是已经验证的创世块 `#0` finalized 同步状态。
- `manifest.json` 把产品、链 ID、协议 ID、创世哈希和两个文件的 SHA-256 固定为一个闭集。

SDK 必须先精确校验 manifest 字段和两个文件摘要，再根据 `#0` header 重新计算 genesis hash，
并核对 chainspec 的链 ID、协议 ID 和 state root。任何一步不一致都必须停止轻节点启动。

这三个 JSON 文件没有在线替换入口。更新任一信任资产都必须同时核对 CitizenChain 正式链事实、
更新 manifest、测试、来源文档和 Release 闭集，并重新发布整个 CitizenSDK。
