const SOURCE: &str = concat!(
    include_str!("../src/api.rs"),
    include_str!("../src/attachments.rs"),
    include_str!("../src/auth.rs"),
    include_str!("../src/push.rs"),
    include_str!("../src/realtime.rs"),
    include_str!("../src/store.rs"),
);

#[test]
fn identity_never_comes_from_untrusted_chat_headers() {
    assert!(!SOURCE.contains("x-chat-user-id"));
    assert!(!SOURCE.contains("x-chat-device-id"));
    assert!(SOURCE.contains("CHAT_AUTH_ED25519_PUBLIC_KEY"));
    assert!(SOURCE.contains("Algorithm::EdDSA"));
}

#[test]
fn cloudflare_attachment_flow_has_no_account_signing_credentials() {
    assert!(!SOURCE.contains("CF_ACCOUNT_ID"));
    assert!(!SOURCE.contains("R2_KEY"));
    assert!(!SOURCE.contains("R2_SECRET"));
    assert!(!SOURCE.contains("presign"));
    assert!(SOURCE.contains("FixedLengthStream"));
    assert!(SOURCE.contains(".sha256(digest)"));
}

#[test]
fn every_network_endpoint_is_encrypted() {
    assert!(!SOURCE.contains(concat!("http", "://")));
    assert!(!SOURCE.contains(concat!("ws", "://")));
    assert!(SOURCE.contains("\"api.push.apple.com\""));
    assert!(SOURCE.contains("\"api.sandbox.push.apple.com\""));
    assert!(SOURCE.contains("https://{host}/3/device/{}"));
    assert!(SOURCE.contains("https://fcm.googleapis.com"));
}

#[test]
fn realtime_and_push_never_transport_chat_content() {
    let realtime = include_str!("../src/realtime.rs");
    let push = include_str!("../src/push.rs");
    assert!(realtime.contains("send_with_bytes"));
    assert!(realtime.contains("RealtimeEvent::from_bytes"));
    assert!(!realtime.contains("send_with_str"));
    assert!(!push.contains("\"conversation_id\""));
    assert!(!push.contains("\"message_id\""));
    assert!(!push.contains("\"attachment_id\""));
}
