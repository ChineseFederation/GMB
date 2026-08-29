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
预检，不能借中间符号链接或路径穿越把生成状态写进 SDK 源码树或 Console 中央目录之外。

脚本使用 `cargo build --locked`，核对 `smoldot_*` 与四个 `citizen_sr25519_*` 符号，并拒绝
聊天或产品账户密码学符号进入原生核心。`all` 另外按 Runner 宿主架构生成
`ios-simulator/libsmoldot.a` 和对应符号清单，只用于执行 iOS Swift XCTest；宿主
`libsmoldot.dylib` 固定为 arm64+x86_64，同时适用于原生与 Rosetta `flutter_tester`。发布器不会把
这些测试库复制进正式候选。

设备与 Simulator 的 iOS 原生构建共用脚本中的唯一 `ios_deployment_target=16.0`，两条
`cargo build` 都显式接收 `IPHONEOS_DEPLOYMENT_TARGET="$ios_deployment_target"`。该环境同时约束
Rust 对象和 Cargo 依赖中由 C 编译器生成的对象，避免它们继承构建机 Xcode 的当前系统版本。
`ios/citizen_sdk.podspec` 同样固定宿主集成最低版本为 iOS 16.0；原生对象、插件与宿主因此保持
同一最低版本合同。macOS `flutter_tester` 宿主测试库不读取该 iOS 环境变量。

## Android 与 iOS 注入

Android 构建读取：

```text
CONSOLE_NATIVE_ANDROID_DIR=<包含 arm64-v8a/libsmoldot.so 的目录>
```

`android/build.gradle` 只声明 `arm64-v8a`，其它 ABI 不进入正式包。

iOS 构建读取：

```text
CONSOLE_NATIVE_IOS_DIR=<包含 libsmoldot.a 与 exported_symbols.txt 的目录>
```

podspec 用 `-force_load` 链入静态库，并根据真实产物的 `exported_symbols.txt` 逐符号添加
`-Wl,-u,<symbol>`，防止 Release `dead_strip` 删除 Dart FFI 入口。缺文件、空清单或符号漂移
必须失败关闭。

## 本机 Console

所有本机生成状态只允许位于 `/Users/rhett/Only/console/target/citizensdk`。本机构建先读取
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

Console 本机构建以 `.work/candidate-transaction.lock` 覆盖初始化、构建、提交和恢复的完整
跨进程事务。锁 owner 先以 noclobber 完整写入 PID 与随机 token，再由同文件系统硬链接原子
声明固定普通文件锁，不存在空 owner 固定态。活动、非法或无法确认死亡的 owner 均失败关闭，
失效锁只有在两种本机进程检查均证明 PID 已死亡后才可原子接管。退出清理只能移除逐字节属于
本进程的锁；恢复槽建立前和最终提交前还会重新检查中央目录闭集。

## CI 与 Release

CitizenSDK 复用 GMB 唯一顶层 Workflow 和现有产品流程：

- CI 对准确 `github.sha` 重新安装锁定依赖、检查发布闭集、执行静态检查与测试、构建原生
  核心，实际运行 Android JUnit、iOS Simulator XCTest、Dart/Flutter 与 Rust 测试，并上传
  `CitizenSDK-CI` 三件套。
- Release 复核指定 CI 的 workflow、显示标题、产品 `citizensdk`、目标 `sdk`、成功状态和
  准确 `source_sha`，不读取、下载或比较 CI 资产；随后在隔离快照中重新执行依赖检查、测试、
  原生构建与候选生成，并创建正式 GitHub Release。

CI 与 Release 都使用确定性候选算法，但 Release 的成立条件是来源绑定、独立重建与完整
验证，不宣称不同 Runner、不同 run 的压缩包在所有环境下必然逐字节相同。

两条流程的测试命令合同相同：根包以 `flutter test` 完整执行 230 项；冻结
`native/smoldot/dart` 包以 `dart test --timeout=2m` 完整执行 51 项，外层两分钟超时必须长于
来源测试内部的 30 秒活链订阅窗口。Android 在临时 Flutter 宿主中执行 Gradle
`:citizen_sdk:testDebugUnitTest`，iOS 启动可用 iPhone Simulator 后执行限定 `RunnerTests` 的
`xcodebuild test`。平台测试必须实际启动测试运行器并取得成功终态，不能用 APK 构建、Pod
链接、test discovery 或报告文件存在来代替。

## 正式候选格式

`scripts/release.mjs` 从只读源码快照和外部原生产物构造规范 gzip/tar。归档内包含完整 SDK
源码、Android/iOS 原生库与 `citizensdk-release.json`；外层 `SHA256SUMS` 不进入 tgz，避免
对 tgz 自身形成循环哈希。

GitHub Release 三项资产固定为：

```text
citizensdk.tgz
citizensdk-release.json
SHA256SUMS
```

`citizensdk-release.json` 固定产品、包名、版本、40 位提交 SHA、Android/iOS 平台集合及
归档载荷逐文件 SHA-256。`SHA256SUMS` 精确覆盖外层 manifest 与 tgz。反向验证会重建规范
tar/gzip 字节并逐字节比较归档，拒绝符号链接、路径穿越、未登记文件和常见私钥材料。

## 分发边界

GitHub Release 是 CitizenSDK 的正式分发终态：不设独立发布按钮，不接公民网下载，不更新
CitizenServe/CitizenWeb/Cloudflare 下载指针，也不发布到 pub.dev。当前正式平台只有
Android ARM64 与 iOS ARM64。
