//! CitizenSDK 能力发现合同。

use std::collections::BTreeSet;

use crate::{ContractError, ContractErrorCode, ContractResult};

/// CitizenSDK 唯一正式能力名；不得增加近义别名制造第二套能力语义。
#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub enum CapabilityName {
    ChainRead,
    TransactionBuild,
    TransactionSubmit,
    TransactionVerify,
    WalletProfile,
    LocalSigning,
    HardwareVault,
    UserAuthentication,
    History,
    BackgroundSync,
}
impl CapabilityName {
    pub const ALL: [Self; 10] = [
        Self::ChainRead,
        Self::TransactionBuild,
        Self::TransactionSubmit,
        Self::TransactionVerify,
        Self::WalletProfile,
        Self::LocalSigning,
        Self::HardwareVault,
        Self::UserAuthentication,
        Self::History,
        Self::BackgroundSync,
    ];

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::ChainRead => "CHAIN_READ",
            Self::TransactionBuild => "TRANSACTION_BUILD",
            Self::TransactionSubmit => "TRANSACTION_SUBMIT",
            Self::TransactionVerify => "TRANSACTION_VERIFY",
            Self::WalletProfile => "WALLET_PROFILE",
            Self::LocalSigning => "LOCAL_SIGNING",
            Self::HardwareVault => "HARDWARE_VAULT",
            Self::UserAuthentication => "USER_AUTHENTICATION",
            Self::History => "HISTORY",
            Self::BackgroundSync => "BACKGROUND_SYNC",
        }
    }
}

/// 能力尚未 ready 的稳定原因。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CapabilityReason {
    BuildUnsupported,
    DeviceUnavailable,
    HostDisabled,
    DependencyNotReady,
    UserAuthenticationRequired,
    VaultLocked,
    ChainStarting,
    ChainUnsynced,
    StorageUnavailable,
}

impl CapabilityReason {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::BuildUnsupported => "build_unsupported",
            Self::DeviceUnavailable => "device_unavailable",
            Self::HostDisabled => "host_disabled",
            Self::DependencyNotReady => "dependency_not_ready",
            Self::UserAuthenticationRequired => "user_authentication_required",
            Self::VaultLocked => "vault_locked",
            Self::ChainStarting => "chain_starting",
            Self::ChainUnsynced => "chain_unsynced",
            Self::StorageUnavailable => "storage_unavailable",
        }
    }
}

/// 单项能力在当前构建、设备、宿主配置和运行时中的完整状态。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CapabilityStatus {
    name: CapabilityName,
    supported: bool,
    available: bool,
    enabled: bool,
    ready: bool,
    reason: Option<CapabilityReason>,
}

impl CapabilityStatus {
    pub fn try_new(
        name: CapabilityName,
        supported: bool,
        available: bool,
        enabled: bool,
        ready: bool,
        reason: Option<CapabilityReason>,
    ) -> ContractResult<Self> {
        if ready && (!supported || !available || !enabled || reason.is_some()) {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "ready 能力必须同时 supported、available、enabled 且无失败原因",
            ));
        }
        if !ready && reason.is_none() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "未 ready 的能力必须携带稳定原因",
            ));
        }
        Ok(Self {
            name,
            supported,
            available,
            enabled,
            ready,
            reason,
        })
    }

    pub fn ready(name: CapabilityName) -> Self {
        Self {
            name,
            supported: true,
            available: true,
            enabled: true,
            ready: true,
            reason: None,
        }
    }

    pub const fn name(&self) -> CapabilityName {
        self.name
    }

    pub const fn supported(&self) -> bool {
        self.supported
    }

    pub const fn available(&self) -> bool {
        self.available
    }

    pub const fn enabled(&self) -> bool {
        self.enabled
    }

    pub const fn is_ready(&self) -> bool {
        self.ready
    }

    pub const fn reason(&self) -> Option<CapabilityReason> {
        self.reason
    }
}

/// 一次原子读取的完整能力快照。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CapabilitySnapshot {
    revision: u64,
    statuses: Vec<CapabilityStatus>,
}

impl CapabilitySnapshot {
    /// 快照必须把十个正式能力各包含一次，防止“未返回”被上层误当成 false 或 true。
    pub fn try_new(revision: u64, mut statuses: Vec<CapabilityStatus>) -> ContractResult<Self> {
        let names: BTreeSet<_> = statuses.iter().map(CapabilityStatus::name).collect();
        let expected: BTreeSet<_> = CapabilityName::ALL.into_iter().collect();
        if statuses.len() != CapabilityName::ALL.len() || names != expected {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "能力快照必须精确包含十个正式能力且不得重复",
            ));
        }
        statuses.sort_by_key(CapabilityStatus::name);
        Ok(Self { revision, statuses })
    }

    pub const fn revision(&self) -> u64 {
        self.revision
    }

    pub fn statuses(&self) -> &[CapabilityStatus] {
        &self.statuses
    }

    pub fn status(&self, name: CapabilityName) -> Option<&CapabilityStatus> {
        self.statuses.iter().find(|status| status.name() == name)
    }
}
