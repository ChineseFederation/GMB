//! 无秘密钱包公开事实的原子仓储。

use crate::{ContractFuture, WalletState};

/// 只保存 `WalletState`；助记词、母种子、mini-secret、私钥和签名均不属于该类型。
pub trait WalletProfileStore: Send + Sync {
    fn load(&self) -> ContractFuture<'_, WalletState>;

    /// `next.revision` 必须等于 `expected_revision + 1`，并以底层原子 CAS 提交。
    /// 写后异常必须完整回读：等于候选状态才收敛为成功，否则报告冲突/存储错误。
    fn compare_and_swap(
        &self,
        expected_revision: u64,
        next: WalletState,
    ) -> ContractFuture<'_, WalletState>;
}
