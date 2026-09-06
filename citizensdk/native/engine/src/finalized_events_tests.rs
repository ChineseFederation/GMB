//! 生产 CitizenChain metadata/events 的 finalized 严格解码合同。

#![allow(clippy::expect_used)]

use citizen_sdk_contracts::{
    FinalizedBlockRef, FinalizedTransferRecord, Hash32, RuntimeContext, RuntimeVersion,
    MAX_FINALIZED_REMARK_DISPLAY_BYTES,
};
use subxt_core::{
    config::SubstrateConfig,
    events::{Events, Phase},
    ext::codec::{Compact, Encode},
};

use crate::{
    finalized_events::decode_finalized_events,
    system_events::{decode_metadata_strict, DecodedSystemOutcome},
    EngineError,
};

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/citizenchain-runtime-v14-metadata.hex");
const EVENTS_HEX: &str =
    include_str!("../../../test/transaction/citizenchain-runtime-system-events.hex");
const SYSTEM_ONLY_METADATA_HEX: &str =
    include_str!("../../../test/transaction/substrate-v14-system-events-metadata.hex");

#[test]
fn production_fixture_decodes_exact_transfers_and_both_system_outcomes() {
    let block = finalized_block(0x91, 91);
    let context = runtime(block, METADATA_HEX);
    let decoded = decode_finalized_events(block, &context, &hex_bytes(EVENTS_HEX))
        .expect("生产 finalized 事件夹具必须严格解码");

    assert_eq!(decoded.transfers().len(), 2);
    let balances = &decoded.transfers()[0];
    assert_eq!(balances.event_record_index, 0);
    assert_eq!(balances.extrinsic_index, Some(0));
    assert_eq!(balances.source_pallet, "Balances");
    assert_eq!(balances.from_account_id.as_bytes(), &[0x11; 32]);
    assert_eq!(balances.to_account_id.as_bytes(), &[0x22; 32]);
    assert_eq!(balances.amount_fen, 123_456);
    assert_eq!(balances.remark, None);

    let business = &decoded.transfers()[1];
    assert_eq!(business.event_record_index, 1);
    assert_eq!(business.extrinsic_index, Some(0));
    assert_eq!(business.source_pallet, "OnchainTransaction");
    assert_eq!(business.from_account_id, balances.from_account_id);
    assert_eq!(business.to_account_id, balances.to_account_id);
    assert_eq!(business.amount_fen, balances.amount_fen);
    assert_eq!(
        business.remark.as_deref(),
        Some("CitizenSDK production Runtime fixture")
    );

    assert!(matches!(
        decoded.outcome(0),
        Some(DecodedSystemOutcome::Success)
    ));
    match decoded.outcome(1) {
        Some(DecodedSystemOutcome::Failed(failure)) => {
            assert_eq!(failure.variant, "BadOrigin");
            assert_eq!(failure.variant_index, 2);
            assert!(failure.module_index.is_none());
        }
        other => panic!("index 1 必须是 BadOrigin，实际为 {other:?}"),
    }
}

#[test]
fn decoder_rejects_cross_block_metadata_trailing_bytes_and_truncated_events() {
    let block = finalized_block(0x92, 92);
    let context = runtime(block, METADATA_HEX);
    let events = hex_bytes(EVENTS_HEX);

    let cross_block = decode_finalized_events(finalized_block(0x93, 92), &context, &events)
        .expect_err("跨块 Runtime context 必须失败关闭");
    assert!(matches!(cross_block, EngineError::BlockContextMismatch(_)));

    let mut trailing_metadata = hex_bytes(METADATA_HEX);
    trailing_metadata.push(0);
    let trailing_context = RuntimeContext::try_new(
        block.verified(),
        RuntimeVersion::new(100, 12),
        trailing_metadata,
    )
    .expect("RuntimeContext 值对象只负责非空检查");
    assert!(matches!(
        decode_finalized_events(block, &trailing_context, &events),
        Err(EngineError::InvalidMetadata(_))
    ));

    let mut trailing_events = events.clone();
    trailing_events.push(0);
    assert!(matches!(
        decode_finalized_events(block, &context, &trailing_events),
        Err(EngineError::InvalidEvents(_))
    ));

    let truncated = &events[..events.len() - 1];
    assert!(matches!(
        decode_finalized_events(block, &context, truncated),
        Err(EngineError::InvalidEvents(_))
    ));
}

#[test]
fn metadata_field_type_contract_drift_fails_before_event_values_are_trusted() {
    let block = finalized_block(0x95, 95);
    let mut metadata = hex_bytes(METADATA_HEX);
    replace_first_equal_length(
        &mut metadata,
        b"TransferRemarkOf<T>",
        b"TransferRemarkOf<X>",
    );
    let context = RuntimeContext::try_new(block.verified(), RuntimeVersion::new(100, 12), metadata)
        .expect("等长测试漂移仍是可解码候选 metadata");
    assert!(matches!(
        decode_finalized_events(block, &context, &hex_bytes(EVENTS_HEX)),
        Err(EngineError::InvalidMetadata(_))
    ));

    let unrelated = runtime(block, SYSTEM_ONLY_METADATA_HEX);
    assert!(matches!(
        decode_finalized_events(block, &unrelated, &hex_bytes(EVENTS_HEX)),
        Err(EngineError::InvalidMetadata(_)) | Err(EngineError::InvalidEvents(_))
    ));
}

#[test]
fn synchronized_call_and_event_portable_type_drift_still_fails_absolute_gate() {
    let block = finalized_block(0x97, 97);

    // Portable type id 6 是 call/event 共用的生产 u128。直接把底层 primitive 同步
    // 漂成 u64 后，相对 call/event hash 仍相等；只有生产绝对指纹能在事件解码前拒绝。
    let mut amount_metadata = hex_bytes(METADATA_HEX);
    replace_first_equal_length(
        &mut amount_metadata,
        &[0x18, 0x00, 0x00, 0x05, 0x07, 0x00],
        &[0x18, 0x00, 0x00, 0x05, 0x06, 0x00],
    );
    let amount_context = RuntimeContext::try_new(
        block.verified(),
        RuntimeVersion::new(100, 12),
        amount_metadata,
    )
    .expect("u128 到 u64 的 portable primitive 漂移仍是可解码 metadata");
    assert!(matches!(
        decode_finalized_events(block, &amount_context, &hex_bytes(EVENTS_HEX)),
        Err(EngineError::InvalidMetadata(_))
    ));

    // Portable type id 14 是 BoundedVec 内部 Vec<u8>。把序列元素同步改为现有 u32
    // 后 call/event 的 remark hash 仍一致，但不再是生产 BoundedVec<u8>，必须拒绝。
    let mut remark_metadata = hex_bytes(METADATA_HEX);
    replace_first_equal_length(
        &mut remark_metadata,
        &[0x38, 0x00, 0x00, 0x02, 0x08, 0x00],
        &[0x38, 0x00, 0x00, 0x02, 0x10, 0x00],
    );
    let remark_context = RuntimeContext::try_new(
        block.verified(),
        RuntimeVersion::new(100, 12),
        remark_metadata,
    )
    .expect("Vec<u8> 到 Vec<u32> 的 portable registry 漂移仍是可解码 metadata");
    assert!(matches!(
        decode_finalized_events(block, &remark_context, &hex_bytes(EVENTS_HEX)),
        Err(EngineError::InvalidMetadata(_))
    ));
}

#[test]
fn non_utf8_runtime_remark_uses_a_bounded_deterministic_lossy_projection() {
    let block = finalized_block(0x96, 96);
    let context = runtime(block, METADATA_HEX);
    let mut events = hex_bytes(EVENTS_HEX);
    let remark = b"CitizenSDK production Runtime fixture";
    let offset = events
        .windows(remark.len())
        .position(|window| window == remark)
        .expect("生产夹具必须含备注原始 bytes");
    events[offset] = 0xff;

    let decoded = decode_finalized_events(block, &context, &events)
        .expect("Runtime remark 是有界 bytes，非 UTF-8 仍是合法链事实");
    assert_eq!(
        decoded.transfers()[1].remark.as_deref(),
        Some("�itizenSDK production Runtime fixture")
    );
}

#[test]
fn runtime_remark_accepts_99_raw_invalid_bytes_but_rejects_100() {
    let block = finalized_block(0x98, 98);
    let context = runtime(block, METADATA_HEX);

    let accepted_raw = vec![0xff; 99];
    let accepted = replace_fixture_remark(hex_bytes(EVENTS_HEX), &accepted_raw);
    let decoded = decode_finalized_events(block, &context, &accepted)
        .expect("99 个任意 Runtime bytes 必须仍能进入 finalized 只读历史");
    let expected = "�".repeat(99);
    assert_eq!(
        decoded.transfers()[1].remark.as_deref(),
        Some(expected.as_str())
    );
    let transfer = &decoded.transfers()[1];
    let record = FinalizedTransferRecord::try_for_tracked_account_from_runtime_event(
        transfer.to_account_id,
        transfer.from_account_id,
        transfer.to_account_id,
        transfer.amount_fen,
        block,
        transfer.event_record_index,
        transfer.extrinsic_index,
        transfer.source_pallet,
        Some(&accepted_raw),
    )
    .expect("finalized 专用值对象必须接受 raw<=99 的标准 lossy 展示展开");
    assert_eq!(record.remark(), Some(expected.as_str()));
    assert_eq!(record.remark_bytes(), Some(accepted_raw.as_slice()));
    assert_eq!(record.remark().expect("必须有备注").len(), 99 * 3);
    assert_eq!(MAX_FINALIZED_REMARK_DISPLAY_BYTES, 99 * 3);
    let reconstructed = FinalizedTransferRecord::try_for_tracked_account_from_runtime_event(
        record.tracked_account_id(),
        record.from_account_id(),
        record.to_account_id(),
        record.amount_fen(),
        record.block(),
        record.event_record_index(),
        record.extrinsic_index(),
        record.source_pallet(),
        record.remark_bytes(),
    )
    .expect("平台 store 保存 raw bytes 后必须能确定性重建同一值对象");
    assert_eq!(reconstructed, record);

    let rejected_raw = vec![0xff; 100];
    let rejected = replace_fixture_remark(hex_bytes(EVENTS_HEX), &rejected_raw);
    assert!(matches!(
        decode_finalized_events(block, &context, &rejected),
        Err(EngineError::InvalidEvents(_))
    ));
    assert!(
        FinalizedTransferRecord::try_for_tracked_account_from_runtime_event(
            transfer.to_account_id,
            transfer.from_account_id,
            transfer.to_account_id,
            transfer.amount_fen,
            block,
            transfer.event_record_index,
            transfer.extrinsic_index,
            transfer.source_pallet,
            Some(&rejected_raw),
        )
        .is_err()
    );
}

#[test]
fn system_only_event_never_slides_unknown_bytes_into_a_transfer() {
    let block = finalized_block(0x94, 94);
    let context = runtime(block, METADATA_HEX);
    let fixture = hex_bytes(EVENTS_HEX);
    let metadata = decode_metadata_strict(context.metadata()).expect("生产 metadata 必须有效");
    let decoded_fixture = Events::<SubstrateConfig>::decode_from(fixture, metadata);
    let success = decoded_fixture
        .iter()
        .filter_map(Result::ok)
        .find(|event| {
            event.phase() == Phase::ApplyExtrinsic(0)
                && event.pallet_name() == "System"
                && event.variant_name() == "ExtrinsicSuccess"
        })
        .expect("生产夹具必须含 index 0 success");
    // 只保留一条正式 System 事件。即使 payload 偶然出现账户/金额字节，解码器也只能
    // 服从 metadata pallet/variant 身份，不能滑窗制造转账。
    let mut events = Compact(1_u32).encode();
    events.extend_from_slice(success.bytes());
    let decoded =
        decode_finalized_events(block, &context, &events).expect("System-only 规范事件必须可解码");
    assert!(decoded.transfers().is_empty());
    assert!(matches!(
        decoded.outcome(0),
        Some(DecodedSystemOutcome::Success)
    ));
}

#[test]
fn initialization_and_finalization_balances_preserve_absent_extrinsic_index() {
    let block = finalized_block(0x96, 96);
    let context = runtime(block, METADATA_HEX);
    let events = Events::<SubstrateConfig>::decode_from(
        hex_bytes(EVENTS_HEX),
        decode_metadata_strict(context.metadata())
            .unwrap_or_else(|error| panic!("测试夹具失败: {error}")),
    );
    let records: Vec<_> = events.iter().map(Result::unwrap).collect();
    // SCALE Phase::ApplyExtrinsic 占 5 字节；其它两个官方 phase 只占一字节。
    let mut bytes = Compact(6_u32).encode();
    for phase in [Phase::Initialization, Phase::Finalization] {
        bytes.extend(phase.encode());
        bytes.extend_from_slice(&records[0].bytes()[5..]);
    }
    for record in &records {
        bytes.extend_from_slice(record.bytes());
    }
    let decoded = decode_finalized_events(block, &context, &bytes)
        .unwrap_or_else(|error| panic!("测试夹具失败: {error}"));
    assert_eq!(decoded.transfers().len(), 4);
    assert_eq!(decoded.transfers()[0].extrinsic_index, None);
    assert_eq!(decoded.transfers()[1].extrinsic_index, None);
    assert_eq!(decoded.transfers()[2].extrinsic_index, Some(0));
    assert!(matches!(
        decoded.outcome(0),
        Some(DecodedSystemOutcome::Success)
    ));
    // 没有 index 的业务事件、成功和失败都不能用于确定执行结果。
    for record in &records[1..] {
        let mut invalid = Compact(1_u32).encode();
        invalid.extend(Phase::Initialization.encode());
        invalid.extend_from_slice(&record.bytes()[5..]);
        assert!(decode_finalized_events(block, &context, &invalid).is_err());
    }
}

fn runtime(block: FinalizedBlockRef, metadata_hex: &str) -> RuntimeContext {
    RuntimeContext::try_new(
        block.verified(),
        RuntimeVersion::new(100, 12),
        hex_bytes(metadata_hex),
    )
    .expect("Runtime fixture 必须有效")
}

fn finalized_block(byte: u8, number: u64) -> FinalizedBlockRef {
    FinalizedBlockRef::from_parts(Hash32::from_bytes([byte; 32]), number)
}

fn hex_bytes(value: &str) -> Vec<u8> {
    let value = value.trim();
    let body = value.strip_prefix("0x").expect("fixture 必须带 0x");
    assert_eq!(body.len() % 2, 0, "fixture hex 必须是偶数长度");
    body.as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            let text = std::str::from_utf8(pair).expect("fixture hex 必须是 ASCII");
            u8::from_str_radix(text, 16).expect("fixture 必须是 hex")
        })
        .collect()
}

fn replace_first_equal_length(bytes: &mut [u8], from: &[u8], to: &[u8]) {
    assert_eq!(from.len(), to.len(), "metadata 漂移测试必须保持 SCALE 长度");
    let offset = bytes
        .windows(from.len())
        .position(|window| window == from)
        .expect("metadata 必须含目标类型名");
    bytes[offset..offset + to.len()].copy_from_slice(to);
}

fn replace_fixture_remark(mut events: Vec<u8>, replacement: &[u8]) -> Vec<u8> {
    let original = b"CitizenSDK production Runtime fixture";
    let offset = events
        .windows(original.len())
        .position(|window| window == original)
        .expect("生产 events fixture 必须含目标备注");
    let original_prefix = Compact(original.len() as u32).encode();
    let prefix_offset = offset
        .checked_sub(original_prefix.len())
        .expect("备注前必须存在 SCALE Compact 长度");
    assert_eq!(
        &events[prefix_offset..offset],
        original_prefix.as_slice(),
        "fixture 备注必须紧跟规范 Compact 长度"
    );
    let mut encoded = Compact(replacement.len() as u32).encode();
    encoded.extend_from_slice(replacement);
    events.splice(prefix_offset..offset + original.len(), encoded);
    events
}
