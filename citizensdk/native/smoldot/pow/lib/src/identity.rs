//! Public account-address encoding required by the light-client JSON-RPC protocol.
//!
//! CitizenSDK intentionally exposes only SS58 public-key formatting from smoldot's historical
//! `identity` namespace. Private-key parsing, keystores and signing remain owned by the SDK signer
//! and platform secure vault.

pub mod ss58;
