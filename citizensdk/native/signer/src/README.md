# sr25519 实现边界

`sr25519.rs` 是 CitizenSDK 唯一算法实现，集中保存硬派生、public key、`substrate` context
签名、验签、panic 收口与零化语义。`lib.rs` 只保留四个 legacy 原语的 C FFI 包装，
`chain_signer.rs` 只实现类型化 `ChainSigner`；两者都调用 `sr25519.rs`，禁止复制第二套算法。

最初行为来自 GMB 稳定 `shared/citizen-signer`，但第 4.1 步重构后的 `lib.rs` 不再是该来源的
逐字节副本。CitizenSDK 不在运行时回指 shared；来源语义由 Substrate 向量、legacy parity、
FFI 合同和类型化 signer 测试共同守住。任何行为修改都必须同时审查来源策略、向量、错误
契约、秘密所有权与零化路径。

`lib.rs` 的四个 `citizen_sr25519_*` 包装不会进入 Android 或 Apple 产品候选；它们只会进入
源码树外的 ARM64 legacy 差分测试宿主库。它们不是产品 `citizensdk_*` C ABI，产品符号验收
必须在每个正式平台拒绝它们。
