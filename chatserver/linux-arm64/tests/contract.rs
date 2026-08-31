use chatserver_core::{
    protocol::{AttachmentChunk, AttachmentMetadata},
    AuthenticatedDevice, EncryptedAttachment,
};
use chatserver_linux::server::{ATTACHMENT_CONTENT_ROUTE, HEALTH_ROUTE, REALTIME_ROUTE};

#[test]
fn linux_routes_are_the_single_control_and_attachment_contract() {
    let routes = [HEALTH_ROUTE, REALTIME_ROUTE, ATTACHMENT_CONTENT_ROUTE];
    assert!(routes.iter().all(|route| !route.contains("legacy")));
    assert!(routes.iter().all(|route| !route.contains("/v1")));
}

#[test]
fn attachment_contract_binds_sender_and_seven_day_expiry() {
    let now = 1_000_000_u64;
    let actor = AuthenticatedDevice {
        user_id: "alice".to_owned(),
        device_id: "phone-a".to_owned(),
    };
    let metadata = AttachmentMetadata {
        attachment_id: "attachment-1".to_owned(),
        sender_user_id: "alice".to_owned(),
        recipient_user_ids: vec!["bob".to_owned()],
        chunks: vec![AttachmentChunk {
            chunk_index: 0,
            cipher_byte_size: 16,
            cipher_sha256: "a".repeat(64),
        }],
        cipher_byte_size: 16,
        cipher_sha256: "a".repeat(64),
        created_at_millis: now,
    };
    let attachment =
        EncryptedAttachment::from_protocol(&metadata, &actor, now, 1024).expect("valid attachment");
    assert!(attachment.expires_at_millis > now);

    let mut forged = metadata.clone();
    forged.sender_user_id = "mallory".to_owned();
    assert!(EncryptedAttachment::from_protocol(&forged, &actor, now, 1024).is_err());

    let mut third_party_identity = metadata;
    third_party_identity.recipient_user_ids = vec!["bob@example.com".to_owned()];
    assert!(EncryptedAttachment::from_protocol(&third_party_identity, &actor, now, 1024).is_ok());
}

#[test]
fn linux_push_payload_is_a_content_free_wake_only() {
    let push = include_str!("../src/push.rs");
    assert!(push.matches("\"event\": \"chat_wake\"").count() >= 2);
    for forbidden in [
        "conversation_id",
        "sender_user_id",
        "sender_cid_number",
        "message_id",
        "attachment_id",
    ] {
        assert!(!push.contains(forbidden));
    }
}
