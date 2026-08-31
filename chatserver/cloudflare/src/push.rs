use chatserver_core::{PushEndpoint, PushPlatform};
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use serde_json::json;
use url::form_urlencoded;
use wasm_bindgen::JsValue;
use worker::{Env, Error, Fetch, Headers, Method, Request, RequestInit, Result};

use crate::store::CloudflareStore;

const APNS_PRIVATE_KEY_SECRET: &str = "CHAT_APNS_PRIVATE_KEY";
const APNS_TEAM_ID_VAR: &str = "CHAT_APNS_TEAM_ID";
const APNS_KEY_ID_VAR: &str = "CHAT_APNS_KEY_ID";
const APNS_ALLOWED_TOPICS_VAR: &str = "CHAT_APNS_ALLOWED_TOPICS";
const APNS_SANDBOX_VAR: &str = "CHAT_APNS_SANDBOX";
const FCM_SERVICE_ACCOUNT_SECRET: &str = "CHAT_FCM_SERVICE_ACCOUNT";
const FCM_TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const FCM_SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";

pub async fn drain(env: Env, now_millis: u64) -> Result<()> {
    let store = CloudflareStore::from_env(&env)?;
    let jobs = store.claim_push_jobs(now_millis, 32).await?;
    let mut dispatcher = PushDispatcher::new(env);
    for job in jobs {
        let endpoints = store
            .list_push_endpoints(&job.recipient_user_id, &job.recipient_device_id)
            .await?;
        let mut success = true;
        for endpoint in endpoints {
            if dispatcher.dispatch(&endpoint).await.is_err() {
                success = false;
            }
        }
        if success {
            store.complete_push_job(&job).await?;
        } else {
            store.retry_push_job(&job, now_millis).await?;
        }
    }
    Ok(())
}

struct PushDispatcher {
    env: Env,
    apns_token: Option<CachedToken>,
    fcm_token: Option<CachedToken>,
}

impl PushDispatcher {
    fn new(env: Env) -> Self {
        Self {
            env,
            apns_token: None,
            fcm_token: None,
        }
    }

    async fn dispatch(&mut self, endpoint: &PushEndpoint) -> Result<()> {
        match endpoint.platform {
            PushPlatform::Ios => self.dispatch_apns(endpoint).await,
            PushPlatform::Android => self.dispatch_fcm(endpoint).await,
        }
    }

    async fn dispatch_apns(&mut self, endpoint: &PushEndpoint) -> Result<()> {
        let team_id = required_var(&self.env, APNS_TEAM_ID_VAR)?;
        let key_id = required_var(&self.env, APNS_KEY_ID_VAR)?;
        let topics = required_var(&self.env, APNS_ALLOWED_TOPICS_VAR)?;
        if !topics
            .split(',')
            .map(str::trim)
            .any(|topic| topic == endpoint.app_id)
        {
            return Err(rust_error("APNs topic is not allowed"));
        }
        if !endpoint.token.bytes().all(|byte| byte.is_ascii_hexdigit()) {
            return Err(rust_error("invalid APNs device token"));
        }
        let now = now_seconds();
        let auth_token = if let Some(token) = &self.apns_token {
            if token.expires_at > now.saturating_add(60) {
                token.value.clone()
            } else {
                self.create_apns_token(&team_id, &key_id, now)?
            }
        } else {
            self.create_apns_token(&team_id, &key_id, now)?
        };
        self.apns_token = Some(CachedToken {
            value: auth_token.clone(),
            expires_at: now.saturating_add(3_000),
        });
        let sandbox = self
            .env
            .var(APNS_SANDBOX_VAR)
            .map(|value| value.to_string() == "true")
            .unwrap_or(false);
        let host = if sandbox {
            "api.sandbox.push.apple.com"
        } else {
            "api.push.apple.com"
        };
        let url = format!("https://{host}/3/device/{}", endpoint.token);
        let headers = Headers::new();
        headers.set("authorization", &format!("bearer {auth_token}"))?;
        headers.set("apns-topic", &endpoint.app_id)?;
        headers.set("apns-push-type", "alert")?;
        headers.set("apns-priority", "10")?;
        headers.set("content-type", "application/json")?;
        let body = json!({
            "aps": {
                "alert": {"title": "Chat", "body": "You have a new message."},
                "sound": "default"
            },
            "event": "chat_wake"
        })
        .to_string();
        let response = send_json(&url, headers, body).await?;
        if response == 200 {
            Ok(())
        } else {
            Err(rust_error(format!("APNs rejected wake-up: {response}")))
        }
    }

    fn create_apns_token(&self, team_id: &str, key_id: &str, now: u64) -> Result<String> {
        #[derive(Serialize)]
        struct Claims<'a> {
            iss: &'a str,
            iat: u64,
        }
        let private_key = self.env.secret(APNS_PRIVATE_KEY_SECRET)?.to_string();
        let mut header = Header::new(Algorithm::ES256);
        header.kid = Some(key_id.to_owned());
        encode(
            &header,
            &Claims {
                iss: team_id,
                iat: now,
            },
            &EncodingKey::from_ec_pem(private_key.as_bytes())
                .map_err(|error| rust_error(error.to_string()))?,
        )
        .map_err(|error| rust_error(error.to_string()))
    }

    async fn dispatch_fcm(&mut self, endpoint: &PushEndpoint) -> Result<()> {
        let account: FcmServiceAccount =
            serde_json::from_str(&self.env.secret(FCM_SERVICE_ACCOUNT_SECRET)?.to_string())
                .map_err(|error| rust_error(error.to_string()))?;
        if account.token_uri != FCM_TOKEN_URL {
            return Err(rust_error("FCM token URI is not official HTTPS endpoint"));
        }
        let now = now_seconds();
        let access_token = if let Some(token) = &self.fcm_token {
            if token.expires_at > now.saturating_add(60) {
                token.value.clone()
            } else {
                self.request_fcm_token(&account, now).await?
            }
        } else {
            self.request_fcm_token(&account, now).await?
        };
        let url = format!(
            concat!(
                "https://fcm.googleapis.com/",
                "v1",
                "/projects/{}/messages:send"
            ),
            account.project_id
        );
        let headers = Headers::new();
        headers.set("authorization", &format!("Bearer {access_token}"))?;
        headers.set("content-type", "application/json")?;
        let body = json!({
            "message": {
                "token": endpoint.token,
                "notification": {
                    "title": "Chat",
                    "body": "You have a new message."
                },
                "data": {"event": "chat_wake"},
                "android": {"priority": "high"}
            }
        })
        .to_string();
        let response = send_json(&url, headers, body).await?;
        if response == 200 {
            Ok(())
        } else {
            Err(rust_error(format!("FCM rejected wake-up: {response}")))
        }
    }

    async fn request_fcm_token(&mut self, account: &FcmServiceAccount, now: u64) -> Result<String> {
        #[derive(Serialize)]
        struct Claims<'a> {
            iss: &'a str,
            scope: &'a str,
            aud: &'a str,
            iat: u64,
            exp: u64,
        }
        let mut header = Header::new(Algorithm::RS256);
        header.kid = account.private_key_id.clone();
        let assertion = encode(
            &header,
            &Claims {
                iss: &account.client_email,
                scope: FCM_SCOPE,
                aud: FCM_TOKEN_URL,
                iat: now,
                exp: now.saturating_add(3_600),
            },
            &EncodingKey::from_rsa_pem(account.private_key.as_bytes())
                .map_err(|error| rust_error(error.to_string()))?,
        )
        .map_err(|error| rust_error(error.to_string()))?;
        let body = form_urlencoded::Serializer::new(String::new())
            .append_pair("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
            .append_pair("assertion", &assertion)
            .finish();
        let headers = Headers::new();
        headers.set("content-type", "application/x-www-form-urlencoded")?;
        let mut response = send(FCM_TOKEN_URL, headers, body).await?;
        if response.status_code() != 200 {
            return Err(rust_error(format!(
                "FCM OAuth rejected credentials: {}",
                response.status_code()
            )));
        }
        let token: OAuthToken = response.json().await?;
        if token.access_token.is_empty() || token.expires_in <= 60 {
            return Err(rust_error("FCM OAuth returned invalid token"));
        }
        self.fcm_token = Some(CachedToken {
            value: token.access_token.clone(),
            expires_at: now.saturating_add(token.expires_in),
        });
        Ok(token.access_token)
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

#[derive(Debug, Deserialize)]
struct OAuthToken {
    access_token: String,
    expires_in: u64,
}

struct CachedToken {
    value: String,
    expires_at: u64,
}

async fn send_json(url: &str, headers: Headers, body: String) -> Result<u16> {
    Ok(send(url, headers, body).await?.status_code())
}

async fn send(url: &str, headers: Headers, body: String) -> Result<worker::Response> {
    if !url.starts_with("https://") {
        return Err(rust_error("push endpoint must use HTTPS"));
    }
    let mut init = RequestInit::new();
    init.with_method(Method::Post)
        .with_headers(headers)
        .with_body(Some(JsValue::from_str(&body)));
    Fetch::Request(Request::new_with_init(url, &init)?)
        .send()
        .await
}

fn required_var(env: &Env, name: &str) -> Result<String> {
    let value = env.var(name)?.to_string();
    if value.trim().is_empty() {
        Err(rust_error(format!("missing {name}")))
    } else {
        Ok(value)
    }
}

fn now_seconds() -> u64 {
    (js_sys::Date::now() / 1_000.0) as u64
}

fn rust_error(message: impl Into<String>) -> Error {
    Error::RustError(message.into())
}
