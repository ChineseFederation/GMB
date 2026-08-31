use std::collections::HashSet;

use serde::{Deserialize, Serialize};

use crate::{mailbox::server_expiry, protocol, AuthenticatedDevice, ChatServerError};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EncryptedAttachmentChunk {
    pub chunk_index: u32,
    pub cipher_byte_size: u64,
    pub cipher_sha256: String,
}

/// 客户端已经完成端到端加密的附件元数据。服务端永远看不到明文。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EncryptedAttachment {
    pub attachment_id: String,
    pub sender_user_id: String,
    pub recipient_user_ids: Vec<String>,
    pub chunks: Vec<EncryptedAttachmentChunk>,
    pub cipher_byte_size: u64,
    pub cipher_sha256: String,
    pub created_at_millis: u64,
    pub accepted_at_millis: u64,
    pub expires_at_millis: u64,
}

impl EncryptedAttachment {
    /// 统一校验分块清单，并使用服务端接收时间生成最终期限。
    pub fn from_protocol(
        attachment: &protocol::AttachmentMetadata,
        actor: &AuthenticatedDevice,
        now_millis: u64,
        max_cipher_bytes: u64,
    ) -> Result<Self, ChatServerError> {
        actor.validate()?;
        if attachment.sender_user_id != actor.user_id
            || !valid_attachment_id(&attachment.attachment_id)
            || attachment.recipient_user_ids.is_empty()
            || attachment.recipient_user_ids.len() > 256
            || attachment.chunks.is_empty()
            || attachment.chunks.len() > 10_000
            || attachment.cipher_byte_size == 0
            || attachment.cipher_byte_size > max_cipher_bytes
            || !valid_sha256(&attachment.cipher_sha256)
        {
            return Err(ChatServerError::InvalidRequest);
        }

        let mut total = 0_u64;
        let chunks = attachment
            .chunks
            .iter()
            .enumerate()
            .map(|(index, chunk)| {
                if chunk.chunk_index != index as u32
                    || chunk.cipher_byte_size == 0
                    || chunk.cipher_byte_size > max_cipher_bytes
                    || !valid_sha256(&chunk.cipher_sha256)
                {
                    return Err(ChatServerError::InvalidRequest);
                }
                total = total
                    .checked_add(chunk.cipher_byte_size)
                    .ok_or(ChatServerError::ResourceLimit)?;
                Ok(EncryptedAttachmentChunk {
                    chunk_index: chunk.chunk_index,
                    cipher_byte_size: chunk.cipher_byte_size,
                    cipher_sha256: chunk.cipher_sha256.to_ascii_lowercase(),
                })
            })
            .collect::<Result<Vec<_>, _>>()?;
        if total != attachment.cipher_byte_size || total > max_cipher_bytes {
            return Err(ChatServerError::InvalidRequest);
        }

        let mut recipients = HashSet::with_capacity(attachment.recipient_user_ids.len());
        for recipient in &attachment.recipient_user_ids {
            if !valid_user_id(recipient) || !recipients.insert(recipient.clone()) {
                return Err(ChatServerError::InvalidRequest);
            }
        }
        Ok(Self {
            attachment_id: attachment.attachment_id.clone(),
            sender_user_id: attachment.sender_user_id.clone(),
            recipient_user_ids: attachment.recipient_user_ids.clone(),
            chunks,
            cipher_byte_size: attachment.cipher_byte_size,
            cipher_sha256: attachment.cipher_sha256.to_ascii_lowercase(),
            created_at_millis: attachment.created_at_millis,
            accepted_at_millis: now_millis,
            expires_at_millis: server_expiry(attachment.created_at_millis, now_millis)?,
        })
    }

    pub fn expected_chunk(&self, chunk_index: u32) -> Option<&EncryptedAttachmentChunk> {
        self.chunks
            .get(chunk_index as usize)
            .filter(|chunk| chunk.chunk_index == chunk_index)
    }

    pub fn validate_stored(&self) -> Result<(), ChatServerError> {
        if !valid_attachment_id(&self.attachment_id)
            || !valid_user_id(&self.sender_user_id)
            || self.recipient_user_ids.is_empty()
            || self.chunks.is_empty()
            || self.cipher_byte_size == 0
            || self.expires_at_millis <= self.accepted_at_millis
            || !valid_sha256(&self.cipher_sha256)
        {
            return Err(ChatServerError::InvalidRequest);
        }
        let mut recipients = HashSet::with_capacity(self.recipient_user_ids.len());
        if self
            .recipient_user_ids
            .iter()
            .any(|recipient| !valid_user_id(recipient) || !recipients.insert(recipient))
        {
            return Err(ChatServerError::InvalidRequest);
        }
        let mut total = 0_u64;
        for (index, chunk) in self.chunks.iter().enumerate() {
            if chunk.chunk_index != index as u32
                || chunk.cipher_byte_size == 0
                || !valid_sha256(&chunk.cipher_sha256)
            {
                return Err(ChatServerError::InvalidRequest);
            }
            total = total
                .checked_add(chunk.cipher_byte_size)
                .ok_or(ChatServerError::InvalidRequest)?;
        }
        if total != self.cipher_byte_size {
            return Err(ChatServerError::InvalidRequest);
        }
        Ok(())
    }
}

fn valid_attachment_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
}

fn valid_user_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 256
        && !value
            .bytes()
            .any(|byte| byte == b':' || byte.is_ascii_control())
}

fn valid_sha256(value: &str) -> bool {
    value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit())
}
