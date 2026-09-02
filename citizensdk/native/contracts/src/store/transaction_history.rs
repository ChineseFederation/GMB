//! finalized 交易事实、待确认提交和逐账户同步游标的专用仓储。

use std::collections::BTreeSet;

use crate::{
    AccountId32, ContractError, ContractErrorCode, ContractFuture, ContractResult,
    ExecutionConclusion, FinalizedBlockRef, Hash32, VerifiedBlockRef,
};

/// 99 个任意 Runtime bytes 经标准 UTF-8 lossy 投影后的最坏展示字节数。
///
/// 该上限只属于 finalized 链事实；pending/call 输入仍使用
/// [`crate::MAX_TRANSFER_REMARK_BYTES`]，不得复用本常量放宽业务输入。
pub const MAX_FINALIZED_REMARK_DISPLAY_BYTES: usize = crate::MAX_TRANSFER_REMARK_BYTES * 3;

/// 本机提交记录的产品无关状态；入块和 finalized 都不等于执行成功。
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum HistoryTransactionStatus {
    /// 精确对应现有 Dart 持久状态 `pending`：已在广播前持久化，但没有入块或执行证明。
    Pending,
    InBlock {
        block: VerifiedBlockRef,
    },
    PoolRejected {
        reason: String,
    },
    /// 只接受 finalized 同块同 index 的明确 Success/Failed；Unverified 不能持久化。
    Execution(ExecutionConclusion),
}

impl HistoryTransactionStatus {
    pub fn try_pool_rejected(reason: impl Into<String>) -> ContractResult<Self> {
        let reason = reason.into();
        if reason.trim().is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "交易池拒绝原因不能为空",
            ));
        }
        Ok(Self::PoolRejected { reason })
    }

    pub fn pool_rejection_reason(&self) -> Option<&str> {
        match self {
            Self::PoolRejected { reason } => Some(reason),
            _ => None,
        }
    }

    /// 只有同块同 extrinsic index 核验出的 runtime Success/Failed 才是链上终态。
    pub const fn is_chain_terminal(&self) -> bool {
        match self {
            Self::Execution(ExecutionConclusion::Success { block, .. })
            | Self::Execution(ExecutionConclusion::Failed { block, .. }) => block.is_finalized(),
            _ => false,
        }
    }

    /// 与已验证 Dart 持久枚举的唯一映射；`None` 表示非法的 Unverified 终态。
    pub fn persisted_name(&self) -> Option<&'static str> {
        match self {
            Self::Pending => Some("pending"),
            Self::InBlock { .. } => Some("inBlock"),
            Self::PoolRejected { reason } if !reason.trim().is_empty() => Some("poolRejected"),
            Self::Execution(ExecutionConclusion::Success { block, .. }) if block.is_finalized() => {
                Some("finalized")
            }
            Self::Execution(ExecutionConclusion::Failed { block, .. }) if block.is_finalized() => {
                Some("failed")
            }
            Self::PoolRejected { .. }
            | Self::Execution(ExecutionConclusion::Success { .. })
            | Self::Execution(ExecutionConclusion::Failed { .. })
            | Self::Execution(ExecutionConclusion::Unverified { .. }) => None,
        }
    }

    /// 本地状态只能向更强证据前进；pool rejection 仍可被随后找到的链上执行事实覆盖。
    pub fn allows_transition_to(&self, next: &Self) -> bool {
        if self == next {
            return true;
        }
        match (self, next) {
            (
                Self::Pending,
                Self::InBlock { .. } | Self::PoolRejected { .. } | Self::Execution(_),
            )
            | (
                Self::InBlock { .. },
                Self::InBlock { .. } | Self::PoolRejected { .. } | Self::Execution(_),
            )
            | (Self::PoolRejected { .. }, Self::Execution(_)) => true,
            (Self::Execution(_), _) => false,
            _ => false,
        }
    }
}

/// 一条本机交易记录；不保存私钥、签名秘密或产品订单数据。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TransactionHistoryRecord {
    account_id: AccountId32,
    transaction_hash: Hash32,
    nonce: u64,
    destination_account_id: AccountId32,
    amount_fen: u128,
    remark: String,
    status: HistoryTransactionStatus,
    created_at_millis: u64,
    updated_at_millis: u64,
}

impl TransactionHistoryRecord {
    /// 构造参数逐项对应已验证 Dart `PendingSubmittedTransaction` 的不可省略持久字段。
    #[allow(clippy::too_many_arguments)]
    pub fn try_new(
        account_id: AccountId32,
        transaction_hash: Hash32,
        nonce: u64,
        destination_account_id: AccountId32,
        amount_fen: u128,
        remark: impl Into<String>,
        status: HistoryTransactionStatus,
        created_at_millis: u64,
        updated_at_millis: u64,
    ) -> ContractResult<Self> {
        let remark = remark.into();
        if amount_fen == 0 || remark.len() > crate::MAX_TRANSFER_REMARK_BYTES {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "pending 转账金额必须为正 u128，备注不得超过 99 个 UTF-8 字节",
            ));
        }
        if updated_at_millis < created_at_millis {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "交易记录更新时间不能早于创建时间",
            ));
        }
        if !history_status_is_persistable(&status) {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "交易历史 Execution 必须是 finalized 同块同 index 的 Success/Failed",
            ));
        }
        Ok(Self {
            account_id,
            transaction_hash,
            nonce,
            destination_account_id,
            amount_fen,
            remark,
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

    pub const fn destination_account_id(&self) -> AccountId32 {
        self.destination_account_id
    }

    pub const fn amount_fen(&self) -> u128 {
        self.amount_fen
    }

    pub fn remark(&self) -> &str {
        &self.remark
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

    /// 相同 `(account_id, txHash)` 的广播前重试只能复用逐项完全一致的提交事实。
    pub fn require_same_submission_facts(&self, other: &Self) -> ContractResult<()> {
        if self.account_id != other.account_id
            || self.transaction_hash != other.transaction_hash
            || self.nonce != other.nonce
            || self.destination_account_id != other.destination_account_id
            || self.amount_fen != other.amount_fen
            || self.remark != other.remark
        {
            return Err(ContractError::new(
                ContractErrorCode::Integrity,
                "同一 txHash 的本机提交事实不一致",
            ));
        }
        Ok(())
    }

    /// 保持交易身份、nonce 与创建时间不变，只按证据强度更新状态和时间。
    pub fn try_with_status(
        &self,
        status: HistoryTransactionStatus,
        updated_at_millis: u64,
    ) -> ContractResult<Self> {
        if !self.status.allows_transition_to(&status) {
            return Err(ContractError::new(
                ContractErrorCode::InvalidState,
                "交易历史状态不能从强证据倒退或改写终态",
            ));
        }
        Self::try_new(
            self.account_id,
            self.transaction_hash,
            self.nonce,
            self.destination_account_id,
            self.amount_fen,
            self.remark.clone(),
            status,
            self.created_at_millis,
            updated_at_millis,
        )
    }
}

fn history_status_is_persistable(status: &HistoryTransactionStatus) -> bool {
    match status {
        HistoryTransactionStatus::Execution(ExecutionConclusion::Success { block, .. })
        | HistoryTransactionStatus::Execution(ExecutionConclusion::Failed { block, .. }) => {
            block.is_finalized()
        }
        HistoryTransactionStatus::Execution(ExecutionConclusion::Unverified { .. }) => false,
        HistoryTransactionStatus::PoolRejected { reason } => !reason.trim().is_empty(),
        _ => true,
    }
}

/// 一个账户的 finalized 增量同步游标。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct TransactionHistoryCursor {
    account_id: AccountId32,
    tracking_start_block: FinalizedBlockRef,
    last_synced_block: FinalizedBlockRef,
}

impl TransactionHistoryCursor {
    pub fn try_new(
        account_id: AccountId32,
        tracking_start_block: FinalizedBlockRef,
        last_synced_block: FinalizedBlockRef,
    ) -> ContractResult<Self> {
        if last_synced_block.number() < tracking_start_block.number()
            || (last_synced_block.number() == tracking_start_block.number()
                && last_synced_block != tracking_start_block)
        {
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

    pub const fn tracking_start_block(self) -> FinalizedBlockRef {
        self.tracking_start_block
    }

    pub const fn last_synced_block(self) -> FinalizedBlockRef {
        self.last_synced_block
    }

    pub fn try_advance(self, next_finalized_block: FinalizedBlockRef) -> ContractResult<Self> {
        if next_finalized_block == self.last_synced_block {
            return Ok(self);
        }
        let expected_number = self
            .last_synced_block
            .number()
            .checked_add(1)
            .ok_or_else(|| {
                ContractError::new(
                    ContractErrorCode::InvalidState,
                    "finalized 交易游标高度已耗尽",
                )
            })?;
        if next_finalized_block.number() != expected_number {
            return Err(ContractError::new(
                ContractErrorCode::InvalidState,
                "finalized 交易游标只能逐块连续推进，不能倒退或跳块",
            ));
        }
        Self::try_new(
            self.account_id,
            self.tracking_start_block,
            next_finalized_block,
        )
    }
}

/// finalized 块中的产品无关 CitizenChain 转账事件。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FinalizedTransferRecord {
    tracked_account_id: AccountId32,
    incoming: bool,
    from_account_id: AccountId32,
    to_account_id: AccountId32,
    amount_fen: u128,
    block: crate::FinalizedBlockRef,
    event_record_index: u32,
    extrinsic_index: Option<u32>,
    source_pallet: String,
    remark: Option<String>,
    /// finalized Runtime 的规范原始 bytes；持久化层必须与展示投影一起 round-trip。
    remark_bytes: Option<Vec<u8>>,
}

impl FinalizedTransferRecord {
    /// 兼容原合同的发送方视图；新扫描器应显式调用 [`Self::try_for_tracked_account`]。
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
        // 兼容构造器固定创建“发送方视图”：第一个参数是 tracked account，第二个才是
        // event from account。显式命名，避免两个同值位置参数被误读成重复参数遗漏。
        let tracked_account_id = from_account_id;
        Self::try_for_tracked_account(
            tracked_account_id,
            from_account_id,
            to_account_id,
            amount_fen,
            block,
            event_record_index,
            extrinsic_index,
            source_pallet,
            remark,
        )
    }

    /// 为一个实际被跟踪账户构造链上事件视图；同一事件可分别为收发双方各保存一条。
    ///
    /// CitizenApp 的 finalized 解码器不把自转账视为资金流水；Core 在值对象
    /// 边界同样拒绝，避免任何 provider/store 组合绕过解码层后写入伪流水。
    #[allow(clippy::too_many_arguments)]
    pub fn try_for_tracked_account(
        tracked_account_id: AccountId32,
        from_account_id: AccountId32,
        to_account_id: AccountId32,
        amount_fen: u128,
        block: crate::FinalizedBlockRef,
        event_record_index: u32,
        extrinsic_index: Option<u32>,
        source_pallet: impl Into<String>,
        remark: Option<String>,
    ) -> ContractResult<Self> {
        if remark
            .as_ref()
            .is_some_and(|value| value.len() > crate::MAX_TRANSFER_REMARK_BYTES)
        {
            return Err(ContractError::new(
                ContractErrorCode::Integrity,
                "链上 transfer_with_remark 备注超过 Runtime 上限",
            ));
        }
        let remark_bytes = remark.as_ref().map(|value| value.as_bytes().to_vec());
        Self::try_for_tracked_account_inner(
            tracked_account_id,
            from_account_id,
            to_account_id,
            amount_fen,
            block,
            event_record_index,
            extrinsic_index,
            source_pallet.into(),
            remark,
            remark_bytes,
        )
    }

    /// 从 metadata 严格解码的 finalized Runtime 原始备注 bytes 构造历史视图。
    ///
    /// Runtime 合同允许最多 99 个任意 bytes，并不要求 UTF-8。该入口在 contracts
    /// 边界验证原始长度，再用标准 `String::from_utf8_lossy` 完整投影；因此 99 个非法
    /// bytes 产生的 297-byte 展示字符串仍是合法链事实。普通字符串构造器继续执行
    /// 99 UTF-8 bytes 上限，不能借此放宽 pending/call 业务输入。
    #[allow(clippy::too_many_arguments)]
    pub fn try_for_tracked_account_from_runtime_event(
        tracked_account_id: AccountId32,
        from_account_id: AccountId32,
        to_account_id: AccountId32,
        amount_fen: u128,
        block: crate::FinalizedBlockRef,
        event_record_index: u32,
        extrinsic_index: Option<u32>,
        source_pallet: impl Into<String>,
        remark_bytes: Option<&[u8]>,
    ) -> ContractResult<Self> {
        if remark_bytes.is_some_and(|bytes| bytes.len() > crate::MAX_TRANSFER_REMARK_BYTES) {
            return Err(ContractError::new(
                ContractErrorCode::Integrity,
                "链上 transfer_with_remark 原始备注超过 Runtime 上限",
            ));
        }
        let remark = remark_bytes.map(|bytes| String::from_utf8_lossy(bytes).into_owned());
        if remark
            .as_ref()
            .is_some_and(|value| value.len() > MAX_FINALIZED_REMARK_DISPLAY_BYTES)
        {
            return Err(ContractError::new(
                ContractErrorCode::Integrity,
                "finalized 备注 lossy 展示超过可证明的最坏上限",
            ));
        }
        Self::try_for_tracked_account_inner(
            tracked_account_id,
            from_account_id,
            to_account_id,
            amount_fen,
            block,
            event_record_index,
            extrinsic_index,
            source_pallet.into(),
            remark,
            remark_bytes.map(|bytes| bytes.to_vec()),
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn try_for_tracked_account_inner(
        tracked_account_id: AccountId32,
        from_account_id: AccountId32,
        to_account_id: AccountId32,
        amount_fen: u128,
        block: crate::FinalizedBlockRef,
        event_record_index: u32,
        extrinsic_index: Option<u32>,
        source_pallet: String,
        remark: Option<String>,
        remark_bytes: Option<Vec<u8>>,
    ) -> ContractResult<Self> {
        if amount_fen == 0 {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "finalized 转账金额必须大于 0 分",
            ));
        }
        if from_account_id == to_account_id {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "finalized 资金流水不接受自转账事件",
            ));
        }
        if tracked_account_id != from_account_id && tracked_account_id != to_account_id {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "tracked account 必须是转账事件的发送方或接收方",
            ));
        }
        match source_pallet.as_str() {
            "Balances" if remark.is_some() => {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "Balances.Transfer 不得携带 remark",
                ));
            }
            "OnchainTransaction" if remark.is_none() || extrinsic_index.is_none() => {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "OnchainTransaction.transfer_with_remark 必须携带 remark 和 extrinsic index",
                ));
            }
            "Balances" | "OnchainTransaction" => {}
            _ => {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "finalized 转账来源只能是 Balances 或 OnchainTransaction",
                ));
            }
        }
        if remark_bytes
            .as_ref()
            .is_some_and(|bytes| bytes.len() > crate::MAX_TRANSFER_REMARK_BYTES)
        {
            return Err(ContractError::new(
                ContractErrorCode::Integrity,
                "链上 transfer_with_remark 原始备注超过 Runtime 上限",
            ));
        }
        if remark.is_some() != remark_bytes.is_some()
            || remark
                .as_deref()
                .zip(remark_bytes.as_deref())
                .is_some_and(|(projected, raw)| String::from_utf8_lossy(raw).as_ref() != projected)
        {
            return Err(ContractError::new(
                ContractErrorCode::Integrity,
                "finalized 备注展示与 Runtime 原始 bytes 不一致",
            ));
        }
        Ok(Self {
            tracked_account_id,
            incoming: tracked_account_id == to_account_id,
            from_account_id,
            to_account_id,
            amount_fen,
            block,
            event_record_index,
            extrinsic_index,
            source_pallet,
            remark,
            remark_bytes,
        })
    }

    pub const fn tracked_account_id(&self) -> AccountId32 {
        self.tracked_account_id
    }

    pub fn is_incoming(&self) -> bool {
        self.incoming
    }

    pub fn is_outgoing(&self) -> bool {
        !self.incoming
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

    /// 返回 finalized Runtime 原始备注 bytes；持久化适配必须保存它以便无损重建。
    pub fn remark_bytes(&self) -> Option<&[u8]> {
        self.remark_bytes.as_deref()
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
            .map(|transfer| {
                (
                    transfer.tracked_account_id(),
                    transfer.block().hash(),
                    transfer.event_record_index(),
                )
            })
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
