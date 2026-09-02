//! 高层钱包 submit-and-watch、准确 finalized 终态和中断持久门测试。

#![allow(clippy::expect_used, clippy::unwrap_used)]

use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex,
};

use citizen_sdk_contracts::{
    store::{HistoryTransactionStatus, TransactionHistoryState, TransactionHistoryStore},
    AccountId32, ChainIdentity, ContractError, ContractErrorCode, ContractFuture, ContractResult,
    ContractStream, ExecutionConclusion, ExportedChainState, ExtrinsicWatchEvent,
    FinalizedBlockRef, Hash32, RuntimeContext, RuntimeVersion, SignedExtrinsic, StateImportReceipt,
    SubmittedExtrinsic, VerifiedBlockRef, VerifiedChainClient,
};
use futures::executor::block_on;

use crate::{
    finalized_history_runtime::{FinalizedHistoryRunGuard, FinalizedHistoryRuntime},
    signed_extrinsic_hash,
    transaction_history::TransactionHistoryService,
    wallet_service::WalletClock,
    wallet_transfer_watch::{
        watch_recorded_transfer, WalletTransferObserver, WalletTransferResolution,
        WalletTransferWatchStage, WalletTransferWatchUpdate,
    },
    EngineError,
};

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex");
const EVENTS_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-system-events.hex");
const FIXTURE_EXTRINSIC: &[u8] = &[0x0c, 0x84, 0x01, 0x02];

#[derive(Debug)]
struct MemoryHistoryStore {
    state: Mutex<TransactionHistoryState>,
}

impl Default for MemoryHistoryStore {
    fn default() -> Self {
        Self {
            state: Mutex::new(
                TransactionHistoryState::try_new(0, Vec::new(), Vec::new(), Vec::new())
                    .expect("空历史状态有效"),
            ),
        }
    }
}

impl MemoryHistoryStore {
    fn snapshot(&self) -> TransactionHistoryState {
        self.state.lock().unwrap().clone()
    }
}

impl TransactionHistoryStore for MemoryHistoryStore {
    fn load(&self) -> ContractFuture<'_, TransactionHistoryState> {
        Box::pin(async move { Ok(self.state.lock().unwrap().clone()) })
    }

    fn compare_and_swap(
        &self,
        expected_revision: u64,
        next: TransactionHistoryState,
    ) -> ContractFuture<'_, TransactionHistoryState> {
        Box::pin(async move {
            let mut state = self.state.lock().unwrap();
            if state.revision() != expected_revision {
                return Err(ContractError::new(
                    ContractErrorCode::Conflict,
                    "测试历史 revision 冲突",
                ));
            }
            *state = next.clone();
            Ok(next)
        })
    }
}

#[derive(Debug, Default)]
struct TestClock(AtomicU64);

impl WalletClock for TestClock {
    fn now_millis(&self) -> ContractResult<u64> {
        Ok(2_000_000_000_000 + self.0.fetch_add(1, Ordering::SeqCst))
    }
}

#[derive(Debug, Default)]
struct AlwaysRunning;

impl FinalizedHistoryRunGuard for AlwaysRunning {
    fn ensure_current(&self) -> Result<(), EngineError> {
        Ok(())
    }
}

#[derive(Debug, Default)]
struct RecordingObserver {
    updates: Mutex<Vec<WalletTransferWatchUpdate>>,
    panic_on_update: bool,
}

impl RecordingObserver {
    fn stages(&self) -> Vec<WalletTransferWatchStage> {
        self.updates
            .lock()
            .unwrap()
            .iter()
            .map(|update| update.stage().clone())
            .collect()
    }
}

impl WalletTransferObserver for RecordingObserver {
    fn on_update(&self, update: WalletTransferWatchUpdate) {
        if self.panic_on_update {
            panic!("测试观察器 panic");
        }
        self.updates.lock().unwrap().push(update);
    }
}

struct FakeChainClient {
    head: u64,
    metadata: Vec<u8>,
    events: Vec<u8>,
    body: Mutex<Vec<Vec<u8>>>,
    watch_events: Mutex<Option<Vec<ContractResult<ExtrinsicWatchEvent>>>>,
    expected_extrinsic: Vec<u8>,
    history_store: Arc<MemoryHistoryStore>,
    watch_saw_pending: AtomicBool,
}

impl FakeChainClient {
    fn new(
        head: u64,
        watch_events: Vec<ContractResult<ExtrinsicWatchEvent>>,
        store: Arc<MemoryHistoryStore>,
    ) -> Self {
        Self {
            head,
            metadata: hex_bytes(METADATA_HEX),
            events: hex_bytes(EVENTS_HEX),
            body: Mutex::new(vec![FIXTURE_EXTRINSIC.to_vec(), vec![0x08, 0x84, 0x03]]),
            watch_events: Mutex::new(Some(watch_events)),
            expected_extrinsic: FIXTURE_EXTRINSIC.to_vec(),
            history_store: store,
            watch_saw_pending: AtomicBool::new(false),
        }
    }
}

impl VerifiedChainClient for FakeChainClient {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity> {
        Box::pin(async { Ok(ChainIdentity::citizenchain()) })
    }

    fn get_best_head(&self) -> ContractFuture<'_, VerifiedBlockRef> {
        let head = block(self.head);
        Box::pin(async move { Ok(VerifiedBlockRef::best(head.hash(), head.number())) })
    }

    fn get_finalized_head(&self) -> ContractFuture<'_, FinalizedBlockRef> {
        let head = block(self.head);
        Box::pin(async move { Ok(head) })
    }

    fn get_finalized_block_at(&self, number: u64) -> ContractFuture<'_, FinalizedBlockRef> {
        let head = self.head;
        Box::pin(async move {
            if number > head {
                return Err(ContractError::new(
                    ContractErrorCode::NotFound,
                    "测试高度尚未 finalized",
                ));
            }
            Ok(block(number))
        })
    }

    fn get_finalized_blocks_at(
        &self,
        start_number: u64,
        end_number: u64,
    ) -> ContractFuture<'_, Vec<FinalizedBlockRef>> {
        let head = self.head;
        Box::pin(async move {
            if start_number > end_number || end_number > head {
                return Err(ContractError::new(
                    ContractErrorCode::NotFound,
                    "测试 finalized 区间无效",
                ));
            }
            Ok((start_number..=end_number).map(block).collect())
        })
    }

    fn get_storage_at(
        &self,
        _block: VerifiedBlockRef,
        _key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>> {
        let events = self.events.clone();
        Box::pin(async move { Ok(Some(events)) })
    }

    fn get_storage_batch_at(
        &self,
        _block: VerifiedBlockRef,
        keys: Vec<Vec<u8>>,
    ) -> ContractFuture<'_, Vec<Option<Vec<u8>>>> {
        let events = self.events.clone();
        Box::pin(async move { Ok(keys.into_iter().map(|_| Some(events.clone())).collect()) })
    }

    fn get_runtime_context_at(
        &self,
        block: VerifiedBlockRef,
    ) -> ContractFuture<'_, RuntimeContext> {
        let metadata = self.metadata.clone();
        Box::pin(
            async move { RuntimeContext::try_new(block, RuntimeVersion::new(100, 12), metadata) },
        )
    }

    fn get_block_extrinsics_at(
        &self,
        _block: VerifiedBlockRef,
    ) -> ContractFuture<'_, Vec<Vec<u8>>> {
        let body = self.body.lock().unwrap().clone();
        Box::pin(async move { Ok(body) })
    }

    fn submit_extrinsic(
        &self,
        _extrinsic: SignedExtrinsic,
    ) -> ContractFuture<'_, SubmittedExtrinsic> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::InvalidState,
                "高层钱包协调器不得调用 submit_extrinsic",
            ))
        })
    }

    fn watch_extrinsic(
        &self,
        extrinsic: SignedExtrinsic,
    ) -> ContractStream<'_, ExtrinsicWatchEvent> {
        assert_eq!(extrinsic.as_bytes(), self.expected_extrinsic);
        let snapshot = self.history_store.snapshot();
        self.watch_saw_pending.store(
            snapshot.records().len() == 1
                && matches!(
                    snapshot.records()[0].status(),
                    HistoryTransactionStatus::Pending
                ),
            Ordering::SeqCst,
        );
        let events = self
            .watch_events
            .lock()
            .unwrap()
            .take()
            .expect("每个测试 client 只允许启动一次 watch");
        Box::pin(futures::stream::iter(events))
    }

    fn export_state(&self) -> ContractFuture<'_, ExportedChainState> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "测试不导出状态",
            ))
        })
    }

    fn import_state(&self, _state: ExportedChainState) -> ContractFuture<'_, StateImportReceipt> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "测试不导入状态",
            ))
        })
    }
}

struct Harness {
    client: Arc<FakeChainClient>,
    runtime: FinalizedHistoryRuntime,
    history: TransactionHistoryService,
    store: Arc<MemoryHistoryStore>,
    account_id: AccountId32,
    transaction_hash: Hash32,
    signed: SignedExtrinsic,
}

impl Harness {
    async fn new(watch_events: Vec<ContractResult<ExtrinsicWatchEvent>>) -> Self {
        let store = Arc::new(MemoryHistoryStore::default());
        let history = TransactionHistoryService::new(store.clone(), Arc::new(TestClock::default()));
        let account_id = account(0x11);
        let destination = account(0x22);
        let signed = SignedExtrinsic::try_new(FIXTURE_EXTRINSIC.to_vec()).unwrap();
        let context = RuntimeContext::try_new(
            block(1).verified(),
            RuntimeVersion::new(100, 12),
            hex_bytes(METADATA_HEX),
        )
        .unwrap();
        let transaction_hash = signed_extrinsic_hash(&context, &signed).unwrap();
        history
            .ensure_cursors(&[account_id], block(0))
            .await
            .unwrap();
        history
            .record_pending_before_broadcast(
                account_id,
                transaction_hash,
                0,
                destination,
                123_456,
                "CitizenSDK production Runtime fixture",
            )
            .await
            .unwrap();
        let client = Arc::new(FakeChainClient::new(1, watch_events, store.clone()));
        let runtime = FinalizedHistoryRuntime::new(client.clone(), history.clone());
        Self {
            client,
            runtime,
            history,
            store,
            account_id,
            transaction_hash,
            signed,
        }
    }

    async fn watch(
        &self,
        observer: Arc<dyn WalletTransferObserver>,
    ) -> Result<crate::WalletTransferWatchResult, EngineError> {
        watch_recorded_transfer(
            self.client.as_ref(),
            &self.runtime,
            &self.history,
            &AlwaysRunning,
            &observer,
            self.account_id,
            self.transaction_hash,
            self.signed.clone(),
        )
        .await
    }
}

#[test]
fn pending_precedes_provider_and_finalized_requires_exact_system_outcome() {
    block_on(async {
        let finalized = block(1);
        let harness = Harness::new(vec![
            Ok(ExtrinsicWatchEvent::Ready),
            Ok(ExtrinsicWatchEvent::InBlock {
                block: VerifiedBlockRef::best(finalized.hash(), finalized.number()),
            }),
            Ok(ExtrinsicWatchEvent::Finalized { block: finalized }),
        ])
        .await;
        let observer = Arc::new(RecordingObserver::default());
        let result = harness.watch(observer.clone()).await.unwrap();

        assert!(harness.client.watch_saw_pending.load(Ordering::SeqCst));
        assert_eq!(result.transaction_hash(), harness.transaction_hash);
        assert!(matches!(
            result.resolution(),
            WalletTransferResolution::Finalized(ExecutionConclusion::Success {
                block,
                extrinsic_index: 0,
            }) if *block == finalized.verified()
        ));
        assert!(matches!(
            result.history().records()[0].status(),
            HistoryTransactionStatus::Execution(ExecutionConclusion::Success { .. })
        ));
        assert!(matches!(
            observer.stages().as_slice(),
            [
                WalletTransferWatchStage::Pending,
                WalletTransferWatchStage::Ready,
                WalletTransferWatchStage::InBlock { .. },
                WalletTransferWatchStage::Finalized { .. }
            ]
        ));
    });
}

#[test]
fn invalid_and_usurped_are_pool_rejections_not_chain_success() {
    block_on(async {
        for (event, expected_replacement) in [
            (ExtrinsicWatchEvent::Invalid, None),
            (
                ExtrinsicWatchEvent::Usurped {
                    replacement_hash: hash(0xaa),
                },
                Some(hash(0xaa)),
            ),
        ] {
            let harness = Harness::new(vec![Ok(event)]).await;
            let observer = Arc::new(RecordingObserver::default());
            let result = harness.watch(observer.clone()).await.unwrap();
            assert!(matches!(
                result.resolution(),
                WalletTransferResolution::PoolRejected { .. }
            ));
            assert!(result.history().records()[0]
                .status()
                .pool_rejection_reason()
                .is_some());
            assert!(matches!(
                observer.stages().last(),
                Some(WalletTransferWatchStage::PoolRejected {
                    replacement_hash,
                    ..
                }) if *replacement_hash == expected_replacement
            ));
        }
    });
}

#[test]
fn finalized_watch_fact_without_exact_body_and_system_outcome_never_becomes_success() {
    block_on(async {
        let finalized = block(1);
        let harness = Harness::new(vec![Ok(ExtrinsicWatchEvent::Finalized {
            block: finalized,
        })])
        .await;
        *harness.client.body.lock().unwrap() = vec![vec![0x08, 0x84, 0x03]];

        let error = harness
            .watch(Arc::new(RecordingObserver::default()))
            .await
            .unwrap_err();
        assert!(matches!(error, EngineError::InvalidEvents(_)));
        assert!(matches!(
            harness.store.snapshot().records()[0].status(),
            HistoryTransactionStatus::Pending
        ));
    });
}

#[test]
fn disconnect_and_nondefinitive_watch_failures_keep_the_durable_account_gate() {
    block_on(async {
        let event_sets = vec![
            Vec::new(),
            vec![Ok(ExtrinsicWatchEvent::Dropped)],
            vec![
                Ok(ExtrinsicWatchEvent::InBlock {
                    block: VerifiedBlockRef::best(hash(0x51), 5),
                }),
                Ok(ExtrinsicWatchEvent::Retracted {
                    block: VerifiedBlockRef::best(hash(0x51), 5),
                }),
            ],
            vec![Ok(ExtrinsicWatchEvent::FinalityTimeout { block: None })],
        ];
        for events in event_sets {
            let harness = Harness::new(events).await;
            let observer = Arc::new(RecordingObserver::default());
            let error = harness.watch(observer).await.unwrap_err();
            assert!(matches!(error, EngineError::Contract(_)));
            assert!(matches!(
                harness.store.snapshot().records()[0].status(),
                HistoryTransactionStatus::Pending | HistoryTransactionStatus::InBlock { .. }
            ));
            let conflict = harness
                .history
                .record_pending_before_broadcast(
                    harness.account_id,
                    hash(0xbb),
                    0,
                    account(0x33),
                    1,
                    "must remain gated",
                )
                .await
                .unwrap_err();
            assert!(matches!(
                conflict,
                EngineError::Contract(ref inner) if inner.code() == ContractErrorCode::Conflict
            ));
        }
    });
}

#[test]
fn provider_error_notifies_interruption_and_observer_panic_cannot_abort_terminal_state() {
    block_on(async {
        let disconnected = Harness::new(vec![Err(ContractError::new(
            ContractErrorCode::Network,
            "测试断线",
        ))])
        .await;
        let observer = Arc::new(RecordingObserver::default());
        let error = disconnected.watch(observer.clone()).await.unwrap_err();
        assert!(matches!(
            error,
            EngineError::Contract(ref inner) if inner.code() == ContractErrorCode::Network
        ));
        assert!(matches!(
            observer.stages().last(),
            Some(WalletTransferWatchStage::Interrupted { .. })
        ));
        assert!(matches!(
            disconnected.store.snapshot().records()[0].status(),
            HistoryTransactionStatus::Pending
        ));

        let rejected = Harness::new(vec![Ok(ExtrinsicWatchEvent::Invalid)]).await;
        let panicking: Arc<dyn WalletTransferObserver> = Arc::new(RecordingObserver {
            updates: Mutex::new(Vec::new()),
            panic_on_update: true,
        });
        let result = rejected.watch(panicking).await.unwrap();
        assert!(matches!(
            result.resolution(),
            WalletTransferResolution::PoolRejected { .. }
        ));
    });
}

fn account(byte: u8) -> AccountId32 {
    AccountId32::from_bytes([byte; 32])
}

fn hash(byte: u8) -> Hash32 {
    Hash32::from_bytes([byte; 32])
}

fn block(number: u64) -> FinalizedBlockRef {
    let mut bytes = [0_u8; 32];
    bytes[..8].copy_from_slice(&number.to_le_bytes());
    bytes[8..].fill(0x5a);
    FinalizedBlockRef::from_parts(Hash32::from_bytes(bytes), number)
}

fn hex_bytes(value: &str) -> Vec<u8> {
    let value = value.trim().strip_prefix("0x").unwrap_or(value.trim());
    value
        .as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            let text = std::str::from_utf8(pair).unwrap();
            u8::from_str_radix(text, 16).unwrap()
        })
        .collect()
}
