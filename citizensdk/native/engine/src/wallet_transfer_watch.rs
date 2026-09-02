//! SDK 钱包转账的唯一 submit-and-watch 协调器。
//!
//! 完整 signed extrinsic 只在 Rust Engine 内部生存。调用本模块前必须已经把同一
//! extrinsic 的完整公开事实持久化为 `Pending`；本模块随后才允许 provider 的
//! `watch_extrinsic`（实际语义为 submit-and-watch）看到字节。`InBlock` 仍是未终态，
//! `Invalid/Usurped` 只形成交易池拒绝，`Finalized` 必须再经过 canonical finalized
//! 块体和同 index `System.ExtrinsicSuccess/Failed` 核验才能形成链上终态。

use std::{
    panic::{catch_unwind, AssertUnwindSafe},
    sync::Arc,
};

use citizen_sdk_contracts::{
    store::{HistoryTransactionStatus, TransactionHistoryState},
    AccountId32, ContractErrorCode, ExecutionConclusion, ExtrinsicWatchEvent, FinalizedBlockRef,
    Hash32, SignedExtrinsic, VerifiedBlockRef, VerifiedChainClient,
};
use futures::StreamExt;

use crate::{
    error::EngineError,
    finalized_history_runtime::{FinalizedHistoryRunGuard, FinalizedHistoryRuntime},
    transaction_history::TransactionHistoryService,
};

/// 已持久化或核验后才会发布给语言绑定的高层交易阶段。
///
/// 这里故意不暴露 signed extrinsic，也不把 provider 的 `Finalized` 原样透传。只有
/// `Finalized` variant 携带的 [`ExecutionConclusion`] 才代表经过准确块/index 核验的终态。
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum WalletTransferWatchStage {
    Pending,
    Ready,
    Broadcast {
        peer_count: u32,
    },
    Future,
    InBlock {
        block: VerifiedBlockRef,
    },
    Retracted {
        block: VerifiedBlockRef,
    },
    FinalityTimeout {
        block: Option<VerifiedBlockRef>,
    },
    Dropped,
    Finalized {
        conclusion: ExecutionConclusion,
    },
    PoolRejected {
        reason: String,
        /// `Some` 精确表示 provider 返回 `Usurped`，并保留替代交易哈希；
        /// `None` 精确表示 `Invalid`。展示层不得把两者降格成同一状态。
        replacement_hash: Option<Hash32>,
    },
    /// provider 错误或流结束时的观察通知；该阶段不是交易终态。
    Interrupted {
        reason: String,
    },
}

/// 一个经过 Engine 状态机处理后的观察更新。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WalletTransferWatchUpdate {
    transaction_hash: Hash32,
    stage: WalletTransferWatchStage,
    history: TransactionHistoryState,
}

impl WalletTransferWatchUpdate {
    fn new(
        transaction_hash: Hash32,
        stage: WalletTransferWatchStage,
        history: TransactionHistoryState,
    ) -> Self {
        Self {
            transaction_hash,
            stage,
            history,
        }
    }

    pub const fn transaction_hash(&self) -> Hash32 {
        self.transaction_hash
    }

    pub const fn stage(&self) -> &WalletTransferWatchStage {
        &self.stage
    }

    pub const fn history(&self) -> &TransactionHistoryState {
        &self.history
    }
}

/// 宿主可选的同步观察器。
///
/// 回调只接收无秘密、已经持久化/核验的快照。回调 panic 会被 Engine 隔离，不能改变
/// 交易状态、阻止后续 watch 或伪造另一个终态；实现应只做快速入队，不能阻塞调用线程。
pub trait WalletTransferObserver: Send + Sync {
    fn on_update(&self, update: WalletTransferWatchUpdate);
}

/// 高层钱包转账唯一允许返回的明确终态。
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum WalletTransferResolution {
    Finalized(ExecutionConclusion),
    PoolRejected { reason: String },
}

/// 高层转账完成值；`transaction_hash` 始终对应已持久化的完整 signed extrinsic。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WalletTransferWatchResult {
    transaction_hash: Hash32,
    resolution: WalletTransferResolution,
    history: TransactionHistoryState,
}

impl WalletTransferWatchResult {
    fn new(
        transaction_hash: Hash32,
        resolution: WalletTransferResolution,
        history: TransactionHistoryState,
    ) -> Self {
        Self {
            transaction_hash,
            resolution,
            history,
        }
    }

    pub const fn transaction_hash(&self) -> Hash32 {
        self.transaction_hash
    }

    /// 与 [`citizen_sdk_contracts::SubmittedExtrinsic`] 的只读命名保持迁移期一致；本结果
    /// 仍然只会在明确终态后返回，不能据此恢复旧的“提交即成功”语义。
    pub const fn hash(&self) -> Hash32 {
        self.transaction_hash
    }

    pub const fn resolution(&self) -> &WalletTransferResolution {
        &self.resolution
    }

    pub const fn history(&self) -> &TransactionHistoryState {
        &self.history
    }
}

#[derive(Debug, Default)]
pub(crate) struct NoopWalletTransferObserver;

impl WalletTransferObserver for NoopWalletTransferObserver {
    fn on_update(&self, _update: WalletTransferWatchUpdate) {}
}

/// 观察一笔已经持久化的 SDK 钱包交易直至明确终态。
#[allow(clippy::too_many_arguments)]
pub(crate) async fn watch_recorded_transfer(
    chain_client: &dyn VerifiedChainClient,
    runtime: &FinalizedHistoryRuntime,
    history: &TransactionHistoryService,
    guard: &dyn FinalizedHistoryRunGuard,
    observer: &Arc<dyn WalletTransferObserver>,
    account_id: AccountId32,
    transaction_hash: Hash32,
    signed_extrinsic: SignedExtrinsic,
) -> Result<WalletTransferWatchResult, EngineError> {
    guard.ensure_current()?;
    history
        .require_recorded_before_broadcast(transaction_hash)
        .await?;
    guard.ensure_current()?;
    let (pending_state, _) = history
        .require_submission_snapshot(account_id, transaction_hash)
        .await?;
    guard.ensure_current()?;
    notify(
        observer,
        WalletTransferWatchUpdate::new(
            transaction_hash,
            WalletTransferWatchStage::Pending,
            pending_state,
        ),
    );

    // VerifiedChainClient 的该入口实际执行 submit-and-watch。它只能在 durable Pending
    // 已确认之后创建；任何提前创建 stream 的重构都会重新引入广播竞态。
    let mut events = chain_client.watch_extrinsic(signed_extrinsic);
    while let Some(item) = events.next().await {
        guard.ensure_current()?;
        let event = match item {
            Ok(event) => event,
            Err(error) => {
                let engine_error = EngineError::from(error);
                notify_interrupted(
                    observer,
                    history,
                    guard,
                    account_id,
                    transaction_hash,
                    engine_error.to_string(),
                )
                .await?;
                return Err(engine_error);
            }
        };

        match event {
            ExtrinsicWatchEvent::Finalized { block } => {
                let (state, conclusion) = finalize_exact_transaction(
                    runtime,
                    history,
                    guard,
                    account_id,
                    transaction_hash,
                    block,
                )
                .await?;
                notify(
                    observer,
                    WalletTransferWatchUpdate::new(
                        transaction_hash,
                        WalletTransferWatchStage::Finalized {
                            conclusion: conclusion.clone(),
                        },
                        state.clone(),
                    ),
                );
                return Ok(WalletTransferWatchResult::new(
                    transaction_hash,
                    WalletTransferResolution::Finalized(conclusion),
                    state,
                ));
            }
            event @ (ExtrinsicWatchEvent::Invalid | ExtrinsicWatchEvent::Usurped { .. }) => {
                let replacement_hash = match &event {
                    ExtrinsicWatchEvent::Usurped { replacement_hash } => Some(*replacement_hash),
                    ExtrinsicWatchEvent::Invalid => None,
                    _ => unreachable!("pool rejection match is exhaustive"),
                };
                let state = runtime
                    .apply_watch_event(account_id, transaction_hash, event, guard)
                    .await?;
                let reason = pool_rejection_reason(&state, account_id, transaction_hash)?;
                notify(
                    observer,
                    WalletTransferWatchUpdate::new(
                        transaction_hash,
                        WalletTransferWatchStage::PoolRejected {
                            reason: reason.clone(),
                            replacement_hash,
                        },
                        state.clone(),
                    ),
                );
                return Ok(WalletTransferWatchResult::new(
                    transaction_hash,
                    WalletTransferResolution::PoolRejected { reason },
                    state,
                ));
            }
            ExtrinsicWatchEvent::Dropped => {
                let state = apply_nonterminal_event(
                    runtime,
                    guard,
                    account_id,
                    transaction_hash,
                    ExtrinsicWatchEvent::Dropped,
                )
                .await?;
                notify(
                    observer,
                    WalletTransferWatchUpdate::new(
                        transaction_hash,
                        WalletTransferWatchStage::Dropped,
                        state,
                    ),
                );
                return Err(retryable(
                    "provider 报告交易 dropped；持久 Pending/InBlock 保留",
                ));
            }
            ExtrinsicWatchEvent::Retracted { block } => {
                let state = apply_nonterminal_event(
                    runtime,
                    guard,
                    account_id,
                    transaction_hash,
                    ExtrinsicWatchEvent::Retracted { block },
                )
                .await?;
                notify(
                    observer,
                    WalletTransferWatchUpdate::new(
                        transaction_hash,
                        WalletTransferWatchStage::Retracted { block },
                        state,
                    ),
                );
                return Err(retryable(
                    "provider 报告交易所在 best 块已 retracted；持久 Pending/InBlock 保留",
                ));
            }
            ExtrinsicWatchEvent::FinalityTimeout { block } => {
                let state = apply_nonterminal_event(
                    runtime,
                    guard,
                    account_id,
                    transaction_hash,
                    ExtrinsicWatchEvent::FinalityTimeout { block },
                )
                .await?;
                notify(
                    observer,
                    WalletTransferWatchUpdate::new(
                        transaction_hash,
                        WalletTransferWatchStage::FinalityTimeout { block },
                        state,
                    ),
                );
                return Err(retryable(
                    "provider 观察交易 finality timeout；持久 Pending/InBlock 保留",
                ));
            }
            ExtrinsicWatchEvent::Ready => {
                publish_nonterminal(
                    runtime,
                    guard,
                    observer,
                    account_id,
                    transaction_hash,
                    ExtrinsicWatchEvent::Ready,
                    WalletTransferWatchStage::Ready,
                )
                .await?;
            }
            ExtrinsicWatchEvent::Broadcast { peer_count } => {
                publish_nonterminal(
                    runtime,
                    guard,
                    observer,
                    account_id,
                    transaction_hash,
                    ExtrinsicWatchEvent::Broadcast { peer_count },
                    WalletTransferWatchStage::Broadcast { peer_count },
                )
                .await?;
            }
            ExtrinsicWatchEvent::Future => {
                publish_nonterminal(
                    runtime,
                    guard,
                    observer,
                    account_id,
                    transaction_hash,
                    ExtrinsicWatchEvent::Future,
                    WalletTransferWatchStage::Future,
                )
                .await?;
            }
            ExtrinsicWatchEvent::InBlock { block } => {
                publish_nonterminal(
                    runtime,
                    guard,
                    observer,
                    account_id,
                    transaction_hash,
                    ExtrinsicWatchEvent::InBlock { block },
                    WalletTransferWatchStage::InBlock { block },
                )
                .await?;
            }
        }
    }

    notify_interrupted(
        observer,
        history,
        guard,
        account_id,
        transaction_hash,
        "provider 交易观察流在明确终态前结束".to_owned(),
    )
    .await?;
    Err(EngineError::contract(
        ContractErrorCode::Network,
        "provider 交易观察流在明确终态前结束；持久 Pending/InBlock 保留",
    ))
}

async fn publish_nonterminal(
    runtime: &FinalizedHistoryRuntime,
    guard: &dyn FinalizedHistoryRunGuard,
    observer: &Arc<dyn WalletTransferObserver>,
    account_id: AccountId32,
    transaction_hash: Hash32,
    event: ExtrinsicWatchEvent,
    stage: WalletTransferWatchStage,
) -> Result<(), EngineError> {
    let state =
        apply_nonterminal_event(runtime, guard, account_id, transaction_hash, event).await?;
    notify(
        observer,
        WalletTransferWatchUpdate::new(transaction_hash, stage, state),
    );
    Ok(())
}

async fn apply_nonterminal_event(
    runtime: &FinalizedHistoryRuntime,
    guard: &dyn FinalizedHistoryRunGuard,
    account_id: AccountId32,
    transaction_hash: Hash32,
    event: ExtrinsicWatchEvent,
) -> Result<TransactionHistoryState, EngineError> {
    runtime
        .apply_watch_event(account_id, transaction_hash, event, guard)
        .await
}

async fn finalize_exact_transaction(
    runtime: &FinalizedHistoryRuntime,
    history: &TransactionHistoryService,
    guard: &dyn FinalizedHistoryRunGuard,
    account_id: AccountId32,
    transaction_hash: Hash32,
    finalized: FinalizedBlockRef,
) -> Result<(TransactionHistoryState, ExecutionConclusion), EngineError> {
    // `Finalized` watch 事实本身不能写终态。它只给出上界；随后复用 finalized history
    // runtime，从准确 canonical ancestry 顺序读取 block body、metadata 与 System.Events。
    let mut state = history.load().await?;
    guard.ensure_current()?;
    loop {
        let record = unique_submission(&state, account_id, transaction_hash)?;
        if let HistoryTransactionStatus::Execution(conclusion) = record.status() {
            if conclusion_block(conclusion) != Some(finalized.verified()) {
                return Err(integrity(
                    "持久执行终态与 provider Finalized 事件的准确块不一致",
                ));
            }
            let conclusion = conclusion.clone();
            return Ok((state, conclusion));
        }

        let cursor = state
            .cursors()
            .iter()
            .find(|cursor| cursor.account_id() == account_id)
            .ok_or_else(|| invalid_state("钱包转账账户缺少 finalized 历史游标"))?
            .last_synced_block();
        if cursor.number() >= finalized.number() {
            return Err(EngineError::InvalidEvents(
                "provider 报告交易 Finalized，但准确目标块没有同 hash/index 的 System 执行终态"
                    .to_owned(),
            ));
        }

        let before = cursor;
        state = runtime.sync_batch(&[account_id], guard).await?;
        guard.ensure_current()?;
        let after = state
            .cursors()
            .iter()
            .find(|cursor| cursor.account_id() == account_id)
            .ok_or_else(|| invalid_state("钱包转账账户的 finalized 历史游标在同步后消失"))?
            .last_synced_block();
        if after.number() <= before.number() {
            return Err(EngineError::contract(
                ContractErrorCode::Unavailable,
                "provider 尚不能把 finalized 历史推进到交易目标块；持久 Pending/InBlock 保留",
            ));
        }
    }
}

async fn notify_interrupted(
    observer: &Arc<dyn WalletTransferObserver>,
    history: &TransactionHistoryService,
    guard: &dyn FinalizedHistoryRunGuard,
    account_id: AccountId32,
    transaction_hash: Hash32,
    reason: String,
) -> Result<(), EngineError> {
    let (state, _) = history
        .require_submission_snapshot(account_id, transaction_hash)
        .await?;
    guard.ensure_current()?;
    notify(
        observer,
        WalletTransferWatchUpdate::new(
            transaction_hash,
            WalletTransferWatchStage::Interrupted { reason },
            state,
        ),
    );
    Ok(())
}

fn pool_rejection_reason(
    state: &TransactionHistoryState,
    account_id: AccountId32,
    transaction_hash: Hash32,
) -> Result<String, EngineError> {
    unique_submission(state, account_id, transaction_hash)?
        .status()
        .pool_rejection_reason()
        .map(str::to_owned)
        .ok_or_else(|| integrity("交易池拒绝 watch 事件没有形成精确持久拒绝状态"))
}

fn unique_submission(
    state: &TransactionHistoryState,
    account_id: AccountId32,
    transaction_hash: Hash32,
) -> Result<&citizen_sdk_contracts::TransactionHistoryRecord, EngineError> {
    let matching = state
        .records()
        .iter()
        .filter(|record| {
            record.account_id() == account_id && record.transaction_hash() == transaction_hash
        })
        .collect::<Vec<_>>();
    match matching.as_slice() {
        [record] => Ok(record),
        [] => Err(invalid_state("钱包转账的持久 submission 记录不存在")),
        _ => Err(integrity("钱包转账的账户/hash 对应多条持久 submission")),
    }
}

fn conclusion_block(conclusion: &ExecutionConclusion) -> Option<VerifiedBlockRef> {
    match conclusion {
        ExecutionConclusion::Success { block, .. } | ExecutionConclusion::Failed { block, .. } => {
            Some(*block)
        }
        ExecutionConclusion::Unverified { .. } => None,
    }
}

fn notify(observer: &Arc<dyn WalletTransferObserver>, update: WalletTransferWatchUpdate) {
    // 观察器属于宿主展示边界，不是交易状态机的一部分；恶意或有缺陷的实现不能通过
    // panic 中止 Rust 交易协调器，也不能撤销已经持久化的事实。
    let _ = catch_unwind(AssertUnwindSafe(|| observer.on_update(update)));
}

fn retryable(message: impl Into<String>) -> EngineError {
    EngineError::contract(ContractErrorCode::Unavailable, message)
}

fn invalid_state(message: impl Into<String>) -> EngineError {
    EngineError::contract(ContractErrorCode::InvalidState, message)
}

fn integrity(message: impl Into<String>) -> EngineError {
    EngineError::contract(ContractErrorCode::Integrity, message)
}
