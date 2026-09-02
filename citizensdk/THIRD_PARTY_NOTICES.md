# Third-party notices

CitizenSDK 组合了不同许可证覆盖的源码。根 `LICENSE` 是组件许可证入口；任何分发都必须
保留本文件及对应许可证原文，不能只分发原生二进制。GitHub Release 审计包另外保留完整源码、
来源说明和锁文件；Hosted Package 只过滤开发输入，但继续携带本文件、根许可证入口、MIT、
GPL with Classpath Exception 原文，以及根许可证入口中完整重现的 Apache-2.0 原文。

## sr25519 signer

`native/signer` 的最初密码学语义来自 `shared/citizen-signer`，许可证为 MIT；原文保存于根
目录 `LICENSE-MIT`。第 4.1 步已把算法集中到 `src/sr25519.rs`，由 `src/lib.rs` 的 legacy FFI
与 `src/chain_signer.rs` 的类型化合同共同调用；当前文件布局不再宣称与 shared 的 `lib.rs`
逐字节一致。该 crate 使用 `schnorrkel`、`zeroize` 等官方生态依赖，解析闭包由根
`Cargo.lock` 固定。

## CitizenSDK Rust Core

`native/contracts`、`native/engine`、`native/ffi` 与 `native/smoldot/provider` 是 CitizenSDK
自有实现，继承根 `Cargo.toml` workspace 声明的 MIT 许可证；自有代码的许可证原文保存于
`LICENSE-MIT`。contracts 使用 `zeroize 1.9.0` 保护短生命周期秘密缓冲区，并使用
`futures-core 0.3.34` 表达不绑定具体 executor 的对象安全异步合同。它还直接使用：

- `bs58 0.5.1`（crate manifest：`MIT/Apache-2.0`）编码规范 SS58；
- `blake2 0.10.6`（crate manifest：`MIT OR Apache-2.0`）计算 `SS58PRE` checksum。

engine 精确依赖 crates.io 官方 `subxt-core 0.43.0`；该依赖声明为
`Apache-2.0 OR GPL-3.0`。CitizenSDK 只使用它解析 SCALE metadata、`System.Events`、构造并
编码已签名 extrinsic V4，以及计算 Substrate extrinsic 哈希，不把它当作网络客户端，也不
由此引入远程 RPC 或第二份轻节点实现。
准确依赖闭包和 registry checksum 由根 `Cargo.lock` 固定。Rust Core/产品 FFI 的来源闭集
独立受 Release 合同保护；`native/smoldot/SOURCE_SHA256.json` 只分类收编的 smoldot 来源、
必要适配和与其共同演进的 SDK-only Provider，不承担 Core 清单职责。
`subxt-core 0.43.0` 的解析闭包另包含 `base58 0.2.0`（crate manifest：MIT）。这些第三方项目
的许可证与 copyright notice 以各 crate 自身分发内容为准；根 `LICENSE-MIT` 只覆盖
ChineseFederation/CitizenSDK 自有代码，不能冒充第三方许可证原文。

Rust 钱包派生与短生命周期秘密处理还直接使用 `bip39 2.2.2`、`getrandom 0.2.17`、
`hmac 0.12.1`、`pbkdf2 0.12.2`、`sha2 0.10.9`、`unicode-normalization 0.1.25`、
`unicode-segmentation 1.13.3` 与 `zeroize 1.9.0`；准确许可证声明、copyright notice、
registry checksum 和传递闭包以各 crate 分发内容及根 `Cargo.lock` 为准。`bip39` 的
`zeroize` feature 是本产品处理 mnemonic 的必选依赖语义，不是可省略的构建优化。

产品 FFI 使用 `sha2 0.10.9` 与 `blake2 0.10.6` 复核随包资产；平台金库适配另外使用
RustCrypto 官方 `aes-gcm 0.10.3`、`aes 0.8.4` 与 `ghash 0.5.1` 在 Rust 受控缓冲区内
认证加密账户 child mini-secret；三个 crate 均启用其可用的 `zeroize` feature，以清理
AES key schedule 和认证构造期间的临时 key material，
使用 `getrandom 0.2.17` 生成每份密文独立的 256 位 DEK 与 nonce，并以 `zeroize 1.9.0`
清理 DEK、助记词和其它短生命周期秘密。系统金库只封装随机 DEK，不直接接收
child mini-secret 或 sr25519 私钥。准确许可证声明、copyright notice、registry checksum
与传递闭包以各 crate 分发内容及根 `Cargo.lock` 为准。

smoldot provider 使用 `tokio 1.53.1` 驱动轻节点异步工作，并用 `blake2-rfc 0.2.18` 独立核对完整 extrinsic hash。
Provider 对 `smoldot-light` 的路径依赖继续受下述 smoldot PoW 许可证边界覆盖。根
`Cargo.lock` 固定这些准确版本与 registry checksum，且 Release 另外要求 Provider 的递归
smoldot registry 闭包与已验证 PoW 锁逐项一致。

## smoldot Dart 与 FFI

CitizenApp 已验证的 Dart smoldot 包已作为 CitizenSDK 内部实现并入 `lib/src/smoldot`，原六个
测试和两个公开链夹具并入 `test/smoldot`。历史包清单、锁文件、许可证、说明和示例保存于
`docs/smoldot-dart` 供审计；它们不再构成第二个 Dart 包或 `path` 依赖。迁移闭集继续由发布
合同逐文件校验。

`native/smoldot/ffi` 继承 CitizenApp 的 Apache-2.0 legacy FFI 边界，保留当前 Dart 所需的
轻节点和 signer C ABI，
排除只供聊天使用的 OpenMLS/聊天信封与账户数据加密代码。Apache 2.0 许可证原文保存于
`native/smoldot/LICENSE-APACHE-2.0`；Hosted 包排除 `native` 源码目录，但在根 `LICENSE`
逐字重现同一原文。FFI `Cargo.lock` 从 CitizenApp 已验证锁机械裁掉已排除产品闭包，并保持
全部保留 registry 包的 name/version/checksum。

新的产品级公共头文件只位于根 `include`，只声明 `citizensdk_*`，不把 legacy
`smoldot_*`、`citizen_sr25519_*` 或底层依赖接口提升为第三方产品 ABI。

## smoldot PoW 轻节点

`native/smoldot/pow/lib` 与 `native/smoldot/pow/light-base` 来源于 CitizenApp 当前使用的
smoldot PoW + GRANDPA 快照。该范围保留上游声明的
`GPL-3.0-or-later WITH Classpath-exception-2.0`；许可证原文保存于根目录
`LICENSE-GPL-3.0` 与 `native/smoldot/LICENSE`，上游提交和本地 PoW 改动记录保存于
`native/smoldot/UPSTREAM.md`。

轻客户端产品明确不包含全节点 `author` 出块模块，也不包含全节点 identity keystore 与
seed phrase 私钥入口。其余共享生产源码、夹具和上游内联测试按来源复制；仅 workspace、
crate 入口和 identity 模块做最小产品边界适配。PoW 依赖闭包由与 CitizenApp 稳定来源
中保留 registry 包 name/version/checksum 一致、但已机械裁掉全节点/WASM 不可达闭包的
`native/smoldot/pow/Cargo.lock` 固定。

完整来源分类、排除项和同步策略见 `docs/SOURCE_PROVENANCE.md`。锁文件是依赖输入，不是
构建产物；实际许可证义务仍以每个依赖包自身许可证为准。
