use core::fmt;

/// Stable Rust-side failure categories used before the C ABI maps them to
/// numeric public error codes.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum EngineError {
    /// Runtime metadata is malformed, unsupported, or has trailing bytes.
    InvalidMetadata(String),
    /// `System.Events` cannot be decoded completely with the exact metadata.
    InvalidEvents(String),
    /// Evidence combines different blocks or contradicts its verified anchor.
    BlockContextMismatch(String),
    /// A capability dependency is unavailable for the requested operation.
    CapabilityUnavailable(String),
    /// A provider or typed store rejected an operation.
    Contract(String),
    /// Internal synchronized state was poisoned and is no longer trustworthy.
    StatePoisoned,
}

impl fmt::Display for EngineError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidMetadata(reason) => {
                write!(formatter, "invalid runtime metadata: {reason}")
            }
            Self::InvalidEvents(reason) => write!(formatter, "invalid System.Events: {reason}"),
            Self::BlockContextMismatch(reason) => {
                write!(formatter, "verified block context mismatch: {reason}")
            }
            Self::CapabilityUnavailable(reason) => {
                write!(formatter, "capability unavailable: {reason}")
            }
            Self::Contract(reason) => write!(formatter, "provider contract failed: {reason}"),
            Self::StatePoisoned => formatter.write_str("engine synchronized state is poisoned"),
        }
    }
}

impl std::error::Error for EngineError {}
