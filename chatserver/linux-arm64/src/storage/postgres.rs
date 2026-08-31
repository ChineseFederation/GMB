use std::{collections::BTreeSet, io};

use chatserver_core::{
    AuthenticatedDevice, EncryptedAttachment, EncryptedDeliveryRecord, PublishedKeyPackage,
    PushEndpoint, PushPlatform,
};
use serde_json::Value;
use sqlx::{postgres::PgPoolOptions, PgPool, Row};
use thiserror::Error;

use crate::{config::DatabaseConfig, BoxError};

const EXPECTED_SCHEMA_VERSION: i32 = 1;
const EXPECTED_TABLES: [&str; 9] = [
    "attachment_chunks",
    "attachment_receipts",
    "attachment_recipients",
    "attachments",
    "chatserver_schema",
    "key_packages",
    "messages",
    "push_endpoints",
    "push_outbox",
];

#[derive(Debug, Error)]
pub enum StoreError {
    #[error("PostgreSQL 操作失败: {0}")]
    Database(#[from] sqlx::Error),
    #[error("数据库中的协议数据无效: {0}")]
    Json(#[from] serde_json::Error),
    #[error("数据库数值超出协议范围")]
    NumericRange,
    #[error("数据库结构不是当前唯一规范")]
    SchemaMismatch,
}

impl StoreError {
    pub fn is_conflict(&self) -> bool {
        matches!(self, Self::Database(sqlx::Error::Database(error)) if error.is_unique_violation())
    }
}

#[derive(Debug, Clone)]
pub struct PgStore {
    pool: PgPool,
}

#[derive(Debug, Clone)]
pub struct StoredAttachment {
    pub attachment: EncryptedAttachment,
    pub state: String,
}

#[derive(Debug, Clone)]
pub struct PushJob {
    pub message_id: String,
    pub recipient_user_id: String,
    pub recipient_device_id: String,
    pub attempts: i32,
}

impl PgStore {
    pub async fn connect(config: &DatabaseConfig) -> Result<Self, StoreError> {
        let pool = PgPoolOptions::new()
            .max_connections(config.max_connections)
            .connect(&config.url)
            .await?;
        Ok(Self { pool })
    }

    pub async fn initialize_empty(
        config: &DatabaseConfig,
        schema: &'static str,
    ) -> Result<(), BoxError> {
        let store = Self::connect(config).await?;
        let existing = store.public_tables().await?;
        if !existing.is_empty() {
            return Err(io::Error::new(
                io::ErrorKind::AlreadyExists,
                "ChatServer 只允许初始化完全空的 PostgreSQL 数据库",
            )
            .into());
        }
        sqlx::raw_sql(schema).execute(&store.pool).await?;
        store.verify_schema().await?;
        store.close().await;
        Ok(())
    }

    pub async fn purge_canonical(config: &DatabaseConfig) -> Result<(), BoxError> {
        let store = Self::connect(config).await?;
        store.verify_schema().await?;
        sqlx::raw_sql(
            "DROP TABLE push_outbox, push_endpoints, attachment_receipts,              attachment_recipients, attachment_chunks, attachments, messages, key_packages,              chatserver_schema CASCADE",
        )
        .execute(&store.pool)
        .await?;
        store.close().await;
        Ok(())
    }

    pub async fn verify_schema(&self) -> Result<(), StoreError> {
        let tables = self.public_tables().await?;
        let expected = EXPECTED_TABLES
            .into_iter()
            .map(str::to_owned)
            .collect::<BTreeSet<_>>();
        if tables != expected {
            return Err(StoreError::SchemaMismatch);
        }
        let version: i32 = sqlx::query_scalar(
            "SELECT schema_version FROM chatserver_schema WHERE singleton = TRUE",
        )
        .fetch_one(&self.pool)
        .await?;
        if version != EXPECTED_SCHEMA_VERSION {
            return Err(StoreError::SchemaMismatch);
        }
        Ok(())
    }

    pub async fn health(&self) -> Result<(), StoreError> {
        let value: i32 = sqlx::query_scalar("SELECT 1").fetch_one(&self.pool).await?;
        if value != 1 {
            return Err(StoreError::SchemaMismatch);
        }
        Ok(())
    }

    pub async fn close(&self) {
        self.pool.close().await;
    }

    /// RFC 9420 Last Resort KeyPackage 按设备原子替换，不按解析次数消费。
    pub async fn put_key_package(&self, package: &PublishedKeyPackage) -> Result<(), StoreError> {
        let payload = serde_json::to_value(package)?;
        sqlx::query(
            "INSERT INTO key_packages              (user_id, device_id, key_package_ref, not_after_millis, payload)              VALUES ($1, $2, $3, $4, $5)              ON CONFLICT (user_id, device_id) DO UPDATE SET              key_package_ref = EXCLUDED.key_package_ref,              not_after_millis = EXCLUDED.not_after_millis, payload = EXCLUDED.payload",
        )
        .bind(&package.user_id)
        .bind(&package.device_id)
        .bind(&package.key_package_ref)
        .bind(to_i64(package.not_after)?)
        .bind(payload)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn list_key_packages(
        &self,
        user_id: &str,
        device_id: Option<&str>,
        now_millis: u64,
        limit: u32,
    ) -> Result<Vec<PublishedKeyPackage>, StoreError> {
        let rows = if let Some(device_id) = device_id {
            sqlx::query(
                "SELECT payload FROM key_packages                  WHERE user_id = $1 AND device_id = $2 AND not_after_millis > $3                  ORDER BY device_id ASC LIMIT $4",
            )
            .bind(user_id)
            .bind(device_id)
            .bind(to_i64(now_millis)?)
            .bind(i64::from(limit))
            .fetch_all(&self.pool)
            .await?
        } else {
            sqlx::query(
                "SELECT payload FROM key_packages                  WHERE user_id = $1 AND not_after_millis > $2                  ORDER BY device_id ASC LIMIT $3",
            )
            .bind(user_id)
            .bind(to_i64(now_millis)?)
            .bind(i64::from(limit))
            .fetch_all(&self.pool)
            .await?
        };
        decode_payloads(rows)
    }

    pub async fn put_messages(
        &self,
        messages: &[EncryptedDeliveryRecord],
    ) -> Result<(), StoreError> {
        let mut transaction = self.pool.begin().await?;
        for message in messages {
            let payload = serde_json::to_value(message)?;
            sqlx::query(
                "INSERT INTO messages                  (message_id, recipient_user_id, recipient_device_id, accepted_at_millis,                   expires_at_millis, payload) VALUES ($1, $2, $3, $4, $5, $6)                  ON CONFLICT (message_id, recipient_user_id, recipient_device_id) DO NOTHING",
            )
            .bind(&message.message_id)
            .bind(&message.recipient_user_id)
            .bind(&message.recipient_device_id)
            .bind(to_i64(message.accepted_at_millis)?)
            .bind(to_i64(message.expires_at_millis)?)
            .bind(payload)
            .execute(&mut *transaction)
            .await?;
            sqlx::query(
                "INSERT INTO push_outbox                  (message_id, recipient_user_id, recipient_device_id, next_attempt_at)                  SELECT message_id, recipient_user_id, recipient_device_id, NOW()                  FROM messages WHERE message_id = $1 AND recipient_user_id = $2                    AND recipient_device_id = $3                  ON CONFLICT (message_id, recipient_user_id, recipient_device_id) DO NOTHING",
            )
            .bind(&message.message_id)
            .bind(&message.recipient_user_id)
            .bind(&message.recipient_device_id)
            .execute(&mut *transaction)
            .await?;
        }
        transaction.commit().await?;
        Ok(())
    }

    pub async fn list_messages(
        &self,
        recipient: &AuthenticatedDevice,
        now_millis: u64,
        limit: u32,
    ) -> Result<Vec<EncryptedDeliveryRecord>, StoreError> {
        let rows = sqlx::query(
            "SELECT payload FROM messages              WHERE recipient_user_id = $1 AND recipient_device_id = $2              AND expires_at_millis > $3              ORDER BY accepted_at_millis ASC, message_id ASC LIMIT $4",
        )
        .bind(&recipient.user_id)
        .bind(&recipient.device_id)
        .bind(to_i64(now_millis)?)
        .bind(i64::from(limit))
        .fetch_all(&self.pool)
        .await?;
        decode_payloads(rows)
    }

    pub async fn acknowledge_messages(
        &self,
        recipient: &AuthenticatedDevice,
        message_ids: &[String],
    ) -> Result<(), StoreError> {
        sqlx::query(
            "DELETE FROM messages WHERE recipient_user_id = $1              AND recipient_device_id = $2 AND message_id = ANY($3)",
        )
        .bind(&recipient.user_id)
        .bind(&recipient.device_id)
        .bind(message_ids)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn create_attachment(
        &self,
        attachment: &EncryptedAttachment,
    ) -> Result<(), StoreError> {
        let payload = serde_json::to_value(attachment)?;
        let mut transaction = self.pool.begin().await?;
        sqlx::query(
            "INSERT INTO attachments              (attachment_id, sender_user_id, accepted_at_millis, expires_at_millis, state, payload)              VALUES ($1, $2, $3, $4, 'pending', $5)",
        )
        .bind(&attachment.attachment_id)
        .bind(&attachment.sender_user_id)
        .bind(to_i64(attachment.accepted_at_millis)?)
        .bind(to_i64(attachment.expires_at_millis)?)
        .bind(payload)
        .execute(&mut *transaction)
        .await?;
        for recipient in &attachment.recipient_user_ids {
            sqlx::query(
                "INSERT INTO attachment_recipients (attachment_id, recipient_user_id)                  VALUES ($1, $2)",
            )
            .bind(&attachment.attachment_id)
            .bind(recipient)
            .execute(&mut *transaction)
            .await?;
        }
        for chunk in &attachment.chunks {
            sqlx::query(
                "INSERT INTO attachment_chunks                  (attachment_id, chunk_index, cipher_byte_size, cipher_sha256, uploaded)                  VALUES ($1, $2, $3, $4, FALSE)",
            )
            .bind(&attachment.attachment_id)
            .bind(i64::from(chunk.chunk_index))
            .bind(to_i64(chunk.cipher_byte_size)?)
            .bind(&chunk.cipher_sha256)
            .execute(&mut *transaction)
            .await?;
        }
        transaction.commit().await?;
        Ok(())
    }

    pub async fn attachment_for_upload(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<Option<StoredAttachment>, StoreError> {
        let row = sqlx::query(
            "SELECT payload, state FROM attachments              WHERE attachment_id = $1 AND sender_user_id = $2 AND expires_at_millis > $3",
        )
        .bind(attachment_id)
        .bind(&actor.user_id)
        .bind(to_i64(now_millis)?)
        .fetch_optional(&self.pool)
        .await?;
        decode_attachment(row)
    }

    pub async fn mark_attachment_chunk_uploaded(
        &self,
        attachment_id: &str,
        chunk_index: u32,
        cipher_byte_size: u64,
        cipher_sha256: &str,
    ) -> Result<bool, StoreError> {
        let result = sqlx::query(
            "UPDATE attachment_chunks c SET uploaded = TRUE              FROM attachments a WHERE c.attachment_id = $1 AND c.chunk_index = $2                AND c.cipher_byte_size = $3 AND lower(c.cipher_sha256) = lower($4)                AND a.attachment_id = c.attachment_id AND a.state = 'pending'",
        )
        .bind(attachment_id)
        .bind(i64::from(chunk_index))
        .bind(to_i64(cipher_byte_size)?)
        .bind(cipher_sha256)
        .execute(&self.pool)
        .await?;
        Ok(result.rows_affected() == 1)
    }

    pub async fn complete_attachment(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<bool, StoreError> {
        let result = sqlx::query(
            "UPDATE attachments SET state = 'ready'              WHERE attachment_id = $1 AND sender_user_id = $2 AND state = 'pending'                AND expires_at_millis > $3                AND NOT EXISTS (SELECT 1 FROM attachment_chunks c                  WHERE c.attachment_id = attachments.attachment_id AND c.uploaded = FALSE)",
        )
        .bind(attachment_id)
        .bind(&actor.user_id)
        .bind(to_i64(now_millis)?)
        .execute(&self.pool)
        .await?;
        Ok(result.rows_affected() == 1)
    }

    pub async fn attachment_for_download(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<Option<StoredAttachment>, StoreError> {
        let row = sqlx::query(
            "SELECT a.payload, a.state FROM attachments a              WHERE a.attachment_id = $1 AND a.expires_at_millis > $2 AND (                a.sender_user_id = $3 OR EXISTS (                  SELECT 1 FROM attachment_recipients r                  WHERE r.attachment_id = a.attachment_id AND r.recipient_user_id = $3                )              )",
        )
        .bind(attachment_id)
        .bind(to_i64(now_millis)?)
        .bind(&actor.user_id)
        .fetch_optional(&self.pool)
        .await?;
        decode_attachment(row)
    }

    pub async fn acknowledge_attachment(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
        now_millis: u64,
    ) -> Result<Option<bool>, StoreError> {
        let mut transaction = self.pool.begin().await?;
        let authorized: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM attachment_recipients              WHERE attachment_id = $1 AND recipient_user_id = $2)",
        )
        .bind(attachment_id)
        .bind(&actor.user_id)
        .fetch_one(&mut *transaction)
        .await?;
        if !authorized {
            transaction.rollback().await?;
            return Ok(None);
        }
        sqlx::query(
            "INSERT INTO attachment_receipts              (attachment_id, recipient_user_id, recipient_device_id, acknowledged_at_millis)              VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING",
        )
        .bind(attachment_id)
        .bind(&actor.user_id)
        .bind(&actor.device_id)
        .bind(to_i64(now_millis)?)
        .execute(&mut *transaction)
        .await?;
        let result = sqlx::query(
            "UPDATE attachments SET state = 'deleting'              WHERE attachment_id = $1 AND state = 'ready' AND NOT EXISTS (                SELECT 1 FROM attachment_recipients r                WHERE r.attachment_id = attachments.attachment_id AND NOT EXISTS (                  SELECT 1 FROM attachment_receipts x                  WHERE x.attachment_id = r.attachment_id                    AND x.recipient_user_id = r.recipient_user_id                )              )",
        )
        .bind(attachment_id)
        .execute(&mut *transaction)
        .await?;
        transaction.commit().await?;
        Ok(Some(result.rows_affected() == 1))
    }

    pub async fn abort_attachment(
        &self,
        actor: &AuthenticatedDevice,
        attachment_id: &str,
    ) -> Result<bool, StoreError> {
        let result = sqlx::query(
            "UPDATE attachments SET state = 'deleting'              WHERE attachment_id = $1 AND sender_user_id = $2 AND state != 'deleting'",
        )
        .bind(attachment_id)
        .bind(&actor.user_id)
        .execute(&self.pool)
        .await?;
        Ok(result.rows_affected() == 1)
    }

    pub async fn finalize_attachment(&self, attachment_id: &str) -> Result<(), StoreError> {
        sqlx::query("DELETE FROM attachments WHERE attachment_id = $1 AND state = 'deleting'")
            .bind(attachment_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn put_push_endpoint(&self, endpoint: &PushEndpoint) -> Result<(), StoreError> {
        let payload = serde_json::to_value(endpoint)?;
        sqlx::query(
            "INSERT INTO push_endpoints              (user_id, device_id, platform, app_id, payload, updated_at_millis)              VALUES ($1, $2, $3, $4, $5, $6)              ON CONFLICT (user_id, device_id, platform, app_id) DO UPDATE SET              payload = EXCLUDED.payload, updated_at_millis = EXCLUDED.updated_at_millis",
        )
        .bind(&endpoint.user_id)
        .bind(&endpoint.device_id)
        .bind(endpoint.platform.as_str())
        .bind(&endpoint.app_id)
        .bind(payload)
        .bind(to_i64(endpoint.updated_at_millis)?)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn remove_push_endpoint(
        &self,
        actor: &AuthenticatedDevice,
        platform: PushPlatform,
        app_id: &str,
    ) -> Result<(), StoreError> {
        sqlx::query(
            "DELETE FROM push_endpoints              WHERE user_id = $1 AND device_id = $2 AND platform = $3 AND app_id = $4",
        )
        .bind(&actor.user_id)
        .bind(&actor.device_id)
        .bind(platform.as_str())
        .bind(app_id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn list_push_endpoints(
        &self,
        user_id: &str,
        device_id: &str,
    ) -> Result<Vec<PushEndpoint>, StoreError> {
        let rows =
            sqlx::query("SELECT payload FROM push_endpoints WHERE user_id = $1 AND device_id = $2")
                .bind(user_id)
                .bind(device_id)
                .fetch_all(&self.pool)
                .await?;
        decode_payloads(rows)
    }

    pub async fn claim_push_jobs(&self, limit: u32) -> Result<Vec<PushJob>, StoreError> {
        let rows = sqlx::query(
            "WITH due AS (               SELECT message_id, recipient_user_id, recipient_device_id FROM push_outbox                WHERE next_attempt_at <= NOW() ORDER BY next_attempt_at ASC                FOR UPDATE SKIP LOCKED LIMIT $1             )              UPDATE push_outbox p SET attempts = p.attempts + 1,              next_attempt_at = NOW() + INTERVAL '60 seconds' FROM due              WHERE p.message_id = due.message_id                AND p.recipient_user_id = due.recipient_user_id                AND p.recipient_device_id = due.recipient_device_id              RETURNING p.message_id, p.recipient_user_id,              p.recipient_device_id, p.attempts",
        )
        .bind(i64::from(limit))
        .fetch_all(&self.pool)
        .await?;
        rows.into_iter()
            .map(|row| {
                Ok(PushJob {
                    message_id: row.try_get("message_id")?,
                    recipient_user_id: row.try_get("recipient_user_id")?,
                    recipient_device_id: row.try_get("recipient_device_id")?,
                    attempts: row.try_get("attempts")?,
                })
            })
            .collect()
    }

    pub async fn complete_push_job(&self, job: &PushJob) -> Result<(), StoreError> {
        sqlx::query(
            "DELETE FROM push_outbox              WHERE message_id = $1 AND recipient_user_id = $2 AND recipient_device_id = $3",
        )
        .bind(&job.message_id)
        .bind(&job.recipient_user_id)
        .bind(&job.recipient_device_id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn retry_push_job(&self, job: &PushJob) -> Result<(), StoreError> {
        let exponent = u32::try_from(job.attempts.clamp(1, 10)).unwrap_or(10);
        let seconds = (2_i64.pow(exponent)).min(1800);
        sqlx::query(
            "UPDATE push_outbox SET next_attempt_at = NOW() + make_interval(secs => $4)              WHERE message_id = $1 AND recipient_user_id = $2 AND recipient_device_id = $3",
        )
        .bind(&job.message_id)
        .bind(&job.recipient_user_id)
        .bind(&job.recipient_device_id)
        .bind(seconds as f64)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    /// 逻辑查询立即排除过期数据；物理清理每轮固定上限。
    pub async fn cleanup_expired(&self, now_millis: u64) -> Result<Vec<String>, StoreError> {
        let now = to_i64(now_millis)?;
        let mut transaction = self.pool.begin().await?;
        sqlx::query(
            "WITH expired AS (                SELECT attachment_id FROM attachments                WHERE expires_at_millis <= $1 AND state != 'deleting'                ORDER BY expires_at_millis ASC FOR UPDATE SKIP LOCKED LIMIT 100              ) UPDATE attachments a SET state = 'deleting' FROM expired              WHERE a.attachment_id = expired.attachment_id",
        )
        .bind(now)
        .execute(&mut *transaction)
        .await?;
        let rows = sqlx::query(
            "SELECT attachment_id FROM attachments              WHERE state = 'deleting' ORDER BY expires_at_millis ASC LIMIT 100",
        )
        .fetch_all(&mut *transaction)
        .await?;
        let attachment_ids = rows
            .into_iter()
            .map(|row| row.try_get("attachment_id"))
            .collect::<Result<Vec<String>, sqlx::Error>>()?;
        sqlx::query(
            "DELETE FROM messages WHERE ctid IN (                SELECT ctid FROM messages WHERE expires_at_millis <= $1                ORDER BY expires_at_millis ASC LIMIT 500              )",
        )
        .bind(now)
        .execute(&mut *transaction)
        .await?;
        sqlx::query(
            "DELETE FROM key_packages WHERE ctid IN (                SELECT ctid FROM key_packages WHERE not_after_millis <= $1                ORDER BY not_after_millis ASC LIMIT 100              )",
        )
        .bind(now)
        .execute(&mut *transaction)
        .await?;
        transaction.commit().await?;
        Ok(attachment_ids)
    }

    async fn public_tables(&self) -> Result<BTreeSet<String>, StoreError> {
        let rows = sqlx::query(
            "SELECT tablename FROM pg_catalog.pg_tables              WHERE schemaname = 'public' ORDER BY tablename",
        )
        .fetch_all(&self.pool)
        .await?;
        rows.into_iter()
            .map(|row| row.try_get("tablename").map_err(StoreError::from))
            .collect()
    }
}

fn decode_payloads<T>(rows: Vec<sqlx::postgres::PgRow>) -> Result<Vec<T>, StoreError>
where
    T: serde::de::DeserializeOwned,
{
    rows.into_iter()
        .map(|row| {
            let payload: Value = row.try_get("payload")?;
            Ok(serde_json::from_value(payload)?)
        })
        .collect()
}

fn decode_attachment(
    row: Option<sqlx::postgres::PgRow>,
) -> Result<Option<StoredAttachment>, StoreError> {
    row.map(|row| {
        let payload: Value = row.try_get("payload")?;
        let attachment: EncryptedAttachment = serde_json::from_value(payload)?;
        attachment
            .validate_stored()
            .map_err(|_| StoreError::SchemaMismatch)?;
        Ok(StoredAttachment {
            attachment,
            state: row.try_get("state")?,
        })
    })
    .transpose()
}

fn to_i64(value: u64) -> Result<i64, StoreError> {
    i64::try_from(value).map_err(|_| StoreError::NumericRange)
}
