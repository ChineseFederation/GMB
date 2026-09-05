use std::mem::{align_of, offset_of, size_of};

use citizensdk::{
    CitizenSdkAccountBalanceInfo, CitizenSdkAccountId, CitizenSdkAccountNonceInfo,
    CitizenSdkBlockRef, CitizenSdkBytesView, CitizenSdkCapabilitySnapshot,
    CitizenSdkCapabilityStatus, CitizenSdkCreateOptions, CitizenSdkEvent, CitizenSdkExecutionInfo,
    CitizenSdkExportedStateInfo, CitizenSdkFeeSnapshotInfo, CitizenSdkFinalizedTransferInfo,
    CitizenSdkHistoryCursorInfo, CitizenSdkHistoryInfo, CitizenSdkHistoryRecordInfo,
    CitizenSdkHistoryStatus, CitizenSdkHostBoolResultV1, CitizenSdkHostBytesKind,
    CitizenSdkHostBytesResultV1, CitizenSdkHostHash32, CitizenSdkHostId128,
    CitizenSdkHostPublicStoreV1, CitizenSdkHostRecordDomain, CitizenSdkHostRecordResultV1,
    CitizenSdkHostSecretKind, CitizenSdkHostSecretRefV1, CitizenSdkHostSecretVaultV1,
    CitizenSdkHostSecureStoreV1, CitizenSdkHostServicesV1, CitizenSdkHostStatusResultV1,
    CitizenSdkHostVaultAvailability, CitizenSdkHostVaultAvailabilityResultV1,
    CitizenSdkHostWalletKeyRefV1, CitizenSdkMutableBytesView, CitizenSdkPreparedWalletInfo,
    CitizenSdkResultInfo, CitizenSdkResultKind, CitizenSdkRuntimeContextInfo,
    CitizenSdkTransferDirection, CitizenSdkTransferResolution, CitizenSdkU128,
    CitizenSdkWalletAccountInfo, CitizenSdkWalletOrigin, CitizenSdkWalletProfileInfo,
    CitizenSdkWalletTransferInfo, CitizenSdkWalletWordCount, CitizenSdkWatchEventInfo,
    CITIZENSDK_ABI_VERSION, CITIZENSDK_CAPABILITY_COUNT, CITIZENSDK_HOST_DEK_BYTES,
};

macro_rules! assert_layout {
    ($type:ty, $size:expr, $align:expr, {$($field:ident: $offset:expr),+ $(,)?}) => {{
        assert_eq!(size_of::<$type>(), $size, concat!(stringify!($type), " size"));
        assert_eq!(align_of::<$type>(), $align, concat!(stringify!($type), " align"));
        $(
            assert_eq!(
                offset_of!($type, $field),
                $offset,
                concat!(stringify!($type), ".", stringify!($field), " offset"),
            );
        )+
    }};
}

#[test]
fn original_public_layout_remains_frozen() {
    assert_eq!(CITIZENSDK_ABI_VERSION, 1);
    assert_eq!(CITIZENSDK_CAPABILITY_COUNT, 10);

    assert_layout!(CitizenSdkBytesView, 16, 8, { data: 0, len: 8 });
    assert_layout!(CitizenSdkU128, 16, 8, { low: 0, high: 8 });
    assert_layout!(CitizenSdkAccountId, 32, 1, { bytes: 0 });
    assert_layout!(CitizenSdkCreateOptions, 88, 8, {
        struct_size: 0,
        abi_version: 4,
        asset_manifest: 8,
        chain_spec: 24,
        light_sync_state: 40,
        system_name: 56,
        system_version: 72,
    });
    assert_layout!(CitizenSdkBlockRef, 56, 8, {
        struct_size: 0,
        abi_version: 4,
        hash: 8,
        number: 40,
        finality: 48,
        reserved: 52,
    });
    assert_layout!(CitizenSdkCapabilityStatus, 16, 4, {
        name: 0,
        reason: 4,
        supported: 8,
        available: 9,
        enabled: 10,
        ready: 11,
        reserved: 12,
    });
    assert_layout!(CitizenSdkCapabilitySnapshot, 184, 8, {
        struct_size: 0,
        abi_version: 4,
        revision: 8,
        count: 16,
        reserved: 20,
        statuses: 24,
    });
    assert_layout!(CitizenSdkEvent, 48, 8, {
        struct_size: 0,
        abi_version: 4,
        event_type: 8,
        reserved: 12,
        sequence: 16,
        request_id: 24,
        result: 32,
        capability_revision: 40,
    });
    assert_layout!(CitizenSdkResultInfo, 32, 8, {
        struct_size: 0,
        abi_version: 4,
        error_code: 8,
        kind: 12,
        payload_len: 16,
        error_message_len: 24,
    });
    assert_layout!(CitizenSdkRuntimeContextInfo, 80, 8, {
        struct_size: 0,
        abi_version: 4,
        block: 8,
        spec_version: 64,
        transaction_version: 68,
        metadata_len: 72,
    });
    assert_layout!(CitizenSdkWatchEventInfo, 112, 8, {
        struct_size: 0,
        abi_version: 4,
        status: 8,
        peer_count: 12,
        has_block: 16,
        has_replacement_hash: 17,
        reserved: 18,
        block: 24,
        replacement_hash: 80,
    });
    assert_layout!(CitizenSdkExecutionInfo, 88, 8, {
        struct_size: 0,
        abi_version: 4,
        status: 8,
        reason_or_dispatch_variant: 12,
        has_block: 16,
        has_extrinsic_index: 17,
        has_module: 18,
        reserved: 19,
        block: 24,
        extrinsic_index: 80,
        pallet_index: 84,
        error_index: 85,
        reserved_tail: 86,
    });
    assert_layout!(CitizenSdkExportedStateInfo, 80, 8, {
        struct_size: 0,
        abi_version: 4,
        format_version: 8,
        reserved: 12,
        finalized: 16,
        database_len: 72,
    });
    assert_eq!(CitizenSdkCapabilitySnapshot::default().count, 10);
}

#[test]
fn host_v1_layout_and_constants_are_exact() {
    assert_eq!(CITIZENSDK_HOST_DEK_BYTES, 32);

    assert_layout!(CitizenSdkMutableBytesView, 16, 8, { data: 0, len: 8 });
    assert_layout!(CitizenSdkHostHash32, 32, 1, { bytes: 0 });
    assert_layout!(CitizenSdkHostId128, 16, 1, { bytes: 0 });
    assert_layout!(CitizenSdkHostSecretRefV1, 80, 4, {
        struct_size: 0,
        abi_version: 4,
        wallet_index: 8,
        kind: 12,
        generation: 16,
        owner: 32,
        account_id: 48,
    });
    assert_layout!(CitizenSdkHostWalletKeyRefV1, 32, 4, {
        struct_size: 0,
        abi_version: 4,
        wallet_index: 8,
        reserved: 12,
        generation: 16,
    });
    assert_layout!(CitizenSdkHostRecordResultV1, 56, 8, {
        struct_size: 0,
        abi_version: 4,
        host_operation_id: 8,
        error_code: 16,
        domain: 20,
        present: 24,
        reserved: 25,
        revision: 32,
        record: 40,
    });
    assert_layout!(CitizenSdkHostStatusResultV1, 24, 8, {
        struct_size: 0,
        abi_version: 4,
        host_operation_id: 8,
        error_code: 16,
        reserved: 20,
    });
    assert_layout!(CitizenSdkHostBoolResultV1, 32, 8, {
        struct_size: 0,
        abi_version: 4,
        host_operation_id: 8,
        error_code: 16,
        value: 20,
        reserved: 21,
    });
    assert_layout!(CitizenSdkHostVaultAvailabilityResultV1, 24, 8, {
        struct_size: 0,
        abi_version: 4,
        host_operation_id: 8,
        error_code: 16,
        availability: 20,
    });
    assert_layout!(CitizenSdkHostBytesResultV1, 40, 8, {
        struct_size: 0,
        abi_version: 4,
        host_operation_id: 8,
        error_code: 16,
        kind: 20,
        bytes: 24,
    });
    assert_layout!(CitizenSdkHostPublicStoreV1, 72, 8, {
        struct_size: 0,
        abi_version: 4,
        context: 8,
        chain_database_load: 16,
        chain_database_compare_and_swap: 24,
        runtime_cache_load: 32,
        runtime_cache_store: 40,
        runtime_cache_delete: 48,
        transaction_history_load: 56,
        transaction_history_compare_and_swap: 64,
    });
    assert_layout!(CitizenSdkHostSecureStoreV1, 48, 8, {
        struct_size: 0,
        abi_version: 4,
        context: 8,
        wallet_profile_load: 16,
        wallet_profile_compare_and_swap: 24,
        encrypted_secret_blob_load: 32,
        encrypted_secret_blob_compare_and_swap: 40,
    });
    assert_layout!(CitizenSdkHostSecretVaultV1, 64, 8, {
        struct_size: 0,
        abi_version: 4,
        context: 8,
        availability: 16,
        ensure_wallet_kek: 24,
        has_wallet_kek: 32,
        wrap_dek: 40,
        unwrap_dek: 48,
        retire_wallet_kek: 56,
    });
    assert_layout!(CitizenSdkHostServicesV1, 32, 8, {
        struct_size: 0,
        abi_version: 4,
        public_store: 8,
        secure_store: 16,
        secret_vault: 24,
    });

    assert_eq!(CitizenSdkHostRecordDomain::ChainDatabase as u32, 1);
    assert_eq!(CitizenSdkHostRecordDomain::RuntimeCache as u32, 2);
    assert_eq!(CitizenSdkHostRecordDomain::WalletProfile as u32, 3);
    assert_eq!(CitizenSdkHostRecordDomain::TransactionHistory as u32, 4);
    assert_eq!(CitizenSdkHostRecordDomain::EncryptedSecretBlob as u32, 5);
    assert_eq!(CitizenSdkHostSecretKind::AccountMiniSecret as u32, 1);
    assert_eq!(CitizenSdkHostVaultAvailability::Available as u32, 1);
    assert_eq!(
        CitizenSdkHostVaultAvailability::NoStrongUserAuthentication as u32,
        2
    );
    assert_eq!(CitizenSdkHostVaultAvailability::Unsupported as u32, 3);
    assert_eq!(CitizenSdkHostVaultAvailability::Unavailable as u32, 4);
    assert_eq!(CitizenSdkHostBytesKind::WrappedDek as u32, 1);
}

#[test]
fn account_wallet_and_history_layout_and_constants_are_exact() {
    assert_layout!(CitizenSdkAccountBalanceInfo, 144, 8, {
        struct_size: 0,
        abi_version: 4,
        block: 8,
        account_id: 64,
        free_fen: 96,
        reserved_fen: 112,
        total_fen: 128,
    });
    assert_layout!(CitizenSdkAccountNonceInfo, 104, 8, {
        struct_size: 0,
        abi_version: 4,
        best_block: 8,
        account_id: 64,
        nonce: 96,
    });
    assert_layout!(CitizenSdkFeeSnapshotInfo, 104, 8, {
        struct_size: 0,
        abi_version: 4,
        best_block: 8,
        fee_rate_parts: 64,
        reserved: 68,
        minimum_fee_fen: 72,
        existential_deposit_fen: 88,
    });
    assert_layout!(CitizenSdkWalletProfileInfo, 96, 8, {
        struct_size: 0,
        abi_version: 4,
        present: 8,
        origin: 12,
        wallet_index: 16,
        account_count: 20,
        created_at_millis: 24,
        master_account_id: 32,
        active_account_id: 64,
    });
    assert_layout!(CitizenSdkWalletAccountInfo, 72, 8, {
        struct_size: 0,
        abi_version: 4,
        index: 8,
        is_active: 12,
        account_id: 16,
        created_at_millis: 48,
        ss58_address_len: 56,
        name_len: 64,
    });
    assert_layout!(CitizenSdkPreparedWalletInfo, 16, 8, {
        struct_size: 0,
        abi_version: 4,
        prepared_wallet: 8,
    });
    assert_layout!(CitizenSdkWalletTransferInfo, 144, 8, {
        struct_size: 0,
        abi_version: 4,
        transaction_hash: 8,
        resolution: 40,
        has_execution: 44,
        execution: 48,
        pool_rejection_reason_len: 136,
    });
    assert_layout!(CitizenSdkHistoryInfo, 32, 8, {
        struct_size: 0,
        abi_version: 4,
        revision: 8,
        cursor_count: 16,
        record_count: 20,
        transfer_count: 24,
        reserved: 28,
    });
    assert_layout!(CitizenSdkHistoryCursorInfo, 152, 8, {
        struct_size: 0,
        abi_version: 4,
        account_id: 8,
        tracking_start_block: 40,
        last_synced_block: 96,
    });
    assert_layout!(CitizenSdkHistoryRecordInfo, 320, 8, {
        struct_size: 0,
        abi_version: 4,
        account_id: 8,
        transaction_hash: 40,
        nonce: 72,
        destination_account_id: 80,
        amount_fen: 112,
        status: 128,
        has_block: 132,
        block: 136,
        has_execution: 192,
        reserved: 196,
        execution: 200,
        created_at_millis: 288,
        updated_at_millis: 296,
        remark_len: 304,
        pool_rejection_reason_len: 312,
    });
    assert_layout!(CitizenSdkFinalizedTransferInfo, 216, 8, {
        struct_size: 0,
        abi_version: 4,
        tracked_account_id: 8,
        from_account_id: 40,
        to_account_id: 72,
        amount_fen: 104,
        block: 120,
        event_record_index: 176,
        has_extrinsic_index: 180,
        extrinsic_index: 184,
        direction: 188,
        source_pallet_len: 192,
        remark_display_len: 200,
        remark_bytes_len: 208,
    });

    assert_eq!(CitizenSdkResultKind::AccountBalance as u32, 9);
    assert_eq!(CitizenSdkResultKind::AccountNonce as u32, 10);
    assert_eq!(CitizenSdkResultKind::FeeSnapshot as u32, 11);
    assert_eq!(CitizenSdkResultKind::WalletProfile as u32, 12);
    assert_eq!(CitizenSdkResultKind::WalletAccounts as u32, 13);
    assert_eq!(CitizenSdkResultKind::Signature as u32, 14);
    assert_eq!(CitizenSdkResultKind::PreparedWallet as u32, 15);
    assert_eq!(CitizenSdkResultKind::WalletTransfer as u32, 16);
    assert_eq!(CitizenSdkResultKind::TransactionHistory as u32, 17);
    assert_eq!(CitizenSdkWalletWordCount::Words12 as u32, 12);
    assert_eq!(CitizenSdkWalletWordCount::Words18 as u32, 18);
    assert_eq!(CitizenSdkWalletWordCount::Words24 as u32, 24);
    assert_eq!(CitizenSdkWalletOrigin::Created as u32, 1);
    assert_eq!(CitizenSdkWalletOrigin::Imported as u32, 2);
    assert_eq!(CitizenSdkHistoryStatus::Pending as u32, 1);
    assert_eq!(CitizenSdkHistoryStatus::InBlock as u32, 2);
    assert_eq!(CitizenSdkHistoryStatus::PoolRejected as u32, 3);
    assert_eq!(CitizenSdkHistoryStatus::FinalizedSuccess as u32, 4);
    assert_eq!(CitizenSdkHistoryStatus::FinalizedFailed as u32, 5);
    assert_eq!(CitizenSdkTransferResolution::FinalizedSuccess as u32, 1);
    assert_eq!(CitizenSdkTransferResolution::FinalizedFailed as u32, 2);
    assert_eq!(CitizenSdkTransferResolution::PoolRejected as u32, 3);
    assert_eq!(CitizenSdkTransferDirection::Outgoing as u32, 1);
    assert_eq!(CitizenSdkTransferDirection::Incoming as u32, 2);
}
