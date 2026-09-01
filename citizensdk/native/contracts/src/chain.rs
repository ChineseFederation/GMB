//! 带验证语义的 CitizenChain 客户端合同。

use std::fmt;

use crate::{
    ContractError, ContractErrorCode, ContractFuture, ContractResult, ContractStream,
    ExtrinsicWatchEvent, SignedExtrinsic, SubmittedExtrinsic,
};

/// 32 字节链哈希。区块哈希、genesis hash 和 extrinsic hash 共享字节宽度，调用处仍须
/// 通过字段名保持业务语义，不允许从可变长度文本猜测。
#[derive(Clone, Copy, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct Hash32([u8; 32]);

impl Hash32 {
    pub const fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub const fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub const fn into_bytes(self) -> [u8; 32] {
        self.0
    }
}

impl fmt::Debug for Hash32 {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.debug_tuple("Hash32").field(&self.0).finish()
    }
}

/// CitizenChain AccountId32；与字符串形式的 SS58 展示地址分离。
#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct AccountId32([u8; 32]);

impl AccountId32 {
    pub const fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub const fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub const fn into_bytes(self) -> [u8; 32] {
        self.0
    }
}

/// provider 已核对出的块语义；不能把 best 口头当成 finalized。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum BlockFinality {
    Best,
    Finalized,
}

/// 带哈希、高度和验证语义的准确块引用。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct VerifiedBlockRef {
    hash: Hash32,
    number: u64,
    finality: BlockFinality,
}

impl VerifiedBlockRef {
    pub const fn best(hash: Hash32, number: u64) -> Self {
        Self {
            hash,
            number,
            finality: BlockFinality::Best,
        }
    }

    pub const fn finalized(hash: Hash32, number: u64) -> Self {
        Self {
            hash,
            number,
            finality: BlockFinality::Finalized,
        }
    }

    pub const fn hash(&self) -> Hash32 {
        self.hash
    }

    pub const fn number(&self) -> u64 {
        self.number
    }

    pub const fn finality(&self) -> BlockFinality {
        self.finality
    }

    pub const fn is_finalized(&self) -> bool {
        matches!(self.finality, BlockFinality::Finalized)
    }

    pub fn require_finalized(self) -> ContractResult<FinalizedBlockRef> {
        FinalizedBlockRef::try_from(self)
    }
}

/// 编译期强制 finalized-only 调用不能接收 best 块。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct FinalizedBlockRef(VerifiedBlockRef);

impl FinalizedBlockRef {
    pub const fn from_parts(hash: Hash32, number: u64) -> Self {
        Self(VerifiedBlockRef::finalized(hash, number))
    }

    pub const fn verified(self) -> VerifiedBlockRef {
        self.0
    }

    pub const fn hash(self) -> Hash32 {
        self.0.hash()
    }

    pub const fn number(self) -> u64 {
        self.0.number()
    }
}

impl TryFrom<VerifiedBlockRef> for FinalizedBlockRef {
    type Error = ContractError;

    fn try_from(value: VerifiedBlockRef) -> Result<Self, Self::Error> {
        if value.is_finalized() {
            Ok(Self(value))
        } else {
            Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "finalized-only 操作拒绝 best 块引用",
            ))
        }
    }
}

impl From<FinalizedBlockRef> for VerifiedBlockRef {
    fn from(value: FinalizedBlockRef) -> Self {
        value.verified()
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RuntimeVersion {
    spec_version: u32,
    transaction_version: u32,
}

impl RuntimeVersion {
    pub const fn new(spec_version: u32, transaction_version: u32) -> Self {
        Self {
            spec_version,
            transaction_version,
        }
    }

    pub const fn spec_version(self) -> u32 {
        self.spec_version
    }

    pub const fn transaction_version(self) -> u32 {
        self.transaction_version
    }
}

/// 同一准确块上的 runtime version 与完整 SCALE metadata。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RuntimeContext {
    block: VerifiedBlockRef,
    version: RuntimeVersion,
    metadata: Vec<u8>,
}

impl RuntimeContext {
    pub fn try_new(
        block: VerifiedBlockRef,
        version: RuntimeVersion,
        metadata: Vec<u8>,
    ) -> ContractResult<Self> {
        if metadata.is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "runtime metadata 不能为空",
            ));
        }
        Ok(Self {
            block,
            version,
            metadata,
        })
    }

    pub const fn block(&self) -> VerifiedBlockRef {
        self.block
    }

    pub const fn version(&self) -> RuntimeVersion {
        self.version
    }

    pub fn metadata(&self) -> &[u8] {
        &self.metadata
    }
}

/// 一条链的不可混淆身份。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ChainIdentity {
    chain_id: String,
    protocol_id: String,
    genesis_hash: Hash32,
}

impl ChainIdentity {
    pub fn try_new(
        chain_id: impl Into<String>,
        protocol_id: impl Into<String>,
        genesis_hash: Hash32,
    ) -> ContractResult<Self> {
        let chain_id = chain_id.into();
        let protocol_id = protocol_id.into();
        if chain_id.trim().is_empty() || protocol_id.trim().is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "chain_id 与 protocol_id 不能为空",
            ));
        }
        Ok(Self {
            chain_id,
            protocol_id,
            genesis_hash,
        })
    }

    pub fn chain_id(&self) -> &str {
        &self.chain_id
    }

    pub fn protocol_id(&self) -> &str {
        &self.protocol_id
    }

    pub const fn genesis_hash(&self) -> Hash32 {
        self.genesis_hash
    }
}

/// provider 导出的轻节点数据库信封；只含公开链状态，不含钱包或秘密。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ExportedChainState {
    identity: ChainIdentity,
    format_version: u32,
    finalized: FinalizedBlockRef,
    database: Vec<u8>,
}

impl ExportedChainState {
    pub fn try_new(
        identity: ChainIdentity,
        format_version: u32,
        finalized: FinalizedBlockRef,
        database: Vec<u8>,
    ) -> ContractResult<Self> {
        if format_version == 0 || database.is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "链状态格式版本和数据库正文必须有效",
            ));
        }
        Ok(Self {
            identity,
            format_version,
            finalized,
            database,
        })
    }

    pub const fn format_version(&self) -> u32 {
        self.format_version
    }

    pub fn identity(&self) -> &ChainIdentity {
        &self.identity
    }

    pub const fn finalized(&self) -> FinalizedBlockRef {
        self.finalized
    }

    pub fn database(&self) -> &[u8] {
        &self.database
    }

    pub fn into_database(self) -> Vec<u8> {
        self.database
    }
}

/// provider 接受导入后的回执；Engine 仍须在调用前独立完成全部门禁。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct StateImportReceipt {
    finalized: FinalizedBlockRef,
}

impl StateImportReceipt {
    pub const fn new(finalized: FinalizedBlockRef) -> Self {
        Self { finalized }
    }

    pub const fn finalized(self) -> FinalizedBlockRef {
        self.finalized
    }
}

/// 经过验证语义收口的链客户端；不得增加任意 JSON-RPC 公共入口。
pub trait VerifiedChainClient: Send + Sync {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity>;

    fn get_best_head(&self) -> ContractFuture<'_, VerifiedBlockRef>;

    fn get_finalized_head(&self) -> ContractFuture<'_, FinalizedBlockRef>;

    fn get_storage_at(
        &self,
        block: VerifiedBlockRef,
        key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>>;

    fn get_storage_batch_at(
        &self,
        block: VerifiedBlockRef,
        keys: Vec<Vec<u8>>,
    ) -> ContractFuture<'_, Vec<Option<Vec<u8>>>>;

    fn get_runtime_context_at(
        &self,
        block: VerifiedBlockRef,
    ) -> ContractFuture<'_, RuntimeContext>;

    /// 读取目标块完整 extrinsic 字节，供 Engine 按完整哈希定位准确 index。
    fn get_block_extrinsics_at(
        &self,
        block: VerifiedBlockRef,
    ) -> ContractFuture<'_, Vec<Vec<u8>>>;

    /// 节点接收只返回提交事实，不代表入块、finalized 或 runtime 执行成功。
    fn submit_extrinsic(
        &self,
        extrinsic: SignedExtrinsic,
    ) -> ContractFuture<'_, SubmittedExtrinsic>;

    /// watch 事件的块锚必须携带 provider 已核对的 `VerifiedBlockRef`。
    fn watch_extrinsic(
        &self,
        extrinsic: SignedExtrinsic,
    ) -> ContractStream<'_, ExtrinsicWatchEvent>;

    fn export_state(&self) -> ContractFuture<'_, ExportedChainState>;

    /// 只允许在 provider 启动前调用。Engine 仍须先核对身份、格式、finalized 与非倒退。
    fn import_state(
        &self,
        state: ExportedChainState,
    ) -> ContractFuture<'_, StateImportReceipt>;
}

