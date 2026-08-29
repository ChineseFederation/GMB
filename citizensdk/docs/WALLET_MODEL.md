# CitizenSDK 钱包模型

## 固定模型

CitizenSDK 固定采用一台设备一只热钱包，钱包内支持账户
`//0` 至 `//1989`。账户0是锚点，其 AccountId 同时是钱包 masterAccountId；存在兄弟账户
时禁止单独删除账户0。

CitizenWallet 冷钱包是独立产品，不迁入 SDK，也不由热端保存冷钱包助记词。

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

助记词与母种子从不进入 `WalletRepository` 或 `SecureSeedStore`。每个 child mini-secret
写入后立即清理调用方缓冲；读取必须触发平台认证，签名后再次清零。

新密文的 AAD 产品字段固定为 `citizensdk`，密文键固定在
`citizensdk.wallet.secret.*`。公开钱包状态单独使用 `citizensdk.wallet.state.v1`；
smoldot finalized database 使用 `citizensdk.smoldot.database.v1`，三者不得互相复用。

创建返回助记词仅用于用户当场备份。恢复通过重新导入助记词完成；追加账户也必须重新
输入助记词，以证明其派生账户0等于当前 masterAccountId。

## 双存储一致性

钱包公开事实和硬件金库无法进行同一个平台事务。SDK 采用以下规则：

- 新建或追加：先写硬件金库，再以 revision compare-and-swap 提交公开事实；提交失败则
  幂等删除刚写入的 child。
- 删除：先原子提交“删除后的公开事实 + WalletCleanupPlan”，再清理硬件金库，最后原子
  清除计划。
- 进程在清理中退出时，下一次钱包写操作先重放清理计划。

因此 `WalletRepository.commit` 必须真正原子并检查 expectedRevision；
`SecureSeedStore.deleteAccountKey/deleteWalletKey` 必须幂等。

CitizenSDK 不提供其它产品的密文迁移、旧别名查询或删除能力。普通读取只检查
`citizensdk.wallet.secret.*`；未来任何产品切换都必须由该产品另行设计迁移和回滚，不能
隐藏在 SDK 的账户读取、导入或删除路径中。

## 账户体系边界

公民链账户、TUYU 账户授权和 TuyuBooking 员工身份仍是三种业务身份：

- 公民链账户由公钥、AccountId、SS58 和链上状态定义。
- TUYU 可以选择同一公钥并调用钱包签名，但 TUYU challenge/授权记录属于 TUYU 服务。
- 员工登录属于商家上游员工账户体系，不能因设备上有钱包而自动变成链账户或管理员。

允许共用同一把用户自有 sr25519 密钥，不等于合并三套业务账户、权限或审计记录。
