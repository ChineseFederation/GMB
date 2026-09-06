//! finalized 历史的确定性单批协调器。
//!
//! 本模块不创建后台线程或区块订阅。后台批次由宿主调度；仅高层交易已见 finalized 时
//! 使用官方 Tokio 定时器在整笔执行预算内重试事件读取。每次调用最多
//! 连续处理 120 个高度。每一块都从 [`VerifiedChainClient`] 直接读取 canonical finalized
//! 块、同块 Runtime、完整 body 与 `System.Events`，然后把转账、执行终态和游标交给
//! [`TransactionHistoryService`] 一次 CAS。任何证据缺失都在 CAS 前失败，游标保持原位。

use std::{collections::BTreeSet, sync::Arc};

use citizen_sdk_contracts::{
    store::{FinalizedTransferRecord, TransactionHistoryState},
    validated_finalized_block_range_len, AccountId32, ContractErrorCode, ExtrinsicWatchEvent,
    FinalizedBlockRef, Hash32, SignedExtrinsic, VerifiedChainClient,
    MAX_FINALIZED_BLOCKS_PER_BATCH,
};

use crate::{
    error::EngineError,
    finalized_events::{
        decode_finalized_events, DecodedFinalizedEvents, SYSTEM_EVENTS_STORAGE_KEY,
    },
    signed_extrinsic_hash,
    transaction_history::TransactionHistoryService,
    transaction_outcome::{verify_finalized_execution, TransactionEvidence},
};

/// Engine 生命周期代际门；每次外部 await 后必须重新核对。
pub(crate) trait FinalizedHistoryRunGuard: Send + Sync {
    fn ensure_current(&self) -> Result<(), EngineError>;
    fn begin_watch(&self) {}
    fn begin_execution(&self) {}
    fn execution_budget(&self) -> Option<std::time::Duration> {
        None
    }
    fn poll_cancelled(&self, _: &mut std::task::Context<'_>) -> std::task::Poll<()> {
        std::task::Poll::Pending
    }
}

/// 只有高层交易已见 finalized 才重试；钱包历史后台批次仍立即返回失败给调度器。
pub(crate) async fn wait_execution_retry(
    guard: &dyn FinalizedHistoryRunGuard,
) -> Result<bool, EngineError> {
    let Some(remaining) = guard.execution_budget() else {
        return Ok(false);
    };
    if remaining.is_zero() {
        return Err(EngineError::contract(
            ContractErrorCode::Timeout,
            "finalized execution lookup budget expired; durable pending history retained",
        ));
    }
    cancellable_chain(
        tokio::time::sleep(remaining.min(std::time::Duration::from_secs(1))),
        guard,
    )
    .await?;
    guard.ensure_current()?;
    Ok(true)
}

/// 只用于链读取/观察，不包裹持久化 future；已进入的 store/CAS 必须真正返回。
pub(crate) async fn cancellable_chain<T>(
    future: impl std::future::Future<Output = T>,
    guard: &dyn FinalizedHistoryRunGuard,
) -> Result<T, EngineError> {
    let mut future = std::pin::pin!(future);
    std::future::poll_fn(|cx| {
        if guard.poll_cancelled(cx).is_ready() {
            return std::task::Poll::Ready(Err(invalid_state(
                "wallet monitor generation was cancelled",
            )));
        }
        future.as_mut().poll(cx).map(Ok)
    })
    .await
}

/// 仅由 [`crate::CitizenEngine`] 构造的低层协调器。
pub(crate) struct FinalizedHistoryRuntime {
    chain_client: Arc<dyn VerifiedChainClient>,
    history: TransactionHistoryService,
}

impl FinalizedHistoryRuntime {
    pub(crate) const fn new(
        chain_client: Arc<dyn VerifiedChainClient>,
        history: TransactionHistoryService,
    ) -> Self {
        Self {
            chain_client,
            history,
        }
    }

    /// 新账户从调用时的当前 finalized head 开始监控，不补写加入前历史。
    pub(crate) async fn initialize_accounts(
        &self,
        account_ids: &[AccountId32],
        guard: &dyn FinalizedHistoryRunGuard,
    ) -> Result<TransactionHistoryState, EngineError> {
        guard.ensure_current()?;
        if account_ids.is_empty() {
            let state = self.history.load().await?;
            guard.ensure_current()?;
            return Ok(state);
        }
        let finalized = cancellable_chain(self.chain_client.get_finalized_head(), guard)
            .await?
            .map_err(EngineError::from)?;
        guard.ensure_current()?;
        let state = self.history.ensure_cursors(account_ids, finalized).await?;
        guard.ensure_current()?;
        Ok(state)
    }

    /// 向当前 provider finalized head 连续同步至多 120 个高度。
    pub(crate) async fn sync_batch(
        &self,
        account_ids: &[AccountId32],
        guard: &dyn FinalizedHistoryRunGuard,
    ) -> Result<TransactionHistoryState, EngineError> {
        guard.ensure_current()?;
        let tracked: BTreeSet<_> = account_ids.iter().copied().collect();
        let mut state = self.history.load().await?;
        guard.ensure_current()?;
        if tracked.is_empty() {
            return Ok(state);
        }
        require_all_cursors(&state, &tracked)?;

        let finalized_head = cancellable_chain(self.chain_client.get_finalized_head(), guard)
            .await?
            .map_err(EngineError::from)?;
        guard.ensure_current()?;
        let minimum_cursor = minimum_cursor_number(&state, &tracked)?;
        if minimum_cursor > finalized_head.number() {
            return Err(integrity("本地交易游标高于 provider 已验证 finalized head"));
        }
        let Some(start_number) = minimum_cursor.checked_add(1) else {
            return Err(invalid_state("finalized 交易游标高度已耗尽"));
        };
        if start_number > finalized_head.number() {
            return Ok(state);
        }
        let inclusive_limit = start_number.saturating_add(MAX_FINALIZED_BLOCKS_PER_BATCH - 1);
        let end_number = finalized_head.number().min(inclusive_limit);

        // 一次请求让 provider 从同一个 verified finalized anchor 完成整段 ancestry walk；
        // 禁止逐高度从当前链头重复回溯形成 O(batch × gap)。
        let blocks = cancellable_chain(
            self.chain_client
                .get_finalized_blocks_at(start_number, end_number),
            guard,
        )
        .await?
        .map_err(EngineError::from)?;
        guard.ensure_current()?;
        let expected_len = validated_finalized_block_range_len(start_number, end_number)
            .map_err(EngineError::from)?;
        if blocks.len() != expected_len {
            return Err(integrity("provider 返回了部分 finalized batch"));
        }

        for (index, block) in blocks.into_iter().enumerate() {
            let offset =
                u64::try_from(index).map_err(|_| integrity("finalized batch 索引超过 u64"))?;
            let expected_number = start_number
                .checked_add(offset)
                .ok_or_else(|| integrity("finalized batch 高度顺序溢出"))?;
            if block.number() != expected_number || block.number() > finalized_head.number() {
                return Err(integrity(
                    "provider 返回的 canonical finalized 块高度偏离请求或越过已验证上界",
                ));
            }
            guard.ensure_current()?;
            state = self.process_finalized_block(block, &tracked, guard).await?;
        }
        Ok(state)
    }

    /// 恢复未终态记录，只查询准确 canonical body/System.Events，绝不调用 submit/watch。
    /// 游标已越过该块也允许复核 pending，覆盖广播和历史 CAS 交错及重启窗口。
    /// 内存进度丢失仅导致重读，不影响持久化终态；一次最多 120 块。
    pub(crate) async fn reconcile_pending_batch(
        &self,
        accounts: &[AccountId32],
        positions: &mut std::collections::BTreeMap<Hash32, u64>,
        guard: &dyn FinalizedHistoryRunGuard,
    ) -> Result<TransactionHistoryState, EngineError> {
        let mut state = self.history.load().await?;
        guard.ensure_current()?;
        let tracked = accounts.iter().copied().collect::<BTreeSet<_>>();
        let pending = state
            .records()
            .iter()
            .filter(|record| {
                tracked.contains(&record.account_id())
                    && matches!(
                        record.status(),
                        citizen_sdk_contracts::HistoryTransactionStatus::Pending
                            | citizen_sdk_contracts::HistoryTransactionStatus::InBlock { .. }
                    )
            })
            .map(|record| (record.transaction_hash(), record.block().number()))
            .collect::<Vec<_>>();
        positions.retain(|hash, _| pending.iter().any(|(candidate, _)| candidate == hash));
        if pending.is_empty() || tracked.is_empty() {
            return Ok(state);
        }
        let upper = minimum_cursor_number(&state, &tracked)?;
        for (hash, floor) in pending {
            positions.entry(hash).or_insert(floor);
        }
        let Some(start) = positions
            .values()
            .copied()
            .filter(|height| *height <= upper)
            .min()
        else {
            return Ok(state);
        };
        let end = upper.min(start.saturating_add(MAX_FINALIZED_BLOCKS_PER_BATCH - 1));
        let blocks =
            cancellable_chain(self.chain_client.get_finalized_blocks_at(start, end), guard)
                .await??;
        if blocks.len() != validated_finalized_block_range_len(start, end)? {
            return Err(integrity(
                "pending recovery received a partial finalized batch",
            ));
        }
        for (offset, block) in blocks.into_iter().enumerate() {
            if block.number() != start + offset as u64 {
                return Err(integrity("pending recovery block order mismatch"));
            }
            state = self.process_finalized_block(block, &tracked, guard).await?;
            for position in positions.values_mut() {
                if *position <= block.number() {
                    *position = block.number().saturating_add(1).min(upper);
                }
            }
        }
        Ok(state)
    }

    /// 处理一个准确块。该入口保持 crate-private，供确定性重放/并发合同测试使用。
    pub(crate) async fn process_finalized_block(
        &self,
        block: FinalizedBlockRef,
        tracked: &BTreeSet<AccountId32>,
        guard: &dyn FinalizedHistoryRunGuard,
    ) -> Result<TransactionHistoryState, EngineError> {
        guard.ensure_current()?;
        let runtime_context = cancellable_chain(
            self.chain_client.get_finalized_runtime_context_at(block),
            guard,
        )
        .await?
        .map_err(EngineError::from)?;
        guard.ensure_current()?;
        if runtime_context.block() != block.verified() {
            return Err(EngineError::BlockContextMismatch(
                "provider 返回了跨块 finalized Runtime context".to_owned(),
            ));
        }

        let block_extrinsics = cancellable_chain(
            self.chain_client.get_finalized_block_extrinsics_at(block),
            guard,
        )
        .await?
        .map_err(EngineError::from)?;
        guard.ensure_current()?;
        let (system_events, decoded) = loop {
            // 同一块体只读一次；短暂不可用的 System.Events 读取复用上方准确块/metadata。
            let candidate = cancellable_chain(
                self.chain_client
                    .get_finalized_storage_at(block, SYSTEM_EVENTS_STORAGE_KEY.to_vec()),
                guard,
            )
            .await?
            .map_err(EngineError::from)
            .and_then(|events| {
                events.ok_or_else(|| {
                    EngineError::InvalidEvents(
                        "provider 未返回 finalized System.Events；本块不得推进游标".to_owned(),
                    )
                })
            })
            .and_then(|events| {
                decode_finalized_events(block, &runtime_context, &events)
                    .map(|decoded| (events, decoded))
            });
            guard.ensure_current()?;
            match candidate {
                Ok(value) => break value,
                Err(error) => {
                    // 已验证身份/证明冲突不能通过重试降级；仅暂不可用或事件未取得可重试。
                    let retryable = match &error {
                        EngineError::InvalidEvents(_) => true,
                        EngineError::Contract(error) => matches!(
                            error.code(),
                            ContractErrorCode::Unavailable
                                | ContractErrorCode::NotReady
                                | ContractErrorCode::Timeout
                        ),
                        _ => false,
                    };
                    if !retryable || !wait_execution_retry(guard).await? {
                        return Err(error);
                    }
                }
            }
        };

        // 链读取完成后重新加载最新仓储，以纳入读取期间新增的 pending。后续所有事实仍由
        // TransactionHistoryService 在同一个 CAS 候选中提交。
        let state = self.history.load().await?;
        guard.ensure_current()?;
        require_all_cursors(&state, tracked)?;
        let accounts_to_advance = accounts_ready_for_block(&state, tracked, block)?;
        let pending = state
            .records()
            .iter()
            .filter(|record| {
                tracked.contains(&record.account_id()) && !record.status().is_chain_terminal()
            })
            .collect::<Vec<_>>();

        let mut body = Vec::with_capacity(block_extrinsics.len());
        for bytes in block_extrinsics {
            let extrinsic = SignedExtrinsic::try_new(bytes).map_err(EngineError::from)?;
            let transaction_hash = signed_extrinsic_hash(&runtime_context, &extrinsic)?;
            body.push((transaction_hash, extrinsic));
        }

        let body_bytes = body
            .iter()
            .map(|(_, extrinsic)| extrinsic.as_bytes().to_vec())
            .collect::<Vec<_>>();
        let mut execution_updates = Vec::new();
        for record in pending {
            let matches = body
                .iter()
                .enumerate()
                .filter_map(|(index, (hash, extrinsic))| {
                    (*hash == record.transaction_hash()).then_some((index, extrinsic))
                })
                .collect::<Vec<_>>();
            match matches.as_slice() {
                [] => {}
                [(index, extrinsic)] => {
                    let extrinsic_index = u32::try_from(*index)
                        .map_err(|_| integrity("finalized 块体 extrinsic index 超过 u32"))?;
                    if decoded.outcome(extrinsic_index).is_none() {
                        return Err(EngineError::InvalidEvents(format!(
                            "pending txHash 命中 extrinsic index {extrinsic_index}，但缺少唯一 System 终态"
                        )));
                    }
                    execution_updates.push(verify_finalized_execution(TransactionEvidence {
                        block: block.verified(),
                        runtime_context: &runtime_context,
                        signed_extrinsic: extrinsic,
                        submitted_hash: record.transaction_hash(),
                        block_extrinsics: &body_bytes,
                        system_events: Some(&system_events),
                    })?);
                }
                _ => {
                    return Err(integrity(
                        "同一 pending txHash 在 finalized 块体中命中多个 extrinsic",
                    ));
                }
            }
        }

        let transfers = project_transfers(block, decoded, &accounts_to_advance)?;
        let advance_accounts = accounts_to_advance.iter().copied().collect::<Vec<_>>();
        guard.ensure_current()?;
        let committed = self
            .history
            .commit_finalized_block(block, &transfers, &execution_updates, &advance_accounts)
            .await?;
        guard.ensure_current()?;
        Ok(committed)
    }

    /// typed watch 只保存不会伪造链上终态的有限事实。
    pub(crate) async fn apply_watch_event(
        &self,
        account_id: AccountId32,
        transaction_hash: Hash32,
        event: ExtrinsicWatchEvent,
        guard: &dyn FinalizedHistoryRunGuard,
    ) -> Result<TransactionHistoryState, EngineError> {
        guard.ensure_current()?;
        let state = match event {
            ExtrinsicWatchEvent::InBlock { block } => {
                self.history
                    .mark_in_block(account_id, transaction_hash, block)
                    .await?
            }
            ExtrinsicWatchEvent::Invalid => {
                self.history
                    .mark_pool_rejected(account_id, transaction_hash, "invalid transaction")
                    .await?
            }
            ExtrinsicWatchEvent::Usurped { replacement_hash } => {
                let reason = format!(
                    "usurped by replacement extrinsic 0x{}",
                    encode_hash(replacement_hash)
                );
                self.history
                    .mark_pool_rejected(account_id, transaction_hash, &reason)
                    .await?
            }
            // `Finalized` 只证明块锚，不证明 Runtime 执行成功；Ready/Broadcast/Future/
            // Dropped/Retracted/timeout 以及宿主观察到的断线均不写任何终态。
            ExtrinsicWatchEvent::Ready
            | ExtrinsicWatchEvent::Broadcast { .. }
            | ExtrinsicWatchEvent::Future
            | ExtrinsicWatchEvent::Finalized { .. }
            | ExtrinsicWatchEvent::Retracted { .. }
            | ExtrinsicWatchEvent::FinalityTimeout { .. }
            | ExtrinsicWatchEvent::Dropped => self.history.load().await?,
        };
        guard.ensure_current()?;
        Ok(state)
    }
}

fn require_all_cursors(
    state: &TransactionHistoryState,
    tracked: &BTreeSet<AccountId32>,
) -> Result<(), EngineError> {
    if tracked.iter().any(|account_id| {
        !state
            .cursors()
            .iter()
            .any(|cursor| cursor.account_id() == *account_id)
    }) {
        return Err(invalid_state("监控账户缺少持久 finalized 游标"));
    }
    Ok(())
}

fn minimum_cursor_number(
    state: &TransactionHistoryState,
    tracked: &BTreeSet<AccountId32>,
) -> Result<u64, EngineError> {
    tracked
        .iter()
        .filter_map(|account_id| {
            state
                .cursors()
                .iter()
                .find(|cursor| cursor.account_id() == *account_id)
                .map(|cursor| cursor.last_synced_block().number())
        })
        .min()
        .ok_or_else(|| invalid_state("监控账户没有可用 finalized 游标"))
}

fn accounts_ready_for_block(
    state: &TransactionHistoryState,
    tracked: &BTreeSet<AccountId32>,
    block: FinalizedBlockRef,
) -> Result<BTreeSet<AccountId32>, EngineError> {
    let mut ready = BTreeSet::new();
    for account_id in tracked {
        let cursor = state
            .cursors()
            .iter()
            .find(|cursor| cursor.account_id() == *account_id)
            .ok_or_else(|| invalid_state("监控账户缺少持久 finalized 游标"))?;
        let last = cursor.last_synced_block();
        if last.number() == block.number() {
            if last.hash() != block.hash() {
                return Err(integrity(
                    "交易游标与 provider canonical finalized 块在同高度发生哈希冲突",
                ));
            }
            continue;
        }
        if last.number() > block.number() {
            continue;
        }
        let expected = last
            .number()
            .checked_add(1)
            .ok_or_else(|| invalid_state("finalized 交易游标高度已耗尽"))?;
        if expected != block.number() {
            return Err(invalid_state(
                "finalized 历史处理检测到游标跳块；本块不得提交",
            ));
        }
        ready.insert(*account_id);
    }
    Ok(ready)
}

fn project_transfers(
    block: FinalizedBlockRef,
    decoded: DecodedFinalizedEvents,
    eligible_accounts: &BTreeSet<AccountId32>,
) -> Result<Vec<FinalizedTransferRecord>, EngineError> {
    let mut records = Vec::new();
    for transfer in decoded.transfers() {
        for account_id in [transfer.from_account_id, transfer.to_account_id] {
            if !eligible_accounts.contains(&account_id) {
                continue;
            }
            let record = FinalizedTransferRecord::try_for_tracked_account_from_runtime_event(
                account_id,
                transfer.from_account_id,
                transfer.to_account_id,
                transfer.amount_fen,
                block,
                transfer.event_record_index,
                transfer.extrinsic_index,
                transfer.source_pallet,
                transfer.remark_bytes.as_deref(),
            )?;
            if record.remark() != transfer.remark.as_deref() {
                return Err(integrity(
                    "finalized Runtime remark 在解码层与历史值对象间产生投影漂移",
                ));
            }
            records.push(record);
        }
    }
    Ok(records)
}

fn encode_hash(hash: Hash32) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut encoded = String::with_capacity(64);
    for byte in hash.as_bytes() {
        encoded.push(char::from(HEX[usize::from(byte >> 4)]));
        encoded.push(char::from(HEX[usize::from(byte & 0x0f)]));
    }
    encoded
}

fn invalid_state(message: impl Into<String>) -> EngineError {
    EngineError::contract(ContractErrorCode::InvalidState, message)
}

fn integrity(message: impl Into<String>) -> EngineError {
    EngineError::contract(ContractErrorCode::Integrity, message)
}
