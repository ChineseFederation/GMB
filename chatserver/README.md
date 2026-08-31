# ChatServer

ChatServer 是 ChatSDK 的通用服务端，负责 OpenMLS Last Resort KeyPackage、七天离线密文邮箱、端到端加密附件分块、WSS 实时唤醒和 APNs/FCM 无内容通知。它不依赖任何宿主产品的身份、会员或业务模型，可部署到 Cloudflare，也可通过 Linux ARM64 安装包部署到自建服务器。

## 唯一协议边界

- core/：唯一命令解析、数据校验、服务端时钟、七天期限和稳定错误码。
- cloudflare/：D1、R2、Durable Objects、APNs/FCM 运行时适配。
- linux-arm64/：PostgreSQL、本机私有对象目录、进程内 WSS 和 APNs/FCM 运行时适配。
- 控制面固定为 GET /realtime 升级后的 WSS 二进制 Protobuf。
- 数据面固定为 HTTPS PUT/GET /attachments/{attachment_id}/chunks/{chunk_index}。
- GET /health 只检查当前唯一数据库结构和运行状态。
- 第一方路径不含版本段，不存在 JSON 控制接口或第二套消息传输合同。

## 控制命令

同一个 ChatFrame 处理以下命令：

- key_package.publish、key_package.resolve
- message.send、message.sync、message.ack
- attachment.begin、attachment.complete、attachment.ack、attachment.abort
- push.register、push.remove
- ping

每个认证 WSS 会话独立执行 KeyPackage 解析限流，不产生数据库计数写入。每个设备只保存当前有效的 RFC 9420 Last Resort KeyPackage；发布新引用时原子替换，解析时不消费。

## 服务端时间与七天期限

- 客户端只提交创建时间，不提交 TTL 或过期时间。
- 创建时间最多领先服务端五分钟，且不得早于服务端当前时间七天。
- 服务端写入 accepted_at_millis。
- 最终期限为 created_at 加七天与 accepted_at 加七天两者中的较早值。
- 消息与附件查询立即排除过期记录；物理删除按固定批量执行。
- 消息唯一键为 message_id、recipient_user_id、recipient_device_id 三元组，一条逻辑消息可安全写入多个接收设备。

## 附件生命周期

1. attachment.begin 提交接收者、总密文摘要和完整分块清单。
2. 每个 HTTPS 分块必须同时匹配声明的序号、长度和 SHA-256。
3. 只有全部声明分块都已校验写入，attachment.complete 才返回 attachment_ready。
4. 单个附件失败不会阻塞其他消息或附件。
5. 全部接收者确认或服务端七天到期后，先标记 deleting，再删除对象，最后删除元数据。
6. Cloudflare 直接流式写入 R2；Linux ARM64 使用同文件系统临时文件、摘要校验和原子公开。

## 安全硬规则

- 网络只允许 HTTPS 与 WSS；没有明文监听、协议降级或非加密回退。
- JWT 固定使用 EdDSA，并校验签发者、受众、有效期、用户和设备绑定。
- APNs/FCM 只携带固定唤醒文案，不携带消息、会话、发送者或附件标识。
- 服务端只保存 OpenMLS 密文和客户端已经加密的附件字节。
- 每个部署必须配置一个 CHAT_APP_ID 或 server.app_id，仅用于该部署的推送应用标识。
- Cloudflare D1 与 Linux PostgreSQL 都只接受当前唯一全新结构，不执行迁移、兼容或运行时改表。

## Linux ARM64 安装

主机必须已经具备 PostgreSQL、有效 TLS 证书、EdDSA JWT 公钥和 systemd。编辑 linux-arm64/package/chatserver.toml 后执行 linux-arm64/package/install.sh，并传入 TLS 证书、TLS 私钥和 JWT Ed25519 公钥路径。

安装器拒绝已有数据库表，创建最小权限系统用户和私有对象目录。卸载命令会删除当前规范表、密文对象、配置和系统用户。

## 本地质量检查

- cargo fmt --manifest-path chatserver/Cargo.toml --all -- --check
- cargo clippy --manifest-path chatserver/Cargo.toml --workspace --all-targets --locked -- -D warnings
- cargo test --manifest-path chatserver/Cargo.toml --workspace --all-targets --locked
