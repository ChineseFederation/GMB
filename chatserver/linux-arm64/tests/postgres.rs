use std::collections::BTreeSet;

const SCHEMA: &str = include_str!("../schema.sql");

#[test]
fn schema_is_single_canonical_empty_database_definition() {
    let expected = BTreeSet::from([
        "attachment_receipts",
        "attachment_recipients",
        "attachment_chunks",
        "attachments",
        "chatserver_schema",
        "messages",
        "key_packages",
        "push_endpoints",
        "push_outbox",
    ]);
    let actual = SCHEMA
        .lines()
        .filter_map(|line| line.trim().strip_prefix("CREATE TABLE "))
        .filter_map(|line| line.split_whitespace().next())
        .collect::<BTreeSet<_>>();
    assert_eq!(actual, expected);
    assert_eq!(SCHEMA.matches("schema_version = 1").count(), 1);
    assert!(!SCHEMA.contains("ALTER TABLE"));
}

#[test]
fn mailbox_and_push_outbox_share_one_transactional_identity() {
    assert!(SCHEMA.contains("FOREIGN KEY (message_id, recipient_user_id, recipient_device_id)"));
    assert!(SCHEMA.contains("PRIMARY KEY (message_id, recipient_user_id, recipient_device_id)"));
    assert!(SCHEMA.contains("expires_at_millis"));
    assert!(SCHEMA.contains("uploaded BOOLEAN NOT NULL DEFAULT FALSE"));
}

#[test]
fn cleanup_uses_fixed_batch_limits() {
    let store = include_str!("../src/storage/postgres.rs");
    assert!(store.contains("LIMIT 500"));
    assert!(store.matches("LIMIT 100").count() >= 3);
}
