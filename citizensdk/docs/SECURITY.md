# CitizenSDK 安全模型

## sr25519 固定口径

- 密码学实现使用 `schnorrkel`，禁止增加第二套纯 Dart 或自研 sr25519 实现。
- mini-secret 扩展固定为 `ExpansionMode::Ed25519`。
- 签名上下文固定为字节串 `substrate`。
- 硬派生 chain code 由上层按 Substrate junction 规则生成，原生层逐层派生。
- 私钥输入、child mini-secret 和展开后的 SecretKey 必须在使用后清零。
- FFI panic 必须转为错误码，禁止跨 FFI 展开或使宿主应用退出。

## 设备机密

助记词、母种子、child mini-secret 和私钥不得上传到 TuyuServe、TuyuBooking 主机、
Cloudflare 或任何远端服务。后续钱包层只能存储硬件金库产生的密文，解锁和签名必须在
用户设备本地完成。

新硬件金库产品标识固定为 `citizensdk`。没有满足安全契约的平台实现或设备能力时必须失败
关闭：允许轻节点查询和公钥验签，但禁止创建、导入、解锁钱包和提交签名交易。

Android 继续使用硬件 RSA-OAEP KEK 包装随机 AES-256-GCM DEK，KEK 必须位于 StrongBox
或 TEE，且每次私钥使用由硬件强制 `BIOMETRIC_STRONG`。iOS 继续使用 Secure Enclave
ECIES，访问控制固定为 `biometryCurrentSet + privateKeyUsage` 和
`WhenUnlockedThisDeviceOnly`。两个平台都只通过 Flutter 通道传输字节数组。

硬件金库不存在旧产品入口。Dart 不接收宿主产品名或密钥命名空间；Android/iOS 原生层
只接受 `citizensdk`，硬件别名和 AAD 都由 SDK 固定生成。SDK 不读取、转换或删除其它产品的
密文和硬件密钥，未来任何产品切换都必须在该产品步骤中单独设计和批准。

## 当前阶段限制

当前目录已包含 sr25519、轻节点核心、Dart 编排、交易与无根钱包源码及锁文件，但全面复核
已经确认：Dart 轻节点行为、交易执行结果、锁文件依赖闭包和测试来源仍未完成与 CitizenApp
稳定实现的逐项对齐，必须按后续步骤继续修复，不能把当前目录描述成完整源码闭包。
2026-08-28 的历史基线曾完成本机构建和已有测试；第 10.1 步又修改了钱包服务、仓储、安全
存储及测试源码，依用户限制未运行测试或编译。因此历史结果既不证明与 CitizenApp 完整
一致，也不证明当前字节已经通过，本轮不得声明完成构建验收。
全节点 `identity` keystore、seed phrase 解析和 `author` 出块模块明确排除；保留的
`identity::ss58` 只处理公开公钥地址，不接触私钥。SQLite 完整数据库保持上游源码和特性
门控，移动轻节点使用 finalized database 序列化，不把它作为钱包存储。

libp2p Noise 私钥只用于单条连接的传输握手：由平台随机源按连接生成，使用 `Zeroizing`
清理，不保存到数据库或安全金库，也不得被解释为公民账户、钱包、TUYU 账户或管理员
身份密钥。测试源码只使用公开开发向量、上游公开链数据和固定非生产字节，不得加入真实
助记词、设备密钥或用户数据。

## Dart 钱包边界

- `WalletRepository` 只保存公开账户资料、revision 和待清理计划，禁止出现秘密字段。
- `SecureSeedStore` 只保存 `//index` child mini-secret，读取必须由平台认证保护。
- 创建返回的助记词不持久化；恢复和追加账户时只在派生作用域短暂使用。
- 创建、导入和追加先提交并回读公开事实，只有 CAS 胜者写秘密；写后必须回读账户密文和
  钱包 KEK，失败时只有秘密全部确认不存在后才回滚公开事实。
- 删除采用持久清理计划，安全金库删除接口必须幂等；全部账户 child 和钱包 KEK 都要尝试，
  每项删除后回读，任一失败都保留计划。
- 默认变更串行范围是同一 Dart isolate；SharedPreferences 不提供跨 isolate 或进程 CAS。
- `WalletService.sign` 是任意协议载荷的唯一账户签名入口；调用方拿不到 child 私钥。
- 公民链 extrinsic 固定实时 runtime nonce 与 immortal era，不提供远程 RPC 或服务器签名。

Android/iOS 硬件金库历史基线曾完成本机构建与合同测试，但尚未完成签名 Release 真机安全
验收；第 10.1 步当前钱包字节也尚未重新执行测试或编译，因此仍不能声明生产可用。
SharedPreferences 只允许保存公开钱包事实与公开 finalized database；私钥材料只能保存为
硬件金库密文，禁止用内存、普通文件、SharedPreferences 或产品数据库模拟生产私钥存储。

## 构建与分发安全

- 源码树不得接收 Cargo、Flutter、Gradle、CocoaPods、原生库或 Release 产物；构建脚本会
  对解析后的真实工作目录和输出目录执行源码树越界检查。
- CI 不接受 `source_sha` 或正式版本。Release 必须通过同产品 `citizensdk`、同目标 `sdk`、
  同 CI workflow 的成功 `ci_run_id` 复核，并绑定准确的 40 位小写 Git SHA。
- Release 候选拒绝符号链接、路径穿越、未登记文件、常见密钥文件和私钥 PEM 材料；
  `citizensdk-release.json` 与 `SHA256SUMS` 覆盖全部源码和移动原生库。
- GitHub runner 不读取宿主产品私钥、用户助记词或设备硬件金库数据。构建来源证明只签署
  三项公开 SDK 资产，不能被解释为设备密钥证明或生产真机安全验收。
- 当前 Release 只声明 Android `arm64-v8a` 与 iOS `arm64`。测试用 macOS dylib 不进入
  候选；macOS、Linux、Windows 只有在平台适配和硬件金库另行批准后才能扩展同一产品流程。
