//! 合同层稳定错误类别；C ABI 数字码不在本层冻结。

use std::{error::Error, fmt};

/// Engine 可以稳定分类的合同错误。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ContractErrorCode {
    InvalidArgument,
    InvalidState,
    Unsupported,
    Unavailable,
    NotReady,
    NotFound,
    Conflict,
    Integrity,
    AuthenticationCancelled,
    AuthenticationRequired,
    KeyInvalidated,
    PermissionDenied,
    Storage,
    Network,
    Decode,
    Timeout,
    Internal,
}

impl ContractErrorCode {
    /// 稳定、与语言无关的文本码；面向用户的本地化文案由绑定层处理。
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::InvalidArgument => "invalid_argument",
            Self::InvalidState => "invalid_state",
            Self::Unsupported => "unsupported",
            Self::Unavailable => "unavailable",
            Self::NotReady => "not_ready",
            Self::NotFound => "not_found",
            Self::Conflict => "conflict",
            Self::Integrity => "integrity",
            Self::AuthenticationCancelled => "authentication_cancelled",
            Self::AuthenticationRequired => "authentication_required",
            Self::KeyInvalidated => "key_invalidated",
            Self::PermissionDenied => "permission_denied",
            Self::Storage => "storage",
            Self::Network => "network",
            Self::Decode => "decode",
            Self::Timeout => "timeout",
            Self::Internal => "internal",
        }
    }
}

/// 不包含秘密字节的合同错误。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ContractError {
    code: ContractErrorCode,
    message: String,
}

impl ContractError {
    pub fn new(code: ContractErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }

    pub const fn code(&self) -> ContractErrorCode {
        self.code
    }

    pub fn message(&self) -> &str {
        &self.message
    }
}

impl fmt::Display for ContractError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}: {}", self.code.as_str(), self.message)
    }
}

impl Error for ContractError {}

pub type ContractResult<T> = Result<T, ContractError>;
