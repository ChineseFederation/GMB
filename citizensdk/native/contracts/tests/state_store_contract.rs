//! 五类数据仓储的强类型、对象安全和钱包公开状态合同。

use std::{
    future::Future,
    task::{Context, Poll, Waker},
};

use citizen_sdk_contracts::{
    AccountId32, ChainDatabaseSnapshot, ChainDatabaseStore, ContractFuture, ContractResult,
    EncryptedSecretBlobSnapshot, EncryptedSecretBlobStore, FinalizedBlockRef,
    FinalizedTransferRecord, Hash32, RuntimeCacheStore, RuntimeContext, RuntimeVersion,
    SecretOwner, SecretRef, TransactionHistoryState, TransactionHistoryStore, VaultGeneration,
    VerifiedBlockRef, WalletAccount, WalletCleanupPlan, WalletOrigin, WalletProfile,
    WalletProfileStore, WalletProvisioningPlan, WalletState,
};

fn block_on<F: Future>(future: F) -> F::Output {
    let waker = Waker::noop();
    let mut context = Context::from_waker(waker);
    let mut future = std::pin::pin!(future);
    loop {
        match future.as_mut().poll(&mut context) {
            Poll::Ready(output) => return output,
            Poll::Pending => std::thread::yield_now(),
        }
    }
}

fn value_or_panic<T>(result: ContractResult<T>) -> T {
    match result {
        Ok(value) => value,
        Err(error) => panic!("合同调用失败: {error}"),
    }
}

struct MemoryChainDatabase;

impl ChainDatabaseStore for MemoryChainDatabase {
    fn load(&self) -> ContractFuture<'_, ChainDatabaseSnapshot> {
        Box::pin(async { Ok(ChainDatabaseSnapshot::new(0, None)) })
    }

    fn compare_and_swap(
        &self,
        expected_revision: u64,
        state: Option<citizen_sdk_contracts::ExportedChainState>,
    ) -> ContractFuture<'_, ChainDatabaseSnapshot> {
        Box::pin(async move { Ok(ChainDatabaseSnapshot::new(expected_revision + 1, state)) })
    }
}

struct MemoryRuntimeCache;

impl RuntimeCacheStore for MemoryRuntimeCache {
    fn load(&self, _block_hash: Hash32) -> ContractFuture<'_, Option<RuntimeContext>> {
        Box::pin(async { Ok(None) })
    }

    fn store(&self, _context: RuntimeContext) -> ContractFuture<'_, ()> {
        Box::pin(async { Ok(()) })
    }

    fn delete(&self, _block_hash: Hash32) -> ContractFuture<'_, ()> {
        Box::pin(async { Ok(()) })
    }
}

struct MemoryWalletProfiles;

impl WalletProfileStore for MemoryWalletProfiles {
    fn load(&self) -> ContractFuture<'_, WalletState> {
        Box::pin(async { Ok(WalletState::empty()) })
    }

    fn compare_and_swap(
        &self,
        _expected_revision: u64,
        next: WalletState,
    ) -> ContractFuture<'_, WalletState> {
        Box::pin(async move { Ok(next) })
    }
}

struct MemoryHistory;

impl TransactionHistoryStore for MemoryHistory {
    fn load(&self) -> ContractFuture<'_, TransactionHistoryState> {
        Box::pin(async { TransactionHistoryState::try_new(0, Vec::new(), Vec::new(), Vec::new()) })
    }

    fn compare_and_swap(
        &self,
        _expected_revision: u64,
        next: TransactionHistoryState,
    ) -> ContractFuture<'_, TransactionHistoryState> {
        Box::pin(async move { Ok(next) })
    }
}

struct MemoryEncryptedBlobs;

impl EncryptedSecretBlobStore for MemoryEncryptedBlobs {
    fn load(&self, _secret_ref: SecretRef) -> ContractFuture<'_, EncryptedSecretBlobSnapshot> {
        Box::pin(async { Ok(EncryptedSecretBlobSnapshot::new(0, None)) })
    }

    fn compare_and_swap(
        &self,
        _secret_ref: SecretRef,
        expected_revision: u64,
        envelope: Option<citizen_sdk_contracts::EncryptedSecretEnvelope>,
    ) -> ContractFuture<'_, EncryptedSecretBlobSnapshot> {
        Box::pin(async move {
            Ok(EncryptedSecretBlobSnapshot::new(
                expected_revision + 1,
                envelope,
            ))
        })
    }
}

fn secret_ref(index: u32, account_byte: u8) -> SecretRef {
    SecretRef::account_mini_secret(
        7,
        VaultGeneration::from_bytes([1; 16]),
        SecretOwner::from_bytes([index as u8; 16]),
        AccountId32::from_bytes([account_byte; 32]),
    )
}

#[test]
fn five_store_traits_are_separate_object_safe_boundaries() {
    let chain: Box<dyn ChainDatabaseStore> = Box::new(MemoryChainDatabase);
    let runtime: Box<dyn RuntimeCacheStore> = Box::new(MemoryRuntimeCache);
    let wallet: Box<dyn WalletProfileStore> = Box::new(MemoryWalletProfiles);
    let history: Box<dyn TransactionHistoryStore> = Box::new(MemoryHistory);
    let blobs: Box<dyn EncryptedSecretBlobStore> = Box::new(MemoryEncryptedBlobs);

    assert_eq!(value_or_panic(block_on(chain.load())).revision(), 0);
    assert!(value_or_panic(block_on(runtime.load(Hash32::from_bytes([2; 32])))).is_none());
    assert_eq!(value_or_panic(block_on(wallet.load())).revision(), 0);
    assert_eq!(value_or_panic(block_on(history.load())).revision(), 0);
    assert!(value_or_panic(block_on(blobs.load(secret_ref(3, 4))))
        .envelope()
        .is_none());
}

#[test]
fn wallet_profile_rejects_duplicate_or_cross_generation_secret_refs() {
    let generation = VaultGeneration::from_bytes([1; 16]);
    let first_id = AccountId32::from_bytes([4; 32]);
    let first = value_or_panic(WalletAccount::try_new(
        0,
        first_id,
        secret_ref(1, 4),
        "5CitizenFirst",
        "first",
        100,
    ));
    let duplicate_index = value_or_panic(WalletAccount::try_new(
        0,
        AccountId32::from_bytes([5; 32]),
        secret_ref(2, 5),
        "5CitizenSecond",
        "second",
        101,
    ));
    assert!(WalletProfile::try_new(
        7,
        generation,
        first_id,
        WalletOrigin::Created,
        100,
        first_id,
        vec![first.clone(), duplicate_index],
    )
    .is_err());

    let foreign_ref = SecretRef::account_mini_secret(
        8,
        generation,
        SecretOwner::from_bytes([3; 16]),
        AccountId32::from_bytes([6; 32]),
    );
    let foreign = value_or_panic(WalletAccount::try_new(
        1,
        AccountId32::from_bytes([6; 32]),
        foreign_ref,
        "5CitizenForeign",
        "foreign",
        102,
    ));
    assert!(WalletProfile::try_new(
        7,
        generation,
        first_id,
        WalletOrigin::Created,
        100,
        first_id,
        vec![first.clone(), foreign],
    )
    .is_err());

    let foreign_generation_ref = SecretRef::account_mini_secret(
        7,
        VaultGeneration::from_bytes([2; 16]),
        SecretOwner::from_bytes([4; 16]),
        AccountId32::from_bytes([7; 32]),
    );
    let foreign_generation = value_or_panic(WalletAccount::try_new(
        1,
        AccountId32::from_bytes([7; 32]),
        foreign_generation_ref,
        "5CitizenGeneration",
        "generation",
        103,
    ));
    assert!(WalletProfile::try_new(
        7,
        generation,
        first_id,
        WalletOrigin::Created,
        100,
        first_id,
        vec![first, foreign_generation],
    )
    .is_err());
}

#[test]
fn wallet_profile_requires_account_zero_master_and_bounded_indices() {
    let generation = VaultGeneration::from_bytes([1; 16]);
    let master = AccountId32::from_bytes([4; 32]);
    let wrong_anchor = value_or_panic(WalletAccount::try_new(
        1,
        master,
        secret_ref(1, 4),
        "5CitizenMaster",
        "master",
        100,
    ));
    assert!(WalletProfile::try_new(
        7,
        generation,
        master,
        WalletOrigin::Created,
        100,
        master,
        vec![wrong_anchor],
    )
    .is_err());

    let wrong_zero_id = AccountId32::from_bytes([5; 32]);
    let wrong_zero = value_or_panic(WalletAccount::try_new(
        0,
        wrong_zero_id,
        secret_ref(2, 5),
        "5CitizenWrongZero",
        "wrong-zero",
        100,
    ));
    assert!(WalletProfile::try_new(
        7,
        generation,
        master,
        WalletOrigin::Created,
        100,
        wrong_zero_id,
        vec![wrong_zero],
    )
    .is_err());

    let valid_zero = value_or_panic(WalletAccount::try_new(
        0,
        master,
        secret_ref(3, 4),
        "5CitizenMaster",
        "master",
        100,
    ));
    let maximum_id = AccountId32::from_bytes([6; 32]);
    let maximum = value_or_panic(WalletAccount::try_new(
        1989,
        maximum_id,
        secret_ref(4, 6),
        "5CitizenMaximum",
        "maximum",
        101,
    ));
    assert!(WalletProfile::try_new(
        7,
        generation,
        master,
        WalletOrigin::Created,
        100,
        maximum_id,
        vec![valid_zero.clone(), maximum],
    )
    .is_ok());

    let too_high = value_or_panic(WalletAccount::try_new(
        1990,
        maximum_id,
        secret_ref(5, 6),
        "5CitizenTooHigh",
        "too-high",
        100,
    ));
    assert!(WalletProfile::try_new(
        7,
        generation,
        master,
        WalletOrigin::Created,
        100,
        master,
        vec![valid_zero, too_high],
    )
    .is_err());
}

#[test]
fn wallet_state_rejects_conflicting_ownership_and_cross_wallet_cleanup() {
    let generation = VaultGeneration::from_bytes([1; 16]);
    let master = AccountId32::from_bytes([4; 32]);
    let account = value_or_panic(WalletAccount::try_new(
        0,
        master,
        secret_ref(1, 4),
        "5CitizenMaster",
        "master",
        100,
    ));
    let profile = value_or_panic(WalletProfile::try_new(
        7,
        generation,
        master,
        WalletOrigin::Created,
        100,
        master,
        vec![account],
    ));
    let next_generation = VaultGeneration::from_bytes([2; 16]);
    let next_secret = SecretRef::account_mini_secret(
        7,
        next_generation,
        SecretOwner::from_bytes([8; 16]),
        AccountId32::from_bytes([8; 32]),
    );
    let provisioning = value_or_panic(WalletProvisioningPlan::try_new(
        [1; 16],
        7,
        next_generation,
        Some(profile.clone()),
        vec![next_secret],
        true,
    ));
    let cleanup = value_or_panic(WalletCleanupPlan::try_new(
        [2; 16],
        7,
        generation,
        vec![secret_ref(1, 4)],
        true,
    ));
    assert!(WalletState::try_from_parts(
        1,
        Some(profile.clone()),
        Some(provisioning.clone()),
        Some(cleanup.clone()),
        Vec::new(),
    )
    .is_err());

    let wrong_previous = value_or_panic(WalletProvisioningPlan::try_new(
        [3; 16],
        7,
        next_generation,
        None,
        vec![next_secret],
        true,
    ));
    assert!(WalletState::try_from_parts(
        1,
        Some(profile.clone()),
        Some(wrong_previous),
        None,
        Vec::new(),
    )
    .is_err());

    let foreign_cleanup = value_or_panic(WalletCleanupPlan::try_new(
        [4; 16],
        8,
        generation,
        Vec::new(),
        true,
    ));
    assert!(WalletState::try_from_parts(
        1,
        Some(profile.clone()),
        None,
        None,
        vec![foreign_cleanup],
    )
    .is_err());

    let duplicate_operation = value_or_panic(WalletCleanupPlan::try_new(
        [2; 16],
        7,
        VaultGeneration::from_bytes([3; 16]),
        Vec::new(),
        true,
    ));
    assert!(WalletState::try_from_parts(
        1,
        Some(profile.clone()),
        None,
        Some(cleanup),
        vec![duplicate_operation],
    )
    .is_err());

    assert!(WalletState::try_from_parts(
        1,
        Some(profile),
        Some(provisioning),
        None,
        Vec::new(),
    )
    .is_ok());
}

#[test]
fn runtime_cache_value_carries_its_exact_block_identity() {
    let block = VerifiedBlockRef::finalized(Hash32::from_bytes([9; 32]), 88);
    let context = value_or_panic(RuntimeContext::try_new(
        block,
        RuntimeVersion::new(17, 3),
        vec![1, 2, 3],
    ));
    assert_eq!(context.block(), block);
    assert_eq!(context.version().spec_version(), 17);
}

#[test]
fn finalized_transfer_history_rejects_zero_amount_and_duplicate_event_identity() {
    let block = FinalizedBlockRef::from_parts(Hash32::from_bytes([7; 32]), 55);
    assert!(FinalizedTransferRecord::try_new(
        AccountId32::from_bytes([1; 32]),
        AccountId32::from_bytes([2; 32]),
        0,
        block,
        3,
        Some(0),
        "Balances",
        None,
    )
    .is_err());

    let transfer = value_or_panic(FinalizedTransferRecord::try_new(
        AccountId32::from_bytes([1; 32]),
        AccountId32::from_bytes([2; 32]),
        100,
        block,
        3,
        Some(0),
        "Balances",
        None,
    ));
    assert!(TransactionHistoryState::try_new(
        1,
        Vec::new(),
        Vec::new(),
        vec![transfer.clone(), transfer],
    )
    .is_err());
}
