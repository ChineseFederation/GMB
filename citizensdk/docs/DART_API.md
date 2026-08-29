# CitizenSDK Dart/Flutter 公共接口

## 包入口

宿主应用统一导入：

```dart
import 'package:citizen_sdk/citizen_sdk.dart';
```

`CitizenSdk` 是单产品门面，组合四类能力：

- `chain`：进程内公民链 smoldot 轻节点。
- `wallet`：单热钱包、多 `//index` 账户的本地生命周期与签名。
- `transfers`：公民链 `transfer_with_remark` 构造、签名与提交。
- `signer`：使用公开公钥执行 sr25519 验签。

聊天、广场、TUYU v1 消息编码、旅行商品、预订和宿主导航不在公共接口内。

## 构造与依赖

```dart
final sdk = CitizenSdk(
  walletRepository: repository,
  secureSeedStore: secureSeedStore,
  chainDatabaseStore: chainDatabaseStore,
);
await sdk.start(waitUntilSynced: true);
```

Android/iOS 宿主可以使用标准装配：

```dart
final sdk = CitizenSdk.mobile();
await sdk.start(waitUntilSynced: true);
```

也可以自行注入三种存储接口：

1. `WalletRepository` 原子保存公开钱包资料、revision 和清理计划。
2. `SecureSeedStore` 把 child mini-secret 保存到平台硬件金库。
3. `ChainDatabaseStore` 保存不含秘密的 smoldot finalized database 信封。

`CitizenSdk.mobile()` 使用 `PreferencesWalletRepository`、`HardwareBoundSeedStore` 和
`PreferencesChainDatabaseStore`。`HardwareBoundSeedStore` 的产品标识固定为
`citizensdk`，不能由宿主传入。macOS、Linux、Windows 必须在各自硬件安全方案单独获准
后接入；没有安全金库实现时钱包创建、导入和签名必须失败关闭，但轻节点公开查询仍可用。

移动装配不接受产品名或旧金库迁移开关。SDK 只读写 `citizensdk` 信封；任何宿主产品迁移
必须在宿主切换步骤中单独设计，不进入 CitizenSDK 公共 API。

## 轻节点

`CitizenLightClient` 默认从公民网 `/chain/citizensdk/bootstrap` 获取 bootnode 建议，且只
接受 `citizensdk.chain.bootstrap`。清单不包含广场、聊天、媒体或宿主交易中继字段；失败时
回退到随包 `chainspec.json`。远端清单不是链状态真源，不得下发 RPC URL 或 checkpoint；
finalized 状态只能由本机 smoldot 从 P2P 网络验证。

宿主通过 `health` 与 `healthChanges` 展示同步状态。只有 `operational` 且 `isUsable=true`
才表示完整验证的 finalized chain information 已经可用。

## 钱包与协议签名

创建钱包一次性返回助记词：

```dart
final created = await sdk.wallet.create(wordCount: 12);
final mnemonicShownOnce = created.mnemonic;
```

恢复和追加账户需要重新输入助记词及原可选 password。SDK 不提供“再次导出助记词”，因为
设备从未持久化母种子或助记词。

任意上层协议使用钱包账户本地签名：

```dart
final signature = await sdk.wallet.sign(accountId, protocolPayload);
```

这使 TUYU v1 客户端能够复用同一 sr25519 钱包密钥，但 TUYU 的 domain、版本、challenge
和消息序列化仍由 TUYU 客户端实现，不能冒充公民链 extrinsic 协议。

## 链上转账

```dart
final submitted = await sdk.transfers.transferWithRemark(
  fromSs58Address: sender.ss58Address,
  signerPublicKey: citizenAccountIdBytes(sender.accountId),
  toSs58Address: receiverAddress,
  amountFen: BigInt.from(1250),
  remark: '午餐',
  sign: (payload) => sdk.wallet.sign(sender.accountId, payload),
);
```

金额必须以整数分传入。返回 txHash 只表示轻节点已接受提交；应用必须继续消费
`TransactionStatus`，或使用等待入块接口，不能把 txHash 当作最终成功。
