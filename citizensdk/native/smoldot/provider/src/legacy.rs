//! crate 私有的 smoldot JSON-RPC allowlist 运输层。
//!
//! `smoldot-light` 目前只有当前 best/finalized 的部分 typed API；准确历史块、提交和观察
//! 仍通过它自己的验证型 JSON-RPC 服务取得。本模块只接收 provider 源码内固定方法名，
//! 不从任何公开 SDK 参数读取 method。

use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc,
    },
    time::Duration,
};

use citizen_sdk_contracts::{ContractErrorCode, ContractResult};
use parking_lot::Mutex;
use serde_json::{json, Value};
use smoldot_light::{platform::DefaultPlatform, ChainId, Client, JsonRpcResponses};
use tokio::sync::{broadcast, oneshot};

use crate::client::{contract_error, provider_error};

type NativeClient = Client<Arc<DefaultPlatform>, ()>;
type PendingResponses = Arc<tokio::sync::Mutex<HashMap<String, oneshot::Sender<Value>>>>;

#[derive(Clone)]
pub(crate) struct LegacyRpc {
    client: Arc<Mutex<NativeClient>>,
    chain_id: ChainId,
    pending: PendingResponses,
    notifications: broadcast::Sender<Value>,
    next_request_id: Arc<AtomicU64>,
    closed: Arc<AtomicBool>,
    timeout: Duration,
}

impl LegacyRpc {
    pub(crate) fn new(
        client: Arc<Mutex<NativeClient>>,
        chain_id: ChainId,
        timeout: Duration,
        responses: JsonRpcResponses<Arc<DefaultPlatform>>,
        runtime: &tokio::runtime::Handle,
    ) -> Self {
        let pending = Arc::new(tokio::sync::Mutex::new(HashMap::new()));
        let (notifications, _) = broadcast::channel(256);
        let closed = Arc::new(AtomicBool::new(false));
        runtime.spawn(forward_responses(
            responses,
            Arc::clone(&pending),
            notifications.clone(),
            Arc::clone(&closed),
        ));
        Self {
            client,
            chain_id,
            pending,
            notifications,
            next_request_id: Arc::new(AtomicU64::new(1)),
            closed,
            timeout,
        }
    }

    pub(crate) async fn request(
        &self,
        method: &'static str,
        params: Value,
    ) -> ContractResult<Value> {
        let request_number = reserve_request_number(&self.next_request_id)?;
        let request_id = format!("__citizensdk_{request_number}");
        let (sender, receiver) = oneshot::channel();
        self.pending.lock().await.insert(request_id.clone(), sender);
        let request = json!({
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
            "params": params,
        })
        .to_string();
        let queue_result = self.client.lock().json_rpc_request(request, self.chain_id);
        if let Err(error) = queue_result {
            self.pending.lock().await.remove(&request_id);
            return Err(provider_error(format!(
                "smoldot 无法排队 {method}: {error:?}"
            )));
        }

        let response = match tokio::time::timeout(self.timeout, receiver).await {
            Ok(Ok(response)) => response,
            Ok(Err(_)) => {
                self.pending.lock().await.remove(&request_id);
                return Err(provider_error(format!("smoldot {method} 响应通道关闭")));
            }
            Err(_) => {
                self.pending.lock().await.remove(&request_id);
                return Err(contract_error(
                    ContractErrorCode::Timeout,
                    format!("smoldot {method} 超时"),
                ));
            }
        };
        if let Some(error) = response.get("error") {
            return Err(provider_error(format!(
                "smoldot {method} 返回 JSON-RPC error: {error}"
            )));
        }
        response.get("result").cloned().ok_or_else(|| {
            contract_error(
                ContractErrorCode::Decode,
                format!("smoldot {method} 响应缺少 result"),
            )
        })
    }

    /// 在排队订阅前取得广播 receiver，避免首条状态紧随订阅 ID 到达时丢失。
    pub(crate) async fn subscribe_extrinsic(
        &self,
        extrinsic_hex: String,
    ) -> ContractResult<(String, broadcast::Receiver<Value>)> {
        let receiver = self.notifications.subscribe();
        let result = self
            .request("author_submitAndWatchExtrinsic", json!([extrinsic_hex]))
            .await?;
        let subscription = result.as_str().ok_or_else(|| {
            contract_error(
                ContractErrorCode::Decode,
                "submitAndWatch 响应不是 subscription id",
            )
        })?;
        if subscription.is_empty() {
            return Err(contract_error(
                ContractErrorCode::Decode,
                "submitAndWatch 返回空 subscription id",
            ));
        }
        Ok((subscription.to_owned(), receiver))
    }

    pub(crate) async fn unwatch_extrinsic(&self, subscription: &str) {
        let _ = self
            .request("author_unwatchExtrinsic", json!([subscription]))
            .await;
    }

    pub(crate) fn is_closed(&self) -> bool {
        self.closed.load(Ordering::Acquire)
    }
}

/// 单调预留内部 request ID。`fetch_update` 只有在 `checked_add` 成功时才写回，
/// 因此达到 `u64::MAX` 后计数器永久停留在耗尽态，不会先回卷到 0 再复用旧 ID。
fn reserve_request_number(next: &AtomicU64) -> ContractResult<u64> {
    next.fetch_update(Ordering::Relaxed, Ordering::Relaxed, |current| {
        current.checked_add(1).filter(|value| *value != 0)
    })
    .map_err(|_| {
        contract_error(
            ContractErrorCode::Internal,
            "smoldot provider request id exhausted",
        )
    })
}

async fn forward_responses(
    mut responses: JsonRpcResponses<Arc<DefaultPlatform>>,
    pending: PendingResponses,
    notifications: broadcast::Sender<Value>,
    closed: Arc<AtomicBool>,
) {
    while let Some(raw) = responses.next().await {
        let Ok(response) = serde_json::from_str::<Value>(&raw) else {
            continue;
        };
        if let Some(id) = response.get("id").and_then(normalize_id) {
            if let Some(sender) = pending.lock().await.remove(&id) {
                let _ = sender.send(response);
                continue;
            }
        }
        let _ = notifications.send(response);
    }
    closed.store(true, Ordering::Release);
    pending.lock().await.clear();
}

fn normalize_id(value: &Value) -> Option<String> {
    match value {
        Value::String(value) => Some(value.clone()),
        Value::Number(value) => Some(value.to_string()),
        _ => None,
    }
}

pub(crate) fn subscription_result<'a>(
    notification: &'a Value,
    subscription: &str,
) -> Option<&'a Value> {
    let params = notification.get("params")?;
    let received = params.get("subscription").and_then(normalize_id)?;
    (received == subscription)
        .then(|| params.get("result"))
        .flatten()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn notification_filter_requires_exact_subscription() {
        let notification = json!({
            "jsonrpc": "2.0",
            "method": "author_extrinsicUpdate",
            "params": {"subscription": "7", "result": {"inBlock": "0x00"}}
        });
        assert!(subscription_result(&notification, "7").is_some());
        assert!(subscription_result(&notification, "8").is_none());
    }

    #[test]
    fn request_id_exhaustion_is_permanent_and_never_wraps_to_zero() {
        let next = AtomicU64::new(u64::MAX - 1);
        assert_eq!(reserve_request_number(&next).ok(), Some(u64::MAX - 1));
        assert_eq!(next.load(Ordering::Relaxed), u64::MAX);

        for _ in 0..2 {
            let Err(error) = reserve_request_number(&next) else {
                panic!("exhausted request id counter must remain fail closed");
            };
            assert_eq!(error.code(), ContractErrorCode::Internal);
            assert_eq!(next.load(Ordering::Relaxed), u64::MAX);
        }
    }
}
