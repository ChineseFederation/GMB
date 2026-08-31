use chatserver_core::protocol::{
    chat_frame, ChatFrame, EncryptedDelivery, EncryptedMessage, Recipient, SendMessage,
};

#[test]
fn one_message_carries_one_ciphertext_per_recipient_device() {
    let message = EncryptedMessage {
        message_id: "message-a".into(),
        conversation_id: "conversation-a".into(),
        sender_user_id: "user-a".into(),
        sender_device_id: "device-a".into(),
        deliveries: vec![
            EncryptedDelivery {
                recipient: Some(Recipient {
                    user_id: "user-b".into(),
                    device_id: "device-b".into(),
                }),
                openmls_ciphertext: vec![1, 2, 3],
            },
            EncryptedDelivery {
                recipient: Some(Recipient {
                    user_id: "user-b".into(),
                    device_id: "device-c".into(),
                }),
                openmls_ciphertext: vec![4, 5, 6],
            },
        ],
        created_at_millis: 10,
    };
    let frame = ChatFrame {
        body: Some(chat_frame::Body::SendMessage(SendMessage {
            message: Some(message),
        })),
    };
    let bytes = chatserver_core::encode_chat_frame(&frame);
    assert_eq!(chatserver_core::decode_chat_frame(&bytes), Ok(frame));
}
