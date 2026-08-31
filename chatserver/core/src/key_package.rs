use base64::{engine::general_purpose::STANDARD, Engine as _};
use serde::{Deserialize, Serialize};

use crate::{protocol, AuthenticatedDevice, ChatServerError};

/// 服务端保存的不透明 RFC 9420 Last Resort KeyPackage。
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct PublishedKeyPackage {
    pub user_id: String,
    pub device_id: String,
    pub key_package_ref: String,
    pub key_package: String,
    pub cipher_suite: String,
    pub not_before: u64,
    pub not_after: u64,
    pub last_resort: bool,
}

impl PublishedKeyPackage {
    pub fn from_protocol(
        package: &protocol::KeyPackage,
        actor: &AuthenticatedDevice,
        now_millis: u64,
    ) -> Result<Self, ChatServerError> {
        let package = Self {
            user_id: package.user_id.clone(),
            device_id: package.device_id.clone(),
            key_package_ref: package.key_package_ref.clone(),
            key_package: STANDARD.encode(&package.key_package),
            cipher_suite: package.cipher_suite.clone(),
            not_before: package.not_before,
            not_after: package.not_after,
            last_resort: package.last_resort,
        };
        package.validate_for(actor, now_millis)?;
        Ok(package)
    }

    pub fn to_protocol(&self) -> Result<protocol::KeyPackage, ChatServerError> {
        Ok(protocol::KeyPackage {
            user_id: self.user_id.clone(),
            device_id: self.device_id.clone(),
            key_package_ref: self.key_package_ref.clone(),
            key_package: STANDARD
                .decode(&self.key_package)
                .map_err(|_| ChatServerError::StorageUnavailable)?,
            cipher_suite: self.cipher_suite.clone(),
            not_before: self.not_before,
            not_after: self.not_after,
            last_resort: self.last_resort,
        })
    }

    pub fn validate_for(
        &self,
        actor: &AuthenticatedDevice,
        now_millis: u64,
    ) -> Result<(), ChatServerError> {
        actor.validate()?;
        if self.user_id != actor.user_id
            || self.device_id != actor.device_id
            || !self.last_resort
            || self.key_package.is_empty()
            || self.key_package.len() > 174_764
            || self.cipher_suite.is_empty()
            || self.cipher_suite.len() > 128
            || self.not_before >= self.not_after
            || self.not_before > now_millis.saturating_add(5 * 60 * 1000)
            || self.not_after <= now_millis
            || self.key_package_ref.len() < 32
            || self.key_package_ref.len() > 128
            || !self
                .key_package_ref
                .bytes()
                .all(|byte| byte.is_ascii_hexdigit())
        {
            return Err(ChatServerError::InvalidRequest);
        }
        Ok(())
    }
}
