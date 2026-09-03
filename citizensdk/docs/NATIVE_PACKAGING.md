# CitizenSDK 原生产物与候选打包

## 源码树规则

`/Users/rhett/GMB/citizensdk` 只保存源码、`assets/README.md` 资产边界、
`assets/citizenchain` 固定链资产、manifest、锁文件、文档和测试源码，
不得保存 `.so`、`.a`、`target`、`build`、CMake cache、`.dart_tool`、Gradle/CocoaPods 状态或
Release 包。

根 `Cargo.toml` workspace 现包含 `native/contracts`、`native/engine`、`native/ffi`、
`native/signer` 和 `native/smoldot/provider`。前三项是 CitizenSDK 自有 Core/产品 ABI 闭集；
Provider 是 `SOURCE_SHA256.json` 中单独分类的 SDK-only smoldot 适配。`engine` 精确依赖官方
`subxt-core = 0.43.0`。收编的 PoW/light-base 保留嵌套 workspace 与已验证锁语义；Release
另外核对 Provider 递归 smoldot registry 闭包与 PoW 锁的 name/version/checksum 完全一致。

统一原生入口 `scripts/build-native.sh` 要求调用方提供源码树外的：

```text
CITIZENSDK_WORK_DIR=<Cargo 工作目录>
CITIZENSDK_NATIVE_OUTPUT_DIR=<原生产物目录>
```

脚本在首次 `mkdir` 前要求两个目录都是绝对规范路径，拒绝 `.`、`..`、重复或末尾分隔符，
并逐级拒绝既存符号链接及非目录祖先。发布器对 candidate、archive 和 verify 路径执行同一
预检，不能借中间符号链接或路径穿越把生成状态写进 SDK 源码树或 TataConsole 中央目录之外。

脚本使用 `cargo build --locked`。Android 产品目标构建唯一
`libcitizensdk.so` 与薄 `libcitizensdk_jni.so`，拒绝 `libsmoldot`、共享 C++ 运行库、额外 ABI
或第二份 Core。Apple 产品从 `native/ffi` 构建同一 `citizensdk_*` Core，再将
`darwin/Sources/CitizenSDK` Swift 源码、根产品头、Privacy Manifest 与完整 CitizenChain 资产组合为一个
`CitizenSDK.xcframework`。其闭集只有 iOS 设备变体、iOS 模拟器变体与 macOS；三个
Apple machine slice 的架构元数据均为 `arm64`；
每个 slice 精确导出产品头声明的 70 个符号，并拒绝 `smoldot_*`、`citizen_sr25519_*`、
`account_crypto_*` 和其它架构。

legacy `libsmoldot.dylib` 只允许作为源码树外的 macOS `arm64` 差分测试宿主库生成；它绝不进入
XCFramework、Hosted 或 GitHub 候选。其 `LC_ID_DYLIB` 是编译工作区的 build-local 路径，只适合
按准确文件路径直接加载测试，不是可分发 install name，并须随 `.work` 清理。

显式 `abi-host` 目标从 `native/ffi` 构建当前宿主测试用 `libcitizensdk`，把真实导出符号与根
`include/citizensdk.h` 逐项比较，同时用 C11/C++17 编译合同核对全部公开布局；任何
`smoldot_*`、`citizen_sr25519_*` 或 `account_crypto_*` 泄露都会失败。它只写入调用者指定的
外部 `abi-host/` 目录，不加入 `all`，也不进入 Android/Apple 正式候选。
产品 ABI v1 的闭集是原 36 个符号保持不变并追加 34 个符号，总计 70 个；构建产物与头文件
任一缺失、额外或重复都必须失败关闭。

Android Core 在进入 Gradle 前由固定 NDK 的 `llvm-strip --strip-unneeded` 显式处理一次；该同一
staging 字节随后复制为独立 `libcitizensdk.so` 并进入 AAR。构建结束再逐字节对拍 AAR 与独立
双库，避免 AGP 在 AAR 内隐式产生第二个 stripped Core 版本。
Android Core 同时固定 `DT_SONAME=libcitizensdk.so`；JNI 固定
`DT_SONAME=libcitizensdk_jni.so`，并且必须只按该 SONAME 依赖一次 Core。最终 ELF 门禁拒绝
任何包含 `/` 的 `DT_NEEDED`，防止中央构建机绝对路径进入设备运行时依赖。

Android 原生 AAR 与 Flutter 插件消费同一产品双库字节。Apple Swift 原生 API 与 Flutter
adapter 消费同一个 `CitizenSDK.xcframework`；`native/smoldot/ffi` 只属于归档差分测试，不能
被描述为任何正式平台的产品 ABI。

第 4.1 步已经加入 Rust Core 账户、钱包、sr25519、准确 V4 交易构造和历史源码；钱包
创建使用 prepare/备份确认/commit，删除使用永久密文墓碑和 generation retirement，钱包交易在
pending CAS 成功后才广播。第 4.2 步完成 Rust 内部 provider/runtime/store/vault 组合；第 5.1
步在未发布 ABI v1 内保留旧 `citizensdk_create` 的 chain-only 语义，并追加
`citizensdk_create_with_host`、五类 typed stores/KEK-DEK Vault 合同以及账户、钱包、签名、
高层转账和历史投影。第 5.2 步进一步完成 Dart 公共入口、Android Kotlin/JNI/安全界面、
Flutter tuple channel 与 Android 候选投影；第 6 步共享 Darwin 源码把同一产品 ABI 投影为
Swift/Flutter、typed SQLite 与 Apple Vault。TataConsole Flow 同步仍由后续步骤验收。

同一未发布 ABI v1 还把平台链数据库接点固定在既有 start/export/stop：host start 自动恢复，
host export 与 graceful stop 自动 exact-CAS 持久化；legacy constructor 跳过这些自动动作。
host start/stop/import 独占异步 admission，平台包装必须先收口较早请求，并在完成前阻止后续控制；
Android/Apple 包装不得自行解析私有 store 信封或另造缓存协议，且直接 destroy 不作为 checkpoint。

第 7.1 步新增 LinuxARM、LinuxAMD 共用的 Host/C/C++ 源码、typed stores、TPM Vault 与合同测试，
但不修改 Rust Core、根 C ABI、Cargo workspace 或 Dart 平台注册。该步没有生成 `.so`，没有运行
Linux 编译/测试，也没有把 Linux 加入正式候选 manifest。

Android NDK 版本在 SDK 原生入口中固定为 `28.2.13676358`，与 GMB 官方依赖合同一致。
调用方提供 `ANDROID_NDK_HOME` 时必须精确指向该版本；同时提供 `ANDROID_HOME` 与
`ANDROID_SDK_ROOT` 时两者必须一致。若三个 Android 环境变量均缺失，本机入口只从宿主标准
SDK 目录（macOS 为 `$HOME/Library/Android/sdk`，LinuxARM 或 LinuxAMD 为 `$HOME/Android/Sdk`）解析该固定
版本，不扫描或选择“最新”NDK。这样 SDK 本机构建不依赖塔塔控制台版本，同时仍拒绝版本漂移。

Apple 产品构建固定 `ios_deployment_target=16.0` 与 `macos_deployment_target=13.0`。iOS 设备变体、
iOS 模拟器变体与 macOS 三次 `cargo build` 分别使用 `aarch64-apple-ios`、
`aarch64-apple-ios-sim` 与 `aarch64-apple-darwin`，并显式设置对应最低系统版本，避免 Rust/C
对象继承构建机当前系统。`darwin/citizen_sdk.podspec` 与 `darwin/Package.swift` 使用相同最低
版本合同；所有 Swift module、framework binary 与 XCFramework 的机器架构元数据都必须精确为 `arm64`。

## LinuxARM 与 LinuxAMD 第 7.1 步边界

Flutter 官方平台源码目录固定为小写 `linux/`；公开平台目录和 manifest 值只允许
`LinuxARM`、`LinuxAMD`。两者对应的工具链值分别是 `aarch64-unknown-linux-gnu` 与
`x86_64-unknown-linux-gnu`，首版动态兼容基线固定为 glibc 2.31。这些 target triple、ELF
machine 和 `CMAKE_SYSTEM_PROCESSOR` 只属于机器字段，不能演变为额外产品名。

第 7.3 步构建完成后，唯一候选允许注入：

```text
linux/lib/LinuxARM/libcitizensdk.so
linux/lib/LinuxARM/libcitizensdk_host.so
linux/lib/LinuxAMD/libcitizensdk.so
linux/lib/LinuxAMD/libcitizensdk_host.so
```

Core 必须精确导出 70 个根 `citizensdk_*`；Host 只装配 typed stores、TPM/认证、SDK-owned
钱包流程和生命周期，不复制 smoldot、signer 或 Engine。Host 只能按 SONAME 依赖 Core 一次，
两库不得出现绝对 `DT_NEEDED` 或构建机 RPATH/RUNPATH。CMake 公开目标固定为
`CitizenSDK::Core` 与 `CitizenSDK::Host`，C++ convenience API 保持 header-only，不引入跨
编译器 C++ ABI。Host 使用自有 openat 型 SQLite VFS，把主库、journal、WAL 与 SHM 的实际
文件操作绑定到已验证目录 fd；不得依赖 `/proc/self/fd` 或重新解析可替换路径。第 7.3 步
relocated-install consumer smoke 必须覆盖目录替换、sidecar、精确 schema/PRAGMA 与 durable
commit 线性化合同。

所有 Linux 构建与测试状态必须写入
`/Users/rhett/TATA/tataconsole/target/citizensdk` 下的任务独占工作目录。第 7.1 步只固定源码
和 Release 源文件反向闭集；上述候选路径、ELF、GLIBC、TPM 和两种机器运行门禁尚未执行，
因此当前 release manifest 仍精确只包含 Android、iOS、macOS。
Linux CMake/CTest 调用方必须以
`-DCITIZENSDK_TEST_WORK_DIR=<该任务目录>` 注入一个已存在、有效 UID 所有、权限为 `0700` 的
绝对目录；测试不创建或猜测中央根，只在已验证目录 fd 下以 CSPRNG 名称和 `mkdirat` 创建
本用例子目录，也没有 `/tmp` fallback。

## Android 与 Apple 注入

Android 根 Gradle 与 native AAR 子项目统一读取：

```text
CITIZENSDK_ANDROID_BUILD_DIR=<源码树外的 Android 构建根>
CITIZENSDK_ANDROID_CORE_DIR=<直接包含双 SO 的 arm64-v8a 目录>
```

后一目录必须且只能包含 `libcitizensdk.so` 与 `libcitizensdk_jni.so`。本机两个目录都必须位于
`/Users/rhett/TATA/tataconsole/target/citizensdk`；GitHub Actions 必须位于 checkout 外。根 Flutter 模块
通过 source set 编译 `android/native/src/main/kotlin` 的同一生产 facade，不依赖或嵌套 AAR。
正式候选另外放置 `android/citizensdk.aar` 供原生宿主使用。
Gradle/Kotlin 的 persistent project state 必须由构建器显式定向到 TataConsole 中央 work
directory；源码树不得生成或保存 `android/.kotlin`，候选构造与反向验证也必须将其视为错误。

Apple 构建不读取 legacy iOS 静态库目录。统一原生入口在外部工作目录生成
`apple/CitizenSDK.xcframework`，随后由候选构造器原子注入到 `darwin/CitizenSDK.xcframework`。
podspec、Swift Package 与 `Sources/CitizenSDKFlutter` 均引用这一名字固定的 XCFramework，不重新链接一份
Core。反向验证精确核对 iOS 设备与模拟器变体、macOS 三个 slice、单一 Apple `arm64` machine 架构、
每个平台的准确 install ID、产品 70 符号、Swift interface、根头文件、
Privacy Manifest 与完整链资产；缺失或额外项均失败关闭。

iOS 设备和模拟器变体的 framework 是浅层布局，二进制位于
`CitizenSDK.framework/CitizenSDK`，install ID 均为
`@rpath/CitizenSDK.framework/CitizenSDK`。macOS framework 使用标准版本化布局，真实二进制
位于 `CitizenSDK.framework/Versions/A/CitizenSDK`，install ID 为
`@rpath/CitizenSDK.framework/Versions/A/CitizenSDK`。macOS 产品和 slice 公开名称始终是
`macOS`，不会附加架构后缀。

macOS framework 内只允许并必须保留以下精确五个相对符号链接：

```text
Versions/Current -> A
CitizenSDK -> Versions/Current/CitizenSDK
Headers -> Versions/Current/Headers
Modules -> Versions/Current/Modules
Resources -> Versions/Current/Resources
```

iOS 两种变体、XCFramework 其他位置和候选其他目录不允许任何符号链接。上述五个链接
若目标、相对路径、节点类型或数量漂移，或出现绝对路径、`..`、dangling、环路、逃逸，同样
失败关闭。

## 本机 TataConsole

所有本机生成状态只允许位于 `/Users/rhett/TATA/tataconsole/target/citizensdk`。本机构建先读取
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

TataConsole 本机构建以 `.work/candidate-transaction.lock` 覆盖初始化、构建、提交和恢复的完整
跨进程事务。锁 owner 先以 noclobber 完整写入 PID 与随机 token，再由同文件系统硬链接原子
声明固定普通文件锁，不存在空 owner 固定态。活动、非法或无法确认死亡的 owner 均失败关闭，
失效锁只有在两种本机进程检查均证明 PID 已死亡后才可原子接管。退出清理只能移除逐字节属于
本进程的锁；恢复槽建立前和最终提交前还会重新检查中央目录闭集。

## CI 与 Release

CitizenSDK 复用 GMB 唯一顶层 Workflow 和现有产品流程：

- CI 对准确 `github.sha` 重新安装锁定依赖、检查发布闭集、执行静态检查与测试、构建原生
  核心，实际运行 Android JUnit、Apple XCTest、Dart/Flutter 与 Rust 测试，在同一
  注入后候选上执行 Hosted dry-run，并上传 `CitizenSDK-CI` 三件套。
- Release 复核指定 CI 的 workflow、显示标题、产品 `citizensdk`、目标 `sdk`、成功状态和
  准确 `source_sha`，不读取、下载或比较 CI 资产；随后在隔离快照中重新执行依赖检查、测试、
  原生构建、候选生成、反向验证与 Hosted dry-run，并创建正式 GitHub Release。孤立 Tag
  清理、主发布路径和响应中断恢复三处都必须核验版本 Tag 精确锚定该成功 CI 的 `source_sha`。

CI 与 Release 都使用确定性候选算法，但 Release 的成立条件是来源绑定、独立重建与完整
验证，不宣称不同 Runner、不同 run 的压缩包在所有环境下必然逐字节相同。

当前只更新 CitizenSDK canonical 源码/候选合同，没有修改 TataConsole Flow 的内嵌副本。
任务卡已经明确这些 Flow 在第 10、11 步按当时完成的统一流程一次同步；在此之前不得把现态
远程 CI/Release 当作已接入新 Rust Core 的验证渠道，也不得局部新增第二套流程。

两条流程的测试命令合同相同：根包一次发现并执行全部根测试和已经迁入的 smoldot 测试，
不把历史的 230 项与 51 项固定成两套数量门禁，并以 `flutter test --timeout=2m` 统一执行；
第 2 步隔离副本实际执行结果为 288/288。外层两分钟超时必须长于来源测试内部的 30 秒活链
订阅窗口。Android 在临时 Flutter 宿主中执行 Gradle
`:citizen_sdk:testDebugUnitTest`；Apple 必须启动 iOS 模拟器变体 runtime 执行 XCTest，并验证
iOS 设备变体、iOS 模拟器变体与 macOS 的 XCFramework/Swift/Flutter 闭集；三个 slice 的
机器架构元数据均须为 `arm64`。
平台测试必须实际启动测试运行器并取得成功终态，不能用 APK 构建、framework 链接、test
discovery 或报告文件存在来代替。本轮本机 Android AAR 构建通过，Apple 单一 XCFramework
只含 iOS 设备与模拟器变体及 macOS 三个 Apple `arm64` machine slice 并构建通过；iOS 的
两组测试 bundle 已编译，但本机没有 Simulator runtime，所以 iOS XCTest
仅记录编译门禁。macOS 已运行
Core 50 项和 Flutter adapter 22 项 XCTest，0 失败、1 项真机硬件用例跳过；最终
normal/supervisor smoke 通过。正式 CI 仍必须在安装了 Simulator runtime 的 runner 上实际
执行 iOS XCTest。

同一真实 Flutter consumer 已完成 Android release APK（ABI `arm64-v8a`）、iOS device Release
no-codesign、iOS 模拟器变体（Rust target `aarch64-apple-ios-sim`）编译和 macOS Release 构建。它们证明当前
Flutter/Dart、插件与原生投影能够链接成正式配置产物，不代表移动真机或 Simulator runtime
已执行。Flutter 对插件 Swift Package Manager 目录的未来识别警告，以及 Android built-in
Kotlin 迁移提示，留到第 9 步 Hosted/Flutter 集成统一处理，不扩展第 6 步。

同一本机闭集还验证 Hosted 17 个 Dart 文件分析 0 问题、完整 Dart 316/316
（`--timeout=2m`）、根 Rust 285/285 加 compile-fail 文档测试 1/1、Clippy/格式，以及
Android 原生 Kotlin/Java 单元测试 Gradle 17 个 task 全部成功。

## 正式候选格式

`scripts/release.mjs` 从只读源码快照和外部原生产物构造唯一规范候选与 gzip/tar。GitHub
归档内包含完整 SDK 源码、测试、文档、锁文件、Android 原生投影与 Apple XCFramework，并包含
`citizensdk-release.json`；外层 `SHA256SUMS` 不进入 tgz，避免对 tgz 自身形成循环哈希。

GitHub Release 三项资产固定为：

```text
citizensdk.tgz
citizensdk-release.json
SHA256SUMS
```

`citizensdk-release.json` 固定产品、包名、版本、40 位提交 SHA，并只登记 Android、iOS 与
macOS 三个平台；iOS 设备与模拟器只是同一平台内的技术变体。manifest 同时登记
归档载荷逐文件 SHA-256。`SHA256SUMS` 精确覆盖外层 manifest 与 tgz。反向验证会重建规范
tar/gzip 字节并逐字节比较归档，拒绝符号链接、路径穿越、未登记文件和常见私钥材料。
其中“拒绝符号链接”唯一例外是上文标准 macOS framework 的精确五个内部相对链接；归档必须
保留其链接身份与目标，不能把它们展开为重复文件。除此之外的任何符号链接仍一律拒绝。

## Hosted Package 与分发边界

GitHub Release 三件套继续作为来源审计、校验和离线留档。Hosted Package 不重新装配 SDK：
官方 Dart 发布工具读取已经注入 Android `arm64-v8a` 产品双库/AAR 与 Apple `arm64` machine XCFramework、并通过反向校验的同一
候选的逐字节临时副本；副本只隔离 Dart 生成的 `.dart_tool`，不是第二份发布候选。根
`.pubignore` 排除完整 Rust 源码、测试、脚本、审计文档、Cargo/Dart
锁文件以及 GitHub 外层 manifest/checksums，只保留根 pubspec、运行时 Dart/Flutter、平台插件、
`assets/README.md` 与 `assets/citizenchain` 四文件链资产闭集、Android/Apple 原生投影、README、
CHANGELOG、第三方声明与全部适用许可证。GitHub 候选中的 `android/citizensdk.aar` 不进入
Hosted 包；Hosted Android 只保留根插件、共享 Kotlin 生产 facade 和同一双 SO，不保留 native
测试、C++、Gradle/AAR 构建输入。即使 dry-run 副本已经执行过 Dart、Flutter 或平台
工具，`.dart_tool`、`build`、`target` 与 `.gradle` 生成树也必须全部过滤。CI 和 Release 都执行
`dart pub publish --dry-run`，任何缺失文件、不允许的依赖源或官方校验问题都会失败关闭。

Hosted 的 Dart 运行时闭包精确为 17 个文件：`lib/citizen_sdk.dart`、`lib/src/api`
六个 Dart 文件、`lib/src/crypto/account_codec.dart`、`lib/src/models` 五个 Dart 文件，以及
`lib/src/platform` 下 codec、sessions、platform contract 和 Flutter platform 四个文件。运行依赖只有
Flutter SDK 与 `polkadart_keyring`；legacy/差分依赖是 dev-only，不进入 Hosted 运行时。

源码中的 `pubspec.yaml`、`android/build.gradle` 与 `darwin/citizen_sdk.podspec` 已统一冻结为
`1.0.0`。发布器要求三者、请求软件版本及候选 manifest 完全一致；版本升级必须先形成新的
源码提交，不能只向 Release 输入另一个版本。本步骤不执行 Hosted 上传，在首次发布完成前
不得宣称已经可由 `citizen_sdk: ^1.0.0` 获取。不设独立发布按钮，不接公民网下载，也不更新
CitizenServe/CitizenWeb/Cloudflare 下载指针。Android、iOS 与 macOS 源码投影均使用同一
产品 ABI。本步已完成 Android AAR、Apple 单一 XCFramework、本机 Apple 编译、macOS XCTest
和最终 smoke；本机无
Simulator runtime 和真实 Apple 移动设备，因此不声称 iOS XCTest 已运行或真机硬件金库
已验收。当前 TataConsole Flow 仍未集成本闭集，也未运行远程 CI、正式 Release、
Hosted 上传或 Git。

Linux 第 7.1 步源码已进入 GitHub 审计候选的受控源闭集，但 Hosted 运行时和正式平台清单仍
不包含 Linux。只有第 7.2 步完成 Flutter adapter、并在第 7.3 步完成 LinuxARM/LinuxAMD
真实构建、测试、ELF/ABI 反向校验后，才允许一次性修改 `.pubignore`、pubspec 和 manifest；
不能先发布一个声明 Linux、实际缺少对应运行库的 Dart 包。
