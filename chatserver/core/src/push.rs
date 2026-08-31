use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::{AuthenticatedDevice, ChatServerError};

/// 系统推送平台。推送负载只允许携带“有新消息”唤醒信号。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PushPlatform {
    Ios,
    Android,
}

impl PushPlatform {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Ios => "ios",
            Self::Android => "android",
        }
    }

    pub fn parse(value: &str) -> Result<Self, ChatServerError> {
        match value {
            "ios" => Ok(Self::Ios),
            "android" => Ok(Self::Android),
            _ => Err(ChatServerError::InvalidRequest),
        }
    }
}

/// 单个设备的 APNs 或 FCM 端点。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PushEndpoint {
    pub user_id: String,
    pub device_id: String,
    pub platform: PushPlatform,
    pub token: String,
    pub app_id: String,
    pub updated_at_millis: u64,
}

impl PushEndpoint {
    pub fn from_registration(
        actor: &AuthenticatedDevice,
        platform: PushPlatform,
        token: String,
        app_id: String,
        now_millis: u64,
    ) -> Result<Self, ChatServerError> {
        let endpoint = Self {
            user_id: actor.user_id.clone(),
            device_id: actor.device_id.clone(),
            platform,
            token,
            app_id,
            updated_at_millis: now_millis,
        };
        endpoint.validate_for(actor)?;
        Ok(endpoint)
    }

    pub fn validate_for(&self, actor: &AuthenticatedDevice) -> Result<(), ChatServerError> {
        actor.validate()?;
        if self.user_id != actor.user_id
            || self.device_id != actor.device_id
            || self.token.is_empty()
            || self.token.len() > 4096
            || self.token.bytes().any(|byte| byte.is_ascii_whitespace())
            || self.app_id.is_empty()
            || self.app_id.len() > 256
            || self.app_id.bytes().any(|byte| byte.is_ascii_whitespace())
        {
            return Err(ChatServerError::InvalidRequest);
        }
        Ok(())
    }
}

#[async_trait(?Send)]
pub trait PushSink {
    /// 只发送唤醒，不传递消息正文、附件地址或任何聊天明文。
    async fn wake_device(&self, user_id: &str, device_id: &str) -> Result<(), ChatServerError>;
}
