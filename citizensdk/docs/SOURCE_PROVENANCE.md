# CitizenSDK 源码来源与同步策略

## 权威来源

`/Users/rhett/GMB/citizensdk` 是 CitizenSDK 产品源码、测试、锁文件、文档与打包脚本的唯一
权威目录。CI、Release 和宿主接入不得通过 `../citizenapp`、`../shared` 或其它仓库相对路径
读取运行时源码。

初始收编不改变现有产品：CitizenApp 继续使用自己的轻节点、钱包和交易实现；CitizenApp 与
CitizenWallet 继续使用 `shared/citizen-signer`。CitizenSDK 稳定后如需让 CitizenApp 切换，
必须另立并批准独立切换步骤，不能把当前复制过程反向写入现有 App。

从收编基线起，CitizenSDK 内部改动只在 `citizensdk` 演进。安全或共识修复如需同时回补
CitizenApp、CitizenWallet 或上游 fork，必须列出两侧精确文件、分别审查并用相同向量和行为
测试验证；不做自动双向同步，也不维护 CI 时跨目录复制。

## 许可证原文

根 `LICENSE` 是 CitizenSDK 组件许可证入口，明确 SDK 自有代码、smoldot Dart/FFI 与
smoldot PoW 的适用许可证边界，SHA-256 为
`85cbc4861f93949326d45a484db8df26125af2c19ba78b35f2a9e51bcaa5042a`；它还完整重现 Apache-2.0
原文，使过滤掉 `native` 源码目录的 Hosted 包仍携带适用条款。正式候选同时保留并固定
两份权威法律原文：`LICENSE-GPL-3.0` 与
`citizenapp/smoldot/pow/LICENSE` 逐字节一致，SHA-256 为
`aab56b4a581fc1c50b7c782eacf2fc8be05a47cd98e4bf4d836dd9b6dd9c86f4`；`LICENSE-MIT`
与 GMB 根 `LICENSE` 逐字节一致，SHA-256 为
`39d4ad97ead876b44da69d6d5a3cdc185cd109e82c508ffa5a29f65897c24e1c`。Release 来源守卫会拒绝
删除或内容替换。Apache-2.0 原文由固定的 `native/smoldot/LICENSE-APACHE-2.0` 提供。
`THIRD_PARTY_NOTICES.md` 是随已审查依赖演进的 CitizenSDK 自有归属清单，不冒充逐字节上游
副本，但始终进入候选文件清单和最终归档哈希。Hosted 过滤合同继续保留根许可入口、两份根
许可证原文和第三方声明；Apache-2.0 原文已内嵌于根许可入口，只把其 byte-identical 的
`native` 来源副本、完整来源记录与锁文件留在 GitHub 审计包。

## sr25519 signer

以下两个生产文件与 GMB 稳定 signer 逐字节一致：

| 来源 | CitizenSDK 目标 | SHA-256 |
|---|---|---|
| `shared/citizen-signer/Cargo.toml` | `native/signer/Cargo.toml` | `4b063da8dbf821d14798be37b41366be35418f5c14ed2b451420be80d424d3d8` |
| `shared/citizen-signer/src/lib.rs` | `native/signer/src/lib.rs` | `4fcdcda78e3050ab2daff782881b2c223ddabf61dc00113f4f83f799b5436f9d` |

派生、context、错误码、C ABI、panic 捕获和内存清理逻辑没有在复制时重写。CitizenSDK 在
相邻 `tests/` 增加产品内 FFI 合同和 Substrate 向量测试源码；这些新增测试不改变上述两份
生产基线。

## smoldot Dart 包

`citizenapp/smoldot/dart` 是初始来源。为使根 Flutter 包能够作为单一 Hosted Package 直接
解析，Dart 包边界只做以下机械重排：

- `lib/smoldot.dart` 与 `lib/src/*` 迁入 `lib/src/smoldot/*`；
- 6 个 Dart 测试和两个公开链 fixture 迁入 `test/smoldot`；
- 包清单、锁文件、分析规则、许可证、上游说明和示例迁入 `docs/smoldot-dart` 作为历史记录。

根 `pubspec.yaml` 是唯一有效包清单，已经直接声明 smoldot 绑定需要的 `ffi`、`meta`、`path`
和 `convert` 依赖，不再声明本地 `path` 包。历史清单使用 `source-` 前缀，禁止参与依赖解析。
生产绑定除 import/export、移动测试夹具路径、移动平台测试加载路径、交付范围注释和根包
formatter 归一外不改行为；
发布器继续对迁移闭集逐文件固定哈希，并对 `native/smoldot` Rust/FFI 闭集反向枚举。

历史 `README.md`、`BUILD.md`、`UPSTREAM.md` 中的桌面平台、CitizenApp 路径及源码树内
`target` 命令不代表 CitizenSDK 当前交付合同，也不得作为 SDK 构建指引。CitizenSDK 当前只
交付 Android ARM64 与 iOS ARM64；宿主测试库与全部生成记录只能写入 Runner 临时目录或
ProgramConsole 中央目录。实际指引以本文件、根 README 和 `docs/NATIVE_PACKAGING.md` 为准。

## smoldot FFI

FFI 来源是 `citizenapp/smoldot/ffi`。以下文件保持来源字节：

- `rust-toolchain.toml`
- `src/error.rs`
- `src/ffi_types.rs`

以下文件只做 CitizenSDK 产品边界适配：

- `Cargo.toml`：删除 OpenMLS、聊天信封和账户数据加密依赖，signer 指向 SDK 内部路径。
- `build.rs`：删除聊天源文件监控。
- `src/lib.rs`：删除聊天和账户加密导出，保留 `smoldot_*` 与四个 sr25519 入口。

来源独有的 `src/chat_mls.rs` 没有复制。SDK 新增 README、公共头文件合同与范围守卫测试。
`native/smoldot/ffi/Cargo.lock` 从 CitizenApp 已验证锁文件机械裁掉 OpenMLS、聊天与账户加密
闭包；所有保留的 registry 包继续使用来源锁中的准确 name/version/checksum，不引入新身份。
SDK 锁文件 SHA-256 为
`05190e2ed21987a8ca61c023c47eadc29f9cb415a065308843af5c4ad37537e7`。

## smoldot PoW + GRANDPA

来源是 `citizenapp/smoldot/pow`，上游提交与本地 PoW 改动清单见
`native/smoldot/UPSTREAM.md`。

`pow/light-base` 的 18 个来源文件全部逐字节复制，SDK 只增加说明和能力/来源闭集测试。
它保留数据库、网络、JSON-RPC、runtime、同步、交易池和平台编排。

`pow/lib` 收编轻客户端需要的 chain、chain-spec、finality、header、verify、trie、executor、
database、JSON-RPC、libp2p、network、sync、transactions、公开测试夹具和上游内联测试。
共享生产文件逐字节复制，仅对 Cargo/workspace、crate 模块入口和 `identity` 模块做最小适配。

明确排除的 8 个来源文件是：

```text
src/author.rs
src/author/aura.rs
src/author/build.rs
src/author/runtime.rs
src/author/runtime/example-chain-specs.json
src/author/runtime/tests.rs
src/identity/keystore.rs
src/identity/seed_phrase.rs
```

前 6 个属于全节点出块，后 2 个会形成轻客户端钱包之外的第二条私钥生成/保存路径。保留的
`identity::ss58` 只处理公钥地址。SDK 另加来源 manifest 和轻客户端能力边界测试，用来钉死
排除项与逐字节来源集合。

`native/smoldot/pow/Cargo.lock` 从 CitizenApp 已验证 workspace 锁文件机械裁掉全节点与 WASM
成员不可达闭包；所有保留的 registry 包继续使用来源锁中的准确 name/version/checksum，不
引入新身份。SDK 锁文件 SHA-256 为
`6d832fb629bbf19ff6c2cce589c6285c3367cbcb3b55f4819beb7e733d9e038b`。

Release 门禁把 `native/smoldot` 固定为 223 个普通文件的完整闭集：来源清单自身 1 个、清单
四个单元中的 Rust/锁文件 213 个，以及以下 9 个单元外支持文件。迁出的 Dart 生产、测试和
来源记录另由跨目录闭集固定。门禁不仅逐文件校验哈希，还反向枚举目录；新增、删除、符号链接
或单字节变化都会失败关闭。

| 支持文件 | 来源分类 | SHA-256 |
|---|---|---|
| `LICENSE` | 与 `citizenapp/smoldot/pow/LICENSE` 逐字节一致 | `aab56b4a581fc1c50b7c782eacf2fc8be05a47cd98e4bf4d836dd9b6dd9c86f4` |
| `LICENSE-APACHE-2.0` | 与 `citizenapp/smoldot/dart/LICENSE` 逐字节一致 | `4524e4d70a6295dfa882b0411cc49fcca03273e959fea68bbfe7df7ed63e7d78` |
| `README.md` | CitizenSDK 边界说明 | `00edbd5b7559d061e43b3d6e1d64e3d760340c28799dccd880af20a32c8a6b52` |
| `UPSTREAM.md` | CitizenSDK 上游与本地改动说明 | `9826a09529ebf2eabb253d05bcccbf8b2107e9c39950ee0aa200b06b5e4feb94` |
| `include/README.md` | CitizenSDK 公共 ABI 说明 | `2ae510563d3b87a852bc990d462ad940d92578b05fbe9809a9c82d63c16503bc` |
| `include/citizensdk.h` | CitizenSDK 聚合公共 ABI | `18c476d67cd00822b1a14fe4317330d56195712a7f8e33f39a487d84ad1a0819` |
| `include/smoldot.h` | CitizenApp 头文件删除聊天/OpenMLS 导出后的边界适配 | `f7c2645588809f73f8aa799975b363a4a7b22e8de7149da9d0b4c2ea20c90a20` |
| `pow/demo-chain-specs/polkadot.json` | CitizenApp 逐字节来源；由 `light-base/examples/basic.rs` 编译引用 | `859c8ade8b740e6a106082e0fdb4ae14075d79f8a277f02124bf9856d8a302aa` |
| `pow/demo-chain-specs/polkadot_asset_hub.json` | CitizenApp 逐字节来源；由 `light-base/examples/basic.rs` 编译引用 | `4909f824189edd0c7c64e444f81a4082fe5bc433861a5ac9e8b00838203a35ab` |

## 链资产、轻节点行为与交易

以下固定链资产逐字节来自 CitizenApp：

- `assets/chainspec.json`，SHA-256
  `6ae934933682a8ffca78663dd4391a730b6ae219bd12abfb5d96b4d8154fc2e0`；
- `assets/light_sync_state.json`，SHA-256
  `014802836a0f6e01a9f1bf7173b8e04c9df8fc3f057565f855abdccdc7361ab6`。

Release 门禁反向枚举 `assets`，只允许上述两个普通文件，并逐文件固定哈希。仅验证 JSON 可解析、
bootnode 数量、区块高度或哈希字段形状不能替代这项逐字节信任锚检查。

CitizenApp 的轻节点服务、钱包管理器和交易 RPC 同时耦合全局单例、Isar、日志、身份、
聊天、广场或服务器中继，不能整文件复制进产品无关 SDK。以下层属于行为收编与适配，不宣称
目标文件逐字节相同：

- `lib/src/node/*`：复制启动/停止/重试、同步健康、缓存锚、finalized database、bootnode、
  JSON-RPC、链头订阅和错误语义，并改为可注入的 SDK 依赖。
- `lib/src/wallet/*`：复制无根钱包、多账户、失败回滚、删除清理、完整热钱包可用性门禁、
  账户改名和用户主动查看子账户私钥的行为，并改为 revision CAS 与平台安全存储接口。导出
  只返回 child mini-secret；内部字节清零，宿主必须处理不可擦除 String 的展示风险。
- `lib/src/transaction/*`：复制实时 metadata/runtime/nonce、immortal extrinsic、
  `transfer_with_remark`、本机提交与状态订阅；补全同一 extrinsic 的
  `System.ExtrinsicSuccess/Failed` 核对；submit-only 收到 finalized、等待式交易收到目标
  inBlock/finalized 后都由执行核对独占终态，忽略交易池订阅的迟到数据、错误和关闭。执行
  核对的总 deadline 同时覆盖区块体、txHash 定位、`System.Events` 与首次 runtime metadata
  读取；任一传输 Future 永不完成都会受控返回“未核实”，metadata 超时后也不会留下永久
  污染后续交易的 in-flight 缓存。runtime version 与 metadata 现按同一块/specVersion 原子
  绑定，前一代 in-flight 迟到不得倒灌；观察回调及订阅取消 Future 的异常不改变终态。
- `ChainRpc` 同时收编 finalized `System.Account` free/reserved/total、一次 batch storage 的
  多账户余额，以及完全由 metadata `OnchainFeeRate`/`OnchainMinFee` 驱动的 runtime 同值
  手续费估算；不存在与传输失败保持不同语义。

产品适配明确删除 CitizenApp 日志、导航、CID、冷钱包、产品数据库、远程交易中继、聊天和
广场。对应 Dart/Flutter 测试源码覆盖生命周期、缓存、订阅、钱包故障窗口、交易状态、同块
extrinsic 定位及 runtime 执行结果；这些是 CitizenSDK 自有合同测试，不冒充逐字节来源。

交易执行确认使用
`test/transaction/fixtures/substrate-v14-system-events-metadata.hex` 中的真实 Substrate v14
runtime metadata 快照，SHA-256 为
`95b368e7907511b28ba283a6741f4be551b56fb917c2f0183b4143dbe0ebf95b`。它逐字节来自 CitizenApp
已验证的 full-node 测试夹具，只为测试提供 `System.Event`、`Phase`、`DispatchInfo` 等 SCALE
类型；CitizenSDK 不因此复制、编译或开放全节点出块能力，也不把该夹具作为运行时信任锚。
Release 来源守卫同时固定该夹具哈希，防止测试和测试输入一起漂移后产生伪通过。

CitizenServe 的 `/chain/citizensdk/bootstrap` 使用逐字段投影生成 SDK 独立 wire schema，不把
CitizenApp 的 `chain_name`、`chain_type`、`bootnodes_source` 或产品服务字段泄漏给 exact
parser。服务端测试与 SDK 客户端测试共同读取
`test/node/citizensdk_bootstrap_manifest.json`，分别验证服务端输出和客户端解析，且该夹具
进入 Release 测试源码闭集；它只用于跨端合同，不是运行时链状态真源。

钱包派生合同另外逐值收编 CitizenApp/CitizenWallet 已共同验证的 `//0`、`//1`、`//2`
child mini-secret、AccountId、SS58 与非空 password 金标，并用 `polkadart_keyring` 作外部
Substrate URI 派生参照。password 测试保留共享真源的 6/30 边界、30/31 拒绝、NFKD、空白、
换行、emoji、全角、韩文和西里尔字符边界；仅产品 UI 风险确认框不属于 SDK 密码学测试。

## 移动硬件金库

Android/iOS 安全语义参考 `shared/hardware-secretvault` 与 CitizenApp 稳定装配：

- Android：StrongBox/TEE RSA-OAEP KEK、AES-256-GCM、逐次强生物识别。
- iOS：Secure Enclave ECIES、`biometryCurrentSet`、`WhenUnlockedThisDeviceOnly`。
- 两端继续使用字节通道和 v1 信封，但产品、别名、AAD 与通道固定为 `citizensdk`。

这是平台插件适配，不是逐文件副本。SDK 不包含 CitizenApp 别名读取、转换或删除分支。

## 锁文件与测试收编

CitizenSDK 的受控依赖输入包括：

```text
pubspec.lock
Cargo.lock
native/smoldot/ffi/Cargo.lock
native/smoldot/pow/Cargo.lock
```

唯一根 Dart 包、signer、FFI、PoW workspace 都在 CI/Release 使用 locked/enforce-lockfile
模式。`docs/smoldot-dart/source-pubspec.lock` 只保存来源事实，不参与解析。锁文件属于源码输入，
不是编译产物。Release 还逐字节固定根 `Cargo.lock`（SHA-256
`62571bec0b3a1f40af270aa22415124ae201f07ebd1d0de35ab23884317d5670`）和根
`pubspec.lock`（SHA-256
`d71a06a3c9b899872e8f1ea28c4a871da02707e2f3ccb0a47a140d33d8465e06`）；其中根 Cargo 锁是
CitizenSDK signer 独立 workspace 的已审查解析闭包，不宣称与 CitizenApp 整份锁逐字节相同。
当前闭包的密码学核心 `schnorrkel 0.11.5`、`zeroize 1.9.0` 与已验证来源一致，独立解析得到的
`syn 3.0.4` 作为 SDK workspace 适配身份明确固定。任何依赖升级都必须显式更新哈希与合同测试。
Release 对 `native/signer` 做 6 个普通文件的逐字节哈希与反向闭集检查；两份生产真源、两份
说明和两份合同测试缺一不可，额外 `build.rs`、`src/bin` 或其它文件也必须失败关闭。

测试来源分三类：上游/CitizenApp 逐字节夹具与内联测试、迁入根套件的 Dart smoldot 测试、
CitizenSDK 新增的来源闭集/能力边界/平台/钱包/轻节点/交易/发布合同测试。文档只记录测试
来源和职责；实际通过数量必须由对应提交的执行报告产生，不能由文件数量或历史候选推断。

Release 反向固定的 SDK 自有测试源码增加了 `test/smoldot` 的 6 个测试与两个公开链 fixture；
其余根测试、signer、Android、iOS 和 `scripts/release.test.mjs` 继续处于同一反向闭集。Android 闭集准确固定
`android/src/test/README.md`、`android/src/test/kotlin/README.md`、
`android/src/test/kotlin/org/README.md`、`android/src/test/kotlin/org/citizen/README.md`，以及官方
`org/citizen/sdk` 包目录中的 `HardwareSecretVaultTest.kt`、`VaultEnvelopeTest.kt`；扁平或其它包路径
均属于闭集漂移。文件闭集与运行时测试数量是两项不同合同，均必须满足。

当前完整测试执行合同把原根 Flutter 230 项和 smoldot Dart 51 项合并到同一根套件，使用
`flutter test --timeout=2m`，不能以默认外层超时截断其中的 30 秒活链订阅窗口。移动平台合同
还必须在临时宿主中真实运行
Android `:citizen_sdk:testDebugUnitTest` JUnit 与 iOS Simulator `xcodebuild test` XCTest；只编译
插件、发现测试或生成测试报告都不能替代执行。上述数量和命令描述测试套件合同，不是尚未完成
的某次最终验收结果。

2026-08-29 包边界重构前的 ProgramConsole `.work` 隔离快照已实际通过根 Flutter
230/230、独立 smoldot Dart 51/51、钱包定向 88/88、交易定向 85/85、signer Rust 6/6、
FFI Rust 5/5、PoW Rust 290/290（另有 3 项上游 ignored、14 个 benchmark 目标成功）、
Android JUnit 3/3、Release 合同 18/18、ProgramConsole 99/99 与统一数据字典定向合同 2/2；
这些历史结果不冒充本次目录重构后的验证结论。
Android 最终冻结副本与产品真源逐字节目录比较无差异，生成的 CitizenSDK AAR 只包含
`arm64-v8a/libsmoldot.so`。iOS ARM64 设备 Release App 与 ARM64 Simulator 测试包均完成
编译链接并保留全部 25 个轻节点/sr25519 导出符号；设备与 Simulator 静态归档各有 397 个
可解析 Mach-O 对象，最低系统版本全部不高于 iOS 16.0。本机没有 Simulator runtime，故
没有把 2 项 XCTest 记为本地执行通过，正式 workflow 继续在 GitHub macOS Runner 上强制
真实执行。本轮禁止运行 Git，因而不把内部调用 Git 的 GMB 完整仓库套件记为当前通过。

## 同步流程

1. 选定 CitizenApp 稳定提交和 smoldot 上游基线。
2. 在临时目录生成来源/目标文件闭集、差异与哈希，先核对明确排除项。
3. 逐字节更新来源快照；产品适配文件单独审查，不把适配伪装成上游原文。
4. 同步锁文件、许可证、来源 manifest 和全部相关测试。
5. 在源码树外执行根/嵌套 Dart、三个 Rust workspace、平台原生构建和候选反向验证。
6. 更新本文件的基线提交、排除清单与必要哈希；不得把临时 patch 或构建产物留在 SDK。

任何同步都不得在 CI/Release 时回指 CitizenApp，也不得让一个产品静默覆盖另一个产品的
权威源码。
