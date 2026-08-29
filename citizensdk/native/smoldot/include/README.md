# CitizenSDK C headers

`smoldot.h` 描述轻节点 C ABI；`citizensdk.h` 在其上补充 CitizenSDK ABI 版本和 sr25519
入口。调用方只需包含 `citizensdk.h`。

构建在源码树外用真实 Rust 导出重新生成并对拍头文件，同时从真实库提取导出符号。Rust、
头文件或符号清单任一漂移都必须失败，禁止靠手写声明掩盖 ABI 不一致。
