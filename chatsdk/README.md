# ChatSDK

ChatSDK 是独立、部署无关的端到端加密聊天客户端 SDK。宿主只注入用户身份、产品策略、平台能力和 ChatServer 传输实现；聊天运行编排、OpenMLS、消息模型、本机存储、可靠队列、附件处理与通用界面均由本包负责。

公开 Dart 包名固定为 `gmb_chat_sdk`，产品名仍为 ChatSDK。不得再发布或引用第二个 Dart 包身份；原生动态库和 C ABI 继续使用稳定的 `chat_sdk` / `chat_sdk_*` 名称。

## 依赖方式

第三方应用只使用 pub.dev 的公开包：

```yaml
dependencies:
  gmb_chat_sdk: ^1.0.0
```

```dart
import 'package:gmb_chat_sdk/chat_sdk.dart';
```

GMB 第一方正式产品固定依赖准确的 ChatSDK GitHub Release Tag，不跟随浮动分支：

```yaml
dependencies:
  gmb_chat_sdk:
    git:
      url: https://github.com/ChineseFederation/GMB.git
      ref: chatsdk-sdk-v1.0.0
      path: chatsdk
```

GMB 本机开发由产品脚本临时写入 `pubspec_overrides.yaml`，把同一依赖直接指向仓库内 `../chatsdk`；脚本退出必须删除覆盖文件并恢复产品锁文件。首次 ChatSDK Release Tag 尚未生成前，第一方宿主保持同仓路径锁定，禁止伪造不存在的 Git Tag 或提交哈希。

## 唯一边界

- 唯一端到端加密协议：OpenMLS。
- 唯一逻辑消息编号：message_id。
- 每个接收设备持有独立的 OpenMLS 密文投递。
- 控制与实时通道只允许 WSS。
- 附件数据通道只允许 HTTPS。
- 本机待发任务和服务端投递都不得超过七天。
- 私聊与群聊共用同一套消息、存储和传输合同。
- 群聊不提供语音或视频通话入口。
- SDK 不包含任何宿主产品身份、会员、链、品牌或部署凭据。

## 宿主必须注入

- ChatRuntimeHost：当前用户、ChatServer 会话、发送授权和账户失效处理。
- ChatServiceTransport：WSS 控制面、邮箱、KeyPackage、推送、附件和通话信令边界。
- ChatStorageKeyProvider：按用户绑定和用途返回本机存储钥。
- ChatMediaLimitPolicy：宿主决定媒体类型和大小限制；SDK 只执行结果。
- 平台回调：系统推送、文件选择、录音、相机和通话设备能力。
- 产品 UI 配置：主题、文案覆盖和入口组合；默认通用 UI 仍由 SDK 提供。

## SDK 负责

- ChatRuntimeCore 的启动、恢复、实时同步、邮箱补拉和账户上下文生命周期。
- OpenMLS 会话、Last Resort KeyPackage、设备投递和群组状态。
- 文本、表情、贴纸、语音、照片、视频与文件消息。
- 本机 Isar 数据库、静止态密文、搜索索引、未读数、交接和清理。
- 待发队列、失败隔离、幂等确认、七天到期和附件异步上传。
- 私聊、群聊、会话列表、消息列表、输入栏、媒体预览和通话通用 UI。
- 原生 OpenMLS 库的独立构建、加载和符号合同。

## 目录

- lib/chat_sdk.dart：公开入口。
- lib/src/attachment：附件密文、分块和本机文件库。
- lib/src/call：私聊通话状态和客户端边界。
- lib/src/core：通用消息、内容、会话与范围模型。
- lib/src/group：群聊模型与 OpenMLS 群流程。
- lib/src/mls：OpenMLS 会话、状态库和原生边界。
- lib/src/protocol：Protobuf 生成代码与严格编解码。
- lib/src/runtime：唯一运行编排、队列、同步和账户生命周期。
- lib/src/storage：唯一 Isar、静止态密文、索引和交接实现。
- lib/src/ui：通用聊天界面。
- native、include、proto、scripts、test：独立原生、协议、构建与测试。

宿主不得复制 runtime 和 storage 的实现。

## 本机存储

- 数据库实例名固定为 chat_sdk_chat。
- 文件域固定为 chat/by_user/<user_id>/by_binding/<revision>/<account_id>。
- 正文、摘要、搜索索引和 OpenMLS 状态均按用途钥隔离。
- 交接清单使用严格字段、完整认证和失败关闭。
- 系统备份必须排除聊天文件域及 chat_sdk_chat* 数据库文件。

## 网络安全

任何首方运行路径出现明文 HTTP 或明文 WS 都是错误。ChatSDK 不提供明文回退、旧协议兼容、版本路径兼容或第二套传输实现。

## 开发验证

所有 Flutter/Dart 构建与测试产物必须写入 ProgramConsole 的 target/.work 隔离工作区，不得在源码目录生成构建产物。

基础验证为 flutter analyze 和 flutter test。

原生 OpenMLS 测试只有在独立 ChatSDK 原生库可用时执行；缺少宿主库的用例必须明确显示为跳过，不能冒充通过。
