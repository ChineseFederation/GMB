use citizen_sdk_contracts::{
    ExecutionConclusion, Hash32, RuntimeContext, RuntimeVersion, SignedExtrinsic, UnverifiedReason,
    VerifiedBlockRef,
};
use citizen_sdk_engine::{signed_extrinsic_hash, verify_transaction_outcome, TransactionEvidence};

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex");
const EVENTS_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-system-events.hex");

fn hex_bytes(value: &str) -> Vec<u8> {
    let value = value.trim();
    let Some(value) = value.strip_prefix("0x") else {
        panic!("fixture must use 0x prefix");
    };
    assert_eq!(value.len() % 2, 0, "fixture hex length must be even");
    value
        .as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            let text = match std::str::from_utf8(pair) {
                Ok(text) => text,
                Err(error) => panic!("fixture is not UTF-8 hex: {error}"),
            };
            match u8::from_str_radix(text, 16) {
                Ok(byte) => byte,
                Err(error) => panic!("fixture contains invalid hex: {error}"),
            }
        })
        .collect()
}

fn runtime(block: VerifiedBlockRef) -> RuntimeContext {
    match RuntimeContext::try_new(block, RuntimeVersion::new(100, 12), hex_bytes(METADATA_HEX)) {
        Ok(context) => context,
        Err(error) => panic!("runtime fixture failed: {error}"),
    }
}

fn signed(bytes: &[u8]) -> SignedExtrinsic {
    match SignedExtrinsic::try_new(bytes.to_vec()) {
        Ok(extrinsic) => extrinsic,
        Err(error) => panic!("extrinsic fixture failed: {error}"),
    }
}

fn hash(context: &RuntimeContext, extrinsic: &SignedExtrinsic) -> Hash32 {
    match signed_extrinsic_hash(context, extrinsic) {
        Ok(hash) => hash,
        Err(error) => panic!("hash failed: {error}"),
    }
}

#[test]
fn production_events_prove_index_zero_success_and_index_one_bad_origin() {
    let block = VerifiedBlockRef::finalized(Hash32::from_bytes([9; 32]), 100);
    let context = runtime(block);
    let first = signed(&[0x0c, 0x84, 0x01, 0x02]);
    let second = signed(&[0x08, 0x84, 0x03]);
    let body = vec![first.as_bytes().to_vec(), second.as_bytes().to_vec()];
    let events = hex_bytes(EVENTS_HEX);

    let success = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &context,
        signed_extrinsic: &first,
        submitted_hash: hash(&context, &first),
        block_extrinsics: &body,
        system_events: Some(&events),
    });
    assert!(matches!(
        success,
        ExecutionConclusion::Success {
            extrinsic_index: 0,
            ..
        }
    ));

    let failed = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &context,
        signed_extrinsic: &second,
        submitted_hash: hash(&context, &second),
        block_extrinsics: &body,
        system_events: Some(&events),
    });
    match failed {
        ExecutionConclusion::Failed {
            extrinsic_index,
            failure,
            ..
        } => {
            assert_eq!(extrinsic_index, 1);
            assert_eq!(failure.variant(), 2);
            assert!(failure.module().is_none());
        }
        other => panic!("expected BadOrigin failure, got {other:?}"),
    }
}

#[test]
fn hash_block_and_body_identity_fail_closed() {
    let block = VerifiedBlockRef::best(Hash32::from_bytes([1; 32]), 10);
    let context = runtime(block);
    let target = signed(&[0x0c, 0x84, 0x01, 0x02]);
    let target_hash = hash(&context, &target);
    let events = hex_bytes(EVENTS_HEX);

    let wrong_hash = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &context,
        signed_extrinsic: &target,
        submitted_hash: Hash32::from_bytes([0; 32]),
        block_extrinsics: &[target.as_bytes().to_vec()],
        system_events: Some(&events),
    });
    assert!(matches!(
        wrong_hash,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::ExtrinsicHashMismatch,
            ..
        }
    ));

    let duplicate_body = vec![target.as_bytes().to_vec(), target.as_bytes().to_vec()];
    let duplicate = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &context,
        signed_extrinsic: &target,
        submitted_hash: target_hash,
        block_extrinsics: &duplicate_body,
        system_events: Some(&events),
    });
    assert!(matches!(
        duplicate,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::MultipleExtrinsicMatches,
            ..
        }
    ));

    let other_block = VerifiedBlockRef::best(Hash32::from_bytes([2; 32]), 11);
    let wrong_block = verify_transaction_outcome(TransactionEvidence {
        block: other_block,
        runtime_context: &context,
        signed_extrinsic: &target,
        submitted_hash: target_hash,
        block_extrinsics: &[target.as_bytes().to_vec()],
        system_events: Some(&events),
    });
    assert!(matches!(
        wrong_block,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::RuntimeContextUnavailable,
            ..
        }
    ));
}

#[test]
fn malformed_metadata_events_and_wrong_index_never_guess_success() {
    let block = VerifiedBlockRef::finalized(Hash32::from_bytes([3; 32]), 30);
    let context = runtime(block);
    let target = signed(&[0x0c, 0x84, 0x01, 0x02]);
    let target_hash = hash(&context, &target);
    let body = vec![target.as_bytes().to_vec()];
    let mut trailing_events = hex_bytes(EVENTS_HEX);
    trailing_events.push(0);
    let trailing = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &context,
        signed_extrinsic: &target,
        submitted_hash: target_hash,
        block_extrinsics: &body,
        system_events: Some(&trailing_events),
    });
    assert!(matches!(
        trailing,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::SystemEventsMalformed,
            ..
        }
    ));

    let canonical_events = hex_bytes(EVENTS_HEX);
    assert_eq!(canonical_events.first(), Some(&0x10));
    let mut noncanonical_events = vec![0x11, 0x00];
    noncanonical_events.extend_from_slice(&canonical_events[1..]);
    let noncanonical = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &context,
        signed_extrinsic: &target,
        submitted_hash: target_hash,
        block_extrinsics: &body,
        system_events: Some(&noncanonical_events),
    });
    assert!(matches!(
        noncanonical,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::SystemEventsMalformed,
            ..
        }
    ));

    let third = signed(&[0x04, 0x99]);
    let third_body = vec![vec![0x04], vec![0x08], third.as_bytes().to_vec()];
    let no_outcome = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &context,
        signed_extrinsic: &third,
        submitted_hash: hash(&context, &third),
        block_extrinsics: &third_body,
        system_events: Some(&hex_bytes(EVENTS_HEX)),
    });
    assert!(matches!(
        no_outcome,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::OutcomeEventMissing,
            ..
        }
    ));

    let mut bad_metadata = context.metadata().to_vec();
    bad_metadata.push(0);
    let bad_context =
        match RuntimeContext::try_new(block, RuntimeVersion::new(100, 12), bad_metadata) {
            Ok(context) => context,
            Err(error) => panic!("bad metadata fixture construction failed: {error}"),
        };
    let rejected_metadata = verify_transaction_outcome(TransactionEvidence {
        block,
        runtime_context: &bad_context,
        signed_extrinsic: &target,
        submitted_hash: target_hash,
        block_extrinsics: &body,
        system_events: Some(&hex_bytes(EVENTS_HEX)),
    });
    assert!(matches!(
        rejected_metadata,
        ExecutionConclusion::Unverified {
            reason: UnverifiedReason::MetadataDecodeFailed,
            ..
        }
    ));
}

#[test]
fn compact_length_prefix_is_part_of_the_transaction_hash() {
    let block = VerifiedBlockRef::best(Hash32::from_bytes([4; 32]), 40);
    let context = runtime(block);
    let complete = signed(&[0x0c, 0x84, 0x01, 0x02]);
    let without_prefix = signed(&[0x84, 0x01, 0x02]);
    assert_ne!(hash(&context, &complete), hash(&context, &without_prefix));
}
