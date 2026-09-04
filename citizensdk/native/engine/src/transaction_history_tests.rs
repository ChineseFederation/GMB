//! 广播前 pending、交易池/入块事实与 finalized 流水的原子状态机测试。

#![allow(clippy::expect_used, clippy::unwrap_used)]

use std::sync::{
    atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering},
    Arc, Barrier, Mutex,
};

use crate::{
    error::EngineError, transaction_history::TransactionHistoryService,
    transaction_outcome::verified_finalized_execution_for_test, wallet_service::WalletClock,
};
use citizen_sdk_contracts::{
    store::{
        FinalizedTransferRecord, HistoryTransactionStatus, TransactionHistoryState,
        TransactionHistoryStore,
    },
    AccountId32, ContractError, ContractErrorCode, ContractFuture, ContractResult, DispatchFailure,
    ExecutionConclusion, FinalizedBlockRef, Hash32, UnverifiedReason, VerifiedBlockRef,
};
use futures::executor::block_on;

#[derive(Debug)]
struct MemoryHistoryStore {
    state: Mutex<TransactionHistoryState>,
    throw_after_next_write: AtomicBool,
    cas_calls: AtomicUsize,
}

impl Default for MemoryHistoryStore {
    fn default() -> Self {
        Self {
            state: Mutex::new(
                TransactionHistoryState::try_new(0, Vec::new(), Vec::new(), Vec::new())
                    .expect("空历史状态有效"),
            ),
            throw_after_next_write: AtomicBool::new(false),
            cas_calls: AtomicUsize::new(0),
        }
    }
}

impl MemoryHistoryStore {
    fn fail_next_after_write(&self) {
        self.throw_after_next_write.store(true, Ordering::SeqCst);
    }

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
            self.cas_calls.fetch_add(1, Ordering::SeqCst);
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
            *state = next.clone();
            if self.throw_after_next_write.swap(false, Ordering::SeqCst) {
                return Err(ContractError::new(
                    ContractErrorCode::Storage,
                    "测试历史已写入但平台抛错",
                ));
            }
            Ok(next)
        })
    }
}

#[derive(Debug)]
struct IncrementingClock(AtomicU64);

impl Default for IncrementingClock {
    fn default() -> Self {
        Self(AtomicU64::new(1_800_000_000_000))
    }
}

impl WalletClock for IncrementingClock {
    fn now_millis(&self) -> ContractResult<u64> {
        Ok(self.0.fetch_add(1, Ordering::SeqCst))
    }
}

struct Harness {
    service: TransactionHistoryService,
    store: Arc<MemoryHistoryStore>,
}

impl Harness {
    fn new() -> Self {
        let store = Arc::new(MemoryHistoryStore::default());
        let service =
            TransactionHistoryService::new(store.clone(), Arc::new(IncrementingClock::default()));
        Self { service, store }
    }
}

#[test]
fn pending_is_committed_before_broadcast_and_same_hash_requires_identical_facts() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(1);
        let destination = account(2);
        let transaction_hash = hash(9);
        harness.store.fail_next_after_write();

        let pending = harness
            .service
            .record_pending_before_broadcast(
                sender,
                transaction_hash,
                7,
                destination,
                1_234,
                "before broadcast",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .expect("写后异常回读一致时 pending 必须收敛");
        assert_eq!(pending.revision(), 1);
        assert_eq!(pending.records().len(), 1);
        let record = &pending.records()[0];
        assert_eq!(record.account_id(), sender);
        assert_eq!(record.transaction_hash(), transaction_hash);
        assert_eq!(record.nonce(), 7);
        assert_eq!(record.destination_account_id(), destination);
        assert_eq!(record.amount_fen(), 1_234);
        assert_eq!(record.remark(), "before broadcast");
        assert!(matches!(record.status(), HistoryTransactionStatus::Pending));
        harness
            .service
            .require_recorded_before_broadcast(transaction_hash)
            .await
            .expect("写后抛错但精确收敛的 Pending 必须允许唯一一次广播路径继续");
        let (snapshot, exact) = harness
            .service
            .require_submission_snapshot(sender, transaction_hash)
            .await
            .expect("高层 watch 必须能读取唯一持久 submission");
        assert_eq!(snapshot, pending);
        assert_eq!(exact, pending.records()[0]);
        assert_contract_code(
            harness
                .service
                .require_submission_snapshot(account(0xff), transaction_hash)
                .await
                .expect_err("不同账户不能借用相同 txHash 的持久记录"),
            ContractErrorCode::InvalidState,
        );

        let idempotent = harness
            .service
            .record_pending_before_broadcast(
                sender,
                transaction_hash,
                7,
                destination,
                1_234,
                "before broadcast",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .expect("完全相同的广播重试应幂等");
        assert_eq!(idempotent, pending);
        assert_eq!(harness.store.cas_calls.load(Ordering::SeqCst), 1);

        let before_conflict = harness.store.snapshot();
        assert_contract_code(
            harness
                .service
                .record_pending_before_broadcast(
                    sender,
                    transaction_hash,
                    7,
                    destination,
                    1_235,
                    "before broadcast",
                    citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                    citizen_sdk_contracts::VerifiedBlockRef::best(
                        citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                        1,
                    ),
                    citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                    citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
                )
                .await
                .expect_err("同 txHash 不得改写金额等提交事实"),
            ContractErrorCode::Integrity,
        );
        assert_eq!(harness.store.snapshot(), before_conflict);
    });
}

#[test]
fn same_account_pending_is_durable_single_flight_but_other_accounts_remain_independent() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(0x51);
        harness
            .service
            .record_pending_before_broadcast(
                sender,
                hash(1),
                7,
                account(0x61),
                10,
                "first",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();

        assert_contract_code(
            harness
                .service
                .record_pending_before_broadcast(
                    sender,
                    hash(2),
                    7,
                    account(0x62),
                    20,
                    "same nonce must not race",
                    citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                    citizen_sdk_contracts::VerifiedBlockRef::best(
                        citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                        1,
                    ),
                    citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                    citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
                )
                .await
                .expect_err("同账户第二条未决交易必须在 durable CAS 门被拒绝"),
            ContractErrorCode::Conflict,
        );

        harness
            .service
            .record_pending_before_broadcast(
                account(0x52),
                hash(3),
                7,
                account(0x63),
                30,
                "different account",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .expect("不同账户可以各自持有一条未决交易");
        assert_eq!(harness.store.snapshot().records().len(), 2);
    });
}

#[test]
fn concurrent_same_account_candidates_allow_exactly_one_pending_winner() {
    let harness = Harness::new();
    let sender = account(0x53);
    let barrier = Arc::new(Barrier::new(3));
    let mut workers = Vec::new();
    for value in [4_u8, 5_u8] {
        let service = harness.service.clone();
        let barrier = Arc::clone(&barrier);
        workers.push(std::thread::spawn(move || {
            barrier.wait();
            block_on(service.record_pending_before_broadcast(
                sender,
                hash(value),
                9,
                account(0x64),
                u128::from(value),
                "concurrent",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            ))
        }));
    }
    barrier.wait();
    let results = workers
        .into_iter()
        .map(|worker| worker.join().expect("并发测试线程必须结束"))
        .collect::<Vec<_>>();
    assert_eq!(results.iter().filter(|result| result.is_ok()).count(), 1);
    assert_eq!(results.iter().filter(|result| result.is_err()).count(), 1);
    let error = results
        .into_iter()
        .find_map(Result::err)
        .expect("必须存在 durable single-flight 失败方");
    assert_contract_code(error, ContractErrorCode::Conflict);
    let state = harness.store.snapshot();
    assert_eq!(state.records().len(), 1);
    assert_eq!(state.records()[0].account_id(), sender);
}

#[test]
fn pool_rejected_and_verified_execution_release_the_account_pending_gate() {
    block_on(async {
        let harness = Harness::new();
        let pool_sender = account(0x54);
        harness
            .service
            .record_pending_before_broadcast(
                pool_sender,
                hash(6),
                1,
                account(0x65),
                10,
                "pool",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        harness
            .service
            .mark_pool_rejected(pool_sender, hash(6), "invalid transaction")
            .await
            .unwrap();
        assert_contract_code(
            harness
                .service
                .require_recorded_before_broadcast(hash(6))
                .await
                .expect_err("PoolRejected 旧 txHash 不得再次广播"),
            ContractErrorCode::InvalidState,
        );
        assert_contract_code(
            harness
                .service
                .record_pending_before_broadcast(
                    pool_sender,
                    hash(6),
                    1,
                    account(0x65),
                    10,
                    "pool",
                    citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                    citizen_sdk_contracts::VerifiedBlockRef::best(
                        citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                        1,
                    ),
                    citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                    citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
                )
                .await
                .expect_err("同 txHash 的 PoolRejected 不能伪装成 Pending 重试"),
            ContractErrorCode::InvalidState,
        );
        harness
            .service
            .record_pending_before_broadcast(
                pool_sender,
                hash(7),
                1,
                account(0x66),
                20,
                "after pool rejection",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .expect("PoolRejected 不再阻塞同账户下一笔");

        let executed_sender = account(0x55);
        let executed_hash = hash(8);
        harness
            .service
            .record_pending_before_broadcast(
                executed_sender,
                executed_hash,
                2,
                account(0x67),
                30,
                "executed",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        let finalized = finalized_block(0x70, 70);
        let execution = verified_finalized_execution_for_test(
            executed_hash,
            ExecutionConclusion::Success {
                block: finalized.verified(),
                extrinsic_index: 0,
            },
        )
        .unwrap();
        harness
            .service
            .commit_finalized_block(finalized, &[], &[execution], &[])
            .await
            .unwrap();
        assert_contract_code(
            harness
                .service
                .require_recorded_before_broadcast(executed_hash)
                .await
                .expect_err("Execution 旧 txHash 不得再次广播"),
            ContractErrorCode::InvalidState,
        );
        assert_contract_code(
            harness
                .service
                .record_pending_before_broadcast(
                    executed_sender,
                    executed_hash,
                    2,
                    account(0x67),
                    30,
                    "executed",
                    citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                    citizen_sdk_contracts::VerifiedBlockRef::best(
                        citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                        1,
                    ),
                    citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                    citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
                )
                .await
                .expect_err("同 txHash 的 Execution 不能伪装成 Pending 重试"),
            ContractErrorCode::InvalidState,
        );
        harness
            .service
            .record_pending_before_broadcast(
                executed_sender,
                hash(9),
                3,
                account(0x68),
                40,
                "after execution",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .expect("finalized Execution 不再阻塞同账户下一笔");
    });
}

#[test]
fn in_block_hash_is_non_terminal_but_cannot_be_rebroadcast_or_recreated_as_pending() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(0x56);
        let transaction_hash = hash(10);
        harness
            .service
            .record_pending_before_broadcast(
                sender,
                transaction_hash,
                4,
                account(0x69),
                50,
                "in block",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        harness
            .service
            .mark_in_block(
                sender,
                transaction_hash,
                VerifiedBlockRef::best(hash(0x71), 71),
            )
            .await
            .unwrap();
        assert_contract_code(
            harness
                .service
                .require_recorded_before_broadcast(transaction_hash)
                .await
                .expect_err("InBlock 交易不能再次广播"),
            ContractErrorCode::InvalidState,
        );
        assert_contract_code(
            harness
                .service
                .record_pending_before_broadcast(
                    sender,
                    transaction_hash,
                    4,
                    account(0x69),
                    50,
                    "in block",
                    citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                    citizen_sdk_contracts::VerifiedBlockRef::best(
                        citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                        1,
                    ),
                    citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                    citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
                )
                .await
                .expect_err("同 txHash 的 InBlock 不能倒退为 Pending"),
            ContractErrorCode::InvalidState,
        );
    });
}

#[test]
fn in_block_is_not_success_and_only_explicit_pool_rejection_is_persisted() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(3);
        let transaction_hash = hash(4);
        harness
            .service
            .record_pending_before_broadcast(
                sender,
                transaction_hash,
                1,
                account(5),
                8,
                "",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();

        let in_block_ref = VerifiedBlockRef::best(hash(6), 20);
        let in_block = harness
            .service
            .mark_in_block(sender, transaction_hash, in_block_ref)
            .await
            .unwrap();
        let status = in_block.records()[0].status();
        assert!(matches!(
            status,
            HistoryTransactionStatus::InBlock { block } if *block == in_block_ref
        ));
        assert!(!status.is_chain_terminal());
        assert_eq!(status.persisted_name(), Some("inBlock"));

        let before_invalid_reason = harness.store.snapshot();
        assert_contract_code(
            harness
                .service
                .mark_pool_rejected(sender, transaction_hash, " \n ")
                .await
                .expect_err("空白原因不构成明确 pool rejection"),
            ContractErrorCode::InvalidArgument,
        );
        assert_eq!(harness.store.snapshot(), before_invalid_reason);

        let rejected = harness
            .service
            .mark_pool_rejected(sender, transaction_hash, "invalid transaction")
            .await
            .expect("已入块的非终态仍可被明确 pool rejection 更新");
        let rejected_status = rejected.records()[0].status();
        assert_eq!(rejected_status.persisted_name(), Some("poolRejected"));
        assert_eq!(
            rejected_status.pool_rejection_reason(),
            Some("invalid transaction")
        );
        assert!(!rejected_status.is_chain_terminal());
    });
}

#[test]
fn finalized_success_and_failure_require_exact_block_and_extrinsic_index() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(7);
        let failure_sender = account(17);
        let success_hash = hash(8);
        let failure_hash = hash(9);
        harness
            .service
            .record_pending_before_broadcast(
                sender,
                success_hash,
                2,
                account(10),
                20,
                "ok",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        harness
            .service
            .record_pending_before_broadcast(
                failure_sender,
                failure_hash,
                3,
                account(11),
                30,
                "fail",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        let block = finalized_block(12, 40);

        let wrong_block_update = verified_finalized_execution_for_test(
            success_hash,
            ExecutionConclusion::Success {
                block: VerifiedBlockRef::finalized(hash(13), 41),
                extrinsic_index: 4,
            },
        )
        .unwrap();
        let before_wrong_block = harness.store.snapshot();
        assert_contract_code(
            harness
                .service
                .commit_finalized_block(block, &[], &[wrong_block_update], &[])
                .await
                .expect_err("不同 finalized block 的 outcome 不得提交"),
            ContractErrorCode::Integrity,
        );
        assert_eq!(harness.store.snapshot(), before_wrong_block);

        let unverified_error = verified_finalized_execution_for_test(
            success_hash,
            ExecutionConclusion::Unverified {
                block: Some(block.verified()),
                extrinsic_index: Some(4),
                reason: UnverifiedReason::OutcomeEventMissing,
            },
        )
        .expect_err("缺少执行事件不能提升为 finalized 令牌");
        assert_contract_code(unverified_error, ContractErrorCode::InvalidState);

        let success = verified_finalized_execution_for_test(
            success_hash,
            ExecutionConclusion::Success {
                block: block.verified(),
                extrinsic_index: 4,
            },
        )
        .unwrap();
        let failed = verified_finalized_execution_for_test(
            failure_hash,
            ExecutionConclusion::Failed {
                block: block.verified(),
                extrinsic_index: 5,
                failure: DispatchFailure::new(2, None),
            },
        )
        .unwrap();
        let committed = harness
            .service
            .commit_finalized_block(block, &[], &[success, failed], &[])
            .await
            .unwrap();
        assert!(matches!(
            committed.records()[0].status(),
            HistoryTransactionStatus::Execution(ExecutionConclusion::Success {
                block: actual_block,
                extrinsic_index: 4,
            }) if *actual_block == block.verified()
        ));
        assert!(committed.records()[0].status().is_chain_terminal());
        assert_eq!(
            committed.records()[0].status().persisted_name(),
            Some("finalized")
        );
        assert!(matches!(
            committed.records()[1].status(),
            HistoryTransactionStatus::Execution(ExecutionConclusion::Failed {
                block: actual_block,
                extrinsic_index: 5,
                ..
            }) if *actual_block == block.verified()
        ));
        assert!(committed.records()[1].status().is_chain_terminal());
        assert_eq!(
            committed.records()[1].status().persisted_name(),
            Some("failed")
        );

        let after_terminal = harness
            .service
            .mark_in_block(sender, success_hash, VerifiedBlockRef::best(hash(14), 42))
            .await
            .unwrap();
        assert_eq!(after_terminal, committed, "链上终态不得被较弱事实改写");
    });
}

#[test]
fn finalized_execution_hash_must_match_exactly_one_pending_record() {
    block_on(async {
        let harness = Harness::new();
        let transaction_hash = hash(0x44);
        harness
            .service
            .record_pending_before_broadcast(
                account(1),
                transaction_hash,
                1,
                account(3),
                10,
                "first",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        harness
            .service
            .record_pending_before_broadcast(
                account(2),
                transaction_hash,
                2,
                account(4),
                20,
                "duplicate-hash",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        let block = finalized_block(0x45, 60);
        let verified = verified_finalized_execution_for_test(
            transaction_hash,
            ExecutionConclusion::Success {
                block: block.verified(),
                extrinsic_index: 1,
            },
        )
        .unwrap();

        assert_contract_code(
            harness
                .service
                .commit_finalized_block(block, &[], &[verified], &[])
                .await
                .expect_err("同一 txHash 的多账户歧义不得写入任一终态"),
            ContractErrorCode::Integrity,
        );
        assert!(harness
            .store
            .snapshot()
            .records()
            .iter()
            .all(|record| record.status() == &HistoryTransactionStatus::Pending));
    });
}

#[test]
fn finalized_commit_deduplicates_events_and_pending_claims_sender_atomically() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(20);
        let receiver = account(21);
        let tracking_start = finalized_block(19, 50);
        harness
            .service
            .ensure_cursors(&[receiver, sender, sender], tracking_start)
            .await
            .unwrap();
        let transaction_hash = hash(22);
        harness
            .service
            .record_pending_before_broadcast(
                sender,
                transaction_hash,
                9,
                receiver,
                500,
                "two-sided",
                citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap(),
                citizen_sdk_contracts::VerifiedBlockRef::best(
                    citizen_sdk_contracts::Hash32::from_bytes([1; 32]),
                    1,
                ),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        let block = finalized_block(23, 51);
        let balances_sender = transfer(sender, sender, receiver, block, 7, Some(3), None);
        let balances_receiver = transfer(receiver, sender, receiver, block, 7, Some(3), None);
        let onchain_sender = transfer(
            sender,
            sender,
            receiver,
            block,
            8,
            Some(3),
            Some("two-sided".to_owned()),
        );
        let onchain_receiver = transfer(
            receiver,
            sender,
            receiver,
            block,
            8,
            Some(3),
            Some("two-sided".to_owned()),
        );
        assert!(balances_sender.is_outgoing());
        assert!(balances_receiver.is_incoming());
        assert!(onchain_sender.is_outgoing());
        assert!(onchain_receiver.is_incoming());
        let raw_transfers = vec![
            balances_sender,
            balances_receiver,
            onchain_sender,
            onchain_receiver,
        ];

        let update = verified_finalized_execution_for_test(
            transaction_hash,
            ExecutionConclusion::Success {
                block: block.verified(),
                extrinsic_index: 3,
            },
        )
        .unwrap();

        // transform 已经组装 transfer/outcome 后才发现第三个账户没有游标；整个候选不得落盘。
        let before_atomic_failure = harness.store.snapshot();
        assert_contract_code(
            harness
                .service
                .commit_finalized_block(
                    block,
                    &raw_transfers,
                    std::slice::from_ref(&update),
                    &[sender, receiver, account(99)],
                )
                .await
                .expect_err("任一游标无效时整块事实必须原子回滚"),
            ContractErrorCode::InvalidState,
        );
        assert_eq!(harness.store.snapshot(), before_atomic_failure);

        let committed = harness
            .service
            .commit_finalized_block(block, &raw_transfers, &[update], &[sender, receiver])
            .await
            .unwrap();
        assert_eq!(committed.transfers().len(), 1);
        let receiver_transfer = &committed.transfers()[0];
        assert_eq!(receiver_transfer.tracked_account_id(), receiver);
        assert!(receiver_transfer.is_incoming());
        assert_eq!(receiver_transfer.event_record_index(), 8);
        assert_eq!(receiver_transfer.source_pallet(), "OnchainTransaction");
        assert_eq!(receiver_transfer.remark(), Some("two-sided"));
        assert!(committed
            .transfers()
            .iter()
            .all(|transfer| transfer.tracked_account_id() != sender));
        assert!(committed
            .cursors()
            .iter()
            .all(|cursor| cursor.last_synced_block() == block));
        assert!(committed.records()[0].status().is_chain_terminal());

        let raw_replay = harness
            .service
            .commit_finalized_block(block, &raw_transfers, &[], &[sender, receiver])
            .await
            .expect("同块 raw 链事实重放必须从已持久终态恢复 sender 认领");
        assert_eq!(raw_replay, committed);

        let idempotent = harness
            .service
            .commit_finalized_block(block, committed.transfers(), &[], &[sender, receiver])
            .await
            .expect("同一 finalized 块的完全相同事实应幂等");
        assert_eq!(idempotent, committed);
    });
}

#[test]
fn finalized_event_deduplication_preserves_both_views_without_a_local_claim() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(30);
        let receiver = account(31);
        let tracking_start = finalized_block(29, 70);
        harness
            .service
            .ensure_cursors(&[sender, receiver], tracking_start)
            .await
            .unwrap();
        let block = finalized_block(32, 71);
        let committed = harness
            .service
            .commit_finalized_block(
                block,
                &[
                    transfer(sender, sender, receiver, block, 4, Some(2), None),
                    transfer(receiver, sender, receiver, block, 4, Some(2), None),
                    transfer(
                        sender,
                        sender,
                        receiver,
                        block,
                        5,
                        Some(2),
                        Some("business".to_owned()),
                    ),
                    transfer(
                        receiver,
                        sender,
                        receiver,
                        block,
                        5,
                        Some(2),
                        Some("business".to_owned()),
                    ),
                ],
                &[],
                &[sender, receiver],
            )
            .await
            .unwrap();

        assert_eq!(committed.transfers().len(), 2);
        assert_eq!(
            committed
                .transfers()
                .iter()
                .map(|transfer| transfer.tracked_account_id())
                .collect::<std::collections::BTreeSet<_>>(),
            std::collections::BTreeSet::from([sender, receiver])
        );
        assert!(committed.transfers().iter().all(|transfer| {
            transfer.source_pallet() == "OnchainTransaction"
                && transfer.event_record_index() == 5
                && transfer.remark() == Some("business")
        }));
    });
}

#[test]
fn finalized_event_deduplication_is_one_to_one_and_never_guesses_a_missing_phase() {
    block_on(async {
        let harness = Harness::new();
        let sender = account(40);
        let receiver = account(41);
        let tracking_start = finalized_block(39, 80);
        harness
            .service
            .ensure_cursors(&[sender], tracking_start)
            .await
            .unwrap();
        let block = finalized_block(42, 81);
        let committed = harness
            .service
            .commit_finalized_block(
                block,
                &[
                    transfer(sender, sender, receiver, block, 1, Some(7), None),
                    transfer(
                        sender,
                        sender,
                        receiver,
                        block,
                        2,
                        Some(7),
                        Some("first".to_owned()),
                    ),
                    transfer(sender, sender, receiver, block, 3, Some(8), None),
                    transfer(sender, sender, receiver, block, 4, None, None),
                    transfer(sender, sender, receiver, block, 5, Some(7), None),
                    transfer(
                        sender,
                        sender,
                        receiver,
                        block,
                        6,
                        Some(7),
                        Some("second".to_owned()),
                    ),
                ],
                &[],
                &[sender],
            )
            .await
            .unwrap();

        assert_eq!(committed.transfers().len(), 4);
        assert_eq!(
            committed
                .transfers()
                .iter()
                .map(|transfer| transfer.event_record_index())
                .collect::<Vec<_>>(),
            vec![2, 3, 4, 6],
            "同 index 只一对一抑制 Balances；不同 index 和缺 phase 的同值事件必须保留",
        );
    });
}

fn transfer(
    tracked: AccountId32,
    from: AccountId32,
    to: AccountId32,
    block: FinalizedBlockRef,
    event_index: u32,
    extrinsic_index: Option<u32>,
    remark: Option<String>,
) -> FinalizedTransferRecord {
    FinalizedTransferRecord::try_for_tracked_account(
        tracked,
        from,
        to,
        500,
        block,
        event_index,
        extrinsic_index,
        if remark.is_some() {
            "OnchainTransaction"
        } else {
            "Balances"
        },
        remark,
    )
    .expect("合法 finalized transfer fixture")
}

#[test]
fn durable_outbox_survives_write_then_error_and_service_restart() {
    block_on(async {
        let store = Arc::new(MemoryHistoryStore::default());
        let service =
            TransactionHistoryService::new(store.clone(), Arc::new(IncrementingClock::default()));
        let signed = citizen_sdk_contracts::SignedExtrinsic::try_new(vec![0x04, 0x84]).unwrap();
        store.fail_next_after_write();
        service
            .record_pending_before_broadcast(
                account(1),
                hash(2),
                3,
                account(4),
                5,
                "resume",
                signed.clone(),
                VerifiedBlockRef::best(hash(6), 7),
                citizen_sdk_contracts::RuntimeVersion::new(100, 12),
                citizen_sdk_contracts::ChainIdentity::citizenchain().genesis_hash(),
            )
            .await
            .unwrap();
        drop(service);
        let restarted =
            TransactionHistoryService::new(store.clone(), Arc::new(IncrementingClock::default()));
        let record = restarted
            .resumable_transfer(account(1), account(4), 5, "resume")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(record.signed_extrinsic(), &signed);
        assert_eq!(record.nonce(), 3);
        assert_eq!(record.transaction_hash(), hash(2));
        assert!(restarted
            .resumable_transfer(account(1), account(4), 6, "resume")
            .await
            .is_err());
        assert!(restarted
            .resumable_transfer(account(1), account(4), 5, "other")
            .await
            .is_err());
        restarted
            .mark_in_block(account(1), hash(2), VerifiedBlockRef::best(hash(8), 8))
            .await
            .unwrap();
        assert_eq!(
            restarted
                .resumable_transfer(account(1), account(4), 5, "resume")
                .await
                .unwrap()
                .unwrap()
                .signed_extrinsic(),
            &signed
        );
        restarted
            .mark_pool_rejected(account(1), hash(2), "Invalid")
            .await
            .unwrap();
        assert!(restarted
            .resumable_transfer(account(1), account(4), 5, "resume")
            .await
            .unwrap()
            .is_none());
    });
}

fn account(byte: u8) -> AccountId32 {
    AccountId32::from_bytes([byte; 32])
}

fn hash(byte: u8) -> Hash32 {
    Hash32::from_bytes([byte; 32])
}

fn finalized_block(byte: u8, number: u64) -> FinalizedBlockRef {
    FinalizedBlockRef::from_parts(hash(byte), number)
}

fn assert_contract_code(error: EngineError, expected: ContractErrorCode) {
    match error {
        EngineError::Contract(contract) => assert_eq!(contract.code(), expected),
        other => panic!("期望 typed contract error，实际为 {other:?}"),
    }
}
