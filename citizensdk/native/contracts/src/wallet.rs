//! 不含助记词、母种子、mini-secret 或私钥的钱包公开状态模型。

use std::collections::{BTreeSet, HashSet};

use crate::{
    AccountId32, ContractError, ContractErrorCode, ContractResult, SecretRef, VaultGeneration,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WalletOrigin {
    Created,
    Imported,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WalletAccount {
    index: u32,
    account_id: AccountId32,
    secret_ref: SecretRef,
    ss58_address: String,
    name: String,
    created_at_millis: u64,
}

impl WalletAccount {
    pub fn try_new(
        index: u32,
        account_id: AccountId32,
        secret_ref: SecretRef,
        ss58_address: impl Into<String>,
        name: impl Into<String>,
        created_at_millis: u64,
    ) -> ContractResult<Self> {
        let ss58_address = ss58_address.into();
        let name = name.into();
        if secret_ref.account_id() != account_id || ss58_address.trim().is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "钱包账户、秘密引用和 SS58 展示地址不一致",
            ));
        }
        Ok(Self {
            index,
            account_id,
            secret_ref,
            ss58_address,
            name,
            created_at_millis,
        })
    }

    pub const fn index(&self) -> u32 {
        self.index
    }

    pub const fn account_id(&self) -> AccountId32 {
        self.account_id
    }

    pub const fn secret_ref(&self) -> SecretRef {
        self.secret_ref
    }

    pub fn ss58_address(&self) -> &str {
        &self.ss58_address
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub const fn created_at_millis(&self) -> u64 {
        self.created_at_millis
    }
}

/// 单只无根热钱包的公开资料。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WalletProfile {
    wallet_index: u32,
    generation: VaultGeneration,
    master_account_id: AccountId32,
    origin: WalletOrigin,
    created_at_millis: u64,
    active_account_id: AccountId32,
    accounts: Vec<WalletAccount>,
}

impl WalletProfile {
    #[allow(clippy::too_many_arguments)]
    pub fn try_new(
        wallet_index: u32,
        generation: VaultGeneration,
        master_account_id: AccountId32,
        origin: WalletOrigin,
        created_at_millis: u64,
        active_account_id: AccountId32,
        accounts: Vec<WalletAccount>,
    ) -> ContractResult<Self> {
        if accounts.is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "钱包至少需要一个账户",
            ));
        }
        let indices: BTreeSet<_> = accounts.iter().map(WalletAccount::index).collect();
        let account_ids: BTreeSet<_> = accounts.iter().map(WalletAccount::account_id).collect();
        if indices.len() != accounts.len() || account_ids.len() != accounts.len() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "钱包账户 index 与 AccountId 必须唯一",
            ));
        }
        if !account_ids.contains(&active_account_id)
            || accounts.iter().any(|account| {
                account.secret_ref().wallet_index() != wallet_index
                    || account.secret_ref().generation() != generation
            })
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "active account 或秘密引用不属于当前钱包生命周期",
            ));
        }
        Ok(Self {
            wallet_index,
            generation,
            master_account_id,
            origin,
            created_at_millis,
            active_account_id,
            accounts,
        })
    }

    pub const fn wallet_index(&self) -> u32 {
        self.wallet_index
    }

    pub const fn generation(&self) -> VaultGeneration {
        self.generation
    }

    pub const fn master_account_id(&self) -> AccountId32 {
        self.master_account_id
    }

    pub const fn origin(&self) -> WalletOrigin {
        self.origin
    }

    pub const fn created_at_millis(&self) -> u64 {
        self.created_at_millis
    }

    pub const fn active_account_id(&self) -> AccountId32 {
        self.active_account_id
    }

    pub fn accounts(&self) -> &[WalletAccount] {
        &self.accounts
    }
}

/// 秘密写入前必须先以 CAS 持久化的操作所有权。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WalletProvisioningPlan {
    operation_id: [u8; 16],
    wallet_index: u32,
    generation: VaultGeneration,
    previous_profile: Option<WalletProfile>,
    secret_refs: Vec<SecretRef>,
    delete_wallet_key_on_rollback: bool,
}

impl WalletProvisioningPlan {
    pub fn try_new(
        operation_id: [u8; 16],
        wallet_index: u32,
        generation: VaultGeneration,
        previous_profile: Option<WalletProfile>,
        secret_refs: Vec<SecretRef>,
        delete_wallet_key_on_rollback: bool,
    ) -> ContractResult<Self> {
        let unique_refs: HashSet<_> = secret_refs.iter().copied().collect();
        if secret_refs.is_empty()
            || unique_refs.len() != secret_refs.len()
            || secret_refs.iter().any(|secret_ref| {
                secret_ref.wallet_index() != wallet_index || secret_ref.generation() != generation
            })
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "provisioning 计划必须精确拥有当前钱包生命周期的秘密集合",
            ));
        }
        Ok(Self {
            operation_id,
            wallet_index,
            generation,
            previous_profile,
            secret_refs,
            delete_wallet_key_on_rollback,
        })
    }

    pub const fn operation_id(&self) -> &[u8; 16] {
        &self.operation_id
    }

    pub const fn wallet_index(&self) -> u32 {
        self.wallet_index
    }

    pub const fn generation(&self) -> VaultGeneration {
        self.generation
    }

    pub fn previous_profile(&self) -> Option<&WalletProfile> {
        self.previous_profile.as_ref()
    }

    pub fn secret_refs(&self) -> &[SecretRef] {
        &self.secret_refs
    }

    pub const fn delete_wallet_key_on_rollback(&self) -> bool {
        self.delete_wallet_key_on_rollback
    }
}

/// 已提交公开事实后仍需幂等完成的精确补偿计划。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WalletCleanupPlan {
    operation_id: [u8; 16],
    wallet_index: u32,
    generation: VaultGeneration,
    secret_refs: Vec<SecretRef>,
    delete_wallet_key: bool,
}

impl WalletCleanupPlan {
    pub fn try_new(
        operation_id: [u8; 16],
        wallet_index: u32,
        generation: VaultGeneration,
        secret_refs: Vec<SecretRef>,
        delete_wallet_key: bool,
    ) -> ContractResult<Self> {
        let unique_refs: HashSet<_> = secret_refs.iter().copied().collect();
        if unique_refs.len() != secret_refs.len()
            || secret_refs.iter().any(|secret_ref| {
                secret_ref.wallet_index() != wallet_index || secret_ref.generation() != generation
            })
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "cleanup 计划不得命中其它钱包生命周期",
            ));
        }
        Ok(Self {
            operation_id,
            wallet_index,
            generation,
            secret_refs,
            delete_wallet_key,
        })
    }

    pub const fn operation_id(&self) -> &[u8; 16] {
        &self.operation_id
    }

    pub const fn wallet_index(&self) -> u32 {
        self.wallet_index
    }

    pub const fn generation(&self) -> VaultGeneration {
        self.generation
    }

    pub fn secret_refs(&self) -> &[SecretRef] {
        &self.secret_refs
    }

    pub const fn delete_wallet_key(&self) -> bool {
        self.delete_wallet_key
    }
}

/// 钱包公开事实、在途所有权和补偿队列的一次原子快照。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WalletState {
    revision: u64,
    profile: Option<WalletProfile>,
    provisioning: Option<WalletProvisioningPlan>,
    cleanup: Option<WalletCleanupPlan>,
    cleanup_queue: Vec<WalletCleanupPlan>,
}

impl WalletState {
    pub const fn empty() -> Self {
        Self {
            revision: 0,
            profile: None,
            provisioning: None,
            cleanup: None,
            cleanup_queue: Vec::new(),
        }
    }

    pub fn from_parts(
        revision: u64,
        profile: Option<WalletProfile>,
        provisioning: Option<WalletProvisioningPlan>,
        cleanup: Option<WalletCleanupPlan>,
        cleanup_queue: Vec<WalletCleanupPlan>,
    ) -> Self {
        Self {
            revision,
            profile,
            provisioning,
            cleanup,
            cleanup_queue,
        }
    }

    pub const fn revision(&self) -> u64 {
        self.revision
    }

    pub fn profile(&self) -> Option<&WalletProfile> {
        self.profile.as_ref()
    }

    pub fn provisioning(&self) -> Option<&WalletProvisioningPlan> {
        self.provisioning.as_ref()
    }

    pub fn cleanup(&self) -> Option<&WalletCleanupPlan> {
        self.cleanup.as_ref()
    }

    pub fn cleanup_queue(&self) -> &[WalletCleanupPlan] {
        &self.cleanup_queue
    }
}
