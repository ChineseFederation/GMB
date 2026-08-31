use std::{
    io,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use axum::body::Bytes;
use futures_util::{Stream, StreamExt};
use sha2::{Digest, Sha256};
use thiserror::Error;
use tokio::{
    fs::{self, File, OpenOptions},
    io::AsyncWriteExt,
};

#[derive(Debug, Error)]
pub enum ObjectError {
    #[error("附件标识无效")]
    InvalidIdentifier,
    #[error("附件密文字节超过限制")]
    TooLarge,
    #[error("附件密文字节大小或摘要不一致")]
    IntegrityMismatch,
    #[error("附件对象已经存在")]
    AlreadyExists,
    #[error("附件对象不存在")]
    NotFound,
    #[error("附件对象流读取失败: {0}")]
    Stream(String),
    #[error("附件对象存储失败: {0}")]
    Io(#[from] io::Error),
}

/// 同一私有目录内的密文对象存储，使用硬链接完成不覆盖的原子公开。
#[derive(Debug, Clone)]
pub struct ObjectStore {
    root: PathBuf,
}

impl ObjectStore {
    pub async fn open(root: PathBuf) -> Result<Self, ObjectError> {
        fs::create_dir_all(&root).await?;
        fs::set_permissions(&root, std::fs::Permissions::from_mode(0o700)).await?;
        let canonical = fs::canonicalize(&root).await?;
        Ok(Self { root: canonical })
    }

    pub async fn put_stream<S, E>(
        &self,
        attachment_id: &str,
        chunk_index: u32,
        expected_bytes: u64,
        expected_sha256: &str,
        max_bytes: u64,
        mut stream: S,
    ) -> Result<(), ObjectError>
    where
        S: Stream<Item = Result<Bytes, E>> + Unpin,
        E: std::fmt::Display,
    {
        validate_identifier(attachment_id)?;
        if expected_bytes == 0 || expected_bytes > max_bytes {
            return Err(ObjectError::TooLarge);
        }

        let final_path = self.path_for(attachment_id, chunk_index)?;
        if fs::symlink_metadata(&final_path).await.is_ok() {
            return Err(ObjectError::AlreadyExists);
        }
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let temporary_path = self.root.join(format!(
            ".{attachment_id}.{chunk_index}.{}.{}.tmp",
            std::process::id(),
            nonce
        ));
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temporary_path)
            .await?;
        let result = async {
            let mut digest = Sha256::new();
            let mut written = 0_u64;
            while let Some(chunk) = stream.next().await {
                let chunk = chunk.map_err(|error| ObjectError::Stream(error.to_string()))?;
                written = written
                    .checked_add(chunk.len() as u64)
                    .ok_or(ObjectError::TooLarge)?;
                if written > expected_bytes || written > max_bytes {
                    return Err(ObjectError::TooLarge);
                }
                digest.update(&chunk);
                file.write_all(&chunk).await?;
            }
            file.flush().await?;
            file.sync_all().await?;
            let actual_sha256 = format!("{:x}", digest.finalize());
            if written != expected_bytes || !actual_sha256.eq_ignore_ascii_case(expected_sha256) {
                return Err(ObjectError::IntegrityMismatch);
            }
            drop(file);

            // hard_link 在目标已存在时失败，不会覆盖另一请求已公开的对象。
            fs::hard_link(&temporary_path, &final_path)
                .await
                .map_err(|error| {
                    if error.kind() == io::ErrorKind::AlreadyExists {
                        ObjectError::AlreadyExists
                    } else {
                        ObjectError::Io(error)
                    }
                })?;
            fs::remove_file(&temporary_path).await?;
            sync_directory(&self.root).await?;
            Ok(())
        }
        .await;
        if result.is_err() {
            let _ = fs::remove_file(&temporary_path).await;
        }
        result
    }

    pub async fn open_file(
        &self,
        attachment_id: &str,
        chunk_index: u32,
    ) -> Result<(File, u64), ObjectError> {
        let path = self.path_for(attachment_id, chunk_index)?;
        let file = File::open(&path).await.map_err(|error| {
            if error.kind() == io::ErrorKind::NotFound {
                ObjectError::NotFound
            } else {
                ObjectError::Io(error)
            }
        })?;
        let size = file.metadata().await?.len();
        Ok((file, size))
    }

    pub async fn remove_chunk(
        &self,
        attachment_id: &str,
        chunk_index: u32,
    ) -> Result<(), ObjectError> {
        let path = self.path_for(attachment_id, chunk_index)?;
        match fs::remove_file(path).await {
            Ok(()) => {
                sync_directory(&self.root).await?;
                Ok(())
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
            Err(error) => Err(ObjectError::Io(error)),
        }
    }

    pub async fn remove(&self, attachment_id: &str) -> Result<(), ObjectError> {
        validate_identifier(attachment_id)?;
        let prefix = format!("{attachment_id}.");
        let mut entries = fs::read_dir(&self.root).await?;
        while let Some(entry) = entries.next_entry().await? {
            if entry.file_name().to_string_lossy().starts_with(&prefix) {
                fs::remove_file(entry.path()).await?;
            }
        }
        sync_directory(&self.root).await
    }

    fn path_for(&self, attachment_id: &str, chunk_index: u32) -> Result<PathBuf, ObjectError> {
        validate_identifier(attachment_id)?;
        Ok(self.root.join(format!("{attachment_id}.{chunk_index}")))
    }
}

fn validate_identifier(value: &str) -> Result<(), ObjectError> {
    if value.is_empty()
        || value.len() > 128
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
    {
        return Err(ObjectError::InvalidIdentifier);
    }
    Ok(())
}

async fn sync_directory(path: &Path) -> Result<(), ObjectError> {
    let directory = File::open(path).await?;
    directory.sync_all().await?;
    Ok(())
}
