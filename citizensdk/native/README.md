# CitizenSDK 原生核心

本目录承载同一 CitizenSDK 产品的统一原生核心：`contracts` 固定类型化依赖语义，`engine`
负责产品无关的能力、runtime、状态导入与交易执行协调，`ffi` 是唯一产品 C ABI，`signer`
提供 sr25519，`smoldot/provider` 实现类型化链合同，`smoldot/ffi` 只保留归档
Dart/smoldot ARM64 差分测试所需的 legacy 入口，`smoldot/pow` 是公民链 PoW + GRANDPA
轻节点快照。

固定依赖方向为：

```text
语言绑定 -> 产品级唯一 C ABI -> engine -> contracts <- smoldot / signer / OS vault / stores
```

`native/ffi` 与根 `include` 已建立产品级唯一 C ABI，并让其经 Engine 调用真实 smoldot
provider。ABI v1 保留原有 36 个符号不变并追加 34 个账户、钱包、签名、转账和历史符号，
总计 70 个。`citizensdk_create` 仍构造 chain-only session；
`citizensdk_create_with_host` 通过五类具名 typed stores 与 KEK/DEK Vault 构造完整平台无关
组合。ABI 不开放任意 RPC、private key、child secret、低层 signer 或钱包裸 signed
extrinsic。

host 组合还固定公开链数据库生命周期：start 在 provider 启动前自动 restore，显式 export 在
返回同一快照前先完成 exact revision CAS，graceful stop 在退订/停止服务/provider 前先
checkpoint。持久化失败不会执行后续 stop 副作用；destroy 不替代 graceful stop。legacy session
构造不启用这三项自动行为。host start/stop/import 采用独占 request admission：先前请求必须
结束，后续请求、回调/订阅控制和 destroy 在该生命周期请求完成前失败关闭；legacy 构造仍沿用
原共享 admission。

第 4.1/4.2 步已经在 `engine`/`contracts`/`signer` 源码实现并组合 finalized 账户余额、同块链上
费用、准确 best `AccountNonceApi_account_nonce`、完整钱包生命周期、准确 signed extrinsic V4
`transfer_with_remark`、广播前 pending 和 finalized 同 index System 终态。创建钱包是
prepare 零持久写入→用户确认备份→commit；删除后的 SecretRef 保留永久 tombstone，整代
Vault generation 被持久退休。钱包秘密只在 Rust `SecretBuffer` 中解锁并交给唯一
`ChainSigner`，没有私钥导出路径。钱包交易只公开不可拆分的 `transfer_with_remark`；
pending CAS 成功后才进入 provider，provider 哈希不一致时失败并保留本地 pending。
finalized 流水拒绝自转，对业务/Balances 双事件精确一对一去重，并由已核验 pending
认领发送方 outgoing；同一原始块重放不能恢复已消费 pending。底层 watch 是
submit-and-watch，组合钱包组件后会在 provider 前关闭 raw 入口。终态 metadata 直接从
provider 的准确 finalized 块取得，持久 runtime cache 只用于性能，不能充当执行证据。第 4.2 步
新增的 Rust 内部 `ProductComposition` 固定 smoldot、准确 Runtime nonce 与唯一 sr25519 signer，
并只接受宿主注入的 typed Vault/stores。五类 store 分别是 chain database、runtime cache、
wallet profile、transaction history 与 encrypted secret blob；secure store/Vault
all-or-none。旧构造准确报告 chain-only 能力，host 构造则组合真实钱包/历史能力；不能再把
旧构造的 unsupported 快照写成整个产品 ABI 尚未投影。根 Dart、Android 与共享 Darwin
绑定均已切换到 host 产品组合。

创建准备会话的助记词仅经绑定 owner instance handle 的 SDK-owned handle 提供给明确备份 UI；
import/add 的恢复词是用户显式输入。Rust 以随机 DEK/nonce 和完整 `SecretRef` AAD 执行
AES-256-GCM，宿主只 wrap/unwrap DEK，unwrap 直接写 Rust-owned 32 字节缓冲区；private key
与 child secret 永不导出。

finalized 历史只按一次 verified finalized 锚进行 parent-header ancestry 证明，每批最多 120 块；
有界 proof-derived cache 只优化回溯长度，不参与安全结论。Engine 的历史操作租约覆盖全部
provider/store await 和最终 CAS，stop/dispose 不能穿越提交窗口。同账户 Pending/InBlock 的持久
single-flight 防止准确 Runtime nonce 在并发构造中被再次使用。

`smoldot/ffi` 只继续服务归档 Dart/smoldot 差分验证；它的 `smoldot_*` 与四个
`citizen_sr25519_*` 是 legacy ARM64 宿主测试库的真实导出，但不属于产品 `citizensdk_*` ABI，
也不进入任何候选。根 Dart、Android 与 Apple 钱包、交易和秘密处理已经切换到 Rust Engine，
不能把保留源码误写成当前公开运行路径。

Engine 的 `sign_wallet_payload` 是受信任宿主的通用 sr25519 账户签名能力，不是交易专用签名器；
宿主可把返回签名用于 SDK 高层交易路径之外。因此 pending-before-broadcast 只保证 SDK 的
高层钱包交易入口。产品 C ABI 已以 `citizensdk_sign_wallet_payload` 投影该方法，后续绑定
必须如实保留这条信任边界。

高层 `citizensdk_transfer_with_remark` 在独立四线程长观察池中等待完整 Engine terminal
future，不占用短操作池。只有 canonical finalized body、准确块 metadata 与同 index
`System.Events` 形成终态；取消或中断只结束本次观察，durable Pending/InBlock 门保持。

原生轻节点源码闭包、FFI、Dart smoldot 包、来源测试与锁文件已经迁入；当前不存在通过
CitizenApp 或 `shared` 相对路径取得运行时源码的依赖。`android/` 与 `darwin/` 平台目录只负责
链接、装载、typed stores 和设备安全能力，不复制链或签名实现。

`engine` 精确使用官方 `subxt-core = 0.43.0` 解码 metadata 与 `System.Events`，不实现网络
连接或任意 RPC；网络验证只由 `smoldot/provider` 的 `VerifiedChainClient` 提供。Provider
内部使用固定方法 allowlist 取得 smoldot 已验证数据，公开层不能传入方法名。它的 SDK-only
源码与收编快照一起由 `smoldot/SOURCE_SHA256.json` 分类记录，Core/产品 FFI 则由 Release 的
独立反向闭集固定。

Rust 钱包合同固定 wallet index `0`、账户 index `0` 为 `masterAccountId`、账户 index 范围
`0..1989` 和 SS58 prefix `2027`。`WalletState` 分别校验 create/import 的空 previous 与 append
的严格账户列表前缀，并拒绝 cleanup 命中当前 exact secrets、当前 generation KEK 或重复物理
目标。Engine 仅在 `Running` 时开放 `CHAIN_READ` 及其依赖能力；revisioned
`ChainDatabaseStore` 以 CAS 保存 finalized 锚。跨 Engine 或进程防回退只在 store provider
实现共享、耐久、强原子 CAS 时成立；保留的 legacy Dart Preferences store 不具备该保证。

账户/交易、密钥/金库和业务账户协议是三个层次：公民链 AccountId/余额/nonce/交易属于 Core；
sr25519 与安全存储只负责本地秘密和签名；TUYU、员工登录等 challenge、权限与审计属于 SDK
外部业务。它们可以明确复用同一公钥签名，但不能混为同一业务账户。

全节点出块、全节点 identity 私钥、聊天、OpenMLS、TUYU 与产品业务被排除。候选合同打包
Android ARM64 产品 Core/JNI 双库，以及由同一 Core 生成的 iOS 设备 ARM64、`iOS-Simulator`
ARM64 与 macOS（仅支持 ARM64 架构）`CitizenSDK.xcframework`；根 Dart、Android 与 Apple 均使用产品 ABI。
Linux、Windows 仍未交付。本轮 Android AAR 与 Apple 单一 XCFramework 构建通过；框架只含
`iOS`、`iOS-Simulator`、`macOS` 三个 ARM64 slice。Apple 本机已编译 iOS 设备与
`iOS-Simulator` 两组测试 bundle；因无
Simulator runtime 未执行 iOS XCTest。macOS Core 50 项和 Flutter adapter 22 项 XCTest
0 失败，1 项真机硬件用例跳过；normal/supervisor smoke 通过。这不代表真机 Apple
金库已验收，也不代表 TataConsole Flow、远程 CI 或正式 Release 已运行。

iOS 与 `iOS-Simulator` 是浅层 framework，install ID 为
`@rpath/CitizenSDK.framework/CitizenSDK`；macOS 使用标准 `Versions/A` framework，install
ID 为 `@rpath/CitizenSDK.framework/Versions/A/CitizenSDK`。候选只允许后者标准布局中的
精确五个内部相对符号链接。Android Gradle/Kotlin persistent project state 必须在
TataConsole 中央 work directory，源码 `android/.kotlin` 禁止。

同一真实 Flutter consumer 已构建 Android release ARM64 APK、iOS device Release
no-codesign、`iOS-Simulator` generic ARM64 和 macOS Release；这些是 compile/link 结果，不是
移动真机或 Simulator runtime 结果。Flutter SPM 识别警告与 Android built-in Kotlin 迁移提示
延后到第 9 步 Hosted/Flutter 集成处理。

同一本机闭集的根 Rust workspace 285/285、compile-fail 文档测试 1/1、Clippy 与格式检查
通过；完整 Dart 316/316（`--timeout=2m`）、Hosted 17 文件分析 0 问题，Android 原生
Kotlin/Java 单元测试 Gradle 17 个 task 成功。

任何编译状态和原生产物都必须写入调用方指定的源码树外目录。本机唯一允许目录是
`/Users/rhett/TATA/tataconsole/target/citizensdk`。
