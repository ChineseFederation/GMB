use super::{
    claim_prepared_wallet, copy_pair, lock_prepared_wallets, next_prepared_wallet_handle,
    require_prepared_owner, secret_utf8, u128_from_abi, u128_to_abi, wallet_profile_to_abi,
    wallet_transfer_or_cancellation, wallet_transfer_watch_event, wallet_word_count,
    PreparedWalletSlot,
};
use crate::abi::{
    CitizenSdkBytesView, CitizenSdkErrorCode, CitizenSdkU128, CitizenSdkWalletWordCount,
};
use citizen_sdk_contracts::{ExecutionConclusion, ExtrinsicWatchEvent, Hash32, VerifiedBlockRef};
use citizen_sdk_engine::{EngineError, WalletTransferWatchResult, WalletTransferWatchStage};
use std::{
    future::Future,
    pin::Pin,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    task::{Context, Poll},
};

struct PendingWalletTransfer {
    dropped: Arc<AtomicBool>,
}

impl Future for PendingWalletTransfer {
    type Output = Result<WalletTransferWatchResult, EngineError>;

    fn poll(self: Pin<&mut Self>, _context: &mut Context<'_>) -> Poll<Self::Output> {
        Poll::Pending
    }
}

impl Drop for PendingWalletTransfer {
    fn drop(&mut self) {
        self.dropped.store(true, Ordering::SeqCst);
    }
}

#[test]
fn portable_u128_round_trips_boundary_values() {
    for value in [0, 1, u64::MAX as u128, 1_u128 << 64, u128::MAX] {
        assert_eq!(u128_from_abi(u128_to_abi(value)), value);
    }
    assert_eq!(
        u128_from_abi(CitizenSdkU128 {
            low: 0x0123_4567_89ab_cdef,
            high: 0xfedc_ba98_7654_3210,
        }),
        0xfedc_ba98_7654_3210_0123_4567_89ab_cdef,
    );
}

#[test]
fn wallet_word_count_accepts_only_the_two_frozen_values() {
    assert!(wallet_word_count(CitizenSdkWalletWordCount::Words12 as u32).is_ok());
    assert!(wallet_word_count(CitizenSdkWalletWordCount::Words24 as u32).is_ok());
    for invalid in [0, 11, 13, 23, 25, u32::MAX] {
        assert!(wallet_word_count(invalid).is_err());
    }
}

#[test]
fn invalid_secret_utf8_is_rejected_before_async_acceptance() {
    let bytes = [0xff, 0xfe];
    let view = CitizenSdkBytesView {
        data: bytes.as_ptr(),
        len: bytes.len() as u64,
    };
    // SAFETY: the fixed test array remains readable through the synchronous copy.
    assert!(unsafe { secret_utf8(view, "test secret", bytes.len()) }.is_err());
}

#[test]
fn multi_buffer_copy_validates_every_destination_before_writing_any() {
    let first = b"first";
    let second = b"second";
    let mut first_output = [0xaa; 5];
    let mut second_output = [0xbb; 2];
    let mut first_required = u64::MAX;
    let mut second_required = u64::MAX;
    // SAFETY: all test pointers are valid for their declared capacities. The
    // second capacity is deliberately too small and must fail atomically.
    let result = unsafe {
        copy_pair(
            first,
            first_output.as_mut_ptr(),
            first_output.len() as u64,
            &mut first_required,
            second,
            second_output.as_mut_ptr(),
            second_output.len() as u64,
            &mut second_required,
        )
    };
    assert!(result.is_err());
    assert_eq!(first_output, [0xaa; 5]);
    assert_eq!(second_output, [0xbb; 2]);
    assert_eq!(first_required, u64::MAX);
    assert_eq!(second_required, u64::MAX);
}

#[test]
fn absent_wallet_profile_is_a_successful_zeroed_projection() {
    let info = wallet_profile_to_abi(None)
        .unwrap_or_else(|error| panic!("absent profile projection failed: {error:?}"));
    assert_eq!(info.present, 0);
    assert_eq!(info.origin, 0);
    assert_eq!(info.account_count, 0);
    assert_eq!(info.master_account_id.bytes, [0; 32]);
    assert_eq!(info.active_account_id.bytes, [0; 32]);
}

#[test]
fn prepared_wallet_handles_are_nonzero_monotonic_and_never_reused() {
    let first = next_prepared_wallet_handle()
        .unwrap_or_else(|error| panic!("first prepared handle failed: {error:?}"));
    let second = next_prepared_wallet_handle()
        .unwrap_or_else(|error| panic!("second prepared handle failed: {error:?}"));
    assert_ne!(first, 0);
    assert_eq!(second, first + 1);
}

#[test]
fn prepared_wallet_owner_is_checked_even_while_the_handle_is_claimed() {
    let handle = next_prepared_wallet_handle()
        .unwrap_or_else(|error| panic!("prepared handle failed: {error:?}"));
    lock_prepared_wallets()
        .unwrap_or_else(|error| panic!("prepared registry failed: {error:?}"))
        .insert(handle, PreparedWalletSlot::Claimed { owner: 7001 });

    let error = claim_prepared_wallet(handle, 7002)
        .err()
        .unwrap_or_else(|| panic!("cross-instance claim must fail"));
    assert_eq!(error.code, CitizenSdkErrorCode::InvalidHandle);
    assert_eq!(
        require_prepared_owner(7001, 7002)
            .err()
            .unwrap_or_else(|| panic!("cross-instance owner check must fail"))
            .code,
        CitizenSdkErrorCode::InvalidHandle,
    );

    lock_prepared_wallets()
        .unwrap_or_else(|error| panic!("prepared registry cleanup failed: {error:?}"))
        .remove(&handle);
}

#[test]
fn wallet_transfer_cancellation_returns_cancelled_and_drops_the_terminal_future() {
    let dropped = Arc::new(AtomicBool::new(false));
    let transfer = PendingWalletTransfer {
        dropped: Arc::clone(&dropped),
    };
    let (cancel, cancellation) = futures_channel::oneshot::channel();
    cancel
        .send(())
        .unwrap_or_else(|_| panic!("cancellation receiver disappeared before selection"));

    let error = futures_executor::block_on(wallet_transfer_or_cancellation(transfer, cancellation))
        .err()
        .unwrap_or_else(|| panic!("cancellation must not return a wallet transfer result"));
    assert_eq!(error.code, CitizenSdkErrorCode::Cancelled);
    assert!(error.message.contains("durable pending/in-block history"));
    assert!(dropped.load(Ordering::SeqCst));
}

#[test]
fn wallet_transfer_is_dispatched_only_to_the_dedicated_watch_pool() {
    let source = include_str!("wallet_abi.rs");
    let function = source
        .split("pub unsafe extern \"C\" fn citizensdk_transfer_with_remark")
        .nth(1)
        .and_then(|tail| tail.split("#[no_mangle]").next())
        .unwrap_or_else(|| panic!("wallet transfer ABI function must remain present"));
    assert!(function.contains("accept_and_write_watch("));
    assert!(!function.contains("accept_and_write(runtime"));
    assert!(function.contains("wallet_transfer_or_cancellation("));
    assert!(function.contains("transfer_with_remark_and_watch("));
    assert!(!function.contains(".transfer_with_remark(source"));
}

#[test]
fn high_level_wallet_progress_uses_only_truthful_existing_watch_states() {
    let best = VerifiedBlockRef::best(Hash32::from_bytes([7; 32]), 42);
    let finalized = VerifiedBlockRef::finalized(Hash32::from_bytes([8; 32]), 43);

    assert_eq!(
        wallet_transfer_watch_event(&WalletTransferWatchStage::Pending),
        None
    );
    assert_eq!(
        wallet_transfer_watch_event(&WalletTransferWatchStage::Interrupted {
            reason: "network".to_owned(),
        }),
        None,
    );
    assert_eq!(
        wallet_transfer_watch_event(&WalletTransferWatchStage::Broadcast { peer_count: 3 }),
        Some(ExtrinsicWatchEvent::Broadcast { peer_count: 3 }),
    );
    assert_eq!(
        wallet_transfer_watch_event(&WalletTransferWatchStage::InBlock { block: best }),
        Some(ExtrinsicWatchEvent::InBlock { block: best }),
    );
    assert_eq!(
        wallet_transfer_watch_event(&WalletTransferWatchStage::Finalized {
            conclusion: ExecutionConclusion::Success {
                block: finalized,
                extrinsic_index: 5,
            },
        }),
        Some(ExtrinsicWatchEvent::Finalized {
            block: finalized
                .try_into()
                .unwrap_or_else(|error| panic!("finalized conversion failed: {error:?}")),
        }),
    );
    assert_eq!(
        wallet_transfer_watch_event(&WalletTransferWatchStage::PoolRejected {
            reason: "invalid".to_owned(),
            replacement_hash: None,
        }),
        Some(ExtrinsicWatchEvent::Invalid),
    );
    assert_eq!(
        wallet_transfer_watch_event(&WalletTransferWatchStage::PoolRejected {
            reason: "usurped".to_owned(),
            replacement_hash: Some(Hash32::from_bytes([9; 32])),
        }),
        Some(ExtrinsicWatchEvent::Usurped {
            replacement_hash: Hash32::from_bytes([9; 32]),
        }),
    );
}
