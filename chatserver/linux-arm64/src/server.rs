use std::{
    net::SocketAddr,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use axum::{
    body::{Body, Bytes},
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        DefaultBodyLimit, Path, State,
    },
    http::{
        header::{CACHE_CONTROL, CONTENT_LENGTH, CONTENT_TYPE},
        HeaderMap, StatusCode,
    },
    response::{IntoResponse, Response},
    routing::{get, put},
    Json, Router,
};
use axum_server::tls_rustls::RustlsConfig;
use chatserver_core::{
    attachment_ready_frame, key_package_batch_frame, message_batch_frame, parse_control_command,
    pong_frame, success_frame, AuthenticatedAccess, AuthenticatedDevice, ChatServerError,
    ControlCommand, ControlSessionLimits, PushEndpoint, RealtimeEvent,
};
use futures_util::{SinkExt, StreamExt};
use serde_json::json;
use tokio::time;
use tokio_util::io::ReaderStream;

use crate::{
    auth::Authenticator,
    config::Config,
    push::PushDispatcher,
    realtime::RealtimeHub,
    storage::{
        objects::{ObjectError, ObjectStore},
        postgres::{PgStore, StoreError},
    },
    BoxError,
};

pub const HEALTH_ROUTE: &str = "/health";
pub const REALTIME_ROUTE: &str = "/realtime";
pub const ATTACHMENT_CONTENT_ROUTE: &str = "/attachments/{attachment_id}/chunks/{chunk_index}";

#[derive(Clone)]
pub struct AppState {
    auth: Authenticator,
    store: PgStore,
    objects: ObjectStore,
    realtime: RealtimeHub,
    push: PushDispatcher,
    app_id: String,
    max_attachment_bytes: u64,
    cleanup_interval: Duration,
}

pub struct Server {
    state: AppState,
    bind: SocketAddr,
    tls: RustlsConfig,
}

impl Server {
    pub async fn build(config: Config) -> Result<Self, BoxError> {
        config.validate()?;
        let tls = RustlsConfig::from_pem_file(
            &config.server.tls_certificate,
            &config.server.tls_private_key,
        )
        .await?;
        let auth = Authenticator::load(&config.auth).await?;
        let store = PgStore::connect(&config.database).await?;
        store.verify_schema().await?;
        let objects = ObjectStore::open(config.storage.object_directory.clone()).await?;
        let push = PushDispatcher::load(&config.push).await?;
        let state = AppState {
            auth,
            store,
            objects,
            realtime: RealtimeHub::default(),
            push,
            app_id: config.server.app_id.clone(),
            max_attachment_bytes: config.storage.max_attachment_bytes,
            cleanup_interval: Duration::from_secs(config.server.cleanup_interval_seconds),
        };
        Ok(Self {
            state,
            bind: config.server.bind,
            tls,
        })
    }

    pub async fn run(self) -> Result<(), BoxError> {
        let push_state = self.state.clone();
        tokio::spawn(async move { push_worker(push_state).await });
        let cleanup_state = self.state.clone();
        tokio::spawn(async move { cleanup_worker(cleanup_state).await });
        axum_server::bind_rustls(self.bind, self.tls)
            .serve(router(self.state).into_make_service())
            .await?;
        Ok(())
    }
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route(HEALTH_ROUTE, get(health))
        .route(REALTIME_ROUTE, get(realtime))
        .route(
            ATTACHMENT_CONTENT_ROUTE,
            put(upload_attachment).get(download_attachment),
        )
        // 附件正文自行按声明长度流式限流，禁止框架先整体缓冲。
        .layer(DefaultBodyLimit::disable())
        .with_state(state)
}

#[derive(Debug)]
pub struct ApiError(ChatServerError);

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status = match &self.0 {
            ChatServerError::InvalidRequest => StatusCode::BAD_REQUEST,
            ChatServerError::Forbidden => StatusCode::FORBIDDEN,
            ChatServerError::NotFound => StatusCode::NOT_FOUND,
            ChatServerError::Conflict => StatusCode::CONFLICT,
            ChatServerError::ResourceLimit => StatusCode::PAYLOAD_TOO_LARGE,
            ChatServerError::StorageUnavailable => StatusCode::SERVICE_UNAVAILABLE,
        };
        (status, Json(json!({"error": self.0.code()}))).into_response()
    }
}

async fn health(State(state): State<AppState>) -> Result<Json<serde_json::Value>, ApiError> {
    state.store.health().await.map_err(map_store)?;
    Ok(Json(json!({"status": "success"})))
}

async fn upload_attachment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((attachment_id, chunk_index)): Path<(String, u32)>,
    body: Body,
) -> Result<StatusCode, ApiError> {
    let access = authenticate(&state, &headers)?;
    let actor = &access.actor;
    let stored = state
        .store
        .attachment_for_upload(&actor, &attachment_id, now_millis())
        .await
        .map_err(map_store)?
        .ok_or(ApiError(ChatServerError::NotFound))?;
    if stored.state != "pending" {
        return Err(ApiError(ChatServerError::Conflict));
    }
    let expected = stored
        .attachment
        .expected_chunk(chunk_index)
        .ok_or(ApiError(ChatServerError::InvalidRequest))?;
    let cipher_byte_size = headers
        .get(CONTENT_LENGTH)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|value| {
            *value == expected.cipher_byte_size
                && access
                    .effective_max_attachment_bytes(state.max_attachment_bytes)
                    .is_ok_and(|maximum| *value <= maximum)
        })
        .ok_or(ApiError(ChatServerError::InvalidRequest))?;
    let cipher_sha256 = headers
        .get("x-chat-cipher-sha256")
        .and_then(|value| value.to_str().ok())
        .filter(|value| value.eq_ignore_ascii_case(&expected.cipher_sha256))
        .ok_or(ApiError(ChatServerError::InvalidRequest))?;
    state
        .objects
        .put_stream(
            &attachment_id,
            chunk_index,
            cipher_byte_size,
            cipher_sha256,
            state.max_attachment_bytes,
            body.into_data_stream(),
        )
        .await
        .map_err(map_object)?;
    if !state
        .store
        .mark_attachment_chunk_uploaded(
            &attachment_id,
            chunk_index,
            cipher_byte_size,
            cipher_sha256,
        )
        .await
        .map_err(map_store)?
    {
        let _ = state
            .objects
            .remove_chunk(&attachment_id, chunk_index)
            .await;
        return Err(ApiError(ChatServerError::Conflict));
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn download_attachment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((attachment_id, chunk_index)): Path<(String, u32)>,
) -> Result<Response, ApiError> {
    let access = authenticate(&state, &headers)?;
    let actor = &access.actor;
    let stored = state
        .store
        .attachment_for_download(&actor, &attachment_id, now_millis())
        .await
        .map_err(map_store)?
        .ok_or(ApiError(ChatServerError::NotFound))?;
    if stored.state != "ready" {
        return Err(ApiError(ChatServerError::Conflict));
    }
    let expected = stored
        .attachment
        .expected_chunk(chunk_index)
        .ok_or(ApiError(ChatServerError::InvalidRequest))?;
    let (file, size) = state
        .objects
        .open_file(&attachment_id, chunk_index)
        .await
        .map_err(map_object)?;
    if size != expected.cipher_byte_size {
        return Err(ApiError(ChatServerError::StorageUnavailable));
    }
    Response::builder()
        .status(StatusCode::OK)
        .header(CONTENT_TYPE, "application/octet-stream")
        .header(CONTENT_LENGTH, size)
        .header(CACHE_CONTROL, "private, no-store")
        .header("x-chat-cipher-sha256", &expected.cipher_sha256)
        .body(Body::from_stream(ReaderStream::new(file)))
        .map_err(|_| ApiError(ChatServerError::StorageUnavailable))
}

async fn realtime(
    State(state): State<AppState>,
    headers: HeaderMap,
    upgrade: WebSocketUpgrade,
) -> Result<Response, ApiError> {
    let access = authenticate(&state, &headers)?;
    Ok(upgrade
        .protocols(["chatserver"])
        .on_upgrade(move |socket| realtime_session(state, access, socket))
        .into_response())
}

async fn realtime_session(state: AppState, access: AuthenticatedAccess, socket: WebSocket) {
    let actor = &access.actor;
    let mut events = state.realtime.subscribe(&actor).await;
    let (mut sender, mut receiver) = socket.split();
    if send_frame(&mut sender, chatserver_core::ready_frame(now_millis()))
        .await
        .is_err()
    {
        return;
    }

    let mut limits = ControlSessionLimits::default();
    let mut keepalive = time::interval(Duration::from_secs(30));
    keepalive.set_missed_tick_behavior(time::MissedTickBehavior::Delay);
    loop {
        tokio::select! {
            event = events.recv() => match event {
                Ok(event) => {
                    if sender.send(Message::Binary(event.as_bytes().to_vec().into())).await.is_err() {
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            },
            incoming = receiver.next() => match incoming {
                Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                Some(Ok(Message::Ping(payload))) => {
                    if sender.send(Message::Pong(payload)).await.is_err() {
                        break;
                    }
                }
                Some(Ok(Message::Binary(payload))) => {
                    let now = now_millis();
                    let response = match chatserver_core::decode_chat_frame(&payload)
                        .and_then(|frame| parse_control_command(
                            frame,
                            &actor,
                            now,
                            access
                                .effective_max_attachment_bytes(state.max_attachment_bytes)
                                .unwrap_or(0),
                            &mut limits,
                        ))
                    {
                        Ok(command) => execute_command(&state, &actor, command, now)
                            .await
                            .unwrap_or_else(|error| chatserver_core::failure_frame(error.code())),
                        Err(error) => chatserver_core::failure_frame(error.code()),
                    };
                    if send_frame(&mut sender, response).await.is_err() {
                        break;
                    }
                }
                Some(Ok(Message::Text(_))) => {
                    let _ = sender
                        .send(Message::Close(None))
                        .await;
                    break;
                }
                Some(Ok(_)) => {}
            },
            _ = keepalive.tick() => {
                if sender.send(Message::Ping(Bytes::new())).await.is_err() {
                    break;
                }
            }
        }
    }
    state.realtime.disconnect(&actor).await;
}

async fn execute_command(
    state: &AppState,
    actor: &AuthenticatedDevice,
    command: ControlCommand,
    now_millis: u64,
) -> Result<chatserver_core::protocol::ChatFrame, ChatServerError> {
    match command {
        ControlCommand::Ping { sent_at_millis } => Ok(pong_frame(sent_at_millis, now_millis)),
        ControlCommand::PublishKeyPackage(package) => {
            let id = package.key_package_ref.clone();
            state
                .store
                .put_key_package(&package)
                .await
                .map_err(store_error)?;
            Ok(success_frame("key_package.published", vec![id]))
        }
        ControlCommand::ResolveKeyPackages {
            user_id,
            device_id,
            limit,
        } => {
            let packages = state
                .store
                .list_key_packages(&user_id, device_id.as_deref(), now_millis, limit)
                .await
                .map_err(store_error)?;
            key_package_batch_frame(&packages)
        }
        ControlCommand::SendMessage(messages) => {
            let message_id = messages
                .first()
                .map(|message| message.message_id.clone())
                .ok_or(ChatServerError::InvalidRequest)?;
            state
                .store
                .put_messages(&messages)
                .await
                .map_err(store_error)?;
            for message in &messages {
                let recipient = AuthenticatedDevice {
                    user_id: message.recipient_user_id.clone(),
                    device_id: message.recipient_device_id.clone(),
                };
                state
                    .realtime
                    .notify(
                        &recipient,
                        RealtimeEvent::message_available(message, now_millis),
                    )
                    .await;
            }
            Ok(success_frame("message.accepted", vec![message_id]))
        }
        ControlCommand::SyncMessages { limit } => {
            let messages = state
                .store
                .list_messages(actor, now_millis, limit)
                .await
                .map_err(store_error)?;
            message_batch_frame(&messages)
        }
        ControlCommand::AcknowledgeMessages { message_ids } => {
            state
                .store
                .acknowledge_messages(actor, &message_ids)
                .await
                .map_err(store_error)?;
            Ok(success_frame("messages.acknowledged", message_ids))
        }
        ControlCommand::BeginAttachment(attachment) => {
            let id = attachment.attachment_id.clone();
            state
                .store
                .create_attachment(&attachment)
                .await
                .map_err(store_error)?;
            Ok(success_frame("attachment.begun", vec![id]))
        }
        ControlCommand::CompleteAttachment { attachment_id } => {
            if !state
                .store
                .complete_attachment(actor, &attachment_id, now_millis)
                .await
                .map_err(store_error)?
            {
                return Err(ChatServerError::Conflict);
            }
            Ok(attachment_ready_frame(attachment_id))
        }
        ControlCommand::AcknowledgeAttachment { attachment_id } => {
            let delete = state
                .store
                .acknowledge_attachment(actor, &attachment_id, now_millis)
                .await
                .map_err(store_error)?
                .ok_or(ChatServerError::NotFound)?;
            if delete {
                state
                    .objects
                    .remove(&attachment_id)
                    .await
                    .map_err(object_error)?;
                state
                    .store
                    .finalize_attachment(&attachment_id)
                    .await
                    .map_err(store_error)?;
            }
            Ok(success_frame(
                "attachment.acknowledged",
                vec![attachment_id],
            ))
        }
        ControlCommand::AbortAttachment { attachment_id } => {
            if !state
                .store
                .abort_attachment(actor, &attachment_id)
                .await
                .map_err(store_error)?
            {
                return Err(ChatServerError::NotFound);
            }
            state
                .objects
                .remove(&attachment_id)
                .await
                .map_err(object_error)?;
            state
                .store
                .finalize_attachment(&attachment_id)
                .await
                .map_err(store_error)?;
            Ok(success_frame("attachment.aborted", vec![attachment_id]))
        }
        ControlCommand::RegisterPush { platform, token } => {
            let endpoint = PushEndpoint::from_registration(
                actor,
                platform,
                token,
                state.app_id.clone(),
                now_millis,
            )?;
            state
                .store
                .put_push_endpoint(&endpoint)
                .await
                .map_err(store_error)?;
            Ok(success_frame("push.registered", Vec::new()))
        }
        ControlCommand::RemovePush { platform } => {
            state
                .store
                .remove_push_endpoint(actor, platform, &state.app_id)
                .await
                .map_err(store_error)?;
            Ok(success_frame("push.removed", Vec::new()))
        }
    }
}

async fn send_frame(
    sender: &mut futures_util::stream::SplitSink<WebSocket, Message>,
    frame: chatserver_core::protocol::ChatFrame,
) -> Result<(), axum::Error> {
    sender
        .send(Message::Binary(
            chatserver_core::encode_chat_frame(&frame).into(),
        ))
        .await
}

async fn push_worker(state: AppState) {
    let mut interval = time::interval(Duration::from_secs(2));
    interval.set_missed_tick_behavior(time::MissedTickBehavior::Delay);
    loop {
        interval.tick().await;
        let jobs = match state.store.claim_push_jobs(32).await {
            Ok(jobs) => jobs,
            Err(error) => {
                eprintln!("chatserver push outbox: {error}");
                continue;
            }
        };
        for job in jobs {
            let endpoints = match state
                .store
                .list_push_endpoints(&job.recipient_user_id, &job.recipient_device_id)
                .await
            {
                Ok(endpoints) => endpoints,
                Err(error) => {
                    eprintln!("chatserver push endpoint: {error}");
                    let _ = state.store.retry_push_job(&job).await;
                    continue;
                }
            };
            let mut success = true;
            for endpoint in endpoints {
                if let Err(error) = state.push.dispatch(&endpoint).await {
                    eprintln!("chatserver push delivery: {error}");
                    success = false;
                }
            }
            let result = if success {
                state.store.complete_push_job(&job).await
            } else {
                state.store.retry_push_job(&job).await
            };
            if let Err(error) = result {
                eprintln!("chatserver push finalize: {error}");
            }
        }
    }
}

async fn cleanup_worker(state: AppState) {
    let mut interval = time::interval(state.cleanup_interval);
    interval.set_missed_tick_behavior(time::MissedTickBehavior::Delay);
    loop {
        interval.tick().await;
        match state.store.cleanup_expired(now_millis()).await {
            Ok(attachments) => {
                for attachment_id in attachments {
                    if let Err(error) = state.objects.remove(&attachment_id).await {
                        eprintln!("chatserver attachment cleanup: {error}");
                        continue;
                    }
                    if let Err(error) = state.store.finalize_attachment(&attachment_id).await {
                        eprintln!("chatserver attachment finalize: {error}");
                    }
                }
            }
            Err(error) => eprintln!("chatserver database cleanup: {error}"),
        }
    }
}

fn authenticate(state: &AppState, headers: &HeaderMap) -> Result<AuthenticatedAccess, ApiError> {
    state.auth.authenticate(headers).map_err(ApiError)
}

fn map_store(error: StoreError) -> ApiError {
    ApiError(store_error(error))
}

fn store_error(error: StoreError) -> ChatServerError {
    if error.is_conflict() {
        ChatServerError::Conflict
    } else {
        ChatServerError::StorageUnavailable
    }
}

fn map_object(error: ObjectError) -> ApiError {
    ApiError(object_error(error))
}

fn object_error(error: ObjectError) -> ChatServerError {
    match error {
        ObjectError::InvalidIdentifier | ObjectError::IntegrityMismatch => {
            ChatServerError::InvalidRequest
        }
        ObjectError::TooLarge => ChatServerError::ResourceLimit,
        ObjectError::AlreadyExists => ChatServerError::Conflict,
        ObjectError::NotFound => ChatServerError::NotFound,
        ObjectError::Stream(_) | ObjectError::Io(_) => ChatServerError::StorageUnavailable,
    }
}

fn now_millis() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        .try_into()
        .unwrap_or(u64::MAX)
}
