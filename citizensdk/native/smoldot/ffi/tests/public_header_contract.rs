//! 固定 CitizenSDK 第一版原生公共函数族，避免头文件在平台打包时静默缺符号。

const NODE_HEADER: &str = include_str!("../../include/smoldot.h");
const SDK_HEADER: &str = include_str!("../../include/citizensdk.h");

#[test]
fn node_header_keeps_required_light_client_operations() {
    for symbol in [
        "smoldot_client_init",
        "smoldot_add_chain",
        "smoldot_send_json_rpc",
        "smoldot_next_json_rpc_response",
        "smoldot_remove_chain",
        "smoldot_client_destroy",
        "smoldot_submit_extrinsic_async",
        "smoldot_get_status_snapshot_async",
        "smoldot_get_metadata_async",
        "smoldot_get_account_next_index_async",
    ] {
        assert!(NODE_HEADER.contains(symbol), "smoldot.h 缺少 {symbol}");
    }
}

#[test]
fn sdk_header_keeps_all_sr25519_operations() {
    assert!(SDK_HEADER.contains("#define CITIZENSDK_ABI_VERSION 1"));
    for symbol in [
        "citizen_sr25519_derive_hard",
        "citizen_sr25519_public_key",
        "citizen_sr25519_sign",
        "citizen_sr25519_verify",
    ] {
        assert!(SDK_HEADER.contains(symbol), "citizensdk.h 缺少 {symbol}");
    }
}
