# CitizenSDK 原生产物打包

## 源码树规则

`citizensdk` 源码树不保存 `.so`、`.a`、`jniLibs`、`Frameworks`、`target` 或发布包。
Rust 轻节点与 signer 的构建产物由公民控制台生成到中央工作目录，再在构建时注入。这样
CI、Release 和本机开发使用同一来源，同时不把机器相关二进制混入源码。

统一构建入口是 `scripts/build-native.sh`。它强制调用方同时提供：

```text
CITIZENSDK_WORK_DIR=<Cargo 工作目录>
CITIZENSDK_NATIVE_OUTPUT_DIR=<原生产物目录>
```

两个目录解析后的真实路径都不得位于 `citizensdk` 源码树。Console 本机调用时，它们只能
设置在 `/Users/rhett/Only/console/target/citizensdk` 内；GitHub CI/Release 固定使用
`$RUNNER_TEMP/citizensdk`。脚本使用 `cargo build --locked`，拒绝覆盖已有目标文件，并从
实际二进制核验 `smoldot_*` 与四个 `citizen_sr25519_*` 符号；聊天和产品账户密码学符号
不得混入 SDK 原生核心。

## Android 注入

控制台设置：

```text
CONSOLE_NATIVE_ANDROID_DIR=<包含 arm64-v8a/libsmoldot.so 的中央目录>
```

`android/build.gradle` 将该目录设为插件 `main` 的唯一额外 `jniLibs` 来源。SDK 当前只允许
`arm64-v8a`；构建系统同时排除 armeabi、x86 和 x86_64。没有该变量时源码仍可被工具读取，
但最终接入构建不得发布缺少 `libsmoldot.so` 的产物。

## iOS 注入

控制台设置：

```text
CONSOLE_NATIVE_IOS_DIR=<包含 libsmoldot.a 与 exported_symbols.txt 的中央目录>
```

`ios/citizen_sdk.podspec` 在 CocoaPods 解析时检查两个文件。静态库用 `-force_load` 链入；
`exported_symbols.txt` 必须从实际产物抽取，podspec 为每个符号生成 `-Wl,-u,<symbol>`，防止
Release 的 `dead_strip` 删除 Dart `DynamicLibrary.process()` 需要的 FFI 符号。符号清单
为空或文件缺失时构建立即失败，禁止退回手写符号表。

## CI 与 Release 候选

GMB 唯一顶层 Workflow 路由以下分组流水线：

- `公民SDK · CI · SDK`：使用任务创建时 GitHub 固定的 `github.sha`，不接收正式版本；
  运行锁定依赖检查、安全审计、源码测试和真实原生构建后生成 CI 候选。
- `公民SDK · Release · SDK`：要求 `source_sha`、成功 `ci_run_id`、`software_version` 与
  `citizensdk-v<version>`，只重建该准确提交并用统一 GitHub Release 事务固化。

`scripts/release.mjs` 从只读源码和外部原生产物目录组装确定性候选。下载归档内默认放置：

```text
android/src/main/jniLibs/arm64-v8a/libsmoldot.so
ios/libsmoldot.a
ios/exported_symbols.txt
citizensdk-release.json
SHA256SUMS
```

因此正式下载包无需把二进制回写仓库源码，也能让 Android 默认 `jniLibs` 与 iOS podspec
找到各自原生库。正式 GitHub Release 只上传 `citizensdk.tgz`、
`citizensdk-release.json` 和 `SHA256SUMS`；清单固定产品 id、Dart 包名、软件版本、准确
Git SHA、Android/iOS ABI 与全部文件 SHA-256。

## 发布边界

当前步骤只建立 GMB 统一 CI/Release 源码，没有实际运行构建、测试、CI 或 Release，也没有
创建任何发布包。公民网下载指针和 Console 的编译、CI、Release、发布按钮将在后续已确认
步骤中接入；不得由本流程直接更新网站或伪造发布成功状态。
