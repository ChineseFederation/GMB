use crate::{
    protocol::{chat_frame, ChatFrame, MessageAvailable},
    ChatServerError, EncryptedDeliveryRecord,
};
use async_trait::async_trait;

/// 内部唤醒事件同样保存规范 Protobuf 帧，禁止生成第二套 JSON 协议。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RealtimeEvent(Vec<u8>);

impl RealtimeEvent {
    pub fn message_available(message: &EncryptedDeliveryRecord, server_time_millis: u64) -> Self {
        let frame = ChatFrame {
            body: Some(chat_frame::Body::MessageAvailable(MessageAvailable {
                message_id: message.message_id.clone(),
                conversation_id: message.conversation_id.clone(),
                server_time_millis,
            })),
        };
        Self(prost::Message::encode_to_vec(&frame))
    }

    pub fn from_bytes(bytes: Vec<u8>) -> Result<Self, ChatServerError> {
        crate::decode_chat_frame(&bytes)?;
        Ok(Self(bytes))
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }
}

#[async_trait(?Send)]
pub trait RealtimeSink {
    async fn notify_message(
        &self,
        message: &EncryptedDeliveryRecord,
    ) -> Result<(), ChatServerError>;
}
