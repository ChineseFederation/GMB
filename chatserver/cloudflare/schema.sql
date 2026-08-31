PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

CREATE TABLE chatserver_schema (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    version INTEGER NOT NULL CHECK (version = 1)
);

INSERT INTO chatserver_schema (singleton, version) VALUES (1, 1);

-- 每个设备只保存当前有效的 RFC 9420 Last Resort KeyPackage。
CREATE TABLE key_packages (
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    key_package_ref TEXT NOT NULL,
    payload TEXT NOT NULL,
    not_after INTEGER NOT NULL,
    PRIMARY KEY (user_id, device_id)
);

CREATE INDEX key_packages_resolve_idx
    ON key_packages (user_id, not_after, device_id);

CREATE TABLE messages (
    message_id TEXT NOT NULL,
    recipient_user_id TEXT NOT NULL,
    recipient_device_id TEXT NOT NULL,
    payload TEXT NOT NULL,
    accepted_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    PRIMARY KEY (message_id, recipient_user_id, recipient_device_id)
);

CREATE INDEX messages_mailbox_idx
    ON messages (recipient_user_id, recipient_device_id, expires_at, accepted_at);
CREATE INDEX messages_expiry_idx ON messages (expires_at);

CREATE TABLE attachments (
    attachment_id TEXT PRIMARY KEY,
    sender_user_id TEXT NOT NULL,
    payload TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('pending', 'ready', 'deleting')),
    accepted_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
);

CREATE INDEX attachments_cleanup_idx ON attachments (state, expires_at);

CREATE TABLE attachment_chunks (
    attachment_id TEXT NOT NULL REFERENCES attachments (attachment_id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    cipher_byte_size INTEGER NOT NULL,
    cipher_sha256 TEXT NOT NULL,
    uploaded INTEGER NOT NULL DEFAULT 0 CHECK (uploaded IN (0, 1)),
    PRIMARY KEY (attachment_id, chunk_index)
);

CREATE TABLE attachment_recipients (
    attachment_id TEXT NOT NULL REFERENCES attachments (attachment_id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    PRIMARY KEY (attachment_id, user_id)
);

CREATE INDEX attachment_recipients_user_idx
    ON attachment_recipients (user_id, attachment_id);

CREATE TABLE attachment_receipts (
    attachment_id TEXT NOT NULL REFERENCES attachments (attachment_id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    acknowledged_at INTEGER NOT NULL,
    PRIMARY KEY (attachment_id, user_id, device_id)
);

CREATE TABLE push_endpoints (
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    token TEXT NOT NULL,
    app_id TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, device_id, platform, app_id)
);

CREATE TABLE push_outbox (
    message_id TEXT NOT NULL,
    recipient_user_id TEXT NOT NULL,
    recipient_device_id TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('pending', 'leased')),
    attempts INTEGER NOT NULL DEFAULT 0,
    available_at INTEGER NOT NULL,
    lease_until INTEGER,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (message_id, recipient_user_id, recipient_device_id),
    FOREIGN KEY (message_id, recipient_user_id, recipient_device_id)
        REFERENCES messages (message_id, recipient_user_id, recipient_device_id)
        ON DELETE CASCADE
);

CREATE INDEX push_outbox_claim_idx
    ON push_outbox (state, available_at, lease_until, created_at);

COMMIT;
