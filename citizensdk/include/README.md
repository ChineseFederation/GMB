# CitizenSDK C/C++ headers

`citizensdk.h` is the only product header. It includes
`citizensdk_types.h`; it deliberately does not include `smoldot.h` and exposes
no raw smoldot client, arbitrary RPC, mnemonic, mini-secret or private-key
function.

Every extensible structure starts with `struct_size` and `abi_version`. Set
those fields to `sizeof(struct)` and `CITIZENSDK_ABI_VERSION` before passing an
input or output structure. All lengths and handles are fixed-width integers;
CitizenSDK ABI v1 supports the product's 64-bit target architectures.

Typical host order:

1. load and pass the three packaged `assets/citizenchain` files to
   `citizensdk_create` for a chain-only session, or provide the typed platform
   services to `citizensdk_create_with_host` for durable state and wallet use;
2. install one event callback and optionally subscribe to capability changes;
3. call `citizensdk_start` and consume its one completion result;
4. check all ten capabilities before using a typed operation;
5. inspect and release every nonzero event result exactly once;
6. call `citizensdk_stop` and await success (host instances checkpoint first),
   then release all results, clear the callback, and destroy; explicit
   unsubscribe before stop is optional because stop also performs it.

## Host services v1

`citizensdk_create_with_host` copies the three pointed-to vtables before the
call returns. The public store is mandatory. The secure store and secret vault
must either both be present or both be absent, so a partially wired wallet can
never be advertised. Hosts cannot inject a chain signer, nonce implementation,
arbitrary key/value store or RPC method.

For a host-backed instance, start automatically restores the typed chain
database before provider start; export and graceful stop persist an exact
revisioned snapshot. If persistence fails, stop has not unsubscribed or stopped
any dependency and may be retried. Direct destroy is not a checkpoint and must
follow a successful stop when the latest light-client state matters. Legacy
session instances keep explicit import/export and their original stop behavior.
Host start, stop and import are exclusive asynchronous lifecycle requests:
acceptance requires no earlier pending request, then later requests, callback or
subscription controls, and destroy return `BUSY` until completion. A host stop
may still join the capability monitor it exclusively owns.

Every host operation receives a unique `host_operation_id`. Returning
`CITIZENSDK_OK` accepts the operation and requires exactly one later completion;
returning any other stable error rejects it and forbids completion. Operations
may complete concurrently from background threads. Ordinary input views are
valid only during the operation callback; completion views are valid only
during completion and are copied synchronously by CitizenSDK. The sole input
lifetime exception is `wrap_dek`: its exact 32-byte view remains backed by a
Rust-owned zeroizing buffer until synchronous rejection or the first completion,
so an asynchronous platform bridge can use the native buffer without copying
the plaintext DEK into Swift/Kotlin-managed storage. It must not retain the
view after completion. Every claimed completion remains outstanding until SDK
validation, copying and delivery finish; the remaining callback tail accesses
no instance state, so destroy cannot race that work. Callback contexts remain
host-owned and must stay valid until successful instance destruction returns.
Before any non-null completion reads or claims the pending registry, its
`host_operation_id` must equal the operation ID encoded in the callback token.
A crossed token/result pair is ignored without consuming either operation. A
null result has no second identity and terminates the token-selected operation
with an integrity failure. Only a matching non-null pair may enter the
Pending-to-Completing phase.

The vault owns only generation-scoped hardware KEKs and 32-byte DEK wrapping.
Both `wrap_dek` input and `unwrap_dek` output use Rust-owned zeroizing buffers
whose lifetime ends at rejection/first completion; `unwrap_dek` receives an
exact 32-byte `citizensdk_mutable_bytes_view_t` and reports only status at
completion. It does not return plaintext through a byte-result callback. No
vault callback receives an account mini-secret, private key, recovery phrase or
signing request.

## Account and wallet results

CitizenChain amounts use `citizensdk_u128_t`: the numeric value is
`high * 2^64 + low`. Balance reads bind to an exact finalized block; nonce and
fee snapshots bind to an exact best block. A nonce result is Runtime state, not
a transaction-pool lease. Use `citizensdk_result_estimate_fee` while retaining
the fee-snapshot result to apply CitizenSDK's exact Perbill rounding and minimum
self-pay calculation.

Wallet operations return only public profiles/accounts, 64-byte signatures,
high-level transfer conclusions and typed history. They never return an account
secret or wallet-built signed extrinsic. Password and recovery-phrase inputs
are byte views borrowed only for the accepting call and copied into Rust-owned
zeroizing containers before return.

Wallet creation is two phase:

1. `citizensdk_prepare_wallet_creation` returns a result containing an
   independent, instance-owned `citizensdk_prepared_wallet_handle_t`;
2. the host size-queries/copies the recovery phrase only through
   `citizensdk_prepared_wallet_copy_mnemonic`, confirms backup with the user,
   then consumes the handle with `citizensdk_commit_wallet_creation`.

Release an abandoned prepared handle explicitly. Instance destruction also
drops its remaining prepared sessions. A commit accepted by the request queue
consumes the handle exactly once; a synchronous acceptance failure restores it.
Copy, release and commit all require the owning `citizensdk_handle_t`; another
live instance cannot guess, read, release or consume the recovery phrase.

`citizensdk_transfer_with_remark` is the wallet transaction path: it constructs
against one exact Runtime, signs inside Rust, atomically records pending before
broadcast, submits, watches and returns only a proven finalized execution or an
explicit pool rejection. A dropped/retracted/timed-out/interrupted watch leaves
durable pending/in-block history intact and completes with a retryable error; it
is never projected as a successful result. Its complete terminal watch runs on
the dedicated four-thread watch pool rather than the short-operation pool.
Cancellation completes with `CITIZENSDK_ERROR_CANCELLED`; dropping the active
future does not clear an already durable pending/in-block record.

History initialization anchors new account cursors to current finality. Batch
sync advances no more than the Core's fixed 120-block limit. Result getters
expose cursor, local submission and finalized transfer collections separately;
finalized remarks include both the lossy UTF-8 display and the original Runtime
bytes so non-UTF-8 chain facts round-trip without corruption.

The callback runs on a CitizenSDK dispatch thread. Do not destroy the instance
from inside that callback; the call returns `CITIZENSDK_ERROR_BUSY` without
changing provider or Engine lifecycle. Capability subscribe and unsubscribe
are likewise rejected from inside the callback before they can publish through
the bounded queue or join the monitor. Other SDK calls are reentrant.
Callback changes, subscription changes, request acceptance and destroy are
linearized per instance; a conflicting transition returns `BUSY` without
holding the gate while it waits for callback/monitor completion. Installing a
callback or subscription is the commit point. Its immediate state event is
best-effort because the same snapshot can be queried synchronously.

An asynchronous completion can race with and arrive before its accepting C
function returns. Route it by `event.request_id`; do not assume the host has
observed `out_request_id` first. `BUSY` from destroy is a preflight and leaves
the handle usable. Any other live-handle destroy failure after teardown starts
leaves a teardown-only handle; issue no new work and retry destroy.

Every accepted request has already reserved one nonzero result handle and one
mandatory completion-event capacity unit. If either monotonic space is
exhausted, acceptance fails synchronously without returning a request ID.
Ordinary events cannot consume reserved completion capacity, and rejected work
removes its placeholder without reusing the numeric handle.

Every copy function supports a first `buffer = NULL, capacity = 0` size query
that returns `CITIZENSDK_OK` and writes `out_required`. Returned text is UTF-8
without a trailing NUL byte.

`citizensdk_cancel_request` is effective for the long-lived raw-extrinsic watch
and high-level wallet-transfer watch requests. Atomic reads and other
state-mutating start/import/submit/stop calls return
`CITIZENSDK_ERROR_UNSUPPORTED` after acceptance rather than pretending that an
already executing operation rolled back.

An imported-state startup failure is one-way: the Engine enters `START_FAILED`.
The binding must destroy that handle and create a new, never-imported instance
to fall back to the packaged #0 checkpoint. ABI v1 does not delete a rejected
host cache or retry it automatically.
