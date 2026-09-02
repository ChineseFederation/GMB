# CitizenSDK Flutter Apple adapter

This target only projects the native `CitizenSDK` Swift API through the same
fixed-position protocol-v1 tuples used by Android. It contains no Core, chain,
wallet, signer, state-store, or secret-vault implementation.

The method channel is `citizen/sdk/core/v1`; the event channel is
`citizen/sdk/events/v1`. Mnemonics, passwords, DEKs, native handles, result
handles and prepared-wallet identities have no tuple position. Create/import/
add-account operations launch the SDK-owned Apple wallet UI. A recovery phrase
may be held briefly only by that non-selectable UI until commit/cancel; it is
cleared on terminal paths and never crosses this Flutter target.

Registration publishes the plugin instance on both Apple platforms. Detach is
idempotent and always revokes the method handler, revokes the event handler,
permanently invalidates the current event epoch, clears the sink, cancels every
session's outstanding operations, and only then awaits session closure. One
failed close is transferred to the existing Core supervisor and cannot prevent
later sessions from closing. iOS receives Flutter's published-object
`detachFromEngine(for:)` callback; the current FlutterMacOS registrar exposes no
equivalent callback, so macOS uses the same explicit detach entry and keeps
`deinit` only as the final shutdown fallback.
