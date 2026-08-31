use std::{collections::HashMap, sync::Arc};

use chatserver_core::{AuthenticatedDevice, RealtimeEvent};
use tokio::sync::{broadcast, RwLock};

type DeviceKey = (String, String);

/// 单进程 WSS 二进制帧总线。可靠消息真源始终是 PostgreSQL 密文存储。
#[derive(Clone, Default)]
pub struct RealtimeHub {
    channels: Arc<RwLock<HashMap<DeviceKey, broadcast::Sender<RealtimeEvent>>>>,
}

impl RealtimeHub {
    pub async fn subscribe(
        &self,
        actor: &AuthenticatedDevice,
    ) -> broadcast::Receiver<RealtimeEvent> {
        let key = (actor.user_id.clone(), actor.device_id.clone());
        let mut channels = self.channels.write().await;
        channels
            .entry(key)
            .or_insert_with(|| broadcast::channel(128).0)
            .subscribe()
    }

    pub async fn notify(&self, actor: &AuthenticatedDevice, event: RealtimeEvent) {
        let key = (actor.user_id.clone(), actor.device_id.clone());
        let sender = self.channels.read().await.get(&key).cloned();
        if let Some(sender) = sender {
            let _ = sender.send(event);
        }
    }

    pub async fn disconnect(&self, actor: &AuthenticatedDevice) {
        let key = (actor.user_id.clone(), actor.device_id.clone());
        let mut channels = self.channels.write().await;
        if channels
            .get(&key)
            .is_some_and(|sender| sender.receiver_count() == 0)
        {
            channels.remove(&key);
        }
    }
}
