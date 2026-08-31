use worker::{Bucket, Env, Error, FixedLengthStream, Headers, Request, Response, Result};

use crate::store::CloudflareStore;

const BUCKET_BINDING: &str = "CHAT_ATTACHMENTS";

#[derive(Clone)]
pub struct AttachmentObjects {
    bucket: Bucket,
}

impl AttachmentObjects {
    pub fn from_env(env: &Env) -> Result<Self> {
        Ok(Self {
            bucket: env.bucket(BUCKET_BINDING)?,
        })
    }

    /// Streams already-encrypted bytes into R2 and lets R2 verify the client SHA-256.
    pub async fn upload(
        &self,
        req: &mut Request,
        attachment_id: &str,
        chunk_index: u32,
        cipher_byte_size: u64,
        cipher_sha256: &str,
    ) -> Result<()> {
        let digest = decode_sha256(cipher_sha256)?;
        let stream = FixedLengthStream::wrap(req.stream()?, cipher_byte_size);
        self.bucket
            .put(object_key(attachment_id, chunk_index), stream)
            .sha256(digest)
            .execute()
            .await?;
        Ok(())
    }

    /// Hands the R2 body directly to the Workers runtime without buffering it in WASM.
    pub async fn download(
        &self,
        attachment_id: &str,
        chunk_index: u32,
        cipher_sha256: &str,
    ) -> Result<Option<Response>> {
        let Some(object) = self
            .bucket
            .get(object_key(attachment_id, chunk_index))
            .execute()
            .await?
        else {
            return Ok(None);
        };
        let Some(body) = object.body() else {
            return Ok(None);
        };
        let headers = Headers::new();
        headers.set("content-type", "application/octet-stream")?;
        headers.set("content-length", &object.size().to_string())?;
        headers.set("cache-control", "private, no-store")?;
        headers.set("x-chat-cipher-sha256", cipher_sha256)?;
        Ok(Some(
            Response::from_body(body.response_body()?)?.with_headers(headers),
        ))
    }

    pub async fn delete_chunk(&self, attachment_id: &str, chunk_index: u32) -> Result<()> {
        self.bucket
            .delete(object_key(attachment_id, chunk_index))
            .await
    }

    pub async fn delete(&self, attachment_id: &str) -> Result<()> {
        let prefix = object_prefix(attachment_id);
        let mut cursor = None;
        loop {
            let mut request = self.bucket.list().limit(1000).prefix(prefix.clone());
            if let Some(value) = cursor.take() {
                request = request.cursor(value);
            }
            let listed = request.execute().await?;
            let keys = listed
                .objects()
                .into_iter()
                .map(|object| object.key().to_owned())
                .collect::<Vec<_>>();
            if !keys.is_empty() {
                self.bucket.delete_multiple(keys).await?;
            }
            if !listed.truncated() {
                return Ok(());
            }
            cursor = listed.cursor();
        }
    }
}

/// Retries both completed acknowledgements and expired objects without deleting D1 first.
pub async fn cleanup(env: Env, now_millis: u64) -> Result<()> {
    let store = CloudflareStore::from_env(&env)?;
    let objects = AttachmentObjects::from_env(&env)?;
    for attachment_id in store.mark_expired_attachments(now_millis).await? {
        objects.delete(&attachment_id).await?;
        store.finalize_attachment(&attachment_id).await?;
    }
    store.cleanup_expired_metadata(now_millis).await
}

fn object_prefix(attachment_id: &str) -> String {
    format!("attachments/{attachment_id}/chunks/")
}

fn object_key(attachment_id: &str, chunk_index: u32) -> String {
    format!("{}{chunk_index}", object_prefix(attachment_id))
}

fn decode_sha256(value: &str) -> Result<Vec<u8>> {
    if value.len() != 64 {
        return Err(Error::RustError("invalid SHA-256".to_owned()));
    }
    value
        .as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            let high = hex_nibble(pair[0])
                .ok_or_else(|| Error::RustError("invalid SHA-256".to_owned()))?;
            let low = hex_nibble(pair[1])
                .ok_or_else(|| Error::RustError("invalid SHA-256".to_owned()))?;
            Ok((high << 4) | low)
        })
        .collect()
}

fn hex_nibble(value: u8) -> Option<u8> {
    match value {
        b'0'..=b'9' => Some(value - b'0'),
        b'a'..=b'f' => Some(value - b'a' + 10),
        b'A'..=b'F' => Some(value - b'A' + 10),
        _ => None,
    }
}
