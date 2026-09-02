# legacy smoldot FFI

本 crate 保留 CitizenApp 稳定实现的 `smoldot_*` 句柄、回调、所有权和异步 RPC 语义，并
把 CitizenSDK 内部唯一 signer 的四个 `citizen_sr25519_*` 入口链接到同一原生库。它只服务
归档 Dart/smoldot ARM64 差分测试，不是根 Dart、Android 或 Apple 当前运行边界，也不是新的
产品级 `citizensdk_*` ABI；该 legacy 库绝不进入候选。

来源的 `rust-toolchain.toml`、错误类型与 FFI 类型逐字节保留；Cargo 清单、build script 和
模块入口只删除聊天/OpenMLS/账户数据加密依赖与导出，并把路径依赖指向本 SDK 的
`../pow/light-base` 和 `../../signer`。

本 crate 维持独立 workspace。锁文件从 CitizenApp 已验证锁机械裁掉已排除产品闭包；保留
registry 包的 name/version/checksum 必须与来源完全一致。`../provider` 另行把相同轻节点
实现收口成 `VerifiedChainClient`，不改写本 crate。legacy 头文件和测试守卫会核对动态库
名、全部现有符号、回调、资源边界与禁止能力；实际通过状态以对应提交的执行报告为准。
