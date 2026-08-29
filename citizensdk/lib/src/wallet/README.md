# 无根热钱包

CitizenSDK 保持 CitizenApp 已验证的 ROOTLESS 模型：设备只保存每个 `//index` 账户的
child mini-secret，绝不保存助记词或母种子。账户公开资料与待清理计划进入
`WalletRepository`，私钥材料只进入 `SecureSeedStore`。

SDK 当前固定一只热钱包、多个账户；独立 CitizenWallet 冷钱包不在本产品范围。创建时
助记词只返回一次，恢复或追加账户要求用户重新输入助记词与可选 password。
