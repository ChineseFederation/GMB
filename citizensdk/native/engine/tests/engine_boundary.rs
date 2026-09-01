use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};

use citizen_sdk_contracts::{
    CapabilityName, CapabilityReason, ChainIdentity, ContractFuture, ContractStream,
    ExecutionConclusion, ExportedChainState, ExtrinsicWatchEvent, FinalizedBlockRef, Hash32,
    RuntimeContext, RuntimeVersion, SignedExtrinsic, StateImportReceipt, SubmittedExtrinsic,
    UnverifiedReason, VerifiedBlockRef, VerifiedChainClient,
};
use citizen_sdk_engine::{
    signed_extrinsic_hash, CapabilityProbe, CitizenEngine, EngineComponents, EngineLifecycle,
    CHAIN_STATE_FORMAT_VERSION,
};

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex");
const EVENTS_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-system-events.hex");
const SYSTEM_EVENTS_STORAGE_KEY: [u8; 32] = [
    0x26, 0xaa, 0x39, 0x4e, 0xea, 0x56, 0x30, 0xe0, 0x7c, 0x48, 0xae, 0x0c, 0x95, 0x58, 0xce, 0xf7,
    0x80, 0xd4, 0x1e, 0x5e, 0x16, 0x05, 0x67, 0x65, 0xbc, 0x84, 0x61, 0x85, 0x10, 0x72, 0xc9, 0xd7,
];

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
    evidence_reads: Arc<AtomicUsize>,
    exports: Arc<AtomicUsize>,
}

impl VerifiedChainClient for FakeClient {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity> {
        Box::pin(async { Ok(ChainIdentity::citizenchain()) })
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
        key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>> {
        self.evidence_reads.fetch_add(1, Ordering::SeqCst);
        Box::pin(async move {
            Ok((key.as_slice() == SYSTEM_EVENTS_STORAGE_KEY)
                .then(|| self.events.clone())
                .flatten())
        })
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
        self.evidence_reads.fetch_add(1, Ordering::SeqCst);
        Box::pin(async move { Ok(self.context.clone()) })
    }

    fn get_block_extrinsics_at(
        &self,
        _block: VerifiedBlockRef,
    ) -> ContractFuture<'_, Vec<Vec<u8>>> {
        self.evidence_reads.fetch_add(1, Ordering::SeqCst);
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
        self.exports.fetch_add(1, Ordering::SeqCst);
        Box::pin(async move {
            ExportedChainState::try_new(
                ChainIdentity::citizenchain(),
                CHAIN_STATE_FORMAT_VERSION,
                self.block.require_finalized()?,
                vec![1],
            )
        })
    }

    fn import_state(&self, state: ExportedChainState) -> ContractFuture<'_, StateImportReceipt> {
        self.imports.fetch_add(1, Ordering::SeqCst);
        Box::pin(async move { Ok(StateImportReceipt::new(state.finalized())) })
    }
}

#[derive(Clone)]
struct FakeCounters {
    imports: Arc<AtomicUsize>,
    evidence_reads: Arc<AtomicUsize>,
    exports: Arc<AtomicUsize>,
}

fn all_ready() -> Vec<CapabilityProbe> {
    CapabilityName::ALL
        .into_iter()
        .map(CapabilityProbe::ready)
        .collect()
}

fn engine(
    events: Option<Vec<u8>>,
) -> (
    CitizenEngine,
    RuntimeContext,
    SignedExtrinsic,
    FakeCounters,
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
    let evidence_reads = Arc::new(AtomicUsize::new(0));
    let exports = Arc::new(AtomicUsize::new(0));
    let client = Arc::new(FakeClient {
        block,
        context: context.clone(),
        extrinsics: vec![signed.as_bytes().to_vec()],
        events,
        imports: Arc::clone(&imports),
        evidence_reads: Arc::clone(&evidence_reads),
        exports: Arc::clone(&exports),
    });
    let components = EngineComponents::new(client, None, None, None, None, None, None, None);
    let engine = CitizenEngine::new(components);
    if let Err(error) = engine.update_capabilities(all_ready()) {
        panic!("capability initialization failed: {error}");
    }
    (
        engine,
        context,
        signed,
        FakeCounters {
            imports,
            evidence_reads,
            exports,
        },
    )
}

#[test]
fn engine_gathers_provider_evidence_without_arbitrary_rpc() {
    let (engine, context, signed, _) = engine(Some(hex_bytes(EVENTS_HEX)));
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
fn capability_change_is_rechecked_before_provider_evidence() {
    let (engine, context, signed, counters) = engine(Some(hex_bytes(EVENTS_HEX)));
    let mut unavailable = all_ready();
    let chain = unavailable
        .iter_mut()
        .find(|probe| probe.name == CapabilityName::ChainRead)
        .unwrap_or_else(|| panic!("CHAIN_READ probe missing"));
    chain.runtime_ready = false;
    chain.not_ready_reason = Some(CapabilityReason::ChainUnsynced);
    if let Err(error) = engine.update_capabilities(unavailable) {
        panic!("capability update failed: {error}");
    }
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
        Err(error) => panic!("capability gate returned an unexpected error: {error}"),
    };
    assert!(matches!(
        outcome,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::ProviderFailure,
            ..
        }
    ));
    assert_eq!(counters.evidence_reads.load(Ordering::SeqCst), 0);
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
    let (engine, context, _, counters) = engine(None);
    let chain = identity(7);
    let state = match ExportedChainState::try_new(
        chain.clone(),
        CHAIN_STATE_FORMAT_VERSION,
        context
            .block()
            .require_finalized()
            .unwrap_or_else(|error| panic!("finalized fixture failed: {error}")),
        vec![1],
    ) {
        Ok(state) => state,
        Err(error) => panic!("state fixture failed: {error}"),
    };
    let result = futures::executor::block_on(engine.import_state(state));
    assert!(result.is_err());
    assert_eq!(counters.imports.load(Ordering::SeqCst), 0);
}

#[test]
fn engine_owns_import_startup_and_export_lifecycle() {
    let (engine, context, _, counters) = engine(None);
    let finalized = context
        .block()
        .require_finalized()
        .unwrap_or_else(|error| panic!("finalized fixture failed: {error}"));
    let imported = match ExportedChainState::try_new(
        ChainIdentity::citizenchain(),
        CHAIN_STATE_FORMAT_VERSION,
        finalized,
        vec![1],
    ) {
        Ok(state) => state,
        Err(error) => panic!("state fixture failed: {error}"),
    };
    if let Err(error) = futures::executor::block_on(engine.import_state(imported.clone())) {
        panic!("valid pre-start import failed: {error}");
    }
    assert_eq!(counters.imports.load(Ordering::SeqCst), 1);
    assert_eq!(engine.lifecycle(), Ok(EngineLifecycle::Created));

    if let Err(error) = engine.begin_provider_start() {
        panic!("provider start reservation failed: {error}");
    }
    assert!(futures::executor::block_on(engine.import_state(imported)).is_err());
    assert_eq!(counters.imports.load(Ordering::SeqCst), 1);
    let started = match futures::executor::block_on(engine.complete_provider_start()) {
        Ok(finalized) => finalized,
        Err(error) => panic!("provider startup verification failed: {error}"),
    };
    assert_eq!(started, finalized);
    assert_eq!(engine.lifecycle(), Ok(EngineLifecycle::Running));

    let exported = match futures::executor::block_on(engine.export_state()) {
        Ok(state) => state,
        Err(error) => panic!("stable state export failed: {error}"),
    };
    assert_eq!(exported.finalized(), finalized);
    assert_eq!(counters.exports.load(Ordering::SeqCst), 1);
}
