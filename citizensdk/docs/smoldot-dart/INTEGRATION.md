# smoldot Dart 来源合并说明

本目录保存 CitizenApp `smoldot/dart` 的历史说明、许可证、原始包清单和示例来源，供来源
审计使用。`source-pubspec.yaml`、`source-pubspec.lock` 与
`source-analysis_options.yaml` 只是历史记录，不参与 CitizenSDK 依赖解析或静态分析。

长期运行代码已经机械迁入：

- `lib/src/smoldot/`：Dart FFI 绑定；
- `test/smoldot/`：原六个测试及两个公开链夹具；
- `native/smoldot/ffi/`：原生 C ABI；
- `native/smoldot/pow/`：轻节点 Rust 快照。

根 `pubspec.yaml` 是唯一有效 Dart/Flutter 包清单，包名固定为 `citizen_sdk`，不得再次增加
指向仓库内嵌 Dart 包的 `path` 依赖。smoldot 只是 CitizenSDK 内部实现，不形成第二个 SDK、
第二个发布版本或第二个源码真源。迁入的 Dart 文件统一接受根包 formatter；来源内容变更仅限
包 import/export、夹具路径、产物搜索边界、交付范围注释和格式归一，不改轻节点行为。
