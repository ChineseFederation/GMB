use std::{
    collections::BTreeSet,
    mem::{align_of, size_of},
};

use citizensdk::{
    CitizenSdkAccountBalanceInfo, CitizenSdkAccountId, CitizenSdkAccountNonceInfo,
    CitizenSdkFeeSnapshotInfo, CitizenSdkFinalizedTransferInfo, CitizenSdkHistoryCursorInfo,
    CitizenSdkHistoryInfo, CitizenSdkHistoryRecordInfo, CitizenSdkHostBoolResultV1,
    CitizenSdkHostBytesResultV1, CitizenSdkHostHash32, CitizenSdkHostId128,
    CitizenSdkHostPublicStoreV1, CitizenSdkHostRecordResultV1, CitizenSdkHostSecretRefV1,
    CitizenSdkHostSecretVaultV1, CitizenSdkHostSecureStoreV1, CitizenSdkHostServicesV1,
    CitizenSdkHostStatusResultV1, CitizenSdkHostVaultAvailabilityResultV1,
    CitizenSdkHostWalletKeyRefV1, CitizenSdkMutableBytesView, CitizenSdkPreparedWalletInfo,
    CitizenSdkResultKind, CitizenSdkU128, CitizenSdkWalletAccountInfo, CitizenSdkWalletProfileInfo,
    CitizenSdkWalletTransferInfo,
};

fn rust_exports(source: &str) -> BTreeSet<String> {
    let lines: Vec<_> = source.lines().collect();
    let mut exports = BTreeSet::new();
    for (index, line) in lines.iter().enumerate() {
        if line.trim() != "#[no_mangle]" {
            continue;
        }
        let declaration = lines
            .iter()
            .skip(index + 1)
            .find(|candidate| candidate.contains("fn "))
            .unwrap_or_else(|| panic!("no_mangle without function declaration"));
        let name = declaration
            .split("fn ")
            .nth(1)
            .and_then(|value| value.split(['(', '<']).next())
            .unwrap_or_else(|| panic!("cannot parse export: {declaration}"));
        assert!(exports.insert(name.to_owned()), "duplicate export {name}");
    }
    exports
}

fn header_functions(header: &str) -> BTreeSet<String> {
    let bytes = header.as_bytes();
    let mut functions = BTreeSet::new();
    let mut offset = 0;
    while let Some(relative) = header[offset..].find("citizensdk_") {
        let start = offset + relative;
        let mut end = start;
        while end < bytes.len()
            && (bytes[end].is_ascii_lowercase()
                || bytes[end].is_ascii_digit()
                || bytes[end] == b'_')
        {
            end += 1;
        }
        let following = header[end..].trim_start();
        if following.starts_with('(') {
            functions.insert(header[start..end].to_owned());
        }
        offset = end.max(start + 1);
    }
    functions
}

#[test]
fn base_exports_and_wallet_surface_are_exact_and_disjoint() {
    let old = rust_exports(include_str!("../src/lib.rs"));
    let wallet = rust_exports(include_str!("../src/wallet_abi.rs"));
    assert_eq!(old.len(), 36);
    assert_eq!(wallet.len(), 37);
    assert!(old.is_disjoint(&wallet));

    let expected_wallet: BTreeSet<_> = [
        "citizensdk_create_with_host",
        "citizensdk_validate_wallet_password",
        "citizensdk_validate_wallet_mnemonic",
        "citizensdk_wallet_word_suggestions",
        "citizensdk_get_finalized_account_balance",
        "citizensdk_get_account_nonce",
        "citizensdk_get_best_fee_snapshot",
        "citizensdk_get_wallet_profile",
        "citizensdk_prepare_wallet_creation",
        "citizensdk_prepared_wallet_copy_mnemonic",
        "citizensdk_prepared_wallet_release",
        "citizensdk_commit_wallet_creation",
        "citizensdk_import_wallet",
        "citizensdk_add_wallet_accounts",
        "citizensdk_set_active_wallet_account",
        "citizensdk_rename_wallet_account",
        "citizensdk_delete_wallet_account",
        "citizensdk_delete_wallet",
        "citizensdk_reconcile_wallet_cleanup",
        "citizensdk_sign_wallet_payload",
        "citizensdk_transfer_with_remark",
        "citizensdk_initialize_finalized_history",
        "citizensdk_sync_finalized_history_batch",
        "citizensdk_result_get_account_balance",
        "citizensdk_result_get_account_nonce",
        "citizensdk_result_get_fee_snapshot",
        "citizensdk_result_estimate_fee",
        "citizensdk_result_get_wallet_profile",
        "citizensdk_result_get_wallet_account_count",
        "citizensdk_result_get_wallet_account",
        "citizensdk_result_get_signature",
        "citizensdk_result_get_prepared_wallet",
        "citizensdk_result_get_wallet_transfer",
        "citizensdk_result_get_history_info",
        "citizensdk_result_get_history_cursor",
        "citizensdk_result_get_history_record",
        "citizensdk_result_get_finalized_transfer",
    ]
    .into_iter()
    .map(str::to_owned)
    .collect();
    assert_eq!(wallet, expected_wallet);

    let header = header_functions(include_str!("../../../include/citizensdk.h"));
    let all: BTreeSet<_> = old.union(&wallet).cloned().collect();
    assert_eq!(header, all);
}

#[test]
fn new_export_names_contain_no_rpc_key_or_raw_transaction_escape_hatch() {
    let wallet = rust_exports(include_str!("../src/wallet_abi.rs"));
    for symbol in wallet {
        for forbidden in [
            "rpc",
            "private_key",
            "mini_secret",
            "raw_signer",
            "signed_extrinsic",
        ] {
            assert!(!symbol.contains(forbidden), "forbidden export {symbol}");
        }
    }
}

#[test]
fn appended_result_values_and_portable_product_layouts_are_frozen() {
    assert_eq!(CitizenSdkResultKind::AccountBalance as u32, 9);
    assert_eq!(CitizenSdkResultKind::AccountNonce as u32, 10);
    assert_eq!(CitizenSdkResultKind::FeeSnapshot as u32, 11);
    assert_eq!(CitizenSdkResultKind::WalletProfile as u32, 12);
    assert_eq!(CitizenSdkResultKind::WalletAccounts as u32, 13);
    assert_eq!(CitizenSdkResultKind::Signature as u32, 14);
    assert_eq!(CitizenSdkResultKind::PreparedWallet as u32, 15);
    assert_eq!(CitizenSdkResultKind::WalletTransfer as u32, 16);
    assert_eq!(CitizenSdkResultKind::TransactionHistory as u32, 17);

    assert_eq!(size_of::<CitizenSdkU128>(), 16);
    assert_eq!(align_of::<CitizenSdkU128>(), 8);
    assert_eq!(size_of::<CitizenSdkAccountId>(), 32);
    assert_eq!(size_of::<CitizenSdkAccountBalanceInfo>(), 144);
    assert_eq!(size_of::<CitizenSdkAccountNonceInfo>(), 104);
    assert_eq!(size_of::<CitizenSdkFeeSnapshotInfo>(), 104);
    assert_eq!(size_of::<CitizenSdkWalletProfileInfo>(), 96);
    assert_eq!(size_of::<CitizenSdkWalletAccountInfo>(), 72);
    assert_eq!(size_of::<CitizenSdkPreparedWalletInfo>(), 16);
    assert_eq!(size_of::<CitizenSdkWalletTransferInfo>(), 144);
    assert_eq!(size_of::<CitizenSdkHistoryInfo>(), 32);
    assert_eq!(size_of::<CitizenSdkHistoryCursorInfo>(), 152);
    assert_eq!(size_of::<CitizenSdkHistoryRecordInfo>(), 320);
    assert_eq!(size_of::<CitizenSdkFinalizedTransferInfo>(), 216);
}

#[test]
fn host_v1_layout_matches_the_c_header_contract() {
    assert_eq!(size_of::<CitizenSdkMutableBytesView>(), 16);
    assert_eq!(size_of::<CitizenSdkHostHash32>(), 32);
    assert_eq!(size_of::<CitizenSdkHostId128>(), 16);
    assert_eq!(size_of::<CitizenSdkHostSecretRefV1>(), 80);
    assert_eq!(size_of::<CitizenSdkHostWalletKeyRefV1>(), 32);
    assert_eq!(size_of::<CitizenSdkHostRecordResultV1>(), 56);
    assert_eq!(size_of::<CitizenSdkHostStatusResultV1>(), 24);
    assert_eq!(size_of::<CitizenSdkHostBoolResultV1>(), 32);
    assert_eq!(size_of::<CitizenSdkHostVaultAvailabilityResultV1>(), 24);
    assert_eq!(size_of::<CitizenSdkHostBytesResultV1>(), 40);
    assert_eq!(size_of::<CitizenSdkHostPublicStoreV1>(), 72);
    assert_eq!(size_of::<CitizenSdkHostSecureStoreV1>(), 48);
    assert_eq!(size_of::<CitizenSdkHostSecretVaultV1>(), 64);
    assert_eq!(size_of::<CitizenSdkHostServicesV1>(), 32);
}

#[test]
fn header_exposes_mutable_dek_output_but_no_plaintext_completion_kind() {
    let types = include_str!("../../../include/citizensdk_types.h");
    assert!(types.contains("citizensdk_mutable_bytes_view_t plaintext_dek_out"));
    assert!(types.contains("CITIZENSDK_HOST_BYTES_WRAPPED_DEK"));
    assert!(!types.contains("HOST_BYTES_PLAINTEXT_DEK"));
    assert!(!types.contains("host_sign"));
}
