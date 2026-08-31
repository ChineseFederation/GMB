BEGIN;

CREATE TABLE chatserver_schema (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    schema_version INTEGER NOT NULL CHECK (schema_version = 1)
);

INSERT INTO chatserver_schema (singleton, schema_version) VALUES (TRUE, 1);

-- 每个设备只保存当前有效的 RFC 9420 Last Resort KeyPackage。
CREATE TABLE key_packages (
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    key_package_ref TEXT NOT NULL,
    not_after_millis BIGINT NOT NULL CHECK (not_after_millis > 0),
    payload JSONB NOT NULL,
    PRIMARY KEY (user_id, device_id)
);

CREATE INDEX key_packages_resolve_idx
    ON key_packages (user_id, not_after_millis, device_id);

CREATE TABLE messages (
    message_id TEXT NOT NULL,
    recipient_user_id TEXT NOT NULL,
    recipient_device_id TEXT NOT NULL,
    accepted_at_millis BIGINT NOT NULL CHECK (accepted_at_millis > 0),
    expires_at_millis BIGINT NOT NULL CHECK (expires_at_millis > accepted_at_millis),
    payload JSONB NOT NULL,
    PRIMARY KEY (message_id, recipient_user_id, recipient_device_id)
);

CREATE INDEX messages_mailbox_idx
    ON messages (recipient_user_id, recipient_device_id, expires_at_millis, accepted_at_millis);
CREATE INDEX messages_expiry_idx ON messages (expires_at_millis);

CREATE TABLE attachments (
    attachment_id TEXT PRIMARY KEY,
    sender_user_id TEXT NOT NULL,
    accepted_at_millis BIGINT NOT NULL CHECK (accepted_at_millis > 0),
    expires_at_millis BIGINT NOT NULL CHECK (expires_at_millis > accepted_at_millis),
    state TEXT NOT NULL CHECK (state IN ('pending', 'ready', 'deleting')),
    payload JSONB NOT NULL
);

CREATE INDEX attachments_cleanup_idx ON attachments (state, expires_at_millis);

CREATE TABLE attachment_chunks (
    attachment_id TEXT NOT NULL REFERENCES attachments (attachment_id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL CHECK (chunk_index >= 0),
    cipher_byte_size BIGINT NOT NULL CHECK (cipher_byte_size > 0),
    cipher_sha256 TEXT NOT NULL,
    uploaded BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (attachment_id, chunk_index)
);

CREATE TABLE attachment_recipients (
    attachment_id TEXT NOT NULL REFERENCES attachments (attachment_id) ON DELETE CASCADE,
    recipient_user_id TEXT NOT NULL,
    PRIMARY KEY (attachment_id, recipient_user_id)
);

CREATE INDEX attachment_recipients_user_idx
    ON attachment_recipients (recipient_user_id, attachment_id);

CREATE TABLE attachment_receipts (
    attachment_id TEXT NOT NULL,
    recipient_user_id TEXT NOT NULL,
    recipient_device_id TEXT NOT NULL,
    acknowledged_at_millis BIGINT NOT NULL,
    PRIMARY KEY (attachment_id, recipient_user_id, recipient_device_id),
    FOREIGN KEY (attachment_id, recipient_user_id)
        REFERENCES attachment_recipients (attachment_id, recipient_user_id)
        ON DELETE CASCADE
);

CREATE TABLE push_endpoints (
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    app_id TEXT NOT NULL,
    payload JSONB NOT NULL,
    updated_at_millis BIGINT NOT NULL CHECK (updated_at_millis > 0),
    PRIMARY KEY (user_id, device_id, platform, app_id)
);

CREATE TABLE push_outbox (
    message_id TEXT NOT NULL,
    recipient_user_id TEXT NOT NULL,
    recipient_device_id TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    next_attempt_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, recipient_user_id, recipient_device_id),
    FOREIGN KEY (message_id, recipient_user_id, recipient_device_id)
        REFERENCES messages (message_id, recipient_user_id, recipient_device_id)
        ON DELETE CASCADE
);

CREATE INDEX push_outbox_due_idx ON push_outbox (next_attempt_at);

COMMIT;
