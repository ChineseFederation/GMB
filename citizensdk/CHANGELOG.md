# Changelog

## 1.0.0 - 2026-08-29

- Froze the first stable CitizenSDK package contract for Android ARM64 and
  iOS ARM64.
- Kept the CitizenChain light client, rootless hot wallet, sr25519 local
  signing, and on-chain transaction execution behind one `citizen_sdk` API.
- Verified that the Hosted Package candidate is derived from the same audited
  GitHub Release candidate. Publication to a Hosted registry remains a
  separately authorized operation.
- Bound the packaged CitizenChain chain spec and light sync state to an exact
  `citizenchain` identity, genesis hash, and SHA-256 asset manifest.
- Required the complete chain-asset contract to pass before the native
  smoldot client is created or initialized.
- Excluded generated build and tool state from the Hosted Package even when
  validation runs in a previously exercised disposable copy.

## 0.1.0 - 2026-08-29

- Established `citizen_sdk` as the single Flutter package boundary for the
  CitizenChain light client, hot wallet, sr25519 signing, and on-chain
  transactions.
- Added Android ARM64 and iOS ARM64 native-library packaging contracts.
- Added a Hosted Package candidate contract derived from the same verified
  GitHub Release candidate. This version remains a pre-1.0 release candidate.
