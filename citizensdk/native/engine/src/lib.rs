//! CitizenSDK product-independent Rust Core Engine.

#![forbid(unsafe_code)]

pub mod capabilities;
pub mod engine;
pub mod error;
pub mod runtime_context;
pub mod state_import;
pub mod system_events;
pub mod transaction_outcome;

pub use capabilities::{resolve_capabilities, CapabilityProbe, CapabilityTracker};
pub use engine::{CitizenEngine, EngineComponents, EngineFuture};
pub use error::EngineError;
pub use runtime_context::{RuntimeContextCache, RuntimeContextRequest};
pub use state_import::{
    validate_import_startup, validate_state_export, validate_state_import, EngineLifecycle,
    StateImportPolicy, StateImportRejection, CHAIN_STATE_FORMAT_VERSION,
    MAX_CHAIN_DATABASE_BYTES,
};
pub use system_events::{decode_system_outcome, DecodedDispatchFailure, DecodedSystemOutcome};
pub use transaction_outcome::{
    signed_extrinsic_hash, verify_transaction_outcome, TransactionEvidence,
};
