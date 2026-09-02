//! 带备注转账 call、immortal 签名载荷和完整构造结果合同。

use citizen_sdk_contracts::{
    AccountId32, AccountNonce, ChainIdentity, ContractResult, FinalizedBlockRef,
    FinalizedTransferRecord, Hash32, HistoryTransactionStatus, ImmortalSigningPayload,
    RuntimeContext, RuntimeVersion, SignedExtrinsic, SignedTransactionBuild, Sr25519PublicKey,
    Sr25519Signature, TransactionHistoryCursor, TransactionHistoryRecord, TransactionHistoryState,
    TransferWithRemarkCall, UnverifiedReason, VerifiedBlockRef, MAX_TRANSFER_REMARK_BYTES,
};

fn value_or_panic<T>(result: ContractResult<T>) -> T {
    match result {
        Ok(value) => value,
        Err(error) => panic!("合同调用失败: {error}"),
    }
}

#[test]
fn transfer_with_remark_call_is_byte_exact_with_the_verified_dart_builder() {
    let destination = AccountId32::from_bytes(std::array::from_fn(|index| index as u8));
    let call = value_or_panic(TransferWithRemarkCall::try_new(destination, 100, "hi"));
    let encoded = call.encode_call_data();
    assert_eq!(&encoded[..2], &[4, 0]);
    assert_eq!(&encoded[2..34], destination.as_bytes());
    assert_eq!(encoded[34], 100);
    assert!(encoded[35..50].iter().all(|byte| *byte == 0));
    assert_eq!(encoded[50], 8); // SCALE Compact(2) = 2 << 2.
    assert_eq!(&encoded[51..], b"hi");

    let unicode = "中".repeat(33);
    let maximum = value_or_panic(TransferWithRemarkCall::try_new(
        AccountId32::from_bytes([0; 32]),
        1,
        unicode,
    ));
    let encoded = maximum.encode_call_data();
    assert_eq!(&encoded[50..52], &[0x8d, 0x01]); // Compact(99).
    assert_eq!(encoded.len(), 52 + MAX_TRANSFER_REMARK_BYTES);
}

#[test]
fn transfer_call_rejects_zero_amount_and_overlong_utf8_remark() {
    let account = AccountId32::from_bytes([0; 32]);
    assert!(TransferWithRemarkCall::try_new(account, 0, "").is_err());
    assert!(TransferWithRemarkCall::try_new(account, 1, "a".repeat(100)).is_err());
    assert!(TransferWithRemarkCall::try_new(account, 1, "中".repeat(34)).is_err());
}

fn valid_payload() -> ImmortalSigningPayload {
    let identity = ChainIdentity::citizenchain();
    let best = VerifiedBlockRef::best(Hash32::from_bytes([7; 32]), 51);
    let account_id = AccountId32::from_bytes([8; 32]);
    let runtime = value_or_panic(RuntimeContext::try_new(
        best,
        RuntimeVersion::new(42, 7),
        vec![0x6d, 0x65, 0x74, 0x61],
    ));
    let nonce = value_or_panic(AccountNonce::try_new(&identity, best, account_id, 9));
    value_or_panic(ImmortalSigningPayload::try_new(
        &identity,
        &runtime,
        nonce,
        account_id,
        Sr25519PublicKey::from_bytes(account_id.into_bytes()),
        vec![4, 0],
        vec![0xaa, 0xbb],
    ))
}

#[test]
fn signing_payload_binds_account_nonce_runtime_and_genesis() {
    let payload = valid_payload();
    assert_eq!(payload.block().number(), 51);
    assert_eq!(payload.runtime_version().spec_version(), 42);
    assert_eq!(payload.runtime_version().transaction_version(), 7);
    assert_eq!(
        payload.genesis_hash(),
        ChainIdentity::citizenchain().genesis_hash()
    );
    assert_eq!(
        payload.signer_account_id(),
        AccountId32::from_bytes([8; 32])
    );
    assert_eq!(payload.signer_public_key().as_bytes(), &[8; 32]);
    assert_eq!(payload.nonce(), 9);
    assert_eq!(payload.call_data(), &[4, 0]);
    assert_eq!(payload.signing_message(), &[0xaa, 0xbb]);
}

#[test]
fn signing_payload_rejects_cross_block_cross_account_and_wrong_network() {
    let identity = ChainIdentity::citizenchain();
    let best = VerifiedBlockRef::best(Hash32::from_bytes([7; 32]), 51);
    let other_best = VerifiedBlockRef::best(Hash32::from_bytes([9; 32]), 52);
    let account_id = AccountId32::from_bytes([8; 32]);
    let runtime = value_or_panic(RuntimeContext::try_new(
        best,
        RuntimeVersion::new(42, 7),
        vec![1],
    ));
    let other_nonce = value_or_panic(AccountNonce::try_new(&identity, other_best, account_id, 0));
    assert!(ImmortalSigningPayload::try_new(
        &identity,
        &runtime,
        other_nonce,
        account_id,
        Sr25519PublicKey::from_bytes([8; 32]),
        vec![4, 0],
        vec![1],
    )
    .is_err());

    let nonce = value_or_panic(AccountNonce::try_new(&identity, best, account_id, 0));
    assert!(ImmortalSigningPayload::try_new(
        &identity,
        &runtime,
        nonce,
        account_id,
        Sr25519PublicKey::from_bytes([1; 32]),
        vec![4, 0],
        vec![1],
    )
    .is_err());

    let wrong = value_or_panic(ChainIdentity::try_new(
        "citizenchain",
        "citizenchain",
        Hash32::from_bytes([0; 32]),
    ));
    let nonce = value_or_panic(AccountNonce::try_new(&identity, best, account_id, 0));
    assert!(ImmortalSigningPayload::try_new(
        &wrong,
        &runtime,
        nonce,
        account_id,
        Sr25519PublicKey::from_bytes([8; 32]),
        vec![4, 0],
        vec![1],
    )
    .is_err());
}

#[test]
fn signed_build_exposes_only_public_trace_signature_and_extrinsic() {
    let build = SignedTransactionBuild::new(
        valid_payload(),
        Sr25519Signature::from_bytes([3; 64]),
        value_or_panic(SignedExtrinsic::try_new(vec![0x04, 0x84, 0x01])),
    );
    assert_eq!(build.payload().nonce(), 9);
    assert_eq!(build.signature().as_bytes(), &[3; 64]);
    assert_eq!(build.extrinsic().as_bytes(), &[0x04, 0x84, 0x01]);
    assert_eq!(build.extrinsic_bytes(), &[0x04, 0x84, 0x01]);
}

#[test]
fn history_moves_only_toward_verified_chain_evidence() {
    let account = AccountId32::from_bytes([4; 32]);
    let hash = Hash32::from_bytes([5; 32]);
    let submitted = value_or_panic(TransactionHistoryRecord::try_new(
        account,
        hash,
        3,
        AccountId32::from_bytes([9; 32]),
        123,
        "fixture",
        HistoryTransactionStatus::Pending,
        100,
        100,
    ));
    assert_eq!(
        submitted.destination_account_id(),
        AccountId32::from_bytes([9; 32])
    );
    assert_eq!(submitted.amount_fen(), 123);
    assert_eq!(submitted.remark(), "fixture");
    assert_eq!(submitted.status().persisted_name(), Some("pending"));
    let block = VerifiedBlockRef::best(Hash32::from_bytes([6; 32]), 8);
    let in_block =
        value_or_panic(submitted.try_with_status(HistoryTransactionStatus::InBlock { block }, 101));
    assert_eq!(in_block.status().persisted_name(), Some("inBlock"));
    let rejected_after_in_block = value_or_panic(in_block.try_with_status(
        value_or_panic(HistoryTransactionStatus::try_pool_rejected(
            "交易池随后给出确定拒绝",
        )),
        102,
    ));
    assert_eq!(
        rejected_after_in_block.status().persisted_name(),
        Some("poolRejected")
    );
    let finalized = VerifiedBlockRef::finalized(Hash32::from_bytes([7; 32]), 9);
    let success = value_or_panic(in_block.try_with_status(
        HistoryTransactionStatus::Execution(citizen_sdk_contracts::ExecutionConclusion::Success {
            block: finalized,
            extrinsic_index: 2,
        }),
        102,
    ));
    assert!(success.status().is_chain_terminal());
    assert_eq!(success.status().persisted_name(), Some("finalized"));
    assert!(success
        .try_with_status(HistoryTransactionStatus::Pending, 103)
        .is_err());

    let pool_rejected = value_or_panic(HistoryTransactionStatus::try_pool_rejected(
        "交易被同 nonce 的另一笔交易替代",
    ));
    assert_eq!(pool_rejected.persisted_name(), Some("poolRejected"));
    assert!(pool_rejected.pool_rejection_reason().is_some());
    let duplicate = value_or_panic(TransactionHistoryRecord::try_new(
        account,
        hash,
        3,
        AccountId32::from_bytes([9; 32]),
        123,
        "fixture",
        pool_rejected,
        200,
        200,
    ));
    assert!(submitted.require_same_submission_facts(&duplicate).is_ok());
    let conflict = value_or_panic(TransactionHistoryRecord::try_new(
        account,
        hash,
        3,
        AccountId32::from_bytes([9; 32]),
        124,
        "fixture",
        HistoryTransactionStatus::Pending,
        100,
        100,
    ));
    assert!(submitted.require_same_submission_facts(&conflict).is_err());
    assert!(HistoryTransactionStatus::try_pool_rejected(" ").is_err());

    assert!(TransactionHistoryRecord::try_new(
        account,
        hash,
        3,
        AccountId32::from_bytes([9; 32]),
        123,
        "fixture",
        HistoryTransactionStatus::Execution(
            citizen_sdk_contracts::ExecutionConclusion::Unverified {
                block: Some(finalized),
                extrinsic_index: Some(2),
                reason: UnverifiedReason::OutcomeEventMissing,
            },
        ),
        100,
        101,
    )
    .is_err());

    let tracking_start = FinalizedBlockRef::from_parts(Hash32::from_bytes([5; 32]), 5);
    let last = FinalizedBlockRef::from_parts(Hash32::from_bytes([8; 32]), 8);
    let next = FinalizedBlockRef::from_parts(Hash32::from_bytes([9; 32]), 9);
    let cursor = value_or_panic(TransactionHistoryCursor::try_new(
        account,
        tracking_start,
        last,
    ));
    assert_eq!(
        value_or_panic(cursor.try_advance(next)).last_synced_block(),
        next
    );
    assert!(cursor
        .try_advance(FinalizedBlockRef::from_parts(
            Hash32::from_bytes([7; 32]),
            7
        ))
        .is_err());
    assert!(cursor
        .try_advance(FinalizedBlockRef::from_parts(
            Hash32::from_bytes([10; 32]),
            10
        ))
        .is_err());
    assert!(cursor
        .try_advance(FinalizedBlockRef::from_parts(
            Hash32::from_bytes([0x88; 32]),
            8
        ))
        .is_err());
}

#[test]
fn finalized_transfer_source_and_remark_are_not_ambiguous() {
    let from = AccountId32::from_bytes([1; 32]);
    let to = AccountId32::from_bytes([2; 32]);
    let block = FinalizedBlockRef::from_parts(Hash32::from_bytes([3; 32]), 4);
    assert!(FinalizedTransferRecord::try_for_tracked_account(
        from,
        from,
        to,
        1,
        block,
        0,
        Some(0),
        "Balances",
        Some(String::new()),
    )
    .is_err());
    assert!(
        FinalizedTransferRecord::try_new(from, to, 1, block, 0, Some(0), "OtherPallet", None,)
            .is_err()
    );
    assert!(FinalizedTransferRecord::try_new(
        from,
        to,
        1,
        block,
        0,
        Some(0),
        "OnchainTransaction",
        Some("中".repeat(34)),
    )
    .is_err());
    assert!(FinalizedTransferRecord::try_new(
        from,
        to,
        1,
        block,
        0,
        Some(0),
        "OnchainTransaction",
        None,
    )
    .is_err());
    assert!(FinalizedTransferRecord::try_new(
        from,
        to,
        1,
        block,
        0,
        None,
        "OnchainTransaction",
        Some("fixture".to_owned()),
    )
    .is_err());
    let outgoing = value_or_panic(FinalizedTransferRecord::try_for_tracked_account(
        from,
        from,
        to,
        1,
        block,
        0,
        Some(0),
        "OnchainTransaction",
        Some("fixture".to_owned()),
    ));
    let incoming = value_or_panic(FinalizedTransferRecord::try_for_tracked_account(
        to,
        from,
        to,
        1,
        block,
        0,
        Some(0),
        "OnchainTransaction",
        Some("fixture".to_owned()),
    ));
    assert!(outgoing.is_outgoing());
    assert!(incoming.is_incoming());
    assert_eq!(outgoing.tracked_account_id(), from);
    assert_eq!(incoming.tracked_account_id(), to);
    assert!(TransactionHistoryState::try_new(
        1,
        Vec::new(),
        Vec::new(),
        vec![outgoing.clone(), incoming],
    )
    .is_ok());
    assert!(TransactionHistoryState::try_new(
        1,
        Vec::new(),
        Vec::new(),
        vec![outgoing.clone(), outgoing],
    )
    .is_err());

    assert!(FinalizedTransferRecord::try_for_tracked_account(
        from,
        from,
        from,
        1,
        block,
        1,
        Some(1),
        "OnchainTransaction",
        Some(String::new()),
    )
    .is_err());
}
