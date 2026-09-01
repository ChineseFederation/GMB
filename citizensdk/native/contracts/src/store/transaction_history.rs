//! finalized 交易事实、待确认提交和逐账户同步游标的专用仓储。

use std::collections::BTreeSet;

use crate::{
    AccountId32, ContractError, ContractErrorCode, ContractFuture, ContractResult,
    ExecutionConclusion, Hash32, VerifiedBlockRef,
};

/// 本机提交记录的产品无关状态；入块和 finalized 都不等于执行成功。
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum HistoryTransactionStatus {
    Submitted,
    InBlock { block: VerifiedBlockRef },
    PoolRejected,
    Execution(ExecutionConclusion),
}

/// 一条本机交易记录；不保存私钥、签名秘密或产品订单数据。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TransactionHistoryRecord {
    account_id: AccountId32,
    transaction_hash: Hash32,
    nonce: u64,
    status: HistoryTransactionStatus,
    created_at_millis: u64,
    updated_at_millis: u64,
}

impl TransactionHistoryRecord {
    pub fn try_new(
        account_id: AccountId32,
        transaction_hash: Hash32,
        nonce: u64,
        status: HistoryTransactionStatus,
        created_at_millis: u64,
        updated_at_millis: u64,
    ) -> ContractResult<Self> {
        if updated_at_millis < created_at_millis {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "交易记录更新时间不能早于创建时间",
            ));
        }
        Ok(Self {
            account_id,
            transaction_hash,
            nonce,
            status,
            created_at_millis,
            updated_at_millis,
        })
    }

    pub const fn account_id(&self) -> AccountId32 {
        self.account_id
    }

    pub const fn transaction_hash(&self) -> Hash32 {
        self.transaction_hash
    }

    pub const fn nonce(&self) -> u64 {
        self.nonce
    }

    pub const fn status(&self) -> &HistoryTransactionStatus {
        &self.status
    }

    pub const fn created_at_millis(&self) -> u64 {
        self.created_at_millis
    }

    pub const fn updated_at_millis(&self) -> u64 {
        self.updated_at_millis
    }
}

/// 一个账户的 finalized 增量同步游标。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct TransactionHistoryCursor {
    account_id: AccountId32,
    tracking_start_block: u64,
    last_synced_block: u64,
}

impl TransactionHistoryCursor {
    pub fn try_new(
        account_id: AccountId32,
        tracking_start_block: u64,
        last_synced_block: u64,
    ) -> ContractResult<Self> {
        if last_synced_block < tracking_start_block {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "交易游标不能倒退到跟踪起点之前",
            ));
        }
        Ok(Self {
            account_id,
            tracking_start_block,
            last_synced_block,
        })
    }

    pub const fn account_id(self) -> AccountId32 {
        self.account_id
    }

    pub const fn tracking_start_block(self) -> u64 {
        self.tracking_start_block
    }

    pub const fn last_synced_block(self) -> u64 {
        self.last_synced_block
    }
}

/// finalized 块中的产品无关 CitizenChain 转账事件。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FinalizedTransferRecord {
    from_account_id: AccountId32,
    to_account_id: AccountId32,
    amount_fen: u128,
    block: crate::FinalizedBlockRef,
    event_record_index: u32,
    extrinsic_index: Option<u32>,
    source_pallet: String,
    remark: Option<String>,
}

impl FinalizedTransferRecord {
    #[allow(clippy::too_many_arguments)]
    pub fn try_new(
        from_account_id: AccountId32,
        to_account_id: AccountId32,
        amount_fen: u128,
        block: crate::FinalizedBlockRef,
        event_record_index: u32,
        extrinsic_index: Option<u32>,
        source_pallet: impl Into<String>,
        remark: Option<String>,
    ) -> ContractResult<Self> {
        let source_pallet = source_pallet.into();
        if amount_fen == 0 || source_pallet.trim().is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "finalized 转账金额与来源 pallet 必须有效",
            ));
        }
        Ok(Self {
            from_account_id,
            to_account_id,
            amount_fen,
            block,
            event_record_index,
            extrinsic_index,
            source_pallet,
            remark,
        })
    }

    pub const fn from_account_id(&self) -> AccountId32 {
        self.from_account_id
    }

    pub const fn to_account_id(&self) -> AccountId32 {
        self.to_account_id
    }

    pub const fn amount_fen(&self) -> u128 {
        self.amount_fen
    }

    pub const fn block(&self) -> crate::FinalizedBlockRef {
        self.block
    }

    pub const fn event_record_index(&self) -> u32 {
        self.event_record_index
    }

    pub const fn extrinsic_index(&self) -> Option<u32> {
        self.extrinsic_index
    }

    pub fn source_pallet(&self) -> &str {
        &self.source_pallet
    }

    pub fn remark(&self) -> Option<&str> {
        self.remark.as_deref()
    }
}

/// 历史仓储的一次完整、可 CAS 的公开状态。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TransactionHistoryState {
    revision: u64,
    cursors: Vec<TransactionHistoryCursor>,
    records: Vec<TransactionHistoryRecord>,
    transfers: Vec<FinalizedTransferRecord>,
}

impl TransactionHistoryState {
    pub fn try_new(
        revision: u64,
        cursors: Vec<TransactionHistoryCursor>,
        records: Vec<TransactionHistoryRecord>,
        transfers: Vec<FinalizedTransferRecord>,
    ) -> ContractResult<Self> {
        let cursor_accounts: BTreeSet<_> = cursors
            .iter()
            .copied()
            .map(TransactionHistoryCursor::account_id)
            .collect();
        let record_keys: BTreeSet<_> = records
            .iter()
            .map(|record| (record.account_id(), record.transaction_hash()))
            .collect();
        let transfer_keys: BTreeSet<_> = transfers
            .iter()
            .map(|transfer| (transfer.block().hash(), transfer.event_record_index()))
            .collect();
        if cursor_accounts.len() != cursors.len()
            || record_keys.len() != records.len()
            || transfer_keys.len() != transfers.len()
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "交易游标、账户/交易哈希键或 finalized 事件键重复",
            ));
        }
        Ok(Self {
            revision,
            cursors,
            records,
            transfers,
        })
    }

    pub const fn revision(&self) -> u64 {
        self.revision
    }

    pub fn cursors(&self) -> &[TransactionHistoryCursor] {
        &self.cursors
    }

    pub fn records(&self) -> &[TransactionHistoryRecord] {
        &self.records
    }

    pub fn transfers(&self) -> &[FinalizedTransferRecord] {
        &self.transfers
    }
}

/// finalized 历史、待确认提交和游标必须在一次 CAS 中共同提交。
pub trait TransactionHistoryStore: Send + Sync {
    fn load(&self) -> ContractFuture<'_, TransactionHistoryState>;

    fn compare_and_swap(
        &self,
        expected_revision: u64,
        next: TransactionHistoryState,
    ) -> ContractFuture<'_, TransactionHistoryState>;
}
