# CitizenSDK Linux 平台合同

本文固定 CitizenSDK 第 7 步的 LinuxARM、LinuxAMD 平台投影。Linux 平台不会复制或改写
CitizenChain 轻节点、钱包、sr25519、Runtime 或交易实现；它只把根目录已经冻结的 70 个
`citizensdk_*` 产品 C ABI 与宿主操作系统能力组合起来。

## 当前状态

第 7.1 步只新增并审查 Linux C/C++ Host 源码、typed stores、TPM 2.0 Vault、SDK-owned
钱包流程、合同测试源码和文档。此时：

- 尚未注册根 `pubspec.yaml` 的 Linux Flutter plugin；
- 尚未把 LinuxARM、LinuxAMD 写入正式 Release manifest；
- 尚未生成或注入任何 `.so`；
- 尚未运行 Linux 编译、测试、远程 CI、Release、Hosted 上传或 Git；
- 因而不能把 LinuxARM、LinuxAMD 描述为已经交付的平台。

第 7.2 步才增加 Flutter adapter；第 7.3 步在两种真实机器目标完成编译、测试、ELF/ABI
核验和候选反向校验后，才允许原子启用公开平台声明。

## 平台与工具链

公开平台名称严格限定为：

| 平台 | GNU target triple | ELF machine | 第 7 步目标 |
|---|---|---|---|
| LinuxARM | `aarch64-unknown-linux-gnu` | ELF64 AArch64 | 待构建与验证 |
| LinuxAMD | `x86_64-unknown-linux-gnu` | ELF64 x86-64 | 待构建与验证 |

target triple、ELF machine 和 `CMAKE_SYSTEM_PROCESSOR` 是工具链机器值，不是产品名。目录、
manifest 和面向用户的 API 只能使用 `LinuxARM` 或 `LinuxAMD`，不得从机器字段派生额外平台
名称。Flutter 官方平台源码目录仍按工具约定使用小写 `linux/`。

首版基线是 glibc 2.31；不包含 i386、armhf、musl、riscv64、ppc64 或 s390x。候选验证必须
检查每个动态符号所需的最高 GLIBC version 不超过该基线，而不能只读取构建镜像名称。

## 分层与产物

```text
C/C++ App ───────────┐
                     ├── CitizenSDK::Host
Flutter App           │       │
  └─ Linux plugin ────┘       ▼
                     libcitizensdk_host.so
                              │
                              ▼
                       libcitizensdk.so
                              │
                              ▼
                     CitizenSDK Rust Core
```

- `libcitizensdk.so` 是唯一 Rust Core，必须精确导出根产品头声明的 70 个符号。
- `libcitizensdk_host.so` 只实现 HostBridge、typed stores、TPM/认证、SDK-owned 钱包 UI 和
  生命周期装配；不得包含第二份 smoldot、signer、Engine 或 Core 导出。
- CMake 公开导入目标固定为 `CitizenSDK::Core` 和 `CitizenSDK::Host`。
- C++ convenience API 是根 C ABI 上的 header-only RAII 包装；CitizenSDK 不承诺跨编译器的
  C++ 二进制 ABI。
- 第 7.2 步的 Flutter 动态库名固定为 `libcitizen_sdk_plugin.so`，只依赖 Host，不直接复制
  或静态链接第二份 Core。

正式候选的运行库路径在第 7.3 步固定为：

```text
linux/lib/LinuxARM/libcitizensdk.so
linux/lib/LinuxARM/libcitizensdk_host.so
linux/lib/LinuxAMD/libcitizensdk.so
linux/lib/LinuxAMD/libcitizensdk_host.so
```

这些运行库由发布构造器从源码树外注入；`/Users/rhett/GMB/citizensdk` 永远不保存生成的
`.so`、CMake cache、`build/` 或 `target/`。本机 CitizenSDK 生成状态只能进入
`/Users/rhett/TATA/tataconsole/target/citizensdk` 下由任务独占的工作目录。
Linux 合同测试配置必须通过
`-DCITIZENSDK_TEST_WORK_DIR=<绝对路径>` 显式注入其中一个已经存在、有效 UID 所有且权限精确
为 `0700` 的任务目录；CTest 将同名环境变量传给测试进程。测试 helper 逐级 no-follow 验证
后，以系统 CSPRNG 生成 128-bit 随机名称，并只通过已验证目录 fd 的 `mkdirat` 创建子目录；
不允许重新解析根路径或回退到 `/tmp`、当前目录、用户目录。

## Host 与 C ABI

根产品 ABI 仍是 70 个 `citizensdk_*` 函数。Linux 薄 Host ABI v1 另外精确包含 13 个
`citizensdk_host_*` 函数，用于 Host 创建、Core 借用、callback、父窗口、Vault 可用性、钱包
流程、单调销毁/监督移交和错误复制；它不增加链、钱包、签名、交易或任意 RPC 的第二套语义。

Linux Host 必须使用根 `citizensdk_create_with_host`，并实现完全相同的五类具名 store：

1. `CHAIN_DATABASE`：可重建的轻节点数据库及 finalized anchor；
2. `RUNTIME_CACHE`：按准确 block hash 绑定的可替换 metadata/runtime cache；
3. `WALLET_PROFILE`：钱包公开 profile、provisioning 与 cleanup 事实；
4. `TRANSACTION_HISTORY`：pending、in-block、finalized 历史和游标；
5. `ENCRYPTED_SECRET_BLOB`：只允许认证加密后的 child-secret envelope。

`CHAIN_DATABASE`、`RUNTIME_CACHE`、`TRANSACTION_HISTORY` 进入 public SQLite；
`WALLET_PROFILE`、`ENCRYPTED_SECRET_BLOB` 及 Vault 对象引用进入独立 secure SQLite。两库
不得合并。所有记录操作必须使用具名 domain 和结构化 key，不提供任意字符串键值逃生口。
Host config 强制要求小写 reverse-DNS `application_id`，实际状态根固定为
`storage_root/<application_id>/citizensdk/v1/{public,secure}`；不同宿主应用不得意外共用数据库，
改变 application ID 也不是隐式迁移入口。
CAS 必须跨进程共享、耐久且强原子；
`SQLITE_BUSY`、`SQLITE_ERROR`、`SQLITE_CORRUPT` 等后端错误不能伪装成“不存在”。路径必须
拒绝符号链接、hardlink、非普通文件和越界组件；最终 public/secure 目录及 DB、WAL、SHM
必须由进程有效 UID 拥有，三个文件的 link count 必须精确为 1。目录强制为 `0700`，主 DB、
WAL 与 SHM 的既有普通文件必须经 no-follow fd 收紧为 `0600` 并复核同一 inode 后才可使用。
SQLite 只能通过 CitizenSDK 自有的 openat 型 VFS 使用已经验证并持有的目录 fd；主库、rollback
journal、WAL 与 SHM 的创建、打开、访问、删除和锁定都必须相对该 fd 完成，并在使用前后复核
节点类型、有效 UID、link count 和 inode。不得再把 `/proc/self/fd` 路径或其它可被替换的绝对
路径交回默认 VFS，否则路径校验与 SQLite 实际打开对象可能分裂。

既有数据库不能只执行 `CREATE TABLE IF NOT EXISTS` 后即被信任。Host 必须逐项核验
`sqlite_master` 中精确表、列、约束和索引闭集，并设置后读回 `journal_mode=WAL`、
`synchronous=FULL`、`foreign_keys=ON`、`busy_timeout=5000`；secure 库还必须读回
`secure_delete=ON`。未知或漂移 schema、无法成立的 PRAGMA、额外对象及损坏类型都失败关闭。
写事务中的权限、inode 和存储合同检查必须在 `COMMIT` 前完成；`COMMIT` 成功是唯一 durable
成功线性化点，其后不得再执行会让调用者收到失败的动作，避免“已经提交却返回错误”。

Host operation 遵循根 ABI 的 exact-once 合同：同步返回 `CITIZENSDK_OK` 即表示接受，之后
必须且只能完成一次；其它返回值表示拒绝且禁止稍后 completion。completion 中的
`host_operation_id` 必须与 callback token 一致，跨接结果必须忽略而不能夺走另一操作。
私有钱包请求建立 route 期间同步到达的 completion 必须让 Core 专用 dispatch 线程在准入门
等待，并在 route 线性化后仍由该线程交付；实现不缓存 result，也不设置固定事件槽位。65 个
以上的压力波次或并发等待者不能导致 result 被释放、completion 被吞掉或失败被伪造。

C++ `EventObserver` 只在 trampoline 调用期间同步借用 event 和 result；observer 可同步检查或
复制公开结果，但不得保留或自行调用 `citizensdk_result_release`。header-only wrapper 在
observer 正常返回或抛出后都通过 RAII 对每个非零 result 执行一次 release。

每个公开 Host API 调用都必须先在同一个 admission/closing fence 下取得短期 lease；关闭先
永久封闭新 admission，再等待已经取得的 API lease、callback delivery、私有 route、Vault
operation 与钱包 UI 收口。callback 安装/清除和 parent window 更新也经过同一个线性化门，
关闭不得在持有重入 API 所需锁时等待根 Core callback，否则同步 callback 可形成死锁。

关闭与 Core 生命周期保持单调：停止 capability monitor、清除 callback、销毁 Core，失败只重试
当前或后继 teardown 阶段，最终 closed。任何阶段失败都不得重新开放请求，也不得提前释放 Core 借用的 HostBridge、
store 或 vault context。destroy 成功前必须退役 public/secure store 与 Vault、清零其敏感状态，
并确认所有 lease 已归还。Host-backed 实例必须先成功 graceful stop/checkpoint，直接 destroy
不能冒充持久化完成。显式调用者保留失败 handle 并自行重试；C++ RAII 析构等无法再返回错误
的边界只做有限的 callback-clear/destroy 尝试，失败即调用 `citizensdk_host_abandon` 把完整
所有权移交进程级 supervisor，由它先请求 checkpointed stop，再以有上限的退避间隔持续完成
同一单调 teardown。若连所有权移交都无法成立，析构必须 `std::terminate` 失败关闭，禁止释放
仍被 Host 借用的 callback context 或伪装为已经关闭。

## TPM 2.0 SecretVault

Linux 首版的硬件金库合同固定为 TPM 2.0，不以 Secret Service、文件 KEK 或纯软件密钥作为
降级路径。TPM 只保护 generation-scoped KEK，并只 wrap/unwrap 随机 32-byte DEK；child
mini-secret、助记词、展开私钥和 sr25519 请求始终不进入 TPM Host 接口。

每次 unwrap 使用独立的 CitizenSDK 设备金库解锁口令。该口令与 BIP-39 可选 password 是两种
不同秘密：前者只授权本设备的 TPM 对象，后者参与助记词派生。二者不得互换、自动复用或保存。
设备金库口令只可从 SDK-owned GTK 对话框进入受控原生缓冲区，禁止进入 Dart、Flutter tuple、
环境变量、命令行、日志或持久化记录。

TPM 会话要求：

- 使用 TPM2-TSS ESAPI；
- generation 对象不使用全局持久 handle，v1 只持久化 TPM public/private object blobs 和随机
  `auth_salt`；PBKDF2-HMAC-SHA256 与 600000 次迭代由 `secure-state-v1` 实现版本固定，不作为
  可漂移字段另行持久化，未来改变必须显式迁移存储版本；
- RSA-OAEP-SHA256 执行 DEK wrap/unwrap；
- 使用 salted HMAC session 和 parameter encryption，禁止 plaintext password session；
- load/validate/unwrap 前逐字段核对 child public template 的 type、nameAlg、批准 object
  attributes、authPolicy、symmetric、scheme、keyBits 与 exponent；仅比较对象 name 不足以证明
  它仍是 CitizenSDK 允许的解密 KEK；
- 不绑定 PCR，避免正常系统或固件升级无故毁坏仍由用户认证保护的钱包；
- 口令、明文 DEK 和中间 key material 在完成、错误和取消路径均清零。

能力映射必须如实反映运行设备：

| 运行事实 | Vault availability | 钱包结果 |
|---|---|---|
| TPM、认证 UI 和 provider 均可用 | `AVAILABLE` | 操作时再次认证后可用 |
| TPM 存在但无法提供强认证 UI | `NO_STRONG_USER_AUTHENTICATION` | fail-closed |
| 无 TPM 或缺少必需算法 | `UNSUPPORTED` | fail-closed |
| TPM 忙、不可访问或临时故障 | `UNAVAILABLE` | fail-closed，可在事实恢复后重试 |
| 用户取消认证 | 操作错误 | `AUTHENTICATION_CANCELLED` |
| 解锁口令错误 | 操作错误 | `AUTHENTICATION_REQUIRED` |
| TPM 清除、对象丢失或失效 | 操作错误 | `KEY_INVALIDATED` |

TPM availability 不使用算法名称枚举冒充组合能力；它必须检查 owner authorization 未被外部
配置、storage hierarchy 已启用、dictionary-attack 未锁定及计数/间隔/恢复参数有效，并以两次
`Esys_TestParms` 分别真实探测 RSA-2048/AES-128-CFB primary 与
RSA-2048/OAEP-SHA256 child/wrap 参数组合。任一条件不成立都必须报告不支持或不可用，不允许
自动改用软件 KEK、重新建钥或绕过用户恢复流程。无合格 Vault 时，链读取、同步和公开验证仍
可工作；`HARDWARE_VAULT`、
`LOCAL_SIGNING`、`WALLET_PROFILE` 与钱包交易构造不得被标记为 ready。

## SDK-owned 钱包流程

Linux Host 只为恢复词备份和恢复词/password 输入提供 SDK-owned GTK 界面，不添加 CitizenApp
导航、业务页面或另一套钱包模型。请求进入 UI 前必须完成以下同步校验：

- 创建只接受 12 或 24 词；
- 导入与追加的 `word_count` 必须为 `0`，禁止静默忽略其它 flow kind 的字段；
- 追加账户 index 非空、唯一并位于 `1..1989`；账户 `0` 是既有锚点，不能作为追加项；
- 恢复词、BIP-39 password 与设备金库解锁口令分别执行 UTF-8/长度门禁；
- 同一 CitizenSDK instance 的钱包流程与 close admission 原子互斥。

钱包流程只在 Core 已成功打开后受理；Host config 的 `enable_wallet=false` 返回
`CITIZENSDK_ERROR_UNSUPPORTED`，已启用但 TPM/认证事实不是 `AVAILABLE` 时返回
`CITIZENSDK_ERROR_UNAVAILABLE`，并且都必须发生在展示 GTK 界面之前。

创建仍是 Core 的 `prepare -> 用户确认备份 -> commit`，取消时必须确认 prepared handle 已
成功 release，不能把 release/storage 失败重标成取消。不可逆提交已经开始后，迟到取消也不能
覆盖真实错误。若 prepared release 暂时失败，flow 必须保留该 handle 和 lifecycle token，以
专用 supervisor 持续重试；只有 Core 确认 release 后才允许从 registry 删除 flow 或让 Host
close 继续。界面终态必须 best-effort 清空文本控件并清零原生敏感 buffer；这些防护不构成
对恶意同进程宿主、桌面录屏或全部内存副本的硬隔离。
generation 准入与 Vault object 条件写必须在同一 secure-store 事务中校验并提交；retire 墓碑
与 provision 必须线性化，使长认证提示期间完成的 retire 能拒绝迟到对象写。unwrap 在长提示
返回并即将交付明文 DEK 前必须重新核验 generation 未退休，失败时清零输出。
GTK widget 只能由创建它的 UI 线程销毁。若 `GMainContext` 被其它线程短暂获取，调度 source
必须保留并等待 owner 恢复；终态最多进行 8 次 source attach 重试。仍无法建立 UI-thread
清理时必须 `std::terminate` 失败关闭，禁止在 worker 线程析构 GTK 或遗留秘密控件后伪报完成。
parent window 的 `destroy` 必须在同一 UI 线程使 parent 引用失效、清空 dialog/password/恢复词
控件、结束等待并唤醒工作线程；禁止认证线程在最长五分钟等待后再解引用已经销毁的 parent。

## 测试和交付门禁

`linux/test` 的第 7.1 步源码测试覆盖公共 ABI 常量与 Host 函数闭集、CMake 构建/安装目标
投影、资产边界、operation exact-once、生命周期、public/secure store 隔离、record-key
namespace、敏感缓冲区、Vault 状态与错误映射、TPM 对象策略、秘密不进入 Linux 新增
Host/C++ 旁路以及钱包流程 admission。根产品 C ABI 的明确备份/恢复边界仍由根测试冻结。
软件 TPM 只能提供确定性集成测试，不能
替代 LinuxARM、LinuxAMD 实体 TPM 验收。

第 7.3 步公开 Linux 支持前还必须在两种目标上验证：

- ELF64 machine、SONAME、GLIBC 基线和 `DT_NEEDED` 闭集；
- Core 精确 70 exports，Host 不重复 Core symbols 且只依赖一次 `libcitizensdk.so`；
- RPATH/RUNPATH 不含绝对构建路径；
- 两种机器目标的 C/C++、Flutter、SQLite、软件 TPM 和实体 TPM 测试；
- 候选、归档和 Hosted dry-run 的逐文件闭集与反向校验。

本文件记录的是已经确认的设计和第 7.1 步源码边界，不是上述运行验证的替代品。
