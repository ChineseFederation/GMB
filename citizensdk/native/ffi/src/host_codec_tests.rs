use crate::{
    abi::CitizenSdkErrorCode,
    host_codec::{
        decode_chain_database_snapshot, decode_encrypted_secret_blob_snapshot, decode_host_record,
        decode_runtime_context, decode_transaction_history_state, decode_wallet_state,
        encode_chain_database_snapshot, encode_encrypted_secret_blob_snapshot, encode_host_record,
        encode_runtime_context, encode_transaction_history_state, encode_wallet_state,
        HostCodecErrorKind, HostRecordDomain, HOST_RECORD_FORMAT_VERSION,
    },
};
use citizen_sdk_contracts::{
    AccountId32, ChainDatabaseSnapshot, EncryptedSecretBlobSnapshot, EncryptedSecretBlobState,
    EncryptedSecretEnvelope, Hash32, Hash32Bytes, RuntimeContext, RuntimeVersion, SecretOwner,
    SecretRef, TransactionHistoryState, VaultGeneration, VerifiedBlockRef, WalletState,
};

const HEADER_LEN: usize = 56;

#[test]
fn v1_wire_layout_has_a_frozen_cross_language_vector() {
    let encoded = encode_host_record(HostRecordDomain::WalletProfile, b"citizen")
        .unwrap_or_else(|error| panic!("golden encode failed: {error}"));
    assert_eq!(&encoded[..4], b"CSHR");
    assert_eq!(&encoded[4..6], &[1, 0]);
    assert_eq!(&encoded[6..8], &[56, 0]);
    assert_eq!(&encoded[8..12], &[3, 0, 0, 0]);
    assert_eq!(&encoded[12..16], &[0; 4]);
    assert_eq!(&encoded[16..24], &[7, 0, 0, 0, 0, 0, 0, 0]);
    assert_eq!(
        &encoded[24..56],
        &[
            0xc7, 0x00, 0xc1, 0x99, 0x84, 0x96, 0x66, 0x41, 0x15, 0x0e, 0x5f, 0x22, 0x5a, 0x25,
            0xc1, 0x78, 0x9b, 0xf4, 0xea, 0x30, 0x78, 0xc8, 0xad, 0x11, 0xe9, 0xdb, 0x0b, 0xb3,
            0xd9, 0x98, 0xfd, 0x34,
        ]
    );
    assert_eq!(&encoded[56..], b"citizen");
}

#[test]
fn every_typed_domain_round_trips_without_copying_the_decoded_payload() {
    let domains = [
        HostRecordDomain::ChainDatabase,
        HostRecordDomain::RuntimeCache,
        HostRecordDomain::WalletProfile,
        HostRecordDomain::TransactionHistory,
        HostRecordDomain::EncryptedSecretBlob,
    ];

    for domain in domains {
        let payload = [domain as u8, 0, 0xff, 7];
        let encoded = encode_host_record(domain, &payload)
            .unwrap_or_else(|error| panic!("encode {domain:?} failed: {error}"));
        let decoded = decode_host_record(domain, &encoded)
            .unwrap_or_else(|error| panic!("decode {domain:?} failed: {error}"));
        assert_eq!(decoded.domain(), domain);
        assert_eq!(decoded.payload(), payload);
        assert_eq!(decoded.payload().as_ptr(), encoded[HEADER_LEN..].as_ptr());
    }
}

#[test]
fn empty_typed_payload_has_one_canonical_representation() {
    let encoded = encode_host_record(HostRecordDomain::ChainDatabase, &[])
        .unwrap_or_else(|error| panic!("empty payload failed: {error}"));
    assert_eq!(encoded.len(), HEADER_LEN);
    assert_eq!(&encoded[4..6], &HOST_RECORD_FORMAT_VERSION.to_le_bytes());
    assert!(
        decode_host_record(HostRecordDomain::ChainDatabase, &encoded)
            .unwrap_or_else(|error| panic!("empty payload decode failed: {error}"))
            .payload()
            .is_empty()
    );
}

#[test]
fn the_same_payload_cannot_cross_a_typed_store_domain() {
    let encoded = encode_host_record(HostRecordDomain::WalletProfile, b"public wallet facts")
        .unwrap_or_else(|error| panic!("encode failed: {error}"));
    let error = decode_host_record(HostRecordDomain::TransactionHistory, &encoded)
        .err()
        .unwrap_or_else(|| panic!("cross-domain decode must fail"));
    assert_eq!(error.kind(), HostCodecErrorKind::DomainMismatch);
    assert_eq!(error.ffi_code(), CitizenSdkErrorCode::Integrity);
}

#[test]
fn header_and_payload_corruption_are_detected_before_typed_decode() {
    let encoded = encode_host_record(HostRecordDomain::RuntimeCache, b"metadata")
        .unwrap_or_else(|error| panic!("encode failed: {error}"));

    let mut bad_magic = encoded.clone();
    bad_magic[0] ^= 1;
    assert_eq!(
        decode_host_record(HostRecordDomain::RuntimeCache, &bad_magic)
            .err()
            .unwrap_or_else(|| panic!("bad magic must fail"))
            .kind(),
        HostCodecErrorKind::Malformed
    );

    let mut bad_flags = encoded.clone();
    bad_flags[12] = 1;
    assert_eq!(
        decode_host_record(HostRecordDomain::RuntimeCache, &bad_flags)
            .err()
            .unwrap_or_else(|| panic!("reserved flags must fail"))
            .kind(),
        HostCodecErrorKind::Malformed
    );

    let mut bad_payload = encoded;
    *bad_payload
        .last_mut()
        .unwrap_or_else(|| panic!("encoded payload is unexpectedly empty")) ^= 1;
    assert_eq!(
        decode_host_record(HostRecordDomain::RuntimeCache, &bad_payload)
            .err()
            .unwrap_or_else(|| panic!("corrupt payload must fail"))
            .kind(),
        HostCodecErrorKind::IntegrityMismatch
    );
}

#[test]
fn unsupported_versions_unknown_domains_and_length_mismatches_are_stable() {
    let encoded = encode_host_record(HostRecordDomain::ChainDatabase, b"db")
        .unwrap_or_else(|error| panic!("encode failed: {error}"));

    let mut unknown_version = encoded.clone();
    unknown_version[4..6].copy_from_slice(&2_u16.to_le_bytes());
    assert_eq!(
        decode_host_record(HostRecordDomain::ChainDatabase, &unknown_version)
            .err()
            .unwrap_or_else(|| panic!("unknown version must fail"))
            .kind(),
        HostCodecErrorKind::UnsupportedVersion
    );

    let mut unknown_domain = encoded.clone();
    unknown_domain[8..12].copy_from_slice(&99_u32.to_le_bytes());
    assert_eq!(
        decode_host_record(HostRecordDomain::ChainDatabase, &unknown_domain)
            .err()
            .unwrap_or_else(|| panic!("unknown domain must fail"))
            .kind(),
        HostCodecErrorKind::UnknownDomain
    );

    let mut truncated = encoded;
    let _ = truncated.pop();
    assert_eq!(
        decode_host_record(HostRecordDomain::ChainDatabase, &truncated)
            .err()
            .unwrap_or_else(|| panic!("truncated record must fail"))
            .kind(),
        HostCodecErrorKind::LengthMismatch
    );
}

#[test]
fn each_domain_rejects_payloads_above_its_own_limit() {
    let domain = HostRecordDomain::EncryptedSecretBlob;
    let oversized = vec![0_u8; domain.max_payload_bytes() + 1];
    let error = encode_host_record(domain, &oversized)
        .err()
        .unwrap_or_else(|| panic!("oversized secret envelope must fail"));
    assert_eq!(error.kind(), HostCodecErrorKind::PayloadTooLarge);
    assert_eq!(error.ffi_code(), CitizenSdkErrorCode::InvalidArgument);
}

#[test]
fn malformed_records_map_to_decode_without_echoing_stored_bytes() {
    let error = decode_host_record(HostRecordDomain::WalletProfile, b"not an envelope")
        .err()
        .unwrap_or_else(|| panic!("malformed host bytes must fail"));
    assert_eq!(error.kind(), HostCodecErrorKind::Malformed);
    assert_eq!(error.ffi_code(), CitizenSdkErrorCode::Decode);
    assert!(!error.to_string().contains("not an envelope"));
}

#[test]
fn all_five_typed_models_round_trip_through_strict_binary_codecs() {
    let chain = ChainDatabaseSnapshot::new(0, None);
    let encoded = encode_chain_database_snapshot(&chain)
        .unwrap_or_else(|error| panic!("chain encode failed: {error}"));
    assert_eq!(
        decode_chain_database_snapshot(&encoded)
            .unwrap_or_else(|error| panic!("chain decode failed: {error}")),
        chain
    );

    let runtime = RuntimeContext::try_new(
        VerifiedBlockRef::finalized(Hash32::from_bytes([21; 32]), 34),
        RuntimeVersion::new(55, 89),
        vec![0x6d, 0x65, 0x74, 0x61],
    )
    .unwrap_or_else(|error| panic!("runtime fixture failed: {error}"));
    let encoded = encode_runtime_context(&runtime)
        .unwrap_or_else(|error| panic!("runtime encode failed: {error}"));
    assert_eq!(
        decode_runtime_context(&encoded)
            .unwrap_or_else(|error| panic!("runtime decode failed: {error}")),
        runtime
    );

    let wallet = WalletState::empty();
    let encoded = encode_wallet_state(&wallet)
        .unwrap_or_else(|error| panic!("wallet encode failed: {error}"));
    assert_eq!(
        decode_wallet_state(&encoded)
            .unwrap_or_else(|error| panic!("wallet decode failed: {error}")),
        wallet
    );

    let history = TransactionHistoryState::try_new(0, Vec::new(), Vec::new(), Vec::new())
        .unwrap_or_else(|error| panic!("history fixture failed: {error}"));
    let encoded = encode_transaction_history_state(&history)
        .unwrap_or_else(|error| panic!("history encode failed: {error}"));
    assert_eq!(
        decode_transaction_history_state(&encoded)
            .unwrap_or_else(|error| panic!("history decode failed: {error}")),
        history
    );

    let secret_ref = secret_ref(1, 2, 3, 4);
    let secret = EncryptedSecretBlobSnapshot::empty();
    let encoded = encode_encrypted_secret_blob_snapshot(secret_ref, &secret)
        .unwrap_or_else(|error| panic!("secret encode failed: {error}"));
    assert_eq!(
        decode_encrypted_secret_blob_snapshot(secret_ref, &encoded)
            .unwrap_or_else(|error| panic!("secret decode failed: {error}")),
        secret
    );
}

fn secret_ref(wallet_index: u32, generation: u8, owner: u8, account: u8) -> SecretRef {
    SecretRef::account_mini_secret(
        wallet_index,
        VaultGeneration::from_bytes([generation; 16]),
        SecretOwner::from_bytes([owner; 16]),
        AccountId32::from_bytes([account; 32]),
    )
}

#[test]
fn encrypted_secret_records_bind_the_complete_secret_ref_even_for_tombstones() {
    let expected = secret_ref(7, 8, 9, 10);
    let sealed = EncryptedSecretBlobSnapshot::try_from_persisted_parts(
        1,
        EncryptedSecretBlobState::Sealed {
            provisioning_operation_id: [11; 16],
            envelope: EncryptedSecretEnvelope::try_new(
                1,
                Hash32Bytes::from_bytes([12; 32]),
                vec![13; 48],
            )
            .unwrap_or_else(|error| panic!("test envelope failed: {error}")),
        },
    )
    .unwrap_or_else(|error| panic!("sealed snapshot failed: {error}"));
    let tombstone = EncryptedSecretBlobSnapshot::try_from_persisted_parts(
        1,
        EncryptedSecretBlobState::Tombstone {
            cleanup_operation_id: [14; 16],
        },
    )
    .unwrap_or_else(|error| panic!("tombstone snapshot failed: {error}"));

    for snapshot in [&sealed, &tombstone] {
        let encoded = encode_encrypted_secret_blob_snapshot(expected, snapshot)
            .unwrap_or_else(|error| panic!("secret record encode failed: {error}"));
        assert_eq!(
            decode_encrypted_secret_blob_snapshot(expected, &encoded)
                .unwrap_or_else(|error| panic!("same-ref decode failed: {error}")),
            *snapshot
        );

        for crossed in [
            secret_ref(8, 8, 9, 10),
            secret_ref(7, 7, 9, 10),
            secret_ref(7, 8, 8, 10),
            secret_ref(7, 8, 9, 11),
        ] {
            assert_eq!(
                decode_encrypted_secret_blob_snapshot(crossed, &encoded)
                    .err()
                    .unwrap_or_else(|| panic!("crossed SecretRef must fail"))
                    .ffi_code(),
                CitizenSdkErrorCode::Integrity
            );
        }
    }
}

#[test]
fn encrypted_secret_record_rejects_truncation_and_trailing_bytes() {
    let secret_ref = secret_ref(1, 2, 3, 4);
    let snapshot = EncryptedSecretBlobSnapshot::try_from_persisted_parts(
        1,
        EncryptedSecretBlobState::Tombstone {
            cleanup_operation_id: [5; 16],
        },
    )
    .unwrap_or_else(|error| panic!("snapshot failed: {error}"));
    let encoded = encode_encrypted_secret_blob_snapshot(secret_ref, &snapshot)
        .unwrap_or_else(|error| panic!("encode failed: {error}"));

    let mut truncated = encoded.clone();
    let _ = truncated.pop();
    assert!(decode_encrypted_secret_blob_snapshot(secret_ref, &truncated).is_err());

    let mut trailing = encoded;
    trailing.push(0);
    assert!(decode_encrypted_secret_blob_snapshot(secret_ref, &trailing).is_err());
}
