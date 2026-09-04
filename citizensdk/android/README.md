# CitizenSDK Android Flutter host

`gradle.properties` enables AndroidX for both the standalone native AAR and the
Flutter plugin projection. It is source configuration, not generated Gradle
state; the Kotlin compiler runs in-process so all caches and outputs remain
under TataConsole `target` rather than a user-level compiler-daemon directory.

This directory is the Android side of the `citizen_sdk` Flutter package. The
plugin does not contain a second wallet, vault, JNI adapter, or light client.
Its `main` source set compiles the public Kotlin facade directly from
`android/native/src/main/kotlin`, while the Flutter-specific channel projection
stays under `android/src/main/kotlin/org/citizen/sdk`.

The build consumes one externally staged `arm64-v8a` directory selected by
`CITIZENSDK_ANDROID_CORE_DIR`. That directory must contain exactly
`libcitizensdk.so` and `libcitizensdk_jni.so`. The same staged bytes are used by
the native Android distribution; the Flutter plugin never embeds an AAR and
never packages legacy `libsmoldot.so`.

`CITIZENSDK_ANDROID_BUILD_DIR` selects the shared external build root. Local
flows accept only descendants of `/Users/rhett/TATA/tataconsole/target/GMB/citizensdk/SDK`; GitHub
Actions may use any absolute path outside the SDK source tree. The Flutter and
native modules use separate children below that root.

The native build entry applies the NDK's deterministic `--strip-unneeded` to
the Core staging file before either projection. AGP therefore packages the
same release bytes that are delivered as the standalone Core library instead
of silently creating a second stripped variant inside the AAR.
The same entry fixes the Core ELF SONAME as `libcitizensdk.so`; post-assembly
validation requires both library SONAMEs, exactly one JNI dependency on that
Core name, and rejects every `DT_NEEDED` value containing a build-host path.

Hosted-package assembly may inject the same two files into
`android/src/main/jniLibs/arm64-v8a` in its disposable candidate. Build outputs,
native C++ sources, AARs, and tests remain outside the published runtime package.

The plugin exposes fixed v1 method and event channels. Every request, response,
event, error and nested public value uses a fixed-length positional list;
`Map` payloads are rejected because StandardMessageCodec cannot preserve
duplicate keys for validation. Recovery phrases,
passwords, native handles, prepared-wallet handles, result handles, and signed
extrinsics cannot cross those channels. Wallet creation, import, and account
expansion launch the non-exported SDK-owned secure activity instead.

Detach and explicit close share one supervised lifecycle: all accepted work is
first settled; a `running` provider is checkpointed through `stop` before
destruction; `created`, `stopped`, and `startFailed` instances close directly.
`startFailed` has no persistable stable running snapshot. A still `starting` or
`importingState` instance fails closed, and no stop failure is converted into a
direct destroy. Engine detach transfers the whole session registry into a
process-owned strong orphan supervisor. A failed stop or close is retried with
bounded exponential delay; an operation that has not settled keeps ownership
alive instead of permitting premature native destruction. Supervised close
asks cancellable transfer watches to terminate and waits at most 30 seconds per
attempt; timeout re-enters orphan supervision and never authorizes destruction.
