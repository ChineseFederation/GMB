//! CitizenSDK product-independent Rust Core Engine.

#![forbid(unsafe_code)]

pub mod account_state;
pub mod capabilities;
pub mod engine;
pub mod error;
mod finalized_events;
mod finalized_history_runtime;
pub mod runtime_context;
pub mod state_import;
pub mod system_events;
mod transaction_builder;
mod transaction_history;
pub mod transaction_outcome;
mod wallet_derivation;
mod wallet_input;
mod wallet_service;
mod wallet_transfer_watch;

#[cfg(test)]
mod finalized_events_tests;
#[cfg(test)]
mod finalized_history_runtime_tests;
#[cfg(test)]
mod transaction_builder_tests;
#[cfg(test)]
mod transaction_history_tests;
#[cfg(test)]
mod wallet_derivation_tests;
#[cfg(test)]
mod wallet_input_tests;
#[cfg(test)]
mod wallet_service_tests;
#[cfg(test)]
mod wallet_transfer_watch_tests;

pub use account_state::{AccountStateService, BestFeeSnapshot};
pub use capabilities::{resolve_capabilities, CapabilityProbe, CapabilityTracker};
pub use engine::{CitizenEngine, EngineComponents, EngineFuture};
pub use error::EngineError;
pub use runtime_context::{RuntimeContextCache, RuntimeContextRequest, MAX_RUNTIME_CONTEXTS};
pub use state_import::{
    validate_import_startup, validate_state_export, validate_state_import, EngineLifecycle,
    StateImportPolicy, StateImportRejection, CHAIN_STATE_FORMAT_VERSION, MAX_CHAIN_DATABASE_BYTES,
};
pub use system_events::{decode_system_outcome, DecodedDispatchFailure, DecodedSystemOutcome};
pub use transaction_outcome::{
    signed_extrinsic_hash, verify_transaction_outcome, TransactionEvidence,
};
pub use wallet_derivation::{validate_wallet_password, WalletWordCount};
pub use wallet_input::{validate_wallet_mnemonic, wallet_word_suggestions};
pub use wallet_service::PreparedWalletCreation;
pub use wallet_transfer_watch::{
    WalletTransferObserver, WalletTransferResolution, WalletTransferWatchResult,
    WalletTransferWatchStage, WalletTransferWatchUpdate,
};
