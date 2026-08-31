use serde::{Deserialize, Serialize};

use crate::{
    protocol::{chat_frame, ChatFrame},
    AuthenticatedDevice, ChatServerError, EncryptedAttachment, EncryptedDeliveryRecord,
    PublishedKeyPackage, PushPlatform,
};

const RESOLVE_WINDOW_MILLIS: u64 = 60_000;
const MAX_RESOLVES_PER_WINDOW: u32 = 120;

/// 每条认证 WSS 会话独立持有的轻量限流状态，不产生数据库写放大。
#[derive(Debug, Clone, Default, Deserialize, Serialize, PartialEq, Eq)]
pub struct ControlSessionLimits {
    resolve_window_started_at_millis: u64,
    resolve_count: u32,
}

impl ControlSessionLimits {
    fn consume_resolve(&mut self, now_millis: u64) -> Result<(), ChatServerError> {
        if self.resolve_window_started_at_millis == 0
            || now_millis < self.resolve_window_started_at_millis
            || now_millis.saturating_sub(self.resolve_window_started_at_millis)
                >= RESOLVE_WINDOW_MILLIS
        {
            self.resolve_window_started_at_millis = now_millis;
            self.resolve_count = 0;
        }
        if self.resolve_count >= MAX_RESOLVES_PER_WINDOW {
            return Err(ChatServerError::ResourceLimit);
        }
        self.resolve_count += 1;
        Ok(())
    }
}

#[derive(Debug)]
pub enum ControlCommand {
    Ping {
        sent_at_millis: u64,
    },
    PublishKeyPackage(PublishedKeyPackage),
    ResolveKeyPackages {
        user_id: String,
        device_id: Option<String>,
        limit: u32,
    },
    SendMessage(Vec<EncryptedDeliveryRecord>),
    SyncMessages {
        limit: u32,
    },
    AcknowledgeMessages {
        message_ids: Vec<String>,
    },
    BeginAttachment(EncryptedAttachment),
    CompleteAttachment {
        attachment_id: String,
    },
    AcknowledgeAttachment {
        attachment_id: String,
    },
    AbortAttachment {
        attachment_id: String,
    },
    RegisterPush {
        platform: PushPlatform,
        token: String,
    },
    RemovePush {
        platform: PushPlatform,
    },
}

/// 两种部署运行时共用的唯一客户端命令入口。
pub fn parse_control_command(
    frame: ChatFrame,
    actor: &AuthenticatedDevice,
    now_millis: u64,
    max_attachment_bytes: u64,
    limits: &mut ControlSessionLimits,
) -> Result<ControlCommand, ChatServerError> {
    actor.validate()?;
    match frame.body.ok_or(ChatServerError::InvalidRequest)? {
        chat_frame::Body::Ping(value) => Ok(ControlCommand::Ping {
            sent_at_millis: value.sent_at_millis,
        }),
        chat_frame::Body::PublishKeyPackage(value) => {
            let package = value
                .key_package
                .as_ref()
                .ok_or(ChatServerError::InvalidRequest)?;
            Ok(ControlCommand::PublishKeyPackage(
                PublishedKeyPackage::from_protocol(package, actor, now_millis)?,
            ))
        }
        chat_frame::Body::ResolveKeyPackages(value) => {
            limits.consume_resolve(now_millis)?;
            if !valid_identity(&value.user_id)
                || !value.device_id.is_empty() && !valid_identity(&value.device_id)
            {
                return Err(ChatServerError::InvalidRequest);
            }
            Ok(ControlCommand::ResolveKeyPackages {
                user_id: value.user_id,
                device_id: (!value.device_id.is_empty()).then_some(value.device_id),
                limit: default_limit(value.limit, 32, 100),
            })
        }
        chat_frame::Body::SendMessage(value) => {
            let message = value.message.ok_or(ChatServerError::InvalidRequest)?;
            Ok(ControlCommand::SendMessage(
                EncryptedDeliveryRecord::from_message(&message, actor, now_millis)?,
            ))
        }
        chat_frame::Body::SyncMessages(value) => Ok(ControlCommand::SyncMessages {
            limit: default_limit(value.limit, 100, 100),
        }),
        chat_frame::Body::AcknowledgeMessages(value) => {
            if value.message_ids.is_empty()
                || value.message_ids.len() > 100
                || value
                    .message_ids
                    .iter()
                    .any(|id| !valid_identifier(id, 128))
            {
                return Err(ChatServerError::InvalidRequest);
            }
            Ok(ControlCommand::AcknowledgeMessages {
                message_ids: value.message_ids,
            })
        }
        chat_frame::Body::BeginAttachment(value) => {
            let attachment = value.attachment.ok_or(ChatServerError::InvalidRequest)?;
            Ok(ControlCommand::BeginAttachment(
                EncryptedAttachment::from_protocol(
                    &attachment,
                    actor,
                    now_millis,
                    max_attachment_bytes,
                )?,
            ))
        }
        chat_frame::Body::CompleteAttachment(value) => Ok(ControlCommand::CompleteAttachment {
            attachment_id: checked_attachment_id(value.attachment_id)?,
        }),
        chat_frame::Body::AcknowledgeAttachment(value) => {
            Ok(ControlCommand::AcknowledgeAttachment {
                attachment_id: checked_attachment_id(value.attachment_id)?,
            })
        }
        chat_frame::Body::AbortAttachment(value) => Ok(ControlCommand::AbortAttachment {
            attachment_id: checked_attachment_id(value.attachment_id)?,
        }),
        chat_frame::Body::RegisterPush(value) => {
            let platform = PushPlatform::parse(&value.platform)?;
            if value.token.is_empty()
                || value.token.len() > 4096
                || value.token.bytes().any(|byte| byte.is_ascii_whitespace())
            {
                return Err(ChatServerError::InvalidRequest);
            }
            Ok(ControlCommand::RegisterPush {
                platform,
                token: value.token,
            })
        }
        chat_frame::Body::RemovePush(value) => Ok(ControlCommand::RemovePush {
            platform: PushPlatform::parse(&value.platform)?,
        }),
        _ => Err(ChatServerError::InvalidRequest),
    }
}

fn default_limit(value: u32, default: u32, maximum: u32) -> u32 {
    if value == 0 {
        default
    } else {
        value.min(maximum)
    }
}

fn checked_attachment_id(value: String) -> Result<String, ChatServerError> {
    if valid_identifier(&value, 128) {
        Ok(value)
    } else {
        Err(ChatServerError::InvalidRequest)
    }
}

fn valid_identifier(value: &str, max_len: usize) -> bool {
    !value.is_empty()
        && value.len() <= max_len
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.'))
}

fn valid_identity(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 256
        && !value
            .bytes()
            .any(|byte| byte == b':' || byte.is_ascii_control())
}
