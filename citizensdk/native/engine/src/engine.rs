use std::{
    future::Future,
    pin::Pin,
    sync::{Arc, Mutex},
};

use citizen_sdk_contracts::{
    store::{
        ChainDatabaseSnapshot, ChainDatabaseStore, EncryptedSecretBlobStore, RuntimeCacheStore,
        TransactionHistoryState, TransactionHistoryStore, WalletProfileStore,
    },
    AccountId32, AccountNonce, AccountNonceSource, CapabilityName, CapabilityReason,
    CapabilitySnapshot, ChainSigner, ContractErrorCode, ExecutionConclusion, ExportedChainState,
    ExtrinsicWatchEvent, FinalizedAccountBalance, FinalizedBlockRef, Hash32, RuntimeContext,
    SecretBuffer, SecretVault, SignedExtrinsic, Sr25519Signature, StateImportReceipt,
    SubmittedExtrinsic, UnverifiedReason, VerifiedBlockRef, VerifiedChainClient, WalletProfile,
};
use zeroize::Zeroizing;

use crate::{
    account_state::{AccountStateService, BestFeeSnapshot},
    capabilities::{CapabilityProbe, CapabilityTracker},
    error::EngineError,
    finalized_events::SYSTEM_EVENTS_STORAGE_KEY,
    finalized_history_runtime::{FinalizedHistoryRunGuard, FinalizedHistoryRuntime},
    runtime_context::RuntimeContextCache,
    state_import::{
        validate_import_startup, validate_state_export, validate_state_import, EngineLifecycle,
        StateImportPolicy, StateImportRejection,
    },
    transaction_history::TransactionHistoryService,
    transaction_outcome::{verify_transaction_outcome, TransactionEvidence},
    wallet_derivation::{SystemWalletEntropy, WalletWordCount},
    wallet_service::{PreparedWalletCreation, SystemWalletClock, WalletService},
    wallet_transfer_watch::{
        watch_recorded_transfer, NoopWalletTransferObserver, WalletTransferObserver,
        WalletTransferWatchResult,
    },
};

/// Engine async return type; the embedding layer chooses the executor.
pub type EngineFuture<'a, T> = Pin<Box<dyn Future<Output = Result<T, EngineError>> + Send + 'a>>;

/// Typed providers and stores available in one host composition.
///
/// Wallet and history components are optional so a read-only host can expose a
/// truthful reduced capability set without fake implementations. The chain
/// client is mandatory because this crate is the CitizenChain Engine.
pub struct EngineComponents {
    chain_client: Arc<dyn VerifiedChainClient>,
    signer: Option<Arc<dyn ChainSigner>>,
    secret_vault: Option<Arc<dyn SecretVault>>,
    chain_database: Option<Arc<dyn ChainDatabaseStore>>,
    runtime_cache: Option<Arc<dyn RuntimeCacheStore>>,
    wallet_profiles: Option<Arc<dyn WalletProfileStore>>,
    transaction_history: Option<Arc<dyn TransactionHistoryStore>>,
    encrypted_secrets: Option<Arc<dyn EncryptedSecretBlobStore>>,
    account_nonce_source: Option<Arc<dyn AccountNonceSource>>,
}

impl EngineComponents {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        chain_client: Arc<dyn VerifiedChainClient>,
        signer: Option<Arc<dyn ChainSigner>>,
        secret_vault: Option<Arc<dyn SecretVault>>,
        chain_database: Option<Arc<dyn ChainDatabaseStore>>,
        runtime_cache: Option<Arc<dyn RuntimeCacheStore>>,
        wallet_profiles: Option<Arc<dyn WalletProfileStore>>,
        transaction_history: Option<Arc<dyn TransactionHistoryStore>>,
        encrypted_secrets: Option<Arc<dyn EncryptedSecretBlobStore>>,
    ) -> Self {
        Self {
            chain_client,
            signer,
            secret_vault,
            chain_database,
            runtime_cache,
            wallet_profiles,
            transaction_history,
            encrypted_secrets,
            account_nonce_source: None,
        }
    }

    /// 注入绑定准确 best Runtime 的 CitizenChain AccountNonceApi provider。
    ///
    /// 该 API 不是交易池感知 nonce；钱包广播安全由历史仓储中同账户 durable
    /// single-flight pending CAS 门保证。保留构造函数原签名，避免尚未切换的
    /// FFI/测试被迫伪造实现。
    pub fn with_account_nonce_source(
        mut self,
        account_nonce_source: Arc<dyn AccountNonceSource>,
    ) -> Self {
        self.account_nonce_source = Some(account_nonce_source);
        self
    }

    pub(crate) fn chain_client(&self) -> &Arc<dyn VerifiedChainClient> {
        &self.chain_client
    }

    pub(crate) fn runtime_cache(&self) -> Option<&Arc<dyn RuntimeCacheStore>> {
        self.runtime_cache.as_ref()
    }

    pub(crate) fn chain_database(&self) -> Option<&Arc<dyn ChainDatabaseStore>> {
        self.chain_database.as_ref()
    }

    pub(crate) fn signer(&self) -> Option<&Arc<dyn ChainSigner>> {
        self.signer.as_ref()
    }

    pub(crate) fn secret_vault(&self) -> Option<&Arc<dyn SecretVault>> {
        self.secret_vault.as_ref()
    }

    pub(crate) fn wallet_profiles(&self) -> Option<&Arc<dyn WalletProfileStore>> {
        self.wallet_profiles.as_ref()
    }

    pub(crate) fn transaction_history(&self) -> Option<&Arc<dyn TransactionHistoryStore>> {
        self.transaction_history.as_ref()
    }

    pub(crate) fn encrypted_secrets(&self) -> Option<&Arc<dyn EncryptedSecretBlobStore>> {
        self.encrypted_secrets.as_ref()
    }

    pub(crate) fn account_nonce_source(&self) -> Option<&Arc<dyn AccountNonceSource>> {
        self.account_nonce_source.as_ref()
    }

    /// 是否注入了任何 SDK 热钱包交易栈组件。
    ///
    /// 只要宿主开始组合钱包能力，原始 signed-extrinsic 提交入口就必须服从
    /// pending-before-broadcast 合同，不能因组件只装配了一部分而退回无历史旁路。
    fn has_any_wallet_transaction_component(&self) -> bool {
        self.signer.is_some()
            || self.secret_vault.is_some()
            || self.wallet_profiles.is_some()
            || self.encrypted_secrets.is_some()
            || self.account_nonce_source.is_some()
    }

    fn enforce_component_presence(&self, probes: &mut [CapabilityProbe]) {
        for probe in probes {
            let present = match probe.name {
                CapabilityName::WalletProfile => self.wallet_profiles.is_some(),
                CapabilityName::LocalSigning => {
                    self.signer.is_some()
                        && self.secret_vault.is_some()
                        && self.wallet_profiles.is_some()
                        && self.encrypted_secrets.is_some()
                }
                CapabilityName::HardwareVault => self.secret_vault.is_some(),
                CapabilityName::History => self.transaction_history.is_some(),
                CapabilityName::BackgroundSync => {
                    self.chain_database.is_some() && self.transaction_history.is_some()
                }
                CapabilityName::TransactionBuild => {
                    self.account_nonce_source.is_some()
                        && self.signer.is_some()
                        && self.secret_vault.is_some()
                        && self.wallet_profiles.is_some()
                        && self.encrypted_secrets.is_some()
                }
                CapabilityName::ChainRead
                | CapabilityName::TransactionSubmit
                | CapabilityName::TransactionVerify => true,
                CapabilityName::UserAuthentication => self.secret_vault.is_some(),
            };
            if !present {
                // 组件未注入是宿主组合选择，不得误报成设备硬件不可用。
                probe.enabled = false;
                probe.runtime_ready = false;
            }
        }
    }
}

/// Product-independent CitizenSDK Core Engine.
pub struct CitizenEngine {
    components: EngineComponents,
    runtime_contexts: Mutex<RuntimeContextCache>,
    capabilities: Mutex<EngineCapabilityState>,
    state: Arc<Mutex<EngineState>>,
}

#[derive(Default)]
struct EngineCapabilityState {
    tracker: CapabilityTracker,
    /// 已完成宿主组件过滤、尚未叠加 Engine 生命周期的原始事实。
    base_probes: Option<Vec<CapabilityProbe>>,
}

#[derive(Debug)]
struct EngineState {
    lifecycle: EngineLifecycle,
    generation: u64,
    provisional_import: Option<FinalizedBlockRef>,
    verified_finalized: Option<FinalizedBlockRef>,
    export_in_progress: bool,
    /// 已取得生命周期租约、尚未完成全部 provider/store await 的历史操作数。
    ///
    /// finalized 历史的一次原子提交可能跨越多个 await。stop/dispose 只有在这里为
    /// 0 时才能切换代际，从而保证最后一个 CAS 也不能穿越 Engine 停止边界。
    inflight_history_operations: u64,
}

impl Default for EngineState {
    fn default() -> Self {
        Self {
            lifecycle: EngineLifecycle::Created,
            generation: 0,
            provisional_import: None,
            verified_finalized: None,
            export_in_progress: false,
            inflight_history_operations: 0,
        }
    }
}

impl CitizenEngine {
    pub fn new(components: EngineComponents) -> Self {
        Self {
            components,
            runtime_contexts: Mutex::new(RuntimeContextCache::new()),
            capabilities: Mutex::new(EngineCapabilityState::default()),
            state: Arc::new(Mutex::new(EngineState::default())),
        }
    }

    /// Atomically replace host/provider capability facts. Revision ownership
    /// remains inside the Engine so bindings cannot create divergent counters.
    pub fn update_capabilities(
        &self,
        mut probes: Vec<CapabilityProbe>,
    ) -> Result<CapabilitySnapshot, EngineError> {
        self.components.enforce_component_presence(&mut probes);
        // 所有同时观察 lifecycle/capabilities 的路径统一按 state -> capabilities
        // 加锁，避免 stop/dispose 与宿主 probe 更新交错后发布过期的 Running 快照。
        let state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        let effective = probes_for_lifecycle(probes.clone(), state.lifecycle);
        let mut capabilities = self
            .capabilities
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        let snapshot = capabilities.tracker.update(effective)?;
        capabilities.base_probes = Some(probes);
        Ok(snapshot)
    }

    pub fn capabilities(&self) -> Result<Option<CapabilitySnapshot>, EngineError> {
        let _state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        Ok(self
            .capabilities
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?
            .tracker
            .current()
            .cloned())
    }

    /// Current Engine-owned lifecycle. Bindings may observe it but cannot set
    /// it to bypass state import gates.
    pub fn lifecycle(&self) -> Result<EngineLifecycle, EngineError> {
        Ok(self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?
            .lifecycle)
    }

    /// Read the provider's verified best head through the Engine capability
    /// and lifecycle gate. Bindings must use this method instead of retaining
    /// or exposing the provider itself.
    pub fn best_head(&self) -> EngineFuture<'_, VerifiedBlockRef> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            self.components
                .chain_client()
                .get_best_head()
                .await
                .map_err(EngineError::from)
        })
    }

    /// Read the provider's independently verified finalized head.
    pub fn finalized_head(&self) -> EngineFuture<'_, FinalizedBlockRef> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            self.components
                .chain_client()
                .get_finalized_head()
                .await
                .map_err(EngineError::from)
        })
    }

    /// Read one storage key at one exact, provider-verified block.
    pub fn storage_at(
        &self,
        block: VerifiedBlockRef,
        key: Vec<u8>,
    ) -> EngineFuture<'_, Option<Vec<u8>>> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            self.components
                .chain_client()
                .get_storage_at(block, key)
                .await
                .map_err(EngineError::from)
        })
    }

    /// Read a batch of storage keys at one exact block while preserving input
    /// order and duplicate entries.
    pub fn storage_batch_at(
        &self,
        block: VerifiedBlockRef,
        keys: Vec<Vec<u8>>,
    ) -> EngineFuture<'_, Vec<Option<Vec<u8>>>> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            self.components
                .chain_client()
                .get_storage_batch_at(block, keys)
                .await
                .map_err(EngineError::from)
        })
    }

    /// 从准确 finalized `System.Account` 读取一个账户的公开余额。
    pub fn finalized_account_balance(
        &self,
        account_id: AccountId32,
    ) -> EngineFuture<'_, FinalizedAccountBalance> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            AccountStateService::new(
                self.components.chain_client().as_ref(),
                self.components
                    .account_nonce_source()
                    .map(|source| source.as_ref()),
            )
            .finalized_account_balance(account_id)
            .await
        })
    }

    /// 批量余额保持输入顺序和重复项，底层只请求去重后的 storage key。
    pub fn finalized_account_balances(
        &self,
        account_ids: Vec<AccountId32>,
    ) -> EngineFuture<'_, Vec<FinalizedAccountBalance>> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            AccountStateService::new(
                self.components.chain_client().as_ref(),
                self.components
                    .account_nonce_source()
                    .map(|source| source.as_ref()),
            )
            .finalized_account_balances(account_ids)
            .await
        })
    }

    /// 读取绑定准确 best Runtime 的链 nonce；同账户并发由 durable pending 门串行化。
    pub fn account_next_index(&self, account_id: AccountId32) -> EngineFuture<'_, AccountNonce> {
        Box::pin(async move {
            self.require_capabilities(&[
                CapabilityName::ChainRead,
                CapabilityName::TransactionBuild,
            ])?;
            AccountStateService::new(
                self.components.chain_client().as_ref(),
                self.components
                    .account_nonce_source()
                    .map(|source| source.as_ref()),
            )
            .account_next_index(account_id)
            .await
        })
    }

    /// 从同一准确 best Runtime metadata 解码费率、最低费和存在性存款。
    pub fn best_fee_snapshot(&self) -> EngineFuture<'_, BestFeeSnapshot> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            AccountStateService::new(
                self.components.chain_client().as_ref(),
                self.components
                    .account_nonce_source()
                    .map(|source| source.as_ref()),
            )
            .best_fee_snapshot()
            .await
        })
    }

    /// 读取不含秘密的钱包公开资料；轻节点尚未启动时也可使用本机钱包能力。
    pub fn wallet_profile(&self) -> EngineFuture<'_, Option<WalletProfile>> {
        let service = self.local_wallet_service(&[CapabilityName::WalletProfile]);
        Box::pin(async move { service?.profile().await })
    }

    /// 对硬件密钥、全部密文和 child 公钥做一次完整核验。
    pub fn usable_wallet_profile(&self) -> EngineFuture<'_, Option<WalletProfile>> {
        let service = self.local_wallet_service(&[
            CapabilityName::WalletProfile,
            CapabilityName::LocalSigning,
            CapabilityName::HardwareVault,
            CapabilityName::UserAuthentication,
        ]);
        Box::pin(async move { service?.usable_profile().await })
    }

    /// 生成一次性恢复词会话；准备阶段不会写入 profile、密文或硬件 KEK。
    pub fn prepare_wallet_creation(
        &self,
        word_count: WalletWordCount,
        password: Zeroizing<String>,
    ) -> EngineFuture<'_, PreparedWalletCreation> {
        let service = self.local_wallet_service(&[
            CapabilityName::WalletProfile,
            CapabilityName::LocalSigning,
            CapabilityName::HardwareVault,
            CapabilityName::UserAuthentication,
        ]);
        Box::pin(async move { service?.prepare_create(word_count, password).await })
    }

    /// 用户确认已经备份恢复词后消费会话并提交钱包。
    pub fn commit_wallet_creation_after_backup(
        &self,
        prepared: PreparedWalletCreation,
    ) -> EngineFuture<'_, WalletProfile> {
        let service = self.local_wallet_service(&[
            CapabilityName::WalletProfile,
            CapabilityName::LocalSigning,
            CapabilityName::HardwareVault,
            CapabilityName::UserAuthentication,
        ]);
        Box::pin(async move { service?.commit_create_after_backup(prepared).await })
    }

    pub fn import_wallet(
        &self,
        mnemonic: SecretBuffer,
        password: Zeroizing<String>,
    ) -> EngineFuture<'_, WalletProfile> {
        let service = self.local_wallet_service(&[
            CapabilityName::WalletProfile,
            CapabilityName::LocalSigning,
            CapabilityName::HardwareVault,
            CapabilityName::UserAuthentication,
        ]);
        Box::pin(async move { service?.import(&mnemonic, &password).await })
    }

    pub fn add_wallet_accounts(
        &self,
        mnemonic: SecretBuffer,
        password: Zeroizing<String>,
        indices: Vec<u32>,
    ) -> EngineFuture<'_, Vec<citizen_sdk_contracts::WalletAccount>> {
        let service = self.local_wallet_service(&[
            CapabilityName::WalletProfile,
            CapabilityName::LocalSigning,
            CapabilityName::HardwareVault,
            CapabilityName::UserAuthentication,
        ]);
        Box::pin(async move { service?.add_accounts(&mnemonic, &password, &indices).await })
    }

    pub fn set_active_wallet_account(
        &self,
        account_id: AccountId32,
    ) -> EngineFuture<'_, WalletProfile> {
        let service = self.local_wallet_service(&[CapabilityName::WalletProfile]);
        Box::pin(async move { service?.set_active_account(account_id).await })
    }

    pub fn rename_wallet_account(
        &self,
        account_id: AccountId32,
        name: String,
    ) -> EngineFuture<'_, WalletProfile> {
        let service = self.local_wallet_service(&[CapabilityName::WalletProfile]);
        Box::pin(async move { service?.rename_account(account_id, &name).await })
    }

    /// 产品协议（例如 TUYU v1）可复用同一账户密钥签名，但不会被混成链上交易。
    pub fn sign_wallet_payload(
        &self,
        account_id: AccountId32,
        message: Vec<u8>,
    ) -> EngineFuture<'_, Sr25519Signature> {
        let service = self.local_wallet_service(&[
            CapabilityName::WalletProfile,
            CapabilityName::LocalSigning,
            CapabilityName::HardwareVault,
            CapabilityName::UserAuthentication,
        ]);
        Box::pin(async move { service?.sign(account_id, message).await })
    }

    pub fn delete_wallet_account(&self, account_id: AccountId32) -> EngineFuture<'_, ()> {
        let service = self
            .local_wallet_service(&[CapabilityName::WalletProfile, CapabilityName::HardwareVault]);
        Box::pin(async move { service?.delete_account(account_id).await })
    }

    pub fn delete_wallet(&self) -> EngineFuture<'_, ()> {
        let service = self
            .local_wallet_service(&[CapabilityName::WalletProfile, CapabilityName::HardwareVault]);
        Box::pin(async move { service?.delete_wallet().await })
    }

    pub fn reconcile_wallet_cleanup(&self) -> EngineFuture<'_, ()> {
        let service = self
            .local_wallet_service(&[CapabilityName::WalletProfile, CapabilityName::HardwareVault]);
        Box::pin(async move { service?.reconcile_cleanup().await })
    }

    /// 完成一笔钱包转账直到得到准确 finalized 执行终态或明确交易池拒绝。
    ///
    /// 这是没有进度观察器的便利入口，仍会完整执行 submit-and-watch；它不是“只提交”
    /// API，也不返回可脱离历史状态机单独广播的 signed bytes。
    pub fn transfer_with_remark(
        &self,
        source_account_id: AccountId32,
        destination: AccountId32,
        amount_fen: u128,
        remark: String,
    ) -> EngineFuture<'_, WalletTransferWatchResult> {
        self.transfer_with_remark_and_watch(
            source_account_id,
            destination,
            amount_fen,
            remark,
            Arc::new(NoopWalletTransferObserver),
        )
    }

    /// 钱包转账的唯一完整 submit-and-watch 路径。
    ///
    /// 从设备金库解锁账户，在 Rust 内完成准确 Runtime 构造和 sr25519 签名；随后先以
    /// 同账户 single-flight CAS 持久化 `Pending`，再把 signed extrinsic 交给 provider
    /// 的 submit-and-watch。`InBlock` 不结束 future；`Finalized` 会从准确 canonical
    /// 块体和同 index `System.Events` 核验 Success/Failed。断线、dropped、retracted 或
    /// timeout 返回可重试错误，但不会清除 durable `Pending/InBlock` 门。
    pub fn transfer_with_remark_and_watch(
        &self,
        source_account_id: AccountId32,
        destination: AccountId32,
        amount_fen: u128,
        remark: String,
        observer: Arc<dyn WalletTransferObserver>,
    ) -> EngineFuture<'_, WalletTransferWatchResult> {
        Box::pin(async move {
            let (history_runtime, guard) = self.prepare_finalized_history_runtime(&[
                CapabilityName::ChainRead,
                CapabilityName::TransactionBuild,
                CapabilityName::TransactionSubmit,
                CapabilityName::TransactionVerify,
                CapabilityName::History,
                CapabilityName::WalletProfile,
                CapabilityName::LocalSigning,
                CapabilityName::HardwareVault,
                CapabilityName::UserAuthentication,
            ])?;
            let service = self.wallet_service_from_components()?;
            let history = self.history_service_from_components()?;
            let nonce_source = self.components.account_nonce_source().ok_or_else(|| {
                EngineError::CapabilityUnavailable("account_nonce_source_missing".to_owned())
            })?;

            // 在构造交易前固定该账户的 finalized 起始游标。finalized watch 到达后只会
            // 从这个已持久锚顺序追赶，不能跳到宿主给出的块直接伪造终态。
            history_runtime
                .initialize_accounts(&[source_account_id], &guard)
                .await?;
            let built = service
                .build_transfer_with_remark(
                    self.components.chain_client().as_ref(),
                    nonce_source.as_ref(),
                    source_account_id,
                    destination,
                    amount_fen,
                    remark,
                )
                .await?;
            let hash_context = self
                .components
                .chain_client()
                .get_runtime_context_at(built.signed().payload().block())
                .await?;
            if hash_context.block() != built.signed().payload().block()
                || hash_context.version() != built.signed().payload().runtime_version()
            {
                return Err(EngineError::BlockContextMismatch(
                    "提交前的准确 Runtime context 与构造轨迹不一致".to_owned(),
                ));
            }
            let transaction_hash =
                crate::signed_extrinsic_hash(&hash_context, built.signed().extrinsic())?;
            history
                .record_pending_before_broadcast(
                    built.source_account_id(),
                    transaction_hash,
                    built.signed().payload().nonce(),
                    built.call().destination(),
                    built.call().amount_fen(),
                    built.call().remark(),
                )
                .await?;

            watch_recorded_transfer(
                self.components.chain_client().as_ref(),
                &history_runtime,
                &history,
                &guard,
                &observer,
                source_account_id,
                transaction_hash,
                built.signed().extrinsic().clone(),
            )
            .await
        })
    }

    /// 把新纳入监控的账户游标原子初始化到调用时的当前 finalized head。
    ///
    /// 这是 Rust Core 的高层确定性入口；FFI/语言绑定当前不直接投影低层扫描服务。
    pub fn initialize_finalized_history(
        &self,
        account_ids: Vec<AccountId32>,
    ) -> EngineFuture<'_, TransactionHistoryState> {
        let preparation = self.prepare_finalized_history_runtime(&[
            CapabilityName::ChainRead,
            CapabilityName::History,
        ]);
        Box::pin(async move {
            let (runtime, guard) = preparation?;
            runtime.initialize_accounts(&account_ids, &guard).await
        })
    }

    /// 确定性同步一批 finalized 历史；一次最多连续处理 120 个块，不创建 timer/thread。
    pub fn sync_finalized_history_batch(
        &self,
        account_ids: Vec<AccountId32>,
    ) -> EngineFuture<'_, TransactionHistoryState> {
        let preparation = self.prepare_finalized_history_runtime(&[
            CapabilityName::ChainRead,
            CapabilityName::TransactionVerify,
            CapabilityName::History,
        ]);
        Box::pin(async move {
            let (runtime, guard) = preparation?;
            runtime.sync_batch(&account_ids, &guard).await
        })
    }

    /// 把 provider typed watch 事实映射到本机 pending；该入口永不从 watch 伪造链上成功。
    pub fn apply_transaction_watch_event(
        &self,
        account_id: AccountId32,
        transaction_hash: Hash32,
        event: ExtrinsicWatchEvent,
    ) -> EngineFuture<'_, TransactionHistoryState> {
        let preparation = self.prepare_finalized_history_runtime(&[
            CapabilityName::ChainRead,
            CapabilityName::History,
        ]);
        Box::pin(async move {
            let (runtime, guard) = preparation?;
            runtime
                .apply_watch_event(account_id, transaction_hash, event, &guard)
                .await
        })
    }

    /// 提交宿主在 SDK 外部完成签名的完整 extrinsic。
    ///
    /// 这是供纯链客户端/C ABI 迁移使用的高级入口，不是 SDK 钱包交易入口。只要当前
    /// Engine 注入任一钱包交易栈组件，该交易哈希就必须已经由内部钱包路径写入 pending，
    /// 否则拒绝广播。交易池接受仍不等于链上执行成功。
    pub fn submit_signed_extrinsic(
        &self,
        extrinsic: SignedExtrinsic,
    ) -> EngineFuture<'_, SubmittedExtrinsic> {
        Box::pin(async move {
            self.require_capabilities(&[
                CapabilityName::ChainRead,
                CapabilityName::TransactionSubmit,
            ])?;
            if self.components.has_any_wallet_transaction_component() {
                self.require_capabilities(&[CapabilityName::History])?;
                let best = self.components.chain_client().get_best_head().await?;
                let context = self
                    .components
                    .chain_client()
                    .get_runtime_context_at(best)
                    .await?;
                if context.block() != best {
                    return Err(EngineError::BlockContextMismatch(
                        "原始提交哈希使用的 Runtime context 不属于当前 best 块".to_owned(),
                    ));
                }
                let transaction_hash = crate::signed_extrinsic_hash(&context, &extrinsic)?;
                self.history_service_from_components()?
                    .require_recorded_before_broadcast(transaction_hash)
                    .await?;
            }
            self.components
                .chain_client()
                .submit_extrinsic(extrinsic)
                .await
                .map_err(EngineError::from)
        })
    }

    /// 提交并监听宿主在 SDK 外部完成签名的完整 extrinsic。
    ///
    /// 这是供纯链客户端/C ABI 迁移使用的兼容入口；底层 provider 的 watch 合同会广播
    /// extrinsic，而不是只观察一个既有哈希。只要 Engine 注入任一钱包交易栈组件，就必须
    /// 改用内部高层钱包交易路径，避免绕过 pending-before-broadcast 合同。
    pub fn watch_signed_extrinsic(
        &self,
        extrinsic: SignedExtrinsic,
    ) -> Result<citizen_sdk_contracts::ContractStream<'_, ExtrinsicWatchEvent>, EngineError> {
        self.require_capabilities(&[CapabilityName::ChainRead, CapabilityName::TransactionSubmit])?;
        if self.components.has_any_wallet_transaction_component() {
            return Err(EngineError::contract(
                ContractErrorCode::InvalidState,
                "组合钱包组件后禁止原始 submit-and-watch；钱包交易必须使用高层交易入口",
            ));
        }
        Ok(self.components.chain_client().watch_extrinsic(extrinsic))
    }

    /// Reserve the one-way transition into provider startup.
    pub fn begin_provider_start(&self) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Created || state.export_in_progress {
            return Err(lifecycle_error(
                "provider start requires a never-started Engine",
            ));
        }
        require_no_inflight_history_operations(&state, "provider start")?;
        state.generation = next_generation(state.generation)?;
        state.lifecycle = EngineLifecycle::Starting;
        self.refresh_capabilities_while_state_locked(EngineLifecycle::Starting)
    }

    /// Complete startup only after the provider exposes an independently
    /// verified finalized head. A provisional import that regresses or
    /// conflicts moves the Engine to `StartFailed`; the provider adapter must
    /// then destroy its failed instance before a new Engine is created.
    pub fn complete_provider_start(&self) -> EngineFuture<'_, FinalizedBlockRef> {
        let generation = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)
            .and_then(|state| {
                if state.lifecycle == EngineLifecycle::Starting {
                    Ok(state.generation)
                } else {
                    Err(lifecycle_error("provider is not starting"))
                }
            });
        Box::pin(async move {
            let generation = generation?;
            let identity = match self.components.chain_client().identity().await {
                Ok(identity) => identity,
                Err(error) => {
                    self.fail_start_if_current(generation)?;
                    return Err(EngineError::from(error));
                }
            };
            if identity != *StateImportPolicy::citizenchain(None).identity() {
                self.fail_start_if_current(generation)?;
                return Err(EngineError::contract(
                    ContractErrorCode::Integrity,
                    "provider identity changed away from CitizenChain during startup".to_owned(),
                ));
            }
            let finalized = match self.components.chain_client().get_finalized_head().await {
                Ok(finalized) => finalized,
                Err(error) => {
                    self.fail_start_if_current(generation)?;
                    return Err(EngineError::from(error));
                }
            };
            let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
            if state.lifecycle != EngineLifecycle::Starting || state.generation != generation {
                return Err(lifecycle_error(
                    "provider startup completed after its lifecycle generation ended",
                ));
            }
            if let Some(imported) = state.provisional_import {
                if let Err(rejection) = validate_import_startup(imported, finalized) {
                    state.lifecycle = EngineLifecycle::StartFailed;
                    state.generation = next_generation(state.generation)?;
                    self.refresh_capabilities_while_state_locked(EngineLifecycle::StartFailed)?;
                    return Err(state_rejection_error(rejection));
                }
            }
            state.lifecycle = EngineLifecycle::Running;
            state.provisional_import = None;
            state.verified_finalized = Some(finalized);
            self.refresh_capabilities_while_state_locked(EngineLifecycle::Running)?;
            Ok(finalized)
        })
    }

    /// Record a provider startup failure without allowing the same Engine to
    /// return to the importable state.
    pub fn mark_provider_start_failed(&self) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Starting {
            return Err(lifecycle_error("only a starting provider can fail startup"));
        }
        require_no_inflight_history_operations(&state, "provider start failure")?;
        state.lifecycle = EngineLifecycle::StartFailed;
        state.generation = next_generation(state.generation)?;
        self.refresh_capabilities_while_state_locked(EngineLifecycle::StartFailed)
    }

    pub fn mark_provider_stopped(&self) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Running || state.export_in_progress {
            return Err(lifecycle_error("only an idle running provider can stop"));
        }
        require_no_inflight_history_operations(&state, "provider stop")?;
        state.lifecycle = EngineLifecycle::Stopped;
        state.generation = next_generation(state.generation)?;
        state.export_in_progress = false;
        self.refresh_capabilities_while_state_locked(EngineLifecycle::Stopped)
    }

    pub fn dispose(&self) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle == EngineLifecycle::Disposed {
            return Ok(());
        }
        require_no_inflight_history_operations(&state, "engine dispose")?;
        state.lifecycle = EngineLifecycle::Disposed;
        state.generation = next_generation(state.generation)?;
        state.export_in_progress = false;
        self.refresh_capabilities_while_state_locked(EngineLifecycle::Disposed)
    }

    /// Load a context at one exact block and reject provider cross-block data.
    pub fn runtime_context_at(&self, block: VerifiedBlockRef) -> EngineFuture<'_, RuntimeContext> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            let request = self
                .runtime_contexts
                .lock()
                .map_err(|_| EngineError::StatePoisoned)?
                .begin(block)?;

            if let Some(store) = self.components.runtime_cache() {
                let cached = store.load(block.hash()).await.map_err(EngineError::from)?;
                if let Some(cached) = cached {
                    return self
                        .runtime_contexts
                        .lock()
                        .map_err(|_| EngineError::StatePoisoned)?
                        .complete(request, cached);
                }
            }

            let context = self
                .components
                .chain_client()
                .get_runtime_context_at(block)
                .await
                .map_err(EngineError::from)?;
            let context = self
                .runtime_contexts
                .lock()
                .map_err(|_| EngineError::StatePoisoned)?
                .complete(request, context)?;
            if let Some(store) = self.components.runtime_cache() {
                store
                    .store(context.clone())
                    .await
                    .map_err(EngineError::from)?;
            }
            Ok(context)
        })
    }

    /// Gather evidence for an exact provider-resolved finalized block and return a fail-closed
    /// execution conclusion.
    ///
    /// `VerifiedBlockRef` is serializable host input, not an unforgeable proof token. Therefore
    /// this boundary asks `VerifiedChainClient` to resolve the supplied hash/height onto its
    /// finalized canonical chain before reading Runtime/body/events. A caller-provided finality bit
    /// can never manufacture `Success` or `Failed`, while historical finalized catch-up remains
    /// available after the head advances.
    pub fn verify_transaction_at(
        &self,
        block: VerifiedBlockRef,
        signed_extrinsic: SignedExtrinsic,
        submitted_hash: Hash32,
    ) -> EngineFuture<'_, ExecutionConclusion> {
        Box::pin(async move {
            if self
                .require_capabilities(&[
                    CapabilityName::ChainRead,
                    CapabilityName::TransactionVerify,
                ])
                .is_err()
            {
                return Ok(unverified(block, None, UnverifiedReason::ProviderFailure));
            }
            if !block.is_finalized() {
                return Ok(unverified(
                    block,
                    None,
                    UnverifiedReason::TargetBlockUnavailable,
                ));
            }
            let provider_finalized = match self
                .components
                .chain_client()
                .resolve_finalized_block(block.hash(), block.number())
                .await
            {
                Ok(finalized) => finalized,
                Err(error)
                    if matches!(
                        error.code(),
                        ContractErrorCode::Network
                            | ContractErrorCode::Timeout
                            | ContractErrorCode::Unavailable
                            | ContractErrorCode::NotReady
                            | ContractErrorCode::Internal
                    ) =>
                {
                    return Ok(unverified(block, None, UnverifiedReason::ProviderFailure));
                }
                Err(_) => {
                    return Ok(unverified(
                        block,
                        None,
                        UnverifiedReason::TargetBlockUnavailable,
                    ));
                }
            };
            if block != provider_finalized.verified() {
                return Ok(unverified(
                    block,
                    None,
                    UnverifiedReason::TargetBlockUnavailable,
                ));
            }
            // 持久 RuntimeCacheStore 是性能层，不是 provider-issued 证明。执行结论
            // 会按 metadata 解释真实 System.Events，因此安全关键核验必须直接取得
            // 轻节点对该 finalized 块返回的 context；不允许持久 cache 重映射
            // Success/Failed 语义。
            let runtime_context = match self
                .components
                .chain_client()
                .get_finalized_runtime_context_at(provider_finalized)
                .await
            {
                Ok(context) if context.block() == provider_finalized.verified() => context,
                Ok(_) | Err(_) => {
                    return Ok(unverified(
                        block,
                        None,
                        UnverifiedReason::RuntimeContextUnavailable,
                    ));
                }
            };
            let block_extrinsics = match self
                .components
                .chain_client()
                .get_finalized_block_extrinsics_at(provider_finalized)
                .await
            {
                Ok(extrinsics) => extrinsics,
                Err(_) => {
                    return Ok(unverified(
                        block,
                        None,
                        UnverifiedReason::BlockBodyUnavailable,
                    ));
                }
            };
            let system_events = self
                .components
                .chain_client()
                .get_finalized_storage_at(provider_finalized, SYSTEM_EVENTS_STORAGE_KEY.to_vec())
                .await
                .ok()
                .flatten();
            Ok(verify_transaction_outcome(TransactionEvidence {
                block,
                runtime_context: &runtime_context,
                signed_extrinsic: &signed_extrinsic,
                submitted_hash,
                block_extrinsics: &block_extrinsics,
                system_events: system_events.as_deref(),
            }))
        })
    }

    /// Validate all import gates before the provider sees database bytes, then
    /// require its receipt to preserve the exact finalized anchor.
    pub fn import_state(
        &self,
        imported: ExportedChainState,
    ) -> EngineFuture<'_, StateImportReceipt> {
        let preparation = self.prepare_state_import(&imported);
        Box::pin(async move {
            let (reservation, provisional_finalized) = preparation?;
            let store = Arc::clone(self.components.chain_database().ok_or_else(|| {
                EngineError::CapabilityUnavailable(
                    "chain database store is required for state import".to_owned(),
                )
            })?);
            let stored = store.load().await.map_err(EngineError::from)?;
            self.complete_state_import(imported, reservation, provisional_finalized, store, stored)
                .await
        })
    }

    /// Restore the exact opaque light-client state selected by the configured
    /// typed store. An empty store is a successful no-op. Every non-empty value
    /// passes the same import gates, provider receipt check, revision CAS and
    /// one-way post-provider failure semantics as an explicit import.
    pub fn restore_state_from_store(&self) -> EngineFuture<'_, Option<StateImportReceipt>> {
        Box::pin(async move {
            let store = Arc::clone(self.components.chain_database().ok_or_else(|| {
                EngineError::CapabilityUnavailable(
                    "chain database store is required for state restore".to_owned(),
                )
            })?);
            let stored = store.load().await.map_err(EngineError::from)?;
            let Some(imported) = stored.state().cloned() else {
                // Linearize the empty result against startup/import. Returning
                // None while another lifecycle transition already won would
                // falsely claim restore completed before provider startup.
                let state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
                if state.lifecycle != EngineLifecycle::Created || state.export_in_progress {
                    return Err(lifecycle_error(
                        "empty state restore requires a never-started Engine",
                    ));
                }
                return Ok(None);
            };
            let (reservation, provisional_finalized) = self.prepare_state_import(&imported)?;
            self.complete_state_import(imported, reservation, provisional_finalized, store, stored)
                .await
                .map(Some)
        })
    }

    async fn complete_state_import(
        &self,
        imported: ExportedChainState,
        mut reservation: StateImportReservation,
        provisional_finalized: Option<FinalizedBlockRef>,
        store: Arc<dyn ChainDatabaseStore>,
        stored: ChainDatabaseSnapshot,
    ) -> Result<StateImportReceipt, EngineError> {
        let stored_finalized = validate_persisted_chain_state(&stored)?;
        let current_finalized = merge_finalized_anchors(provisional_finalized, stored_finalized)?;
        let policy = StateImportPolicy::citizenchain(current_finalized);
        validate_state_import(&policy, EngineLifecycle::Created, &imported)
            .map_err(state_rejection_error)?;
        let provider_identity = self
            .components
            .chain_client()
            .identity()
            .await
            .map_err(EngineError::from)?;
        if &provider_identity != policy.identity() {
            return Err(EngineError::contract(
                ContractErrorCode::Integrity,
                "provider identity does not match CitizenChain".to_owned(),
            ));
        }
        // Prove revision capacity before the irreversible provider import.
        let expected_persisted = next_chain_database_snapshot(&stored, imported.clone())?;
        let expected = imported.finalized();
        reservation.mark_provider_invoked()?;
        let receipt = self
            .components
            .chain_client()
            .import_state(imported)
            .await
            .map_err(EngineError::from)?;
        if receipt.finalized() != expected {
            return Err(EngineError::BlockContextMismatch(
                "state import receipt changed the finalized anchor".to_owned(),
            ));
        }
        // Even when the loaded state equals the candidate, CAS proves no other
        // process changed that revision while provider import was in flight.
        persist_chain_database_exact(&store, stored.revision(), expected_persisted).await?;
        reservation.commit(expected)?;
        Ok(receipt)
    }

    /// Export only from one stable running generation and require the
    /// provider's verified finalized head to remain unchanged across
    /// serialization.
    pub fn export_state(&self) -> EngineFuture<'_, ExportedChainState> {
        self.export_state_inner(false)
    }

    /// Export one stable provider snapshot and atomically persist it to the
    /// configured typed chain database before releasing the Engine generation.
    pub fn export_and_persist_state(&self) -> EngineFuture<'_, ExportedChainState> {
        self.export_state_inner(true)
    }

    fn export_state_inner(&self, persist: bool) -> EngineFuture<'_, ExportedChainState> {
        let reservation = self.prepare_state_export();
        let store = if persist {
            self.components.chain_database().map(Arc::clone)
        } else {
            None
        };
        Box::pin(async move {
            let mut reservation = reservation?;
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            let stored = if persist {
                let store = store.as_ref().ok_or_else(|| {
                    EngineError::CapabilityUnavailable(
                        "chain database store is required for persistent state export".to_owned(),
                    )
                })?;
                let snapshot = store.load().await.map_err(EngineError::from)?;
                // Reject corrupt persisted envelopes before asking the provider
                // to serialize another database.
                let _ = validate_persisted_chain_state(&snapshot)?;
                Some(snapshot)
            } else {
                None
            };
            let before = self
                .components
                .chain_client()
                .get_finalized_head()
                .await
                .map_err(EngineError::from)?;
            let provider_identity = self
                .components
                .chain_client()
                .identity()
                .await
                .map_err(EngineError::from)?;
            if provider_identity != *StateImportPolicy::citizenchain(None).identity() {
                return Err(EngineError::contract(
                    ContractErrorCode::Integrity,
                    "provider identity changed away from CitizenChain during export".to_owned(),
                ));
            }
            if let Some(current) = reservation.verified_finalized {
                validate_import_startup(current, before).map_err(state_rejection_error)?;
            }
            if let Some(stored_finalized) = stored
                .as_ref()
                .and_then(|snapshot| snapshot.state().map(ExportedChainState::finalized))
            {
                validate_import_startup(stored_finalized, before).map_err(state_rejection_error)?;
            }
            let exported = self
                .components
                .chain_client()
                .export_state()
                .await
                .map_err(EngineError::from)?;
            let after = self
                .components
                .chain_client()
                .get_finalized_head()
                .await
                .map_err(EngineError::from)?;
            let policy = StateImportPolicy::citizenchain(Some(before));
            validate_state_export(&policy, EngineLifecycle::Running, before, &exported, after)
                .map_err(state_rejection_error)?;
            if let Some(stored) = stored {
                let store = store.as_ref().ok_or_else(|| {
                    EngineError::CapabilityUnavailable(
                        "chain database store disappeared during persistent export".to_owned(),
                    )
                })?;
                let expected_persisted = next_chain_database_snapshot(&stored, exported.clone())?;
                persist_chain_database_exact(store, stored.revision(), expected_persisted).await?;
            }
            reservation.commit(after)?;
            Ok(exported)
        })
    }

    fn prepare_state_import(
        &self,
        imported: &ExportedChainState,
    ) -> Result<(StateImportReservation, Option<FinalizedBlockRef>), EngineError> {
        if self.components.chain_database().is_none() {
            return Err(EngineError::CapabilityUnavailable(
                "chain database store is required for state import".to_owned(),
            ));
        }
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        let policy = StateImportPolicy::citizenchain(state.provisional_import);
        validate_state_import(&policy, state.lifecycle, imported).map_err(state_rejection_error)?;
        require_no_inflight_history_operations(&state, "state import")?;
        state.generation = next_generation(state.generation)?;
        state.lifecycle = EngineLifecycle::ImportingState;
        Ok((
            StateImportReservation::new(Arc::clone(&self.state), state.generation),
            state.provisional_import,
        ))
    }

    fn prepare_state_export(&self) -> Result<StateExportReservation, EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Running || state.export_in_progress {
            return Err(lifecycle_error(
                "state export requires one idle running Engine generation",
            ));
        }
        state.export_in_progress = true;
        Ok(StateExportReservation::new(
            Arc::clone(&self.state),
            state.generation,
            state.verified_finalized,
        ))
    }

    fn fail_start_if_current(&self, generation: u64) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        let mut changed = false;
        if state.lifecycle == EngineLifecycle::Starting && state.generation == generation {
            require_no_inflight_history_operations(&state, "provider start failure")?;
            state.lifecycle = EngineLifecycle::StartFailed;
            state.generation = next_generation(state.generation)?;
            changed = true;
        }
        if changed {
            self.refresh_capabilities_while_state_locked(EngineLifecycle::StartFailed)?;
        }
        Ok(())
    }

    fn wallet_service_from_components(&self) -> Result<WalletService, EngineError> {
        let signer = self
            .components
            .signer()
            .cloned()
            .ok_or_else(|| component_missing("chain_signer"))?;
        let vault = self
            .components
            .secret_vault()
            .cloned()
            .ok_or_else(|| component_missing("secret_vault"))?;
        let profiles = self
            .components
            .wallet_profiles()
            .cloned()
            .ok_or_else(|| component_missing("wallet_profile_store"))?;
        let encrypted_secrets = self
            .components
            .encrypted_secrets()
            .cloned()
            .ok_or_else(|| component_missing("encrypted_secret_blob_store"))?;
        Ok(WalletService::new(
            signer,
            vault,
            profiles,
            encrypted_secrets,
            Arc::new(SystemWalletEntropy),
            Arc::new(SystemWalletClock),
        ))
    }

    fn local_wallet_service(
        &self,
        required: &[CapabilityName],
    ) -> Result<WalletService, EngineError> {
        self.require_local_capabilities(required)?;
        self.wallet_service_from_components()
    }

    fn history_service_from_components(&self) -> Result<TransactionHistoryService, EngineError> {
        let store = self
            .components
            .transaction_history()
            .cloned()
            .ok_or_else(|| component_missing("transaction_history_store"))?;
        Ok(TransactionHistoryService::new(
            store,
            Arc::new(SystemWalletClock),
        ))
    }

    fn prepare_finalized_history_runtime(
        &self,
        required: &[CapabilityName],
    ) -> Result<(FinalizedHistoryRuntime, EngineHistoryOperationLease), EngineError> {
        self.require_capabilities(required)?;
        // 先解析全部组件，避免租约计数增加后因缺少 store 提前返回而泄漏。
        let runtime = FinalizedHistoryRuntime::new(
            Arc::clone(self.components.chain_client()),
            self.history_service_from_components()?,
        );
        let generation = {
            let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
            if state.lifecycle != EngineLifecycle::Running {
                return Err(lifecycle_error(
                    "finalized history requires a running Engine generation",
                ));
            }
            state.inflight_history_operations = state
                .inflight_history_operations
                .checked_add(1)
                .ok_or_else(|| lifecycle_error("finalized history operation count overflowed"))?;
            state.generation
        };
        Ok((
            runtime,
            EngineHistoryOperationLease {
                state: Arc::clone(&self.state),
                generation,
            },
        ))
    }

    fn require_capabilities(&self, required: &[CapabilityName]) -> Result<(), EngineError> {
        self.require_capability_snapshot(required, true)
    }

    fn require_local_capabilities(&self, required: &[CapabilityName]) -> Result<(), EngineError> {
        self.require_capability_snapshot(required, false)
    }

    fn require_capability_snapshot(
        &self,
        required: &[CapabilityName],
        require_running: bool,
    ) -> Result<(), EngineError> {
        let state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if require_running && state.lifecycle != EngineLifecycle::Running {
            return Err(EngineError::CapabilityUnavailable(
                "engine_not_running".to_owned(),
            ));
        }
        let capabilities = self
            .capabilities
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        let Some(snapshot) = capabilities.tracker.current() else {
            return Err(EngineError::CapabilityUnavailable(
                "capability state has not been established".to_owned(),
            ));
        };
        for name in required {
            if !snapshot
                .status(*name)
                .is_some_and(|status| status.is_ready())
            {
                return Err(EngineError::CapabilityUnavailable(format!(
                    "{} is not ready",
                    name.as_str()
                )));
            }
        }
        Ok(())
    }

    /// Refresh a lifecycle-derived snapshot while the caller still owns the
    /// Engine state lock. Every dual-lock path uses state -> capabilities.
    fn refresh_capabilities_while_state_locked(
        &self,
        lifecycle: EngineLifecycle,
    ) -> Result<(), EngineError> {
        let mut capabilities = self
            .capabilities
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        let Some(base_probes) = capabilities.base_probes.clone() else {
            return Ok(());
        };
        let _ = capabilities
            .tracker
            .update(probes_for_lifecycle(base_probes, lifecycle))?;
        Ok(())
    }
}

/// finalized 协调器持有的不可复用 Engine 代际与完整操作租约。
///
/// guard 从 prepare 开始一直活到所有 provider/store await 与最后一次 CAS 结束。只要
/// guard 存活，stop/dispose 就会失败关闭；这比单纯在 await 前后比较 generation 更强，
/// 因为代际切换无法插入最后一次检查与异步 CAS 之间。
struct EngineHistoryOperationLease {
    state: Arc<Mutex<EngineState>>,
    generation: u64,
}

impl FinalizedHistoryRunGuard for EngineHistoryOperationLease {
    fn ensure_current(&self) -> Result<(), EngineError> {
        let state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Running || state.generation != self.generation {
            return Err(lifecycle_error(
                "finalized history operation outlived its running Engine generation",
            ));
        }
        Ok(())
    }
}

impl Drop for EngineHistoryOperationLease {
    fn drop(&mut self) {
        // Drop 不能返回错误；锁若已 poisoned，Engine 后续所有状态入口本来也会失败。
        if let Ok(mut state) = self.state.lock() {
            if let Some(remaining) = state.inflight_history_operations.checked_sub(1) {
                state.inflight_history_operations = remaining;
            }
        }
    }
}

fn require_no_inflight_history_operations(
    state: &EngineState,
    operation: &str,
) -> Result<(), EngineError> {
    if state.inflight_history_operations != 0 {
        return Err(lifecycle_error(format!(
            "{operation} requires all finalized history operations to drain"
        )));
    }
    Ok(())
}

fn probes_for_lifecycle(
    mut probes: Vec<CapabilityProbe>,
    lifecycle: EngineLifecycle,
) -> Vec<CapabilityProbe> {
    if lifecycle != EngineLifecycle::Running {
        if let Some(chain_read) = probes
            .iter_mut()
            .find(|probe| probe.name == CapabilityName::ChainRead)
        {
            chain_read.runtime_ready = false;
            chain_read.not_ready_reason = Some(CapabilityReason::EngineNotRunning);
        }
    }
    probes
}

struct StateImportReservation {
    state: Arc<Mutex<EngineState>>,
    generation: u64,
    provider_invoked: bool,
    committed: bool,
}

impl StateImportReservation {
    const fn new(state: Arc<Mutex<EngineState>>, generation: u64) -> Self {
        Self {
            state,
            generation,
            provider_invoked: false,
            committed: false,
        }
    }

    fn mark_provider_invoked(&mut self) -> Result<(), EngineError> {
        let state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::ImportingState || state.generation != self.generation
        {
            return Err(lifecycle_error(
                "state import lost its lifecycle reservation before provider mutation",
            ));
        }
        self.provider_invoked = true;
        Ok(())
    }

    fn commit(&mut self, finalized: FinalizedBlockRef) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::ImportingState || state.generation != self.generation
        {
            return Err(lifecycle_error(
                "state import completed after its lifecycle generation ended",
            ));
        }
        state.lifecycle = EngineLifecycle::Created;
        state.provisional_import = Some(finalized);
        self.committed = true;
        Ok(())
    }
}

impl Drop for StateImportReservation {
    fn drop(&mut self) {
        if self.committed {
            return;
        }
        if let Ok(mut state) = self.state.lock() {
            if state.lifecycle == EngineLifecycle::ImportingState
                && state.generation == self.generation
            {
                if self.provider_invoked {
                    state.lifecycle = EngineLifecycle::StartFailed;
                    state.generation = state.generation.saturating_add(1);
                } else {
                    state.lifecycle = EngineLifecycle::Created;
                }
            }
        }
    }
}

struct StateExportReservation {
    state: Arc<Mutex<EngineState>>,
    generation: u64,
    verified_finalized: Option<FinalizedBlockRef>,
    committed: bool,
}

impl StateExportReservation {
    const fn new(
        state: Arc<Mutex<EngineState>>,
        generation: u64,
        verified_finalized: Option<FinalizedBlockRef>,
    ) -> Self {
        Self {
            state,
            generation,
            verified_finalized,
            committed: false,
        }
    }

    fn commit(&mut self, finalized: FinalizedBlockRef) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Running || state.generation != self.generation {
            return Err(lifecycle_error(
                "state export completed after its lifecycle generation ended",
            ));
        }
        state.export_in_progress = false;
        state.verified_finalized = Some(finalized);
        self.committed = true;
        Ok(())
    }
}

impl Drop for StateExportReservation {
    fn drop(&mut self) {
        if self.committed {
            return;
        }
        if let Ok(mut state) = self.state.lock() {
            if state.generation == self.generation {
                state.export_in_progress = false;
            }
        }
    }
}

fn next_generation(current: u64) -> Result<u64, EngineError> {
    current
        .checked_add(1)
        .ok_or_else(|| lifecycle_error("engine lifecycle generation overflowed"))
}

/// Validate a persisted public light-client snapshot before any provider
/// mutation. The typed host codec protects its binary shape; the Engine still
/// owns CitizenChain identity, format, size and genesis semantics.
fn validate_persisted_chain_state(
    snapshot: &ChainDatabaseSnapshot,
) -> Result<Option<FinalizedBlockRef>, EngineError> {
    let Some(state) = snapshot.state() else {
        return Ok(None);
    };
    validate_state_import(
        &StateImportPolicy::citizenchain(None),
        EngineLifecycle::Created,
        state,
    )
    .map_err(state_rejection_error)?;
    Ok(Some(state.finalized()))
}

/// Build the one exact revisioned fact expected after a chain-database CAS.
/// Computing this before a provider import proves revision capacity before the
/// provider receives the irreversible database mutation.
fn next_chain_database_snapshot(
    current: &ChainDatabaseSnapshot,
    candidate: ExportedChainState,
) -> Result<ChainDatabaseSnapshot, EngineError> {
    let revision = current
        .revision()
        .checked_add(1)
        .ok_or_else(|| lifecycle_error("chain database revision is exhausted"))?;
    Ok(ChainDatabaseSnapshot::new(revision, Some(candidate)))
}

/// Persist one exact chain-database candidate and converge only the ambiguous
/// "write committed, then host reported failure" case. A state-only match at
/// another revision is deliberately insufficient: revision is part of the
/// durable fact and prevents a competing writer from being mistaken for this
/// operation.
async fn persist_chain_database_exact(
    store: &Arc<dyn ChainDatabaseStore>,
    expected_revision: u64,
    expected: ChainDatabaseSnapshot,
) -> Result<(), EngineError> {
    let candidate = expected.state().cloned().ok_or_else(|| {
        EngineError::contract(
            ContractErrorCode::Internal,
            "persistent chain database candidate unexpectedly omitted state",
        )
    })?;
    match store
        .compare_and_swap(expected_revision, Some(candidate))
        .await
    {
        Ok(observed) if observed == expected => Ok(()),
        Ok(_) => Err(EngineError::contract(
            ContractErrorCode::Integrity,
            "chain database CAS returned a fact other than the exact revisioned candidate",
        )),
        Err(write_error) => {
            let observed = store.load().await;
            if observed
                .as_ref()
                .is_ok_and(|snapshot| snapshot == &expected)
            {
                Ok(())
            } else {
                Err(EngineError::from(write_error))
            }
        }
    }
}

fn merge_finalized_anchors(
    left: Option<FinalizedBlockRef>,
    right: Option<FinalizedBlockRef>,
) -> Result<Option<FinalizedBlockRef>, EngineError> {
    match (left, right) {
        (None, None) => Ok(None),
        (Some(anchor), None) | (None, Some(anchor)) => Ok(Some(anchor)),
        (Some(left), Some(right)) if left.number() == right.number() => {
            if left.hash() == right.hash() {
                Ok(Some(left))
            } else {
                Err(EngineError::BlockContextMismatch(
                    "persisted and provisional finalized anchors conflict at one height".to_owned(),
                ))
            }
        }
        (Some(left), Some(right)) => Ok(Some(if left.number() > right.number() {
            left
        } else {
            right
        })),
    }
}

fn lifecycle_error(reason: impl Into<String>) -> EngineError {
    EngineError::contract(ContractErrorCode::InvalidState, reason)
}

fn component_missing(name: &str) -> EngineError {
    EngineError::CapabilityUnavailable(format!("{name}_missing"))
}

fn state_rejection_error(rejection: StateImportRejection) -> EngineError {
    let code = match rejection {
        StateImportRejection::ProviderAlreadyStarted
        | StateImportRejection::ExportLifecycleInvalid => ContractErrorCode::InvalidState,
        StateImportRejection::FormatVersionMismatch => ContractErrorCode::Unsupported,
        StateImportRejection::DatabaseTooLarge => ContractErrorCode::InvalidArgument,
        StateImportRejection::ChainIdentityMismatch
        | StateImportRejection::GenesisAnchorMismatch
        | StateImportRejection::FinalizedHeightRegression
        | StateImportRejection::FinalizedHashConflict
        | StateImportRejection::StartupAnchorRegression
        | StateImportRejection::ExportAnchorMoved
        | StateImportRejection::ExportEnvelopeMismatch => ContractErrorCode::Integrity,
    };
    EngineError::contract(code, format!("{rejection:?}"))
}

const fn unverified(
    block: VerifiedBlockRef,
    extrinsic_index: Option<u32>,
    reason: UnverifiedReason,
) -> ExecutionConclusion {
    ExecutionConclusion::Unverified {
        block: Some(block),
        extrinsic_index,
        reason,
    }
}
