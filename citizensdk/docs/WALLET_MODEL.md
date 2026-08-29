# CitizenSDK 钱包模型

## 固定模型

CitizenSDK 在一台设备上管理一只无根热钱包，钱包内支持账户 `//0` 至 `//1989`。账户0是
锚点，其 AccountId 同时是 `masterAccountId`；存在兄弟账户时不能单独删除账户0。
CitizenWallet 冷钱包是独立产品，不属于 SDK。

## 派生与存储

```text
BIP-39 English mnemonic + optional NFKD password
        │
        ▼ substrate_bip39
master mini-secret（仅在内存短暂存在）
        │
        ▼ schnorrkel hard junction //index
child mini-secret ──设备硬件金库──► 本地 sr25519 签名
        │
        └────────────► public key / AccountId / SS58（公开仓储）
```

助记词和母种子从不进入仓储。创建只在返回值中一次性显示助记词；SDK 不提供再次导出。
恢复和追加账户要求用户重新输入原助记词及可选 password。追加还会校验派生账户0等于当前
`masterAccountId`，并在改写公开事实前确认钱包 KEK 和所有既有账户 child 完整存在。该确认
不是只看密文存在：服务会实际解密账户0 child、重新派生公钥/AccountId、与公开锚点逐字节
比对并立即清零明文字节；生物集合变化、失效 KEK 或错配锚点都在提交公开事实前失败。

## 双存储一致性

公开事实仓储与硬件金库不能共享平台事务，SDK 使用以下次序：

1. 创建、导入或追加先生成 CSPRNG 128 位 `walletGeneration`、每账户 `secretOwner` 和
   `operationId`。它们不使用时钟或 revision 充当唯一身份。
2. 以 expected revision 执行 compare-and-swap，在任何秘密写入前持久化并回读完整 profile、
   revision 和 `WalletProvisioningPlan`。计划包含 previous profile 与本操作全部精确秘密引用。
   仓储若在真实写入后抛错，也必须以回读的精确持久事实判断该次 CAS 是否已经成功，避免
   `addAccounts` 把已经提交的当前账户漏出后续处理。
3. 只有 provisioning 胜者可以写账户 child。KEK 由 `walletGeneration` 独占；child 密文由
   `walletGeneration + secretOwner + AccountId` 精确定位。AAD 还认证秘密类型。
4. 每次写后由安全存储适配回读密文，整批完成后服务再次逐项确认持久计划、账户密文和本代
   钱包 KEK；随后以 CAS 清除 provisioning。完成提交的写后抛错由回读事实收敛为成功。
5. 写入或确认失败时，失败方先以 CAS 把自身 provisioning 转成相同 operation/generation/
   owner 的 cleanup，取得计划后才删除。若越出默认单 isolate 合同的另一执行者先完成
   清理而 secret 后落地，还在运行的失败方会把同一 exact cleanup 加入与当前事实不相交的
   `cleanupQueue`，再只删除自身物理身份。
6. 清理无法确认时保留 cleanup 供重放。追加失败只处理新批 owner，绝不删除原钱包账户0
   child 或钱包 KEK。

删除采用持久计划：先提交删除后的公开事实和 `WalletCleanupPlan`，再尝试计划中的全部账户
child 与钱包 KEK。删除接口必须幂等，每项操作后回读；任一失败都保留计划，下一次钱包写
操作或 `reconcileCleanup()` 会重放。active cleanup 与 `cleanupQueue` 中每项都必须结构完整、
操作标识唯一、物理目标不重复，且不得删除当前 profile 的 KEK 或引用其中任何
exact account secret。队列最多 64 项，超限状态失败关闭。

钱包变更和 `sign` 使用同一静态队列，在同一 Dart isolate 内跨实例串行。签名读取 child 后
会再次确认目标账户仍存在，并在签名成功、公钥不匹配或异常路径中统一清零。该队列不扩大
到其它 isolate 或进程；默认合同的进程中断会保留 secret 写入前已持久化的 provisioning，
新实例据此恢复。CSPRNG generation/owner 保证物理清理不会越权命中另一代秘密。
标准 Preferences 装配不承诺跨执行引擎线性化或零孤儿密文；该范围必须同时提供强原子仓储与
覆盖计划、金库写入、确认和回滚的全操作单写协调。

`usableProfile` / `isUsable` 也进入同一队列：它们不把公开 profile 存在误当成热钱包可用，
而是验证账户0锚点、钱包 KEK，并逐个解密 profile 的全部 child、重算 sr25519 公钥与
AccountId，最后回读并核对 profile、provisioning 与 active cleanup 的语义事实，防止长认证
窗口返回过期事实。不存在或秘密缺失/错配返回不可用，安全存储和仓储后端异常继续上抛；
所有读取的 child 都在 `finally` 清零。

账户名称是本机公开事实。`renameAccount` 只提交修剪后 1..30 个 Unicode scalar 的名称，使用
相同 revision CAS 与精确回读；未知账户、遗留 cleanup plan 或并发删除均失败关闭，不读取、
改写或恢复任何密文。

## API 与宿主边界

标准移动装配使用固定 `citizensdk` 硬件金库。公共 API 同时允许注入
`SecureSeedStore`，这是给受控宿主、测试和未来平台移植的高级能力；自定义实现可以观察
child mini-secret，因此宿主属于可信计算基。不能把“SDK 默认不上传”误写为“任意宿主都
无法读取”。

SDK 不读取、转换或删除其它产品的密文。普通读取只访问
`citizensdk.wallet.secret.*`；任何其它产品的数据切换都必须单独设计和批准。

用户明确请求时，`getAccountPrivateKey` 可以从硬件金库读取并导出所选账户的 child
mini-secret，固定编码为 `0x` 加 64 位小写十六进制。它不导出助记词或母种子，返回前再次
核对公开账户和派生公钥，内部字节随后清零；但返回的 Dart `String` 不可擦除。因此宿主必须
提供风险确认、防截屏和即时展示，禁止把结果写入日志、默认剪贴板、磁盘或网络。

## 三种账户边界

- 公民链账户由公钥、AccountId、SS58 和链上状态定义。
- TUYU 账户授权可以选择同一公钥并调用钱包签名，但 challenge、授权记录和服务端会话属于
  TUYU 账户体系。
- TuyuBooking 员工登录属于商家上游员工账户体系，不因设备存在钱包而自动成为链账户或
  管理员。

允许同一用户复用一把 sr25519 密钥，不等于合并三套业务账户、权限和审计记录。
