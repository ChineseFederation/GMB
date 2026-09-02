# CitizenSDK Apple tests

The canonical central Apple candidate harness runs these tests in two modes without
writing build state into this source tree. TataConsole workflow integration is
a later step and must not be claimed until that workflow actually invokes the
harness:

1. Public API/consumer tests link the injected `CitizenSDK.xcframework`, which
   is also the only binary consumed by SwiftPM and CocoaPods.
2. Source-internal contract tests compile the approved `Sources/CitizenSDK`
   and `Sources/CitizenSDKFlutter` files into temporary testable targets with
   `ENABLE_TESTABILITY=YES`. This is required for deterministic SQLite failure,
   callback ownership, vault-operation and Flutter-session negative tests;
   `@testable import` cannot inspect a library-evolution binary built without
   testing enabled.

Source-internal lifecycle fixtures fault-inject callback installation,
capability subscription/unsubscription, callback clear, Flutter-open cleanup,
detach recovery and destroy. They prove monotonic phase retry, no early release
of HostBridge or the ABI +1 owner at any failed stage, immediate HostBridge
release plus exactly-once ABI +1 release after destroy,
and eventual supervised recovery without requiring a deliberately corrupted C
Core binary. Recovery-policy fixtures also prove that a delayed Swift lifecycle
event cannot override the authoritative C lifecycle and that partial teardown
never issues another lifecycle/control call.

Flutter-detach fixtures exercise the production teardown helpers directly. They
prove exactly-once handler revocation in method-channel, event-channel, epoch
order; permanent rejection of queued event generations; cancellation of every
unfinished operation before awaiting any one completion; and continued closure
of later sessions when one session must be transferred to the Core supervisor.
Registration publishes the plugin instance on both Apple platforms. iOS then
delivers Flutter's official `detachFromEngine(for:)` callback. The current
FlutterMacOS registrar has `publish` but declares no engine-detach callback, so a
macOS native host may invoke the same idempotent entry point explicitly and
`deinit` remains the final engine-shutdown fallback.

Both modes use the same C header, Rust Core archive, Swift sources and assets as
the release candidate. The temporary Xcode project, test databases, DerivedData
and result bundles belong only under TataConsole's central CitizenSDK work
directory. Secure Enclave creation, biometric prompts and Keychain device-only
semantics additionally require real supported Apple hardware and are never
declared proven by simulator-only execution.

The current local execution built the one `CitizenSDK.xcframework` with exactly
the iOS, iOS-Simulator and macOS slices, all for ARM64, and compiled both the
iOS device and `iOS-Simulator` test bundles. This Mac has no installed Simulator
runtime, so no iOS XCTest execution is claimed. On macOS, 50 CitizenSDK Core
and 22 Flutter-adapter XCTest cases ran with zero failures; one
real-hardware-only case was skipped. The final normal
and supervisor consumer smoke processes both passed. No physical Apple mobile
device was available, so Secure Enclave, biometric and device-only Keychain
behavior remains a separate device-validation requirement. No remote CI,
formal Release, Hosted upload or Git operation was run, and TataConsole Flow has
not yet integrated this harness.
