use std::sync::Arc;

use citizen_sdk_contracts::{
    CapabilityName, CapabilityReason, ChainDatabaseStore, ContractError, ContractErrorCode,
    ContractFuture, EncryptedSecretBlobSnapshot, EncryptedSecretBlobState,
    EncryptedSecretBlobStore, EncryptedSecretEnvelope, SecretBuffer, SecretRef, SecretVault,
    TransactionHistoryState, TransactionHistoryStore, VaultAvailability, VaultGeneration,
    WalletProfileStore, WalletState,
};
use citizen_sdk_engine::resolve_capabilities;
use citizen_sdk_smoldot_provider::SmoldotProviderConfig;

use crate::composition::{
    ProductComposition, ProductHostProviders, ProductWalletProviders, SessionChainDatabaseStore,
};

struct FakeVault {
    availability: VaultAvailability,
    has_wallet_key: bool,
}

impl SecretVault for FakeVault {
    fn availability(&self) -> ContractFuture<'_, VaultAvailability> {
        let availability = self.availability;
        Box::pin(async move { Ok(availability) })
    }

    fn seal(
        &self,
        _provisioning_operation_id: [u8; 16],
        _secret_ref: SecretRef,
        secret: SecretBuffer,
    ) -> ContractFuture<'_, EncryptedSecretEnvelope> {
        Box::pin(async move {
            drop(secret);
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "fake vault 不执行 seal",
            ))
        })
    }

    fn open(
        &self,
        _secret_ref: SecretRef,
        _envelope: EncryptedSecretEnvelope,
    ) -> ContractFuture<'_, SecretBuffer> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "fake vault 不执行 open",
            ))
        })
    }

    fn has_wallet_key(
        &self,
        _wallet_index: u32,
        _generation: VaultGeneration,
    ) -> ContractFuture<'_, bool> {
        let has_wallet_key = self.has_wallet_key;
        Box::pin(async move { Ok(has_wallet_key) })
    }

    fn delete_wallet_key(
        &self,
        _cleanup_operation_id: [u8; 16],
        _wallet_index: u32,
        _generation: VaultGeneration,
    ) -> ContractFuture<'_, ()> {
        Box::pin(async { Ok(()) })
    }
}

struct FakeWalletProfileStore {
    fail_load: bool,
}

impl WalletProfileStore for FakeWalletProfileStore {
    fn load(&self) -> ContractFuture<'_, WalletState> {
        let fail_load = self.fail_load;
        Box::pin(async move {
            if fail_load {
                Err(ContractError::new(
                    ContractErrorCode::Storage,
                    "fake wallet profile storage failure",
                ))
            } else {
                Ok(WalletState::empty())
            }
        })
    }

    fn compare_and_swap(
        &self,
        _expected_revision: u64,
        next: WalletState,
    ) -> ContractFuture<'_, WalletState> {
        Box::pin(async move { Ok(next) })
    }
}

struct FakeEncryptedSecretStore;

impl EncryptedSecretBlobStore for FakeEncryptedSecretStore {
    fn load(&self, _secret_ref: SecretRef) -> ContractFuture<'_, EncryptedSecretBlobSnapshot> {
        Box::pin(async { Ok(EncryptedSecretBlobSnapshot::empty()) })
    }

    fn compare_and_swap(
        &self,
        _secret_ref: SecretRef,
        expected_revision: u64,
        next: EncryptedSecretBlobState,
    ) -> ContractFuture<'_, EncryptedSecretBlobSnapshot> {
        Box::pin(async move {
            if expected_revision != 0 {
                return Err(ContractError::new(
                    ContractErrorCode::Conflict,
                    "fake encrypted-secret revision conflict",
                ));
            }
            EncryptedSecretBlobSnapshot::empty().try_advance(next)
        })
    }
}

struct FakeHistoryStore {
    fail_load: bool,
}

impl TransactionHistoryStore for FakeHistoryStore {
    fn load(&self) -> ContractFuture<'_, TransactionHistoryState> {
        let fail_load = self.fail_load;
        Box::pin(async move {
            if fail_load {
                Err(ContractError::new(
                    ContractErrorCode::Storage,
                    "fake history storage failure",
                ))
            } else {
                TransactionHistoryState::try_new(0, vec![], vec![], vec![])
            }
        })
    }

    fn compare_and_swap(
        &self,
        _expected_revision: u64,
        next: TransactionHistoryState,
    ) -> ContractFuture<'_, TransactionHistoryState> {
        Box::pin(async move { Ok(next) })
    }
}

fn provider_config(name: &str) -> SmoldotProviderConfig {
    let assets = crate::assets::verify_assets(
        include_bytes!("../../../assets/citizenchain/manifest.json"),
        include_bytes!("../../../assets/citizenchain/chainspec.json"),
        include_bytes!("../../../assets/citizenchain/light_sync_state.json"),
    )
    .unwrap_or_else(|error| panic!("asset verification failed: {error:?}"));
    SmoldotProviderConfig::try_new(
        assets.combined_chain_spec,
        name.to_owned(),
        "1.0.0".to_owned(),
    )
    .unwrap_or_else(|error| panic!("provider config failed: {error}"))
}

fn wallet_bundle(
    availability: VaultAvailability,
    profile_fails: bool,
    history_fails: bool,
) -> ProductWalletProviders {
    ProductWalletProviders::new(
        Arc::new(FakeVault {
            availability,
            has_wallet_key: true,
        }),
        Arc::new(FakeWalletProfileStore {
            fail_load: profile_fails,
        }),
        Arc::new(FakeEncryptedSecretStore),
        Arc::new(FakeHistoryStore {
            fail_load: history_fails,
        }),
    )
}

fn status(
    snapshot: &citizen_sdk_contracts::CapabilitySnapshot,
    name: CapabilityName,
) -> &citizen_sdk_contracts::CapabilityStatus {
    snapshot
        .status(name)
        .unwrap_or_else(|| panic!("capability {name:?} is missing"))
}

#[test]
fn public_abi_composition_is_truthfully_chain_only() {
    let composition = ProductComposition::try_new(
        provider_config("CitizenSDK-chain-only-test"),
        ProductHostProviders::public_abi_session(),
    )
    .unwrap_or_else(|error| panic!("chain-only composition failed: {error:?}"));
    let snapshot = composition
        .engine()
        .capabilities()
        .unwrap_or_else(|error| panic!("capability read failed: {error}"))
        .unwrap_or_else(|| panic!("capability snapshot missing"));

    for name in [
        CapabilityName::TransactionBuild,
        CapabilityName::WalletProfile,
        CapabilityName::LocalSigning,
        CapabilityName::HardwareVault,
        CapabilityName::UserAuthentication,
        CapabilityName::History,
        CapabilityName::BackgroundSync,
    ] {
        assert!(!status(&snapshot, name).supported(), "{name:?}");
        assert!(!status(&snapshot, name).enabled(), "{name:?}");
        assert!(!status(&snapshot, name).is_ready(), "{name:?}");
    }
}

#[test]
fn complete_wallet_bundle_derives_ready_wallet_facts_without_host_signer_or_nonce() {
    let composition = ProductComposition::try_new(
        provider_config("CitizenSDK-wallet-composition-test"),
        ProductHostProviders::new(
            Some(Arc::new(SessionChainDatabaseStore::new()) as Arc<dyn ChainDatabaseStore>),
            None,
            Some(wallet_bundle(VaultAvailability::Available, false, false)),
        ),
    )
    .unwrap_or_else(|error| panic!("wallet composition failed: {error:?}"));
    let engine_snapshot = composition
        .engine()
        .capabilities()
        .unwrap_or_else(|error| panic!("Engine capability read failed: {error}"))
        .unwrap_or_else(|| panic!("Engine capability snapshot missing"));
    for name in [
        CapabilityName::TransactionBuild,
        CapabilityName::WalletProfile,
        CapabilityName::LocalSigning,
        CapabilityName::HardwareVault,
        CapabilityName::UserAuthentication,
        CapabilityName::History,
    ] {
        assert!(status(&engine_snapshot, name).supported(), "{name:?}");
        assert!(status(&engine_snapshot, name).enabled(), "{name:?}");
    }

    let snapshot = resolve_capabilities(1, composition.capability_probes(true))
        .unwrap_or_else(|error| panic!("capability resolution failed: {error}"));

    for name in [
        CapabilityName::TransactionBuild,
        CapabilityName::WalletProfile,
        CapabilityName::LocalSigning,
        CapabilityName::HardwareVault,
        CapabilityName::UserAuthentication,
        CapabilityName::History,
    ] {
        assert!(status(&snapshot, name).supported(), "{name:?}");
        assert!(status(&snapshot, name).is_ready(), "{name:?}");
    }
    assert!(!status(&snapshot, CapabilityName::BackgroundSync).supported());
}

#[test]
fn unavailable_vault_fails_signing_and_build_closed() {
    let composition = ProductComposition::try_new(
        provider_config("CitizenSDK-unavailable-vault-test"),
        ProductHostProviders::new(
            None,
            None,
            Some(wallet_bundle(VaultAvailability::Unavailable, false, false)),
        ),
    )
    .unwrap_or_else(|error| panic!("wallet composition failed: {error:?}"));
    let snapshot = resolve_capabilities(1, composition.capability_probes(true))
        .unwrap_or_else(|error| panic!("capability resolution failed: {error}"));

    for name in [
        CapabilityName::TransactionBuild,
        CapabilityName::LocalSigning,
        CapabilityName::HardwareVault,
        CapabilityName::UserAuthentication,
    ] {
        let capability = status(&snapshot, name);
        assert!(capability.supported(), "{name:?}");
        assert!(!capability.is_ready(), "{name:?}");
        assert_eq!(
            capability.reason(),
            Some(CapabilityReason::DeviceUnavailable)
        );
    }
}

#[test]
fn wallet_storage_failure_fails_profile_signing_and_build_closed() {
    let composition = ProductComposition::try_new(
        provider_config("CitizenSDK-storage-failure-test"),
        ProductHostProviders::new(
            None,
            None,
            Some(wallet_bundle(VaultAvailability::Available, true, false)),
        ),
    )
    .unwrap_or_else(|error| panic!("wallet composition failed: {error:?}"));
    let snapshot = resolve_capabilities(1, composition.capability_probes(true))
        .unwrap_or_else(|error| panic!("capability resolution failed: {error}"));

    for name in [
        CapabilityName::TransactionBuild,
        CapabilityName::WalletProfile,
        CapabilityName::LocalSigning,
    ] {
        let capability = status(&snapshot, name);
        assert!(capability.supported(), "{name:?}");
        assert!(!capability.is_ready(), "{name:?}");
        assert_eq!(
            capability.reason(),
            Some(CapabilityReason::StorageUnavailable),
            "{name:?}"
        );
    }
    assert!(status(&snapshot, CapabilityName::History).is_ready());
}

#[test]
fn history_storage_failure_only_closes_history_dependents() {
    let composition = ProductComposition::try_new(
        provider_config("CitizenSDK-history-failure-test"),
        ProductHostProviders::new(
            None,
            None,
            Some(wallet_bundle(VaultAvailability::Available, false, true)),
        ),
    )
    .unwrap_or_else(|error| panic!("wallet composition failed: {error:?}"));
    let snapshot = resolve_capabilities(1, composition.capability_probes(true))
        .unwrap_or_else(|error| panic!("capability resolution failed: {error}"));

    assert!(status(&snapshot, CapabilityName::LocalSigning).is_ready());
    assert!(!status(&snapshot, CapabilityName::History).is_ready());
    assert_eq!(
        status(&snapshot, CapabilityName::History).reason(),
        Some(CapabilityReason::StorageUnavailable)
    );
}

#[test]
fn session_chain_database_uses_monotonic_cas_without_wallet_state() {
    let store = SessionChainDatabaseStore::new();
    let initial = futures_executor::block_on(store.load())
        .unwrap_or_else(|error| panic!("session load failed: {error}"));
    assert_eq!(initial.revision(), 0);
    assert!(initial.state().is_none());

    let next = futures_executor::block_on(store.compare_and_swap(0, None))
        .unwrap_or_else(|error| panic!("session CAS failed: {error}"));
    assert_eq!(next.revision(), 1);
    assert!(next.state().is_none());

    let stale = futures_executor::block_on(store.compare_and_swap(0, None))
        .err()
        .unwrap_or_else(|| panic!("stale session CAS must fail"));
    assert_eq!(stale.code(), ContractErrorCode::Conflict);
}
