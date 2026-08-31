use chatserver_core::{
    protocol, AuthenticatedDevice, EncryptedDeliveryRecord, PublishedKeyPackage,
};

#[test]
fn key_package_is_bound_to_authenticated_device() {
    let actor = AuthenticatedDevice {
        user_id: "user-a".into(),
        device_id: "phone-a".into(),
    };
    let package = PublishedKeyPackage {
        user_id: "user-a".into(),
        device_id: "phone-a".into(),
        key_package_ref: "ab".repeat(32),
        key_package: "opaque-mls-key-package".into(),
        cipher_suite: "MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519".into(),
        not_before: 1,
        not_after: 10_000,
        last_resort: true,
    };
    assert_eq!(package.validate_for(&actor, 100), Ok(()));
}

#[test]
fn message_is_bound_to_one_recipient_device_and_seven_days() {
    let actor = AuthenticatedDevice {
        user_id: "user-a".into(),
        device_id: "phone-a".into(),
    };
    let message = protocol::EncryptedMessage {
        message_id: "env-a".into(),
        conversation_id: "dm-a-b".into(),
        sender_user_id: "user-a".into(),
        sender_device_id: "phone-a".into(),
        deliveries: vec![protocol::EncryptedDelivery {
            recipient: Some(protocol::Recipient {
                user_id: "user-b".into(),
                device_id: "phone-b".into(),
            }),
            openmls_ciphertext: b"opaque-mls-message".to_vec(),
        }],
        created_at_millis: 100,
    };
    let records = EncryptedDeliveryRecord::from_message(&message, &actor, 100).expect("records");
    assert_eq!(records.len(), 1);
    assert!(records[0].expires_at_millis > records[0].accepted_at_millis);
}
