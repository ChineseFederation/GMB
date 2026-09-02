//! finalized 批处理、严格终态和 typed watch 的确定性合同测试。

#![allow(clippy::expect_used, clippy::unwrap_used)]

use std::{
    sync::{
        atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering},
        Arc, Mutex,
    },
    task::{Context, Poll},
};

use citizen_sdk_contracts::{
    store::{HistoryTransactionStatus, TransactionHistoryState, TransactionHistoryStore},
    AccountId32, CapabilityName, ChainIdentity, ContractError, ContractErrorCode, ContractFuture,
    ContractResult, ContractStream, ExportedChainState, ExtrinsicWatchEvent, FinalizedBlockRef,
    Hash32, RuntimeContext, RuntimeVersion, SignedExtrinsic, StateImportReceipt,
    SubmittedExtrinsic, VerifiedBlockRef, VerifiedChainClient, MAX_FINALIZED_BLOCKS_PER_BATCH,
};
use futures::{channel::oneshot, executor::block_on, task::noop_waker};

use crate::{
    capabilities::CapabilityProbe,
    engine::{CitizenEngine, EngineComponents},
    finalized_history_runtime::{FinalizedHistoryRunGuard, FinalizedHistoryRuntime},
    signed_extrinsic_hash,
    transaction_history::TransactionHistoryService,
    wallet_service::WalletClock,
    EngineError,
};

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex");
const EVENTS_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-system-events.hex");

#[derive(Debug)]
struct MemoryHistoryStore {
    state: Mutex<TransactionHistoryState>,
    cas_calls: AtomicUsize,
}

impl Default for MemoryHistoryStore {
    fn default() -> Self {
        Self {
            state: Mutex::new(
                TransactionHistoryState::try_new(0, Vec::new(), Vec::new(), Vec::new())
                    .expect("空历史状态有效"),
            ),
            cas_calls: AtomicUsize::new(0),
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
            if next.revision() != expected_revision.saturating_add(1) {
                return Err(ContractError::new(
                    ContractErrorCode::Storage,
                    "测试历史 candidate revision 不连续",
                ));
            }
            self.cas_calls.fetch_add(1, Ordering::SeqCst);
            *state = next.clone();
            Ok(next)
        })
    }
}

/// 把 CAS 精确暂停在 await 中，用来证明 stop/dispose 不能穿越最终持久化窗口。
#[derive(Debug)]
struct PausedHistoryStore {
    state: Mutex<TransactionHistoryState>,
    receiver: Mutex<Option<oneshot::Receiver<()>>>,
    cas_entered: AtomicBool,
}

impl PausedHistoryStore {
    fn new(receiver: oneshot::Receiver<()>) -> Self {
        Self {
            state: Mutex::new(
                TransactionHistoryState::try_new(0, Vec::new(), Vec::new(), Vec::new())
                    .expect("空历史状态有效"),
            ),
            receiver: Mutex::new(Some(receiver)),
            cas_entered: AtomicBool::new(false),
        }
    }
}

impl TransactionHistoryStore for PausedHistoryStore {
    fn load(&self) -> ContractFuture<'_, TransactionHistoryState> {
        Box::pin(async move { Ok(self.state.lock().unwrap().clone()) })
    }

    fn compare_and_swap(
        &self,
        expected_revision: u64,
        next: TransactionHistoryState,
    ) -> ContractFuture<'_, TransactionHistoryState> {
        let receiver = self
            .receiver
            .lock()
            .unwrap()
            .take()
            .expect("暂停仓储只允许一次 CAS");
        self.cas_entered.store(true, Ordering::SeqCst);
        Box::pin(async move {
            receiver.await.map_err(|_| {
                ContractError::new(ContractErrorCode::Storage, "测试 CAS 放行端被丢弃")
            })?;
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
        Ok(1_900_000_000_000 + self.0.fetch_add(1, Ordering::SeqCst))
    }
}

struct TestGuard(Arc<AtomicBool>);

impl FinalizedHistoryRunGuard for TestGuard {
    fn ensure_current(&self) -> Result<(), EngineError> {
        if self.0.load(Ordering::SeqCst) {
            Ok(())
        } else {
            Err(EngineError::contract(
                ContractErrorCode::InvalidState,
                "测试代际已停止",
            ))
        }
    }
}

struct FakeChainClient {
    head: u64,
    metadata: Vec<u8>,
    events: Vec<u8>,
    missing_events_at: Option<u64>,
    stop_at_block_request: Option<u64>,
    running: Arc<AtomicBool>,
    block_requests: Arc<AtomicUsize>,
}

impl VerifiedChainClient for FakeChainClient {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity> {
        Box::pin(async { Ok(ChainIdentity::citizenchain()) })
    }

    fn get_best_head(&self) -> ContractFuture<'_, VerifiedBlockRef> {
        let block = block(self.head);
        Box::pin(async move { Ok(VerifiedBlockRef::best(block.hash(), block.number())) })
    }

    fn get_finalized_head(&self) -> ContractFuture<'_, FinalizedBlockRef> {
        let block = block(self.head);
        Box::pin(async move { Ok(block) })
    }

    fn get_finalized_block_at(&self, number: u64) -> ContractFuture<'_, FinalizedBlockRef> {
        self.block_requests.fetch_add(1, Ordering::SeqCst);
        let head = self.head;
        let should_stop = self.stop_at_block_request == Some(number);
        let running = Arc::clone(&self.running);
        Box::pin(async move {
            if number > head {
                return Err(ContractError::new(
                    ContractErrorCode::NotFound,
                    "请求高度尚未 finalized",
                ));
            }
            if should_stop {
                running.store(false, Ordering::SeqCst);
            }
            Ok(block(number))
        })
    }

    fn get_finalized_blocks_at(
        &self,
        start_number: u64,
        end_number: u64,
    ) -> ContractFuture<'_, Vec<FinalizedBlockRef>> {
        self.block_requests.fetch_add(1, Ordering::SeqCst);
        let head = self.head;
        let should_stop = self
            .stop_at_block_request
            .is_some_and(|number| start_number <= number && number <= end_number);
        let running = Arc::clone(&self.running);
        Box::pin(async move {
            if start_number > end_number || end_number > head {
                return Err(ContractError::new(
                    ContractErrorCode::NotFound,
                    "请求区间尚未 finalized",
                ));
            }
            if should_stop {
                running.store(false, Ordering::SeqCst);
            }
            Ok((start_number..=end_number).map(block).collect())
        })
    }

    fn get_storage_at(
        &self,
        block: VerifiedBlockRef,
        _key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>> {
        let missing = self.missing_events_at == Some(block.number());
        let events = self.events.clone();
        Box::pin(async move { Ok((!missing).then_some(events)) })
    }

    fn get_storage_batch_at(
        &self,
        block: VerifiedBlockRef,
        keys: Vec<Vec<u8>>,
    ) -> ContractFuture<'_, Vec<Option<Vec<u8>>>> {
        let missing = self.missing_events_at == Some(block.number());
        let events = self.events.clone();
        Box::pin(async move {
            Ok(keys
                .into_iter()
                .map(|_| (!missing).then(|| events.clone()))
                .collect())
        })
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
        Box::pin(async { Ok(vec![vec![0x0c, 0x84, 0x01, 0x02], vec![0x08, 0x84, 0x03]]) })
    }

    fn submit_extrinsic(
        &self,
        _extrinsic: SignedExtrinsic,
    ) -> ContractFuture<'_, SubmittedExtrinsic> {
        Box::pin(async { Ok(SubmittedExtrinsic::new(hash(0xee))) })
    }

    fn watch_extrinsic(
        &self,
        _extrinsic: SignedExtrinsic,
    ) -> ContractStream<'_, ExtrinsicWatchEvent> {
        Box::pin(futures::stream::empty())
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
    runtime: FinalizedHistoryRuntime,
    history: TransactionHistoryService,
    store: Arc<MemoryHistoryStore>,
    running: Arc<AtomicBool>,
    block_requests: Arc<AtomicUsize>,
}

impl Harness {
    fn new(head: u64, missing_events_at: Option<u64>, stop_at: Option<u64>) -> Self {
        let store = Arc::new(MemoryHistoryStore::default());
        let history = TransactionHistoryService::new(store.clone(), Arc::new(TestClock::default()));
        let running = Arc::new(AtomicBool::new(true));
        let block_requests = Arc::new(AtomicUsize::new(0));
        let client = Arc::new(FakeChainClient {
            head,
            metadata: hex_bytes(METADATA_HEX),
            events: hex_bytes(EVENTS_HEX),
            missing_events_at,
            stop_at_block_request: stop_at,
            running: Arc::clone(&running),
            block_requests: Arc::clone(&block_requests),
        });
        let runtime = FinalizedHistoryRuntime::new(client, history.clone());
        Self {
            runtime,
            history,
            store,
            running,
            block_requests,
        }
    }

    fn guard(&self) -> TestGuard {
        TestGuard(Arc::clone(&self.running))
    }

    async fn seed(&self, accounts: &[AccountId32], height: u64) {
        self.history
            .ensure_cursors(accounts, block(height))
            .await
            .expect("测试游标初始化必须成功");
    }
}

#[test]
fn new_accounts_start_at_current_finalized_without_backfill() {
    block_on(async {
        let harness = Harness::new(42, None, None);
        let accounts = [account(0x11), account(0x22)];
        let state = harness
            .runtime
            .initialize_accounts(&accounts, &harness.guard())
            .await
            .expect("初始化必须成功");
        assert_eq!(state.cursors().len(), 2);
        assert!(state
            .cursors()
            .iter()
            .all(|cursor| cursor.tracking_start_block() == block(42)
                && cursor.last_synced_block() == block(42)));
        assert_eq!(harness.block_requests.load(Ordering::SeqCst), 0);
    });
}

#[test]
fn engine_history_lease_rejects_stop_and_dispose_until_the_future_is_dropped() {
    let store: Arc<dyn TransactionHistoryStore> = Arc::new(MemoryHistoryStore::default());
    let engine = running_engine(store, 7);

    // prepare 在返回 Future 前已经于同一 state 锁内取得租约；即使调用方尚未 poll，
    // stop/dispose 也不能切掉这次已获准的操作代际。
    let future = engine.initialize_finalized_history(vec![account(0x71)]);
    assert!(matches!(
        engine.mark_provider_stopped(),
        Err(EngineError::Contract(_))
    ));
    assert!(matches!(engine.dispose(), Err(EngineError::Contract(_))));

    drop(future);
    engine
        .mark_provider_stopped()
        .expect("Future drop 必须释放历史操作租约，随后 stop 成功");
}

#[test]
fn engine_history_lease_fences_the_complete_cas_await_window() {
    let (release, receiver) = oneshot::channel();
    let store = Arc::new(PausedHistoryStore::new(receiver));
    let engine = running_engine(store.clone(), 9);
    let mut future = engine.initialize_finalized_history(vec![account(0x72)]);

    let waker = noop_waker();
    let mut context = Context::from_waker(&waker);
    // 其他并行单测可能短暂持有进程级 history CAS 门；重复 poll 直到本操作真正进入
    // 被控 CAS，而不是把“正在等测试门”误当作已经覆盖最后写入窗口。
    for _ in 0..100_000 {
        assert!(matches!(future.as_mut().poll(&mut context), Poll::Pending));
        if store.cas_entered.load(Ordering::SeqCst) {
            break;
        }
        std::thread::yield_now();
    }
    assert!(store.cas_entered.load(Ordering::SeqCst));
    assert!(matches!(
        engine.mark_provider_stopped(),
        Err(EngineError::Contract(_))
    ));
    assert!(matches!(engine.dispose(), Err(EngineError::Contract(_))));

    release.send(()).expect("CAS 测试放行端仍由 Future 持有");
    block_on(future).expect("放行后初始化 CAS 必须完成");
    engine
        .mark_provider_stopped()
        .expect("CAS 与租约一起结束后 stop 必须成功");
}

#[test]
fn one_batch_is_hard_limited_to_120_contiguous_finalized_blocks() {
    block_on(async {
        let harness = Harness::new(125, None, None);
        let accounts = [account(0x11), account(0x22)];
        harness.seed(&accounts, 0).await;

        let state = harness
            .runtime
            .sync_batch(&accounts, &harness.guard())
            .await
            .expect("首批同步必须成功");
        assert_eq!(MAX_FINALIZED_BLOCKS_PER_BATCH, 120);
        assert!(state
            .cursors()
            .iter()
            .all(|cursor| cursor.last_synced_block() == block(120)));
        assert_eq!(harness.block_requests.load(Ordering::SeqCst), 1);
    });
}

#[test]
fn missing_events_and_stopped_generation_never_advance_a_cursor() {
    block_on(async {
        let missing = Harness::new(1, Some(1), None);
        let sender = account(0x11);
        missing.seed(&[sender], 0).await;
        let before = missing.store.snapshot();
        assert!(missing
            .runtime
            .sync_batch(&[sender], &missing.guard())
            .await
            .is_err());
        assert_eq!(missing.store.snapshot(), before);

        let stopped = Harness::new(1, None, Some(1));
        stopped.seed(&[sender], 0).await;
        let before = stopped.store.snapshot();
        let error = stopped
            .runtime
            .sync_batch(&[sender], &stopped.guard())
            .await
            .expect_err("旧代际在 provider await 后必须停止");
        assert!(matches!(error, EngineError::Contract(_)));
        assert_eq!(stopped.store.snapshot(), before);
    });
}

#[test]
fn same_index_outcome_transfer_dedupe_and_replay_are_atomic() {
    block_on(async {
        let harness = Harness::new(1, None, None);
        let sender = account(0x11);
        let receiver = account(0x22);
        harness.seed(&[sender, receiver], 0).await;
        let context = RuntimeContext::try_new(
            block(1).verified(),
            RuntimeVersion::new(100, 12),
            hex_bytes(METADATA_HEX),
        )
        .unwrap();
        let signed = SignedExtrinsic::try_new(vec![0x0c, 0x84, 0x01, 0x02]).unwrap();
        let transaction_hash = signed_extrinsic_hash(&context, &signed).unwrap();
        harness
            .history
            .record_pending_before_broadcast(
                sender,
                transaction_hash,
                0,
                receiver,
                123_456,
                "CitizenSDK production Runtime fixture",
            )
            .await
            .unwrap();

        let tracked = [sender, receiver].into_iter().collect();
        let committed = harness
            .runtime
            .process_finalized_block(block(1), &tracked, &harness.guard())
            .await
            .expect("准确同 index 证据必须原子提交");
        assert!(matches!(
            committed.records()[0].status(),
            HistoryTransactionStatus::Execution(
                citizen_sdk_contracts::ExecutionConclusion::Success {
                    extrinsic_index: 0,
                    ..
                }
            )
        ));
        assert_eq!(committed.transfers().len(), 1);
        let receiver_view = &committed.transfers()[0];
        assert_eq!(receiver_view.tracked_account_id(), receiver);
        assert!(receiver_view.is_incoming());
        assert_eq!(receiver_view.source_pallet(), "OnchainTransaction");
        assert_eq!(receiver_view.event_record_index(), 1);
        assert_eq!(
            receiver_view.remark(),
            Some("CitizenSDK production Runtime fixture")
        );

        let replay = harness
            .runtime
            .process_finalized_block(block(1), &tracked, &harness.guard())
            .await
            .expect("同一 canonical finalized 块重放必须幂等");
        assert_eq!(replay, committed);
    });
}

#[test]
fn typed_watch_only_persists_in_block_invalid_and_usurped() {
    block_on(async {
        let harness = Harness::new(1, None, None);
        let senders = [account(0x33), account(0x34), account(0x35), account(0x36)];
        let destination = account(0x44);
        for (sender, value) in senders.into_iter().zip(1_u8..=4) {
            harness
                .history
                .record_pending_before_broadcast(
                    sender,
                    hash(value),
                    u64::from(value),
                    destination,
                    10,
                    "watch",
                )
                .await
                .unwrap();
        }

        let in_block = VerifiedBlockRef::best(hash(0x51), 5);
        let state = harness
            .runtime
            .apply_watch_event(
                senders[0],
                hash(1),
                ExtrinsicWatchEvent::InBlock { block: in_block },
                &harness.guard(),
            )
            .await
            .unwrap();
        assert!(matches!(
            state.records()[0].status(),
            HistoryTransactionStatus::InBlock { block } if *block == in_block
        ));
        let unchanged = harness
            .runtime
            .apply_watch_event(
                senders[0],
                hash(1),
                ExtrinsicWatchEvent::Future,
                &harness.guard(),
            )
            .await
            .unwrap();
        assert_eq!(unchanged, state);

        let invalid = harness
            .runtime
            .apply_watch_event(
                senders[1],
                hash(2),
                ExtrinsicWatchEvent::Invalid,
                &harness.guard(),
            )
            .await
            .unwrap();
        assert_eq!(
            invalid.records()[1].status().pool_rejection_reason(),
            Some("invalid transaction")
        );
        let usurped = harness
            .runtime
            .apply_watch_event(
                senders[2],
                hash(3),
                ExtrinsicWatchEvent::Usurped {
                    replacement_hash: hash(0xaa),
                },
                &harness.guard(),
            )
            .await
            .unwrap();
        assert!(usurped.records()[2]
            .status()
            .pool_rejection_reason()
            .is_some_and(|reason| reason.ends_with(&"aa".repeat(32))));

        let no_terminal_events = [
            ExtrinsicWatchEvent::Ready,
            ExtrinsicWatchEvent::Broadcast { peer_count: 2 },
            ExtrinsicWatchEvent::Dropped,
            ExtrinsicWatchEvent::Retracted {
                block: VerifiedBlockRef::best(hash(0x52), 6),
            },
            ExtrinsicWatchEvent::FinalityTimeout { block: None },
            ExtrinsicWatchEvent::Finalized { block: block(6) },
        ];
        for event in no_terminal_events {
            let state = harness
                .runtime
                .apply_watch_event(senders[3], hash(4), event, &harness.guard())
                .await
                .unwrap();
            assert!(matches!(
                state.records()[3].status(),
                HistoryTransactionStatus::Pending
            ));
        }
        // 断线没有 typed watch event，因此宿主不调用写入口，pending 自然保持不变。
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

fn running_engine(
    history: Arc<dyn TransactionHistoryStore>,
    finalized_height: u64,
) -> CitizenEngine {
    let running = Arc::new(AtomicBool::new(true));
    let block_requests = Arc::new(AtomicUsize::new(0));
    let client = Arc::new(FakeChainClient {
        head: finalized_height,
        metadata: hex_bytes(METADATA_HEX),
        events: hex_bytes(EVENTS_HEX),
        missing_events_at: None,
        stop_at_block_request: None,
        running,
        block_requests,
    });
    let components =
        EngineComponents::new(client, None, None, None, None, None, Some(history), None);
    let engine = CitizenEngine::new(components);
    engine
        .update_capabilities(
            CapabilityName::ALL
                .into_iter()
                .map(CapabilityProbe::ready)
                .collect(),
        )
        .expect("测试 capability 合同必须完整");
    engine
        .begin_provider_start()
        .expect("测试 Engine 必须开始启动");
    block_on(engine.complete_provider_start()).expect("测试 provider 必须进入 Running");
    engine
}

fn hex_bytes(value: &str) -> Vec<u8> {
    let body = value.trim().strip_prefix("0x").expect("fixture 必须带 0x");
    assert_eq!(body.len() % 2, 0);
    body.as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            let text = std::str::from_utf8(pair).expect("fixture hex 必须是 ASCII");
            u8::from_str_radix(text, 16).expect("fixture 必须是 hex")
        })
        .collect()
}
