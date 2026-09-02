// This black-box test intentionally crosses the exported raw-pointer ABI.
#![allow(unsafe_code)]

use citizensdk::{
    citizensdk_create, citizensdk_destroy, CitizenSdkBytesView, CitizenSdkCreateOptions,
    CitizenSdkErrorCode, CITIZENSDK_ABI_VERSION,
};

const MANIFEST: &[u8] = include_bytes!("../../../assets/citizenchain/manifest.json");
const CHAIN_SPEC: &[u8] = include_bytes!("../../../assets/citizenchain/chainspec.json");
const LIGHT_STATE: &[u8] = include_bytes!("../../../assets/citizenchain/light_sync_state.json");

fn view(bytes: &[u8]) -> CitizenSdkBytesView {
    CitizenSdkBytesView {
        data: bytes.as_ptr(),
        len: bytes.len() as u64,
    }
}

fn options() -> CitizenSdkCreateOptions {
    CitizenSdkCreateOptions {
        struct_size: std::mem::size_of::<CitizenSdkCreateOptions>() as u32,
        abi_version: CITIZENSDK_ABI_VERSION,
        asset_manifest: view(MANIFEST),
        chain_spec: view(CHAIN_SPEC),
        light_sync_state: view(LIGHT_STATE),
        system_name: view(b"CitizenSDK-test"),
        system_version: view(b"1.0.0"),
    }
}

#[test]
fn instance_handles_are_nonzero_monotonic_and_never_reused() {
    let mut first = 0;
    let mut second = 0;
    assert_eq!(
        unsafe { citizensdk_create(&options(), &mut first) },
        CitizenSdkErrorCode::Ok.as_i32()
    );
    assert_eq!(
        unsafe { citizensdk_create(&options(), &mut second) },
        CitizenSdkErrorCode::Ok.as_i32()
    );
    assert_ne!(first, 0);
    assert!(second > first);
    assert_eq!(
        unsafe { citizensdk_destroy(first) },
        CitizenSdkErrorCode::Ok.as_i32()
    );
    assert_eq!(
        unsafe { citizensdk_destroy(first) },
        CitizenSdkErrorCode::InvalidHandle.as_i32()
    );
    assert_eq!(
        unsafe { citizensdk_destroy(second) },
        CitizenSdkErrorCode::Ok.as_i32()
    );
}
