# 无根热钱包

CitizenSDK 保持 CitizenApp 已验证的 ROOTLESS 模型：设备只保存每个 `//index` 账户的
child mini-secret，绝不保存助记词或母种子。账户公开资料、秘密写入计划与待清理计划进入
`WalletRepository`，私钥材料只进入 `SecureSeedStore`。

SDK 当前固定一只热钱包、多个账户；独立 CitizenWallet 冷钱包不在本产品范围。创建时
助记词只返回一次，恢复或追加账户要求用户重新输入助记词与可选 password。

钱包公开事实与硬件金库不能组成同一个平台事务。创建、导入和追加账户会先生成 CSPRNG
128 位 `walletGeneration`、每账户 `secretOwner` 与 `operationId`，再以 revision
compare-and-swap 持久化目标 profile 和完整 `WalletProvisioningPlan`。任何账户密文或 KEK
写入都发生在该计划之后。KEK 由 `walletGeneration` 独占；账户密文由
`walletGeneration + secretOwner + AccountId` 精确定位。

安全存储适配在单次写入返回前精确回读密文，服务在整批写入后复核持久计划、全部账户
密文和本代 KEK。完成计划的提交即使出现“写入后抛错”，也由完整持久事实回读收敛。
失败方必须先以 CAS 把自己持有的 provision 转成同一精确身份的 cleanup，取得计划后才可
删除。若另一执行者已完成过清理，而本执行者的 secret 随后才迟到落地，本执行者在写入
返回后会把同一精确 cleanup 以 CAS 加入 `cleanupQueue`；队列计划可与不相交的
当前 profile/provisioning 并存，只能命中自己的 generation/owner，不会删除
随后成功的钱包或同 AccountId 的另一代秘密。清理失败时计划保持持久化，供后续重放。
追加账户的 rollback 只包含新增账户 owner，绝不删除钱包 KEK。

删除先以 CAS 提交删除后公开事实与 `WalletCleanupPlan`，随后继续尝试计划内全部账户 child
和指定 generation 的钱包 KEK，并对每项删除做存在性回读；只有全部目标确认不存在后才清除
计划。下次钱包写操作或显式 `reconcileCleanup()` 会幂等重放未完成计划。

`WalletService` 与 `PreferencesWalletRepository` 在同一 Dart isolate 内跨实例共享变更队列。
该默认合同下，写者进入金库期间其 provisioning 不会被另一 SDK 实例清除；进程
中断会留下预先持久化的计划，新实例可精确重放。

`SharedPreferences` 不提供跨 isolate 或跨进程 compare-and-swap，SDK 不把该范围描述成原子、
线性化或零孤儿密文。generation/owner 仍保证物理删除不会越权命中另一代秘密；
`cleanupQueue` 只能在迟到写调用恢复执行后做精确补偿。需要跨执行引擎支持的宿主必须
同时提供强原子仓储，以及覆盖计划提交、金库写入、确认与回滚的全操作单写协调。
