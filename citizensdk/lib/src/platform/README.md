# Mobile platform adapters

This directory contains the Android/iOS adapters that turn the platform-neutral
wallet and light-client contracts into a ready-to-use mobile `CitizenSdk`.

- `HardwareSecretVault` is the byte-only Flutter channel contract.
- `HardwareBoundSeedStore` stores only per-account 32-byte child mini-secrets.
- hardware envelopes are fixed to the `citizensdk` product identity; this layer
  does not read or delete another product's keys or ciphertext.
- each wallet KEK alias is scoped by a 128-bit `walletGeneration`; each account
  ciphertext key additionally carries its 128-bit `secretOwner` and AccountId.
- envelope AAD authenticates `citizensdk`, wallet scope, wallet generation,
  account secret owner, AccountId, and secret type in a fixed field order.
- preferences adapters persist public wallet facts, provisioning, active
  cleanup, and the exact cleanup queue separately from the public smoldot
  finalized database. The wallet adapter serializes commits only within one
  Dart isolate; it does not claim cross-engine CAS.

The fixed product identifier of every newly written hardware envelope is
`citizensdk`. TUYU and other product protocols remain outside this package.
