# CitizenSDK 技术架构

## 单一产品原则

CitizenSDK 是一个产品、一个版本和一条分发链。轻节点、钱包和 signer 是内部能力层，
不拆成可独立发布的第二套 SDK。Flutter/Dart API 与原生 C ABI 是同一产品的两个接入面。

依赖方向固定为：

1. 宿主 App 依赖 `package:citizen_sdk/citizen_sdk.dart`。
2. 公共门面组合轻节点、钱包、交易与公钥验签。
3. 交易依赖本机轻节点 RPC 和钱包签名回调；钱包依赖公开事实仓储、安全存储及 signer。
4. Android/iOS 适配层依赖系统硬件安全能力与统一原生核心。
5. 原生核心依赖收编的 smoldot PoW 快照和 `schnorrkel` 等官方实现。

原生核心与产品无关 Dart 层不得反向依赖 CitizenApp、CitizenWallet、TuyuLove、TuyuLife、
TuyuBooking、聊天、广场、TUYU 协议、产品导航或产品数据库。

## 目录结构

```text
citizensdk/
├── lib/                    唯一 citizen_sdk 包及内嵌 smoldot Dart 绑定
├── native/
│   ├── signer/             唯一 sr25519 原生实现
│   └── smoldot/
│       ├── ffi/            轻节点与 signer 的稳定 C ABI
│       └── pow/            PoW + GRANDPA 轻节点 Rust 快照
├── android/                Android 插件与硬件金库
├── ios/                    iOS 插件与硬件金库
├── assets/                 chain spec 与 #0 light sync state
├── scripts/                外部原生构建与确定性候选工具
├── test/                   根包合同测试及迁入的 smoldot 测试
└── docs/                   产品技术文档和 smoldot 来源记录
```

根 `pubspec.yaml` 是唯一有效包清单，不含仓库本地 `path` 依赖。原 smoldot Dart 生产绑定
机械迁入 `lib/src/smoldot`，测试和夹具迁入 `test/smoldot`，历史包清单与来源说明归档到
`docs/smoldot-dart`。smoldot 只作为 CitizenSDK 内部实现参与同一版本和同一发布，不形成
第二个 SDK 或第二个源码真源。

## 运行时分层

- `CitizenSdk`：组合 `chain`、`rpc`、`wallet`、`transfers`、finalized 流水与 `signer`。
- `CitizenLightClient`：管理 smoldot 生命周期、随包创世锚、bootnode、同步健康、
  finalized database、JSON-RPC 与链头订阅。
- `WalletService`：管理一只无根热钱包、`//0..//1989` 多账户、创建/导入/追加/删除、完整
  可用性门禁、账户改名、本地任意载荷签名和用户主动的子账户私钥导出。
- `ChainRpc`：只经本机轻节点读取 finalized 状态、提交 extrinsic、订阅状态并核对
  `System.Events`；单/批读取 `System.Account` free/reserved，并从 runtime metadata 估算费用。
- `SignedExtrinsicBuilder` / `TransferService`：使用实时 runtime version、nonce、immortal era、
  sr25519 和公民链 `transfer_with_remark` 编码，并在广播前持久化本机 pending。
- `FinalizedTransactionScanner` / `FinalizedTransactionHistory`：按账户持久游标增量扫描 finalized
  转账，以 txHash、同 extrinsic index 的 System outcome 收敛本机 pending；每块事实原子提交。
- `lib/src/platform`：Android/iOS 硬件金库、公开钱包状态及 finalized database 的标准装配。

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
| 钱包公开事实 | `citizensdk.wallet.state.v1` | profile、revision、cleanup plan，不含秘密 |
| 轻节点数据库 | `citizensdk.smoldot.database.v1` | 公开 finalized database |
| 交易公开事实 | `citizensdk.transactions.state.v1` | finalized 流水、pending、逐账户游标，不含秘密 |
| 账户密文 | `citizensdk.wallet.secret.*` | 硬件金库信封 |

新硬件信封产品标识固定为 `citizensdk`。助记词和母种子不持久化；每个账户只保存 child
mini-secret 的设备密文。libp2p Noise 的连接级临时传输密钥不是钱包、TUYU 或管理员身份，
不进入钱包仓储或平台金库。

SDK 暴露底层仓储接口供受控集成和测试注入，因此宿主进程属于信任边界。标准移动装配只用
内置硬件金库；自行注入 `SecureSeedStore` 的宿主必须接受能够观察传入秘密的安全责任。

## 原生边界

根 signer workspace、FFI workspace 与 PoW workspace 都是 CitizenSDK 内部构建边界，不是
三个 SDK。FFI 的 Release profile 保持 `panic = "unwind"`，使 signer 的 `catch_unwind`
能够把 panic 转成错误码。

轻客户端不收编全节点 `author` 出块代码，以及 identity keystore/seed phrase 私钥入口；
只保留 JSON-RPC 所需的 `identity::ss58` 公钥地址编解码。全节点 SQLite 数据库源码按上游
快照保留并受 feature 控制，移动轻节点使用 finalized database 序列化。

## CI、Release 与平台边界

GMB 七个路由产品共有 24 条分组 CI/Release workflow，并由唯一顶层
`.github/workflows/gmb-repository.yml` 注册。CitizenSDK 使用其中两条：

- `gmb.citizensdk.sdk.ci`
- `gmb.citizensdk.sdk.release`

CI 与 Release 都从干净源码建立隔离构建快照，执行唯一根包依赖锁检查、静态检查、Rust 与
Dart/Flutter 测试、移动原生构建和候选验证。smoldot Dart 绑定和来源测试现与根 Flutter
包一起分析和执行。为保留已经验证的 smoldot 行为字节，静态分析继续报告迁入源码的既有
warning/info，但使用 `--no-fatal-infos --no-fatal-warnings` 只让 analyzer error 阻断流程；
格式检查、编译和完整测试仍失败关闭。三个 Rust workspace 都执行锁定测试；PoW workspace
另外使用 `cargo check --workspace --all-targets --locked` 编译包括 Criterion benchmark 在内的
所有 target，但不把使用随机输入的性能基准误当作确定性测试运行。Android/iOS 原生库注入
同一候选并完成确定性反向校验后，两条流程都从该目录建立逐字节临时验证副本并执行官方
`dart pub publish --dry-run`；
Dart 生成的 `.dart_tool`
因此不会污染正式候选。`.pubignore` 固定 Hosted 运行时闭包，禁止把 GitHub 审计包与 Hosted
包实现成两个源码真源。Release 还会验证指定
成功 CI 的 workflow、显示标题、产品目标、成功状态与准确 source SHA，不读取、下载或比较
CI 资产，并从同一提交重新构建；不以跨 Runner 归档字节必然一致作为发布成立条件。

测试执行合同要求根 Flutter 套件包含原 230 项和迁入的 smoldot 51 项，并统一使用
`flutter test --timeout=2m`，以覆盖其中最长 30 秒的活链订阅窗口。交易执行确认使用带
`System.Event`、`Phase` 与 `DispatchInfo` 类型的真实 Substrate v14 metadata 夹具，不得退回
只能解常量的最小 metadata。Android 必须真实运行插件 JUnit，iOS 必须在 Simulator 上执行
XCTest；编译成功不等于平台测试执行成功。这些是每个准确提交都要重新满足的测试合同，不是
对尚未完成最终验收的日期性结论。

2026-08-29 包边界重构前的 ProgramConsole `.work` 隔离快照已实际通过根 Flutter
230/230 和独立 smoldot Dart 51/51。signer Rust 6/6、FFI Rust 5/5、PoW Rust
290/290（另有 3 项上游 ignored、14 个 benchmark 目标成功）、Android JUnit 3/3
与 ProgramConsole 99/99 是同一次任务中的先前执行记录；这些历史结果不冒充包边界重构后的
验证结论。iOS 的 2 项 XCTest
已编译链接，但本机没有 Simulator runtime，未宣称本地执行成功；正式 workflow
在 GitHub macOS Runner 上要求真实执行并失败关闭。

当前正式候选只发布 Android `arm64-v8a` 与 iOS `arm64`。原生核心的分层允许以后增加
macOS、Linux、Windows 适配，但这些平台当前没有已交付的插件、硬件金库和正式资产。

源码中的 Dart pubspec、Android Gradle 与 iOS podspec 版本已统一冻结为 `1.0.0`。发布器在
复制前拒绝三者不一致，也拒绝 Release 请求版本与源码版本不同；复制后再核对候选 manifest、
pubspec 与两个平台版本。因此 GitHub Release 和 Hosted Package 只能来自同一准确版本提交，
不能在 Runner 中把旧源码临时改号。本步骤不执行 Hosted 上传；Hosted 身份、凭证和首次实际
发布仍需另行明确授权。现有 Release 仍只有 GitHub 正式分发动作，没有新增“发布”按钮。

## 产品外部边界

- TUYU v1 由途遇账户体系编码和验证，可选择调用钱包本地签名，但不进入 SDK。
- 广场和聊天由各产品及其 Cloudflare/服务端边界实现。
- CitizenWallet 冷钱包保持独立。
- CitizenApp 在单独批准切换前继续使用现有实现。
