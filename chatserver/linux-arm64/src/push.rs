use std::{
    collections::BTreeSet,
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};

use chatserver_core::{PushEndpoint, PushPlatform};
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use serde_json::json;
use thiserror::Error;
use tokio::sync::Mutex;

use crate::{
    config::{ApnsConfig, FcmConfig, PushConfig},
    BoxError,
};

#[derive(Debug, Error)]
pub enum PushError {
    #[error("目标推送平台尚未配置")]
    ProviderUnavailable,
    #[error("推送端点的应用标识不受允许")]
    TopicForbidden,
    #[error("推送凭据或响应无效: {0}")]
    InvalidCredential(String),
    #[error("推送网络请求失败: {0}")]
    Request(#[from] reqwest::Error),
    #[error("推送签名失败: {0}")]
    Jwt(#[from] jsonwebtoken::errors::Error),
}

#[derive(Clone)]
pub struct PushDispatcher {
    apns: Option<Arc<ApnsClient>>,
    fcm: Option<Arc<FcmClient>>,
}

impl PushDispatcher {
    pub async fn load(config: &PushConfig) -> Result<Self, BoxError> {
        let client = reqwest::Client::builder().https_only(true).build()?;
        let apns = match &config.apns {
            Some(config) => Some(Arc::new(ApnsClient::load(client.clone(), config).await?)),
            None => None,
        };
        let fcm = match &config.fcm {
            Some(config) => Some(Arc::new(FcmClient::load(client, config).await?)),
            None => None,
        };
        Ok(Self { apns, fcm })
    }

    pub async fn dispatch(&self, endpoint: &PushEndpoint) -> Result<(), PushError> {
        match endpoint.platform {
            PushPlatform::Ios => {
                self.apns
                    .as_ref()
                    .ok_or(PushError::ProviderUnavailable)?
                    .wake(endpoint)
                    .await
            }
            PushPlatform::Android => {
                self.fcm
                    .as_ref()
                    .ok_or(PushError::ProviderUnavailable)?
                    .wake(endpoint)
                    .await
            }
        }
    }
}

struct ApnsClient {
    client: reqwest::Client,
    team_id: String,
    key_id: String,
    key: EncodingKey,
    allowed_topics: BTreeSet<String>,
    endpoint: &'static str,
    token: Mutex<Option<CachedToken>>,
}

impl ApnsClient {
    async fn load(client: reqwest::Client, config: &ApnsConfig) -> Result<Self, BoxError> {
        let pem = tokio::fs::read(&config.private_key).await?;
        let key = EncodingKey::from_ec_pem(&pem)?;
        Ok(Self {
            client,
            team_id: config.team_id.clone(),
            key_id: config.key_id.clone(),
            key,
            allowed_topics: config.allowed_topics.iter().cloned().collect(),
            endpoint: if config.sandbox {
                "https://api.sandbox.push.apple.com"
            } else {
                "https://api.push.apple.com"
            },
            token: Mutex::new(None),
        })
    }

    async fn wake(&self, endpoint: &PushEndpoint) -> Result<(), PushError> {
        if !self.allowed_topics.contains(&endpoint.app_id) {
            return Err(PushError::TopicForbidden);
        }
        let bearer = self.bearer().await?;
        let mut url = reqwest::Url::parse(&format!("{}/3/device", self.endpoint))
            .map_err(|error| PushError::InvalidCredential(error.to_string()))?;
        url.path_segments_mut()
            .map_err(|_| PushError::InvalidCredential("APNs URL 不能追加路径".to_owned()))?
            .push(&endpoint.token);
        let response = self
            .client
            .post(url)
            .bearer_auth(bearer)
            .header("apns-topic", &endpoint.app_id)
            .header("apns-push-type", "alert")
            .header("apns-priority", "10")
            .json(&json!({
                "aps": {
                    "alert": {"title": "Chat", "body": "New message"},
                    "sound": "default",
                    "content-available": 1
                },
                "event": "chat_wake"
            }))
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(PushError::InvalidCredential(format!(
                "APNs status {}",
                response.status()
            )));
        }
        Ok(())
    }

    async fn bearer(&self) -> Result<String, PushError> {
        let now = now_seconds();
        let mut cached = self.token.lock().await;
        if let Some(token) = cached.as_ref().filter(|token| token.expires_at > now + 60) {
            return Ok(token.value.clone());
        }
        let mut header = Header::new(Algorithm::ES256);
        header.kid = Some(self.key_id.clone());
        let value = encode(
            &header,
            &ApnsClaims {
                iss: &self.team_id,
                iat: now,
            },
            &self.key,
        )?;
        *cached = Some(CachedToken {
            value: value.clone(),
            expires_at: now + 3_000,
        });
        Ok(value)
    }
}

#[derive(Serialize)]
struct ApnsClaims<'a> {
    iss: &'a str,
    iat: u64,
}

struct FcmClient {
    client: reqwest::Client,
    account: FcmServiceAccount,
    key: EncodingKey,
    token: Mutex<Option<CachedToken>>,
}

impl FcmClient {
    async fn load(client: reqwest::Client, config: &FcmConfig) -> Result<Self, BoxError> {
        let source = tokio::fs::read(&config.service_account).await?;
        let account: FcmServiceAccount = serde_json::from_slice(&source)?;
        let token_url = reqwest::Url::parse(&account.token_uri)?;
        if token_url.scheme() != "https" {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "FCM token_uri 必须使用 HTTPS",
            )
            .into());
        }
        let key = EncodingKey::from_rsa_pem(account.private_key.as_bytes())?;
        Ok(Self {
            client,
            account,
            key,
            token: Mutex::new(None),
        })
    }

    async fn wake(&self, endpoint: &PushEndpoint) -> Result<(), PushError> {
        let bearer = self.bearer().await?;
        let url = format!(
            concat!(
                "https://fcm.googleapis.com/",
                "v1",
                "/projects/{}/messages:send"
            ),
            self.account.project_id
        );
        let response = self
            .client
            .post(url)
            .bearer_auth(bearer)
            .json(&json!({
                "message": {
                    "token": endpoint.token,
                    "data": {"event": "chat_wake"},
                    "notification": {"title": "Chat", "body": "New message"},
                    "android": {"priority": "HIGH"}
                }
            }))
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(PushError::InvalidCredential(format!(
                "FCM status {}",
                response.status()
            )));
        }
        Ok(())
    }

    async fn bearer(&self) -> Result<String, PushError> {
        let now = now_seconds();
        let mut cached = self.token.lock().await;
        if let Some(token) = cached.as_ref().filter(|token| token.expires_at > now + 60) {
            return Ok(token.value.clone());
        }
        let mut header = Header::new(Algorithm::RS256);
        header.kid = self.account.private_key_id.clone();
        let assertion = encode(
            &header,
            &FcmClaims {
                iss: &self.account.client_email,
                scope: "https://www.googleapis.com/auth/firebase.messaging",
                aud: &self.account.token_uri,
                iat: now,
                exp: now + 3_600,
            },
            &self.key,
        )?;
        let response = self
            .client
            .post(&self.account.token_uri)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
                ("assertion", assertion.as_str()),
            ])
            .send()
            .await?
            .error_for_status()?;
        let token: OAuthToken = response.json().await?;
        if token.access_token.is_empty() || token.expires_in == 0 {
            return Err(PushError::InvalidCredential(
                "FCM OAuth token 为空".to_owned(),
            ));
        }
        let value = token.access_token;
        *cached = Some(CachedToken {
            value: value.clone(),
            expires_at: now + token.expires_in,
        });
        Ok(value)
    }
}

#[derive(Debug, Deserialize)]
struct FcmServiceAccount {
    project_id: String,
    private_key_id: Option<String>,
    private_key: String,
    client_email: String,
    token_uri: String,
}

#[derive(Serialize)]
struct FcmClaims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    iat: u64,
    exp: u64,
}

#[derive(Debug, Deserialize)]
struct OAuthToken {
    access_token: String,
    expires_in: u64,
}

struct CachedToken {
    value: String,
    expires_at: u64,
}

fn now_seconds() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
