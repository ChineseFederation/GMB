use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};

use citizen_sdk_contracts::{
    ChainIdentity, ContractFuture, ContractStream, ExecutionConclusion, ExportedChainState,
    ExtrinsicWatchEvent, FinalizedBlockRef, Hash32, RuntimeContext, RuntimeVersion,
    SignedExtrinsic, StateImportReceipt, SubmittedExtrinsic, UnverifiedReason, VerifiedBlockRef,
    VerifiedChainClient,
};
use citizen_sdk_engine::{
    signed_extrinsic_hash, CitizenEngine, EngineComponents, EngineLifecycle, StateImportPolicy,
};

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex");
const EVENTS_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-system-events.hex");

fn hex_bytes(value: &str) -> Vec<u8> {
    let value = value.trim();
    let Some(value) = value.strip_prefix("0x") else {
        panic!("fixture must use 0x prefix");
    };
    value
        .as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            let text = match std::str::from_utf8(pair) {
                Ok(text) => text,
                Err(error) => panic!("fixture is not UTF-8 hex: {error}"),
            };
            match u8::from_str_radix(text, 16) {
                Ok(byte) => byte,
                Err(error) => panic!("fixture contains invalid hex: {error}"),
            }
        })
        .collect()
}

fn identity(genesis: u8) -> ChainIdentity {
    match ChainIdentity::try_new(
        "citizenchain",
        "citizenchain",
        Hash32::from_bytes([genesis; 32]),
    ) {
        Ok(identity) => identity,
        Err(error) => panic!("identity fixture failed: {error}"),
    }
}

struct FakeClient {
    block: VerifiedBlockRef,
    context: RuntimeContext,
    extrinsics: Vec<Vec<u8>>,
    events: Option<Vec<u8>>,
    imports: Arc<AtomicUsize>,
}

impl VerifiedChainClient for FakeClient {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity> {
        Box::pin(async { Ok(identity(7)) })
    }

    fn get_best_head(&self) -> ContractFuture<'_, VerifiedBlockRef> {
        Box::pin(async move { Ok(self.block) })
    }

    fn get_finalized_head(&self) -> ContractFuture<'_, FinalizedBlockRef> {
        Box::pin(async move { self.block.require_finalized() })
    }

    fn get_storage_at(
        &self,
        _block: VerifiedBlockRef,
        _key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>> {
        Box::pin(async move { Ok(self.events.clone()) })
    }

    fn get_storage_batch_at(
        &self,
        _block: VerifiedBlockRef,
        keys: Vec<Vec<u8>>,
    ) -> ContractFuture<'_, Vec<Option<Vec<u8>>>> {
        Box::pin(async move { Ok(keys.into_iter().map(|_| None).collect()) })
    }

    fn get_runtime_context_at(
        &self,
        _block: VerifiedBlockRef,
    ) -> ContractFuture<'_, RuntimeContext> {
        Box::pin(async move { Ok(self.context.clone()) })
    }

    fn get_block_extrinsics_at(
        &self,
        _block: VerifiedBlockRef,
    ) -> ContractFuture<'_, Vec<Vec<u8>>> {
        Box::pin(async move { Ok(self.extrinsics.clone()) })
    }

    fn submit_extrinsic(
        &self,
        _extrinsic: SignedExtrinsic,
    ) -> ContractFuture<'_, SubmittedExtrinsic> {
        Box::pin(async { Ok(SubmittedExtrinsic::new(Hash32::from_bytes([1; 32]))) })
    }

    fn watch_extrinsic(
        &self,
        _extrinsic: SignedExtrinsic,
    ) -> ContractStream<'_, ExtrinsicWatchEvent> {
        Box::pin(futures::stream::empty())
    }

    fn export_state(&self) -> ContractFuture<'_, ExportedChainState> {
        Box::pin(async move {
            ExportedChainState::try_new(identity(7), 1, self.block.require_finalized()?, vec![1])
        })
    }

    fn import_state(&self, state: ExportedChainState) -> ContractFuture<'_, StateImportReceipt> {
        self.imports.fetch_add(1, Ordering::SeqCst);
        Box::pin(async move { Ok(StateImportReceipt::new(state.finalized())) })
    }
}

fn engine(
    events: Option<Vec<u8>>,
) -> (
    CitizenEngine,
    RuntimeContext,
    SignedExtrinsic,
    Arc<AtomicUsize>,
) {
    let block = VerifiedBlockRef::finalized(Hash32::from_bytes([9; 32]), 100);
    let context =
        match RuntimeContext::try_new(block, RuntimeVersion::new(100, 12), hex_bytes(METADATA_HEX))
        {
            Ok(context) => context,
            Err(error) => panic!("runtime fixture failed: {error}"),
        };
    let signed = match SignedExtrinsic::try_new(vec![0x0c, 0x84, 0x01, 0x02]) {
        Ok(extrinsic) => extrinsic,
        Err(error) => panic!("extrinsic fixture failed: {error}"),
    };
    let imports = Arc::new(AtomicUsize::new(0));
    let client = Arc::new(FakeClient {
        block,
        context: context.clone(),
        extrinsics: vec![signed.as_bytes().to_vec()],
        events,
        imports: Arc::clone(&imports),
    });
    let components = EngineComponents::new(client, None, None, None, None, None, None, None);
    (CitizenEngine::new(components), context, signed, imports)
}

#[test]
fn engine_gathers_provider_evidence_without_arbitrary_rpc() {
    let (engine, context, signed, _) = engine(Some(hex_bytes(EVENTS_HEX)));
    assert!(engine.components().signer().is_none());
    assert!(engine.components().secret_vault().is_none());
    let hash = match signed_extrinsic_hash(&context, &signed) {
        Ok(hash) => hash,
        Err(error) => panic!("hash failed: {error}"),
    };
    let outcome = match futures::executor::block_on(engine.verify_transaction_at(
        context.block(),
        signed,
        hash,
    )) {
        Ok(outcome) => outcome,
        Err(error) => panic!("engine verification failed: {error}"),
    };
    assert!(matches!(outcome, ExecutionConclusion::Success { .. }));
}

#[test]
fn missing_events_remain_unverified() {
    let (engine, context, signed, _) = engine(None);
    let hash = match signed_extrinsic_hash(&context, &signed) {
        Ok(hash) => hash,
        Err(error) => panic!("hash failed: {error}"),
    };
    let outcome = match futures::executor::block_on(engine.verify_transaction_at(
        context.block(),
        signed,
        hash,
    )) {
        Ok(outcome) => outcome,
        Err(error) => panic!("engine verification failed: {error}"),
    };
    assert!(matches!(
        outcome,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::SystemEventsUnavailable,
            ..
        }
    ));
}

#[test]
fn failed_import_preflight_never_reaches_provider() {
    let (engine, context, _, imports) = engine(None);
    let chain = identity(7);
    let state = match ExportedChainState::try_new(
        chain.clone(),
        1,
        context
            .block()
            .require_finalized()
            .unwrap_or_else(|error| panic!("finalized fixture failed: {error}")),
        vec![1],
    ) {
        Ok(state) => state,
        Err(error) => panic!("state fixture failed: {error}"),
    };
    let policy = StateImportPolicy::new(chain, 1, None);
    let result =
        futures::executor::block_on(engine.import_state(&policy, EngineLifecycle::Running, state));
    assert!(result.is_err());
    assert_eq!(imports.load(Ordering::SeqCst), 0);
}
