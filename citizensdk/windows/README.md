# CitizenSDK Windows 原生 Host

本目录是同一个 CitizenSDK 的 Windows 系统适配，不是另一个钱包或轻节点实现。
最低 Windows 11，机器目标 `x86_64-pc-windows-msvc`；公开平台名只有 **Windows**。
本步新增源码与原生构建合同，尚未在 Windows 实际编译、运行或分发。macOS 验收不能
替代 Windows CTest、Win32 交互和实体 TPM 验收。

## 依赖与入口

`CitizenSDK::Host → CitizenSDK::Core → native/ffi → Engine/Contracts/Providers`。
原生安装包含 `citizensdk_host.dll`、`citizensdk.dll`、对应 MSVC import libraries、七个
Host 公开头、两个 Core 公开头、可重定位 CMake 配置与同一 CitizenChain 资产。
原生入口不依赖 Flutter，不复制 signer、交易或 smoldot。第 8.4 步接入默认 Dart 注册和
同版候选运行投影，Flutter 运行包仅保留 21 项安装件与 12 项插件输入，不携带 Host 私有
源码或测试。源码注册不是已经在 Hosted 发布；Windows 实际平台运行仍待统一验收。

```cmake
find_package(CitizenSDK 1.0 CONFIG REQUIRED)
target_link_libraries(application PRIVATE CitizenSDK::Host)
```

```cpp
#include <citizen_sdk/citizen_sdk.hpp>

citizen_sdk::Config config;
config.storage_root = state_directory;  // 绝对路径，当前用户私有目录。
config.asset_root = asset_directory;    // 安装包 share/citizensdk/citizenchain。
config.application_id = "org.example.application";
config.hwnd = nullptr;                  // 关闭钱包时必须为空，不创建钱包窗口。
config.enable_wallet = false;           // 只读链可不创建任何钱包 UI。
citizen_sdk::Host host(config);
host.open();                            // 返回的 native_handle 由 Host 唯一持有。
// Core 尚未 start；运行后必须先异步 stop 完成 checkpoint，再关闭。
host.close();
```

钱包模式要求构造所在 UI 线程持续处理 Win32 消息。窗口不能由其它进程或线程冒充；
父窗口销毁会取消正在进行的原生操作，不转成另一个 rootless 窗口继续输入。
关闭返回 BUSY 时保留整个资源图；C++ 析构可转交 supervisor，不能直接销毁借用的 Core。

## 安全与构建

仅 Microsoft Platform Crypto Provider + TPM 2.0，SDK 独立设备金库口令授权 KEK 使用；
没有 Software KSP、DPAPI、Windows Hello 或纯软件降级。TPM RSA 只封装/解封随机 DEK，
sr25519 仍由同一 Rust signer 实现。设备解锁口令不是业务账户密码，不改变链签名 context。

唯一入口是根 `scripts/build-native.sh Windows`。预先提供 MSVC、Rust 目标、CMake、Node、
已固定 SQLite MSVC 静态归档与头；不由脚本安装工具或联网补依赖。工作区和安装前缀只在
TataConsole/runner checkout 外中央目录，源码目录禁止任何编译缓存、DLL、LIB 或日志。
具体环境、未实测门禁和秘密边界见 [Windows 技术说明](../docs/WINDOWS_PLATFORM.md)。

原生构建先保留原有 14 项合同测试，再安装到本次工作目录，核对精确 21 文件、安装清单、
同轮构建字节、版本和完整 PE 导出。独立 C11/C++17 消费者只查准确安装前缀，不包含 Host
私有头或重新编译核心；检查实际加载 DLL，执行启停、异步完成、结果释放和关闭重试。
两个消费者均关闭钱包且不提供 HWND，不触发 TPM 或钱包 UI。随后完成六项 adapter CTest
和真实 Flutter Release 消费者，全部成功后才同卷导出安装目录；
输出已存在或跨卷则失败，不覆盖既有成功结果。Windows 实际执行仍须统一平台验收。

## Flutter 适配源码

`citizen_sdk_plugin` 通过官方 `flutter`、`flutter_wrapper_plugin` 连接包内同版
`CitizenSDK::Host/Core`，不重新编译核心。使用官方 StandardMethodCodec 和已有双 channel、
22 方法；钱包交互只接本目录现有 Win32 安全流程。

Windows 宿主须在顶层 CMake 引入 generated_plugins.cmake 之前声明一次：

```cmake
set(CITIZENSDK_APPLICATION_ID "org.example.application")
```

这是 3..253 字节小写反向域形式的数据命名空间，不是 Windows 身份认证或业务账户。
必须由宿主固定且升级后不变，缺失/非法立即拒绝，不从展示名、可执行文件、目录或
AppUserModelID 推导。它不进入 Dart tuple；系统 LocalAppData、标准 Flutter 资产与 HWND
由原生环境读取，Host 继续执行已有安全检查。

第 8.4 步同时开启 pubspec 与 `CitizenSdk.open()` 的 Windows 默认入口；缺少同版插件
仍失败关闭。这项原生身份声明意味着 Windows 不是完全零配置，MSVC 运行时也由宿主
部署环境提供。真实消费者只在一次性 GitHub 用户环境运行，不注入私有平台或路径；
应用只使用预检为空的测试命名空间，不创建钱包或触发 TPM 授权。
