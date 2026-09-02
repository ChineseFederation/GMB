# CitizenSDK 技术架构

## 单一产品原则

CitizenSDK 是一个产品、一个版本和一条分发链。轻节点、钱包和 signer 是内部能力层，
不拆成可独立发布的第二套 SDK。产品级唯一 C ABI 已在第 3 步建立；最终 Flutter/Dart、
Swift、Kotlin/Java 与 C/C++ 都只通过该 ABI 使用 Rust Engine。

依赖方向固定为：

1. 宿主 App 依赖对应官方语言绑定；当前根
   `package:citizen_sdk/citizen_sdk.dart`、Android Kotlin/Java 与 Flutter，以及 Apple 共享 Darwin
   源码的 Swift 与 Flutter 投影已经使用产品 ABI。
2. 语言绑定只依赖已冻结的产品级 C ABI，不实现链、钱包、交易或密码学。
3. C ABI 只调用 `CitizenSDK Core Engine`，固定生命周期、所有权、错误、事件和能力查询。
4. Engine 只依赖类型化 contracts；smoldot、sr25519、系统金库和状态仓储实现这些合同。
5. provider 分别依赖收编的 smoldot PoW、`schnorrkel` 和宿主操作系统安全设施。

上述产品 ABI 与 Engine 路径已经由根 Dart API、Android 以及 iOS/macOS 正式绑定消费。
保留的旧 Dart 轻节点、钱包与交易实现只用于归档和差分测试，不能被解释为根公开入口或任一
正式平台运行路径。

原生核心与产品无关 Dart 层不得反向依赖 CitizenApp、CitizenWallet、TuyuLove、TuyuLife、
TuyuBooking、聊天、广场、TUYU 协议、产品导航或产品数据库。

## 目录结构

```text
citizensdk/
├── lib/                    唯一 citizen_sdk 包及内嵌 smoldot Dart 绑定
├── native/
│   ├── contracts/          VerifiedChainClient、signer、vault 与类型化存储合同
│   ├── engine/             产品无关 Core 协调、核验与能力解析
│   ├── ffi/                唯一 citizensdk_* 产品 C ABI
│   ├── signer/             唯一 sr25519 原生实现
│   └── smoldot/
│       ├── provider/       VerifiedChainClient 的真实 smoldot 实现
│       ├── ffi/            仅供 macOS `arm64` 差分测试的 legacy 原生入口
│       └── pow/            PoW + GRANDPA 轻节点 Rust 快照
├── include/                唯一产品 C/C++ 头文件与所有权说明
├── android/                Android 插件与硬件金库
├── darwin/                 iOS/macOS 共享 Apple 投影
│   ├── Sources/CitizenSDK/ Rust Core 的 Swift API、typed stores、Vault 与 SDK-owned UI
│   └── Sources/CitizenSDKFlutter/ 只消费 CitizenSDK.framework 的 Flutter adapter
├── assets/
│   ├── README.md           随包静态资产与设备运行状态边界
│   └── citizenchain/       manifest、chain spec 与 #0 light sync state
├── scripts/                外部原生构建与确定性候选工具
├── test/                   根包合同测试及迁入的 smoldot 测试
└── docs/                   产品技术文档和 smoldot 来源记录
```

根 `pubspec.yaml` 是唯一有效包清单，不含仓库本地 `path` 依赖。原 smoldot Dart 生产绑定
机械迁入 `lib/src/smoldot`，测试和夹具迁入 `test/smoldot`，历史包清单与来源说明归档到
`docs/smoldot-dart`。smoldot 只作为 CitizenSDK 内部实现参与同一版本和同一发布，不形成
第二个 SDK 或第二个源码真源。

`native/contracts`、`native/engine` 与 `native/ffi` 是 CitizenSDK 自有 Rust Core/ABI 源码，
由独立反向闭集固定。`native/smoldot/provider` 同样是 SDK-only 适配，但因为它与收编的
smoldot 快照共同演进，所以在 `native/smoldot/SOURCE_SHA256.json` 中单独分类。根 Rust
workspace 管理 contracts、engine、ffi、signer 和 provider；PoW/light-base 保留各自嵌套
workspace 的已验证解析语义。engine 精确固定官方 `subxt-core = 0.43.0`，只用于 SCALE
metadata、`System.Events` 与 extrinsic 哈希语义。

## Rust Core 合同与 Engine

`native/contracts` 冻结以下边界：

- `VerifiedChainClient`：只提供携带 best/finalized 语义的类型化区块、storage、runtime、
  提交、观察和状态导入导出；`resolve_finalized_block(hash,height)` 把不受信任宿主输入解析为
  provider 已证明的历史 finalized canonical 块，不提供任意 `rpc(method, params)`。
- `ChainSigner` 与 `SecretVault`：分别拥有 sr25519 和设备密文/认证职责，不能把 Secure
  Enclave、Keystore 等系统金库冒充为 sr25519 signer。
- `ChainDatabaseStore`、`RuntimeCacheStore`、`WalletProfileStore`、
  `TransactionHistoryStore` 与 `EncryptedSecretBlobStore`：按数据等级隔离，最后一项只能
  接受加密信封。加上 `SecretVault` 共六个隔离边界。
- 十项固定能力的 revisioned snapshot：`CHAIN_READ`、`TRANSACTION_BUILD`、
  `TRANSACTION_SUBMIT`、`TRANSACTION_VERIFY`、`WALLET_PROFILE`、`LOCAL_SIGNING`、
  `HARDWARE_VAULT`、`USER_AUTHENTICATION`、`HISTORY`、`BACKGROUND_SYNC`。每项分别表达
  `supported`、`available`、`enabled`、`ready` 和稳定 reason；能力发现不能替代敏感操作的
  即时复核。
- `WalletState`：固定唯一 wallet index `0`、Citizen SS58 prefix `2027`；账户 index `0`
  必须等于 `masterAccountId`，账户 index 范围为 `0..1989`。create/import provisioning 使用
  空前态并精确拥有目标全部 secrets；append 的前态必须是目标账户列表的严格前缀，既有
  profile 字段与账户逐项不变，计划只拥有新增账户的 exact refs。cleanup/queue 不得命中
  当前 profile 引用的 exact account secret 或当前 generation 的 wallet key；active cleanup
  与 queue 的 operation ID 和物理目标不得重复。`EncryptedSecretBlobStore` 的
  `Vacant -> Sealed -> Tombstone` 单向状态机和 `SecretVault` 的 generation retirement 是
  跨进程迟到写入 fence，进程内 mutex 不能替代。

`native/engine` 实现能力依赖收敛、准确区块 runtime context 缓存、仅启动前且不倒退的
状态导入门禁，以及交易执行结论。导入会把本 Engine provisional anchor 与 revisioned
`ChainDatabaseStore` 已持久锚合并，先拒绝回退/冲突，再调用 provider；provider 或 CAS
产生不确定副作用后失败会永久关闭该 Engine。跨 Engine 或进程的防回退保证要求 store
adapter 提供共享、耐久、强原子 CAS；保留的 legacy Dart Preferences store 不因此获得该保证。链读取
能力还受 Engine lifecycle 约束，只有 `Running` 才能 ready。持久 `RuntimeCacheStore` 只允许
作为性能缓存，交易终态核验必须直接从 provider 取得目标 finalized 块的 runtime context，
不能把宿主可写缓存提升为执行证据。组件缺失会关闭对应 capability；
当其余 probe 均 ready 时归因为 `host_disabled`。完整签名 extrinsic 先按
Substrate 规则计算哈希，在准确
块体中定位 index，再使用同一块 metadata 解码该 index 的 `System.ExtrinsicSuccess/Failed`；
缺失、畸形、矛盾或跨块证据一律返回未核实。Engine 复用
`test/transaction/fixtures` 的生产 CitizenChain metadata/events 夹具，没有复制第二份输入。

host 组合的链数据库生命周期由同一 Engine 原语闭合：start 在 provider start 前执行
typed-store restore；export 使用稳定 finalized 锚导出并以完整 `revision + state` CAS；
graceful stop 在任何退订、服务或 provider 停止副作用前完成同一持久化。失败时保持 Running
可重试。直接 destroy 不等待异步平台 checkpoint，因此宿主必须先 stop；legacy session 仍只
使用显式 import/export。host start/stop/import 共用独占 admission：先前异步请求未完成时不
受理，受理后直到完成都排斥新请求、callback/subscription 控制与 destroy；stop 仅允许当前
独占 request 自己关闭此前已经存在的 capability monitor。

第 4.1/4.2 步在 Core 源码增加并组合四组真实服务：

- 账户状态：从准确 metadata 生成 finalized `System.Account` storage key，解码
  free/reserved/total；batch 先去重再按原顺序及重复项重建。链上费率、最低费与存在性存款
  绑定同一 best runtime metadata；nonce 只接受同一次
  `AccountNonceApi_account_nonce` Runtime call 携带的账户、hash、高度与值，并复核准确 best
  身份。该值不包含交易池，持久同账户 Pending/InBlock single-flight 防止本地重复使用。
- 钱包与 signer：English BIP-39 12/24 词、可选 NFKD password、`//0..//1989` 派生，以及
  create/import/add/usable/rename/activate/delete/reconcile/sign。create 固定为 prepare（零持久
  写入、一次性恢复词会话）→用户确认备份→commit，消除持久钱包先于恢复词展示的崩溃窗口；
  `bip39`、password 和 NFKD 临时值均进入 zeroize 生命周期。公开事实先以 revision CAS 保存
  provisioning，generation/owner/operation 精确拥有秘密与 cleanup；写后异常由 exact readback
  收敛。金库解锁秘密始终留在 Rust `SecretBuffer`，Rust Core 不提供私钥导出。
  产品 ABI 的 prepared-wallet handle 绑定 owner instance，只允许显式创建/备份 UI 复制助记词；
  import/add 的恢复词只能来自用户明确输入，private key 与 child secret 永不导出。
- 交易构造：固定 `OnchainTransaction.transfer_with_remark` pallet `4` / call `0`、正分金额和
  最多 99 UTF-8 字节 remark，以准确 best runtime/transaction version、CitizenChain genesis、
  准确 Runtime nonce、immortal era、tip `0` 和官方 `subxt-core 0.43.0` 构造 signed extrinsic
  V4。metadata 动态 call bytes 必须与固定合同完全一致，source/public key 与签名均复核。
- 历史：构造对象保持 Engine 私有，钱包只公开不可拆分的 `transfer_with_remark`；它先以完整
  extrinsic hash 持久化 source/destination/amount/remark/nonce pending，再广播。raw pre-signed
  submit 只供无钱包的高级链客户端，一旦组合钱包组件就必须命中内部 pending；底层所谓 watch
  实际是 submit-and-watch，因此组合钱包组件后同样在 provider 前关闭。inBlock/
  finalized 块锚不等于成功；终态只接受完整证据核验器产生的私有令牌，该令牌绑定 txHash 与
  同一 extrinsic index 的 `System.ExtrinsicSuccess/Failed`，并精确匹配唯一 pending。finalized
  流水拒绝自转，对同 identity 的 `OnchainTransaction`/`Balances` 事件严格一对一配对，保留
  业务事件和 remark；已核验 pending 认领发送方 outgoing、保留接收方 incoming，同一原始块
  重放也不能令已消费 pending 重新出现。逐账户 finalized 游标只允许相同块幂等或严格
  `last + 1`，不能跳块。每批最多 120 个连续高度；历史操作代际租约覆盖全部 provider/store
  await 与最后一次 CAS，stop/dispose 不能切入不完整提交。
  高层 C ABI 转账在独立四线程长观察池中选择完整 terminal future 与 cancellation；取消或
  interrupted/dropped/retracted/timeout 不清 durable Pending/InBlock 门，只有 canonical body、
  准确块 metadata 与同 index `System.Events` 核验才形成 finalized 终态。

`VerifiedBlockRef` 是可序列化值，不是不可伪造令牌。Engine 核验交易前必须调用 provider
解析 finalized hash/height；smoldot 从同步状态机的准确 verified finalized 锚沿 exact parent
hash 逐头回溯，核对响应 hash、完整 SCALE header hash、高度与父链。best/recent cache 和按高度
返回值都不是 finalized 证明；独立有界 proof-derived cache 只降低重复回溯成本。这样既关闭
异步重组 TOCTOU，也允许重启后补扫旧块。

真实 smoldot adapter 与产品 C ABI 已形成一个 70 符号的 ABI v1：原 36 个符号及其布局、数值、
语义保持不变，追加 34 个账户、余额/nonce/fee、钱包生命周期/多账户、通用载荷签名、高层
转账和历史符号；产品头文件仍没有任意 RPC、raw signer、private-key 或 child-secret 出口。
`citizensdk_create` 保持 session-backed chain-only；`citizensdk_create_with_host` 固定 smoldot、
准确 Runtime nonce 和唯一 sr25519 signer，并从 host v1 取得 chain database、runtime cache、
wallet profile、transaction history、encrypted secret blob 五类具名 store 及 KEK/DEK Vault。
secure store/Vault all-or-none，不能注入 signer、nonce 或任意键值服务。根 Dart、Android 与
Apple 共享 Darwin 绑定均已改接这个产品 ABI；iOS 与 macOS 使用同一 host composition，平台
差异只在宿主安全设施、文件保护与运行架构。

## 归档 legacy Dart 差分基线

以下实现已经从根 `citizen_sdk.dart` 移除且 Android、iOS 与 macOS 正式绑定均不可到达，只保留
用于归档和差分验证：

- `CitizenSdk`：组合 `chain`、`rpc`、`wallet`、`transfers`、finalized 流水与 `signer`。
- `CitizenLightClient`：管理 smoldot 生命周期、随包创世锚、bootnode、同步健康、
  finalized database、JSON-RPC 与链头订阅。
- `CitizenChainAssets`：在创建或初始化 smoldot 原生客户端前核对 manifest 精确字段闭集、正式
  `citizenchain` 链/协议 ID、两个资产 SHA-256、genesis hash 与 checkpoint state root。
- `WalletService`：管理一只无根热钱包、`//0..//1989` 多账户、创建/导入/追加/删除、完整
  可用性门禁、账户改名、本地任意载荷签名和用户主动的子账户私钥导出。这里描述的是归档
  legacy Dart API，任一正式绑定均不可达；新的 Rust Core 不移植私钥导出。
- `ChainRpc`：只经本机轻节点读取 finalized 状态、提交 extrinsic、订阅状态并核对
  `System.Events`；单/批读取 `System.Account` free/reserved，并从 runtime metadata 估算费用。
- `SignedExtrinsicBuilder` / `TransferService`：使用实时 runtime version、nonce、immortal era、
  sr25519 和公民链 `transfer_with_remark` 编码，并在广播前持久化本机 pending。
- `FinalizedTransactionScanner` / `FinalizedTransactionHistory`：按账户持久游标增量扫描 finalized
  转账，以 txHash、同 extrinsic index 的 System outcome 收敛本机 pending；每块事实原子提交。
- `lib/src/platform` 中仍保留的平台无关 finalized 公开仓储；旧 Dart 硬件秘密通道与
  `SecureSeedStore` 装配已删除，正式装配统一改用 Rust Core、typed stores 与 Vault。

交易成功分为三个事实：返回 txHash 只表示本机轻节点接受提交；`inBlock/finalized` 只表示
包含；只有按 txHash 定位同一 extrinsic index 并读到该 index 的
`System.ExtrinsicSuccess` 才是执行成功。`ExtrinsicFailed` 会返回明确失败；未取得明确事件时
返回未核实，不把“没找到失败”猜成成功。submit-only 后台观察一旦收到有效 `finalized`，
等待式交易一旦收到要求的 `inBlock/finalized`，终态所有权都移交给同块 `System.Events` 核对；
交易池订阅此后的迟到消息、畸形状态、错误或关闭不得再制造第二个终态。

runtime version 与 metadata 组成同一块的 `ChainRuntimeContext`。缓存身份绑定 `specVersion`；
不同版本的 in-flight 请求互不复用，前一代请求迟到不得覆盖新 registry。构造签名交易、读取链上
费率以及解码目标块事件都消费对应 context，避免长驻进程跨升级后拼接前一代 metadata 与新
`transactionVersion`。状态回调和非阻塞订阅取消都按 best-effort 隔离异常，不拥有状态机。

批量余额先把 AccountId/公民 SS58 规范化为唯一 storage key，通过轻节点已有的 finalized
batch storage 一次读取，再按原始输入顺序和重复项重建不可变结果；传输错误上抛，不能被
“账户不存在即零余额”的规则吞掉。

## 数据与安全隔离

| 数据 | 命名空间 | 内容 |
|---|---|---|
| 钱包公开事实 | `citizensdk.wallet.state.v1` | profile、revision、provisioning、active cleanup、exact cleanup queue，不含秘密 |
| 轻节点数据库 | `citizensdk.smoldot.database.v1` | 公开 finalized database |
| 交易公开事实 | `citizensdk.transactions.state.v1` | finalized 流水、pending、逐账户游标，不含秘密 |
| 账户密文 | `citizensdk.wallet.secret.*` | 硬件金库信封 |

Apple 共享 Darwin adapter 将上述逻辑域投影为两套 typed SQLite：public store 保存可重建链状态、
runtime cache 与交易公开事实，secure store 保存钱包公开资料、加密信封和 Vault 引用；两者不
共用一套无类型键值逃生口。iOS 与 macOS 复用相同 schema 和 CAS 语义，但使用各自平台允许的
文件保护能力。

Apple 绑定对 C ABI 宿主上下文使用显式 +1 retain lease。关闭只能沿
`live -> monitorStopped -> destroyOnly -> closed` 单调前进；callback clear 在首次 destroy
前持久成关闭阶段，后续错误只能重试 destroy。成功 destroy 时先断开 HostBridge
和两个 SQLite store，再且只释放一次 ABI +1。宿主遗忘 close、部分关闭或
Flutter detach 失败都把整个 facade 交给进程级 supervisor 按有界退避继续收口，
不会提前释放借用上下文或恢复为可用状态。

C 回调对 capability/lifecycle 的查询只入队，由专用串行队列离开 C callback 后
调用 Core；回调交付、关闭与队列 claim 在同一门上线性化。Flutter detach 的顺序固定为
撤销 method handler、撤销 event handler、永久使当前 epoch 失效、清空 sink，然后先取消
所有 session 的未完工作再等待任何一个关闭；单 session 失败不得跳过后续 session。

新硬件信封产品标识固定为 `citizensdk`。助记词和母种子不持久化；每个账户只保存 child
mini-secret 的设备密文。libp2p Noise 的连接级临时传输密钥不是钱包、TUYU 或管理员身份，
不进入钱包仓储或平台金库。

Rust 为每个 child 生成随机 32 字节 DEK 与随机 nonce，以 AES-256-GCM 加密，并把 product、
wallet index、generation、owner、AccountId 与 secret kind 构成的完整 `SecretRef` 作为 AAD。
宿主 Vault 只创建/查询/退休 KEK 并 wrap/unwrap DEK；unwrap 最终写入 Rust-owned 的精确
32 字节缓冲区。Apple Security framework 返回的不可变 `CFData` 只在对应 `autoreleasepool`
内短暂存活；桥接层避免生成 Swift `Data`/COW 副本，在不能可靠原地清零的边界下立即复制
精确 32 字节，并由 pool 排空释放。该值不进入 public API 或 Flutter；Rust-owned DEK 与 child
明文仍在使用后清零，助记词或 password 也没有 Flutter tuple 位置。

宿主进程属于信任边界。新 host v1 只暴露五类具名 typed store 和不接触 child 的 DEK Vault，
没有明文 `SecureSeedStore` callback。归档 legacy Dart 高级注入仍可能让自定义
`SecureSeedStore` 观察 child，因此它只可用于受控差分测试，不能进入正式装配。

架构明确分开三层：公民链账户/余额/nonce/fee/交易；产品无关的 sr25519 派生、金库与本地
签名；TUYU、员工登录等业务账户协议。业务协议可以请求同一公钥签名，但不得把 challenge、
会话、权限和审计并入公民链账户或 SDK Core。

## 原生边界

根 Rust workspace 的 contracts、engine、ffi、signer、provider，以及 legacy FFI/PoW 嵌套
workspace 都是 CitizenSDK 内部构建边界，不是多个 SDK。根 `include/citizensdk.h` 是唯一
产品头文件，只声明 `citizensdk_*`；`native/smoldot/include/smoldot.h` 只描述 macOS `arm64` 差分
测试所需的 legacy 兼容库。产品 ABI 使用固定宽度、`struct_size + abi_version`、单调非零 handle、Rust-owned
result、独立 callback thread、64 项有界事件队列和稳定错误码。异步请求接受后恰有一个完成
事件；raw extrinsic watch 与高层 wallet transfer watch 可取消，其它原子/状态变更操作不会
伪装成可回滚。

Capability revision 由 Engine 单调持有，链 ready 只读取 smoldot 自身 verified
`is_usable`。Provider 内部固定 RPC allowlist，不对 ABI 暴露方法名。坏导入使当前组合进入
不可复用 `StartFailed`；绑定必须销毁 handle 并新建未导入实例才能从随包 #0 回退，不能在同一
Provider 上重试。完整 ABI 规则见 `C_ABI.md`。

轻客户端不收编全节点 `author` 出块代码，以及 identity keystore/seed phrase 私钥入口；
只保留 JSON-RPC 所需的 `identity::ss58` 公钥地址编解码。全节点 SQLite 数据库源码按上游
快照保留并受 feature 控制，移动轻节点使用 finalized database 序列化。

## CI、Release 与平台边界

CitizenSDK 最终只能接入 GMB/TataConsole 已有的唯一顶层路由，不建第二套
Workflow、缓存或发布系统。目标产品动作为：

- `gmb.citizensdk.sdk.ci`
- `gmb.citizensdk.sdk.release`

CI 与 Release 的目标合同都从干净源码建立隔离构建快照，执行唯一根包依赖锁检查、静态检查、Rust 与
Dart/Flutter 测试、Android/Apple 原生构建和候选验证。smoldot Dart 绑定和来源测试现与根 Flutter
包一起分析和执行。为保留已经验证的 smoldot 行为字节，静态分析继续报告迁入源码的既有
warning/info，但使用 `--no-fatal-infos --no-fatal-warnings` 只让 analyzer error 阻断流程；
格式检查、编译和完整测试仍失败关闭。三个 Rust workspace 都执行锁定测试；PoW workspace
另外使用 `cargo check --workspace --all-targets --locked` 编译包括 Criterion benchmark 在内的
所有 target，但不把使用随机输入的性能基准误当作确定性测试运行。Android 原生双库/AAR 与
Apple XCFramework 注入
同一候选并完成确定性反向校验后，两条流程都从该目录建立逐字节临时验证副本并执行官方
`dart pub publish --dry-run`；
Dart 生成的 `.dart_tool`
因此不会污染正式候选。`.pubignore` 固定 Hosted 运行时闭包，禁止把 GitHub 审计包与 Hosted
包实现成两个源码真源。Release 还会验证指定
成功 CI 的 workflow、显示标题、产品目标、成功状态与准确 source SHA，不读取、下载或比较
CI 资产，并从同一提交重新构建；不以跨 Runner 归档字节必然一致作为发布成立条件。
当前 TataConsole Flow 尚未同步 Apple 三 slice、单一 XCFramework 与本步测试闭集，
所以本步没有运行远程 CI、正式 Release 或 Hosted 上传；现有 Flow 的集成留给
任务卡后续统一流程/控制台步骤。

测试执行合同要求根 Flutter 包一次发现并执行全部根测试及已经迁入的 smoldot 测试，不再把
历史的 230 项与 51 项当成两套独立门禁；统一使用 `flutter test --timeout=2m`，以覆盖其中
最长 30 秒的活链订阅窗口。第 2 步隔离副本实际执行结果为 288/288。交易执行确认使用带
`System.Event`、`Phase` 与 `DispatchInfo` 类型的真实 Substrate v14 metadata 夹具，不得退回
只能解常量的最小 metadata。Android 必须真实运行插件 JUnit；正式 CI 还必须在
iOS 模拟器变体上执行 XCTest，并分别验证 iOS 设备变体、iOS 模拟器变体与 macOS
slice；三个 slice 当前 Apple 机器架构值均为 `arm64`。编译成功不等于平台测试执行成功。

本轮本机已构建 Android AAR 与 Apple 单一 XCFramework；框架只含 iOS 设备与模拟器变体及
macOS 三个 Apple `arm64` machine slice。iOS 设备与模拟器变体两组测试 bundle
均已编译；由于本机没有
Simulator runtime，未记录 iOS XCTest 运行成功。macOS 已实际运行 Core 50 项与
Flutter adapter 22 项 XCTest，0 失败，其中 1 项真机硬件用例跳过；最终
normal/supervisor smoke 均通过。本机无真实 Apple 移动设备，不声称 Secure Enclave、
生物认证或 device-only Keychain 已完成真机验收。

真实 Flutter consumer 已完成 Android release APK（ABI `arm64-v8a`）、iOS device Release no-codesign、
iOS 模拟器变体（Rust target `aarch64-apple-ios-sim`）编译和 macOS Release 构建；这些只构成正式配置的 build/link
证据，不构成移动真机或 Simulator runtime 证据。Flutter SPM 识别警告与 Android built-in
Kotlin 迁移提示推迟到第 9 步 Hosted/Flutter 集成处理。

同一本机闭集对 Hosted 精确 17 个 Dart 文件分析为 0 问题，完整 Dart 套件以
`--timeout=2m` 执行 316/316；根 Rust workspace 285/285、compile-fail 文档测试 1/1、
Clippy 与格式检查通过；Android 原生 Kotlin/Java 单元测试 Gradle 17 个 task 成功。
这些结果未经过 TataConsole 远程 Flow，也不是正式 Release、Hosted 上传或 Git 记录。

2026-08-29 包边界重构前的 TataConsole `.work` 隔离快照已实际通过根 Flutter
230/230 和独立 smoldot Dart 51/51。signer Rust 6/6、FFI Rust 5/5、PoW Rust
290/290（另有 3 项上游 ignored、14 个 benchmark 目标成功）、Android JUnit 3/3
与 TataConsole 99/99 是同一次任务中的先前执行记录；这些历史结果不冒充包边界重构后的
验证结论。iOS 的 2 项 XCTest
已编译链接，但本机没有 Simulator runtime，未宣称本地执行成功；正式 workflow
在 GitHub macOS Runner 上要求真实执行并失败关闭。

当前源码的候选合同包含 Android `arm64-v8a` 产品 ABI 投影，以及由共享 `darwin/` 源码生成的
`CitizenSDK.xcframework`。Android 原生 AAR 与 Flutter 插件使用同一 Kotlin facade、JNI、Rust
Core 和逐字节相同的双 SO；Apple 的 Swift 原生 API 与 Flutter adapter 使用同一个 XCFramework，
支持 iOS 设备变体、iOS 模拟器变体和 macOS，当前 Apple 机器架构值均为 `arm64`。Simulator 不提供
Secure Enclave，硬件金库与钱包能力必须报告不可用。Android Core/JNI 的 SONAME 固定为
`libcitizensdk.so` 与
`libcitizensdk_jni.so`，JNI 只能按 Core SONAME 依赖一次，任何含 `/` 的 `DT_NEEDED` 都失败。
Android Gradle/Kotlin persistent project state 只允许位于 TataConsole 中央 work directory；
源码和候选均禁止 `android/.kotlin`。iOS 设备与模拟器变体使用浅层 framework 和
`@rpath/CitizenSDK.framework/CitizenSDK` install ID；macOS 使用标准 `Versions/A` framework
和 `@rpath/CitizenSDK.framework/Versions/A/CitizenSDK` install ID。候选只允许 macOS
framework 标准布局所需的精确五个内部相对符号链接，其他任何符号链接均失败关闭。
LinuxARM、LinuxAMD、Windows 仍没有已交付的绑定、硬件金库和正式资产。legacy `libsmoldot.dylib` 只允许
作为 macOS `arm64` 差分测试宿主库；其 build-local `LC_ID_DYLIB` 不具分发身份，不得进入候选并须随
本机工作目录清理。

源码中的 Dart pubspec、Android Gradle 与 `darwin/citizen_sdk.podspec` 版本已统一冻结为
`1.0.0`。发布器在
复制前拒绝三者不一致，也拒绝 Release 请求版本与源码版本不同；复制后再核对候选 manifest、
pubspec 与两个平台版本。因此 GitHub Release 和 Hosted Package 只能来自同一准确版本提交，
不能在 Runner 中把旧源码临时改号。本步骤不执行 Hosted 上传；Hosted 身份、凭证和首次实际
发布仍需另行明确授权。现有 Release 仍只有 GitHub 正式分发动作，没有新增“发布”按钮。

## 产品外部边界

- TUYU v1 由途遇账户体系编码和验证，可选择调用钱包本地签名，但不进入 SDK。
- 广场和聊天由各产品及其 Cloudflare/服务端边界实现。
- CitizenWallet 冷钱包保持独立。
- CitizenApp 在单独批准切换前继续使用现有实现。
