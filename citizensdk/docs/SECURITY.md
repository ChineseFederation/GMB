# CitizenSDK 安全模型

## sr25519 固定口径

- 唯一实现是 `native/signer` 中的 `schnorrkel`，不增加纯 Dart 或自研实现。
- mini-secret 扩展模式固定为 `ExpansionMode::Ed25519`。
- 签名 context 固定为字节串 `substrate`。
- 硬派生 chain code 按 Substrate junction 规则生成。
- mini-secret、展开后的 SecretKey 和签名临时字节在作用域结束时清零。
- signer FFI 用 `catch_unwind` 把 panic 转为错误码；FFI Release profile 不允许破坏该契约。

## 设备机密与受信任宿主

助记词、母种子、child mini-secret 和私钥不得上传到 TuyuServe、TuyuBooking、Cloudflare、
GitHub、Console 或任何远端服务。标准移动装配只在用户设备硬件金库保存 child 密文，并在
本地认证、解密和签名。

Android 使用硬件 RSA-OAEP KEK、AES-256-GCM 与逐次 `BIOMETRIC_STRONG`；iOS 使用 Secure
Enclave ECIES、`biometryCurrentSet + privateKeyUsage` 与
`WhenUnlockedThisDeviceOnly`。产品标识、AAD、硬件别名和密文命名空间固定为
`citizensdk`。每代钱包 KEK 别名绑定 `walletGeneration`；每份账户信封和密文键同时绑定
`walletGeneration`、`secretOwner`、AccountId 与秘密类型。

公共 API 保留 `WalletRepository`、`SecureSeedStore` 和平台组件注入，以支持受控宿主、
测试和未来平台适配。这意味着宿主进程是信任边界：恶意自定义 `SecureSeedStore` 可以复制
SDK 交给它的 child mini-secret。SDK 保证自身标准实现不上传秘密，但不能对同进程恶意宿主
提供硬隔离；产品接入必须审计注入点，普通应用应使用 `CitizenSdk.mobile()`。

没有合格硬件金库或设备能力时必须失败关闭钱包创建、导入、追加账户、签名和签名交易；
公开轻节点查询与公钥验签仍可用。

## 钱包一致性

- `WalletRepository` 只保存公开 profile、revision、provisioning plan、active cleanup 和
  不相交的 exact cleanup queue。
- `SecureSeedStore` 每个账户只保存 `//index` child mini-secret。
- 创建、导入、追加账户先预检强生物识别，再为钱包、账户秘密和操作生成 CSPRNG 128 位身份；
  在任何秘密写入前用 revision CAS 提交并回读目标 profile 与完整 provisioning plan。
- 仓储正常返回或“写入后抛错”都必须由回读的 revision/profile/provisioning/cleanup/
  cleanup queue 决定真实提交结果。
- 追加前必须确认钱包 KEK 与当前 profile 的每个既有账户 child 都存在，避免在不可恢复的
  缺失秘密上继续扩大钱包；还必须实际解密并核对账户0锚点，确保生物集合变化没有使先前
  KEK 失效，随后立即清零锚点明文。
- 每个 child 由 `walletGeneration + secretOwner + AccountId` 精确定位；写后逐项确认账户密文
  与本代钱包 KEK。
- 失败方必须先以 CAS 把自己持有的 provisioning 转成 exact cleanup，取得计划后才可删除。
  若越出默认单 isolate 合同的另一执行者先清除计划而 secret 随后落地，还在运行的失败方
  会把同一 exact cleanup 加入与当前事实不相交的 queue；只能删除自身 generation/
  owner。清理失败时计划保持可重放。
- 删除先持久化 cleanup plan，再幂等删除全部账户 child 与钱包 KEK，并逐项回读；未完成计划
  必须保留并可在重启后重放。
- 钱包变更与 `sign` 在同一 Dart isolate 内跨 `WalletService` 实例串行；签名前再次确认账户
  仍存在，成功或失败均清零读取的 child。
- `usableProfile` / `isUsable` 不只读取公开 profile，而是验证账户0、KEK 及全部 child 的
  sr25519 公钥；后端异常上抛，不能把认证、金库或仓储故障伪装成“无钱包”。
- `renameAccount` 只经 revision CAS 修改公开名称；cleanup 未完成或并发删除时失败关闭，绝不
  代为创建、恢复或删除秘密。
- `getAccountPrivateKey` 只在用户主动请求后导出所选 child。内部 `Uint8List` 会清零，但返回的
  Dart `String` 不可擦除；宿主必须负责风险确认、防截屏、禁日志/持久化/上传和尽快丢弃引用。
- 标准合同仅在同一 Dart isolate 内跨实例串行；进程中断会保留 secret 写入前已提交的
  provisioning，新实例可精确重放。SharedPreferences 不承诺跨 isolate 或跨进程 CAS；
  generation/owner 仍提供不越权的物理隔离，但 queue 不能覆盖迟到物理写成功后、
  其补偿 CAS 之前的跨引擎崩溃。需要该范围的宿主必须同时提供强原子仓储和覆盖整个钱包操作
  的单写协调；否则不承诺跨引擎线性化或零孤儿密文。

## 轻节点与交易

公民链状态由设备内 smoldot P2P 轻节点验证。Bootstrap 只能提供固定 schema 下的链身份与
bootnode 建议；根对象及 `chain/light_client/p2p/security` 都必须精确匹配字段闭集，不能夹带
聊天、广场、TUYU、宿主业务、远程 RPC 或链状态真源。SDK 不实现服务器签名或通用 RPC 代理。

`author_submitExtrinsic` 返回 txHash、peer 广播、`inBlock` 和 `finalized` 都不能单独证明
runtime 执行成功。SDK 必须按 txHash 定位同一 extrinsic index，并读取该 index 的
`System.ExtrinsicSuccess/Failed`；未找到明确结果时报告未核实。收到 finalized 后由执行核对
独占后台终态，订阅流的迟到数据和错误不能形成与执行结果冲突的第二终态。

runtime version 与 metadata 必须在同一 finalized/目标块上读取并按 `specVersion` 绑定缓存；
前一代 in-flight 请求迟到不能覆盖新缓存。余额批量读取只走轻节点 finalized batch storage，
手续费只信任同一 metadata 的链上常量。状态观察回调和订阅取消 Future 的异常均为
best-effort 隔离，不能泄漏未处理错误或改变交易终态。

公民链账户签名、TUYU challenge 签名和 TuyuBooking 员工登录是不同业务权限。它们可以在
明确设计下使用同一用户 sr25519 公钥，但不得合并账户、授权或审计记录。

## 原生产品边界

全节点 `author` 出块代码、identity keystore 和 seed phrase 私钥入口不进入 CitizenSDK。
保留的 `identity::ss58` 只做公开地址编解码。libp2p Noise 密钥按连接随机生成、只用于传输
握手并在内存清理，不是钱包或管理员密钥。

聊天、广场、OpenMLS、TUYU 消息协议与产品数据库均被排除。测试夹具只能使用公开向量和
非生产数据，不得加入真实助记词、设备密钥或用户数据。

## 构建与分发

- SDK 源码树不得接收构建缓存、原生库或 Release 产物。
- 原生构建和 Release 在首次建目录前校验绝对规范路径及每一级既存祖先，拒绝路径穿越、
  符号链接祖先和非目录祖先。
- CI/Release 使用锁文件与准确提交；Release 必须绑定同产品、同目标的成功 CI。
- 候选拒绝符号链接、路径穿越、未登记文件、常见密钥文件及 PEM 私钥材料。
- `SHA256SUMS` 是 tgz 外部资产，精确覆盖 manifest 与 tgz；校验器重建规范归档字节。
- 当前 Release 只声明 Android `arm64-v8a` 与 iOS `arm64`。
- GitHub Release 是正式分发终态，但不等于真机硬件金库安全验收；对应结果必须单独留档。

本文不把测试源码存在、历史本机候选或先前哈希解释为当前字节已经通过验证。本轮实际测试、
编译和复核结果以任务关闭时的执行报告为准。
