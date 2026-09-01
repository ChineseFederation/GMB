# Third-party notices

CitizenSDK 组合了不同许可证覆盖的源码。根 `LICENSE` 是组件许可证入口；任何分发都必须
保留本文件及对应许可证原文，不能只分发原生二进制。GitHub Release 审计包另外保留完整源码、
来源说明和锁文件；Hosted Package 只过滤开发输入，但继续携带本文件、根许可证入口、MIT、
GPL with Classpath Exception 原文，以及根许可证入口中完整重现的 Apache-2.0 原文。

## sr25519 signer

`native/signer/Cargo.toml` 与 `native/signer/src/lib.rs` 的初始基线逐字节来自
`shared/citizen-signer`，许可证为 MIT；原文保存于根目录 `LICENSE-MIT`。该 crate 使用
`schnorrkel`、`zeroize` 等官方生态依赖，解析闭包由根 `Cargo.lock` 固定。

## CitizenSDK Rust Core

`native/contracts` 与 `native/engine` 是 CitizenSDK 自有实现，继承根 `Cargo.toml` workspace
声明的 MIT 许可证；原文保存于 `LICENSE-MIT`。contracts 使用 `zeroize 1.9.0` 保护短生命周期秘密缓冲区，并使用
`futures-core 0.3.31` 表达不绑定具体 executor 的对象安全异步合同。

engine 精确依赖 crates.io 官方 `subxt-core 0.43.0`；该依赖声明为
`Apache-2.0 OR GPL-3.0`。CitizenSDK 只使用它解析 SCALE metadata、`System.Events` 和计算
Substrate extrinsic 哈希，不把它当作网络客户端，也不由此引入远程 RPC 或第二份轻节点实现。
准确依赖闭包和 registry checksum 由根 `Cargo.lock` 固定。Rust Core 的来源闭集独立受
Release 合同保护，不写入只描述 CitizenApp smoldot 收编来源的
`native/smoldot/SOURCE_SHA256.json`。

## smoldot Dart 与 FFI

CitizenApp 已验证的 Dart smoldot 包已作为 CitizenSDK 内部实现并入 `lib/src/smoldot`，原六个
测试和两个公开链夹具并入 `test/smoldot`。历史包清单、锁文件、许可证、说明和示例保存于
`docs/smoldot-dart` 供审计；它们不再构成第二个 Dart 包或 `path` 依赖。迁移闭集继续由发布
合同逐文件校验。

`native/smoldot/ffi` 继承 CitizenApp 的 Apache-2.0 FFI 边界，保留轻节点和 signer C ABI，
排除只供聊天使用的 OpenMLS/聊天信封与账户数据加密代码。Apache 2.0 许可证原文保存于
`native/smoldot/LICENSE-APACHE-2.0`；Hosted 包排除 `native` 源码目录，但在根 `LICENSE`
逐字重现同一原文。FFI `Cargo.lock` 从 CitizenApp 已验证锁机械裁掉已排除产品闭包，并保持
全部保留 registry 包的 name/version/checksum。

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
