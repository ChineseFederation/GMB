# CitizenSDK product C ABI

This crate is the only product-level native ABI. Every exported symbol starts
with `citizensdk_`; language bindings do not receive a smoldot handle, an
arbitrary RPC method, a borrowed Rust secret pointer, a raw signer, or an
sr25519 private-key entry point.

The dependency direction is fixed:

```text
C / Dart / Swift / Kotlin
          |
          v
      citizensdk_*
          |
          v
 CitizenEngine -> typed contracts <- smoldot provider
```

The ABI uses fixed-width fields, `struct_size` and `abi_version` prefixes,
monotonic non-zero `uint64_t` handles, stable numeric errors, and owned result
handles. Result bytes are copied into caller memory and every result handle is
released exactly once. An instance cannot be destroyed while requests or
owned results remain, so an accepted request cannot silently lose its one
completion event.

Request acceptance first reserves a unique nonzero result registry slot and a
mandatory completion-event capacity unit. Other events cannot steal that unit;
event sequence values are still assigned at enqueue time so concurrent callback
order remains strictly increasing. Exhaustion rejects the call before a request
ID is returned, and rejection removes placeholders without reusing handles.

Callbacks run only on the instance's dedicated event-dispatch thread and never
while an Engine, registry, callback-state, or result lock is held. Destroying
an instance from inside its own callback is rejected as busy; destruction from
another thread waits for an in-flight callback and guarantees no later call.
Capability subscribe/unsubscribe are also rejected from the callback before
bounded publication or monitor join can wait on that same dispatch thread.
Callback/subscription transitions, request acceptance and destroy share a
per-instance linearization gate, but the gate is released before waiting for
an in-flight callback or monitor. Registration is the commit point; immediate
state notifications are best-effort and remain synchronously queryable.
Completions may race with the accepting ABI return, so bindings route by the
event's request ID. A non-`Busy` failure after destroy starts leaves a
teardown-only, retry-destroy handle instead of reopening partial lifecycle work.
Host-composed start, stop and import reserve that gate exclusively: prior
asynchronous requests must complete before acceptance, and later requests or
controls receive `Busy` through completion. Only the owning stop request may
join a capability monitor that existed before its exclusive reservation.

Long-lived raw-extrinsic watches and high-level wallet-transfer terminal
futures run on a separate bounded four-worker executor. They cannot starve
lifecycle, finite read, import/export, or submit work on the bounded
short-operation executor. Cancelling a wallet transfer drops the active future
and reports `CANCELLED`, but never clears durable Pending/InBlock history.

The ABI v1 surface contains the unchanged original 36 symbols plus 34 appended
typed account, wallet, signing, transfer and history symbols: exactly 70 public
functions. `citizensdk_create` remains the compatible session-backed chain-only
constructor. `citizensdk_create_with_host` builds the platform-independent full
composition from five named stores (chain database, runtime cache, wallet
profile, transaction history and encrypted-secret blob) plus the KEK/DEK
`SecretVault`; secure storage and vault are all-or-none. No placeholder reports
missing components ready.

For that host constructor only, `citizensdk_start` restores and validates the
typed chain database before Engine/provider start, `citizensdk_export_state`
persists the exact exported snapshot before returning it, and
`citizensdk_stop` checkpoints before unsubscribe, product-service or provider
stop. A checkpoint failure leaves those stop side effects untouched. Direct
destroy does not perform asynchronous host persistence; callers use a
successful graceful stop first. The legacy constructor keeps its original
session behavior and shared request admission.

Accepted host callbacks remain registered as outstanding both before and after
their exactly-once completion claim. The completing phase ends only after the
SDK has validated/copied host memory and delivered the completion; the remaining
extern-callback tail accesses no instance state. Destroy therefore cannot free
instance-owned state in the sensitive interval. Duplicate, rejected and late
completions remain pointer-free no-ops.

Before a non-null completion reads or claims the pending registry, its result
`host_operation_id` must equal the operation ID encoded in the callback token.
A crossed identity pair is ignored without consuming either operation. A null
result remains terminal for the token-selected operation; only a matching
non-null pair may move from Pending to Completing.

Prepared-wallet mnemonic bytes exist only behind an SDK-owned handle bound to
its owner instance and may cross the ABI solely for explicit creation/backup
UI. Import and account expansion accept explicit user mnemonic input. Private
keys and child secrets are never exported. Rust encrypts each child with
AES-256-GCM using a random 32-byte DEK, random nonce and full `SecretRef` AAD;
the host only wraps/unwraps the DEK, and unwrap writes directly into an exact
32-byte Rust-owned buffer.

The typed root Dart API, Android Kotlin/Java and Flutter projections, and the
shared Darwin Swift/Flutter projections use this C ABI and host composition.
The Apple host provides separate typed public/secure SQLite stores and a
KEK-only Secure Enclave vault; no secret or native handle crosses Flutter.

Build and test output must be redirected to
`/Users/rhett/TATA/tataconsole/target/citizensdk`. This source directory must
stay free of generated headers and native artifacts; there is intentionally no
`build.rs`.

Imported-state startup failure is a one-way `StartFailed` Engine transition.
Bindings must destroy that handle and create a fresh, never-imported instance
to fall back to the packaged #0 checkpoint; this ABI does not erase a rejected
host cache or retry it automatically.
