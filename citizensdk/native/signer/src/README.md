# Source baseline note

`lib.rs` 是本阶段从 GMB 稳定 signer 导入的逐字节基线。文件中的“共享 crate”“两端”等
表述记录了来源版本当时的调用关系，不表示 CitizenSDK 在 Release 时依赖原目录。

在轻节点 FFI 接入步骤获准前，本文件旁不增加第二套密码学实现，也不修改 `lib.rs` 的行为
或注释。后续若需要更新注释，必须先保留本页记录的来源哈希并确认行为向量不变。
