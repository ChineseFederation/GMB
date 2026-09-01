use std::{
    future::Future,
    pin::Pin,
    sync::{Arc, Mutex},
};

use citizen_sdk_contracts::{
    store::{
        ChainDatabaseStore, EncryptedSecretBlobStore, RuntimeCacheStore, TransactionHistoryStore,
        WalletProfileStore,
    },
    CapabilityName, CapabilitySnapshot, ChainSigner, ExecutionConclusion, ExportedChainState,
    FinalizedBlockRef, Hash32, RuntimeContext, SecretVault, SignedExtrinsic, StateImportReceipt,
    UnverifiedReason, VerifiedBlockRef, VerifiedChainClient,
};

use crate::{
    capabilities::{CapabilityProbe, CapabilityTracker},
    error::EngineError,
    runtime_context::RuntimeContextCache,
    state_import::{
        validate_import_startup, validate_state_export, validate_state_import, EngineLifecycle,
        StateImportPolicy,
    },
    transaction_outcome::{verify_transaction_outcome, TransactionEvidence},
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
        }
    }

    pub(crate) fn chain_client(&self) -> &Arc<dyn VerifiedChainClient> {
        &self.chain_client
    }

    pub(crate) fn runtime_cache(&self) -> Option<&Arc<dyn RuntimeCacheStore>> {
        self.runtime_cache.as_ref()
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
                CapabilityName::ChainRead
                | CapabilityName::TransactionBuild
                | CapabilityName::TransactionSubmit
                | CapabilityName::TransactionVerify
                | CapabilityName::UserAuthentication => true,
            };
            if !present {
                probe.available = false;
                probe.runtime_ready = false;
            }
        }
    }
}

/// Product-independent CitizenSDK Core Engine.
pub struct CitizenEngine {
    components: EngineComponents,
    runtime_contexts: Mutex<RuntimeContextCache>,
    capabilities: Mutex<CapabilityTracker>,
    state: Arc<Mutex<EngineState>>,
}

#[derive(Debug)]
struct EngineState {
    lifecycle: EngineLifecycle,
    generation: u64,
    provisional_import: Option<FinalizedBlockRef>,
    verified_finalized: Option<FinalizedBlockRef>,
    export_in_progress: bool,
}

impl Default for EngineState {
    fn default() -> Self {
        Self {
            lifecycle: EngineLifecycle::Created,
            generation: 0,
            provisional_import: None,
            verified_finalized: None,
            export_in_progress: false,
        }
    }
}

impl CitizenEngine {
    pub fn new(components: EngineComponents) -> Self {
        Self {
            components,
            runtime_contexts: Mutex::new(RuntimeContextCache::new()),
            capabilities: Mutex::new(CapabilityTracker::new()),
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
        self.capabilities
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?
            .update(probes)
    }

    pub fn capabilities(&self) -> Result<Option<CapabilitySnapshot>, EngineError> {
        Ok(self
            .capabilities
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?
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

    /// Reserve the one-way transition into provider startup.
    pub fn begin_provider_start(&self) -> Result<(), EngineError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Created || state.export_in_progress {
            return Err(lifecycle_error("provider start requires a never-started Engine"));
        }
        state.generation = next_generation(state.generation)?;
        state.lifecycle = EngineLifecycle::Starting;
        Ok(())
    }

    /// Complete startup only after the provider exposes an independently
    /// verified finalized head. A provisional import that regresses or
    /// conflicts moves the Engine to `StartFailed`; the provider adapter must
    /// then destroy its failed instance before a new Engine is created.
    pub fn complete_provider_start(&self) -> EngineFuture<'_, FinalizedBlockRef> {
        let generation = self.state.lock().map_err(|_| EngineError::StatePoisoned).and_then(
            |state| {
                if state.lifecycle == EngineLifecycle::Starting {
                    Ok(state.generation)
                } else {
                    Err(lifecycle_error("provider is not starting"))
                }
            },
        );
        Box::pin(async move {
            let generation = generation?;
            let finalized = match self.components.chain_client().get_finalized_head().await {
                Ok(finalized) => finalized,
                Err(error) => {
                    self.fail_start_if_current(generation)?;
                    return Err(EngineError::Contract(error.to_string()));
                }
            };
            let mut state = self
                .state
                .lock()
                .map_err(|_| EngineError::StatePoisoned)?;
            if state.lifecycle != EngineLifecycle::Starting || state.generation != generation {
                return Err(lifecycle_error(
                    "provider startup completed after its lifecycle generation ended",
                ));
            }
            if let Some(imported) = state.provisional_import {
                if let Err(rejection) = validate_import_startup(imported, finalized) {
                    state.lifecycle = EngineLifecycle::StartFailed;
                    state.generation = next_generation(state.generation)?;
                    return Err(EngineError::Contract(format!("{rejection:?}")));
                }
            }
            state.lifecycle = EngineLifecycle::Running;
            state.provisional_import = None;
            state.verified_finalized = Some(finalized);
            Ok(finalized)
        })
    }

    /// Record a provider startup failure without allowing the same Engine to
    /// return to the importable state.
    pub fn mark_provider_start_failed(&self) -> Result<(), EngineError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Starting {
            return Err(lifecycle_error("only a starting provider can fail startup"));
        }
        state.lifecycle = EngineLifecycle::StartFailed;
        state.generation = next_generation(state.generation)?;
        Ok(())
    }

    pub fn mark_provider_stopped(&self) -> Result<(), EngineError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::Running {
            return Err(lifecycle_error("only a running provider can stop"));
        }
        state.lifecycle = EngineLifecycle::Stopped;
        state.generation = next_generation(state.generation)?;
        state.export_in_progress = false;
        Ok(())
    }

    pub fn dispose(&self) -> Result<(), EngineError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle == EngineLifecycle::Disposed {
            return Ok(());
        }
        state.lifecycle = EngineLifecycle::Disposed;
        state.generation = next_generation(state.generation)?;
        state.export_in_progress = false;
        Ok(())
    }

    /// Load a context at one exact block and reject provider cross-block data.
    pub fn runtime_context_at(&self, block: VerifiedBlockRef) -> EngineFuture<'_, RuntimeContext> {
        Box::pin(async move {
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            let request = self
                .runtime_contexts
                .lock()
                .map_err(|_| EngineError::StatePoisoned)?
                .begin(block);

            if let Some(store) = self.components.runtime_cache() {
                let cached = store
                    .load(block.hash())
                    .await
                    .map_err(|error| EngineError::Contract(error.to_string()))?;
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
                .map_err(|error| EngineError::Contract(error.to_string()))?;
            let context = self
                .runtime_contexts
                .lock()
                .map_err(|_| EngineError::StatePoisoned)?
                .complete(request, context)?;
            if let Some(store) = self.components.runtime_cache() {
                store
                    .store(context.clone())
                    .await
                    .map_err(|error| EngineError::Contract(error.to_string()))?;
            }
            Ok(context)
        })
    }

    /// Gather exact-block provider evidence and return a fail-closed execution
    /// conclusion. Provider failures are represented as `Unverified`, because
    /// they do not prove either success or runtime failure.
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
            let runtime_context = match self.runtime_context_at(block).await {
                Ok(context) => context,
                Err(_) => {
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
                .get_block_extrinsics_at(block)
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
                .get_storage_at(block, SYSTEM_EVENTS_STORAGE_KEY.to_vec())
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
    pub fn import_state(&self, imported: ExportedChainState) -> EngineFuture<'_, StateImportReceipt> {
        let preparation = self.prepare_state_import(&imported);
        Box::pin(async move {
            let (mut reservation, policy) = preparation?;
            let provider_identity = self
                .components
                .chain_client()
                .identity()
                .await
                .map_err(|error| EngineError::Contract(error.to_string()))?;
            if &provider_identity != policy.identity() {
                return Err(EngineError::Contract(
                    "provider identity does not match CitizenChain".to_owned(),
                ));
            }
            let expected = imported.finalized();
            let receipt = self
                .components
                .chain_client()
                .import_state(imported)
                .await
                .map_err(|error| EngineError::Contract(error.to_string()))?;
            if receipt.finalized() != expected {
                return Err(EngineError::BlockContextMismatch(
                    "state import receipt changed the finalized anchor".to_owned(),
                ));
            }
            reservation.commit(expected)?;
            Ok(receipt)
        })
    }

    /// Export only from one stable running generation and require the
    /// provider's verified finalized head to remain unchanged across
    /// serialization.
    pub fn export_state(&self) -> EngineFuture<'_, ExportedChainState> {
        let reservation = self.prepare_state_export();
        Box::pin(async move {
            let mut reservation = reservation?;
            self.require_capabilities(&[CapabilityName::ChainRead])?;
            let before = self
                .components
                .chain_client()
                .get_finalized_head()
                .await
                .map_err(|error| EngineError::Contract(error.to_string()))?;
            if let Some(current) = reservation.verified_finalized {
                validate_import_startup(current, before)
                    .map_err(|rejection| EngineError::Contract(format!("{rejection:?}")))?;
            }
            let exported = self
                .components
                .chain_client()
                .export_state()
                .await
                .map_err(|error| EngineError::Contract(error.to_string()))?;
            let after = self
                .components
                .chain_client()
                .get_finalized_head()
                .await
                .map_err(|error| EngineError::Contract(error.to_string()))?;
            let policy = StateImportPolicy::citizenchain(Some(before));
            validate_state_export(
                &policy,
                EngineLifecycle::Running,
                before,
                &exported,
                after,
            )
            .map_err(|rejection| EngineError::Contract(format!("{rejection:?}")))?;
            reservation.commit(after)?;
            Ok(exported)
        })
    }

    fn prepare_state_import(
        &self,
        imported: &ExportedChainState,
    ) -> Result<(StateImportReservation, StateImportPolicy), EngineError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        let policy = StateImportPolicy::citizenchain(state.provisional_import);
        validate_state_import(&policy, state.lifecycle, imported)
            .map_err(|rejection| EngineError::Contract(format!("{rejection:?}")))?;
        state.generation = next_generation(state.generation)?;
        state.lifecycle = EngineLifecycle::ImportingState;
        Ok((
            StateImportReservation::new(Arc::clone(&self.state), state.generation),
            policy,
        ))
    }

    fn prepare_state_export(&self) -> Result<StateExportReservation, EngineError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
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
        let mut state = self
            .state
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle == EngineLifecycle::Starting && state.generation == generation {
            state.lifecycle = EngineLifecycle::StartFailed;
            state.generation = next_generation(state.generation)?;
        }
        Ok(())
    }

    fn require_capabilities(&self, required: &[CapabilityName]) -> Result<(), EngineError> {
        let capabilities = self
            .capabilities
            .lock()
            .map_err(|_| EngineError::StatePoisoned)?;
        let Some(snapshot) = capabilities.current() else {
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
}

struct StateImportReservation {
    state: Arc<Mutex<EngineState>>,
    generation: u64,
    committed: bool,
}

impl StateImportReservation {
    const fn new(state: Arc<Mutex<EngineState>>, generation: u64) -> Self {
        Self {
            state,
            generation,
            committed: false,
        }
    }

    fn commit(&mut self, finalized: FinalizedBlockRef) -> Result<(), EngineError> {
        let mut state = self.state.lock().map_err(|_| EngineError::StatePoisoned)?;
        if state.lifecycle != EngineLifecycle::ImportingState
            || state.generation != self.generation
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
                state.lifecycle = EngineLifecycle::Created;
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

fn lifecycle_error(reason: &str) -> EngineError {
    EngineError::Contract(reason.to_owned())
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

// twox128("System") ++ twox128("Events"), fixed by the Substrate storage
// contract and equal to the existing CitizenApp/CitizenSDK Dart implementation.
const SYSTEM_EVENTS_STORAGE_KEY: [u8; 32] = [
    0x26, 0xaa, 0x39, 0x4e, 0xea, 0x56, 0x30, 0xe0, 0x7c, 0x48, 0xae, 0x0c, 0x95, 0x58, 0xce, 0xf7,
    0x80, 0xd4, 0x1e, 0x5e, 0x16, 0x05, 0x67, 0x65, 0xbc, 0x84, 0x61, 0x85, 0x10, 0x72, 0xc9, 0xd7,
];
