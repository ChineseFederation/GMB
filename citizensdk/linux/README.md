# CitizenSDK Linux Host

This directory is the official Linux projection of the platform-independent
CitizenSDK Core. It adds typed host storage, TPM 2.0 KEK protection, an
SDK-owned GTK wallet flow, and C/C++ packaging. It never implements chain,
runtime, sr25519, wallet-envelope, or transaction logic a second time.

The public product identities are exactly `LinuxARM` and `LinuxAMD`. Machine
triples may appear only in build-tool inputs. The Flutter-required source
directory remains lowercase `linux` and is not a third product identity.

## Runtime boundary

- `libcitizensdk.so` is the single Rust Core and owns the existing 70-function
  C ABI, smoldot, wallet envelopes, sr25519 signing, and transactions.
- `libcitizensdk_host.so` owns the Linux host-services vtables, typed stores,
  TPM objects, user authentication, and native wallet flow.
- Native applications include `citizensdk.h` and `citizen_sdk/citizen_sdk.hpp`.
  The C++ API is header-only so the stable binary contract remains C.
- A later Flutter projection links this Host library; secrets never cross a
  Flutter method or event channel.

Native owners must stop Core and await its persisted checkpoint before normal
destroy. The C++ RAII wrapper transfers an unexpectedly busy destructor to the
process supervisor, which performs a checkpointed stop and monotonic teardown
with bounded backoff; it never frees Host vtables while Core borrows them. The
destructor performs finite clear/destroy attempts and terminates if even that
ownership transfer cannot be established. A C++ `EventObserver` only borrows
its event/result synchronously and must not retain or release the result; the
wrapper releases it exactly once after normal or exceptional observer return.

The source tree must not contain generated libraries, build directories,
CMake caches, downloaded dependencies, or test reports. Every local generated
item belongs under `/Users/rhett/TATA/tataconsole/target/citizensdk` in a
task-exclusive directory selected by TataConsole or the caller. Linux CTest
configuration requires that existing mode-`0700` directory through
`-DCITIZENSDK_TEST_WORK_DIR=<absolute-path>`; the test helper rejects a missing,
relative, root, symlinked, wrongly owned, or wrongly permissioned directory and
has no `/tmp` fallback.

Each application supplies a validated reverse-DNS `application_id`. Host data
is always placed below `<base>/<application_id>/citizensdk/v1/{public,secure}`;
the application cannot point CitizenSDK at another product's final wallet
directory. Both typed roots are mode `0700`; their database, rollback journal,
WAL, and SHM files are mode `0600`, owned by the process effective UID, limited
to one hard link, and opened relative to a no-follow directory descriptor.
CitizenSDK's openat-backed SQLite VFS binds every database and sidecar action
to that descriptor and never routes the validated path back through
`/proc/self/fd` or the default pathname VFS. Existing schema and all required
PRAGMAs are read back exactly; no fallible postcondition may run after a
successful `COMMIT` and turn a durable write into a reported failure.
Fresh v1 tables and `user_version` are created in one explicit transaction;
an unknown version or any partial/extra schema is rejected without repair.

SQLite, OpenSSL crypto, and TPM2-TSS enter the Host link as explicit pinned
static archives supplied from the authorized central build root. CMake rejects
missing, relative, shared, or implicit replacements; there is no dynamic
dependency fallback. `libstdc++` and `libgcc` are selected statically by the
Release-pinned compiler through `-static-libstdc++ -static-libgcc`. CI/Release
must record that toolchain, verify every archive identity, and reject dynamic
C++ runtime dependencies before the two ordinary runtime files are admitted
in step 7.3.

## CMake consumer shape

The installed package is designed for the following minimal CMake boundary:

Select exactly one platform package directory, for example
`<prefix>/lib/LinuxARM/cmake/CitizenSDK` or
`<prefix>/lib/LinuxAMD/cmake/CitizenSDK`, as `CitizenSDK_DIR`. The two package
configs and target exports are deliberately isolated and cannot overwrite one
another when both release projections are unpacked under one prefix.

```cmake
find_package(CitizenSDK 1 CONFIG REQUIRED)

add_executable(example main.cc)
target_link_libraries(example PRIVATE CitizenSDK::Host)
target_compile_definitions(example PRIVATE
  CITIZENSDK_ASSET_DIR="${CITIZENSDK_ASSET_DIR}")
```

The package config exposes `CITIZENSDK_ASSET_DIR`; the example forwards that
installed path into its own source and uses it when constructing the Host:

```cpp
#include <citizen_sdk/citizen_sdk.hpp>

citizen_sdk::Config config;
config.storage_root = "/absolute/application/state";
config.asset_root = CITIZENSDK_ASSET_DIR;
config.application_id = "org.example.application";
citizen_sdk::Host host(config);
host.open();
host.close();
```

No `COMPONENTS` are declared. This snippet records the intended source contract
only: Step 7.1 did not install the package, compile this consumer, or run it.
The real relocated-install consumer fixture and both machine-target checks
remain Step 7.3 gates. `CitizenSDK::Host` carries `CitizenSDK::Core` in its
public link interface; consumers do not rediscover SQLite, TPM2-TSS, OpenSSL,
GTK, or a second Core.

## Hardware-vault contract

Wallet capability is available only when TPM 2.0 and the SDK-owned strong user
authentication flow are both usable. Missing or inaccessible TPM hardware is
reported truthfully and never falls back to a file KEK, Secret Service, or a
software-only key. Chain read and verification remain usable without a vault.
Deterministic software-TPM validation must therefore run inside a controlled
Linux guest that exposes its vTPM as `/dev/tpmrm0` or `/dev/tpm0`; production
code has no socket TCTI injection or public downgrade switch.

The separate device-vault unlock password is used as the TPM object's authValue
and is not the optional BIP-39 derivation password. It is held only in a
zeroizing native buffer. Mnemonics, child mini-secrets, private keys, plaintext
DEKs, and passwords must never be logged or returned by this layer.
