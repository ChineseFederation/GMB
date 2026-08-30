# ChatSDK

ChatSDK 是独立的端到端加密聊天 SDK，不依赖 CitizenSDK、CitizenApp 或 CitizenServe。
应用可以连接 CitizenServe，也可以连接实现同一 ChatSDK 协议的自建服务器。

## 初始化

```dart
final chat = ChatSdk(
  config: ChatConfig(
    httpsEndpoint: Uri.parse('https://chat.example.com'),
    wssEndpoint: Uri.parse('wss://chat.example.com/chat/realtime'),
  ),
  identity: identity,
  access: access,
);

await chat.start();
```

ChatSDK 只接受 HTTPS 与 WSS 地址，不提供明文连接或证书校验绕过选项。

## OpenMLS ownership

ChatSDK owns the OpenMLS protocol models, native engine, FFI symbols, and local
MLS state namespace. Applications supply a deployment-neutral user identifier
and server transport; product identifiers remain outside the SDK.

Native artifacts are named libchat_sdk and export only the
chat_sdk_mls_ and chat_sdk_device_ symbol families.

## CitizenApp adapter boundary

CitizenApp maps its citizen number to ChatSDK user_id in one product adapter.
CitizenServe-specific error codes and CID wording stay in that adapter. ChatSDK
uses the chatsdk/direct/v1 and chatsdk/device-hpke/v1 cryptographic domains.

The native build uses the installed Rust targets and Android NDK directly. It
does not require cargo-ndk. Host, Android arm64, and iOS arm64 artifacts are
checked for OpenMLS, device identity, and string-release symbols.

## 第一类消息完整链路

ChatSDK 现在统一拥有私聊与群聊的文字、emoji、贴纸协议。三种内容使用同一个 protobuf 真源，先严格校验再交给私聊 HPKE 或群聊 OpenMLS；CitizenApp 只映射 CID 与展示模型，不再保存 basic JSON 协议。

- 私聊入口：`lib/direct.dart`，同一会话的密码学操作串行。
- 群聊入口：`lib/group.dart`，一份 OpenMLS 密文按收件人生成确定性信封。
- 可靠性：发送前由宿主保存密文；同一密文重试复用同一 `envelope_id`；邮箱最长保留 7 天。
- 传输：可靠消息使用 HTTPS 密文邮箱，WSS 只做实时通知，WebRTC 只属于语音/视频通话。
- 服务端边界：实现 `MailboxTransport` 即可接入 CitizenServe 或任意自建服务，服务端不得解析端到端明文。

## 第二类媒体消息完整链路

ChatSDK 统一拥有私聊与群聊的语音消息、照片、视频消息和文件协议。媒体描述使用 protobuf，内容密钥和 SHA-256 在端到端加密控制信封内传递；附件字节使用分块 AES-256-GCM 加密后经 HTTPS 对象存储传输，服务端只看到密文。

- 通用附件金库位于 lib/src/media，长期缓存只保存密文，预览明文只进入短命目录。
- AttachmentStorage 是 CitizenServe、Cloudflare R2 与 Linux 自建服务共同实现的服务器中立合同。
- 群聊只加密并上传一份附件密文，再将同一密文引用放入一份 OpenMLS 控制消息扇出。
- 附件上传失败只失败该附件，不占用同会话串行密码学门闩，不阻塞后续文字、表情或贴纸。
- 拍摄、相册、录音、压缩、会员限额和界面仍由宿主应用负责。

## 私聊语音和视频通话

ChatSDK 通过 `call.dart` 提供部署无关的一对一通话状态机。部署端只实现 STUN 读取与加密 WSS 信令转发，音视频只经过 WebRTC `RTCPeerConnection`，禁止 TURN、DataChannel 媒体传输和服务端音视频中转。信令沿用既有 `connection_id`、Offer、Answer、ICE、Hangup、ICE Restart 与 Peer Ready，不创建第二套编号或协议版本。

群聊当前只在产品界面显示禁用的语音、视频图标，不包含群通话实现。

## ProgramConsole 与正式 Release

ChatSDK 在 ProgramConsole 的“编程控制台”流程页中作为独立产品显示，产品标识为 `chatsdk`，平台标识为 `sdk`。它只提供以下三个相互独立的动作：

- `chatsdk-build-sdk`：在本机隔离快照中验证 Dart、Flutter 与 Rust，并生成三件套到 `/Users/rhett/Only/ProgramConsole/target/chatsdk`。
- `chatsdk-ci-sdk`：使用任务创建时 GitHub 锁定的最新 `main` 提交完成检查和 Android、iOS、macOS ARM64 原生构建；CI 不读取、生成或持久化软件版本。
- `chatsdk-release-sdk`：只消费准确成功 CI 的提交和原生候选，按 `chatsdk-v<software_version>` 固化正式 Release。

正式 GitHub Release 必须且只能包含 `chatsdk.tgz`、`chatsdk-release.json`、`SHA256SUMS`。归档内外 manifest 必须逐字节一致，manifest 固定登记 Android ARM64、iOS ARM64 和 macOS ARM64 三个平台及全部文件摘要。ChatSDK 当前没有 LinuxARM 服务端安装包，也没有独立“发布”动作；正式 GitHub Release 是当前 SDK 分发终态。
