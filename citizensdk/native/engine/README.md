# CitizenSDK Core Engine

`citizen-sdk-engine` is the product-independent Rust coordination layer for the
single CitizenSDK product. It owns capability resolution, exact-block runtime
context caching, verified state import, and transaction execution conclusions.
It depends only on typed contracts and official SCALE/metadata tooling.

The dependency direction is fixed:

```text
language bindings -> stable C ABI -> engine -> contracts <- providers
```

The engine does not know Flutter, Swift, Kotlin, application navigation,
CitizenApp databases, TUYU, chat, square, shopping, booking, or arbitrary JSON
RPC. A smoldot adapter will implement `VerifiedChainClient` in a later step;
the current Dart runtime remains active until that adapter and the stable C ABI
are completed.

## Verification rules

- A runtime context binds version and metadata to one exact best or finalized
  block. An older in-flight best request may be cached by its own hash but may
  never replace a newer best identity.
- Imported light-client state is accepted only before startup and only after
  chain ID, protocol ID, genesis hash, format, finality, and non-regression
  checks succeed.
- A submitted hash or block inclusion is not execution success. The engine
  hashes the complete signed extrinsic, locates the exact block index, then
  accepts only `System.ExtrinsicSuccess` or `System.ExtrinsicFailed` for that
  same index using metadata from that same block.
- Missing, malformed, contradictory, or cross-block evidence returns an
  explicit unverified conclusion; it never guesses success.

Build and test state must be redirected outside this source tree. For local
CitizenSDK work, only TataConsole's central `target/citizensdk` scope is
permitted.
