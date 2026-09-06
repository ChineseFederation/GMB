//! Typed account, wallet and finalized-history projection for CitizenSDK ABI v1.
//!
//! Secret inputs are copied synchronously into Rust-owned zeroizing containers
//! before an asynchronous request is accepted. The only secret output is the
//! one-time recovery phrase owned by a prepared-wallet handle; no mini-secret,
//! private key, vault plaintext or standalone signed extrinsic crosses this
//! boundary.

use std::{
    collections::HashMap,
    future::Future,
    ptr,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc, Mutex, MutexGuard, OnceLock,
    },
};

use citizen_sdk_contracts::{
    AccountId32, ExecutionConclusion, ExtrinsicWatchEvent, FinalizedTransferRecord,
    HistoryTransactionStatus, SecretBuffer, TransactionHistoryRecord, TransactionHistoryState,
    WalletAccount, WalletOrigin, WalletProfile,
};
use citizen_sdk_engine::{
    BestFeeSnapshot, EngineError, PreparedWalletCreation, WalletTransferCancellation,
    WalletTransferObserver, WalletTransferResolution, WalletTransferWatchResult,
    WalletTransferWatchStage, WalletTransferWatchUpdate, WalletWordCount,
};
use futures_util::FutureExt;
use zeroize::Zeroizing;

use crate::{
    abi::*,
    accept_and_write, accept_and_write_watch, assets, block_to_abi, copy_to_host, copy_view,
    error::{FfiError, FfiResult},
    execution_to_abi, ffi_status, handles, optional_utf8,
    ownership::{self, ResultPayload},
    read_versioned,
    requests::RequestCancellation,
    require_output,
    runtime::NativeRuntime,
    validate_output_versioned, wrong_result, MAX_ABI_INPUT_BYTES,
};

const MAX_WALLET_SECRET_INPUT_BYTES: usize = 1024;
const MAX_WALLET_NAME_BYTES: usize = 1024;
const MAX_TRANSFER_REMARK_BYTES: usize = citizen_sdk_contracts::MAX_TRANSFER_REMARK_BYTES;
const MAX_ACCOUNT_BATCH: usize = citizen_sdk_contracts::MAX_WALLET_ACCOUNT_INDEX as usize + 1;

/// 把 Engine 已经持久化或核验后的高层钱包阶段投影到 ABI v1 既有的
/// `WATCH_UPDATE` 结果。`Pending` 尚无对应的 v1 watch 状态，`Interrupted`
/// 也不能伪装成链状态，所以二者只保留在持久历史/终态错误中，不发失真事件。
fn wallet_transfer_watch_event(stage: &WalletTransferWatchStage) -> Option<ExtrinsicWatchEvent> {
    match stage {
        WalletTransferWatchStage::Pending | WalletTransferWatchStage::Interrupted { .. } => None,
        WalletTransferWatchStage::Ready => Some(ExtrinsicWatchEvent::Ready),
        WalletTransferWatchStage::Broadcast { peer_count } => {
            Some(ExtrinsicWatchEvent::Broadcast {
                peer_count: *peer_count,
            })
        }
        WalletTransferWatchStage::Future => Some(ExtrinsicWatchEvent::Future),
        WalletTransferWatchStage::InBlock { block } => {
            Some(ExtrinsicWatchEvent::InBlock { block: *block })
        }
        WalletTransferWatchStage::Retracted { block } => {
            Some(ExtrinsicWatchEvent::Retracted { block: *block })
        }
        WalletTransferWatchStage::FinalityTimeout { block } => {
            Some(ExtrinsicWatchEvent::FinalityTimeout { block: *block })
        }
        WalletTransferWatchStage::Dropped => Some(ExtrinsicWatchEvent::Dropped),
        WalletTransferWatchStage::Finalized { conclusion } => {
            let block = match conclusion {
                ExecutionConclusion::Success { block, .. }
                | ExecutionConclusion::Failed { block, .. } => (*block).try_into().ok(),
                ExecutionConclusion::Unverified { block, .. } => {
                    block.and_then(|value| value.try_into().ok())
                }
            }?;
            Some(ExtrinsicWatchEvent::Finalized { block })
        }
        // ABI v1 已有 Invalid 和 Usurped；必须根据 Engine 保留的原始拒绝事实
        // 原样投影，不得丢失替代交易哈希。
        WalletTransferWatchStage::PoolRejected {
            replacement_hash: Some(replacement_hash),
            ..
        } => Some(ExtrinsicWatchEvent::Usurped {
            replacement_hash: *replacement_hash,
        }),
        WalletTransferWatchStage::PoolRejected {
            replacement_hash: None,
            ..
        } => Some(ExtrinsicWatchEvent::Invalid),
    }
}

struct AbiWalletTransferObserver {
    runtime: Arc<NativeRuntime>,
    request_id: CitizenSdkRequestId,
}

impl WalletTransferObserver for AbiWalletTransferObserver {
    fn on_update(&self, update: WalletTransferWatchUpdate) {
        let Some(event) = wallet_transfer_watch_event(update.stage()) else {
            return;
        };
        // 观察器属于展示边界。队列关闭/满不能回滚已经持久化的交易事实，
        // NativeRuntime 会在投递失败时回收刚创建的 result handle。
        let _ = self.runtime.publish_watch_update(self.request_id, event);
    }
}

struct PreparedWalletEntry {
    owner: CitizenSdkHandle,
    prepared: PreparedWalletCreation,
}

enum PreparedWalletSlot {
    Available(PreparedWalletEntry),
    Claimed { owner: CitizenSdkHandle },
}

struct PreparedWalletClaim {
    handle: CitizenSdkPreparedWalletHandle,
    owner: CitizenSdkHandle,
    prepared: Option<PreparedWalletCreation>,
    consumed: bool,
}

impl PreparedWalletClaim {
    fn consume(mut self) -> FfiResult<PreparedWalletCreation> {
        let mut registry = lock_prepared_wallets()?;
        match registry.remove(&self.handle) {
            Some(PreparedWalletSlot::Claimed { owner }) if owner == self.owner => {}
            Some(slot) => {
                registry.insert(self.handle, slot);
                return Err(FfiError::internal(
                    "prepared wallet claim changed before request execution",
                ));
            }
            None => {
                return Err(FfiError::new(
                    CitizenSdkErrorCode::InvalidHandle,
                    "prepared wallet was released before request execution",
                ));
            }
        }
        self.consumed = true;
        self.prepared
            .take()
            .ok_or_else(|| FfiError::internal("prepared wallet claim is empty"))
    }
}

impl Drop for PreparedWalletClaim {
    fn drop(&mut self) {
        if self.consumed {
            return;
        }
        let Some(prepared) = self.prepared.take() else {
            return;
        };
        let mut registry = prepared_wallets()
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if matches!(
            registry.get(&self.handle),
            Some(PreparedWalletSlot::Claimed { owner }) if *owner == self.owner
        ) {
            registry.insert(
                self.handle,
                PreparedWalletSlot::Available(PreparedWalletEntry {
                    owner: self.owner,
                    prepared,
                }),
            );
        }
        // If teardown already removed the marker, dropping `prepared` here
        // zeroizes the recovery phrase instead of resurrecting a dead handle.
    }
}

static NEXT_PREPARED_WALLET: AtomicU64 = AtomicU64::new(1);
static PREPARED_WALLETS: OnceLock<
    Mutex<HashMap<CitizenSdkPreparedWalletHandle, PreparedWalletSlot>>,
> = OnceLock::new();

fn prepared_wallets() -> &'static Mutex<HashMap<CitizenSdkPreparedWalletHandle, PreparedWalletSlot>>
{
    PREPARED_WALLETS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn lock_prepared_wallets(
) -> FfiResult<MutexGuard<'static, HashMap<CitizenSdkPreparedWalletHandle, PreparedWalletSlot>>> {
    prepared_wallets()
        .lock()
        .map_err(|_| FfiError::internal("prepared wallet registry is poisoned"))
}

fn next_prepared_wallet_handle() -> FfiResult<CitizenSdkPreparedWalletHandle> {
    NEXT_PREPARED_WALLET
        .fetch_update(Ordering::SeqCst, Ordering::SeqCst, |value| {
            value.checked_add(1).filter(|next| *next != 0)
        })
        .map_err(|_| FfiError::internal("prepared wallet handle space is exhausted"))
}

fn insert_prepared_wallet(
    owner: CitizenSdkHandle,
    prepared: PreparedWalletCreation,
) -> FfiResult<CitizenSdkPreparedWalletHandle> {
    let handle = next_prepared_wallet_handle()?;
    let replaced = lock_prepared_wallets()?.insert(
        handle,
        PreparedWalletSlot::Available(PreparedWalletEntry { owner, prepared }),
    );
    if replaced.is_some() {
        return Err(FfiError::internal(
            "monotonic prepared wallet handle collided with an existing slot",
        ));
    }
    Ok(handle)
}

fn claim_prepared_wallet(
    handle: CitizenSdkPreparedWalletHandle,
    owner: CitizenSdkHandle,
) -> FfiResult<PreparedWalletClaim> {
    if handle == 0 {
        return Err(FfiError::new(
            CitizenSdkErrorCode::InvalidHandle,
            "prepared wallet handle 0 is invalid",
        ));
    }
    let mut registry = lock_prepared_wallets()?;
    let slot = registry.remove(&handle).ok_or_else(|| {
        FfiError::new(
            CitizenSdkErrorCode::InvalidHandle,
            "prepared wallet is unknown or already consumed",
        )
    })?;
    match slot {
        PreparedWalletSlot::Available(entry) if entry.owner == owner => {
            registry.insert(handle, PreparedWalletSlot::Claimed { owner });
            Ok(PreparedWalletClaim {
                handle,
                owner,
                prepared: Some(entry.prepared),
                consumed: false,
            })
        }
        PreparedWalletSlot::Available(entry) => {
            registry.insert(handle, PreparedWalletSlot::Available(entry));
            Err(FfiError::new(
                CitizenSdkErrorCode::InvalidHandle,
                "prepared wallet belongs to another CitizenSDK instance",
            ))
        }
        PreparedWalletSlot::Claimed { owner: actual } => {
            registry.insert(handle, PreparedWalletSlot::Claimed { owner: actual });
            require_prepared_owner(actual, owner)?;
            Err(FfiError::new(
                CitizenSdkErrorCode::Busy,
                "prepared wallet is already being committed",
            ))
        }
    }
}

/// Teardown hook used by `NativeRuntime`: all uncommitted recovery phrases for
/// this instance are dropped and zeroized. A claimed entry can only coexist
/// with an outstanding request, which the existing destroy preflight rejects.
pub(crate) fn drop_prepared_for_owner(owner: CitizenSdkHandle) {
    let mut registry = prepared_wallets()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    registry.retain(|_, slot| match slot {
        PreparedWalletSlot::Available(entry) => entry.owner != owner,
        PreparedWalletSlot::Claimed { owner: entry_owner } => *entry_owner != owner,
    });
}

#[no_mangle]
/// Creates a host-composed instance after synchronously copying all vtables.
///
/// The public store is mandatory. Secure storage and the vault form one
/// all-or-none wallet bundle; hosts cannot inject a signer or nonce source.
///
/// # Safety
/// `options`, `host_services`, their pointed-to vtables, and `out_handle` must
/// remain readable/writable for this call. Copied callback contexts must stay
/// valid until successful instance destruction returns.
pub unsafe extern "C" fn citizensdk_create_with_host(
    options: *const CitizenSdkCreateOptions,
    host_services: *const CitizenSdkHostServicesV1,
    out_handle: *mut CitizenSdkHandle,
) -> i32 {
    ffi_status(|| {
        require_output(out_handle, "out_handle")?;
        let options = read_versioned(options, "create options")?;
        let host_services = read_versioned(host_services, "host services")?;
        let manifest = copy_view(
            options.asset_manifest,
            "asset_manifest",
            MAX_ABI_INPUT_BYTES,
        )?;
        let chain_spec = copy_view(options.chain_spec, "chain_spec", MAX_ABI_INPUT_BYTES)?;
        let light_state = copy_view(
            options.light_sync_state,
            "light_sync_state",
            MAX_ABI_INPUT_BYTES,
        )?;
        let system_name = optional_utf8(options.system_name, "system_name", "CitizenSDK")?;
        let system_version = optional_utf8(options.system_version, "system_version", "1.0.0")?;
        let verified = assets::verify_assets(&manifest, &chain_spec, &light_state)?;
        let handle = handles::reserve_handle()?;
        // SAFETY: `read_versioned` copied the top-level services value and
        // this exported function's caller contract guarantees that every
        // nested vtable pointer is readable for this call and its copied
        // callback context remains live through successful destroy.
        let runtime = unsafe {
            NativeRuntime::new_with_host(
                handle,
                verified.combined_chain_spec,
                system_name,
                system_version,
                &host_services,
            )
        }?;
        handles::insert(runtime)?;
        ptr::write(out_handle, handle);
        Ok(())
    })
}

#[no_mangle]
/// Reads one finalized CitizenChain account balance.
///
/// # Safety
/// `account_id` and `out_request_id` must be readable/writable respectively.
pub unsafe extern "C" fn citizensdk_get_finalized_account_balance(
    handle: CitizenSdkHandle,
    account_id: *const CitizenSdkAccountId,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let account_id = account_id_from_pointer(account_id, "account_id")?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let balance = runtime
                .provider()
                .drive(runtime.engine().finalized_account_balance(account_id))??;
            Ok(ResultPayload::AccountBalance(balance))
        })
    })
}

#[no_mangle]
/// Reads the exact-best Runtime nonce; this is not a transaction-pool lease.
///
/// # Safety
/// `account_id` and `out_request_id` must be readable/writable respectively.
pub unsafe extern "C" fn citizensdk_get_account_nonce(
    handle: CitizenSdkHandle,
    account_id: *const CitizenSdkAccountId,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let account_id = account_id_from_pointer(account_id, "account_id")?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let nonce = runtime
                .provider()
                .drive(runtime.engine().account_next_index(account_id))??;
            Ok(ResultPayload::AccountNonce(nonce))
        })
    })
}

#[no_mangle]
/// Reads one exact-best fee policy and existential deposit snapshot.
///
/// # Safety
/// `out_request_id` must be writable for one request identifier.
pub unsafe extern "C" fn citizensdk_get_best_fee_snapshot(
    handle: CitizenSdkHandle,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let snapshot = runtime
                .provider()
                .drive(runtime.engine().best_fee_snapshot())??;
            Ok(ResultPayload::FeeSnapshot(snapshot))
        })
    })
}

#[no_mangle]
/// 同步复用派生密码校验，不返回规范化密码，不创建持久化状态。
///
/// # Safety
/// `password` 在调用期间必须按声明长度可读。
pub unsafe extern "C" fn citizensdk_validate_wallet_password(password: CitizenSdkBytesView) -> i32 {
    ffi_status(|| {
        let password = secret_utf8(password, "wallet password", MAX_WALLET_SECRET_INPUT_BYTES)?;
        citizen_sdk_engine::validate_wallet_password(&password)?;
        Ok(())
    })
}

#[no_mangle]
/// 同步复用 English BIP-39 输入校验；错误不回显单词。
///
/// # Safety
/// `mnemonic` 在调用期间必须按声明长度可读。
pub unsafe extern "C" fn citizensdk_validate_wallet_mnemonic(
    mnemonic: CitizenSdkBytesView,
    word_count: u32,
) -> i32 {
    ffi_status(|| {
        let word_count = wallet_word_count(word_count)?;
        let mnemonic = secret_utf8(mnemonic, "wallet mnemonic", MAX_WALLET_SECRET_INPUT_BYTES)?;
        citizen_sdk_engine::validate_wallet_mnemonic(&mnemonic, word_count)?;
        Ok(())
    })
}

#[no_mangle]
/// 同步查询本地官方词表，最多六词，以 LF 分隔且无尾随 LF/NUL。
/// 容量不足时不部分写入；查询所需长度不要求提供输出缓冲区。
///
/// # Safety
/// `prefix` 必须可读；`out_required` 必须可写；非空输出缓冲按容量可写。
pub unsafe extern "C" fn citizensdk_wallet_word_suggestions(
    prefix: CitizenSdkBytesView,
    buffer: *mut u8,
    capacity: u64,
    out_required: *mut u64,
) -> i32 {
    ffi_status(|| {
        require_output(out_required, "out_required")?;
        ptr::write(out_required, 0);
        let prefix = secret_utf8(prefix, "wallet word prefix", MAX_WALLET_SECRET_INPUT_BYTES)?;
        let words = citizen_sdk_engine::wallet_word_suggestions(&prefix)?;
        copy_to_host(words.join("\n"), buffer, capacity, out_required)
    })
}

#[no_mangle]
/// Loads the current public wallet profile without exporting any secret.
///
/// # Safety
/// `out_request_id` must be writable for one request identifier.
pub unsafe extern "C" fn citizensdk_get_wallet_profile(
    handle: CitizenSdkHandle,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let profile = runtime
                .provider()
                .drive(runtime.engine().wallet_profile())??;
            Ok(ResultPayload::WalletProfile(profile))
        })
    })
}

#[no_mangle]
/// Creates a non-persistent, SDK-owned recovery-phrase session.
///
/// # Safety
/// `password` is borrowed only for this call and `out_request_id` is writable.
pub unsafe extern "C" fn citizensdk_prepare_wallet_creation(
    handle: CitizenSdkHandle,
    word_count: u32,
    password: CitizenSdkBytesView,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let word_count = wallet_word_count(word_count)?;
        let password = secret_utf8(password, "wallet password", MAX_WALLET_SECRET_INPUT_BYTES)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let prepared = runtime.provider().drive(
                runtime
                    .engine()
                    .prepare_wallet_creation(word_count, password),
            )??;
            let prepared_handle = insert_prepared_wallet(runtime.handle(), prepared)?;
            Ok(ResultPayload::PreparedWallet(prepared_handle))
        })
    })
}

#[no_mangle]
/// Copies or size-queries the recovery phrase while its prepared handle lives.
///
/// # Safety
/// Output pointers must satisfy the usual CitizenSDK copy-function contract.
pub unsafe extern "C" fn citizensdk_prepared_wallet_copy_mnemonic(
    handle: CitizenSdkHandle,
    prepared_wallet: CitizenSdkPreparedWalletHandle,
    buffer: *mut u8,
    capacity: u64,
    out_required: *mut u64,
) -> i32 {
    ffi_status(|| {
        let _runtime = handles::get(handle)?;
        let registry = lock_prepared_wallets()?;
        let slot = registry.get(&prepared_wallet).ok_or_else(|| {
            FfiError::new(
                CitizenSdkErrorCode::InvalidHandle,
                "prepared wallet is unknown or already released",
            )
        })?;
        match slot {
            PreparedWalletSlot::Available(entry) => {
                require_prepared_owner(entry.owner, handle)?;
                entry
                    .prepared
                    .with_mnemonic(|bytes| copy_to_host(bytes, buffer, capacity, out_required))
            }
            PreparedWalletSlot::Claimed { owner } => {
                require_prepared_owner(*owner, handle)?;
                Err(FfiError::new(
                    CitizenSdkErrorCode::Busy,
                    "prepared wallet is being committed",
                ))
            }
        }
    })
}

#[no_mangle]
/// Releases an uncommitted prepared wallet exactly once and zeroizes secrets.
pub extern "C" fn citizensdk_prepared_wallet_release(
    handle: CitizenSdkHandle,
    prepared_wallet: CitizenSdkPreparedWalletHandle,
) -> i32 {
    ffi_status(|| {
        let _runtime = handles::get(handle)?;
        let mut registry = lock_prepared_wallets()?;
        let slot = registry.remove(&prepared_wallet).ok_or_else(|| {
            FfiError::new(
                CitizenSdkErrorCode::InvalidHandle,
                "prepared wallet is unknown or already released",
            )
        })?;
        match slot {
            PreparedWalletSlot::Available(entry) if entry.owner == handle => Ok(()),
            PreparedWalletSlot::Available(entry) => {
                registry.insert(prepared_wallet, PreparedWalletSlot::Available(entry));
                Err(FfiError::new(
                    CitizenSdkErrorCode::InvalidHandle,
                    "prepared wallet belongs to another CitizenSDK instance",
                ))
            }
            PreparedWalletSlot::Claimed { owner } => {
                registry.insert(prepared_wallet, PreparedWalletSlot::Claimed { owner });
                require_prepared_owner(owner, handle)?;
                Err(FfiError::new(
                    CitizenSdkErrorCode::Busy,
                    "prepared wallet is being committed",
                ))
            }
        }
    })
}

fn require_prepared_owner(actual: CitizenSdkHandle, requested: CitizenSdkHandle) -> FfiResult<()> {
    if actual == requested {
        Ok(())
    } else {
        Err(FfiError::new(
            CitizenSdkErrorCode::InvalidHandle,
            "prepared wallet belongs to another CitizenSDK instance",
        ))
    }
}

#[no_mangle]
/// Consumes a prepared session after the user confirms recovery-phrase backup.
///
/// # Safety
/// `out_request_id` must be writable for one request identifier.
pub unsafe extern "C" fn citizensdk_commit_wallet_creation(
    handle: CitizenSdkHandle,
    prepared_wallet: CitizenSdkPreparedWalletHandle,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let claim = claim_prepared_wallet(prepared_wallet, handle)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            let prepared = claim.consume()?;
            runtime.refresh_provider_capabilities()?;
            let profile = runtime.provider().drive(
                runtime
                    .engine()
                    .commit_wallet_creation_after_backup(prepared),
            )??;
            Ok(ResultPayload::WalletProfile(Some(profile)))
        })
    })
}

#[no_mangle]
/// Imports a wallet from a borrowed recovery phrase and optional password.
///
/// # Safety
/// Secret views are borrowed only for this call; `out_request_id` is writable.
pub unsafe extern "C" fn citizensdk_import_wallet(
    handle: CitizenSdkHandle,
    mnemonic: CitizenSdkBytesView,
    password: CitizenSdkBytesView,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let mnemonic = secret_buffer(mnemonic, "wallet mnemonic", MAX_WALLET_SECRET_INPUT_BYTES)?;
        let password = secret_utf8(password, "wallet password", MAX_WALLET_SECRET_INPUT_BYTES)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let profile = runtime
                .provider()
                .drive(runtime.engine().import_wallet(mnemonic, password))??;
            Ok(ResultPayload::WalletProfile(Some(profile)))
        })
    })
}

#[no_mangle]
/// Derives and persists additional `//index` accounts for the current wallet.
///
/// # Safety
/// Secret/index inputs are borrowed only for this call; output is writable.
pub unsafe extern "C" fn citizensdk_add_wallet_accounts(
    handle: CitizenSdkHandle,
    mnemonic: CitizenSdkBytesView,
    password: CitizenSdkBytesView,
    indices: *const u32,
    index_count: u32,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let mnemonic = secret_buffer(mnemonic, "wallet mnemonic", MAX_WALLET_SECRET_INPUT_BYTES)?;
        let password = secret_utf8(password, "wallet password", MAX_WALLET_SECRET_INPUT_BYTES)?;
        let indices = copy_indices(indices, index_count)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let accounts = runtime.provider().drive(
                runtime
                    .engine()
                    .add_wallet_accounts(mnemonic, password, indices),
            )??;
            Ok(ResultPayload::WalletAccounts(accounts))
        })
    })
}

#[no_mangle]
/// Selects the active public wallet account.
///
/// # Safety
/// `account_id` and `out_request_id` must be readable/writable respectively.
pub unsafe extern "C" fn citizensdk_set_active_wallet_account(
    handle: CitizenSdkHandle,
    account_id: *const CitizenSdkAccountId,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    wallet_profile_mutation(handle, account_id, out_request_id, |engine, account_id| {
        engine.set_active_wallet_account(account_id)
    })
}

#[no_mangle]
/// Renames one public wallet account; the name is UTF-8 without a trailing NUL.
///
/// # Safety
/// Inputs are borrowed only for this call and `out_request_id` is writable.
pub unsafe extern "C" fn citizensdk_rename_wallet_account(
    handle: CitizenSdkHandle,
    account_id: *const CitizenSdkAccountId,
    name: CitizenSdkBytesView,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let account_id = account_id_from_pointer(account_id, "account_id")?;
        let name = utf8(name, "wallet account name", MAX_WALLET_NAME_BYTES)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let profile = runtime
                .provider()
                .drive(runtime.engine().rename_wallet_account(account_id, name))??;
            Ok(ResultPayload::WalletProfile(Some(profile)))
        })
    })
}

#[no_mangle]
/// Deletes one wallet account under the Engine's anchor-account rules.
///
/// # Safety
/// `account_id` and `out_request_id` must be readable/writable respectively.
pub unsafe extern "C" fn citizensdk_delete_wallet_account(
    handle: CitizenSdkHandle,
    account_id: *const CitizenSdkAccountId,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let account_id = account_id_from_pointer(account_id, "account_id")?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            runtime
                .provider()
                .drive(runtime.engine().delete_wallet_account(account_id))??;
            Ok(ResultPayload::Empty)
        })
    })
}

#[no_mangle]
/// Retires the entire wallet generation and all of its secret slots.
///
/// # Safety
/// `out_request_id` must be writable for one request identifier.
pub unsafe extern "C" fn citizensdk_delete_wallet(
    handle: CitizenSdkHandle,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            runtime
                .provider()
                .drive(runtime.engine().delete_wallet())??;
            Ok(ResultPayload::Empty)
        })
    })
}

#[no_mangle]
/// Completes durable cleanup plans left by an interrupted wallet operation.
///
/// # Safety
/// `out_request_id` must be writable for one request identifier.
pub unsafe extern "C" fn citizensdk_reconcile_wallet_cleanup(
    handle: CitizenSdkHandle,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            runtime
                .provider()
                .drive(runtime.engine().reconcile_wallet_cleanup())??;
            Ok(ResultPayload::Empty)
        })
    })
}

#[no_mangle]
/// Signs an application payload with the selected wallet account in Rust.
///
/// # Safety
/// Inputs are borrowed only for this call and `out_request_id` is writable.
pub unsafe extern "C" fn citizensdk_sign_wallet_payload(
    handle: CitizenSdkHandle,
    account_id: *const CitizenSdkAccountId,
    message: CitizenSdkBytesView,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let account_id = account_id_from_pointer(account_id, "account_id")?;
        let message = copy_view(message, "signing message", MAX_ABI_INPUT_BYTES)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let signature = runtime
                .provider()
                .drive(runtime.engine().sign_wallet_payload(account_id, message))??;
            Ok(ResultPayload::Signature(signature))
        })
    })
}

/// Drives the Engine's complete submit-and-watch future until a proven terminal
/// result, or cooperatively cancels and drains the accepted request. Cancellation
/// never drops the Engine future: an in-flight host store/CAS or vault operation
/// must really return before its lease and request completion are released.
/// This does not roll back a durable `Pending`/`InBlock` record.
/// 同参数再次调用 transfer 会核验并恢复原始授权字节，
/// 先同步 finalized 证据再决定是否重广播，不重新签名或更换 nonce。
async fn wallet_transfer_or_cancellation<F>(
    transfer: F,
    cancellation: RequestCancellation,
    transfer_cancellation: WalletTransferCancellation,
) -> FfiResult<WalletTransferWatchResult>
where
    F: Future<Output = Result<WalletTransferWatchResult, EngineError>>,
{
    let budget_token = transfer_cancellation.clone();
    wallet_transfer_or_cancellation_and_budget(
        transfer,
        cancellation,
        transfer_cancellation,
        wallet_transfer_budget(&budget_token),
    )
    .await
}

async fn wallet_transfer_or_cancellation_and_budget<F, B>(
    transfer: F,
    cancellation: RequestCancellation,
    transfer_cancellation: WalletTransferCancellation,
    budget: B,
) -> FfiResult<WalletTransferWatchResult>
where
    F: Future<Output = Result<WalletTransferWatchResult, EngineError>>,
    B: Future<Output = ()>,
{
    let transfer = transfer.fuse();
    let cancellation = cancellation.fuse();
    let budget = budget.fuse();
    futures_util::pin_mut!(transfer, cancellation, budget);
    futures_util::select_biased! {
        _ = cancellation => {
            transfer_cancellation.cancel();
            // Keep polling the same future, including an already-entered CAS. Its
            // generation/request guard stops further reads or broadcast after drain.
            let _ = transfer.await;
            Err(FfiError::new(
                CitizenSdkErrorCode::Cancelled,
                "wallet transfer watch was cancelled after draining; durable pending/in-block history was retained",
            ))
        },
        result = transfer => result.map_err(FfiError::from),
        _ = budget => {
            transfer_cancellation.cancel();
            let _ = transfer.await;
            Err(FfiError::new(CitizenSdkErrorCode::Timeout,
                "wallet transfer observation budget expired after draining; execution remains unverified and durable history was retained"))
        },
    }
}

/// 计时器只唤醒协调取消，不拥有 Engine future；阶段切换由 Engine 的真实 watch 事实驱动。
async fn wallet_transfer_budget(token: &WalletTransferCancellation) {
    loop {
        let remaining = token
            .remaining_budget()
            .unwrap_or(std::time::Duration::from_secs(1));
        if remaining.is_zero() {
            return;
        }
        tokio::time::sleep(remaining.min(std::time::Duration::from_secs(1))).await;
    }
}

#[no_mangle]
/// Builds, signs, records-before-broadcast, submits and verifies one transfer.
/// No signed extrinsic bytes are returned to the host. The complete terminal
/// watch uses the dedicated long-lived pool and may be cancelled without
/// clearing an already durable `Pending`/`InBlock` record. 已持久的完整授权与构造事实
/// 同次 CAS 写入；恢复不会把取消误作撤回，也不会从交易哈希重造另一笔转账。
///
/// # Safety
/// Account IDs/views are borrowed only for this call; output is writable.
pub unsafe extern "C" fn citizensdk_transfer_with_remark(
    handle: CitizenSdkHandle,
    source_account_id: *const CitizenSdkAccountId,
    destination_account_id: *const CitizenSdkAccountId,
    amount_fen: CitizenSdkU128,
    remark: CitizenSdkBytesView,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let source = account_id_from_pointer(source_account_id, "source_account_id")?;
        let destination =
            account_id_from_pointer(destination_account_id, "destination_account_id")?;
        let remark = utf8(remark, "transfer remark", MAX_TRANSFER_REMARK_BYTES)?;
        let amount_fen = u128_from_abi(amount_fen);
        accept_and_write_watch(
            runtime,
            out_request_id,
            move |runtime, request_id, cancellation| {
                runtime.refresh_provider_capabilities()?;
                let cancellation = cancellation.ok_or_else(|| {
                    FfiError::internal("wallet transfer cancellation channel is missing")
                })?;
                let observer: Arc<dyn WalletTransferObserver> =
                    Arc::new(AbiWalletTransferObserver {
                        runtime: Arc::clone(runtime),
                        request_id,
                    });
                let transfer_cancellation = WalletTransferCancellation::default();
                let transfer = runtime.provider().drive(wallet_transfer_or_cancellation(
                    runtime.engine().transfer_with_remark_and_watch(
                        source,
                        destination,
                        amount_fen,
                        remark,
                        observer,
                        transfer_cancellation.clone(),
                    ),
                    cancellation,
                    transfer_cancellation,
                ))??;
                Ok(ResultPayload::WalletTransfer(transfer))
            },
        )
    })
}

#[no_mangle]
/// Initializes tracked-account cursors at the current finalized head.
///
/// # Safety
/// `account_ids[0..account_count]` is readable and output is writable.
pub unsafe extern "C" fn citizensdk_initialize_finalized_history(
    handle: CitizenSdkHandle,
    account_ids: *const CitizenSdkAccountId,
    account_count: u32,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    history_request(
        handle,
        account_ids,
        account_count,
        out_request_id,
        |engine, accounts| engine.initialize_finalized_history(accounts),
    )
}

#[no_mangle]
/// Scans at most the Core's fixed 120-block finalized batch.
///
/// # Safety
/// `account_ids[0..account_count]` is readable and output is writable.
pub unsafe extern "C" fn citizensdk_sync_finalized_history_batch(
    handle: CitizenSdkHandle,
    account_ids: *const CitizenSdkAccountId,
    account_count: u32,
    out_request_id: *mut CitizenSdkRequestId,
) -> i32 {
    history_request(
        handle,
        account_ids,
        account_count,
        out_request_id,
        |engine, accounts| engine.sync_finalized_history_batch(accounts),
    )
}

#[no_mangle]
/// Copies one typed finalized-balance result.
///
/// # Safety
/// `out_info` must contain a supported ABI prefix and be writable.
pub unsafe extern "C" fn citizensdk_result_get_account_balance(
    result: CitizenSdkResultHandle,
    out_info: *mut CitizenSdkAccountBalanceInfo,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "account balance info")?;
        let owned = ownership::get(result)?;
        let ResultPayload::AccountBalance(balance) = owned.payload else {
            return Err(wrong_result("account balance"));
        };
        ptr::write(
            out_info,
            CitizenSdkAccountBalanceInfo {
                block: block_to_abi(balance.block().into()),
                account_id: account_id_to_abi(balance.account_id()),
                free_fen: u128_to_abi(balance.free_fen()),
                reserved_fen: u128_to_abi(balance.reserved_fen()),
                total_fen: u128_to_abi(balance.total_fen()),
                ..CitizenSdkAccountBalanceInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies one exact-best Runtime nonce result.
///
/// # Safety
/// `out_info` must contain a supported ABI prefix and be writable.
pub unsafe extern "C" fn citizensdk_result_get_account_nonce(
    result: CitizenSdkResultHandle,
    out_info: *mut CitizenSdkAccountNonceInfo,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "account nonce info")?;
        let owned = ownership::get(result)?;
        let ResultPayload::AccountNonce(nonce) = owned.payload else {
            return Err(wrong_result("account nonce"));
        };
        ptr::write(
            out_info,
            CitizenSdkAccountNonceInfo {
                best_block: block_to_abi(nonce.best_block()),
                account_id: account_id_to_abi(nonce.account_id()),
                nonce: nonce.value(),
                ..CitizenSdkAccountNonceInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies one exact-best fee-policy result.
///
/// # Safety
/// `out_info` must contain a supported ABI prefix and be writable.
pub unsafe extern "C" fn citizensdk_result_get_fee_snapshot(
    result: CitizenSdkResultHandle,
    out_info: *mut CitizenSdkFeeSnapshotInfo,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "fee snapshot info")?;
        let owned = ownership::get(result)?;
        let ResultPayload::FeeSnapshot(snapshot) = owned.payload else {
            return Err(wrong_result("fee snapshot"));
        };
        ptr::write(out_info, fee_snapshot_to_abi(snapshot));
        Ok(())
    })
}

#[no_mangle]
/// Applies the Core's exact Perbill rounding to a retained fee snapshot.
///
/// # Safety
/// Both output pointers must be writable for one `citizensdk_u128_t`.
pub unsafe extern "C" fn citizensdk_result_estimate_fee(
    result: CitizenSdkResultHandle,
    amount_fen: CitizenSdkU128,
    out_estimated_fee_fen: *mut CitizenSdkU128,
    out_minimum_self_pay_fen: *mut CitizenSdkU128,
) -> i32 {
    ffi_status(|| {
        require_output(out_estimated_fee_fen, "out_estimated_fee_fen")?;
        require_output(out_minimum_self_pay_fen, "out_minimum_self_pay_fen")?;
        let owned = ownership::get(result)?;
        let ResultPayload::FeeSnapshot(snapshot) = owned.payload else {
            return Err(wrong_result("fee snapshot"));
        };
        let estimated = snapshot.estimate_fee_fen(u128_from_abi(amount_fen))?;
        let minimum_self_pay = snapshot.minimum_self_pay_fen()?;
        ptr::write(out_estimated_fee_fen, u128_to_abi(estimated));
        ptr::write(out_minimum_self_pay_fen, u128_to_abi(minimum_self_pay));
        Ok(())
    })
}

#[no_mangle]
/// Copies the secret-free wallet profile descriptor; `present=0` is valid.
///
/// # Safety
/// `out_info` must contain a supported ABI prefix and be writable.
pub unsafe extern "C" fn citizensdk_result_get_wallet_profile(
    result: CitizenSdkResultHandle,
    out_info: *mut CitizenSdkWalletProfileInfo,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "wallet profile info")?;
        let owned = ownership::get(result)?;
        let ResultPayload::WalletProfile(profile) = owned.payload else {
            return Err(wrong_result("wallet profile"));
        };
        ptr::write(out_info, wallet_profile_to_abi(profile.as_ref())?);
        Ok(())
    })
}

#[no_mangle]
/// Returns account count for a profile or add-accounts result.
///
/// # Safety
/// `out_count` must be writable for one `u32`.
pub unsafe extern "C" fn citizensdk_result_get_wallet_account_count(
    result: CitizenSdkResultHandle,
    out_count: *mut u32,
) -> i32 {
    ffi_status(|| {
        require_output(out_count, "out_count")?;
        let owned = ownership::get(result)?;
        let (accounts, _) = wallet_accounts(&owned.payload)?;
        let count = u32::try_from(accounts.len())
            .map_err(|_| FfiError::internal("wallet account result is too large"))?;
        ptr::write(out_count, count);
        Ok(())
    })
}

#[no_mangle]
/// Copies one wallet account and size-queries/copies its two UTF-8 labels.
///
/// # Safety
/// Every output pointer follows the documented CitizenSDK copy contract.
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn citizensdk_result_get_wallet_account(
    result: CitizenSdkResultHandle,
    index: u32,
    out_info: *mut CitizenSdkWalletAccountInfo,
    ss58_buffer: *mut u8,
    ss58_capacity: u64,
    out_ss58_required: *mut u64,
    name_buffer: *mut u8,
    name_capacity: u64,
    out_name_required: *mut u64,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "wallet account info")?;
        let owned = ownership::get(result)?;
        let (accounts, active) = wallet_accounts(&owned.payload)?;
        let account = accounts
            .get(index as usize)
            .ok_or_else(|| FfiError::invalid("wallet account index is out of range"))?;
        copy_pair(
            account.ss58_address().as_bytes(),
            ss58_buffer,
            ss58_capacity,
            out_ss58_required,
            account.name().as_bytes(),
            name_buffer,
            name_capacity,
            out_name_required,
        )?;
        ptr::write(
            out_info,
            CitizenSdkWalletAccountInfo {
                index: account.index(),
                is_active: u32::from(active == Some(account.account_id())),
                account_id: account_id_to_abi(account.account_id()),
                created_at_millis: account.created_at_millis(),
                ss58_address_len: account.ss58_address().len() as u64,
                name_len: account.name().len() as u64,
                ..CitizenSdkWalletAccountInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies a 64-byte sr25519 signature; no signing secret is returned.
///
/// # Safety
/// `out_signature_64` must be writable for exactly 64 bytes.
pub unsafe extern "C" fn citizensdk_result_get_signature(
    result: CitizenSdkResultHandle,
    out_signature_64: *mut u8,
) -> i32 {
    ffi_status(|| {
        require_output(out_signature_64, "out_signature_64")?;
        let owned = ownership::get(result)?;
        let ResultPayload::Signature(signature) = owned.payload else {
            return Err(wrong_result("sr25519 signature"));
        };
        ptr::copy_nonoverlapping(signature.as_bytes().as_ptr(), out_signature_64, 64);
        Ok(())
    })
}

#[no_mangle]
/// Copies the independently-owned prepared handle from its completion result.
///
/// # Safety
/// `out_info` must contain a supported ABI prefix and be writable.
pub unsafe extern "C" fn citizensdk_result_get_prepared_wallet(
    result: CitizenSdkResultHandle,
    out_info: *mut CitizenSdkPreparedWalletInfo,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "prepared wallet info")?;
        let owned = ownership::get(result)?;
        let ResultPayload::PreparedWallet(prepared_wallet) = owned.payload else {
            return Err(wrong_result("prepared wallet"));
        };
        ptr::write(
            out_info,
            CitizenSdkPreparedWalletInfo {
                prepared_wallet,
                ..CitizenSdkPreparedWalletInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies a terminal high-level wallet transfer and optional pool reason.
///
/// # Safety
/// Every output pointer follows the documented CitizenSDK copy contract.
pub unsafe extern "C" fn citizensdk_result_get_wallet_transfer(
    result: CitizenSdkResultHandle,
    out_info: *mut CitizenSdkWalletTransferInfo,
    reason_buffer: *mut u8,
    reason_capacity: u64,
    out_reason_required: *mut u64,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "wallet transfer info")?;
        let owned = ownership::get(result)?;
        let ResultPayload::WalletTransfer(transfer) = owned.payload else {
            return Err(wrong_result("wallet transfer"));
        };
        let (resolution, execution, reason) = transfer_resolution(transfer.resolution())?;
        copy_to_host(
            reason.as_bytes(),
            reason_buffer,
            reason_capacity,
            out_reason_required,
        )?;
        ptr::write(
            out_info,
            CitizenSdkWalletTransferInfo {
                transaction_hash: transfer.transaction_hash().into_bytes(),
                resolution,
                has_execution: u32::from(execution.is_some()),
                execution: execution
                    .as_ref()
                    .map(execution_to_abi)
                    .unwrap_or_else(|| CitizenSdkWalletTransferInfo::default().execution),
                pool_rejection_reason_len: reason.len() as u64,
                ..CitizenSdkWalletTransferInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies summary counts for history or a wallet-transfer result's history.
///
/// # Safety
/// `out_info` must contain a supported ABI prefix and be writable.
pub unsafe extern "C" fn citizensdk_result_get_history_info(
    result: CitizenSdkResultHandle,
    out_info: *mut CitizenSdkHistoryInfo,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "history info")?;
        let owned = ownership::get(result)?;
        let history = history_state(&owned.payload)?;
        ptr::write(
            out_info,
            CitizenSdkHistoryInfo {
                revision: history.revision(),
                cursor_count: checked_count(history.cursors().len(), "history cursor")?,
                record_count: checked_count(history.records().len(), "history record")?,
                transfer_count: checked_count(history.transfers().len(), "history transfer")?,
                ..CitizenSdkHistoryInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies one finalized-history cursor.
///
/// # Safety
/// `out_info` must contain a supported ABI prefix and be writable.
pub unsafe extern "C" fn citizensdk_result_get_history_cursor(
    result: CitizenSdkResultHandle,
    index: u32,
    out_info: *mut CitizenSdkHistoryCursorInfo,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "history cursor info")?;
        let owned = ownership::get(result)?;
        let cursor = history_state(&owned.payload)?
            .cursors()
            .get(index as usize)
            .copied()
            .ok_or_else(|| FfiError::invalid("history cursor index is out of range"))?;
        ptr::write(
            out_info,
            CitizenSdkHistoryCursorInfo {
                account_id: account_id_to_abi(cursor.account_id()),
                tracking_start_block: block_to_abi(cursor.tracking_start_block().into()),
                last_synced_block: block_to_abi(cursor.last_synced_block().into()),
                ..CitizenSdkHistoryCursorInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies one pending/finalized submission record and its variable text.
///
/// # Safety
/// Every output pointer follows the documented CitizenSDK copy contract.
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn citizensdk_result_get_history_record(
    result: CitizenSdkResultHandle,
    index: u32,
    out_info: *mut CitizenSdkHistoryRecordInfo,
    remark_buffer: *mut u8,
    remark_capacity: u64,
    out_remark_required: *mut u64,
    reason_buffer: *mut u8,
    reason_capacity: u64,
    out_reason_required: *mut u64,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "history record info")?;
        let owned = ownership::get(result)?;
        let record = history_state(&owned.payload)?
            .records()
            .get(index as usize)
            .ok_or_else(|| FfiError::invalid("history record index is out of range"))?;
        let (status, block, execution, reason) = history_status(record)?;
        copy_pair(
            record.remark().as_bytes(),
            remark_buffer,
            remark_capacity,
            out_remark_required,
            reason.as_bytes(),
            reason_buffer,
            reason_capacity,
            out_reason_required,
        )?;
        ptr::write(
            out_info,
            CitizenSdkHistoryRecordInfo {
                account_id: account_id_to_abi(record.account_id()),
                transaction_hash: record.transaction_hash().into_bytes(),
                nonce: record.nonce(),
                destination_account_id: account_id_to_abi(record.destination_account_id()),
                amount_fen: u128_to_abi(record.amount_fen()),
                status,
                has_block: u32::from(block.is_some()),
                block: block
                    .map(block_to_abi)
                    .unwrap_or_else(CitizenSdkBlockRef::default),
                has_execution: u32::from(execution.is_some()),
                execution: execution
                    .as_ref()
                    .map(execution_to_abi)
                    .unwrap_or_else(|| CitizenSdkWalletTransferInfo::default().execution),
                created_at_millis: record.created_at_millis(),
                updated_at_millis: record.updated_at_millis(),
                remark_len: record.remark().len() as u64,
                pool_rejection_reason_len: reason.len() as u64,
                ..CitizenSdkHistoryRecordInfo::default()
            },
        );
        Ok(())
    })
}

#[no_mangle]
/// Copies one finalized transfer, preserving raw Runtime remark bytes.
///
/// # Safety
/// Every output pointer follows the documented CitizenSDK copy contract.
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn citizensdk_result_get_finalized_transfer(
    result: CitizenSdkResultHandle,
    index: u32,
    out_info: *mut CitizenSdkFinalizedTransferInfo,
    source_pallet_buffer: *mut u8,
    source_pallet_capacity: u64,
    out_source_pallet_required: *mut u64,
    remark_display_buffer: *mut u8,
    remark_display_capacity: u64,
    out_remark_display_required: *mut u64,
    remark_bytes_buffer: *mut u8,
    remark_bytes_capacity: u64,
    out_remark_bytes_required: *mut u64,
) -> i32 {
    ffi_status(|| {
        validate_output_versioned(out_info, "finalized transfer info")?;
        let owned = ownership::get(result)?;
        let transfer = history_state(&owned.payload)?
            .transfers()
            .get(index as usize)
            .ok_or_else(|| FfiError::invalid("finalized transfer index is out of range"))?;
        let display = transfer.remark().unwrap_or_default().as_bytes();
        let raw = transfer.remark_bytes().unwrap_or_default();
        copy_three(
            transfer.source_pallet().as_bytes(),
            source_pallet_buffer,
            source_pallet_capacity,
            out_source_pallet_required,
            display,
            remark_display_buffer,
            remark_display_capacity,
            out_remark_display_required,
            raw,
            remark_bytes_buffer,
            remark_bytes_capacity,
            out_remark_bytes_required,
        )?;
        ptr::write(out_info, finalized_transfer_to_abi(transfer));
        Ok(())
    })
}

unsafe fn wallet_profile_mutation<F>(
    handle: CitizenSdkHandle,
    account_id: *const CitizenSdkAccountId,
    out_request_id: *mut CitizenSdkRequestId,
    operation: F,
) -> i32
where
    F: for<'a> FnOnce(
            &'a citizen_sdk_engine::CitizenEngine,
            AccountId32,
        ) -> citizen_sdk_engine::EngineFuture<'a, WalletProfile>
        + Send
        + 'static,
{
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let account_id = account_id_from_pointer(account_id, "account_id")?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let profile = runtime
                .provider()
                .drive(operation(runtime.engine().as_ref(), account_id))??;
            Ok(ResultPayload::WalletProfile(Some(profile)))
        })
    })
}

unsafe fn history_request<F>(
    handle: CitizenSdkHandle,
    account_ids: *const CitizenSdkAccountId,
    account_count: u32,
    out_request_id: *mut CitizenSdkRequestId,
    operation: F,
) -> i32
where
    F: for<'a> FnOnce(
            &'a citizen_sdk_engine::CitizenEngine,
            Vec<AccountId32>,
        ) -> citizen_sdk_engine::EngineFuture<'a, TransactionHistoryState>
        + Send
        + 'static,
{
    ffi_status(|| {
        let runtime = handles::get(handle)?;
        let accounts = copy_account_ids(account_ids, account_count)?;
        accept_and_write(runtime, out_request_id, move |runtime, _, _| {
            runtime.refresh_provider_capabilities()?;
            let history = runtime
                .provider()
                .drive(operation(runtime.engine().as_ref(), accounts))??;
            Ok(ResultPayload::TransactionHistory(history))
        })
    })
}

unsafe fn account_id_from_pointer(
    pointer: *const CitizenSdkAccountId,
    name: &str,
) -> FfiResult<AccountId32> {
    if pointer.is_null() {
        return Err(FfiError::invalid(format!("{name} is null")));
    }
    Ok(AccountId32::from_bytes(ptr::read(pointer).bytes))
}

const fn account_id_to_abi(account_id: AccountId32) -> CitizenSdkAccountId {
    CitizenSdkAccountId {
        bytes: *account_id.as_bytes(),
    }
}

const fn u128_from_abi(value: CitizenSdkU128) -> u128 {
    (value.low as u128) | ((value.high as u128) << 64)
}

const fn u128_to_abi(value: u128) -> CitizenSdkU128 {
    CitizenSdkU128 {
        low: value as u64,
        high: (value >> 64) as u64,
    }
}

fn wallet_word_count(value: u32) -> FfiResult<WalletWordCount> {
    match value {
        value if value == CitizenSdkWalletWordCount::Words12 as u32 => Ok(WalletWordCount::Words12),
        value if value == CitizenSdkWalletWordCount::Words18 as u32 => Ok(WalletWordCount::Words18),
        value if value == CitizenSdkWalletWordCount::Words24 as u32 => Ok(WalletWordCount::Words24),
        _ => Err(FfiError::invalid("wallet word count must be 12, 18 or 24")),
    }
}

unsafe fn secret_buffer(
    view: CitizenSdkBytesView,
    name: &str,
    maximum: usize,
) -> FfiResult<SecretBuffer> {
    SecretBuffer::try_new(copy_view(view, name, maximum)?).map_err(Into::into)
}

unsafe fn secret_utf8(
    view: CitizenSdkBytesView,
    name: &str,
    maximum: usize,
) -> FfiResult<Zeroizing<String>> {
    let bytes = Zeroizing::new(copy_view(view, name, maximum)?);
    let text = std::str::from_utf8(bytes.as_slice())
        .map_err(|_| FfiError::invalid(format!("{name} is not UTF-8")))?;
    Ok(Zeroizing::new(text.to_owned()))
}

unsafe fn utf8(view: CitizenSdkBytesView, name: &str, maximum: usize) -> FfiResult<String> {
    String::from_utf8(copy_view(view, name, maximum)?)
        .map_err(|_| FfiError::invalid(format!("{name} is not UTF-8")))
}

unsafe fn copy_indices(pointer: *const u32, count: u32) -> FfiResult<Vec<u32>> {
    let count =
        usize::try_from(count).map_err(|_| FfiError::invalid("index count is too large"))?;
    if count == 0 || count > MAX_ACCOUNT_BATCH || pointer.is_null() {
        return Err(FfiError::invalid(
            "wallet index list must contain between 1 and 1990 items",
        ));
    }
    Ok(std::slice::from_raw_parts(pointer, count).to_vec())
}

unsafe fn copy_account_ids(
    pointer: *const CitizenSdkAccountId,
    count: u32,
) -> FfiResult<Vec<AccountId32>> {
    let count =
        usize::try_from(count).map_err(|_| FfiError::invalid("account count is too large"))?;
    if count == 0 || count > MAX_ACCOUNT_BATCH || pointer.is_null() {
        return Err(FfiError::invalid(
            "account list must contain between 1 and 1990 items",
        ));
    }
    Ok(std::slice::from_raw_parts(pointer, count)
        .iter()
        .map(|account| AccountId32::from_bytes(account.bytes))
        .collect())
}

fn fee_snapshot_to_abi(snapshot: BestFeeSnapshot) -> CitizenSdkFeeSnapshotInfo {
    CitizenSdkFeeSnapshotInfo {
        best_block: block_to_abi(snapshot.block()),
        fee_rate_parts: snapshot.policy().fee_rate_parts(),
        minimum_fee_fen: u128_to_abi(snapshot.policy().minimum_fee_fen()),
        existential_deposit_fen: u128_to_abi(snapshot.existential_deposit_fen()),
        ..CitizenSdkFeeSnapshotInfo::default()
    }
}

fn wallet_profile_to_abi(
    profile: Option<&WalletProfile>,
) -> FfiResult<CitizenSdkWalletProfileInfo> {
    let Some(profile) = profile else {
        return Ok(CitizenSdkWalletProfileInfo::default());
    };
    Ok(CitizenSdkWalletProfileInfo {
        present: 1,
        origin: match profile.origin() {
            WalletOrigin::Created => CitizenSdkWalletOrigin::Created,
            WalletOrigin::Imported => CitizenSdkWalletOrigin::Imported,
        } as u32,
        wallet_index: profile.wallet_index(),
        account_count: checked_count(profile.accounts().len(), "wallet account")?,
        created_at_millis: profile.created_at_millis(),
        master_account_id: account_id_to_abi(profile.master_account_id()),
        active_account_id: account_id_to_abi(profile.active_account_id()),
        ..CitizenSdkWalletProfileInfo::default()
    })
}

fn wallet_accounts(payload: &ResultPayload) -> FfiResult<(&[WalletAccount], Option<AccountId32>)> {
    match payload {
        ResultPayload::WalletProfile(Some(profile)) => {
            Ok((profile.accounts(), Some(profile.active_account_id())))
        }
        ResultPayload::WalletProfile(None) => Ok((&[], None)),
        ResultPayload::WalletAccounts(accounts) => Ok((accounts, None)),
        _ => Err(wrong_result("wallet profile or account list")),
    }
}

fn transfer_resolution(
    resolution: &WalletTransferResolution,
) -> FfiResult<(u32, Option<ExecutionConclusion>, &str)> {
    match resolution {
        WalletTransferResolution::Finalized(conclusion @ ExecutionConclusion::Success { .. }) => {
            Ok((
                CitizenSdkTransferResolution::FinalizedSuccess as u32,
                Some(conclusion.clone()),
                "",
            ))
        }
        WalletTransferResolution::Finalized(conclusion @ ExecutionConclusion::Failed { .. }) => {
            Ok((
                CitizenSdkTransferResolution::FinalizedFailed as u32,
                Some(conclusion.clone()),
                "",
            ))
        }
        WalletTransferResolution::Finalized(ExecutionConclusion::Unverified { .. }) => {
            Err(FfiError::new(
                CitizenSdkErrorCode::Integrity,
                "wallet transfer cannot expose an unverified finalized resolution",
            ))
        }
        WalletTransferResolution::PoolRejected { reason } => Ok((
            CitizenSdkTransferResolution::PoolRejected as u32,
            None,
            reason,
        )),
    }
}

fn history_state(payload: &ResultPayload) -> FfiResult<&TransactionHistoryState> {
    match payload {
        ResultPayload::TransactionHistory(history) => Ok(history),
        ResultPayload::WalletTransfer(transfer) => Ok(transfer.history()),
        _ => Err(wrong_result("transaction history")),
    }
}

type HistoryStatusProjection<'a> = (
    u32,
    Option<citizen_sdk_contracts::VerifiedBlockRef>,
    Option<ExecutionConclusion>,
    &'a str,
);

fn history_status(record: &TransactionHistoryRecord) -> FfiResult<HistoryStatusProjection<'_>> {
    match record.status() {
        HistoryTransactionStatus::Pending => {
            Ok((CitizenSdkHistoryStatus::Pending as u32, None, None, ""))
        }
        HistoryTransactionStatus::InBlock { block } => Ok((
            CitizenSdkHistoryStatus::InBlock as u32,
            Some(*block),
            None,
            "",
        )),
        HistoryTransactionStatus::PoolRejected { reason } => Ok((
            CitizenSdkHistoryStatus::PoolRejected as u32,
            None,
            None,
            reason,
        )),
        HistoryTransactionStatus::Execution(
            conclusion @ ExecutionConclusion::Success { block, .. },
        ) => Ok((
            CitizenSdkHistoryStatus::FinalizedSuccess as u32,
            Some(*block),
            Some(conclusion.clone()),
            "",
        )),
        HistoryTransactionStatus::Execution(
            conclusion @ ExecutionConclusion::Failed { block, .. },
        ) => Ok((
            CitizenSdkHistoryStatus::FinalizedFailed as u32,
            Some(*block),
            Some(conclusion.clone()),
            "",
        )),
        HistoryTransactionStatus::Execution(ExecutionConclusion::Unverified { .. }) => {
            Err(FfiError::new(
                CitizenSdkErrorCode::Integrity,
                "persisted history contains an unverified execution",
            ))
        }
    }
}

fn finalized_transfer_to_abi(
    transfer: &FinalizedTransferRecord,
) -> CitizenSdkFinalizedTransferInfo {
    CitizenSdkFinalizedTransferInfo {
        tracked_account_id: account_id_to_abi(transfer.tracked_account_id()),
        from_account_id: account_id_to_abi(transfer.from_account_id()),
        to_account_id: account_id_to_abi(transfer.to_account_id()),
        amount_fen: u128_to_abi(transfer.amount_fen()),
        block: block_to_abi(transfer.block().into()),
        event_record_index: transfer.event_record_index(),
        has_extrinsic_index: u32::from(transfer.extrinsic_index().is_some()),
        extrinsic_index: transfer.extrinsic_index().unwrap_or_default(),
        direction: if transfer.is_incoming() {
            CitizenSdkTransferDirection::Incoming
        } else {
            CitizenSdkTransferDirection::Outgoing
        } as u32,
        source_pallet_len: transfer.source_pallet().len() as u64,
        remark_display_len: transfer.remark().map_or(0, str::len) as u64,
        remark_bytes_len: transfer.remark_bytes().map_or(0, <[u8]>::len) as u64,
        ..CitizenSdkFinalizedTransferInfo::default()
    }
}

fn checked_count(value: usize, name: &str) -> FfiResult<u32> {
    u32::try_from(value).map_err(|_| FfiError::internal(format!("{name} count exceeds u32")))
}

unsafe fn ensure_copy_destination(
    bytes: &[u8],
    buffer: *mut u8,
    capacity: u64,
    name: &str,
) -> FfiResult<()> {
    let capacity = usize::try_from(capacity)
        .map_err(|_| FfiError::invalid(format!("{name} capacity is too large")))?;
    if bytes.is_empty() || (buffer.is_null() && capacity == 0) {
        return Ok(());
    }
    if buffer.is_null() || capacity < bytes.len() {
        return Err(FfiError::invalid(format!(
            "{name} buffer is null or too small"
        )));
    }
    Ok(())
}

// This mirrors one public two-buffer copy ABI. Keeping all pointer/capacity/
// required-length fields visible makes the preflight-before-write rule
// reviewable at the boundary, just as the three-buffer helper below does.
#[allow(clippy::too_many_arguments)]
unsafe fn copy_pair(
    first: &[u8],
    first_buffer: *mut u8,
    first_capacity: u64,
    first_required: *mut u64,
    second: &[u8],
    second_buffer: *mut u8,
    second_capacity: u64,
    second_required: *mut u64,
) -> FfiResult<()> {
    require_output(first_required, "first_required")?;
    require_output(second_required, "second_required")?;
    ensure_copy_destination(first, first_buffer, first_capacity, "first")?;
    ensure_copy_destination(second, second_buffer, second_capacity, "second")?;
    ptr::write(first_required, first.len() as u64);
    ptr::write(second_required, second.len() as u64);
    if !first.is_empty() && !first_buffer.is_null() {
        ptr::copy_nonoverlapping(first.as_ptr(), first_buffer, first.len());
    }
    if !second.is_empty() && !second_buffer.is_null() {
        ptr::copy_nonoverlapping(second.as_ptr(), second_buffer, second.len());
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
unsafe fn copy_three(
    first: &[u8],
    first_buffer: *mut u8,
    first_capacity: u64,
    first_required: *mut u64,
    second: &[u8],
    second_buffer: *mut u8,
    second_capacity: u64,
    second_required: *mut u64,
    third: &[u8],
    third_buffer: *mut u8,
    third_capacity: u64,
    third_required: *mut u64,
) -> FfiResult<()> {
    require_output(first_required, "first_required")?;
    require_output(second_required, "second_required")?;
    require_output(third_required, "third_required")?;
    ensure_copy_destination(first, first_buffer, first_capacity, "first")?;
    ensure_copy_destination(second, second_buffer, second_capacity, "second")?;
    ensure_copy_destination(third, third_buffer, third_capacity, "third")?;
    ptr::write(first_required, first.len() as u64);
    ptr::write(second_required, second.len() as u64);
    ptr::write(third_required, third.len() as u64);
    if !first.is_empty() && !first_buffer.is_null() {
        ptr::copy_nonoverlapping(first.as_ptr(), first_buffer, first.len());
    }
    if !second.is_empty() && !second_buffer.is_null() {
        ptr::copy_nonoverlapping(second.as_ptr(), second_buffer, second.len());
    }
    if !third.is_empty() && !third_buffer.is_null() {
        ptr::copy_nonoverlapping(third.as_ptr(), third_buffer, third.len());
    }
    Ok(())
}

#[cfg(test)]
#[path = "wallet_abi_tests.rs"]
mod tests;
