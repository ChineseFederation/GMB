# CitizenChatServer

CitizenChatServer 是公民产品使用的 TataChatServer Cloudflare 实例。该目录只保存宿主产品声明与资源配置，不复制通用聊天源码，也不保存编译产物、密钥或生产资源编号。

- HTTPS：`https://chat.crcfrcn.com`
- WSS：`wss://chat.crcfrcn.com/realtime`
- 授权签发方：CitizenServe
- 授权受众：`citizenchatserver`
- 通用实现：TATA 仓库的 `tatachatserver`

`worker.mjs` 由后续中央构建流程在隔离工作目录装配，禁止生成到本产品源码目录。CitizenServe 当前聊天数据面本步骤不切换，只有最终链路验收通过后才执行一次整体切换。
