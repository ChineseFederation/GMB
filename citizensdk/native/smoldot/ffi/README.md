# smoldot FFI

本 crate 保留 CitizenApp 稳定实现的 `smoldot_*` 句柄、回调和异步 RPC 语义，并把
CitizenSDK 内部唯一 signer 的四个 `citizen_sr25519_*` 符号链接进同一原生库。

## 当前状态

`Cargo.toml` 中的 `../pow/light-base` 及其相邻 `../lib` 依赖已经迁入。该 crate 保持
独立 workspace 边界，不加入 GMB 根 workspace，并由本目录的 `Cargo.lock` 固定依赖。
当前仍未运行构建或测试。

## 禁止范围

- 不得加入聊天或广场功能。
- 不得依赖 OpenMLS、`account-crypto` 或其他产品目录。
- 不得改变现有 `smoldot_*` 轻节点函数的句柄、回调、所有权和错误契约。
- 公共头文件必须由真实 Rust 导出面生成并通过符号契约检查，禁止手写漂移。
