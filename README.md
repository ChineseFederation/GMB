# GMB

GMB 是公民链、公民移动端、公民服务端、公民钱包和官网的开源产品仓库，公开契约、测试和 CI 均可独立运行，
不依赖私人运维工具或 AI 编程系统。

快速入口：

- 白皮书唯一真源：[`citizenweb/src/whitepaper.md`](citizenweb/src/whitepaper.md)
- 公民宪法唯一真源：链上立法院模块 [`citizenchain/runtime/public/legislation-yuan/`](citizenchain/runtime/public/legislation-yuan/)（`law_id=0`、`tier=宪法`，创世注入 + 立法投票修订；展示端从链上结构化法律重建）
- 统一数据字典：[`shared/data-dictionary.json`](shared/data-dictionary.json)
- 统一二维码协议：[`shared/qr-protocol/`](shared/qr-protocol/)
- 产品与发布边界：[本文件“产品与发布边界”](#产品与发布边界)
- GitHub Actions：[`gmb-repository.yml`](.github/workflows/gmb-repository.yml) 是 GitHub 唯一注册入口；
  22 条产品 CI/Release 仍按产品保存在 `.github/workflows/<product>/`，由该入口按准确路径路由，
  不移动分组文件，也不生成顶层镜像文件。统一仓库门禁同时检查文档、残留、安全边界和新增
  代码的中文注释；单个代码文件新增不少于 12 行时，中文注释也必须出现在本次新增内容中。

## 产品与发布边界

产品目录：

- `citizenchain`：公民链 Node 与 Runtime。
- `citizenapp`：公民 iOS、Android 移动端，不包含服务端实现。
- `citizenserve`：独立部署到 Cloudflare 的公民服务端。
- `citizenwallet`：公民钱包 iOS、Android 离线冷钱包。
- `citizenweb`：公民网 Web 前端，不包含公民服务端。

生产发布授权中的 `platform` 表示产品端，不表示部署供应商：公民网唯一使用
`citizenweb/web`，公民服务端唯一使用 `citizenserve/cloudflare`。Cloudflare Pages 是
公民网的部署实现，不得改写公民网的 `web` 产品端身份。

每个产品、端和动作独立管理。CitizenServe 的 `cloudflare` 端分别使用独立的 CI、Release
逻辑流水线、记录和产物，不与 CitizenApp 或 CitizenWeb 合并计算；生产 Publish 只由本机
  ProgramConsole 执行，不属于 GitHub Workflow。

会员状态采用“手机即时确认 + 服务端唯一 finalized 投影”两条互补写入路径。CitizenApp 在
订阅、取消、换档或档位变更交易 finalized 后，只用链上 `tx_hash + block_hash` 立即确认；
禁止另造操作编号，HTTP 重试只复用同一交易，不得重新签名或重新发送链上交易。
CitizenServe 每五分钟通过既有 Cloudflare Access + Tunnel 连接国储会权威 RPC，以
System.Events 发现受影响关系，再从同一 finalized 区块批量读取订阅和创作者档位 storage。
平台会员、创作者订阅和创作者档位共用一个游标，整块处理成功后才推进；自动续费、自动
恢复、挂起、终止以及手机同步失败都由这一任务补齐，不增加节点回调、密钥、操作编号或
链时钟。旧 `chain_clock` 表由 ProgramConsole 在 CitizenServe 正式发布的只读门禁和回滚锚点
验收通过后，使用同一次 `SERVER_DEPLOY` 授权通过 Cloudflare 官方 D1 Query API 幂等删除；
该步骤不是 D1 预检，不读取业务数据。广场发布与资料读取仍只读 CitizenServe D1，禁止在请求路径点查链或追赶投影。
D1 没有会员行就不向其他用户展示会员信息，不输出“未知”“尚未同步”等第三状态。

真机聊天诊断统一使用客户端已有 `envelope_id` 串联本机入队、WSS 阶段、密文投递、接收和
落库，不新增操作编号。诊断只在 debug/profile 构建写入手机本地
`citizenapp_diag.log`，只允许稳定阶段码、投递状态、CID/设备路由标识和耗时；禁止记录消息
正文、媒体内容、钱包密钥、设备子钥、签名、会话令牌或完整服务端异常。Release 构建默认
保持零诊断日志；只有本机真机排障构建显式设置编译期
`CITIZENAPP_DIAGNOSTICS=true` 时才临时启用，不能运行时远程开启。复现完成后直接读取两台
手机的本地日志进行同一信封的数据流对账。WSS 握手诊断只在该模式下使用独立 nonce 对同
一路径执行一次无 Upgrade 的 HTTPS 预检，只记录 HTTP 状态和稳定错误码；不记录响应正文
或复用正式 WSS 签名。正常发布不携带该开关。

iOS 必须由 ProgramConsole 完成 Release 编译并安装到真机；安装完成后的真机测试、设备操作和日志
检查必须统一使用 Device Hub，禁止以截图驱动、拍照、模拟器或其他未登记测试工具替代。
真机记录继续遵守最小诊断边界，不得保存消息正文、附件内容、钱包密钥、设备子钥、会话令牌
或生物识别数据。

普通聊天统一采用 OpenMLS 端到端加密存转：文本、表情、贴纸和媒体控制信封进入单 CID
Durable Object 小密文邮箱；图片、语音、视频和文件由发送手机生成独立随机密钥并流式加密，
密文字节通过 Cloudflare R2 官方 S3 multipart HTTPS 地址直传私有桶，禁止经过 Worker 代理。
附件密钥、文件名、MIME 和用户内容只存在于 OpenMLS 密文中；D1 对每个附件只保存一份
R2 对象索引，并用独立收件人映射支持直聊和群聊。接收手机必须先校验、解密并重新写入本机
加密缓存，再删除自己的收件人映射；只有最后一个收件人 ACK 后才删除 R2 密文和主索引。
未 ACK 的 Envelope 与附件均固定保留七天，失败重试只复用原到期时间，禁止续期。普通消息
和附件不使用 WebRTC；KeyPackage 只通过 CitizenServe HTTPS 获取。WSS 只承担语音、视频
通话的扁平信令，普通消息由 APNs/FCM 唤醒并通过 HTTPS 补拉密文邮箱，所有网络地址只允许
`wss://` 或 `https://`。

附件发送必须先把本机消息、端到端载荷和待上传密文原子持久化，再由账户与会话保序队列通过
R2 官方 multipart HTTPS 地址上传；网络失败只保留当前附件待重试，不能把整个聊天判定为
不可用。上传成功后才发送媒体控制信封；重试复用现有 `envelope_id`、附件编号和原七天到期
时间，不增加操作编号，不把附件改成 WebRTC P2P。语音、视频通话的实时媒体才使用 WebRTC
手机直连且不使用 TURN；语音消息、视频消息、图片和文件仍属于七天密文存转附件。

聊天系统通知只携带固定无正文文案、发送方 CID 和既有 `conversation_id`。iOS 使用 APNs alert，
Android 使用 FCM；应用启动和平台 Token 更新后必须向 CitizenServe 幂等登记当前端点，本机缓存
不得代替服务端登记真源。重复 Envelope 在本机落库前先按既有 `envelope_id` 去重，只 ACK、不
重复累计未读。用户成功查看会话后同时清零本机未读并按 `conversation_id` 清除该会话的系统
通知，禁止清除其它聊天或广场通知。

聊天会员展示进入页面时先恢复 CitizenServe 上一次确认的本地快照，真实鉴权仍在同一服务端
登录会话内只读一次 CitizenServe。瞬时网络或会话错误不得把有效缓存改成无会员；没有任何
已确认快照时继续失败关闭。页面错误状态使用固定布局槽位，鉴权和重连不得动态插入组件造成
消息窗口抖动。

聊天窗口读取继续对每条本机密文执行认证解密，并严格校验消息枚举、目标 JSON 字段集合以及
数据库 `messageKind` 与端到端载荷 `kind` 完全一致。严格存储接口遇到篡改仍立即失败，窗口
展示只隔离无法通过认证或载荷验真的单条历史记录，并明确提示；禁止兼容、迁移、改写、删除
或把异常载荷降级成普通文本，也不得让一条异常记录阻断同会话其余有效新消息。只有本地首读
成功、有效记录为零且异常记录也为零时才能显示“暂无消息”；读取失败或全部记录无法验证时
必须显示真实错误，不得用空态掩盖。推送、应用启动和恢复前台必须先补拉密文邮箱；新
Envelope 完成本机落盘后仅按发送方合并重试本机待发队列，不发送实时信令，重复 Envelope
只 ACK。聊天心跳只在消息快照真实变化时更新控制器，禁止
周期性清空重建窗口。信封到达原七天 TTL 后必须标记失败并退出重试队列，不得继续请求服务端。

产品目录只保留代码实现、公开配置、测试、脚本与资源文件；私人运维源码、长期记忆、任务卡、
证书和机密不属于本仓库。

#### 聊天可靠性统一规则（2026-08-28）

- 会员本地快照只负责稳定展示；每次登录会话的聊天发送权限必须由 CitizenServe 明确授权，鉴权失败时禁止发送，但不得抹掉既有展示快照。
- 直聊和群聊附件统一先写本机待发消息与加密暂存文件，再经 HTTPS 上传私有 R2，最后通过 OpenMLS 控制信封投递密钥和元数据；附件禁止经过 WebRTC，失败只保留一条可重试记录。
- 本机待发消息与 CitizenServe 密文邮箱统一最多保留 7 天；过期后标记失败并停止补发。
- APNs/FCM 系统通知使用信封既有的 `conversation_id` 分组；只有本机数据库确实清零该会话未读数后，才清除对应系统通知。
- 普通消息收件必须在 WSS 建连、WebRTC 和待发重试之前补拉 CitizenServe 密文邮箱；推送失败、WSS 断开或对端离线均不得阻塞应用启动和恢复前台时补收。
- WSS 协议只接受带 `connection_id` 的语音、视频通话建连信令；普通消息禁止增加在线探测、反向唤醒或补发信令。
#### CitizenApp 中央测试快照真源规则（2026-08-28）

- CitizenApp 本机测试继续只在 ProgramConsole 中央隔离快照运行；应用目录不得保存链端 SCALE 金标或 CitizenServe 推送实现的镜像副本。
- 官方测试入口必须把 `scale_codec_vectors.json`、`role_permission.json` 与 `citizenserve/src/chat/push.ts` 从当前 GMB 仓库复制到一次性快照，并在任一真源缺失时立即失败。
- 跨产品契约测试始终读取本次仓库源码，禁止读取历史缓存、发布产物或另行维护的兼容副本。

### 设备子钥登记的前台验证规则

- CitizenApp 新设备或硬件子钥变化时，只允许在根导航器就绪后展示一次 Cloudflare Turnstile 设备绑定验证；冷启动不得提交空 token。
- Turnstile 未配置、界面未就绪、用户取消或 token 不合法都必须失败关闭，不得登记设备子钥，也不得循环重试。
- 已登记设备继续使用按 CID 隔离的 P-256 硬件子钥静默登录；该登录和日常请求不触发生物识别。
- iOS 真机交互回归统一使用 Device Hub/XCTest；禁止用桌面坐标点击冒充设备触控。

## CitizenApp / CitizenServe OpenMLS 首次会话合同（2026-08-28）

- CitizenApp 保留 OpenMLS；每台当前 Chat 设备只发布一个普通一次性 KeyPackage 和一个 RFC 9420 last-resort KeyPackage。私密材料只存在于本机 OpenMLS 状态。
- CitizenServe 通过 `PUT /chat/key-packages` 保存两个公开包，通过 `POST /chat/key-packages/claim` 原子领取普通包并在耗尽时返回兜底包；状态复用现有 Chat Durable Object，不新增 D1 表、迁移、任务编号或独立服务。
- 首次私聊和私密小群加人必须经 HTTPS 领取公开 KeyPackage，再由本机生成 Welcome 和 MLS 密文；已有 MLS 会话直接加密并提交 `/chat/messages`。
- WebRTC 严格只允许语音、视频通话入口使用。文字、表情、贴纸、附件和 KeyPackage 获取不得创建 PeerConnection 或 DataChannel；附件继续使用本机加密、HTTPS 私有 R2 密文与 OpenMLS 内容钥控制消息。
- CitizenServe 永不接收 OpenMLS 私钥、聊天明文或附件明文字节；普通消息只有云端持久化成功后才可标记已发送。
- CitizenServe 跨端契约测试必须读取当前存在的 Chat 源码，锁定 KeyPackage 仅走上述 HTTPS
  两条路由，并断言普通消息运行时不存在 `ChatWebrtcTransport`、`RTCPeerConnection` 或
  `context.webrtc.requestKeyPackage`；禁止继续引用已删除的 WebRTC KeyPackage 文件。
