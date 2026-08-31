use chatserver_core::{AuthenticatedAccess, AuthenticatedDevice, ChatServerError};
use serde::Serialize;
use serde_json::json;
use worker::{Context, Env, Method, Request, Response, Result};

use crate::{attachments::AttachmentObjects, auth, realtime, store::CloudflareStore};

pub const HEALTH_ROUTE: &str = "/health";
pub const REALTIME_ROUTE: &str = "/realtime";
pub const ATTACHMENT_CHUNK_ROUTE: &str = "/attachments/{attachment_id}/chunks/{chunk_index}";

pub async fn handle(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    match dispatch(req, env).await {
        Ok(response) => Ok(response),
        Err(failure) => failure.response(),
    }
}

async fn dispatch(mut req: Request, env: Env) -> ApiResult {
    let method = req.method();
    let path = req.path();
    if method == Method::Get && path == HEALTH_ROUTE {
        CloudflareStore::from_env(&env)
            .map_err(ApiFailure::storage)?
            .health()
            .await
            .map_err(ApiFailure::storage)?;
        return json_response(&json!({"status": "success"}), 200);
    }

    let access = auth::authenticate(&req, &env).map_err(ApiFailure)?;
    if method == Method::Get && path == REALTIME_ROUTE {
        return realtime::connect(req, &env, &access)
            .await
            .map_err(ApiFailure::storage);
    }

    let (attachment_id, chunk_index) =
        attachment_chunk(&path).ok_or(ApiFailure(ChatServerError::NotFound))?;
    let store = CloudflareStore::from_env(&env).map_err(ApiFailure::storage)?;
    match method {
        Method::Put => {
            upload_chunk(&mut req, &env, &store, &access, attachment_id, chunk_index).await
        }
        Method::Get => {
            download_chunk(&env, &store, &access.actor, attachment_id, chunk_index).await
        }
        _ => Err(ApiFailure(ChatServerError::NotFound)),
    }
}

async fn upload_chunk(
    req: &mut Request,
    env: &Env,
    store: &CloudflareStore,
    access: &AuthenticatedAccess,
    attachment_id: &str,
    chunk_index: u32,
) -> ApiResult {
    let stored = store
        .attachment_for_upload(&access.actor, attachment_id, now_millis())
        .await
        .map_err(ApiFailure::storage)?
        .ok_or(ApiFailure(ChatServerError::NotFound))?;
    if stored.state != "pending" {
        return Err(ApiFailure(ChatServerError::Conflict));
    }
    let expected = stored
        .attachment
        .expected_chunk(chunk_index)
        .ok_or_else(ApiFailure::invalid)?;
    let content_length = req
        .headers()
        .get("content-length")
        .map_err(|_| ApiFailure::invalid())?
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|value| {
            *value == expected.cipher_byte_size
                && access
                    .effective_max_attachment_bytes(max_attachment_bytes(env).unwrap_or(0))
                    .is_ok_and(|maximum| *value <= maximum)
        })
        .ok_or_else(ApiFailure::invalid)?;
    let cipher_sha256 = req
        .headers()
        .get("x-chat-cipher-sha256")
        .map_err(|_| ApiFailure::invalid())?
        .filter(|value| value.eq_ignore_ascii_case(&expected.cipher_sha256))
        .ok_or_else(ApiFailure::invalid)?;

    let objects = AttachmentObjects::from_env(env).map_err(ApiFailure::storage)?;
    objects
        .upload(
            req,
            attachment_id,
            chunk_index,
            content_length,
            &cipher_sha256,
        )
        .await
        .map_err(ApiFailure::storage)?;
    if !store
        .mark_attachment_chunk_uploaded(attachment_id, chunk_index, content_length, &cipher_sha256)
        .await
        .map_err(ApiFailure::storage)?
    {
        let _ = objects.delete_chunk(attachment_id, chunk_index).await;
        return Err(ApiFailure(ChatServerError::Conflict));
    }
    empty_response(204)
}

async fn download_chunk(
    env: &Env,
    store: &CloudflareStore,
    actor: &AuthenticatedDevice,
    attachment_id: &str,
    chunk_index: u32,
) -> ApiResult {
    let stored = store
        .attachment_for_download(actor, attachment_id, now_millis())
        .await
        .map_err(ApiFailure::storage)?
        .ok_or(ApiFailure(ChatServerError::NotFound))?;
    if stored.state != "ready" {
        return Err(ApiFailure(ChatServerError::Conflict));
    }
    let expected = stored
        .attachment
        .expected_chunk(chunk_index)
        .ok_or_else(ApiFailure::invalid)?;
    AttachmentObjects::from_env(env)
        .map_err(ApiFailure::storage)?
        .download(attachment_id, chunk_index, &expected.cipher_sha256)
        .await
        .map_err(ApiFailure::storage)?
        .ok_or(ApiFailure(ChatServerError::NotFound))
}

type ApiResult = std::result::Result<Response, ApiFailure>;

#[derive(Debug)]
struct ApiFailure(ChatServerError);

impl ApiFailure {
    fn invalid() -> Self {
        Self(ChatServerError::InvalidRequest)
    }

    fn storage(_error: worker::Error) -> Self {
        Self(ChatServerError::StorageUnavailable)
    }

    fn response(self) -> Result<Response> {
        let status = match self.0 {
            ChatServerError::InvalidRequest => 400,
            ChatServerError::Forbidden => 403,
            ChatServerError::NotFound => 404,
            ChatServerError::Conflict => 409,
            ChatServerError::ResourceLimit => 413,
            ChatServerError::StorageUnavailable => 503,
        };
        json_response(&json!({"error": self.0.code()}), status)
            .map_err(|_| worker::Error::RustError("failed to encode API error".to_owned()))
    }
}

fn json_response<T: Serialize>(value: &T, status: u16) -> ApiResult {
    Response::from_json(value)
        .map(|response| response.with_status(status))
        .map_err(ApiFailure::storage)
}

fn empty_response(status: u16) -> ApiResult {
    Response::empty()
        .map(|response| response.with_status(status))
        .map_err(ApiFailure::storage)
}

fn attachment_chunk(path: &str) -> Option<(&str, u32)> {
    let value = path.strip_prefix("/attachments/")?;
    let (attachment_id, chunk_index) = value.split_once("/chunks/")?;
    if !valid_attachment_id(attachment_id) || chunk_index.is_empty() {
        return None;
    }
    Some((attachment_id, chunk_index.parse::<u32>().ok()?))
}

fn valid_attachment_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.'))
}

pub fn max_attachment_bytes(env: &Env) -> std::result::Result<u64, ChatServerError> {
    env.var("CHAT_MAX_ATTACHMENT_BYTES")
        .map_err(|_| ChatServerError::ResourceLimit)?
        .to_string()
        .parse::<u64>()
        .ok()
        .filter(|value| *value > 0)
        .ok_or(ChatServerError::ResourceLimit)
}

pub fn app_id(env: &Env) -> std::result::Result<String, ChatServerError> {
    env.var("CHAT_APP_ID")
        .map_err(|_| ChatServerError::StorageUnavailable)
        .map(|value| value.to_string())
        .and_then(|value| {
            if value.is_empty()
                || value.len() > 256
                || value.bytes().any(|byte| byte.is_ascii_whitespace())
            {
                Err(ChatServerError::StorageUnavailable)
            } else {
                Ok(value)
            }
        })
}

pub fn now_millis() -> u64 {
    js_sys::Date::now() as u64
}
