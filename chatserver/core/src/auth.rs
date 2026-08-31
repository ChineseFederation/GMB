use crate::ChatServerError;
use serde::{Deserialize, Serialize};

/// 宿主认证完成后注入的通用用户/设备身份。
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct AuthenticatedDevice {
    pub user_id: String,
    pub device_id: String,
}

/// 宿主签名后的部署中立聊天权限。ChatServer 不解释会员名称或产品档位。
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct ChatAuthorization {
    pub chat_enabled: bool,
    pub max_attachment_bytes: u64,
}

/// 一次 ChatServer 请求唯一可信的认证与授权结果。
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct AuthenticatedAccess {
    pub actor: AuthenticatedDevice,
    pub authorization: ChatAuthorization,
}

impl AuthenticatedAccess {
    pub fn validate(&self) -> Result<(), ChatServerError> {
        self.actor.validate()?;
        if !self.authorization.chat_enabled || self.authorization.max_attachment_bytes == 0 {
            return Err(ChatServerError::Forbidden);
        }
        Ok(())
    }

    /// 部署硬上限与宿主签名上限同时生效，客户端不能扩大任一边界。
    pub fn effective_max_attachment_bytes(
        &self,
        deployment_max_attachment_bytes: u64,
    ) -> Result<u64, ChatServerError> {
        self.validate()?;
        if deployment_max_attachment_bytes == 0 {
            return Err(ChatServerError::ResourceLimit);
        }
        Ok(self
            .authorization
            .max_attachment_bytes
            .min(deployment_max_attachment_bytes))
    }
}

impl AuthenticatedDevice {
    pub fn validate(&self) -> Result<(), ChatServerError> {
        if self.user_id.trim().is_empty()
            || self.device_id.trim().is_empty()
            || self.user_id.len() > 256
            || self.device_id.len() > 256
            || self.user_id.contains(':')
            || self.device_id.contains(':')
            || self.user_id.bytes().any(|byte| byte.is_ascii_control())
            || self.device_id.bytes().any(|byte| byte.is_ascii_control())
        {
            return Err(ChatServerError::InvalidRequest);
        }
        Ok(())
    }
}
