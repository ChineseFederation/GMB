use chatserver_core::{
    attachment_ready_frame, key_package_batch_frame, message_batch_frame, parse_control_command,
    pong_frame, success_frame, AuthenticatedAccess, AuthenticatedDevice, ChatAuthorization,
    ChatServerError, ControlCommand, ControlSessionLimits, PushEndpoint, RealtimeEvent,
};
use serde::{Deserialize, Serialize};
use wasm_bindgen::{JsCast, JsValue};
use worker::{
    durable_object, DurableObject, Env, Error, Headers, Method, Request, RequestInit, Response,
    Result, State, WebSocket, WebSocketIncomingMessage, WebSocketPair,
};

use crate::{api, attachments::AttachmentObjects, push, store::CloudflareStore};

const NAMESPACE_BINDING: &str = "CHAT_REALTIME";
const PROTOCOL: &str = "chatserver";
const INTERNAL_NOTIFY_URL: &str = "https://chatserver.internal/notify";
const INTERNAL_USER_HEADER: &str = "x-chat-internal-user";
const INTERNAL_DEVICE_HEADER: &str = "x-chat-internal-device";
const INTERNAL_MAX_ATTACHMENT_BYTES_HEADER: &str = "x-chat-internal-max-attachment-bytes";

#[derive(Debug, Clone, Deserialize, Serialize)]
struct SessionAttachment {
    access: AuthenticatedAccess,
    limits: ControlSessionLimits,
}

pub async fn connect(
    mut req: Request,
    env: &Env,
    access: &AuthenticatedAccess,
) -> Result<Response> {
    // 外部请求头先被 JWT 鉴权，再由 Worker 强制覆盖内部身份，DO 不信任客户端身份头。
    req.headers_mut()?
        .set(INTERNAL_USER_HEADER, &access.actor.user_id)?;
    req.headers_mut()?
        .set(INTERNAL_DEVICE_HEADER, &access.actor.device_id)?;
    req.headers_mut()?.set(
        INTERNAL_MAX_ATTACHMENT_BYTES_HEADER,
        &access.authorization.max_attachment_bytes.to_string(),
    )?;
    let namespace = env.durable_object(NAMESPACE_BINDING)?;
    namespace
        .get_by_name(&device_key(&access.actor))?
        .fetch_with_request(req)
        .await
}

/// 内部通知与外部 WSS 使用同一份 Protobuf 二进制帧。
pub async fn notify(env: Env, recipient: AuthenticatedDevice, event: RealtimeEvent) -> Result<()> {
    let namespace = env.durable_object(NAMESPACE_BINDING)?;
    let stub = namespace.get_by_name(&device_key(&recipient))?;
    let payload = js_sys::Uint8Array::from(event.as_bytes());
    let headers = Headers::new();
    headers.set("content-type", "application/x-protobuf")?;
    let mut init = RequestInit::new();
    init.with_method(Method::Post)
        .with_headers(headers)
        .with_body(Some(payload.unchecked_into::<JsValue>()));
    let request = Request::new_with_init(INTERNAL_NOTIFY_URL, &init)?;
    let response = stub.fetch_with_request(request).await?;
    if response.status_code() == 204 {
        Ok(())
    } else {
        Err(Error::RustError(
            "realtime notification rejected".to_owned(),
        ))
    }
}

fn device_key(actor: &AuthenticatedDevice) -> String {
    format!("{}:{}", actor.user_id, actor.device_id)
}

/// One hibernating Durable Object owns all WSS connections for one user device.
#[durable_object]
pub struct ChatRealtime {
    state: State,
    env: Env,
}

impl DurableObject for ChatRealtime {
    fn new(state: State, env: Env) -> Self {
        Self { state, env }
    }

    async fn fetch(&self, mut req: Request) -> Result<Response> {
        match (req.method(), req.path().as_str()) {
            (Method::Get, "/realtime") => {
                let upgrade = req
                    .headers()
                    .get("upgrade")?
                    .is_some_and(|value| value.eq_ignore_ascii_case("websocket"));
                let protocol = req
                    .headers()
                    .get("sec-websocket-protocol")?
                    .is_some_and(|value| value.split(',').any(|item| item.trim() == PROTOCOL));
                if !upgrade || !protocol {
                    return Response::error("websocket upgrade required", 426);
                }
                let access = AuthenticatedAccess {
                    actor: AuthenticatedDevice {
                        user_id: required_header(&req, INTERNAL_USER_HEADER)?,
                        device_id: required_header(&req, INTERNAL_DEVICE_HEADER)?,
                    },
                    authorization: ChatAuthorization {
                        chat_enabled: true,
                        max_attachment_bytes: required_header(
                            &req,
                            INTERNAL_MAX_ATTACHMENT_BYTES_HEADER,
                        )?
                        .parse::<u64>()
                        .map_err(|_| Error::RustError("invalid authenticated access".to_owned()))?,
                    },
                };
                access
                    .validate()
                    .map_err(|error| Error::RustError(error.code().to_owned()))?;

                let pair = WebSocketPair::new()?;
                pair.server.serialize_attachment(SessionAttachment {
                    access,
                    limits: ControlSessionLimits::default(),
                })?;
                self.state.accept_web_socket(&pair.server);
                pair.server
                    .send_with_bytes(chatserver_core::encode_chat_frame(
                        &chatserver_core::ready_frame(api::now_millis()),
                    ))?;
                let headers = Headers::new();
                headers.set("sec-websocket-protocol", PROTOCOL)?;
                Ok(Response::from_websocket(pair.client)?.with_headers(headers))
            }
            (Method::Post, "/notify") => {
                let payload = req.bytes().await?;
                let event = RealtimeEvent::from_bytes(payload)
                    .map_err(|_| Error::RustError("invalid protobuf frame".to_owned()))?;
                for socket in self.state.get_websockets() {
                    socket.send_with_bytes(event.as_bytes())?;
                }
                Ok(Response::empty()?.with_status(204))
            }
            _ => Response::error("not found", 404),
        }
    }

    async fn websocket_message(
        &self,
        ws: WebSocket,
        message: WebSocketIncomingMessage,
    ) -> Result<()> {
        let WebSocketIncomingMessage::Binary(bytes) = message else {
            return ws.close(Some(1003), Some("binary protobuf required"));
        };
        let mut session = ws
            .deserialize_attachment::<SessionAttachment>()?
            .ok_or_else(|| Error::RustError("missing authenticated WSS session".to_owned()))?;
        let frame = match chatserver_core::decode_chat_frame(&bytes) {
            Ok(frame) => frame,
            Err(error) => return send_failure(&ws, &error),
        };
        let max_attachment_bytes = match session
            .access
            .effective_max_attachment_bytes(api::max_attachment_bytes(&self.env).unwrap_or(0))
        {
            Ok(value) => value,
            Err(error) => return send_failure(&ws, &error),
        };
        let command = match parse_control_command(
            frame,
            &session.access.actor,
            api::now_millis(),
            max_attachment_bytes,
            &mut session.limits,
        ) {
            Ok(command) => command,
            Err(error) => {
                ws.serialize_attachment(&session)?;
                return send_failure(&ws, &error);
            }
        };
        ws.serialize_attachment(&session)?;

        let response = match self
            .execute_command(&session.access.actor, command, api::now_millis())
            .await
        {
            Ok(frame) => frame,
            Err(error) => chatserver_core::failure_frame(error.code()),
        };
        ws.send_with_bytes(chatserver_core::encode_chat_frame(&response))
    }

    async fn websocket_close(
        &self,
        _ws: WebSocket,
        _code: usize,
        _reason: String,
        _was_clean: bool,
    ) -> Result<()> {
        Ok(())
    }

    async fn websocket_error(&self, _ws: WebSocket, _error: Error) -> Result<()> {
        Ok(())
    }
}

impl ChatRealtime {
    async fn execute_command(
        &self,
        actor: &AuthenticatedDevice,
        command: ControlCommand,
        now_millis: u64,
    ) -> std::result::Result<chatserver_core::protocol::ChatFrame, ChatServerError> {
        let store = CloudflareStore::from_env(&self.env).map_err(storage_error)?;
        match command {
            ControlCommand::Ping { sent_at_millis } => Ok(pong_frame(sent_at_millis, now_millis)),
            ControlCommand::PublishKeyPackage(package) => {
                let id = package.key_package_ref.clone();
                store
                    .put_key_package(&package)
                    .await
                    .map_err(storage_error)?;
                Ok(success_frame("key_package.published", vec![id]))
            }
            ControlCommand::ResolveKeyPackages {
                user_id,
                device_id,
                limit,
            } => {
                let packages = store
                    .list_key_packages(&user_id, device_id.as_deref(), now_millis, limit)
                    .await
                    .map_err(storage_error)?;
                key_package_batch_frame(&packages)
            }
            ControlCommand::SendMessage(messages) => {
                let message_id = messages
                    .first()
                    .map(|message| message.message_id.clone())
                    .ok_or(ChatServerError::InvalidRequest)?;
                store.put_messages(&messages).await.map_err(storage_error)?;

                let env = self.env.clone();
                self.state.wait_until(async move {
                    for message in &messages {
                        let recipient = AuthenticatedDevice {
                            user_id: message.recipient_user_id.clone(),
                            device_id: message.recipient_device_id.clone(),
                        };
                        let event = RealtimeEvent::message_available(message, now_millis);
                        let _ = notify(env.clone(), recipient, event).await;
                    }
                    let _ = push::drain(env, now_millis).await;
                });
                Ok(success_frame("message.accepted", vec![message_id]))
            }
            ControlCommand::SyncMessages { limit } => {
                let messages = store
                    .list_messages(actor, now_millis, limit)
                    .await
                    .map_err(storage_error)?;
                message_batch_frame(&messages)
            }
            ControlCommand::AcknowledgeMessages { message_ids } => {
                store
                    .acknowledge_messages(actor, &message_ids)
                    .await
                    .map_err(storage_error)?;
                Ok(success_frame("messages.acknowledged", message_ids))
            }
            ControlCommand::BeginAttachment(attachment) => {
                let id = attachment.attachment_id.clone();
                store
                    .create_attachment(&attachment)
                    .await
                    .map_err(storage_error)?;
                Ok(success_frame("attachment.begun", vec![id]))
            }
            ControlCommand::CompleteAttachment { attachment_id } => {
                let complete = store
                    .complete_attachment(actor, &attachment_id, now_millis)
                    .await
                    .map_err(storage_error)?;
                if !complete {
                    return Err(ChatServerError::Conflict);
                }
                Ok(attachment_ready_frame(attachment_id))
            }
            ControlCommand::AcknowledgeAttachment { attachment_id } => {
                let delete = store
                    .acknowledge_attachment(actor, &attachment_id, now_millis)
                    .await
                    .map_err(storage_error)?
                    .ok_or(ChatServerError::NotFound)?;
                if delete {
                    AttachmentObjects::from_env(&self.env)
                        .map_err(storage_error)?
                        .delete(&attachment_id)
                        .await
                        .map_err(storage_error)?;
                    store
                        .finalize_attachment(&attachment_id)
                        .await
                        .map_err(storage_error)?;
                }
                Ok(success_frame(
                    "attachment.acknowledged",
                    vec![attachment_id],
                ))
            }
            ControlCommand::AbortAttachment { attachment_id } => {
                if !store
                    .abort_attachment(actor, &attachment_id)
                    .await
                    .map_err(storage_error)?
                {
                    return Err(ChatServerError::NotFound);
                }
                AttachmentObjects::from_env(&self.env)
                    .map_err(storage_error)?
                    .delete(&attachment_id)
                    .await
                    .map_err(storage_error)?;
                store
                    .finalize_attachment(&attachment_id)
                    .await
                    .map_err(storage_error)?;
                Ok(success_frame("attachment.aborted", vec![attachment_id]))
            }
            ControlCommand::RegisterPush { platform, token } => {
                let endpoint = PushEndpoint::from_registration(
                    actor,
                    platform,
                    token,
                    api::app_id(&self.env)?,
                    now_millis,
                )?;
                store
                    .put_push_endpoint(&endpoint)
                    .await
                    .map_err(storage_error)?;
                Ok(success_frame("push.registered", Vec::new()))
            }
            ControlCommand::RemovePush { platform } => {
                store
                    .remove_push_endpoint(actor, platform, &api::app_id(&self.env)?)
                    .await
                    .map_err(storage_error)?;
                Ok(success_frame("push.removed", Vec::new()))
            }
        }
    }
}

fn required_header(req: &Request, name: &str) -> Result<String> {
    req.headers()
        .get(name)?
        .filter(|value| !value.is_empty())
        .ok_or_else(|| Error::RustError("missing authenticated WSS identity".to_owned()))
}

fn send_failure(ws: &WebSocket, error: &ChatServerError) -> Result<()> {
    ws.send_with_bytes(chatserver_core::encode_chat_frame(
        &chatserver_core::failure_frame(error.code()),
    ))
}

fn storage_error(_error: Error) -> ChatServerError {
    ChatServerError::StorageUnavailable
}
