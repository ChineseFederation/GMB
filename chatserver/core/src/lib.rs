//! ChatServer 的部署中立核心。

pub mod attachment;
pub mod auth;
pub mod command;
pub mod key_package;
pub mod mailbox;
pub mod protocol;
pub mod push;
pub mod realtime;

pub use attachment::{EncryptedAttachment, EncryptedAttachmentChunk};
pub use auth::{AuthenticatedAccess, AuthenticatedDevice, ChatAuthorization};
pub use command::{parse_control_command, ControlCommand, ControlSessionLimits};
pub use key_package::PublishedKeyPackage;
pub use mailbox::EncryptedDeliveryRecord;
pub use protocol::{
    attachment_ready_frame, decode_chat_frame, encode_chat_frame, failure_frame,
    key_package_batch_frame, message_batch_frame, pong_frame, ready_frame, success_frame,
};
pub use push::{PushEndpoint, PushPlatform};
pub use realtime::RealtimeEvent;

/// ChatServer 稳定错误，部署端只能映射这些码，禁止回传底层异常正文。
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum ChatServerError {
    #[error("invalid_request")]
    InvalidRequest,
    #[error("forbidden")]
    Forbidden,
    #[error("not_found")]
    NotFound,
    #[error("conflict")]
    Conflict,
    #[error("resource_limit")]
    ResourceLimit,
    #[error("storage_unavailable")]
    StorageUnavailable,
}

impl ChatServerError {
    pub const fn code(&self) -> &'static str {
        match self {
            Self::InvalidRequest => "invalid_request",
            Self::Forbidden => "forbidden",
            Self::NotFound => "not_found",
            Self::Conflict => "conflict",
            Self::ResourceLimit => "resource_limit",
            Self::StorageUnavailable => "storage_unavailable",
        }
    }
}
