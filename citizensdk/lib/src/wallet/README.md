# 无根热钱包

CitizenSDK 保持 CitizenApp 已验证的 ROOTLESS 模型：设备只保存每个 `//index` 账户的
child mini-secret，绝不保存助记词或母种子。账户公开资料与待清理计划进入
`WalletRepository`，私钥材料只进入 `SecureSeedStore`。

SDK 当前固定一只热钱包、多个账户；独立 CitizenWallet 冷钱包不在本产品范围。创建时
助记词只返回一次，恢复或追加账户要求用户重新输入助记词与可选 password。

钱包公开事实与硬件金库不能组成同一个平台事务。创建、导入和追加账户先以 revision
compare-and-swap 提交并回读完整公开事实，只有提交胜者才能写入对应 child mini-secret；
安全存储适配在单次写入返回前精确回读密文，服务在整批写入后逐项复核账户密文存在性并
确认钱包 KEK。失败回滚会先删除本次实际尝试的秘密并逐项确认不存在，全部确认后才允许
回滚公开事实；任何秘密仍无法确认清除时保留公开事实，避免产生无法定位的孤儿密文。
追加账户回滚绝不删除已有钱包共享的 KEK。

删除先原子提交删除后公开事实与 `WalletCleanupPlan`，随后继续尝试计划内全部账户 child 和
钱包 KEK，并对每项删除做存在性回读；只有全部目标确认不存在后才清除计划。下次钱包写操作
或显式 `reconcileCleanup()` 会幂等重放未完成计划。

`WalletService` 与 `PreferencesWalletRepository` 在同一 Dart isolate 内跨实例共享变更队列。
`SharedPreferences` 不提供跨 isolate 或跨进程 compare-and-swap，SDK 不把该范围描述成原子；
需要多进程宿主时必须提供具备更强原子合同的 `WalletRepository`。
