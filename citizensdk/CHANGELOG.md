# Changelog

## 1.0.0 - Unreleased

- Froze the first stable CitizenSDK package contract around one product ABI for
  Android, the iOS device and simulator variants, and macOS. The current Android
  ABI is `arm64-v8a`; Apple machine architecture metadata is `arm64`.
- Added the typed Dart public API and fixed tuple-only Flutter protocol. The
  Android Flutter plugin and native AAR share one Kotlin facade, JNI bridge,
  Rust Core, chain assets, version, and release candidate.
- Added one shared Darwin source projection for the native Swift API and
  Flutter adapter. iOS and macOS consume the same product Core through
  `CitizenSDK.xcframework`; the product is named macOS and its current machine
  architecture metadata is `arm64`.
- Kept the iOS device and simulator variants as shallow frameworks with install ID
  `@rpath/CitizenSDK.framework/CitizenSDK`, and made macOS a standard
  `Versions/A` framework with install ID
  `@rpath/CitizenSDK.framework/Versions/A/CitizenSDK`. Release candidates permit
  only the five canonical relative symlinks inside that macOS framework and
  reject every other symlink.
- Made Apple teardown monotonic across monitor stop, callback clear,
  destroy-only retry, and final close. An explicit ABI retain lease keeps every
  borrowed host context alive through successful destroy, while abandoned or
  partially closed facades transfer to a supervised backoff reaper.
- Deferred capability and lifecycle Core queries out of the C callback, made
  callback delivery and close linearizable, and made wallet ownership
  fail-closed across concurrent close, stale reservations, and retry handoff.
- Added one idempotent Flutter detach path that revokes method/event handlers,
  permanently invalidates the event epoch, clears the sink, cancels all
  sessions before awaiting any of them, and transfers failed closes to the
  existing supervisor. iOS uses Flutter's published-object detach callback;
  macOS uses the same explicit entry point with deinit as the final fallback.
- Added separate typed public and secure SQLite stores on Apple. Secure Enclave
  protects only a generation-scoped KEK used to wrap random DEKs; sr25519 stays
  in Rust, and no mnemonic, password, DEK, child secret, private key, or native
  handle has a Flutter-channel representation. The iOS simulator variant
  reports hardware-vault and wallet capabilities unavailable instead of using
  a software security downgrade.
- Made the Android release projection exactly one AAR plus the same
  `libcitizensdk.so` and `libcitizensdk_jni.so` bytes used by Flutter; rejected
  nested AARs, Flutter references in the native AAR, extra ABIs, legacy
  `libsmoldot`, missing facade classes, and chain-asset drift.
- Fixed the two Android ELF SONAMEs, required JNI to depend on the Core SONAME
  exactly once, and rejected every `DT_NEEDED` value containing a build-host
  path.
- Required finalized-history bindings to receive 1 through 1990 unique account
  IDs and reject duplicates before session or JNI admission.
- On Android, added SDK-owned non-exported `FLAG_SECURE` wallet flows so
  mnemonic and password input never crosses the Dart channel, plus supervised
  detach that cancels transfer watches, checkpoints running sessions, and
  retains failed cleanup for bounded-backoff retry.
- Kept the CitizenChain light client, rootless hot wallet, sr25519 local
  signing, and on-chain transaction execution behind one `citizen_sdk` API.
- Required the Hosted Package candidate to be derived from the same audited
  GitHub Release candidate. Publication to a Hosted registry remains a
  separately authorized operation.
- Restricted the Hosted Dart runtime to exactly 17 files: one root entry, six
  typed API files, one public account codec, five models, and four platform
  transport files. Archived Dart light-client, wallet, transaction, smoldot,
  and Preferences implementations remain audit/differential inputs only.
- Built the Android AAR, compiled both iOS product test bundles, and assembled
  the single Apple XCFramework with the iOS device and simulator variants plus
  macOS, all with Apple machine architecture value `arm64`. Ran the macOS native suites: 50 Core and 22 Flutter-adapter
  XCTest cases passed with no failures; one
  real-hardware-only case was skipped. The final normal and supervisor consumer
  smoke processes passed. No local Simulator runtime or physical Apple mobile
  device was available, so this does not claim iOS XCTest execution or device
  Secure Enclave/biometric validation.
- Built a real Flutter consumer as an Android release APK for ABI `arm64-v8a`, an iOS device
  Release app without code signing, a generic iOS simulator variant target using Rust
  target `aarch64-apple-ios-sim`, and a
  macOS Release app. These are build/link results, not physical-device or
  Simulator-runtime claims. Flutter's future Swift Package Manager recognition
  warning and Android's built-in Kotlin migration notice are deferred to the
  Step 9 Hosted/Flutter integration work.
- Moved Android Gradle/Kotlin persistent project state into the TataConsole
  central work directory and made source-tree `android/.kotlin` invalid.
- Analyzed the exact 17-file Hosted Dart closure with zero issues, passed the
  complete Dart suite 316/316 with `--timeout=2m`, passed the root Rust
  workspace 285/285 plus its compile-fail doc test 1/1, Clippy and formatting,
  and completed all 17 Android native Kotlin/Java unit-test Gradle tasks.
- Bound the packaged CitizenChain chain spec and light sync state to an exact
  `citizenchain` identity, genesis hash, and SHA-256 asset manifest.
- Required the complete chain-asset contract to pass before the native
  smoldot client is created or initialized.
- Excluded generated build and tool state from the Hosted Package even when
  validation runs in a previously exercised disposable copy.
- Established the product-independent Rust Core contracts and Engine for
  typed verified-chain access, wallet/vault separation, capability snapshots,
  exact-block runtime contexts, guarded state import, and verified transaction
  outcomes.
- Fixed wallet index 0, the account-zero master anchor, Citizen SS58 prefix
  2027, and strict create/import/append provisioning and cleanup ownership.
- Bound chain capability readiness to the Engine lifecycle, with a state-first
  lock order and an immediate readiness check before provider access.
- Added revisioned chain-database snapshots, exact-state CAS, and persistent
  finalized anchors. Cross-process protection requires a qualifying shared,
  durable, strongly atomic store adapter.
- Made host-composed startup restore the typed chain database before provider
  start, and made host export/graceful stop persist the exact stable snapshot
  by revision CAS. Persistence failure short-circuits every stop side effect;
  direct destroy is not a graceful checkpoint. The legacy session constructor
  retains its original explicit import/export and stop behavior.
- Made host-composed start, stop and import exclusive asynchronous lifecycle
  requests. Earlier work must finish before acceptance, and later requests or
  controls observe `BUSY` until completion; the owning stop request alone may
  join its pre-existing capability monitor. Legacy admission remains shared.
- Kept accepted host operations outstanding through completion validation,
  host-memory copying and delivery; the remaining stateless callback tail
  cannot race destroy or expose an instance pointer to late completions.
- Required every non-null host completion to match its callback token and
  `host_operation_id` before the pending registry is claimed. Crossed identity
  pairs are ignored; null completion remains terminal for its token operation.
- Pinned official `subxt-core` 0.43.0 for metadata and `System.Events`
  decoding without adding a remote RPC client or another light node.
- Added the single stable `citizensdk_*` product C ABI with fixed-width
  versioned structures, monotonic handles, owned results, bounded asynchronous
  events, stable errors and truthful capability discovery.
- Preserved all 36 original ABI symbols, layouts, numeric values and legacy
  `citizensdk_create` single-request semantics, then appended 34 typed account,
  wallet, signing, transfer and history symbols for one exact 70-symbol ABI v1
  surface.
- Kept `citizensdk_create` as the compatible chain-only session constructor and
  added `citizensdk_create_with_host` for the platform-independent full Core
  composition over five named typed stores plus the KEK/DEK vault contract.
- Restricted mnemonic output to an SDK-owned prepared-creation handle bound to
  its owner instance and explicit backup UI. Import and account expansion accept
  only explicit user recovery input; private keys and child secrets are never
  exported by the product ABI.
- Added Rust-owned AES-256-GCM child-secret envelopes with random DEKs/nonces and
  full `SecretRef` AAD. Hosts only wrap or unwrap a DEK, and unwrap writes into
  an exact 32-byte Rust-owned output buffer.
- Added the typed smoldot `VerifiedChainClient` provider for exact-block reads,
  verified finalized state, runtime context, signed-extrinsic submission and
  watch, execution verification, and public light-node state import/export.
- Rejected node-returned transaction hashes that differ from the local
  Blake2-256 of the complete signed extrinsic.
- Kept arbitrary JSON-RPC and the legacy `smoldot_*`/`citizen_sr25519_*`
  surface out of the product header. The typed root Dart, Android, iOS and
  macOS bindings use the product ABI; the legacy path remains only as an
  archived differential-test baseline.
- Implemented the Rust Core account-state, exact-best
  `AccountNonceApi_account_nonce` and on-chain fee
  services; the BIP-39 wallet lifecycle with revision CAS, provisioning and
  exact cleanup; the single native sr25519 signer path; exact signed-extrinsic
  V4 `transfer_with_remark` construction; and atomic pending/finalized history.
- Made wallet creation a two-phase, zero-persistent-write prepare followed by
  explicit post-backup commit; encrypted-secret tombstones and Vault generation
  retirement now permanently fence late writers after deletion.
- Required pending submission facts to be persisted before broadcast and
  allowed a finalized success or failure only from the same extrinsic index's
  `System.ExtrinsicSuccess` or `System.ExtrinsicFailed` event.
- Rejected self-transfer history views, paired business and Balances events
  one-for-one, assigned verified local pending to the sender view, preserved the
  receiver view, and kept same-block replay idempotent after pending consumption.
- Resolved historical finalized blocks through the provider before verification
  and fetched security-critical runtime metadata directly from that finalized
  block; persistent runtime caches are never execution evidence.
- Restricted raw submit-and-watch to pure-chain compositions because the watch
  provider broadcasts; wallet compositions fail closed before provider access.
- Documented that general wallet-payload signing is a trusted-host capability,
  so pending-before-broadcast is guaranteed by the SDK high-level wallet
  transaction path rather than imposed on every possible host use of a signature.
- Added the internal product composition that fixes the smoldot provider,
  exact Runtime nonce source and sole sr25519 software signer while accepting
  only typed host stores and `SecretVault`; wallet dependencies are all-or-none.
- Added proof-backed finalized ancestry batches, bounded proof caches, strict
  production-metadata event decoding, 120-block deterministic history batches,
  durable same-account single-flight, and a lifecycle lease covering every
  provider/store await through the final CAS.
- Moved the complete high-level wallet transfer terminal future to the separate
  four-worker watch pool. Cancellation or watch interruption retains durable
  Pending/InBlock state; only canonical body/metadata/System.Events evidence
  yields a finalized execution result.
- Kept the original `citizensdk_create` composition chain-only while exposing
  the complete host-composed surface through `citizensdk_create_with_host`.
  The typed Dart, Android and shared Darwin bindings use that ABI. Legacy
  smoldot host artifacts remain macOS `arm64` differential-test-only and are excluded
  from release candidates.

## 0.1.0 - 2026-08-29

- Established `citizen_sdk` as the single Flutter package boundary for the
  CitizenChain light client, hot wallet, sr25519 signing, and on-chain
  transactions.
- Added Android `arm64-v8a` and iOS Apple `arm64` machine-library packaging contracts.
- Added a Hosted Package candidate contract derived from the same verified
  GitHub Release candidate. This version remains a pre-1.0 release candidate.
