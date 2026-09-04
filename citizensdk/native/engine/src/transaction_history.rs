//! CitizenChain finalized 流水、广播前 pending 与执行终态的原子状态机。
//!
//! 广播前必须先调用 [`TransactionHistoryService::record_pending_before_broadcast`]；
//! `InBlock`、`Finalized` watch 事件都不是成功。只有 finalized 准确块中，同一 extrinsic
//! index 的 `System.ExtrinsicSuccess/Failed` 才能通过 `commit_finalized_block` 写成终态。

use std::{
    collections::{BTreeMap, BTreeSet},
    sync::{Arc, OnceLock},
};

use citizen_sdk_contracts::{
    store::{
        FinalizedTransferRecord, HistoryTransactionStatus, TransactionHistoryCursor,
        TransactionHistoryRecord, TransactionHistoryState, TransactionHistoryStore,
    },
    AccountId32, ContractErrorCode, ExecutionConclusion, FinalizedBlockRef, Hash32, RuntimeVersion,
    SignedExtrinsic, VerifiedBlockRef,
};
use futures::lock::Mutex as AsyncMutex;

use crate::{
    error::EngineError, transaction_outcome::VerifiedFinalizedExecution,
    wallet_service::WalletClock,
};

const MAX_HISTORY_CAS_ATTEMPTS: usize = 8;

static HISTORY_MUTATION_GATE: OnceLock<AsyncMutex<()>> = OnceLock::new();

fn history_mutation_gate() -> &'static AsyncMutex<()> {
    HISTORY_MUTATION_GATE.get_or_init(|| AsyncMutex::new(()))
}

struct HistoryCandidate {
    cursors: Vec<TransactionHistoryCursor>,
    records: Vec<TransactionHistoryRecord>,
    transfers: Vec<FinalizedTransferRecord>,
}

#[derive(Clone)]
pub struct TransactionHistoryService {
    store: Arc<dyn TransactionHistoryStore>,
    clock: Arc<dyn WalletClock>,
}

impl TransactionHistoryService {
    pub fn new(store: Arc<dyn TransactionHistoryStore>, clock: Arc<dyn WalletClock>) -> Self {
        Self { store, clock }
    }

    /// 钱包交易广播前的最后一道门：哈希必须精确匹配唯一持久 `Pending`。
    /// `InBlock`、`PoolRejected` 或链上 `Execution` 均禁止重广播；模块不对外公开，
    /// 因此应用或语言绑定不能伪造记录来绕过该门。
    pub(crate) async fn require_recorded_before_broadcast(
        &self,
        transaction_hash: Hash32,
    ) -> Result<(), EngineError> {
        let state = self.store.load().await?;
        let matching = state
            .records()
            .iter()
            .filter(|record| record.transaction_hash() == transaction_hash)
            .collect::<Vec<_>>();
        match matching.as_slice() {
            [record] if matches!(record.status(), HistoryTransactionStatus::Pending) => Ok(()),
            [] => Err(error(
                ContractErrorCode::InvalidState,
                "钱包 signed extrinsic 在广播前没有持久 pending 记录",
            )),
            [_] => Err(error(
                ContractErrorCode::InvalidState,
                "钱包 signed extrinsic 已离开 Pending；禁止再次广播",
            )),
            _ => Err(error(
                ContractErrorCode::Integrity,
                "钱包 signed extrinsic 哈希对应多条历史记录，禁止广播",
            )),
        }
    }

    /// 新账户从纳入监控时的 finalized 高度开始，不回查加入前历史。
    pub(crate) async fn ensure_cursors(
        &self,
        account_ids: &[AccountId32],
        start_finalized_block: FinalizedBlockRef,
    ) -> Result<TransactionHistoryState, EngineError> {
        let _guard = history_mutation_gate().lock().await;
        self.mutate(|state| {
            let mut cursors = state.cursors().to_vec();
            let mut changed = false;
            for account_id in account_ids
                .iter()
                .copied()
                .collect::<std::collections::BTreeSet<_>>()
            {
                if cursors
                    .iter()
                    .any(|cursor| cursor.account_id() == account_id)
                {
                    continue;
                }
                cursors.push(TransactionHistoryCursor::try_new(
                    account_id,
                    start_finalized_block,
                    start_finalized_block,
                )?);
                changed = true;
            }
            Ok(changed.then(|| HistoryCandidate {
                cursors,
                records: state.records().to_vec(),
                transfers: state.transfers().to_vec(),
            }))
        })
        .await
    }

    /// 在广播完整 signed extrinsic 之前持久化 pending；同 txHash 重试必须逐项一致。
    #[allow(clippy::too_many_arguments)]
    pub async fn record_pending_before_broadcast(
        &self,
        account_id: AccountId32,
        transaction_hash: Hash32,
        nonce: u64,
        destination_account_id: AccountId32,
        amount_fen: u128,
        remark: &str,
        signed_extrinsic: SignedExtrinsic,
        block: VerifiedBlockRef,
        runtime_version: RuntimeVersion,
        genesis_hash: Hash32,
    ) -> Result<TransactionHistoryState, EngineError> {
        let _guard = history_mutation_gate().lock().await;
        let now = self.clock.now_millis()?;
        let candidate_record = TransactionHistoryRecord::try_new(
            account_id,
            transaction_hash,
            nonce,
            destination_account_id,
            amount_fen,
            remark,
            HistoryTransactionStatus::Pending,
            now,
            now,
            signed_extrinsic,
            block,
            runtime_version,
            genesis_hash,
        )?;
        self.mutate(move |state| {
            if let Some(existing) = find_record(state, account_id, transaction_hash) {
                existing.require_same_submission_facts(&candidate_record)?;
                if matches!(existing.status(), HistoryTransactionStatus::Pending) {
                    return Ok(None);
                }
                return Err(error(
                    ContractErrorCode::InvalidState,
                    "同一 txHash 已离开 Pending；禁止把旧交易重新送入广播路径",
                ));
            }
            // CitizenChain 当前 AccountNonceApi 只提供绑定准确 best Runtime 的链 nonce，
            // 不是交易池感知 nonce。必须把“同账户只有一条未决本机交易”纳入同一次
            // durable CAS：两个并发构造即使读到相同 nonce，也只有 CAS 胜者可以通过
            // pending-before-broadcast 门，失败者在重读后被这里拒绝，绝不能继续广播。
            let has_another_open_submission = state.records().iter().any(|record| {
                record.account_id() == account_id
                    && record.transaction_hash() != transaction_hash
                    && matches!(
                        record.status(),
                        HistoryTransactionStatus::Pending
                            | HistoryTransactionStatus::InBlock { .. }
                    )
            });
            if has_another_open_submission {
                return Err(error(
                    ContractErrorCode::Conflict,
                    "同一账户已有 Pending/InBlock 交易；必须等待其收敛后再构造下一笔",
                ));
            }
            let mut records = state.records().to_vec();
            records.push(candidate_record.clone());
            Ok(Some(HistoryCandidate {
                cursors: state.cursors().to_vec(),
                records,
                transfers: state.transfers().to_vec(),
            }))
        })
        .await
    }

    /// 同参数调用恢复原始授权；不同参数不得越过同账户未决门重新占用 nonce。
    pub(crate) async fn resumable_transfer(
        &self,
        account_id: AccountId32,
        destination: AccountId32,
        amount_fen: u128,
        remark: &str,
    ) -> Result<Option<TransactionHistoryRecord>, EngineError> {
        let state = self.load().await?;
        let open: Vec<_> = state
            .records()
            .iter()
            .filter(|record| {
                record.account_id() == account_id
                    && matches!(
                        record.status(),
                        HistoryTransactionStatus::Pending
                            | HistoryTransactionStatus::InBlock { .. }
                    )
            })
            .collect();
        match open.as_slice() {
            [] => Ok(None),
            [record]
                if record.destination_account_id() == destination
                    && record.amount_fen() == amount_fen
                    && record.remark() == remark =>
            {
                Ok(Some((*record).clone()))
            }
            [_] => Err(error(
                ContractErrorCode::Conflict,
                "同一账户已有不同参数的未决交易；禁止重新签名或占用 nonce",
            )),
            _ => Err(error(
                ContractErrorCode::Integrity,
                "同一账户存在多条未决交易，不能选择任意记录恢复",
            )),
        }
    }

    /// 保存交易池提供的块锚；仍保持未终态，不能展示为执行成功。
    pub(crate) async fn mark_in_block(
        &self,
        account_id: AccountId32,
        transaction_hash: Hash32,
        block: VerifiedBlockRef,
    ) -> Result<TransactionHistoryState, EngineError> {
        let _guard = history_mutation_gate().lock().await;
        let now = self.clock.now_millis()?;
        self.mutate(move |state| {
            let Some(position) = record_position(state, account_id, transaction_hash) else {
                return Ok(None);
            };
            let current = &state.records()[position];
            if current.status().is_chain_terminal()
                || matches!(
                    current.status(),
                    HistoryTransactionStatus::PoolRejected { .. }
                )
            {
                return Ok(None);
            }
            let next_status = HistoryTransactionStatus::InBlock { block };
            if current.status() == &next_status {
                return Ok(None);
            }
            let mut records = state.records().to_vec();
            records[position] = current.try_with_status(next_status, now)?;
            Ok(Some(HistoryCandidate {
                cursors: state.cursors().to_vec(),
                records,
                transfers: state.transfers().to_vec(),
            }))
        })
        .await
    }

    /// 只供 `invalid`/`usurped` 等确定交易池拒绝使用；断线、dropped、retracted、
    /// future 和 timeout 均不得调用本入口。
    pub(crate) async fn mark_pool_rejected(
        &self,
        account_id: AccountId32,
        transaction_hash: Hash32,
        reason: &str,
    ) -> Result<TransactionHistoryState, EngineError> {
        let _guard = history_mutation_gate().lock().await;
        let now = self.clock.now_millis()?;
        let status = HistoryTransactionStatus::try_pool_rejected(reason)?;
        self.mutate(move |state| {
            let Some(position) = record_position(state, account_id, transaction_hash) else {
                return Ok(None);
            };
            let current = &state.records()[position];
            if current.status().is_chain_terminal()
                || matches!(
                    current.status(),
                    HistoryTransactionStatus::PoolRejected { .. }
                )
            {
                return Ok(None);
            }
            let mut records = state.records().to_vec();
            records[position] = current.try_with_status(status.clone(), now)?;
            Ok(Some(HistoryCandidate {
                cursors: state.cursors().to_vec(),
                records,
                transfers: state.transfers().to_vec(),
            }))
        })
        .await
    }

    /// 原子提交一个 finalized 块的转账视图、明确执行终态和账户游标。
    pub(crate) async fn commit_finalized_block(
        &self,
        block: FinalizedBlockRef,
        transfers: &[FinalizedTransferRecord],
        execution_updates: &[VerifiedFinalizedExecution],
        advance_cursor_accounts: &[AccountId32],
    ) -> Result<TransactionHistoryState, EngineError> {
        for transfer in transfers {
            if transfer.block() != block {
                return Err(error(
                    ContractErrorCode::Integrity,
                    "finalized 转账与提交块锚不一致",
                ));
            }
        }
        for update in execution_updates {
            let conclusion_block = conclusion_block(update.conclusion()).ok_or_else(|| {
                error(
                    ContractErrorCode::InvalidArgument,
                    "未核实结论不得写入 finalized 交易历史",
                )
            })?;
            if conclusion_block != block.verified() {
                return Err(error(
                    ContractErrorCode::Integrity,
                    "执行结论与 finalized 提交块锚不一致",
                ));
            }
        }

        let _guard = history_mutation_gate().lock().await;
        let now = self.clock.now_millis()?;
        let transfers = transfers.to_vec();
        let updates = execution_updates.to_vec();
        let advance: BTreeSet<_> = advance_cursor_accounts.iter().copied().collect();
        self.mutate(move |state| {
            let mut next_transfers = state.transfers().to_vec();
            let mut records = state.records().to_vec();
            let mut cursors = state.cursors().to_vec();
            let mut changed = false;

            // 先把每个 verified outcome 绑定到唯一本机 submission。这些
            // `(sender, extrinsic_index)` 会认领发送方流水：本机 pending 记录
            // 已是更稳定的 outgoing 真源，不能再从链上 event 写第二条。
            let mut planned_updates = Vec::with_capacity(updates.len());
            let mut claimed_outgoing = BTreeSet::new();
            // at-least-once 重放同一 finalized 块时，协调器可能不再为已终态
            // submission 生成 update。因此必须从已持久的同块终态恢复认领集，
            // 否则重放 raw events 会补写本应被 pending 抑制的 sender outgoing。
            for record in &records {
                let HistoryTransactionStatus::Execution(conclusion) = record.status() else {
                    continue;
                };
                if conclusion_block(conclusion) == Some(block.verified()) {
                    if let Some(extrinsic_index) = conclusion_extrinsic_index(conclusion) {
                        claimed_outgoing.insert((record.account_id(), extrinsic_index));
                    }
                }
            }
            for update in &updates {
                let positions: Vec<_> = records
                    .iter()
                    .enumerate()
                    .filter_map(|(position, record)| {
                        (record.transaction_hash() == update.transaction_hash()).then_some(position)
                    })
                    .collect();
                let [position] = positions.as_slice() else {
                    return Err(error(
                        ContractErrorCode::Integrity,
                        "finalized outcome 必须精确匹配唯一一条 pending submission",
                    ));
                };
                let extrinsic_index =
                    conclusion_extrinsic_index(update.conclusion()).ok_or_else(|| {
                        error(
                            ContractErrorCode::Integrity,
                            "finalized outcome 缺少已核验 extrinsic index",
                        )
                    })?;
                claimed_outgoing.insert((records[*position].account_id(), extrinsic_index));
                planned_updates.push((
                    *position,
                    HistoryTransactionStatus::Execution(update.conclusion().clone()),
                ));
            }

            // 与 CitizenApp 已验证解码器保持相同规则：同一 extrinsic、
            // 同账户、同金额的 OnchainTransaction 事件一对一覆盖底层
            // Balances 事件；phase/index 缺失时不武断去重。
            let normalized_transfers = normalize_finalized_transfers(&transfers, &claimed_outgoing);
            for transfer in &normalized_transfers {
                let existing = next_transfers.iter().find(|item| {
                    item.tracked_account_id() == transfer.tracked_account_id()
                        && item.block().hash() == transfer.block().hash()
                        && item.event_record_index() == transfer.event_record_index()
                });
                if let Some(existing) = existing {
                    if existing != transfer {
                        return Err(error(
                            ContractErrorCode::Integrity,
                            "同一 finalized 事件键对应不同转账事实",
                        ));
                    }
                } else {
                    next_transfers.push(transfer.clone());
                    changed = true;
                }
            }

            for (position, status) in planned_updates {
                if records[position].status() == &status {
                    continue;
                }
                records[position] = records[position].try_with_status(status, now)?;
                changed = true;
            }

            for account_id in &advance {
                let position = cursors
                    .iter()
                    .position(|cursor| cursor.account_id() == *account_id)
                    .ok_or_else(|| {
                        error(
                            ContractErrorCode::InvalidState,
                            "不能推进尚未初始化的账户游标",
                        )
                    })?;
                let advanced = cursors[position].try_advance(block)?;
                if advanced != cursors[position] {
                    cursors[position] = advanced;
                    changed = true;
                }
            }

            Ok(changed.then_some(HistoryCandidate {
                cursors,
                records,
                transfers: next_transfers,
            }))
        })
        .await
    }

    /// 为 finalized 协调器返回一次完整仓储快照；所有写入仍只能经过本服务的 CAS。
    pub(crate) async fn load(&self) -> Result<TransactionHistoryState, EngineError> {
        self.store.load().await.map_err(EngineError::from)
    }

    /// 读取一笔高层钱包提交的准确持久快照。
    ///
    /// watch 协调器在通知中断或终态前使用该入口，保证返回的公开 hash 总能对应唯一的
    /// `(account_id, txHash)` 记录；找不到或出现重复都失败关闭，不能用内存参数伪造状态。
    pub(crate) async fn require_submission_snapshot(
        &self,
        account_id: AccountId32,
        transaction_hash: Hash32,
    ) -> Result<(TransactionHistoryState, TransactionHistoryRecord), EngineError> {
        let state = self.load().await?;
        let matching = state
            .records()
            .iter()
            .filter(|record| {
                record.account_id() == account_id && record.transaction_hash() == transaction_hash
            })
            .cloned()
            .collect::<Vec<_>>();
        match matching.as_slice() {
            [record] => Ok((state, record.clone())),
            [] => Err(error(
                ContractErrorCode::InvalidState,
                "钱包交易没有唯一持久 submission 记录",
            )),
            _ => Err(error(
                ContractErrorCode::Integrity,
                "钱包交易的账户/hash 对应多条持久 submission 记录",
            )),
        }
    }

    async fn mutate(
        &self,
        mut transform: impl FnMut(
            &TransactionHistoryState,
        ) -> Result<Option<HistoryCandidate>, EngineError>,
    ) -> Result<TransactionHistoryState, EngineError> {
        for _ in 0..MAX_HISTORY_CAS_ATTEMPTS {
            let current = self.store.load().await?;
            let Some(candidate) = transform(&current)? else {
                return Ok(current);
            };
            let revision = current.revision().checked_add(1).ok_or_else(|| {
                error(ContractErrorCode::InvalidState, "交易历史 revision 已耗尽")
            })?;
            let next = TransactionHistoryState::try_new(
                revision,
                candidate.cursors,
                candidate.records,
                candidate.transfers,
            )?;
            match self
                .store
                .compare_and_swap(current.revision(), next.clone())
                .await
            {
                Ok(observed) if observed == next => return Ok(observed),
                Ok(_) => {
                    return Err(error(
                        ContractErrorCode::Integrity,
                        "交易历史 CAS 返回的状态与候选不一致",
                    ));
                }
                Err(write_error) => {
                    let observed = self.store.load().await;
                    if observed.as_ref().is_ok_and(|state| state == &next) {
                        return Ok(next);
                    }
                    if write_error.code() != ContractErrorCode::Conflict {
                        return Err(EngineError::from(write_error));
                    }
                }
            }
        }
        Err(error(
            ContractErrorCode::Conflict,
            "交易历史 CAS 超过 8 次仍冲突",
        ))
    }
}

fn record_position(
    state: &TransactionHistoryState,
    account_id: AccountId32,
    transaction_hash: Hash32,
) -> Option<usize> {
    state.records().iter().position(|record| {
        record.account_id() == account_id && record.transaction_hash() == transaction_hash
    })
}

fn find_record(
    state: &TransactionHistoryState,
    account_id: AccountId32,
    transaction_hash: Hash32,
) -> Option<&TransactionHistoryRecord> {
    record_position(state, account_id, transaction_hash).map(|position| &state.records()[position])
}

fn conclusion_block(conclusion: &ExecutionConclusion) -> Option<VerifiedBlockRef> {
    match conclusion {
        ExecutionConclusion::Success { block, .. } | ExecutionConclusion::Failed { block, .. } => {
            Some(*block)
        }
        ExecutionConclusion::Unverified { .. } => None,
    }
}

fn conclusion_extrinsic_index(conclusion: &ExecutionConclusion) -> Option<u32> {
    match conclusion {
        ExecutionConclusion::Success {
            extrinsic_index, ..
        }
        | ExecutionConclusion::Failed {
            extrinsic_index, ..
        } => Some(*extrinsic_index),
        ExecutionConclusion::Unverified { .. } => None,
    }
}

type TransferIdentity = (AccountId32, u32, AccountId32, AccountId32, u128);

/// 把 provider 解码出的转账投影收敛为 CitizenApp 已验证的流水语义。
///
/// 本函数只处理产品无关的链事实：业务 pallet/Balances 双事件去重，
/// 以及 pending submission 对发送方 event 流水的认领。它不会根据同块同额
/// 猜测 phase 缺失的事件，也不改动接收方流水。
fn normalize_finalized_transfers(
    transfers: &[FinalizedTransferRecord],
    claimed_outgoing: &BTreeSet<(AccountId32, u32)>,
) -> Vec<FinalizedTransferRecord> {
    let mut onchain_counts = BTreeMap::<TransferIdentity, usize>::new();
    for transfer in transfers {
        if transfer.source_pallet() != "OnchainTransaction" {
            continue;
        }
        let Some(extrinsic_index) = transfer.extrinsic_index() else {
            continue;
        };
        *onchain_counts
            .entry(transfer_identity(transfer, extrinsic_index))
            .or_default() += 1;
    }

    let mut matched_onchain = BTreeMap::<TransferIdentity, usize>::new();
    let mut normalized = Vec::with_capacity(transfers.len());
    for transfer in transfers {
        if transfer.is_outgoing()
            && transfer.extrinsic_index().is_some_and(|extrinsic_index| {
                claimed_outgoing.contains(&(transfer.tracked_account_id(), extrinsic_index))
            })
        {
            continue;
        }

        if transfer.source_pallet() == "Balances" {
            if let Some(extrinsic_index) = transfer.extrinsic_index() {
                let identity = transfer_identity(transfer, extrinsic_index);
                let available = onchain_counts.get(&identity).copied().unwrap_or_default();
                let matched = matched_onchain.entry(identity).or_default();
                if *matched < available {
                    *matched += 1;
                    continue;
                }
            }
        }
        normalized.push(transfer.clone());
    }
    normalized
}

fn transfer_identity(transfer: &FinalizedTransferRecord, extrinsic_index: u32) -> TransferIdentity {
    (
        transfer.tracked_account_id(),
        extrinsic_index,
        transfer.from_account_id(),
        transfer.to_account_id(),
        transfer.amount_fen(),
    )
}

fn error(code: ContractErrorCode, message: impl Into<String>) -> EngineError {
    EngineError::contract(code, message)
}
