use citizen_sdk_contracts::{
    CapabilityName, CapabilityReason, CapabilitySnapshot, CapabilityStatus, VaultAvailability,
};
use citizen_sdk_engine::{CapabilityProbe, EngineLifecycle};
use citizen_sdk_smoldot_provider::ProviderLifecycle;

use crate::{
    abi::{
        CitizenSdkCapabilityName, CitizenSdkCapabilityReason, CitizenSdkCapabilitySnapshot,
        CitizenSdkCapabilityStatus, CitizenSdkLifecycle,
    },
    error::{FfiError, FfiResult},
};

/// 由产品内部组合实际探测出的组件事实；宿主不能直接提交这组布尔值。
///
/// chain-only 与完整钱包的区别由 `ProductComposition` 的类型化组件推导。任何存储或
/// vault 探测失败都保留“构建支持”事实，但关闭 runtime readiness。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct ProductCapabilityFacts {
    wallet_composed: bool,
    host_probe_completed: bool,
    vault_availability: VaultAvailability,
    wallet_store_ready: bool,
    encrypted_secrets_ready: bool,
    wallet_key_ready: bool,
    history_store_ready: bool,
    background_sync_composed: bool,
}

impl ProductCapabilityFacts {
    pub(crate) const fn chain_only() -> Self {
        Self {
            wallet_composed: false,
            host_probe_completed: false,
            vault_availability: VaultAvailability::Unsupported,
            wallet_store_ready: false,
            encrypted_secrets_ready: false,
            wallet_key_ready: false,
            history_store_ready: false,
            background_sync_composed: false,
        }
    }

    pub(crate) const fn wallet(
        vault_availability: VaultAvailability,
        wallet_store_ready: bool,
        encrypted_secrets_ready: bool,
        wallet_key_ready: bool,
        history_store_ready: bool,
        background_sync_composed: bool,
    ) -> Self {
        Self {
            wallet_composed: true,
            host_probe_completed: true,
            vault_availability,
            wallet_store_ready,
            encrypted_secrets_ready,
            wallet_key_ready,
            history_store_ready,
            background_sync_composed,
        }
    }

    /// 构造阶段只声明钱包组件已经按完整 bundle 组合，不同步调用宿主存储或金库。
    ///
    /// `citizensdk_create_with_host` 可以从 Android/iOS 主线程调用；若在构造函数内等待
    /// 宿主异步 completion，会让随后需要回到同一线程的系统金库形成死锁。真实
    /// availability/readiness 在 SDK 工作线程第一次刷新能力时取得。
    pub(crate) const fn wallet_configured() -> Self {
        Self {
            wallet_composed: true,
            host_probe_completed: false,
            vault_availability: VaultAvailability::Unavailable,
            wallet_store_ready: false,
            encrypted_secrets_ready: false,
            wallet_key_ready: false,
            history_store_ready: false,
            background_sync_composed: false,
        }
    }
}

/// 从真实 provider 与内部组件事实生成十项能力。chain-only 构造明确把钱包能力标为
/// unsupported；host 构造在第一次异步探测前只声明 supported，并以
/// `DependencyNotReady` 关闭 readiness，不把“尚未探测”误报为设备不可用。
pub(crate) fn product_probes(
    provider_is_usable: bool,
    facts: ProductCapabilityFacts,
) -> Vec<CapabilityProbe> {
    let vault_device_available = matches!(
        facts.vault_availability,
        VaultAvailability::Available | VaultAvailability::NoStrongUserAuthentication
    );
    let vault_ready = facts.vault_availability == VaultAvailability::Available;
    let vault_not_ready_reason = match facts.vault_availability {
        VaultAvailability::Available => None,
        VaultAvailability::NoStrongUserAuthentication => {
            Some(CapabilityReason::UserAuthenticationRequired)
        }
        VaultAvailability::Unsupported | VaultAvailability::Unavailable => {
            Some(CapabilityReason::DeviceUnavailable)
        }
    };
    let signing_storage_ready =
        facts.wallet_store_ready && facts.encrypted_secrets_ready && facts.wallet_key_ready;
    let signing_ready = facts.wallet_composed && signing_storage_ready && vault_ready;
    let signing_reason = if !vault_ready {
        vault_not_ready_reason
    } else if !facts.wallet_store_ready || !facts.encrypted_secrets_ready || !facts.wallet_key_ready
    {
        Some(CapabilityReason::StorageUnavailable)
    } else {
        None
    };

    CapabilityName::ALL
        .into_iter()
        .map(|name| match name {
            CapabilityName::ChainRead
            | CapabilityName::TransactionSubmit
            | CapabilityName::TransactionVerify => CapabilityProbe {
                name,
                supported: true,
                available: true,
                enabled: true,
                runtime_ready: provider_is_usable,
                not_ready_reason: (!provider_is_usable).then_some(CapabilityReason::ChainUnsynced),
            },
            CapabilityName::TransactionBuild
            | CapabilityName::WalletProfile
            | CapabilityName::LocalSigning
            | CapabilityName::HardwareVault
            | CapabilityName::UserAuthentication
            | CapabilityName::History
                if facts.wallet_composed && !facts.host_probe_completed =>
            {
                CapabilityProbe {
                    name,
                    supported: true,
                    available: false,
                    enabled: true,
                    runtime_ready: false,
                    not_ready_reason: Some(CapabilityReason::DependencyNotReady),
                }
            }
            CapabilityName::TransactionBuild if facts.wallet_composed => CapabilityProbe {
                name,
                supported: true,
                available: vault_device_available,
                enabled: true,
                runtime_ready: provider_is_usable && signing_ready,
                not_ready_reason: if !provider_is_usable {
                    Some(CapabilityReason::ChainUnsynced)
                } else {
                    signing_reason
                },
            },
            CapabilityName::WalletProfile if facts.wallet_composed => CapabilityProbe {
                name,
                supported: true,
                available: true,
                enabled: true,
                runtime_ready: facts.wallet_store_ready,
                not_ready_reason: (!facts.wallet_store_ready)
                    .then_some(CapabilityReason::StorageUnavailable),
            },
            CapabilityName::LocalSigning if facts.wallet_composed => CapabilityProbe {
                name,
                supported: true,
                available: vault_device_available,
                enabled: true,
                runtime_ready: signing_ready,
                not_ready_reason: signing_reason,
            },
            CapabilityName::HardwareVault | CapabilityName::UserAuthentication
                if facts.wallet_composed =>
            {
                CapabilityProbe {
                    name,
                    supported: true,
                    available: vault_device_available,
                    enabled: true,
                    runtime_ready: vault_ready,
                    not_ready_reason: vault_not_ready_reason,
                }
            }
            CapabilityName::History if facts.wallet_composed => CapabilityProbe {
                name,
                supported: true,
                available: true,
                enabled: true,
                runtime_ready: provider_is_usable && facts.history_store_ready,
                not_ready_reason: if !provider_is_usable {
                    Some(CapabilityReason::ChainUnsynced)
                } else {
                    (!facts.history_store_ready).then_some(CapabilityReason::StorageUnavailable)
                },
            },
            CapabilityName::BackgroundSync
                if facts.wallet_composed && facts.background_sync_composed =>
            {
                CapabilityProbe {
                    name,
                    supported: true,
                    available: true,
                    enabled: true,
                    runtime_ready: provider_is_usable && facts.history_store_ready,
                    not_ready_reason: if !provider_is_usable {
                        Some(CapabilityReason::ChainUnsynced)
                    } else {
                        (!facts.history_store_ready).then_some(CapabilityReason::StorageUnavailable)
                    },
                }
            }
            CapabilityName::TransactionBuild
            | CapabilityName::WalletProfile
            | CapabilityName::LocalSigning
            | CapabilityName::HardwareVault
            | CapabilityName::UserAuthentication
            | CapabilityName::History
            | CapabilityName::BackgroundSync => CapabilityProbe {
                name,
                supported: false,
                available: false,
                enabled: false,
                runtime_ready: false,
                not_ready_reason: None,
            },
        })
        .collect()
}

/// A stale status sample cannot keep chain capabilities open after provider
/// stop. Apart from the lifecycle gate, the provider's own `is_usable` field
/// is consumed verbatim; the ABI does not reinterpret peers or block heights.
pub const fn provider_runtime_ready(
    lifecycle: ProviderLifecycle,
    provider_is_usable: bool,
) -> bool {
    matches!(lifecycle, ProviderLifecycle::Running) && provider_is_usable
}

pub fn snapshot_to_abi(snapshot: &CapabilitySnapshot) -> CitizenSdkCapabilitySnapshot {
    let mut output = CitizenSdkCapabilitySnapshot {
        revision: snapshot.revision(),
        ..CitizenSdkCapabilitySnapshot::default()
    };
    for (index, status) in snapshot.statuses().iter().enumerate() {
        if let Some(slot) = output.statuses.get_mut(index) {
            *slot = status_to_abi(status);
        }
    }
    output
}

pub fn lifecycle_to_abi(lifecycle: EngineLifecycle) -> CitizenSdkLifecycle {
    match lifecycle {
        EngineLifecycle::Created => CitizenSdkLifecycle::Created,
        EngineLifecycle::ImportingState => CitizenSdkLifecycle::ImportingState,
        EngineLifecycle::Starting => CitizenSdkLifecycle::Starting,
        EngineLifecycle::Running => CitizenSdkLifecycle::Running,
        EngineLifecycle::StartFailed => CitizenSdkLifecycle::StartFailed,
        EngineLifecycle::Stopped => CitizenSdkLifecycle::Stopped,
        EngineLifecycle::Disposed => CitizenSdkLifecycle::Disposed,
    }
}

pub fn require_snapshot(snapshot: Option<CapabilitySnapshot>) -> FfiResult<CapabilitySnapshot> {
    snapshot.ok_or_else(|| FfiError::internal("Engine capability snapshot is missing"))
}

fn status_to_abi(status: &CapabilityStatus) -> CitizenSdkCapabilityStatus {
    CitizenSdkCapabilityStatus {
        name: name_to_abi(status.name()) as u32,
        reason: status
            .reason()
            .map_or(CitizenSdkCapabilityReason::None, reason_to_abi) as u32,
        supported: u8::from(status.supported()),
        available: u8::from(status.available()),
        enabled: u8::from(status.enabled()),
        ready: u8::from(status.is_ready()),
        reserved: [0; 4],
    }
}

const fn name_to_abi(name: CapabilityName) -> CitizenSdkCapabilityName {
    match name {
        CapabilityName::ChainRead => CitizenSdkCapabilityName::ChainRead,
        CapabilityName::TransactionBuild => CitizenSdkCapabilityName::TransactionBuild,
        CapabilityName::TransactionSubmit => CitizenSdkCapabilityName::TransactionSubmit,
        CapabilityName::TransactionVerify => CitizenSdkCapabilityName::TransactionVerify,
        CapabilityName::WalletProfile => CitizenSdkCapabilityName::WalletProfile,
        CapabilityName::LocalSigning => CitizenSdkCapabilityName::LocalSigning,
        CapabilityName::HardwareVault => CitizenSdkCapabilityName::HardwareVault,
        CapabilityName::UserAuthentication => CitizenSdkCapabilityName::UserAuthentication,
        CapabilityName::History => CitizenSdkCapabilityName::History,
        CapabilityName::BackgroundSync => CitizenSdkCapabilityName::BackgroundSync,
    }
}

const fn reason_to_abi(reason: CapabilityReason) -> CitizenSdkCapabilityReason {
    match reason {
        CapabilityReason::BuildUnsupported => CitizenSdkCapabilityReason::BuildUnsupported,
        CapabilityReason::DeviceUnavailable => CitizenSdkCapabilityReason::DeviceUnavailable,
        CapabilityReason::HostDisabled => CitizenSdkCapabilityReason::HostDisabled,
        CapabilityReason::EngineNotRunning => CitizenSdkCapabilityReason::EngineNotRunning,
        CapabilityReason::DependencyNotReady => CitizenSdkCapabilityReason::DependencyNotReady,
        CapabilityReason::UserAuthenticationRequired => {
            CitizenSdkCapabilityReason::UserAuthenticationRequired
        }
        CapabilityReason::VaultLocked => CitizenSdkCapabilityReason::VaultLocked,
        CapabilityReason::ChainStarting => CitizenSdkCapabilityReason::ChainStarting,
        CapabilityReason::ChainUnsynced => CitizenSdkCapabilityReason::ChainUnsynced,
        CapabilityReason::StorageUnavailable => CitizenSdkCapabilityReason::StorageUnavailable,
    }
}

#[cfg(test)]
mod tests {
    use citizen_sdk_contracts::{CapabilityName, CapabilityReason};
    use citizen_sdk_engine::CapabilityTracker;
    use citizen_sdk_smoldot_provider::{ProviderLifecycle, SmoldotProviderStatus};

    use super::{product_probes, provider_runtime_ready, ProductCapabilityFacts};

    fn status(lifecycle: ProviderLifecycle, is_usable: bool) -> SmoldotProviderStatus {
        SmoldotProviderStatus {
            lifecycle,
            peer_count: if is_usable { 4 } else { 0 },
            is_syncing: !is_usable,
            is_usable,
            best_block_number: 10,
            best_block_hash: [0x10; 32],
            verified_finalized_block_number: 9,
            verified_finalized_block_hash: [0x09; 32],
        }
    }

    #[test]
    fn provider_is_usable_is_the_only_chain_readiness_input() {
        let unusable = status(ProviderLifecycle::Running, false);
        let usable = status(ProviderLifecycle::Running, true);
        let stopped_with_stale_sample = status(ProviderLifecycle::Stopped, true);
        let mut tracker = CapabilityTracker::new();
        let first = tracker
            .update(product_probes(
                provider_runtime_ready(unusable.lifecycle, unusable.is_usable),
                ProductCapabilityFacts::chain_only(),
            ))
            .unwrap_or_else(|error| panic!("unusable snapshot failed: {error}"));
        let chain = first
            .status(CapabilityName::ChainRead)
            .unwrap_or_else(|| panic!("CHAIN_READ is missing"));
        assert!(!chain.is_ready());
        assert_eq!(chain.reason(), Some(CapabilityReason::ChainUnsynced));

        let second = tracker
            .update(product_probes(
                provider_runtime_ready(usable.lifecycle, usable.is_usable),
                ProductCapabilityFacts::chain_only(),
            ))
            .unwrap_or_else(|error| panic!("usable snapshot failed: {error}"));
        assert_eq!(second.revision(), first.revision() + 1);
        assert!(second
            .status(CapabilityName::ChainRead)
            .is_some_and(|value| value.is_ready()));
        assert!(second
            .status(CapabilityName::TransactionSubmit)
            .is_some_and(|value| value.is_ready()));
        assert!(!second
            .status(CapabilityName::TransactionBuild)
            .is_some_and(|value| value.is_ready()));

        let stopped = tracker
            .update(product_probes(
                provider_runtime_ready(
                    stopped_with_stale_sample.lifecycle,
                    stopped_with_stale_sample.is_usable,
                ),
                ProductCapabilityFacts::chain_only(),
            ))
            .unwrap_or_else(|error| panic!("stopped snapshot failed: {error}"));
        assert_eq!(stopped.revision(), second.revision() + 1);
        assert!(!stopped
            .status(CapabilityName::ChainRead)
            .is_some_and(|value| value.is_ready()));
    }

    #[test]
    fn configured_wallet_is_supported_but_not_ready_before_host_probe() {
        let probes = product_probes(false, ProductCapabilityFacts::wallet_configured());
        let wallet = probes
            .iter()
            .find(|probe| probe.name == CapabilityName::WalletProfile)
            .unwrap_or_else(|| panic!("WALLET_PROFILE is missing"));
        assert!(wallet.supported);
        assert!(!wallet.available);
        assert!(!wallet.runtime_ready);
        assert_eq!(
            wallet.not_ready_reason,
            Some(CapabilityReason::DependencyNotReady)
        );

        let chain = probes
            .iter()
            .find(|probe| probe.name == CapabilityName::ChainRead)
            .unwrap_or_else(|| panic!("CHAIN_READ is missing"));
        assert!(chain.supported);
        assert!(!chain.runtime_ready);
    }
}
