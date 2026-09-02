# CitizenSDK 安全模型

## CitizenChain 随包信任资产

`assets/README.md` 规定随包静态资产不得混入设备数据库、缓存或秘密；
`assets/citizenchain` 是 SDK 唯一随包链信任目录。`manifest.json` 使用精确字段闭集固定
`product_id = citizensdk`、`chain_id = citizenchain`、`protocol_id = citizenchain`、
genesis hash 和两个资产 SHA-256。SDK 先验证摘要，再从 `#0` header 重算 genesis hash，
并核对 chainspec state root；失败时不得创建或初始化 smoldot 原生客户端。

远端 `/chain/citizensdk/bootstrap` 只提供经过边界校验的 bootnode 建议，不能下发 RPC、
checkpoint、manifest 或链资产摘要覆盖。本版本没有在线链资产替换通道。

## sr25519 固定口径

- 唯一实现是 `native/signer` 中的 `schnorrkel`，不增加纯 Dart 或自研实现。
- mini-secret 扩展模式固定为 `ExpansionMode::Ed25519`。
- 签名 context 固定为字节串 `substrate`。
- 硬派生 chain code 按 Substrate junction 规则生成。
- mini-secret、展开后的 SecretKey 和签名临时字节在作用域结束时清零。
- signer FFI 用 `catch_unwind` 把 panic 转为错误码；FFI Release profile 不允许破坏该契约。

## Rust Core 的秘密与 provider 合同

`native/contracts` 已经把 `ChainSigner` 与 `SecretVault` 分开：前者负责 sr25519 派生、签名与
验签，后者只负责设备密文、硬件保护、解锁和用户认证。Android Keystore、Apple Secure
Enclave 以及未来其它平台金库都是 `SecretVault` provider，不冒充能够原生执行 sr25519 的
硬件 signer。

合同层的 `SecretBuffer` 由 `Zeroizing` 持有字节，不实现 `Clone` 或序列化，`Debug` 始终
脱敏，并只把借用交给同步 Rust 闭包。这个设计缩短 Rust Core 内明文生命周期，但不是同进程
硬隔离：受信任闭包仍可主动复制字节，因此 signer/Vault provider 必须继续审计。五类状态仓储
分别承载轻节点数据库、runtime cache、钱包公开资料、交易历史和加密信封；加密信封仓储的
类型不能接收明文秘密，系统金库仍是独立的第六边界。

`WalletAccount` 会从 `AccountId32` 重算 SS58 prefix `2027` 的规范地址；`WalletProfile` 固定
wallet index `0` 和账户0锚。`WalletState` 必须同时携带 provisioning 的 target profile：
create/import 精确拥有全部 target refs 并在回滚时删除本代 wallet key；append 的 previous
profile 是 target 账户列表的严格前缀，既有字段逐项不变，计划只拥有新增 refs。provisioning
与 active cleanup 互斥；cleanup refs 非空、唯一且属于同一 generation，queue 最多 64 项，
各计划的 operation ID 与物理目标不得重叠，也不得命中当前 secrets 或当前 generation KEK。

第 4.1 步的 Rust 钱包服务已经实现 BIP-39 派生、创建/导入/追加、可用性核验、切换、改名、
签名、删除和清理重放。助记词、master 与 child 只以可清零 Rust 缓冲区参与派生或金库调用；
`bip39` 显式启用 `zeroize`，NFKD password 临时值及 Engine 持有的 password 使用
`Zeroizing<String>`。
`native/signer/src/sr25519.rs` 是唯一算法实现，legacy FFI 与类型化 `ChainSigner` 都调用它。
Rust Core 没有私钥导出方法。

产品级 `citizensdk_*` C ABI v1 同时保留原有 chain-only 构造和完整
`citizensdk_create_with_host` 构造。后者只接受职责分离的链数据库、Runtime cache、钱包公开
资料、交易历史、设备密文和 KEK/DEK 金库合同；宿主不能注入 signer、任意 RPC 或 nonce
来源。钱包创建/导入/多账户、通用载荷签名和高层转账/历史入口都经同一个 Rust Engine，
钱包模式下原始 signed-extrinsic submit/watch 在触达 provider 前失败关闭。
legacy `citizensdk_create` 路径原 36 个 ABI 符号、数值、布局和单请求功能语义保持不变，新增
34 个符号，总计 70 个。

Apple 绑定为 Core 借用的 HostBridge、callback、store 和 vault context 保留显式 ABI +1。
关闭只能沿 `live -> monitorStopped -> destroyOnly -> closed` 单调前进；callback clear
在首次 destroy 前已持久，部分关闭后不得重新开放请求。destroy 成功时先释放
HostBridge/数据库，再且只释放一次 ABI +1。显式 close、deinit 或 Flutter detach 失败
把整个 facade 交给进程级 supervisor 按有界退避继续收口，不提前释放借用上下文。
C capability/lifecycle 回调只入队，Core 查询由专用队列执行；这防止 Core callback
线程与 close/destroy 形成重入死锁。wallet ownership 在 open/owned/closing/closed 状态上原子
线性化，交给 supervisor 后即使重试在 teardown 前失败也继续 fail-closed。

创建备份以及 import/add 的用户恢复词输入是唯一明确允许跨语言绑定的助记词边界：创建只由
SDK-owned prepared handle 为明确备份 UI 临时输出，并同时校验 owner SDK handle；另一实例
不能读取、释放或消费。import/add 只接收用户显式输入。C ABI 只接收或返回临时字节缓冲区；
public binding 不得把它转换成日志、返回值或持久缓存。SDK-owned 原生 UI 是唯一展示/输入例外，
流程终态必须 best-effort 清空平台控件和可清零缓冲区。
已经持久化或解锁的 child mini-secret、展开私钥不经过 Dart/Swift/Kotlin；产品 ABI 不提供私钥
或 child secret 导出。Android 恢复词/password 仅进入非导出、`FLAG_SECURE` 的 SDK-owned
Activity。Apple 使用共享 Darwin native 边界；Security framework 解封 DEK 时返回不可变
`CFData`，只在对应 `autoreleasepool` 内短暂存活。桥接层避免生成 Swift `Data`/COW 副本，
在不能可靠原地清零的边界下立即把精确 32 字节复制到 Rust-owned buffer，并由 pool 排空释放；
Rust-owned 输出在使用后清零。
助记词、password、child mini-secret、private key、DEK 及 native/result/prepared handle 都没有
Flutter tuple 位置。旧 Dart 硬件秘密通道与装配已删除，归档差分源码不是正式平台运行路径。

## 设备机密与受信任宿主

助记词、母种子、child mini-secret 和私钥不得上传到 TuyuServe、TuyuBooking、Cloudflare、
GitHub、TataConsole 或任何远端服务。标准移动装配只在用户设备硬件金库保存 child 密文，并在
本地认证、解密和签名。

CitizenSDK Core 使用 RustCrypto `aes-gcm` 在 Rust 受控缓冲区内以随机 256 位 DEK 和随机
nonce 认证加密 child mini-secret；AAD 精确绑定 `citizensdk`、wallet index、generation、secret owner、
AccountId 和秘密类型。Android Keystore/StrongBox 或 Apple Secure Enclave 只创建、查询、
退休 KEK，并封装或解封 32 字节随机 DEK，绝不接收 child mini-secret 或执行 sr25519。
解封目标必须是 Rust 拥有的固定 32 字节输出缓冲区，签名结束后立即清零。Android 仍要求
逐次 `BIOMETRIC_STRONG`；Apple 要求 `biometryCurrentSet + privateKeyUsage` 与
`WhenUnlockedThisDeviceOnly`。Android 与 Apple 正式投影均使用上述边界；`iOS-Simulator` 因无
Secure Enclave 必须如实报告硬件金库和钱包能力不可用，不能用软件降级冒充真机安全能力。
Android 恢复词与密码在比例分配或 JNI 复制之前必须通过严格 UTF-8 校验和 1024-byte 上限；
Kotlin/JNI 临时敏感缓冲区以单一所有权管理，并在全部成功、错误和异常出口清零。
Apple 通过分离的 typed public/secure SQLite 保存公开状态与加密秘密事实。SDK-owned wallet UI
会在流程终态前由文本控件和短期 Swift `String` 持有恢复词/password；终态 best-effort 清空
控件与 Rust 敏感 buffer，但 Swift `String` 不可可靠擦除。实现不得将其返回 public Swift API、
记录、持久化或发送到 Flutter。iOS
没有 `FLAG_SECURE` 等价能力，只能在录屏/后台切换时提供 best-available 覆盖层；macOS 的
SDK-owned window 禁止系统共享。这些界面防护不是对恶意宿主进程或全部截屏路径的硬隔离。

宿主进程仍属于信任边界，但公共 host v1 合同没有“任意键值仓储”或 child-secret callback：
五类存储操作各自具名，金库只接触随机 DEK。恶意同进程宿主仍可篡改公开持久状态、拒绝
completion 或观察本来就需要展示的恢复词，因此 SDK 不能宣称对宿主进程提供硬隔离；所有
host callback、存储原子性和平台绑定都必须审计。

没有合格硬件金库或设备能力时必须失败关闭钱包创建、导入、追加账户、签名和签名交易；
公开轻节点查询与公钥验签仍可用。

## 钱包一致性

以下 CAS/provisioning/cleanup 契约由 Rust `WalletService` 实现，并与归档 legacy Dart 差分
基线对齐；其中 `WalletProfileStore`/`EncryptedSecretBlobStore`/`SecretVault` 是 Rust 名称，
`WalletRepository`/`SecureSeedStore` 是 legacy Dart 名称。Android 与 Apple 正式装配均已切换到
Rust typed stores；这些 Dart 类型仅用于受控差分测试，正式绑定不可达。

- `WalletRepository` 只保存公开 profile、revision、provisioning plan、active cleanup 和
  不相交的 exact cleanup queue。
- `SecureSeedStore` 每个账户只保存 `//index` child mini-secret。
- 创建首先生成只存在于 Rust 内存的一次性会话；准备阶段对 profile、密文和 KEK 零写入，
  用户确认已经备份助记词后才消费会话进入持久提交。由此消除“钱包已提交、唯一助记词尚未
  返回”之间的不可恢复崩溃窗口。导入因用户本来持有助记词，不需要该展示阶段。
- 确认创建、导入、追加账户先预检强生物识别，再为钱包、账户秘密和操作生成 CSPRNG 128 位身份；
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
- 删除先持久化 cleanup plan，再把每个 `SecretRef` 从 `Vacant/Sealed` 单向推进到永久
  `Tombstone`；整钱包删除还要求 `SecretVault` 持久退休 generation，之后任何旧 operation 的
  `seal` 都必须失败。墓碑和退休记录先于清理成功返回落盘，未完成计划保留并可重放。
- Rust 钱包变更与 `sign` 由进程内统一操作门串行；legacy Dart 对应路径在同一 isolate 内跨
  `WalletService` 实例串行。签名前再次确认 exact generation/owner 与账户仍存在，成功或失败
  均由秘密缓冲区完成清零。
- `usableProfile` / `isUsable` 不只读取公开 profile，而是验证账户0、KEK 及全部 child 的
  sr25519 公钥；后端异常上抛，不能把认证、金库或仓储故障伪装成“无钱包”。
- `renameAccount` 只经 revision CAS 修改公开名称；cleanup 未完成或并发删除时失败关闭，绝不
  代为创建、恢复或删除秘密。
- `getAccountPrivateKey` 只属于归档 legacy Dart API：它返回不可擦除的 Dart `String`，
  宿主必须负责风险确认、防截屏、禁日志/持久化/上传和尽快丢弃引用。Rust Core 与新的产品
  C ABI 明确不提供对应私钥导出路径。
- 进程内操作门只减少同进程竞争，不是安全真源。Rust `EncryptedSecretBlobStore` 必须跨进程
  提供共享、耐久、强原子 CAS 和永久墓碑，`SecretVault` 必须提供 generation retirement；
  两道 fence 共同阻止 cleanup 后的迟到密文/KEK 复活。SharedPreferences 仍不自动满足这些
  Rust 合同，legacy Dart 路径也仍只承诺同 isolate 串行，不能借 Rust 合同夸大现有装配。

## 轻节点与交易

公民链状态由设备内 smoldot P2P 轻节点验证。Bootstrap 只能提供固定 schema 下的链身份与
bootnode 建议；根对象及 `chain/light_client/p2p/security` 都必须精确匹配字段闭集，不能夹带
聊天、广场、TUYU、宿主业务、远程 RPC 或链状态真源。Bootstrap 地址只允许 HTTPS，本机
回环地址也不允许使用明文 HTTP；SDK 不实现服务器签名或通用 RPC 代理。

`author_submitExtrinsic` 返回 txHash、peer 广播、`inBlock` 和 `finalized` 都不能单独证明
runtime 执行成功。SDK 必须按 txHash 定位同一 extrinsic index，并读取该 index 的
`System.ExtrinsicSuccess/Failed`；未找到明确结果时报告未核实。收到 finalized 后由执行核对
独占后台终态，订阅流的迟到数据和错误不能形成与执行结果冲突的第二终态。

runtime version 与 metadata 必须在同一 finalized/目标块上读取并按 `specVersion` 绑定缓存；
前一代 in-flight 请求迟到不能覆盖新缓存。余额批量读取只走轻节点 finalized batch storage，
手续费只信任同一 metadata 的链上常量。状态观察回调和订阅取消 Future 的异常均为
best-effort 隔离，不能泄漏未处理错误或改变交易终态。持久 `RuntimeCacheStore` 是可替换的
性能层，不是交易执行证据；安全关键终态核验必须直接从 provider 取得准确 finalized 块的
runtime context，不能信任宿主可写缓存中的 metadata。

Rust 交易构造只接受准确 CitizenChain 身份、同一 best 块的 runtime context 和同次
`AccountNonceApi_account_nonce` typed snapshot。该 Runtime 值不包含交易池；同账户一旦有
Pending/InBlock，持久历史 single-flight 会在新构造前失败，防止本地复用 nonce。
`transfer_with_remark` 固定 pallet `4` / call `0`、正分金额、最多 99 UTF-8 字节
remark、immortal era 与 tip `0`；metadata 动态编码必须与固定 call bytes 相等。签名前复核
source AccountId 与金库秘密公钥，签后立即验签。Rust 钱包不公开可拆分的 signed build；唯一
`transfer_with_remark` 入口在内部把 source/destination/amount/remark/nonce 与完整 extrinsic
hash 持久化为 pending，确认 CAS 成功后才广播。纯链客户端的 raw pre-signed submit 只用于
无钱包组合；一旦注入任一钱包交易组件，它也必须命中内部 pending，否则失败关闭。底层
`watch_extrinsic` 合同实际会 submit-and-watch，而不是被动观察既有哈希；因此只要组合任一
钱包交易组件，Engine 也会在触达 provider 前禁止 raw submit-and-watch。

高层 `citizensdk_transfer_with_remark` 的完整 terminal future 在独立四线程长观察池运行，
不会占用 lifecycle/read/state 所用的短操作池。宿主取消会得到 `CANCELLED`；provider 断线、
dropped、retracted、timeout 或取消只结束本次观察，不删除 durable Pending/InBlock 门。
finalized 返回仍必须经过 canonical body、准确块 metadata 与同 index `System.Events` 核验。

Rust Engine 现在把上述规则固化为准确 `VerifiedBlockRef` 的 runtime context 和交易证据核验：
它对完整 signed extrinsic 计算哈希、在准确块体定位 index，再只接受同块 metadata 解出的
同 index System 终态。宿主传入的 finality 位不是证明；Engine 先调用 provider
`resolve_finalized_block(hash, height)`，smoldot 从准确 verified finalized 锚沿 exact parent
hash 验证到目标高度；best/recent cache 或 peer 高度映射都不能替代这条证明。每批最多 120 块，
独立有界 proof-derived cache 只用于减少重复回溯。这样安全支持重启补扫并关闭重组 TOCTOU。
历史终态
只接收核验器产生的私有令牌，令牌不可分离地绑定 txHash 与 Success/Failed，且必须精确匹配
唯一 pending，不能把 A 交易结论写给 B。finalized 流水拒绝自转，对同一 extrinsic/account/
amount identity 的业务事件与 `Balances` 事件严格一对一配对；已核验本地 pending 认领发送方
outgoing、保留接收方 incoming，并在同一原始块重放时保持终态和 pending 消费幂等。它还对
导入的轻节点状态执行启动前、链/协议/genesis/格式/finality、
最大 256 KiB 和不倒退门禁。finalized 事件还绑定生产 metadata 的绝对 AccountId32/u128/
BoundedVec<u8> 类型指纹；call/event 同步漂移也必须在读取值前失败。Runtime 备注按最多 99 个
原始 bytes 保存，并以标准 UTF-8 lossy/U+FFFD 显示，不能把非法 bytes 与真实 `?` 混同。
engine 使用官方 `subxt-core = 0.43.0` 做 metadata/events 解码，
不增加第二轻节点。真实 `smoldot/provider` 已实现 `VerifiedChainClient`；它内部仅允许源码
固定的准确块读取、runtime、提交/观察和状态方法，产品 ABI 不接受任意 RPC 方法名。Provider
提交后立即独立核对完整 extrinsic Blake2-256；节点哈希不一致直接失败关闭。

`citizensdk_sign_wallet_payload` 是提供给受信任宿主的产品无关本地账户签名能力，可用于 TUYU
等明确业务协议；它返回签名，因此同进程宿主技术上也能把签名用于 SDK 高层交易路径之外。
pending-before-broadcast 保证只覆盖 SDK 自己的高层钱包交易入口，不能被描述为对所有宿主签名
用途的强制约束。语言绑定必须明确这条信任边界，不能把通用载荷签名伪装成只能签业务
challenge 的受限密码学原语。

导入还会合并本 Engine provisional anchor 与 revisioned `ChainDatabaseStore` 的持久化 finalized
锚，拒绝高度回退及同高度异哈希，并以 CAS 保存 exact 导入状态；写后抛错只在回读事实完全
相同时收敛为成功。跨 Engine 或进程防回退仅在 store adapter 提供共享、耐久、强原子 CAS
时成立；旧 `citizensdk_create` 的进程内 chain session store 和 legacy Dart Preferences store
都不因此获得跨进程保证。Android 与共享 Darwin 的 `citizensdk_create_with_host` adapter 负责
满足这些合同；Apple 以分离的 typed public/secure SQLite 落实相同 store 语义。导入数据库导致
启动失败时当前
Provider/Engine 组合进入
不可复用 `StartFailed`；只有销毁该 handle 并创建未导入的新实例才能从随包 #0 回退，禁止在
已经发生副作用的实例上重试或伪报恢复成功。

host 构造的 start 会在 provider start 前自动恢复上述状态；export 与 graceful stop 只在完整
`revision + state` 与预期候选一致时提交，不能把“同 state、不同 revision”的竞争写误判为本次
成功。stop 的 checkpoint 失败必须发生在退订和 provider 停止之前。destroy 为避免主线程等待
任意异步平台回调而不做 checkpoint，宿主必须显式成功 stop；最坏只丢失可重新同步的近期公开
轻节点缓存，不影响钱包秘密或链上事实。host start/stop/import 的独占 admission 还保证从
checkpoint 到 provider/Engine 生命周期提交之间没有另一项链、钱包或控制请求穿插；旧 session
构造继续使用既有共享 admission。

产品 ABI 使用单调非零实例/result handle、Rust-owned 结果和显式一次释放，销毁在请求或结果
未收口时返回 `BUSY`。回调只在每实例独立线程执行；从自身回调销毁或同步退订 capability 会在
任何生命周期/monitor 变更前返回 `BUSY`。事件与请求队列均有界，watch 背压使用稳定
`QUEUE_FULL`，不能无界占用内存。host completion 被 claim 后仍计为 outstanding，直到 SDK
校验、复制与投递结束；其后的无状态 callback 尾部不访问实例，避免 destroy 在敏感窗口释放
实例状态。所有输出先支持 `NULL + 0` 长度查询，再复制到宿主缓冲区。
每个非空 completion 必须在读取或 claim pending registry 前先核对 callback token 与
`result.host_operation_id` 完全相等。交叉 identity pair 被忽略，不能取消、完成、消费或观察任一
真实 operation；空 result 没有第二身份，仍以 integrity 失败终止 token 所属 operation。只有身份
匹配的非空 completion 才能进入 Pending→Completing。

公民链账户签名、TUYU challenge 签名和 TuyuBooking 员工登录是不同业务权限。它们可以在
明确设计下使用同一用户 sr25519 公钥，但不得合并账户、授权或审计记录。

## 原生产品边界

全节点 `author` 出块代码、identity keystore 和 seed phrase 私钥入口不进入 CitizenSDK。
保留的 `identity::ss58` 只做公开地址编解码。libp2p Noise 密钥按连接随机生成、只用于传输
握手并在内存清理，不是钱包或管理员密钥。

根产品 C ABI/头文件不导出低层 signer、private-key 或 child-secret 原语；高层
`citizensdk_sign_wallet_payload` 只返回签名结果。Android AAR/Flutter 双投影禁止
`libsmoldot`，只带产品 Core 与薄 JNI bridge；Apple XCFramework 只导出根产品头的 70 个
`citizensdk_*` 符号，并拒绝 `smoldot_*`、`citizen_sr25519_*` 与 `account_crypto_*`。legacy
smoldot/signer 符号只允许存在于源码树外的 ARM64 差分测试宿主库，绝不进入候选。

聊天、广场、OpenMLS、TUYU 消息协议与产品数据库均被排除。测试夹具只能使用公开向量和
非生产数据，不得加入真实助记词、设备密钥或用户数据。

## 构建与分发

- SDK 源码树不得接收构建缓存、原生库或 Release 产物。
- 原生构建和 Release 在首次建目录前校验绝对规范路径及每一级既存祖先，拒绝路径穿越、
  符号链接祖先和非目录祖先。
- CI/Release 使用锁文件与准确提交；Release 必须绑定同产品、同目标的成功 CI。
- 候选只允许标准 macOS framework 内精确五个相对符号链接：`Versions/Current -> A`，以及
  根 `CitizenSDK`、`Headers`、`Modules`、`Resources` 指向 `Versions/Current/...`；其他任何
  符号链接、路径穿越、未登记文件、常见密钥文件及 PEM 私钥材料均拒绝。
- `SHA256SUMS` 是 tgz 外部资产，精确覆盖 manifest 与 tgz；校验器重建规范归档字节。
- Release 候选合同包含 Android `arm64-v8a`、iOS 设备 ARM64、`iOS-Simulator` ARM64 与
  macOS（仅支持 ARM64 架构），四者使用同一产品 ABI、Core commit 和 SDK version。
- GitHub Release 是正式分发终态，但不等于真机硬件金库安全验收；对应结果必须单独留档。

本轮 Apple 本机已编译 iOS 设备与 `iOS-Simulator` 两组测试 bundle，但因无 Simulator
runtime 没有声称 iOS XCTest 已运行。macOS Core 50 项与 Flutter adapter 22 项 XCTest
0 失败，1 项需要真机硬件的用例跳过；normal/supervisor smoke 通过。本机无真实
Apple 移动设备，所以 Secure Enclave、生物认证和 device-only Keychain 仍需真机验收。
当前 TataConsole Flow 尚未接入本闭集；本步未运行远程 CI、正式 Release、Hosted 上传或 Git。

iOS 与 `iOS-Simulator` 的浅层 framework install ID 为
`@rpath/CitizenSDK.framework/CitizenSDK`；macOS 标准 `Versions/A` framework install ID 为
`@rpath/CitizenSDK.framework/Versions/A/CitizenSDK`。真实 Flutter consumer 已完成 Android
release ARM64 APK、iOS device Release no-codesign、`iOS-Simulator` generic ARM64 编译和
macOS Release 构建，但没有移动真机或 Simulator runtime 声明。Flutter SPM 识别警告与
Android built-in Kotlin 迁移提示延后到第 9 步处理。

同一本机闭集已验证 Android AAR、Hosted 17 文件分析 0 问题、完整 Dart 316/316
（`--timeout=2m`）、根 Rust 285/285 与 compile-fail 文档测试 1/1、Clippy/格式，以及
Android 原生 Kotlin/Java 单元测试 Gradle 17 个 task；这些结果不扩大上述真机安全验收边界。
