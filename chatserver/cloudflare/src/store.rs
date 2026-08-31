use chatserver_core::{
    AuthenticatedDevice, EncryptedAttachment, EncryptedDeliveryRecord, PublishedKeyPackage,
    PushEndpoint, PushPlatform,
};
use serde::Deserialize;
use wasm_bindgen::JsValue;
use worker::{D1Database, Env, Error, Result};

const DATABASE_BINDING: &str = "CHAT_DB";
const SCHEMA_VERSION: u32 = 1;

pub struct CloudflareStore {
    db: D1Database,
}

#[derive(Debug)]
pub struct StoredAttachment {
    pub attachment: EncryptedAttachment,
    pub state: String,
}

#[derive(Debug, Deserialize)]
pub struct PushJob {
    pub message_id: String,
    pub recipient_user_id: String,
    pub recipient_device_id: String,
    pub attempts: u32,
}

#[derive(Debug, Deserialize)]
struct PayloadRow {
    payload: String,
}

#[derive(Debug, Deserialize)]
struct AttachmentRow {
    payload: String,
    state: String,
}

#[derive(Debug, Deserialize)]
struct StateRow {
    state: String,
}

#[derive(Debug, Deserialize)]
struct IdRow {
    attachment_id: String,
}

#[derive(Debug, Deserialize)]
struct CountRow {
    count: u32,
}

#[derive(Debug, Deserialize)]
struct VersionRow {
    version: u32,
}

impl CloudflareStore {
    pub fn from_env(env: &Env) -> Result<Self> {
        Ok(Self {
            db: env.d1(DATABASE_BINDING)?,
        })
    }

    pub async fn health(&self) -> Result<()> {
        let row = self
            .db
            .prepare("SELECT version FROM chatserver_schema WHERE singleton = 1")
            .first::<VersionRow>(None)
            .await?;
        if row.is_some_and(|value| value.version == SCHEMA_VERSION) {
            Ok(())
        } else {
            Err(rust_error("ChatServer D1 schema mismatch"))
        }
    }

    /// RFC 9420 Last Resort KeyPackage 按设备原子替换，不按解析次数消费。
    pub async fn put_key_package(&self, package: &PublishedKeyPackage) -> Result<()> {
        let payload = encode(package)?;
        self.db
            .prepare(
                "INSERT INTO key_packages                  (user_id, device_id, key_package_ref, payload, not_after)                  VALUES (?, ?, ?, ?, ?)                  ON CONFLICT (user_id, device_id) DO UPDATE SET                  key_package_ref = excluded.key_package_ref,                  payload = excluded.payload, not_after = excluded.not_after",
            )
            .bind(&[
                text(&package.user_id),
                text(&package.device_id),
                text(&package.key_package_ref),
                text(&payload),
                number(package.not_after),
            ])?
            .run()
            .await?;
        Ok(())
    }

    pub async fn list_key_packages(
        &self,
        user_id: &str,
        device_id: Option<&str>,
        now_millis: u64,
        limit: u32,
    ) -> Result<Vec<PublishedKeyPackage>> {
        let (sql, values) = if let Some(device_id) = device_id {
            (
                "SELECT payload FROM key_packages                  WHERE user_id = ? AND device_id = ? AND not_after > ?                  ORDER BY device_id ASC LIMIT ?",
                vec![
                    text(user_id),
                    text(device_id),
                    number(now_millis),
                    number(u64::from(limit)),
                ],
            )
        } else {
            (
                "SELECT payload FROM key_packages                  WHERE user_id = ? AND not_after > ?                  ORDER BY device_id ASC LIMIT ?",
                vec![text(user_id), number(now_millis), number(u64::from(limit))],
            )
        };
        decode_rows(self.db.prepare(sql).bind(&values)?.all().await?.results()?)
    }

    /// 一条逻辑消息的全部设备密文与推送任务在同一个 D1 批次内提交。
    pub async fn put_messages(&self, messages: &[EncryptedDeliveryRecord]) -> Result<()> {
        let payload = encode(messages)?;
        let insert_messages = self
            .db
            .prepare(
                "INSERT OR IGNORE INTO messages                  (message_id, recipient_user_id, recipient_device_id, payload, accepted_at, expires_at)                  SELECT json_extract(value, '$.message_id'),                         json_extract(value, '$.recipient_user_id'),                         json_extract(value, '$.recipient_device_id'), value,                         json_extract(value, '$.accepted_at_millis'),                         json_extract(value, '$.expires_at_millis')                  FROM json_each(?)",
            )
            .bind(&[text(&payload)])?;
        let insert_outbox = self
            .db
            .prepare(
                "INSERT OR IGNORE INTO push_outbox                  (message_id, recipient_user_id, recipient_device_id, state, attempts,                   available_at, lease_until, created_at)                  SELECT m.message_id, m.recipient_user_id, m.recipient_device_id,                         'pending', 0, m.accepted_at, NULL, m.accepted_at                  FROM messages m INNER JOIN json_each(?) source                    ON m.message_id = json_extract(source.value, '$.message_id')                   AND m.recipient_user_id = json_extract(source.value, '$.recipient_user_id')                   AND m.recipient_device_id = json_extract(source.value, '$.recipient_device_id')",
            )
            .bind(&[text(&payload)])?;
        self.db.batch(vec![insert_messages, insert_outbox]).await?;
        Ok(())
    }

    pub async fn list_messages(
        &self,
        recipient: &AuthenticatedDevice,
        now_millis: u64,
        limit: u32,
    ) -> Result<Vec<EncryptedDeliveryRecord>> {
        let rows = self
            .db
            .prepare(
                "SELECT payload FROM messages                  WHERE recipient_user_id = ? AND recipient_device_id = ? AND expires_at > ?                  ORDER BY accepted_at ASC, rowid ASC LIMIT ?",
            )
            .bind(&[
                text(&recipient.user_id),
                text(&recipient.device_id),
                number(now_millis),
                number(u64::from(limit)),
            ])?
            .all()
            .await?
            .results()?;
        decode_rows(rows)
    }

    pub async fn acknowledge_messages(
        &self,
        recipient: &AuthenticatedDevice,
        message_ids: &[String],
    ) -> Result<()> {
        let placeholders = vec!["?"; message_ids.len()].join(", ");
        let sql = format!(
            "DELETE FROM messages WHERE recipient_user_id = ? AND recipient_device_id = ?              AND message_id IN ({placeholders})"
        );
        let mut values = Vec::with_capacity(message_ids.len() + 2);
        values.push(text(&recipient.user_id));
        values.push(text(&recipient.device_id));
        values.extend(message_ids.iter().map(|value| text(value)));
        self.db.prepare(&sql).bind(&values)?.run().await?;
        Ok(())
    }

    pub async fn create_attachment(&self, attachment: &EncryptedAttachment) -> Result<()> {
        let payload = encode(attachment)?;
        let recipients = encode(&attachment.recipient_user_ids)?;
        let chunks = encode(&attachment.chunks)?;
        let insert_attachment = self
            .db
            .prepare(
                "INSERT INTO attachments                  (attachment_id, sender_user_id, payload, state, accepted_at, expires_at)                  VALUES (?, ?, ?, 'pending', ?, ?)",
            )
            .bind(&[
                text(&attachment.attachment_id),
                text(&attachment.sender_user_id),
                text(&payload),
                number(attachment.accepted_at_millis),
                number(attachment.expires_at_millis),
            ])?;
        let insert_recipients = self
            .db
            .prepare(
                "INSERT INTO attachment_recipients (attachment_id, user_id)                  SELECT ?, value FROM json_each(?)",
            )
            .bind(&[text(&attachment.attachment_id), text(&recipients)])?;
        let insert_chunks = self
            .db
            .prepare(
                "INSERT INTO attachment_chunks                  (attachment_id, chunk_index, cipher_byte_size, cipher_sha256, uploaded)                  SELECT ?, json_extract(value, '$.chunk_index'),                         json_extract(value, '$.cipher_byte_size'),                         json_extract(value, '$.cipher_sha256'), 0                  FROM json_each(?)",
            )
            .bind(&[text(&attachment.attachment_id), text(&chunks)])?;
        self.db
            .batch(vec![insert_attachment, insert_recipients, insert_chunks])
            .await?;
        Ok(())
    }

    pub async fn attachment_for_upload(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<Option<StoredAttachment>> {
        let row = self
            .db
            .prepare(
                "SELECT payload, state FROM attachments                  WHERE attachment_id = ? AND sender_user_id = ? AND expires_at > ?",
            )
            .bind(&[
                text(attachment_id),
                text(&actor.user_id),
                number(now_millis),
            ])?
            .first::<AttachmentRow>(None)
            .await?;
        decode_attachment(row)
    }

    pub async fn attachment_for_download(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<Option<StoredAttachment>> {
        let row = self
            .db
            .prepare(
                "SELECT a.payload, a.state FROM attachments a                  WHERE a.attachment_id = ? AND a.expires_at > ? AND (                    a.sender_user_id = ? OR EXISTS (                      SELECT 1 FROM attachment_recipients r                      WHERE r.attachment_id = a.attachment_id AND r.user_id = ?                    )                  )",
            )
            .bind(&[
                text(attachment_id),
                number(now_millis),
                text(&actor.user_id),
                text(&actor.user_id),
            ])?
            .first::<AttachmentRow>(None)
            .await?;
        decode_attachment(row)
    }

    pub async fn mark_attachment_chunk_uploaded(
        &self,
        attachment_id: &str,
        chunk_index: u32,
        cipher_byte_size: u64,
        cipher_sha256: &str,
    ) -> Result<bool> {
        self.db
            .prepare(
                "UPDATE attachment_chunks SET uploaded = 1                  WHERE attachment_id = ? AND chunk_index = ?                    AND cipher_byte_size = ? AND lower(cipher_sha256) = lower(?)                    AND EXISTS (SELECT 1 FROM attachments a                      WHERE a.attachment_id = attachment_chunks.attachment_id                        AND a.state = 'pending')",
            )
            .bind(&[
                text(attachment_id),
                number(u64::from(chunk_index)),
                number(cipher_byte_size),
                text(cipher_sha256),
            ])?
            .run()
            .await?;
        let row = self
            .db
            .prepare(
                "SELECT COUNT(*) AS count FROM attachment_chunks                  WHERE attachment_id = ? AND chunk_index = ? AND uploaded = 1",
            )
            .bind(&[
                text(attachment_id),
                number(u64::from(chunk_index)),
            ])?
            .first::<CountRow>(None)
            .await?;
        Ok(row.is_some_and(|value| value.count == 1))
    }

    pub async fn complete_attachment(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<bool> {
        self.db
            .prepare(
                "UPDATE attachments SET state = 'ready'                  WHERE attachment_id = ? AND sender_user_id = ?                    AND state = 'pending' AND expires_at > ?                    AND NOT EXISTS (SELECT 1 FROM attachment_chunks c                      WHERE c.attachment_id = attachments.attachment_id AND c.uploaded = 0)",
            )
            .bind(&[
                text(attachment_id),
                text(&actor.user_id),
                number(now_millis),
            ])?
            .run()
            .await?;
        Ok(self.attachment_state(attachment_id).await?.as_deref() == Some("ready"))
    }

    pub async fn acknowledge_attachment(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<Option<bool>> {
        let authorized = self
            .db
            .prepare(
                "SELECT COUNT(*) AS count FROM attachment_recipients                  WHERE attachment_id = ? AND user_id = ?",
            )
            .bind(&[text(attachment_id), text(&actor.user_id)])?
            .first::<CountRow>(None)
            .await?
            .is_some_and(|value| value.count == 1);
        if !authorized {
            return Ok(None);
        }
        let insert_receipt = self
            .db
            .prepare(
                "INSERT OR IGNORE INTO attachment_receipts                  (attachment_id, user_id, device_id, acknowledged_at) VALUES (?, ?, ?, ?)",
            )
            .bind(&[
                text(attachment_id),
                text(&actor.user_id),
                text(&actor.device_id),
                number(now_millis),
            ])?;
        let mark_deleting = self
            .db
            .prepare(
                "UPDATE attachments SET state = 'deleting'                  WHERE attachment_id = ? AND state = 'ready' AND NOT EXISTS (                    SELECT 1 FROM attachment_recipients r                    WHERE r.attachment_id = attachments.attachment_id AND NOT EXISTS (                      SELECT 1 FROM attachment_receipts q                      WHERE q.attachment_id = r.attachment_id AND q.user_id = r.user_id                    )                  )",
            )
            .bind(&[text(attachment_id)])?;
        self.db.batch(vec![insert_receipt, mark_deleting]).await?;
        Ok(Some(
            self.attachment_state(attachment_id).await?.as_deref() == Some("deleting"),
        ))
    }

    pub async fn abort_attachment(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
    ) -> Result<bool> {
        self.db
            .prepare(
                "UPDATE attachments SET state = 'deleting'                  WHERE attachment_id = ? AND sender_user_id = ? AND state != 'deleting'",
            )
            .bind(&[text(attachment_id), text(&actor.user_id)])?
            .run()
            .await?;
        Ok(self.attachment_state(attachment_id).await?.as_deref() == Some("deleting"))
    }

    /// 每次只标记固定数量，避免定时任务形成无界 D1 写入。
    pub async fn mark_expired_attachments(&self, now_millis: u64) -> Result<Vec<String>> {
        self.db
            .prepare(
                "UPDATE attachments SET state = 'deleting' WHERE rowid IN (                    SELECT rowid FROM attachments                    WHERE expires_at <= ? AND state != 'deleting'                    ORDER BY expires_at ASC LIMIT 100                  )",
            )
            .bind(&[number(now_millis)])?
            .run()
            .await?;
        let rows: Vec<IdRow> = self
            .db
            .prepare(
                "SELECT attachment_id FROM attachments                  WHERE state = 'deleting' ORDER BY expires_at ASC LIMIT 100",
            )
            .all()
            .await?
            .results()?;
        Ok(rows.into_iter().map(|row| row.attachment_id).collect())
    }

    pub async fn finalize_attachment(&self, attachment_id: &str) -> Result<()> {
        self.db
            .prepare("DELETE FROM attachments WHERE attachment_id = ? AND state = 'deleting'")
            .bind(&[text(attachment_id)])?
            .run()
            .await?;
        Ok(())
    }

    pub async fn cleanup_expired_metadata(&self, now_millis: u64) -> Result<()> {
        let messages = self
            .db
            .prepare(
                "DELETE FROM messages WHERE rowid IN (                    SELECT rowid FROM messages WHERE expires_at <= ?                    ORDER BY expires_at ASC LIMIT 500                  )",
            )
            .bind(&[number(now_millis)])?;
        let key_packages = self
            .db
            .prepare(
                "DELETE FROM key_packages WHERE rowid IN (                    SELECT rowid FROM key_packages WHERE not_after <= ?                    ORDER BY not_after ASC LIMIT 100                  )",
            )
            .bind(&[number(now_millis)])?;
        self.db.batch(vec![messages, key_packages]).await?;
        Ok(())
    }

    pub async fn put_push_endpoint(&self, endpoint: &PushEndpoint) -> Result<()> {
        self.db
            .prepare(
                "INSERT INTO push_endpoints                  (user_id, device_id, platform, token, app_id, updated_at)                  VALUES (?, ?, ?, ?, ?, ?)                  ON CONFLICT (user_id, device_id, platform, app_id) DO UPDATE SET                  token = excluded.token, updated_at = excluded.updated_at",
            )
            .bind(&[
                text(&endpoint.user_id),
                text(&endpoint.device_id),
                text(endpoint.platform.as_str()),
                text(&endpoint.token),
                text(&endpoint.app_id),
                number(endpoint.updated_at_millis),
            ])?
            .run()
            .await?;
        Ok(())
    }

    pub async fn remove_push_endpoint(
        &self,
        actor: &AuthenticatedDevice,
        platform: PushPlatform,
        app_id: &str,
    ) -> Result<()> {
        self.db
            .prepare(
                "DELETE FROM push_endpoints                  WHERE user_id = ? AND device_id = ? AND platform = ? AND app_id = ?",
            )
            .bind(&[
                text(&actor.user_id),
                text(&actor.device_id),
                text(platform.as_str()),
                text(app_id),
            ])?
            .run()
            .await?;
        Ok(())
    }

    pub async fn list_push_endpoints(
        &self,
        user_id: &str,
        device_id: &str,
    ) -> Result<Vec<PushEndpoint>> {
        #[derive(Deserialize)]
        struct Row {
            user_id: String,
            device_id: String,
            platform: String,
            token: String,
            app_id: String,
            updated_at: u64,
        }
        let rows: Vec<Row> = self
            .db
            .prepare(
                "SELECT user_id, device_id, platform, token, app_id, updated_at                  FROM push_endpoints WHERE user_id = ? AND device_id = ?",
            )
            .bind(&[text(user_id), text(device_id)])?
            .all()
            .await?
            .results()?;
        rows.into_iter()
            .map(|row| {
                Ok(PushEndpoint {
                    user_id: row.user_id,
                    device_id: row.device_id,
                    platform: PushPlatform::parse(&row.platform)
                        .map_err(|_| rust_error("invalid push platform in D1"))?,
                    token: row.token,
                    app_id: row.app_id,
                    updated_at_millis: row.updated_at,
                })
            })
            .collect()
    }

    pub async fn claim_push_jobs(&self, now_millis: u64, limit: u32) -> Result<Vec<PushJob>> {
        self.db
            .prepare(
                "UPDATE push_outbox SET state = 'leased', lease_until = ?, attempts = attempts + 1                  WHERE rowid IN (                    SELECT rowid FROM push_outbox                    WHERE attempts < 5 AND available_at <= ?                      AND (state = 'pending' OR (state = 'leased' AND lease_until <= ?))                    ORDER BY created_at ASC LIMIT ?                  )                  RETURNING message_id, recipient_user_id, recipient_device_id, attempts",
            )
            .bind(&[
                number(now_millis.saturating_add(60_000)),
                number(now_millis),
                number(now_millis),
                number(u64::from(limit)),
            ])?
            .all()
            .await?
            .results()
    }

    pub async fn complete_push_job(&self, job: &PushJob) -> Result<()> {
        self.db
            .prepare(
                "DELETE FROM push_outbox                  WHERE message_id = ? AND recipient_user_id = ? AND recipient_device_id = ?",
            )
            .bind(&[
                text(&job.message_id),
                text(&job.recipient_user_id),
                text(&job.recipient_device_id),
            ])?
            .run()
            .await?;
        Ok(())
    }

    pub async fn retry_push_job(&self, job: &PushJob, now_millis: u64) -> Result<()> {
        if job.attempts >= 5 {
            return self.complete_push_job(job).await;
        }
        let delay = 30_000_u64.saturating_mul(u64::from(job.attempts).max(1));
        self.db
            .prepare(
                "UPDATE push_outbox SET state = 'pending', available_at = ?, lease_until = NULL                  WHERE message_id = ? AND recipient_user_id = ? AND recipient_device_id = ?",
            )
            .bind(&[
                number(now_millis.saturating_add(delay)),
                text(&job.message_id),
                text(&job.recipient_user_id),
                text(&job.recipient_device_id),
            ])?
            .run()
            .await?;
        Ok(())
    }

    async fn attachment_state(&self, attachment_id: &str) -> Result<Option<String>> {
        Ok(self
            .db
            .prepare("SELECT state FROM attachments WHERE attachment_id = ?")
            .bind(&[text(attachment_id)])?
            .first::<StateRow>(None)
            .await?
            .map(|row| row.state))
    }
}

fn decode_attachment(row: Option<AttachmentRow>) -> Result<Option<StoredAttachment>> {
    row.map(|row| {
        let attachment: EncryptedAttachment = decode(&row.payload)?;
        attachment
            .validate_stored()
            .map_err(|_| rust_error("invalid attachment metadata in D1"))?;
        Ok(StoredAttachment {
            attachment,
            state: row.state,
        })
    })
    .transpose()
}

fn decode_rows<T: for<'de> Deserialize<'de>>(rows: Vec<PayloadRow>) -> Result<Vec<T>> {
    rows.into_iter().map(|row| decode(&row.payload)).collect()
}

fn encode<T: serde::Serialize + ?Sized>(value: &T) -> Result<String> {
    serde_json::to_string(value).map_err(|error| rust_error(error.to_string()))
}

fn decode<T: for<'de> Deserialize<'de>>(value: &str) -> Result<T> {
    serde_json::from_str(value).map_err(|error| rust_error(error.to_string()))
}

fn text(value: &str) -> JsValue {
    JsValue::from_str(value)
}

fn number(value: u64) -> JsValue {
    JsValue::from_f64(value as f64)
}

fn rust_error(message: impl Into<String>) -> Error {
    Error::RustError(message.into())
}
