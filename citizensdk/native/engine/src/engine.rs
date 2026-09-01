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
    ChainSigner, ExecutionConclusion, ExportedChainState, Hash32, RuntimeContext, SecretVault,
    SignedExtrinsic, StateImportReceipt, UnverifiedReason, VerifiedBlockRef, VerifiedChainClient,
};

use crate::{
    error::EngineError,
    runtime_context::RuntimeContextCache,
    state_import::{validate_state_import, EngineLifecycle, StateImportPolicy},
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

    pub fn chain_client(&self) -> &Arc<dyn VerifiedChainClient> {
        &self.chain_client
    }

    pub fn signer(&self) -> Option<&Arc<dyn ChainSigner>> {
        self.signer.as_ref()
    }

    pub fn secret_vault(&self) -> Option<&Arc<dyn SecretVault>> {
        self.secret_vault.as_ref()
    }

    pub fn chain_database(&self) -> Option<&Arc<dyn ChainDatabaseStore>> {
        self.chain_database.as_ref()
    }

    pub fn runtime_cache(&self) -> Option<&Arc<dyn RuntimeCacheStore>> {
        self.runtime_cache.as_ref()
    }

    pub fn wallet_profiles(&self) -> Option<&Arc<dyn WalletProfileStore>> {
        self.wallet_profiles.as_ref()
    }

    pub fn transaction_history(&self) -> Option<&Arc<dyn TransactionHistoryStore>> {
        self.transaction_history.as_ref()
    }

    pub fn encrypted_secrets(&self) -> Option<&Arc<dyn EncryptedSecretBlobStore>> {
        self.encrypted_secrets.as_ref()
    }
}

/// Product-independent CitizenSDK Core Engine.
pub struct CitizenEngine {
    components: EngineComponents,
    runtime_contexts: Mutex<RuntimeContextCache>,
}

impl CitizenEngine {
    pub fn new(components: EngineComponents) -> Self {
        Self {
            components,
            runtime_contexts: Mutex::new(RuntimeContextCache::new()),
        }
    }

    pub const fn components(&self) -> &EngineComponents {
        &self.components
    }

    /// Load a context at one exact block and reject provider cross-block data.
    pub fn runtime_context_at(&self, block: VerifiedBlockRef) -> EngineFuture<'_, RuntimeContext> {
        Box::pin(async move {
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
    pub fn import_state(
        &self,
        policy: &StateImportPolicy,
        lifecycle: EngineLifecycle,
        state: ExportedChainState,
    ) -> EngineFuture<'_, StateImportReceipt> {
        let validation = validate_state_import(policy, lifecycle, &state);
        Box::pin(async move {
            validation.map_err(|reason| EngineError::Contract(format!("{reason:?}")))?;
            let expected = state.finalized();
            let receipt = self
                .components
                .chain_client()
                .import_state(state)
                .await
                .map_err(|error| EngineError::Contract(error.to_string()))?;
            if receipt.finalized() != expected {
                return Err(EngineError::BlockContextMismatch(
                    "state import receipt changed the finalized anchor".to_owned(),
                ));
            }
            Ok(receipt)
        })
    }
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
