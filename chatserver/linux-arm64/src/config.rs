use std::{net::SocketAddr, path::PathBuf};

use serde::Deserialize;
use thiserror::Error;

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub server: ServerConfig,
    pub database: DatabaseConfig,
    pub storage: StorageConfig,
    pub auth: AuthConfig,
    #[serde(default)]
    pub push: PushConfig,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ServerConfig {
    pub bind: SocketAddr,
    pub public_url: String,
    pub app_id: String,
    pub tls_certificate: PathBuf,
    pub tls_private_key: PathBuf,
    #[serde(default = "default_cleanup_interval_seconds")]
    pub cleanup_interval_seconds: u64,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DatabaseConfig {
    pub url: String,
    #[serde(default = "default_database_connections")]
    pub max_connections: u32,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StorageConfig {
    pub object_directory: PathBuf,
    pub max_attachment_bytes: u64,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AuthConfig {
    pub issuer: String,
    pub audience: String,
    pub ed25519_public_key: PathBuf,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PushConfig {
    pub apns: Option<ApnsConfig>,
    pub fcm: Option<FcmConfig>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ApnsConfig {
    pub team_id: String,
    pub key_id: String,
    pub private_key: PathBuf,
    pub allowed_topics: Vec<String>,
    #[serde(default)]
    pub sandbox: bool,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FcmConfig {
    pub service_account: PathBuf,
}

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("配置文件读取失败: {0}")]
    Io(#[from] std::io::Error),
    #[error("配置文件格式无效: {0}")]
    Toml(#[from] toml::de::Error),
    #[error("配置违反安全规则: {0}")]
    Invalid(&'static str),
}

impl Config {
    pub async fn load(path: &std::path::Path) -> Result<Self, ConfigError> {
        let source = tokio::fs::read_to_string(path).await?;
        Self::from_toml(&source)
    }

    pub fn from_toml(source: &str) -> Result<Self, ConfigError> {
        let config: Self = toml::from_str(source)?;
        config.validate()?;
        Ok(config)
    }

    pub fn validate(&self) -> Result<(), ConfigError> {
        let public_url = reqwest::Url::parse(&self.server.public_url)
            .map_err(|_| ConfigError::Invalid("public_url 必须是有效 HTTPS URL"))?;
        if public_url.scheme() != "https"
            || public_url.host_str().is_none()
            || !public_url.username().is_empty()
            || public_url.password().is_some()
            || public_url.query().is_some()
            || public_url.fragment().is_some()
        {
            return Err(ConfigError::Invalid(
                "public_url 只能是无凭据、无查询参数的 HTTPS 地址",
            ));
        }
        if self.server.bind.port() == 0
            || self.server.app_id.is_empty()
            || self.server.app_id.len() > 256
            || self
                .server
                .app_id
                .bytes()
                .any(|byte| byte.is_ascii_whitespace())
            || self.server.cleanup_interval_seconds == 0
            || self.server.tls_certificate.as_os_str().is_empty()
            || self.server.tls_private_key.as_os_str().is_empty()
        {
            return Err(ConfigError::Invalid("TLS 监听配置不完整"));
        }

        let database_url = reqwest::Url::parse(&self.database.url)
            .map_err(|_| ConfigError::Invalid("database.url 必须是有效 PostgreSQL URL"))?;
        if !matches!(database_url.scheme(), "postgres" | "postgresql")
            || self.database.max_connections == 0
        {
            return Err(ConfigError::Invalid("数据库只能使用 PostgreSQL"));
        }
        if self.storage.object_directory.as_os_str().is_empty()
            || self.storage.max_attachment_bytes == 0
        {
            return Err(ConfigError::Invalid("附件对象存储配置不完整"));
        }
        if self.auth.issuer.trim().is_empty()
            || self.auth.audience.trim().is_empty()
            || self.auth.ed25519_public_key.as_os_str().is_empty()
        {
            return Err(ConfigError::Invalid("EdDSA JWT 配置不完整"));
        }
        if let Some(apns) = &self.push.apns {
            if apns.team_id.trim().is_empty()
                || apns.key_id.trim().is_empty()
                || apns.private_key.as_os_str().is_empty()
                || apns.allowed_topics.is_empty()
                || apns
                    .allowed_topics
                    .iter()
                    .any(|topic| topic.trim().is_empty())
            {
                return Err(ConfigError::Invalid("APNs 配置不完整"));
            }
        }
        if let Some(fcm) = &self.push.fcm {
            if fcm.service_account.as_os_str().is_empty() {
                return Err(ConfigError::Invalid("FCM 配置不完整"));
            }
        }
        Ok(())
    }
}

const fn default_database_connections() -> u32 {
    16
}

const fn default_cleanup_interval_seconds() -> u64 {
    300
}
