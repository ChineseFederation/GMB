use chatserver_cloudflare::api::{ATTACHMENT_CHUNK_ROUTE, HEALTH_ROUTE, REALTIME_ROUTE};

#[test]
fn cloudflare_exposes_the_same_contract_as_linux() {
    assert_eq!(HEALTH_ROUTE, "/health");
    assert_eq!(REALTIME_ROUTE, "/realtime");
    assert_eq!(
        ATTACHMENT_CHUNK_ROUTE,
        "/attachments/{attachment_id}/chunks/{chunk_index}"
    );
}

#[test]
fn cloudflare_has_no_deployment_specific_public_api() {
    let api = include_str!("../src/api.rs");
    assert!(!api.contains("/cloudflare/"));
    assert!(!api.contains("/r2/"));
    assert!(!api.contains("presign"));
    assert!(!api.contains("signed_url"));
    assert!(!api.contains(concat!("/", "messages")));
    assert!(!api.contains(concat!("/", "key-package")));
    assert!(!api.contains(concat!("/", "push-endpoint")));
}

#[test]
fn cloudflare_push_payload_is_a_content_free_wake_only() {
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
