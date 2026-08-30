# CitizenSDK 原生产物与候选打包

## 源码树规则

`/Users/rhett/GMB/citizensdk` 只保存源码、固定链资产、manifest、锁文件、文档和测试源码，
不得保存 `.so`、`.a`、`target`、`build`、`.dart_tool`、Gradle/CocoaPods 状态或 Release 包。

统一原生入口 `scripts/build-native.sh` 要求调用方提供源码树外的：

```text
CITIZENSDK_WORK_DIR=<Cargo 工作目录>
CITIZENSDK_NATIVE_OUTPUT_DIR=<原生产物目录>
```

脚本在首次 `mkdir` 前要求两个目录都是绝对规范路径，拒绝 `.`、`..`、重复或末尾分隔符，
并逐级拒绝既存符号链接及非目录祖先。发布器对 candidate、archive 和 verify 路径执行同一
预检，不能借中间符号链接或路径穿越把生成状态写进 SDK 源码树或 ProgramConsole 中央目录之外。

脚本使用 `cargo build --locked`，核对 `smoldot_*` 与四个 `citizen_sr25519_*` 符号，并拒绝
聊天或产品账户密码学符号进入原生核心。`all` 另外按 Runner 宿主架构生成
`ios-simulator/libsmoldot.a` 和对应符号清单，只用于执行 iOS Swift XCTest；宿主
`libsmoldot.dylib` 固定为 arm64+x86_64，同时适用于原生与 Rosetta `flutter_tester`。发布器不会把
这些测试库复制进正式候选。

Android NDK 版本在 SDK 原生入口中固定为 `28.2.13676358`，与 GMB 官方依赖合同一致。
调用方提供 `ANDROID_NDK_HOME` 时必须精确指向该版本；同时提供 `ANDROID_HOME` 与
`ANDROID_SDK_ROOT` 时两者必须一致。若三个 Android 环境变量均缺失，本机入口只从宿主标准
SDK 目录（macOS 为 `$HOME/Library/Android/sdk`，Linux 为 `$HOME/Android/Sdk`）解析该固定
版本，不扫描或选择“最新”NDK。这样 SDK 本机构建不依赖编程控制台版本，同时仍拒绝版本漂移。

设备与 Simulator 的 iOS 原生构建共用脚本中的唯一 `ios_deployment_target=16.0`，两条
`cargo build` 都显式接收 `IPHONEOS_DEPLOYMENT_TARGET="$ios_deployment_target"`。该环境同时约束
Rust 对象和 Cargo 依赖中由 C 编译器生成的对象，避免它们继承构建机 Xcode 的当前系统版本。
`ios/citizen_sdk.podspec` 同样固定宿主集成最低版本为 iOS 16.0；原生对象、插件与宿主因此保持
同一最低版本合同。macOS `flutter_tester` 宿主测试库不读取该 iOS 环境变量。

## Android 与 iOS 注入

Android 构建读取：

```text
PROGRAM_CONSOLE_NATIVE_ANDROID_DIR=<包含 arm64-v8a/libsmoldot.so 的目录>
```

`android/build.gradle` 只声明 `arm64-v8a`，其它 ABI 不进入正式包。

iOS 构建读取：

```text
PROGRAM_CONSOLE_NATIVE_IOS_DIR=<包含 libsmoldot.a 与 exported_symbols.txt 的目录>
```

podspec 用 `-force_load` 链入静态库，并根据真实产物的 `exported_symbols.txt` 逐符号添加
`-Wl,-u,<symbol>`，防止 Release `dead_strip` 删除 Dart FFI 入口。缺文件、空清单或符号漂移
必须失败关闭。

## 本机 ProgramConsole

所有本机生成状态只允许位于 `/Users/rhett/Only/ProgramConsole/target/citizensdk`。本机构建先读取
GMB 当前提交 SHA，再通过 `git archive <sha> citizensdk` 建立无生成状态的打包快照；构建
快照从该提交快照派生。这样工作区未提交修改不会被错误标注为已提交 HEAD。

成功后中央目录只保留：

- `citizensdk.tgz`
- `citizensdk-release.json`
- `SHA256SUMS`

替换使用带恢复槽的三件套事务；`.work` 和恢复记录在完成或恢复后清理。目录中已经存在的
三件套只证明其生成时的提交，不能证明当前未提交源码已构建或通过。
当前中央目录中唯一已知的两行外层合同之前的历史三件套，以 tgz、manifest、sums 三个固定
SHA-256 同时识别。它只允许作为准确历史前驱被完整备份、原子替换或失败恢复；任何其他
324 行先前清单、部分集合或损坏字节均不在接受范围内并失败关闭。

ProgramConsole 本机构建以 `.work/candidate-transaction.lock` 覆盖初始化、构建、提交和恢复的完整
跨进程事务。锁 owner 先以 noclobber 完整写入 PID 与随机 token，再由同文件系统硬链接原子
声明固定普通文件锁，不存在空 owner 固定态。活动、非法或无法确认死亡的 owner 均失败关闭，
失效锁只有在两种本机进程检查均证明 PID 已死亡后才可原子接管。退出清理只能移除逐字节属于
本进程的锁；恢复槽建立前和最终提交前还会重新检查中央目录闭集。

## CI 与 Release

CitizenSDK 复用 GMB 唯一顶层 Workflow 和现有产品流程：

- CI 对准确 `github.sha` 重新安装锁定依赖、检查发布闭集、执行静态检查与测试、构建原生
  核心，实际运行 Android JUnit、iOS Simulator XCTest、Dart/Flutter 与 Rust 测试，在同一
  注入后候选上执行 Hosted dry-run，并上传 `CitizenSDK-CI` 三件套。
- Release 复核指定 CI 的 workflow、显示标题、产品 `citizensdk`、目标 `sdk`、成功状态和
  准确 `source_sha`，不读取、下载或比较 CI 资产；随后在隔离快照中重新执行依赖检查、测试、
  原生构建、候选生成、反向验证与 Hosted dry-run，并创建正式 GitHub Release。孤立 Tag
  清理、主发布路径和响应中断恢复三处都必须核验版本 Tag 精确锚定该成功 CI 的 `source_sha`。

CI 与 Release 都使用确定性候选算法，但 Release 的成立条件是来源绑定、独立重建与完整
验证，不宣称不同 Runner、不同 run 的压缩包在所有环境下必然逐字节相同。

两条流程的测试命令合同相同：根包把原有 230 项与迁入的 smoldot 51 项合并，并以
`flutter test --timeout=2m` 统一执行；外层两分钟超时必须长于来源测试内部的 30 秒活链订阅
窗口。Android 在临时 Flutter 宿主中执行 Gradle
`:citizen_sdk:testDebugUnitTest`，iOS 启动可用 iPhone Simulator 后执行限定 `RunnerTests` 的
`xcodebuild test`。平台测试必须实际启动测试运行器并取得成功终态，不能用 APK 构建、Pod
链接、test discovery 或报告文件存在来代替。

## 正式候选格式

`scripts/release.mjs` 从只读源码快照和外部原生产物构造唯一规范候选与 gzip/tar。GitHub
归档内包含完整 SDK 源码、测试、文档、锁文件、Android/iOS 原生库与
`citizensdk-release.json`；外层 `SHA256SUMS` 不进入 tgz，避免对 tgz 自身形成循环哈希。

GitHub Release 三项资产固定为：

```text
citizensdk.tgz
citizensdk-release.json
SHA256SUMS
```

`citizensdk-release.json` 固定产品、包名、版本、40 位提交 SHA、Android/iOS 平台集合及
归档载荷逐文件 SHA-256。`SHA256SUMS` 精确覆盖外层 manifest 与 tgz。反向验证会重建规范
tar/gzip 字节并逐字节比较归档，拒绝符号链接、路径穿越、未登记文件和常见私钥材料。

## Hosted Package 与分发边界

GitHub Release 三件套继续作为来源审计、校验和离线留档。Hosted Package 不重新装配 SDK：
官方 Dart 发布工具读取已经注入 Android ARM64 与 iOS ARM64 原生库并通过反向校验的同一
候选的逐字节临时副本；副本只隔离 Dart 生成的 `.dart_tool`，不是第二份发布候选。根
`.pubignore` 排除完整 Rust 源码、测试、脚本、审计文档、Cargo/Dart
锁文件以及 GitHub 外层 manifest/checksums，只保留根 pubspec、运行时 Dart/Flutter、平台插件、
链资产、移动原生库、README、CHANGELOG、第三方声明与全部适用许可证。CI 和 Release 都执行
`dart pub publish --dry-run`，任何缺失文件、不允许的依赖源或官方校验问题都会失败关闭。

源码中的 `pubspec.yaml`、`android/build.gradle` 与 `ios/citizen_sdk.podspec` 已统一冻结为
`1.0.0`。发布器要求三者、请求软件版本及候选 manifest 完全一致；版本升级必须先形成新的
源码提交，不能只向 Release 输入另一个版本。本步骤不执行 Hosted 上传，在首次发布完成前
不得宣称已经可由 `citizen_sdk: ^1.0.0` 获取。不设独立发布按钮，不接公民网下载，也不更新
CitizenServe/CitizenWeb/Cloudflare 下载指针。当前正式平台只有 Android ARM64 与 iOS ARM64。
