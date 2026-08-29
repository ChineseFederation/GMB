# CitizenSDK C headers

`smoldot.h` 描述从 CitizenApp 稳定实现继承的轻节点 C ABI；`citizensdk.h` 在其上补充
CitizenSDK ABI 版本和 sr25519 公共入口。调用方只需要包含 `citizensdk.h`。

当前 `smoldot.h` 是净化后的来源基线。轻节点主体迁入并获准编译后，构建流程必须重新用
`cbindgen` 生成它，并把生成结果和当前契约对拍；若真实 Rust 导出面不同，必须修正源码或
头文件，不能静默发布不一致的 ABI。
