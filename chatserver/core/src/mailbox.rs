use std::collections::HashSet;

use base64::{engine::general_purpose::STANDARD, Engine as _};
use serde::{Deserialize, Serialize};

use crate::{protocol, AuthenticatedDevice, ChatServerError};

pub const MESSAGE_RETENTION_MILLIS: u64 = 7 * 24 * 60 * 60 * 1000;
pub const MAX_FUTURE_SKEW_MILLIS: u64 = 5 * 60 * 1000;
const MAX_DELIVERIES: usize = 64;
const MAX_CIPHERTEXT_BYTES: usize = 1024 * 1024;

/// 一条按接收设备路由的不透明 RFC 9420 Message。
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct EncryptedDeliveryRecord {
    pub message_id: String,
    pub conversation_id: String,
    pub sender_user_id: String,
    pub sender_device_id: String,
    pub recipient_user_id: String,
    pub recipient_device_id: String,
    pub openmls_ciphertext: String,
    pub created_at_millis: u64,
    pub accepted_at_millis: u64,
    pub expires_at_millis: u64,
}

impl EncryptedDeliveryRecord {
    /// 把一条逻辑消息拆成按接收设备存储的密文记录，期限只由服务端计算。
    pub fn from_message(
        message: &protocol::EncryptedMessage,
        actor: &AuthenticatedDevice,
        now_millis: u64,
    ) -> Result<Vec<Self>, ChatServerError> {
        actor.validate()?;
        if message.sender_user_id != actor.user_id
            || message.sender_device_id != actor.device_id
            || !valid_identifier(&message.message_id, 128)
            || !valid_identifier(&message.conversation_id, 256)
            || message.deliveries.is_empty()
            || message.deliveries.len() > MAX_DELIVERIES
        {
            return Err(ChatServerError::InvalidRequest);
        }
        let expires_at_millis = server_expiry(message.created_at_millis, now_millis)?;
        let mut recipients = HashSet::with_capacity(message.deliveries.len());
        message
            .deliveries
            .iter()
            .map(|delivery| {
                let recipient = delivery
                    .recipient
                    .as_ref()
                    .ok_or(ChatServerError::InvalidRequest)?;
                if !valid_identity(&recipient.user_id)
                    || !valid_identity(&recipient.device_id)
                    || delivery.openmls_ciphertext.is_empty()
                    || delivery.openmls_ciphertext.len() > MAX_CIPHERTEXT_BYTES
                    || !recipients.insert((recipient.user_id.clone(), recipient.device_id.clone()))
                {
                    return Err(ChatServerError::InvalidRequest);
                }
                Ok(Self {
                    message_id: message.message_id.clone(),
                    conversation_id: message.conversation_id.clone(),
                    sender_user_id: message.sender_user_id.clone(),
                    sender_device_id: message.sender_device_id.clone(),
                    recipient_user_id: recipient.user_id.clone(),
                    recipient_device_id: recipient.device_id.clone(),
                    openmls_ciphertext: STANDARD.encode(&delivery.openmls_ciphertext),
                    created_at_millis: message.created_at_millis,
                    accepted_at_millis: now_millis,
                    expires_at_millis,
                })
            })
            .collect()
    }

    pub fn to_protocol(&self) -> Result<protocol::EncryptedMessage, ChatServerError> {
        let ciphertext = STANDARD
            .decode(&self.openmls_ciphertext)
            .map_err(|_| ChatServerError::StorageUnavailable)?;
        Ok(protocol::EncryptedMessage {
            message_id: self.message_id.clone(),
            conversation_id: self.conversation_id.clone(),
            sender_user_id: self.sender_user_id.clone(),
            sender_device_id: self.sender_device_id.clone(),
            deliveries: vec![protocol::EncryptedDelivery {
                recipient: Some(protocol::Recipient {
                    user_id: self.recipient_user_id.clone(),
                    device_id: self.recipient_device_id.clone(),
                }),
                openmls_ciphertext: ciphertext,
            }],
            created_at_millis: self.created_at_millis,
        })
    }
}

pub fn server_expiry(
    created_at_millis: u64,
    accepted_at_millis: u64,
) -> Result<u64, ChatServerError> {
    if created_at_millis == 0
        || created_at_millis > accepted_at_millis.saturating_add(MAX_FUTURE_SKEW_MILLIS)
    {
        return Err(ChatServerError::InvalidRequest);
    }
    let created_expiry = created_at_millis
        .checked_add(MESSAGE_RETENTION_MILLIS)
        .ok_or(ChatServerError::InvalidRequest)?;
    if created_expiry <= accepted_at_millis {
        return Err(ChatServerError::InvalidRequest);
    }
    Ok(created_expiry.min(accepted_at_millis.saturating_add(MESSAGE_RETENTION_MILLIS)))
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
