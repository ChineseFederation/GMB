//! 准确块身份绑定的 runtime metadata cache。

use crate::{ContractFuture, Hash32, RuntimeContext};

/// Runtime cache 只能按准确块哈希命中，不能只按 specVersion 猜测块身份。
pub trait RuntimeCacheStore: Send + Sync {
    fn load(&self, block_hash: Hash32) -> ContractFuture<'_, Option<RuntimeContext>>;

    /// 写入的 context 自带同块 runtime version、transaction version 与 metadata。
    fn store(&self, context: RuntimeContext) -> ContractFuture<'_, ()>;

    fn delete(&self, block_hash: Hash32) -> ContractFuture<'_, ()>;
}
