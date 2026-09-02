//! 不含助记词、母种子、mini-secret 或私钥的钱包公开状态模型。

use std::collections::{BTreeSet, HashSet};

use blake2::{Blake2b512, Digest};

use crate::{
    AccountId32, ContractError, ContractErrorCode, ContractResult, SecretRef, VaultGeneration,
};

/// 与当前已验证热钱包一致的最大硬派生账户 index。
pub const MAX_WALLET_ACCOUNT_INDEX: u32 = 1989;
/// 当前已验证公民链热钱包只有一只无根钱包，固定使用 wallet index 0。
pub const CITIZEN_WALLET_INDEX: u32 = 0;
/// CitizenChain Runtime 与现有稳定 Dart 钱包共同使用的 SS58 prefix。
pub const CITIZEN_SS58_PREFIX: u16 = 2027;
/// 本机账户名称最多包含 30 个 Unicode scalar，与现有 Dart `runes.length` 一致。
pub const MAX_WALLET_ACCOUNT_NAME_SCALARS: usize = 30;

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
        let normalized_name = name.trim();
        if secret_ref.account_id() != account_id || ss58_address != citizen_ss58_address(account_id)
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "钱包账户、秘密引用和 SS58 展示地址不一致",
            ));
        }
        if normalized_name.is_empty()
            || normalized_name.chars().count() > MAX_WALLET_ACCOUNT_NAME_SCALARS
            || normalized_name.chars().any(|character| {
                character <= '\u{001f}' || ('\u{007f}'..='\u{009f}').contains(&character)
            })
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "账户名称修剪后必须包含 1..30 个 Unicode scalar 且不得含控制字符",
            ));
        }
        Ok(Self {
            index,
            account_id,
            secret_ref,
            ss58_address,
            name: normalized_name.to_owned(),
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

    /// 重建只改变本机展示名称的账户事实；账户、秘密引用和创建时间保持逐字节不变。
    pub fn try_with_name(&self, name: impl Into<String>) -> ContractResult<Self> {
        Self::try_new(
            self.index,
            self.account_id,
            self.secret_ref,
            self.ss58_address.clone(),
            name,
            self.created_at_millis,
        )
    }
}

/// 由 AccountId32 生成唯一规范的 CitizenChain SS58 展示地址。
pub fn citizen_ss58_address(account_id: AccountId32) -> String {
    let prefix = CITIZEN_SS58_PREFIX;
    let mut payload = Vec::with_capacity(36);
    payload.push(((prefix & 0b0000_0000_1111_1100) as u8) >> 2 | 0b0100_0000);
    payload.push(((prefix >> 8) as u8) | ((prefix & 0b11) as u8) << 6);
    payload.extend_from_slice(account_id.as_bytes());

    let mut hasher = Blake2b512::new();
    hasher.update(b"SS58PRE");
    hasher.update(&payload);
    let checksum = hasher.finalize();
    payload.extend_from_slice(&checksum[..2]);
    bs58::encode(payload).into_string()
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
        if wallet_index != CITIZEN_WALLET_INDEX || accounts.is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "公民链热钱包必须使用 wallet index 0 且至少包含一个账户",
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
        let account_zero_matches_master = accounts
            .iter()
            .any(|account| account.index() == 0 && account.account_id() == master_account_id);
        if !account_zero_matches_master
            || accounts
                .iter()
                .any(|account| account.index() > MAX_WALLET_ACCOUNT_INDEX)
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "账户0必须是 masterAccountId，且账户 index 不得超过 1989",
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
        let secret_owners: HashSet<_> = accounts
            .iter()
            .map(|account| account.secret_ref().owner())
            .collect();
        if secret_owners.len() != accounts.len()
            || accounts
                .iter()
                .any(|account| account.secret_ref().owner().as_bytes() == generation.as_bytes())
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "账户秘密 owner 必须唯一且不得复用钱包 generation",
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

    pub fn account_by_id(&self, account_id: AccountId32) -> Option<&WalletAccount> {
        self.accounts
            .iter()
            .find(|account| account.account_id() == account_id)
    }

    pub fn account_by_index(&self, index: u32) -> Option<&WalletAccount> {
        self.accounts
            .iter()
            .find(|account| account.index() == index)
    }

    /// 只切换当前账户；其它 profile 字段和账户顺序保持不变。
    pub fn try_with_active_account(&self, active_account_id: AccountId32) -> ContractResult<Self> {
        Self::try_new(
            self.wallet_index,
            self.generation,
            self.master_account_id,
            self.origin,
            self.created_at_millis,
            active_account_id,
            self.accounts.clone(),
        )
    }

    /// 只重命名一个已存在账户，不触碰任何秘密或链上身份。
    pub fn try_with_account_name(
        &self,
        account_id: AccountId32,
        name: impl Into<String>,
    ) -> ContractResult<Self> {
        let Some(position) = self
            .accounts
            .iter()
            .position(|account| account.account_id() == account_id)
        else {
            return Err(ContractError::new(
                ContractErrorCode::NotFound,
                "未找到待重命名的钱包账户",
            ));
        };
        let mut accounts = self.accounts.clone();
        accounts[position] = accounts[position].try_with_name(name)?;
        Self::try_new(
            self.wallet_index,
            self.generation,
            self.master_account_id,
            self.origin,
            self.created_at_millis,
            self.active_account_id,
            accounts,
        )
    }

    /// 生成删除一个非锚点账户后的公开 profile，并返回被移除账户供 Engine 建立 exact cleanup。
    ///
    /// 账户0只能通过整钱包删除路径移除；若删除当前账户，active 自动回到账户0锚点。
    pub fn try_without_child_account(
        &self,
        account_id: AccountId32,
    ) -> ContractResult<(Self, WalletAccount)> {
        let Some(position) = self
            .accounts
            .iter()
            .position(|account| account.account_id() == account_id)
        else {
            return Err(ContractError::new(
                ContractErrorCode::NotFound,
                "未找到待删除的钱包账户",
            ));
        };
        if self.accounts[position].index() == 0 {
            return Err(ContractError::new(
                ContractErrorCode::InvalidState,
                "账户0是钱包锚点，只能通过整钱包删除路径移除",
            ));
        }
        let mut accounts = self.accounts.clone();
        let removed = accounts.remove(position);
        let active_account_id = if self.active_account_id == account_id {
            self.master_account_id
        } else {
            self.active_account_id
        };
        let next = Self::try_new(
            self.wallet_index,
            self.generation,
            self.master_account_id,
            self.origin,
            self.created_at_millis,
            active_account_id,
            accounts,
        )?;
        Ok((next, removed))
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
        if wallet_index != CITIZEN_WALLET_INDEX
            || secret_refs.is_empty()
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
        if wallet_index != CITIZEN_WALLET_INDEX
            || secret_refs.is_empty()
            || unique_refs.len() != secret_refs.len()
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

    pub fn try_from_parts(
        revision: u64,
        profile: Option<WalletProfile>,
        provisioning: Option<WalletProvisioningPlan>,
        cleanup: Option<WalletCleanupPlan>,
        cleanup_queue: Vec<WalletCleanupPlan>,
    ) -> ContractResult<Self> {
        if cleanup_queue.len() > 64 {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "cleanup queue 不得超过 64 项",
            ));
        }
        if provisioning.is_some() && cleanup.is_some() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "provisioning 与 cleanup 不能同时取得钱包操作所有权",
            ));
        }

        let mut wallet_indices = BTreeSet::new();
        if let Some(profile) = profile.as_ref() {
            wallet_indices.insert(profile.wallet_index());
        }
        if let Some(plan) = provisioning.as_ref() {
            wallet_indices.insert(plan.wallet_index());
            let Some(target) = profile.as_ref() else {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "provisioning 必须携带本次操作的目标公开事实",
                ));
            };
            if plan.wallet_index() != target.wallet_index()
                || plan.generation() != target.generation()
            {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "provisioning 必须属于目标钱包生命周期",
                ));
            }
            match plan.previous_profile() {
                None => {
                    let target_refs: HashSet<_> = target
                        .accounts()
                        .iter()
                        .map(WalletAccount::secret_ref)
                        .collect();
                    let planned_refs: HashSet<_> = plan.secret_refs().iter().copied().collect();
                    if !plan.delete_wallet_key_on_rollback() || planned_refs != target_refs {
                        return Err(ContractError::new(
                            ContractErrorCode::InvalidArgument,
                            "新钱包 provisioning 必须拥有全部目标秘密并在回滚时删除钱包密钥",
                        ));
                    }
                }
                Some(previous) => {
                    if plan.delete_wallet_key_on_rollback()
                        || !profile_is_exact_subset(previous, target)
                    {
                        return Err(ContractError::new(
                            ContractErrorCode::InvalidArgument,
                            "追加账户 provisioning 的前态必须是目标 profile 的严格前缀",
                        ));
                    }
                    let previous_owners: HashSet<_> = previous
                        .accounts()
                        .iter()
                        .map(|account| account.secret_ref().owner())
                        .collect();
                    let added_refs: HashSet<_> = target
                        .accounts()
                        .iter()
                        .filter(|account| !previous_owners.contains(&account.secret_ref().owner()))
                        .map(WalletAccount::secret_ref)
                        .collect();
                    let planned_refs: HashSet<_> = plan.secret_refs().iter().copied().collect();
                    if planned_refs != added_refs {
                        return Err(ContractError::new(
                            ContractErrorCode::InvalidArgument,
                            "追加账户 provisioning 必须精确拥有新增账户秘密",
                        ));
                    }
                }
            }
        }
        if let Some(plan) = cleanup.as_ref() {
            wallet_indices.insert(plan.wallet_index());
            if profile.is_none() && !plan.delete_wallet_key() {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "整钱包删除计划必须清理钱包硬件密钥",
                ));
            }
            if profile
                .as_ref()
                .is_some_and(|profile| !cleanup_can_coexist_with_profile(plan, profile))
            {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "活动 cleanup 不得指向现存公开账户或钱包密钥",
                ));
            }
        }
        for plan in &cleanup_queue {
            wallet_indices.insert(plan.wallet_index());
        }
        if wallet_indices.len() > 1 {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "一个 WalletState 不得混合不同 wallet index",
            ));
        }

        let mut operation_ids = HashSet::new();
        let mut accepted_cleanup = Vec::new();
        if let Some(plan) = provisioning.as_ref() {
            operation_ids.insert(*plan.operation_id());
        }
        if let Some(plan) = cleanup.as_ref() {
            if !operation_ids.insert(*plan.operation_id()) {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "钱包操作所有权标识不得重复",
                ));
            }
            accepted_cleanup.push(plan);
        }
        for plan in &cleanup_queue {
            if !operation_ids.insert(*plan.operation_id()) {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "钱包在途操作与补偿队列的 operation id 必须唯一",
                ));
            }
            if profile
                .as_ref()
                .is_some_and(|profile| !cleanup_can_coexist_with_profile(plan, profile))
            {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "cleanup queue 不得指向现存公开账户或钱包密钥",
                ));
            }
            if accepted_cleanup
                .iter()
                .any(|accepted| cleanup_plans_overlap(accepted, plan))
            {
                return Err(ContractError::new(
                    ContractErrorCode::InvalidArgument,
                    "cleanup 计划不得重复拥有相同物理清理目标",
                ));
            }
            accepted_cleanup.push(plan);
        }

        Ok(Self {
            revision,
            profile,
            provisioning,
            cleanup,
            cleanup_queue,
        })
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

/// 与已验证 Dart 钱包一致：追加账户只能在列表尾部扩展，既有 profile 字段与账户逐项不变。
fn profile_is_exact_subset(previous: &WalletProfile, target: &WalletProfile) -> bool {
    previous.wallet_index() == target.wallet_index()
        && previous.generation() == target.generation()
        && previous.master_account_id() == target.master_account_id()
        && previous.origin() == target.origin()
        && previous.created_at_millis() == target.created_at_millis()
        && previous.active_account_id() == target.active_account_id()
        && previous.accounts().len() < target.accounts().len()
        && previous
            .accounts()
            .iter()
            .zip(target.accounts())
            .all(|(left, right)| left == right)
}

fn cleanup_can_coexist_with_profile(cleanup: &WalletCleanupPlan, profile: &WalletProfile) -> bool {
    if cleanup.delete_wallet_key() && cleanup.generation() == profile.generation() {
        return false;
    }
    cleanup.secret_refs().iter().all(|secret_ref| {
        !profile.accounts().iter().any(|account| {
            secret_ref.generation() == profile.generation()
                && secret_ref.owner() == account.secret_ref().owner()
                && secret_ref.account_id() == account.account_id()
        })
    })
}

fn cleanup_plans_overlap(left: &WalletCleanupPlan, right: &WalletCleanupPlan) -> bool {
    if left == right || left.operation_id() == right.operation_id() {
        return true;
    }
    if left.delete_wallet_key()
        && right.delete_wallet_key()
        && left.generation() == right.generation()
    {
        return true;
    }
    let left_refs: HashSet<_> = left.secret_refs().iter().copied().collect();
    right
        .secret_refs()
        .iter()
        .any(|secret_ref| left_refs.contains(secret_ref))
}
