# Mobile platform adapters

This directory contains the Android/iOS adapters that turn the platform-neutral
wallet and light-client contracts into a ready-to-use mobile `CitizenSdk`.

- `HardwareSecretVault` is the byte-only Flutter channel contract.
- `HardwareBoundSeedStore` stores only per-account 32-byte child mini-secrets.
- hardware envelopes are fixed to the `citizensdk` product identity; this layer
  does not read, migrate, or delete another product's keys or ciphertext.
- preferences adapters persist public wallet facts and the public smoldot
  finalized database in separate namespaces.

The fixed product identifier of every newly written hardware envelope is
`citizensdk`. TUYU and other product protocols remain outside this package.
