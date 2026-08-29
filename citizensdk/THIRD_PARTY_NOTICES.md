# Third-party notices

CitizenSDK 是由不同许可证覆盖的组合产品。任何公开下载、Release 或再分发都必须同时
保留对应源码、许可证文本和来源说明。

## 当前导入内容

`native/signer` 来源于 GMB 的 `shared/citizen-signer`，其 Rust 清单继承 GMB workspace
的 MIT 许可证。根目录的 `LICENSE-MIT` 保存该许可证原文。

该模块依赖官方生态实现 `schnorrkel` 和 `zeroize`。具体解析版本以未来受控生成并纳入
发布留档的 `Cargo.lock` 和 SBOM 为准；本阶段没有运行依赖解析或生成锁文件。

`native/smoldot/ffi` 的初始边界来自 CitizenApp 内收编的 smoldot FFI。SDK 副本已经排除
OpenMLS、AES-GCM 聊天状态、Base64 聊天信封和 `account-crypto`，保留的 Rust 依赖将在
轻节点主体迁入后统一解析和留档。

`native/smoldot/pow/light-base` 已作为逐字节来源快照迁入。该层保留其文件头声明的
GPL-3.0-or-later WITH Classpath-exception-2.0；smoldot Dart/FFI 侧声明的 Apache 2.0
许可证原文保存在 `native/smoldot/LICENSE-APACHE-2.0`。

## 轻节点许可证

公民链 smoldot PoW 快照来源目录使用 GNU GPL v3。根目录 `LICENSE-GPL-3.0` 与
`native/smoldot/LICENSE` 均逐字节保存该来源许可证，`native/smoldot/UPSTREAM.md`
保存上游和分叉说明。迁入轻节点主体时还必须记录精确文件来源与修改清单。
