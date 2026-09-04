# Windows 公共头边界

`citizen_sdk/citizensdk_host.h` 是 13 项薄 Host C ABI，`citizen_sdk.hpp` 是不导出 STL ABI
的 header-only C++ 所有权包装。根 `include/citizensdk.h` 的 70 项 Core ABI 保持不变。
七个 Host 头不暴露 CNG、SQLite、Win32 内部窗口对象或密钥材料。

配置的 `hwnd` 仅借用当前进程/UI 线程父窗口；nullptr 明确表示无父窗口，不能作为已销毁
父窗口的回退。UTF-8 路径经严格转换进入 Windows 文件系统，不能隐式使用当前 ANSI 代码页。
公开钱包流程只返回完成、取消或错误状态；助记词、设备口令和 DEK 均不进入业务回调。

Host 拥有 Core handle。应用可借用它调用根 ABI，但不能替换 Host 的 Core event callback，
不能直接 `citizensdk_destroy`，事件结果也必须遵守单一释放者规则。

第 8.2 步新增 `citizen_sdk_plugin.h`，只声明 Flutter 官方注册 C 入口；源码公共头共八个，
秘密扫描仍覆盖全部。原生安装显式排除该注册头，纯 C/C++ 消费者仍只依赖七个 Host 头，
不因此要求 Flutter。注册不接收应用身份、路径、句柄业务参数或任何秘密。
