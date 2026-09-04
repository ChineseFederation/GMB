# CitizenSDK Apple projection

This directory is the single Apple source projection for CitizenSDK. The
`CitizenSDK` Swift module is compiled together with the Rust product Core into
one `CitizenSDK.xcframework`; `CitizenSDKFlutter` is only the Flutter adapter
that links that framework. There is no Apple-specific Core, signer, chain
implementation, or asset source of truth here.

The canonical builder exposes the C header and Swift declarations as one mixed
Apple framework module. Stable Swift interfaces are emitted with
`-import-underlying-module` against that same `CitizenSDK` framework module;
the checked-in bridging header remains the traditional/source-build contract
and is deliberately not passed to library-evolution compilation. This avoids
both a second C module/product and Swift's unsupported combination of bridging
headers with `.swiftinterface` generation.

Core copies the Apple host vtables but borrows their contexts through successful
instance destruction. Native therefore holds an explicit ABI +1 retain covering
itself, `CitizenSDKHostBridge`, callback context and every store/vault context.
Close advances monotonically through monitor stop, callback clear and
destroy-only phases; callback clear is persisted before the first destroy call,
so every BUSY or non-BUSY destroy failure retries destroy directly. The +1 is
released exactly once only after destroy succeeds. At that same success point
HostBridge is cleared first, closing its SQLite stores even if the already
closed public facade remains retained; the Native ABI +1 is then released once.
Forgotten Swift close and a failed Flutter detach are transferred to a
supervised, backoff reaper rather than releasing borrowed contexts or leaking
an owner with no recovery path.
Recovery never trusts a possibly delayed Swift lifecycle event: it queries the
authoritative C lifecycle, checkpoints a truly running Core, and then resumes
the monotonic ABI teardown phase.

Supported SDK projection variants are deliberately narrow:

- iOS device variant, Rust target `aarch64-apple-ios`;
- iOS simulator variant, Rust target `aarch64-apple-ios-sim`;
- macOS, Rust target `aarch64-apple-darwin`.

The public platform set is exactly `iOS` and `macOS`; the device and simulator
entries are technical variants of iOS, not separate platform names. Rust target
triples, generated XCFramework identifiers and Swift module identities may
contain architecture or simulator markers, but they are compiler contracts and
never become public product or platform names.

The iOS device and simulator variants use a shallow `CitizenSDK.framework` with
install ID `@rpath/CitizenSDK.framework/CitizenSDK`. The macOS slice uses the
standard `Versions/A` framework layout with install ID
`@rpath/CitizenSDK.framework/Versions/A/CitizenSDK`. Its only permitted
symlinks are `Versions/Current -> A` and the root `CitizenSDK`, `Headers`,
`Modules`, and `Resources` links into `Versions/Current`. All five targets are
relative; every other symlink in the XCFramework or release candidate is
invalid.

The checked-in package manifest and podspec consume the XCFramework injected
into this directory by the canonical candidate builder. Build intermediates,
archives, DerivedData, Pods, SwiftPM state and the XCFramework itself must stay
under TataConsole's central CitizenSDK work directory and never be committed.
本机当前工作根固定为
`/Users/rhett/TATA/target/.work/GMB/citizensdk/SDK`，只使用本任务独占子目录。
成功产物根为 `/Users/rhett/TATA/target/GMB/citizensdk/SDK`，已有产物不能被
失败验收覆盖。第 6 步路径仅是任务卡内已结束的历史记录，不是当前生成目录。

The Step 6 Flutter consumer built an Android release APK for ABI `arm64-v8a`, an unsigned iOS
device Release app, a generic iOS simulator variant target using `aarch64-apple-ios-sim`, and a macOS Release
app. These are compile/link results only; no mobile-device or Simulator runtime
success is claimed. Flutter's future Swift Package Manager recognition warning
and Android's built-in Kotlin migration notice are deferred to Step 9.

The hardware vault uses a generation-scoped Secure Enclave EC key only as a
KEK. Rust owns sr25519, secret-envelope encryption and signing. Plaintext DEKs
are borrowed directly from or written directly to Rust-owned 32-byte buffers;
mnemonics and passwords never enter the Flutter adapter.

During create, Apple text controls necessarily retain a Swift recovery-phrase
String inside the non-selectable SDK-owned wallet UI until commit/cancel. Every
terminal path clears the control and zeroes the underlying SDK buffer, although
Swift/platform text storage cannot guarantee in-place String erasure. The
phrase is never returned by public API, logged, persisted, or sent to Flutter.
