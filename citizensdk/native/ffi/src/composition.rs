//! CitizenSDK 产品内部组合边界。
//!
//! 宿主只注入平台存储与系统金库合同，不能注入 signer、nonce 来源或链客户端。
//! `ProductWalletProviders` 在类型上把四个钱包依赖绑定成一组，避免半套钱包在生产
//! 组合中被误报为可用。`citizensdk_create` 使用
//! [`ProductHostProviders::public_abi_session`] 的 chain-only 组合；
//! `citizensdk_create_with_host` 则复制并验证宿主的持久化/金库 vtable，完整钱包 bundle
//! 缺任一项都会失败关闭。本模块不会创建进程内钱包、密文或金库替身。

use std::sync::{Arc, Mutex};

use citizen_sdk_contracts::{
    ChainDatabaseSnapshot, ChainDatabaseStore, ChainSigner, ContractError, ContractErrorCode,
    ContractFuture, EncryptedSecretBlobStore, ExportedChainState, RuntimeCacheStore, SecretVault,
    TransactionHistoryStore, VaultAvailability, WalletProfileStore,
};
use citizen_sdk_engine::{CitizenEngine, EngineComponents};
use citizen_sdk_smoldot_provider::{SmoldotProviderConfig, SmoldotVerifiedChainClient};
use citizen_signer::Sr25519SoftwareSigner;

use crate::{
    abi::CitizenSdkHostServicesV1,
    capabilities::{product_probes, ProductCapabilityFacts},
    error::{FfiError, FfiResult},
    host_providers::HostServicesAdapter,
};

/// 当前公开 ABI 会话的公开链数据库信封。
///
/// 它只承接同一 `CitizenSdkHandle` 生命周期内的 import/export CAS，不耐久，也不允许
/// 钱包资料、交易历史、密文或秘密进入。真正的平台耐久实现必须单独履行
/// `ChainDatabaseStore`，不能把本类型描述成设备数据库。
pub(crate) struct SessionChainDatabaseStore {
    snapshot: Mutex<ChainDatabaseSnapshot>,
}

impl SessionChainDatabaseStore {
    pub(crate) fn new() -> Self {
        Self::default()
    }
}

impl Default for SessionChainDatabaseStore {
    fn default() -> Self {
        Self {
            snapshot: Mutex::new(ChainDatabaseSnapshot::new(0, None)),
        }
    }
}

impl ChainDatabaseStore for SessionChainDatabaseStore {
    fn load(&self) -> ContractFuture<'_, ChainDatabaseSnapshot> {
        let result = self
            .snapshot
            .lock()
            .map(|snapshot| snapshot.clone())
            .map_err(|_| {
                ContractError::new(
                    ContractErrorCode::Internal,
                    "CitizenSDK 会话链数据库状态已损坏",
                )
            });
        Box::pin(async move { result })
    }

    fn compare_and_swap(
        &self,
        expected_revision: u64,
        state: Option<ExportedChainState>,
    ) -> ContractFuture<'_, ChainDatabaseSnapshot> {
        let result = self.snapshot.lock().map_err(|_| {
            ContractError::new(
                ContractErrorCode::Internal,
                "CitizenSDK 会话链数据库状态已损坏",
            )
        });
        let result = result.and_then(|mut snapshot| {
            if snapshot.revision() != expected_revision {
                return Err(ContractError::new(
                    ContractErrorCode::Conflict,
                    "CitizenSDK 会话链数据库 CAS revision 已变化",
                ));
            }
            let revision = expected_revision.checked_add(1).ok_or_else(|| {
                ContractError::new(
                    ContractErrorCode::Internal,
                    "CitizenSDK 会话链数据库 revision 已耗尽",
                )
            })?;
            *snapshot = ChainDatabaseSnapshot::new(revision, state);
            Ok(snapshot.clone())
        });
        Box::pin(async move { result })
    }
}

/// 平台必须整组提供的钱包安全边界。
///
/// 四个字段都没有 `Option`：金库、公开 profile、设备密文与交易历史任何一个缺失，
/// 调用方就只能选择“不组合钱包”。signer 与 nonce 来源故意不在本结构中，宿主无权
/// 替换 CitizenSDK 的 sr25519 口径或绑定准确 best Runtime 的 nonce 实现。
#[derive(Clone)]
pub(crate) struct ProductWalletProviders {
    secret_vault: Arc<dyn SecretVault>,
    wallet_profiles: Arc<dyn WalletProfileStore>,
    encrypted_secrets: Arc<dyn EncryptedSecretBlobStore>,
    transaction_history: Arc<dyn TransactionHistoryStore>,
}

impl ProductWalletProviders {
    pub(crate) fn new(
        secret_vault: Arc<dyn SecretVault>,
        wallet_profiles: Arc<dyn WalletProfileStore>,
        encrypted_secrets: Arc<dyn EncryptedSecretBlobStore>,
        transaction_history: Arc<dyn TransactionHistoryStore>,
    ) -> Self {
        Self {
            secret_vault,
            wallet_profiles,
            encrypted_secrets,
            transaction_history,
        }
    }
}

/// 宿主可提供的类型化持久化边界。
///
/// 公开轻节点数据库与 runtime cache 相互独立；钱包只有完整 bundle 一个可选项。这里
/// 没有任意键值仓储，也没有可装入秘密字节的通用容器。
pub(crate) struct ProductHostProviders {
    chain_database: Option<Arc<dyn ChainDatabaseStore>>,
    runtime_cache: Option<Arc<dyn RuntimeCacheStore>>,
    wallet: Option<ProductWalletProviders>,
}

impl ProductHostProviders {
    /// 当前 `citizensdk_create` 的真实组合：只提供非耐久公开链会话状态，不提供钱包。
    pub(crate) fn public_abi_session() -> Self {
        let chain_database: Arc<dyn ChainDatabaseStore> =
            Arc::new(SessionChainDatabaseStore::new());
        Self {
            chain_database: Some(chain_database),
            runtime_cache: None,
            wallet: None,
        }
    }

    /// 平台绑定必须按这一完整形状组合；钱包四个依赖不允许逐项可选。
    /// signer 与准确 Runtime nonce 仍由 CitizenSDK 内部固定，宿主不能替换。
    pub(crate) fn new(
        chain_database: Option<Arc<dyn ChainDatabaseStore>>,
        runtime_cache: Option<Arc<dyn RuntimeCacheStore>>,
        wallet: Option<ProductWalletProviders>,
    ) -> Self {
        Self {
            chain_database,
            runtime_cache,
            wallet,
        }
    }
}

/// 一个 SDK 实例唯一拥有的 provider、Engine 与产品组件事实。
pub(crate) struct ProductComposition {
    provider: Arc<SmoldotVerifiedChainClient>,
    engine: Arc<CitizenEngine>,
    wallet: Option<ProductWalletProviders>,
    /// Keeps copied host callbacks and their process-global pending-operation
    /// owner alive for the complete SDK instance lifetime.
    host_services: Option<HostServicesAdapter>,
}

impl ProductComposition {
    /// 构造当前公开 ABI 的 chain-only 产品实例。
    pub(crate) fn public_abi(
        combined_chain_spec: String,
        system_name: String,
        system_version: String,
    ) -> FfiResult<Self> {
        let config =
            SmoldotProviderConfig::try_new(combined_chain_spec, system_name, system_version)?
                .with_bootstrap();
        Self::try_new(config, ProductHostProviders::public_abi_session())
    }

    /// Constructs the persistent host-backed product composition.
    ///
    /// # Safety
    /// Nested host vtable pointers must be readable for this call. Their
    /// copied callback contexts/code must remain valid and thread-safe until
    /// successful instance destruction returns.
    pub(crate) unsafe fn host_abi(
        combined_chain_spec: String,
        system_name: String,
        system_version: String,
        services: &CitizenSdkHostServicesV1,
    ) -> FfiResult<Self> {
        // SAFETY: forwarded from this constructor's documented caller
        // contract; adapter construction copies every validated vtable.
        let adapter =
            unsafe { HostServicesAdapter::try_from_ffi(services) }.map_err(FfiError::from)?;
        let wallet_profiles = adapter.wallet_profile_store();
        let encrypted_secrets = adapter.encrypted_secret_blob_store();
        let secret_vault = adapter.secret_vault();
        let wallet = match (secret_vault, wallet_profiles, encrypted_secrets) {
            (Some(secret_vault), Some(wallet_profiles), Some(encrypted_secrets)) => {
                Some(ProductWalletProviders::new(
                    secret_vault,
                    wallet_profiles,
                    encrypted_secrets,
                    adapter.transaction_history_store(),
                ))
            }
            (None, None, None) => None,
            _ => {
                return Err(FfiError::internal(
                    "validated host wallet providers are not all-or-none",
                ));
            }
        };
        let host = ProductHostProviders::new(
            Some(adapter.chain_database_store()),
            Some(adapter.runtime_cache_store()),
            wallet,
        );
        let config =
            SmoldotProviderConfig::try_new(combined_chain_spec, system_name, system_version)?
                .with_bootstrap();
        let mut composition = Self::try_new(config, host)?;
        composition.host_services = Some(adapter);
        Ok(composition)
    }

    /// 组合一个真实 provider 与宿主的类型化平台边界。
    ///
    /// wallet 存在时，signer 固定为 SDK 内唯一 [`Sr25519SoftwareSigner`]，nonce 固定从
    /// 同一个 smoldot provider Arc 取得；二者都不在宿主参数中，因此不能被替换。
    pub(crate) fn try_new(
        provider_config: SmoldotProviderConfig,
        host: ProductHostProviders,
    ) -> FfiResult<Self> {
        let provider = SmoldotVerifiedChainClient::new(provider_config)?;
        let chain_client = provider.as_verified_chain_client();

        let signer: Option<Arc<dyn ChainSigner>> = host
            .wallet
            .as_ref()
            .map(|_| Arc::new(Sr25519SoftwareSigner) as Arc<dyn ChainSigner>);
        let secret_vault = host
            .wallet
            .as_ref()
            .map(|wallet| Arc::clone(&wallet.secret_vault));
        let wallet_profiles = host
            .wallet
            .as_ref()
            .map(|wallet| Arc::clone(&wallet.wallet_profiles));
        let transaction_history = host
            .wallet
            .as_ref()
            .map(|wallet| Arc::clone(&wallet.transaction_history));
        let encrypted_secrets = host
            .wallet
            .as_ref()
            .map(|wallet| Arc::clone(&wallet.encrypted_secrets));

        let mut components = EngineComponents::new(
            chain_client,
            signer,
            secret_vault,
            host.chain_database,
            host.runtime_cache,
            wallet_profiles,
            transaction_history,
            encrypted_secrets,
        );
        if host.wallet.is_some() {
            components = components.with_account_nonce_source(provider.as_account_nonce_source());
        }

        let engine = Arc::new(CitizenEngine::new(components));
        let composition = Self {
            provider,
            engine,
            wallet: host.wallet,
            host_services: None,
        };
        // 构造是同步 ABI，不能在这里调用可能异步完成的宿主存储或系统金库；否则
        // Android/iOS 主线程可能等待一个必须回到同一线程的 completion。这里只提交
        // “已完整组合但尚未探测”的事实，第一次工作线程 refresh 再读取真实 readiness。
        let initial_facts = if composition.wallet.is_some() {
            ProductCapabilityFacts::wallet_configured()
        } else {
            ProductCapabilityFacts::chain_only()
        };
        composition
            .engine
            .update_capabilities(product_probes(false, initial_facts))?;
        Ok(composition)
    }

    pub(crate) fn engine(&self) -> &Arc<CitizenEngine> {
        &self.engine
    }

    pub(crate) fn provider(&self) -> &Arc<SmoldotVerifiedChainClient> {
        &self.provider
    }

    /// Distinguishes the new persistent host constructor from the unchanged
    /// legacy session constructor. Only the former may add automatic
    /// store-restore/persist behavior to the original lifecycle ABI calls.
    pub(crate) const fn uses_host_services(&self) -> bool {
        self.host_services.is_some()
    }

    /// Orphaned host operations can outlive a cancelled Engine future. They
    /// retain Rust-owned buffers and the host callback contract, so destroy
    /// must remain recoverably busy until their one completion arrives.
    pub(crate) fn require_no_pending_host_operations(&self) -> FfiResult<()> {
        let Some(host) = self.host_services.as_ref() else {
            return Ok(());
        };
        if host.pending_host_operations().map_err(FfiError::from)? == 0 {
            Ok(())
        } else {
            Err(FfiError::new(
                crate::abi::CitizenSdkErrorCode::Busy,
                "host operations are still pending; retry destroy after completion",
            ))
        }
    }

    /// Freezes host-operation reservation before destroy preflight scans the
    /// pending registry. The adapter linearizes this gate with insertion, so a
    /// successful close cannot be followed by an unobserved reservation.
    pub(crate) fn close_host_operation_gate(&self) -> FfiResult<()> {
        self.host_services
            .as_ref()
            .map_or(Ok(()), |host| host.close_host_operation_gate())
            .map_err(FfiError::from)
    }

    /// Restores a gate closed by a recoverable destroy preflight. This is used
    /// only before teardown side effects, while the instance must remain fully
    /// usable after returning `BUSY`.
    pub(crate) fn reopen_host_operation_gate(&self) -> FfiResult<()> {
        self.host_services
            .as_ref()
            .map_or(Ok(()), |host| host.reopen_host_operation_gate())
            .map_err(FfiError::from)
    }

    /// 从真实平台组件读取能力事实。任何 vault 或持久化读取异常都只会关闭相关能力，
    /// 绝不会用“组件存在”冒充“组件可用”。
    pub(crate) fn capability_probes(
        &self,
        provider_is_usable: bool,
    ) -> Vec<citizen_sdk_engine::CapabilityProbe> {
        product_probes(provider_is_usable, self.wallet_capability_facts())
    }

    /// 在 provider 停止前关闭并排空产品侧后台工作。
    ///
    /// NativeRuntime 已先取消并 join 自有调度线程；此处等待 Engine 的真实存储租约
    /// 和 provider 的 unsubscribe 应答，之后调用者才允许 remove_chain。
    pub(crate) fn stop_and_drain_product_services(&self) -> FfiResult<()> {
        self.engine.stop_chain_monitor()?;
        self.provider
            .drive(self.engine.drain_chain_monitor())?
            .map_err(FfiError::from)?;
        if matches!(
            self.provider.lifecycle(),
            Ok(citizen_sdk_smoldot_provider::ProviderLifecycle::Running)
        ) {
            self.provider
                .drive(self.provider.drain_finalized_subscriptions())?
                .map_err(FfiError::from)?;
        }
        Ok(())
    }

    pub(crate) fn has_wallet_services(&self) -> bool {
        self.wallet.is_some()
    }

    fn wallet_capability_facts(&self) -> ProductCapabilityFacts {
        let Some(wallet) = self.wallet.as_ref() else {
            return ProductCapabilityFacts::chain_only();
        };

        let vault_availability = match self.provider.drive(wallet.secret_vault.availability()) {
            Ok(Ok(availability)) => availability,
            Ok(Err(_)) | Err(_) => VaultAvailability::Unavailable,
        };

        let wallet_state = self
            .provider
            .drive(wallet.wallet_profiles.load())
            .ok()
            .and_then(Result::ok);
        let wallet_store_ready = wallet_state.is_some();

        // 空钱包仍可以创建；已有 profile 时，每个账户必须已有精确 sealed envelope，
        // 否则 local signing / transaction build 立即失败关闭。
        let encrypted_secrets_ready = wallet_state.as_ref().is_some_and(|state| {
            state.profile().is_none_or(|profile| {
                profile.accounts().iter().all(|account| {
                    matches!(
                        self.provider
                            .drive(wallet.encrypted_secrets.load(account.secret_ref())),
                        Ok(Ok(snapshot)) if snapshot.envelope().is_some()
                    )
                })
            })
        });

        // availability 不是 Available 时不继续触碰硬件 key 查询，避免能力刷新触发无谓
        // 平台调用；相关能力使用 vault 的稳定失败原因关闭。
        let wallet_key_ready = vault_availability == VaultAvailability::Available
            && wallet_state.as_ref().is_some_and(|state| {
                state.profile().is_none_or(|profile| {
                    matches!(
                        self.provider.drive(
                            wallet
                                .secret_vault
                                .has_wallet_key(profile.wallet_index(), profile.generation())
                        ),
                        Ok(Ok(true))
                    )
                })
            });

        let history_store_ready = matches!(
            self.provider.drive(wallet.transaction_history.load()),
            Ok(Ok(_))
        );

        ProductCapabilityFacts::wallet(
            vault_availability,
            wallet_store_ready,
            encrypted_secrets_ready,
            wallet_key_ready,
            history_store_ready,
            false,
        )
    }
}
