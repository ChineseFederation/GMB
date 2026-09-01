# CitizenSDK Dart/Flutter 公共接口

## 包入口

宿主统一导入：

```dart
import 'package:citizen_sdk/citizen_sdk.dart';
```

`CitizenSdk` 组合：

- `chain`：设备进程内的公民链 smoldot 轻节点。
- `rpc`：只依赖该轻节点的公民链读取与交易状态核对。
- `wallet`：一只无根热钱包、多个 `//index` 账户和本地 sr25519 签名。
- `transfers`：公民链 `transfer_with_remark` 构造、签名、广播和执行结果核对。
- `transactionHistory`：可选的 finalized 流水、pending 提交与逐账户游标仓储状态机。
- `transactionScanner`：可选的 finalized 增量扫描和本机 pending 收敛器。
- `signer`：公钥验签。

`CitizenLightClient` 公共方法使用的同步状态与账户快照类型由同一
`package:citizen_sdk/citizen_sdk.dart` 入口导出；调用方不需要也不应导入内部 smoldot 路径。

聊天、广场、TUYU v1 消息编码、旅行商品、预订和宿主导航不在公共 API 内。

## 第 2 步过渡边界

第 2 步没有修改上述 Dart 公共接口或其运行语义。`native/contracts` 与 `native/engine` 已经
建立 Rust Core 的类型化合同和核验规则，但当前 `CitizenSdk` 仍由 Dart 直接协调钱包、交易、
历史与内嵌 smoldot 绑定。第 3 步才建立产品级唯一 `citizensdk_*` C ABI，并设计 Dart 改接和
删除绕过 Engine 的公开路径；在此之前不得把 Rust Core 的存在写成 App 已经使用它。

同样，目标秘密生命周期虽然是 `SecretVault -> Rust SecretBuffer -> ChainSigner -> zeroize`，
当前移动实现仍保留既有 Dart 钱包与平台通道路径。助记词、child mini-secret 或私钥是否经过
Dart 的事实没有在本步骤改变；本文件现有关于 Dart `Uint8List`、不可擦除 `String` 和受信任
宿主注入的风险约束继续全部适用。

## 构造与信任边界

Android/iOS 标准装配：

```dart
final sdk = CitizenSdk.mobile();
await sdk.start(waitUntilSynced: true);
```

受控宿主和测试也可以注入存储：

```dart
final sdk = CitizenSdk(
  walletRepository: repository,
  secureSeedStore: secureSeedStore,
  chainDatabaseStore: chainDatabaseStore,
);
```

- `WalletRepository` 保存公开 profile、revision、provisioning plan、active cleanup 和 exact
  cleanup queue；实现必须
  按自身声明的并发范围提供 revision compare-and-swap。
- `SecureSeedStore` 保存并读取账户 child mini-secret。
- `ChainDatabaseStore` 保存不含秘密的 smoldot finalized database。
- `FinalizedTransactionRepository` 原子保存 finalized 流水、pending 与逐账户游标。

这些接口是高级注入边界，不是对恶意宿主的秘密隔离。自定义 `SecureSeedStore` 能观察传入
的 child mini-secret，因此宿主进程及其注入实现必须被视为受信任计算基；普通产品应使用
`CitizenSdk.mobile()` 的标准硬件金库装配。

标准装配使用 `PreferencesWalletRepository`、`HardwareBoundSeedStore`、
`PreferencesChainDatabaseStore` 与 `PreferencesFinalizedTransactionRepository`。硬件产品
标识固定为 `citizensdk`，不接受宿主产品名或其它产品金库读取开关。

标准 Preferences 钱包仓储在同一 Dart isolate 内串行 CAS，不宣称跨 isolate/进程线性化。
钱包和账户的 CSPRNG generation/owner 会进入 KEK、密文键与 AAD，使迟到清理只能命中自己
持有的物理身份。`cleanupQueue` 在迟到写调用恢复执行后持久精确补偿，但不覆盖该写已
落地、补偿 CAS 尚未执行时的跨引擎崩溃。需要跨执行引擎支持的宿主必须同时提供
强原子仓储和覆盖整个钱包操作的单写协调。

## 轻节点

`CitizenLightClient` 从随包 `assets/citizenchain` 中的 `manifest.json`、`chainspec.json`
和 `light_sync_state.json` 启动。加载器先核对正式 `citizenchain` 链/协议 ID、两个资产
SHA-256、genesis hash 和 checkpoint state root，再把链规格交给 smoldot；任一不一致都在
创建或初始化 smoldot 原生客户端前失败关闭。客户端仍可读取
`/chain/citizensdk/bootstrap` 的 bootnode 建议。远端清单只接受
`citizensdk.chain.bootstrap`，不能下发通用 RPC URL、链状态 checkpoint、聊天或业务服务。
根对象以及 `chain`、`light_client`、`p2p`、`security` 四个嵌套对象都执行精确字段闭集校验，
未知或缺失字段一律拒绝；聊天、广场、TUYU、宿主产品字段因此不能混入。finalized 状态必须由
设备内 smoldot 从 P2P 网络验证。

宿主可通过 `health`、`healthChanges`、新链头与 finalized 链头订阅展示状态。数据库导出只
保存单调前进的 finalized anchor；启动失败、同步失败、订阅丢失和数据库损坏均显式报错或
回退到随包锚，不伪造“已同步”。

## 钱包与协议签名

创建钱包一次性返回助记词：

```dart
final created = await sdk.wallet.create(wordCount: 12);
final mnemonicShownOnce = created.mnemonic;
```

SDK 不持久化助记词或母种子，也不提供再次导出。恢复和追加账户要求用户重新输入助记词及
原可选 password；追加前会确认钱包 KEK、所有既有账户 child 和派生账户0均与当前钱包一致，
还会真实解密账户0 child、重算公钥/AccountId、核对公开锚点并立即清零明文字节。

创建、导入和追加会在任何秘密写入前持久化 `WalletProvisioningPlan`。钱包 KEK 使用独占
`walletGeneration`，每个账户密文使用独占 `secretOwner`。在默认单 isolate 串行合同内，
写入失败、写后抛错和进程中断都按预存计划 exact cleanup 回收；越界交错中存活写者的
迟到写入用 `cleanupQueue` 精确补偿。清理计划没有经 CAS 取得前不得删除，且不能命中
当前 profile 的 KEK 或 exact account secret。

宿主进入钱包页前可以执行完整硬件门禁，并可原子修改本机账户名：

```dart
final profile = await sdk.wallet.usableProfile;
if (profile != null) {
  await sdk.wallet.renameAccount(profile.activeAccountId, '日常账户');
}
```

`profile` 只读公开事实；`usableProfile` / `isUsable` 才会在全实例串行队列中验证账户0锚点、
钱包 KEK 和 profile 的每个 child。钱包不存在、秘密缺失或公钥错配返回不可用；金库、认证或
仓储异常原样上抛，不能伪装为“没有钱包”。

上层协议可以请求账户本地签名：

```dart
final signature = await sdk.wallet.sign(accountId, protocolPayload);
```

签名与创建、追加、删除等钱包操作在同一 Dart isolate 内跨实例串行；读取 child 后会再次
确认账户仍存在，并在成功或失败时清零内存字节。TUYU 客户端可以使用该签名能力，但 TUYU
domain、版本、challenge、消息序列化和服务端授权记录仍由 TUYU 实现，不能冒充链交易协议。

CitizenApp 已有的用户主动子账户私钥查看能力由同一钱包服务提供：

```dart
final privateKey = await sdk.wallet.getAccountPrivateKey(accountId);
```

返回值固定为 `0x` 加 64 位小写十六进制，只对应所选 `//index` 的 child mini-secret，不是
助记词或母种子。Dart `String` 不可原地擦除；产品必须先取得明确风险确认，只在防截屏界面
即时展示并尽快丢弃引用，禁止日志、剪贴板默认复制、持久化或上传。SDK 会在返回前复核
AccountId，并在成功和异常路径清零内部字节。

## Finalized 余额与手续费

```dart
final balance = await sdk.rpc.fetchFinalizedAccountBalance(accountId);
final total = balance.totalFen; // freeFen + reservedFen
final batch = await sdk.rpc.fetchFinalizedAccountBalances(<String>[
  accountId,
  citizenSs58Address,
]);
final fee = await sdk.transfers.estimateTransferFeeFen(BigInt.from(1250));
```

余额只读设备轻节点验证的 finalized `System.Account`；批量入口先规范化并去重 storage key，
通过一次轻节点 batch storage 读取后按原输入顺序和重复项重建不可变结果。不存在或短于完整
`free/reserved` 布局的值按零处理，传输异常不会伪装成零。手续费只读取同一 runtime metadata
中的 `OnchainFeeRate` 与 `OnchainMinFee`，严格按 runtime 的 Perbill、u128 饱和与 half-up
规则计算，不使用本地费率兜底。

## 链上转账

立即返回 txHash 并在后台观察：

```dart
final submitted = await sdk.transfers.transferWithRemark(
  fromSs58Address: sender.ss58Address,
  signerPublicKey: citizenAccountIdBytes(sender.accountId),
  toSs58Address: receiverAddress,
  amountFen: BigInt.from(1250),
  remark: '午餐',
  sign: (payload) => sdk.wallet.sign(sender.accountId, payload),
  onStatus: handleStatus,
);
```

`submitted.txHash` 只表示 `author_submitExtrinsic` 已由本机轻节点接受。后台状态只有
`executionSuccess` 才表示核对到同一 extrinsic 的 `System.ExtrinsicSuccess`。收到有效
`finalized` 后，后台观察由 System.Events 核对独占终态；交易池流随后到达的状态、解析错误、
订阅错误或关闭不会再覆盖执行结果。未 finalized 的流关闭、观察超时或缺失区块哈希会明确
报告“未核实”，不会静默结束。

`onStatus` 是 best-effort 观察者：同步抛错、异步未处理错误以及订阅 `cancel()` Future 的失败
都被隔离，不能阻断定时器、Completer 或形成第二个交易终态。runtime version 与 metadata
固定在同一块读取并按 `specVersion` 换代；长驻 App 跨 runtime 升级时不会把前一代 registry 与
新 `transactionVersion` 拼接签名。

需要调用方等待明确执行结果时使用：

```dart
final included = await sdk.transfers.transferWithRemarkAndWait(
  fromSs58Address: sender.ss58Address,
  signerPublicKey: citizenAccountIdBytes(sender.accountId),
  toSs58Address: receiverAddress,
  amountFen: BigInt.from(1250),
  remark: '午餐',
  sign: (payload) => sdk.wallet.sign(sender.accountId, payload),
  waitForFinalized: true,
);
```

该入口按 txHash 定位目标块中的 extrinsic index，再核对同 index 的
`System.ExtrinsicSuccess/Failed`。失败抛 `TransactionDispatchException`；在受控窗口内没有
明确事件时抛 `TransactionExecutionUnverifiedException`。`inBlock` 可能回退，只有
`waitForFinalized: true` 才要求 finalized 锚。金额单位为整数分，备注最长 99 个 UTF-8
字节。

## Finalized 流水与 pending 收敛

移动标准装配默认启用交易流水仓储。钱包账户集合变化后，由宿主在已进入钱包会话的明确时机
同步监控集合：

```dart
await sdk.syncWalletTransactionHistory();
final state = await sdk.transactionHistory!.load();
final accountTransfers = state.transfers.values.where(
  (entry) => entry.accountId == activeAccountId,
);
```

首次纳入的账户以调用时 finalized 高度为起点，不回读钱包导入前历史；已有游标在重启后补齐
缺口，每轮最多 120 块并继续调度。不同账户可以有不同起点，已有账户补历史时不会把加入前块流水
写给刚加入的新账户。扫描只消费目标块 metadata 解出的 `OnchainTransaction` 与 `Balances`
转账事件；块事件、pending outcome 与游标在同一次 CAS 中提交，任何不完整事实都会保留游标
等待重试。

标准 `TransferService` 在广播前先持久化 txHash、nonce、from/to、金额和备注。交易池的
`invalid/usurped` 是无块锚的 `poolRejected`；`inBlock/finalized` 仅保存定位锚；只有同一
extrinsic index 的 `System.ExtrinsicSuccess/Failed` 才写入链上终态。明确 finalized 链证据
高于先前交易池拒绝线索。本机提交被 txHash 认领后不重复生成转出 event 流水，接收方流水
仍正常发现。

自定义装配可省略 `transactionRepository` 以明确关闭该能力，或注入更强的跨进程仓储。
内置 Preferences 实现提供严格 schema、单 isolate 串行 CAS 与写后回读收敛；它不宣称跨
isolate/进程原子。

## 当前平台声明

公共分层可扩展到桌面平台，但当前正式插件和 Release 只包含 Android ARM64 与 iOS ARM64。
macOS、Linux、Windows 在各自插件、安全金库和打包验收完成前不能使用“已支持”口径。
