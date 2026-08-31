use prost::Message;

use crate::ChatServerError;

mod generated {
    include!(concat!(env!("OUT_DIR"), "/chat.protocol.rs"));
}

pub use generated::*;

/// 两个部署端共用的唯一 Protobuf 解码入口。
pub fn decode_chat_frame(bytes: &[u8]) -> Result<ChatFrame, ChatServerError> {
    ChatFrame::decode(bytes).map_err(|_| ChatServerError::InvalidRequest)
}

/// 两个部署端共用的唯一 Protobuf 编码入口。
pub fn encode_chat_frame(frame: &ChatFrame) -> Vec<u8> {
    frame.encode_to_vec()
}

pub fn ready_frame(server_time_millis: u64) -> ChatFrame {
    ChatFrame {
        body: Some(chat_frame::Body::Ready(Ready { server_time_millis })),
    }
}

pub fn failure_frame(code: &str) -> ChatFrame {
    ChatFrame {
        body: Some(chat_frame::Body::Failure(Failure {
            code: code.to_owned(),
            message: String::new(),
        })),
    }
}

pub fn success_frame(kind: &str, ids: Vec<String>) -> ChatFrame {
    ChatFrame {
        body: Some(chat_frame::Body::Success(Success {
            kind: kind.to_owned(),
            ids,
        })),
    }
}

pub fn pong_frame(sent_at_millis: u64, server_time_millis: u64) -> ChatFrame {
    ChatFrame {
        body: Some(chat_frame::Body::Pong(Pong {
            sent_at_millis,
            server_time_millis,
        })),
    }
}

pub fn key_package_batch_frame(
    packages: &[crate::PublishedKeyPackage],
) -> Result<ChatFrame, ChatServerError> {
    Ok(ChatFrame {
        body: Some(chat_frame::Body::KeyPackageBatch(KeyPackageBatch {
            key_packages: packages
                .iter()
                .map(crate::PublishedKeyPackage::to_protocol)
                .collect::<Result<Vec<_>, _>>()?,
        })),
    })
}

pub fn message_batch_frame(
    records: &[crate::EncryptedDeliveryRecord],
) -> Result<ChatFrame, ChatServerError> {
    Ok(ChatFrame {
        body: Some(chat_frame::Body::MessageBatch(MessageBatch {
            messages: records
                .iter()
                .map(crate::EncryptedDeliveryRecord::to_protocol)
                .collect::<Result<Vec<_>, _>>()?,
        })),
    })
}

pub fn attachment_ready_frame(attachment_id: String) -> ChatFrame {
    ChatFrame {
        body: Some(chat_frame::Body::AttachmentReady(AttachmentReady {
            attachment_id,
        })),
    }
}
