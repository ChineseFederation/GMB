use chatserver_core::{
    parse_control_command,
    protocol::{
        chat_frame, AttachmentChunk, AttachmentMetadata, BeginAttachment, ChatFrame,
        EncryptedDelivery, EncryptedMessage, Recipient, SendMessage,
    },
    AuthenticatedDevice, ControlCommand, ControlSessionLimits,
};

#[test]
fn server_computes_attachment_expiry_and_requires_every_declared_chunk() {
    let actor = AuthenticatedDevice {
        user_id: "user-a".into(),
        device_id: "device-a".into(),
    };
    let frame = ChatFrame {
        body: Some(chat_frame::Body::BeginAttachment(BeginAttachment {
            attachment: Some(AttachmentMetadata {
                attachment_id: "attachment-a".into(),
                sender_user_id: "user-a".into(),
                recipient_user_ids: vec!["user-b".into()],
                chunks: vec![AttachmentChunk {
                    chunk_index: 0,
                    cipher_byte_size: 4,
                    cipher_sha256: "a".repeat(64),
                }],
                cipher_byte_size: 4,
                cipher_sha256: "b".repeat(64),
                created_at_millis: 1_000,
            }),
        })),
    };
    let command = parse_control_command(
        frame,
        &actor,
        1_000,
        1024,
        &mut ControlSessionLimits::default(),
    )
    .expect("valid attachment");
    let ControlCommand::BeginAttachment(attachment) = command else {
        panic!("wrong command");
    };
    assert_eq!(attachment.chunks.len(), 1);
    assert!(attachment.expires_at_millis > attachment.accepted_at_millis);
}

#[test]
fn duplicate_recipient_device_and_expired_client_time_are_rejected() {
    let actor = AuthenticatedDevice {
        user_id: "user-a".into(),
        device_id: "device-a".into(),
    };
    let delivery = EncryptedDelivery {
        recipient: Some(Recipient {
            user_id: "user-b".into(),
            device_id: "device-b".into(),
        }),
        openmls_ciphertext: vec![1, 2, 3],
    };
    let frame = ChatFrame {
        body: Some(chat_frame::Body::SendMessage(SendMessage {
            message: Some(EncryptedMessage {
                message_id: "message-a".into(),
                conversation_id: "conversation-a".into(),
                sender_user_id: "user-a".into(),
                sender_device_id: "device-a".into(),
                deliveries: vec![delivery.clone(), delivery],
                created_at_millis: 1,
            }),
        })),
    };
    assert!(parse_control_command(
        frame,
        &actor,
        8 * 24 * 60 * 60 * 1000,
        1024,
        &mut ControlSessionLimits::default(),
    )
    .is_err());
}
