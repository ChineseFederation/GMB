# CitizenSDK 钱包模型

## 固定模型

CitizenSDK 固定采用一台设备一只热钱包，钱包内支持账户
`//0` 至 `//1989`。账户0是锚点，其 AccountId 同时是钱包 masterAccountId；存在兄弟账户
时禁止单独删除账户0。

CitizenWallet 冷钱包是独立产品，不属于 SDK，也不由热端保存冷钱包助记词。

## 派生与存储

```text
BIP-39 English mnemonic + optional NFKD password
        │
        ▼ substrate_bip39
master mini-secret（只在内存短暂存在）
        │
        ▼ schnorrkel hard junction //index
child mini-secret ──硬件金库──► 本地 sr25519 签名
        │
        └────────────► public key / AccountId / SS58（公开仓储）
```

助记词与母种子从不进入 `WalletRepository` 或 `SecureSeedStore`。child mini-secret 只在
当前派生与整批写入作用域内保留，并在该调用返回或抛错前统一清零；读取必须触发平台认证，
签名后再次清零。

新密文的 AAD 产品字段固定为 `citizensdk`，密文键固定在
`citizensdk.wallet.secret.*`。公开钱包状态单独使用 `citizensdk.wallet.state.v1`；
smoldot finalized database 使用 `citizensdk.smoldot.database.v1`，三者不得互相复用。

创建返回助记词仅用于用户当场备份。恢复通过重新导入助记词完成；追加账户也必须重新
输入助记词，以证明其派生账户0等于当前 masterAccountId。

## 双存储一致性

钱包公开事实和硬件金库无法进行同一个平台事务。SDK 采用以下规则：

- 创建、导入或追加账户先以 revision compare-and-swap 提交完整公开事实，并立即回读
  revision、profile 与 cleanup；只有提交胜者才能开始写 child mini-secret。
- 每次 child 写入都先把当前 AccountId 登记在本次调用的内存 `attempted` 列表；安全存储
  适配在单次写入返回前精确回读密文，服务在整批写入后逐项复核账户密文存在性，并确认
  公开事实和钱包 KEK。`attempted` 不是持久字段。
- 写入或复核失败时，先逐项删除本次尝试的 child，并在创建/导入回滚中删除本次钱包 KEK；
  每项删除后都回读存在性。只有全部秘密确认不存在后才允许 CAS 回滚公开事实。
- 任何秘密无法确认清除时保留完整公开事实，使密文始终能由 AccountId 定位；追加账户失败
  不得删除原钱包的账户0 child 或共享 KEK。设备重启后可先删除该可见钱包/账户，再重新导入。
- 删除先原子提交“删除后的公开事实 + `WalletCleanupPlan`”，再继续尝试计划中的全部账户
  child 和钱包 KEK；任一删除或回读失败都保留计划，全部确认不存在后才 CAS 清除计划。
- 进程在删除清理中退出时，下一次钱包写操作或显式 `reconcileCleanup()` 幂等重放计划。
- 清理执行前必须再次确认计划内容完全一致、目标 AccountId 已不在公开 profile 中；并发执行者
  已清除计划时，也只有删除后公开事实完全一致且 revision 已前进才能收敛为成功。

因此 `WalletRepository.commit` 必须检查 expectedRevision，并在完整记录写后回读一致才返回；
底层已经写入但 API 随后抛错时，以精确持久事实决定成功或失败。
`SecureSeedStore.deleteAccountKey/deleteWalletKey` 必须幂等，删除调用返回或抛错后都要回读。

默认 `WalletService` 和 `PreferencesWalletRepository` 的变更队列只保证同一 Dart isolate 内
跨实例串行。`SharedPreferences` 没有跨 isolate 或跨进程 CAS，SDK 不宣称该范围原子；需要
多进程写钱包的宿主必须注入具备对应原子保证的 `WalletRepository`。

CitizenSDK 不提供其它产品的密文转换、旧别名查询或删除能力。普通读取只检查
`citizensdk.wallet.secret.*`；未来任何产品切换都必须由该产品单独设计并确认，不能隐藏在
SDK 的账户读取、导入或删除路径中。

## 账户体系边界

公民链账户、TUYU 账户授权和 TuyuBooking 员工身份仍是三种业务身份：

- 公民链账户由公钥、AccountId、SS58 和链上状态定义。
- TUYU 可以选择同一公钥并调用钱包签名，但 TUYU challenge/授权记录属于 TUYU 服务。
- 员工登录属于商家上游员工账户体系，不能因设备上有钱包而自动变成链账户或管理员。

允许共用同一把用户自有 sr25519 密钥，不等于合并三套业务账户、权限或审计记录。
