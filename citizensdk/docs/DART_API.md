# CitizenSDK Dart/Flutter 公共接口

## 当前交付边界

根入口只公开 ABI v1 的类型化 API：

```dart
import 'package:citizen_sdk/citizen_sdk.dart';
```

Android、iOS 与 macOS 已安装正式 binding。iOS 和 macOS 在 `pubspec.yaml` 中共同使用
`sharedDarwinSource: true`，由 `darwin/` 的同一 Swift/Flutter adapter 投影产品 ABI。
`CitizenSdkClient.open()` 在 LinuxARM、LinuxAMD、Windows 和 WASM 上稳定返回
`CitizenSdkErrorCode.unsupported`，不会误走移动或 Darwin channel。
iOS 模拟器变体可运行产品 ABI 与公开链能力，但没有 Secure Enclave；硬件金库、钱包和
依赖它们的签名/交易能力必须通过 capability snapshot 报告不可用。

共享 `citizen/sdk/core/v1` 的 22 方法 tuple 从未定义 mnemonic、password、DEK、child secret、
private key、prepared/result/native handle 或 signed-extrinsic 位置。Android 与 Darwin adapter
都必须遵守同一秘密不跨 Flutter 的合同。

`lib/src` 中保留的旧 Dart 轻节点、钱包和交易代码是归档差分基线；它们已从
`lib/citizen_sdk.dart` 根入口移除，Android、iOS 和 macOS 正式绑定均不可达，也不是新宿主的
公开 API。

Hosted Package 的 Dart 运行时闭包精确为 17 个文件：

```text
lib/citizen_sdk.dart
lib/src/api/citizen_chain.dart
lib/src/api/citizen_sdk_client.dart
lib/src/api/citizen_sdk_error.dart
lib/src/api/citizen_sdk_events.dart
lib/src/api/citizen_transactions.dart
lib/src/api/citizen_wallet.dart
lib/src/crypto/account_codec.dart
lib/src/models/citizen_account.dart
lib/src/models/citizen_capability.dart
lib/src/models/citizen_chain_state.dart
lib/src/models/citizen_transaction.dart
lib/src/models/citizen_wallet.dart
lib/src/platform/citizen_sdk_flutter_codec.dart
lib/src/platform/citizen_sdk_flutter_sessions.dart
lib/src/platform/citizen_sdk_platform.dart
lib/src/platform/flutter_citizen_sdk_platform.dart
```

根包运行依赖只有 Flutter SDK 与 `polkadart_keyring`；legacy/差分源码所需其余依赖只是
dev dependencies，且相应源码由 `.pubignore` 排除，不会成为宿主的运行时闭包。

本机对该精确 17 文件 Hosted 闭包执行分析为 0 问题；完整 Dart 套件使用
`flutter test --timeout=2m` 执行 316/316。这里记录本地闭集验证，不代表 Hosted 已上传，
也不代表 TataConsole 远程 CI 已运行。

真实 Flutter consumer 已从本公开入口完成 Android release APK（ABI `arm64-v8a`）、iOS device Release
no-codesign、iOS 模拟器变体（Rust target `aarch64-apple-ios-sim`）编译和 macOS Release 构建。该结果只证明公开
Dart API、Flutter adapter 与原生投影能够链接成产物；未执行移动真机或 Simulator runtime。
Flutter 对插件 Swift Package Manager 目录的识别警告与 Android built-in Kotlin 迁移提示
留到第 9 步 Hosted/Flutter 集成统一处理。

## 会话与生命周期

```dart
final sdk = await CitizenSdkClient.open();
await sdk.start();
final capabilities = await sdk.getCapabilities();
await sdk.stop();
await sdk.close();
```

- `open` 只创建独立 Core session，不隐式启动轻节点。
- `start` 和 `stop` 是独占生命周期操作；它们等待较早请求收口，期间不接纳
  新操作。
- 普通链、钱包和历史请求可并发；request sequence 只用于精确关联，
  不按返回顺序猜测。
- `close` 首先封闭新请求、取消可取消的交易观察并等待已接纳工作。
  Running session 只能在 checkpoint/stop 成功后 destroy；失败时保留实例供重试。
- Apple 绑定把 callback clear 与 destroy 重试保存为单调关闭阶段。一旦开始部分关闭，
  该 facade 不再恢复接纳请求；显式 close、Flutter detach 或 deinit 未能收口时，整个
  facade 由进程级 supervisor 继续重试，直到 Core destroy 成功后才释放宿主上下文。

## 链读取

`sdk.chain` 只提供 Core 已验证的类型化入口：

```dart
final finalized = await sdk.chain.getFinalizedHead();
final balance = await sdk.chain.getAccountBalance(accountId);
final nonce = await sdk.chain.getAccountNonce(accountId);
final fee = await sdk.chain.getFeeSnapshot();
```

- balance 锚定 finalized 块。
- nonce 锚定同一准确 best runtime snapshot，不是交易池 nonce 租约。
- fee snapshot 来自同一 best 块的 runtime context。
- 公开 API 没有 `rpc(method, params)`、RPC URL 或预签名 extrinsic 通道。

## 热钱包

```dart
final profile = await sdk.wallet.getProfile();
final created = await sdk.wallet.create(
  wordCount: CitizenWalletWordCount.words24,
);
final imported = await sdk.wallet.importWallet();
final expanded = await sdk.wallet.addAccounts(const <int>[1, 2]);
```

`create`/`importWallet`/`addAccounts` 只启动 SDK 自有的原生安全流程：Android 使用非导出、
`FLAG_SECURE` Activity，Apple 使用共享 Darwin native flow。Dart 方法没有 mnemonic、
password、private key、DEK、prepared
handle、native handle、result handle 或 signed extrinsic 参数/返回槽位。创建的恢复词
只在备份确认前由 SDK 安全界面展示；取消会尝试 release 未提交的准备钱包。若该次释放失败，
native session 仍拥有 handle，后续 `close` 会在 destroy 前重试并在仍失败时关闭失败，不能直接
销毁或把该 handle 遗忘在 Core 外。

其它钱包操作：

```dart
await sdk.wallet.setActiveAccount(accountId);
await sdk.wallet.renameAccount(accountId: accountId, name: '旅行钱包');
await sdk.wallet.deleteAccount(accountId);
await sdk.wallet.delete();
await sdk.wallet.reconcileCleanup();
```

账户名在 Dart 端先修剪，再以 1..30 个 Unicode scalar 的规范形式编码。全钱包删除
必须同时完成密文墓碑与 generation 永久退役；物理清理未完时由
`reconcileCleanup` 重放，不得把空槽视为已安全删除。

## sr25519 本地签名

```dart
final signature = await sdk.wallet.sign(
  accountId: accountId,
  payload: Uint8List.fromList(protocolPayload),
);
```

payload 长度允许 `0..16 MiB`，空载荷是有效的明确消息。签名 context 固定为 `substrate`。通用 payload
签名把宿主应用视为受信任调用方；TUYU 等业务协议的 domain、challenge、序列化
和服务端授权记录仍由业务协议负责，不是 CitizenSDK 交易协议。

## 链上转账与历史

```dart
final terminal = await sdk.transactions.transferWithRemark(
  sourceAccountId: source,
  destinationAccountId: destination,
  amountFen: BigInt.from(1250),
  remark: '公开备注',
);
```

这是唯一高层钱包交易入口。Core 在 Rust 内完成 nonce/runtime 读取、V4
extrinsic 构造、sr25519 签名、本地 hash、pending-before-broadcast、submit-and-watch
和 finalized 执行核验。Future 只返回下列明确终态：

- `finalizedSuccess`：精确 extrinsic index 存在 `System.ExtrinsicSuccess`。
- `finalizedFailed`：同 index 存在 `System.ExtrinsicFailed`。
- `poolRejected`：交易池明确 `Invalid` 或 `Usurped`。

txHash、`Ready`、`Broadcast`、`InBlock` 或 provider `Finalized` 都不等于链上执行成功。
`sdk.events` 还会返回与 Dart request sequence 精确关联的进度和终态事件；
`Usurped` 保留替代交易哈希。取消、断网、dropped/retracted 或 timeout 不会删除
已持久的 Pending/InBlock 事实。

finalized 历史使用：

```dart
final initial = await sdk.transactions.initializeFinalizedHistory(accountIds);
final next = await sdk.transactions.syncFinalizedHistory(accountIds);
```

`accountIds` 必须包含 1..1990 个规范 AccountId，且整份列表不得重复。Dart 在建立 session 请求前
拒绝空列表、超限和重复项；Android Kotlin facade 与 Darwin Swift adapter 在产品 ABI 前独立
执行同一合同，不能依赖下层集合去重后猜测调用方意图。

历史包含逐账户游标、本机 pending/终态记录和经 Runtime metadata 解码的 finalized
转账流水。调用方只获得公开事实，不获得秘密、签名 payload 内部状态或原始
signed extrinsic。

## Flutter 传输协议

Flutter 内部通道固定为：

```text
MethodChannel  citizen/sdk/core/v1
EventChannel   citizen/sdk/events/v1
```

22 个方法的请求、响应、事件、错误及所有嵌套值都是固定长度、固定位置的
`List` tuple。任意层级的 `Map`、未知枚举、额外字段、跨 session 响应、request/event
序号缺口或乱序都失败关闭，没有兼容旁路。该协议是 binding 内部实现细节，
不是业务应用应直接调用的公共 API。
数值布尔位只接受整数 `1`，拒绝浮点 `1.0`等宽松类型；session ID 长度按
1..128 个 UTF-16 code units 计算，Dart、Swift 与 Kotlin 使用同一边界，包含代理项的字符串
不能因语言各自的字符计数方式而分叉。

每个 Flutter engine 只有一个 EventChannel router；它在发出 native `open` 前先订阅，
按 session 隔离有界暂存早到事件。`open` 响应携带该 session 的准确 event baseline，Dart
建立 session 后才按序排空；不存在“每个 session 在 open 后另订阅一次”的丢事件窗口。

所有 u64/u128、时间戳与区块高度都以规范非负十进制字符串跨通道；平台 adapter 将 u32 字段
无损投影后由 Dart 再验证其范围。AccountId 与 hash 使用 `0x` 加 64 位小写十六进制字符串；
`Uint8List` 只用于 payload、签名、备注原始字节等真实字节槽。native/prepared/result handle 与
signed extrinsic 没有 tuple 位置。

## 分发状态

源码已使用 `name: citizen_sdk` 和 `version: 1.0.0`，但本步不执行 Hosted Registry
上传。首次正式发布完成前，不得对外宣称 `citizen_sdk: ^1.0.0` 已可下载。
