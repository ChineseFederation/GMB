# ChatServer Cloudflare

此目录是 ChatServer 唯一协议的 Cloudflare 运行时适配，不定义 Cloudflare 专属客户端协议。

## 运行边界

- Worker：EdDSA JWT 鉴权、健康检查和 HTTPS 附件分块数据面。
- Durable Object CHAT_REALTIME：每设备休眠 WSS、认证会话附件和 Protobuf 控制命令。
- D1 CHAT_DB：当前 Last Resort KeyPackage、七天密文邮箱、附件状态、推送端点和推送 outbox。
- R2 CHAT_ATTACHMENTS：客户端已加密的附件分块字节。
- APNs/FCM：不包含聊天内容或业务标识的固定系统唤醒通知。

## 公开接口

- GET /health
- GET /realtime，升级为子协议 chatserver 的 WSS
- PUT /attachments/{attachment_id}/chunks/{chunk_index}
- GET /attachments/{attachment_id}/chunks/{chunk_index}

KeyPackage、消息、附件状态、推送和心跳全部使用 WSS ChatFrame 二进制 Protobuf；不存在 JSON 控制接口。附件分块必须匹配 Content-Length 与 x-chat-cipher-sha256，全部声明分块写入后才能完成。

## 唯一数据结构

schema.sql 是唯一 D1 应用结构，只用于全新空数据库。不存在迁移目录、兼容表、旧路由或运行时结构修改。Wrangler 中 Durable Object 的注册记录只用于 Cloudflare 类注册，不是第二套应用数据库结构。

消息主键固定为 message_id、recipient_user_id、recipient_device_id 三元组。每个设备只保留一个 Last Resort KeyPackage。查询立即过滤过期数据，定时任务每轮最多清理固定数量的消息、密钥包和附件，避免无界 D1 写入。

## 配置

公开变量：

- CHAT_APP_ID
- CHAT_AUTH_ISSUER
- CHAT_AUTH_AUDIENCE
- CHAT_MAX_ATTACHMENT_BYTES
- CHAT_APNS_TEAM_ID
- CHAT_APNS_KEY_ID
- CHAT_APNS_ALLOWED_TOPICS
- CHAT_APNS_SANDBOX

密钥：

- CHAT_AUTH_ED25519_PUBLIC_KEY
- CHAT_APNS_PRIVATE_KEY
- CHAT_FCM_SERVICE_ACCOUNT

绑定：

- CHAT_DB
- CHAT_ATTACHMENTS
- CHAT_REALTIME

源码中的零 D1 UUID 不可部署；正式流程必须注入本次新建数据库的准确 UUID。客户端协议不使用预签名 URL、账户编号、R2 访问密钥或 R2 密钥。
