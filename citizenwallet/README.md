# 公民钱包

`CitizenWallet` 是公民体系的离线冷钱包。应用不声明网络权限，使用二维码接收
`QR_V1` 请求并离线签名；SS58 地址仅用于展示和边界输入输出，签名与授权使用
`AccountId`。

## 安全边界

- 助记词和 32 字节 master `MiniSecretKey` 只以可擦除字节数组进出
  `shared/hardware-secretvault`；Secure Storage 只保存 Base64 硬件信封密文。
- Android 使用 StrongBox/TEE RSA-2048 OAEP KEK，每次解密由强生物识别
  `CryptoObject` 原子授权；iOS 使用 Secure Enclave P-256 ECIES，访问控制
  固定为 `biometryCurrentSet + privateKeyUsage`，不回退设备密码。
- 每只钱包使用独立硬件 KEK，AAD 同时绑定产品、`masterId`/`AccountId`
  与机密类型；跨产品、跨钱包、跨类型替换和密文篡改全部失败关闭。
- 创建、导入、查看根机密、删除和签名前强制使用指纹或面容认证，不回退设备密码。
- 创建、导入或删除失败时逐项尝试清理 master 密文、助记词密文和硬件
  KEK；全部清理并回读通过后才删除 Isar 事实行。
- 钱包可选 Substrate BIP-39 `password` 由 `shared/wallet-password` 单源校验和
  派生；非空值为 6–30 位，不持久化。`substrate_bip39` 声明统一为
  `^0.7.0`，实际解析补丁版本由各应用 `pubspec.lock` 锁定。
- 链上签名必须严格匹配正式 `genesis_hash` 和支持的 `transaction_version`；
  `spec_version` 只解析展示，不要求 App 在每次 runtime 升级后同步升级。
- 助记词、私钥和签名响应二维码页面进入后及时启用引用计数式截屏/录屏保护，
  转入后台立即隐藏敏感内容。
- 普通扫码签名与登录扫码签名的请求 id 均在本地持久化原子占位；重复或已过期请求
  在生物识别和私钥调用前拒绝，认证或签名失败会释放占位供用户重试。
- 设置中的应用锁可配置独立 6 位 `duress_mode` 密码，且不得与普通应用锁密码相同。
  启动或重新锁定时单次输入该密码不会累计普通错误次数，第六位命中后先写持久 pending
  门闩，立即封锁、后台擦除并退出前台，全程不显示任何弹窗，也不存在等待或二次输入状态。
  擦除先删除并回读每只钱包的硬件 KEK，再删除
  WalletIsar、Secure Storage 与偏好；中断后下次启动只能继续擦除，完成后回到全新初始化状态。
- 普通应用锁 PIN 与公民统一使用随机盐及 100,000 次 PBKDF2-HMAC-SHA256，`duress_mode`
  PIN 使用独立随机盐及 10,000 次；派生在辅助 isolate 中执行，普通密码命中只执行一次，
  未命中后才识别防共匪密码。数字键盘按下即记录并把触觉反馈移出输入关键路径。

## 密钥关系

`助记词 → 32B 主种子 → //index 硬派生 → 账户私钥 → sr25519 公钥 / AccountId
→ SS58 展示地址`

应用内“设置 → 产品手册”提供对应的图形化说明。

## 本地验证

```bash
flutter analyze
flutter test
```

Android 共享硬件金库的原生单元测试只运行 Release 变体。真机构建、签名、
安装与证书回读只能通过 TataConsole 正式入口执行，不得把未签名候选
当作交付结果。QR registry 与仓库守卫使用 Release profile 验证：

```bash
cargo test --release -p qr-protocol
```
