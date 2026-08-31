const SCHEMA: &str = include_str!("../schema.sql");

#[test]
fn schema_is_one_canonical_empty_database_definition() {
    let expected = [
        "chatserver_schema",
        "key_packages",
        "messages",
        "attachments",
        "attachment_chunks",
        "attachment_recipients",
        "attachment_receipts",
        "push_endpoints",
        "push_outbox",
    ];
    assert_eq!(SCHEMA.matches("CREATE TABLE ").count(), expected.len());
    for table in expected {
        assert!(SCHEMA.contains(&format!("CREATE TABLE {table} (")));
    }
    assert!(SCHEMA.contains("BEGIN TRANSACTION;"));
    assert!(SCHEMA.contains("COMMIT;"));
    assert!(!SCHEMA.contains("ALTER TABLE"));
    assert!(!SCHEMA.contains("DROP TABLE"));
}

#[test]
fn message_and_push_records_share_a_foreign_key_boundary() {
    assert!(SCHEMA.contains("FOREIGN KEY (message_id, recipient_user_id, recipient_device_id)"));
    assert!(SCHEMA.contains("PRIMARY KEY (message_id, recipient_user_id, recipient_device_id)"));
    assert!(SCHEMA.contains("CREATE INDEX push_outbox_claim_idx"));
}

#[test]
fn attachment_lifecycle_cannot_delete_metadata_before_object_cleanup() {
    assert!(SCHEMA.contains("'pending', 'ready', 'deleting'"));
    assert!(SCHEMA.contains("attachment_receipts"));
    assert!(SCHEMA.contains("attachment_chunks"));
    assert!(SCHEMA.contains("uploaded INTEGER NOT NULL DEFAULT 0"));
    assert!(SCHEMA.contains("ON DELETE CASCADE"));
}

#[test]
fn scheduled_cleanup_is_bounded() {
    let store = include_str!("../src/store.rs");
    assert!(store.contains("LIMIT 500"));
    assert!(store.matches("LIMIT 100").count() >= 3);
}
