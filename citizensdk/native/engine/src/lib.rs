//! CitizenSDK product-independent Rust Core Engine.

#![forbid(unsafe_code)]

pub mod capabilities;
pub mod engine;
pub mod error;
pub mod runtime_context;
pub mod state_import;
pub mod system_events;
pub mod transaction_outcome;

pub use capabilities::{CapabilityProbe, resolve_capabilities};
pub use engine::{CitizenEngine, EngineComponents, EngineFuture};
pub use error::EngineError;
pub use runtime_context::{RuntimeContextCache, RuntimeContextRequest};
pub use state_import::{
    EngineLifecycle, MAX_CHAIN_DATABASE_BYTES, StateImportPolicy, StateImportRejection,
    validate_import_startup, validate_state_export, validate_state_import,
};
pub use system_events::{DecodedDispatchFailure, DecodedSystemOutcome, decode_system_outcome};
pub use transaction_outcome::{
    TransactionEvidence, signed_extrinsic_hash, verify_transaction_outcome,
};
