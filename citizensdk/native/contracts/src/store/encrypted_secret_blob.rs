//! 只接受系统金库密文信封的专用仓储。

use crate::{ContractFuture, EncryptedSecretEnvelope, SecretRef};

/// 单个精确 SecretRef 的 CAS 快照。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct EncryptedSecretBlobSnapshot {
    revision: u64,
    envelope: Option<EncryptedSecretEnvelope>,
}

impl EncryptedSecretBlobSnapshot {
    pub const fn new(revision: u64, envelope: Option<EncryptedSecretEnvelope>) -> Self {
        Self { revision, envelope }
    }

    pub const fn revision(&self) -> u64 {
        self.revision
    }

    pub fn envelope(&self) -> Option<&EncryptedSecretEnvelope> {
        self.envelope.as_ref()
    }
}

/// 已加密秘密的精确身份仓储；API 在类型上拒绝 `SecretBuffer` 和普通明文字节。
pub trait EncryptedSecretBlobStore: Send + Sync {
    fn load(&self, secret_ref: SecretRef) -> ContractFuture<'_, EncryptedSecretBlobSnapshot>;

    /// `None` 表示幂等删除。调用返回前必须回读确认完整候选状态。
    fn compare_and_swap(
        &self,
        secret_ref: SecretRef,
        expected_revision: u64,
        envelope: Option<EncryptedSecretEnvelope>,
    ) -> ContractFuture<'_, EncryptedSecretBlobSnapshot>;
}
