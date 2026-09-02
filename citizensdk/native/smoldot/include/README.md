# legacy smoldot C header

`smoldot.h` 只描述归档 Dart/smoldot macOS `arm64` 差分测试使用的 legacy `libsmoldot` C ABI。兼容库继续
包含现有 `smoldot_*` 和 signer 宏生成的 `citizen_sr25519_*` 符号，但本目录不再冒充产品级
CitizenSDK 公共头；Android 与 Apple 产品候选均不包含这些符号。

正式产品 `citizensdk_*` API 的唯一头文件位于仓库根 `include/`；它不包含本文件，也不
公开任意 JSON-RPC 或裸秘密入口。legacy 宿主差分库只能在源码树外由真实 Rust 导出重新生成，
并对拍 `smoldot.h` 与动态符号；它不进入正式平台构建或候选。
