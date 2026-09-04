//! finalized `System.Events` 的严格 CitizenChain 事实解码。
//!
//! 本模块只接受目标块的准确 Runtime metadata，并要求完整消费规范 SCALE
//! `Vec<EventRecord<RuntimeEvent, Hash>>`。任何尾字节、非规范长度、字段类型漂移或
//! 同一 extrinsic 的矛盾 System 终态都会使整个块失败；禁止在未知字节中滑窗搜索
//! 账户、金额或备注来猜测转账。

use std::collections::BTreeMap;

use citizen_sdk_contracts::{
    AccountId32, ContractErrorCode, FinalizedBlockRef, RuntimeContext, MAX_TRANSFER_REMARK_BYTES,
    ONCHAIN_TRANSACTION_PALLET_INDEX, TRANSFER_WITH_REMARK_CALL_INDEX,
};
use subxt_core::{
    config::SubstrateConfig,
    events::{Events, Phase},
    ext::{
        codec::{Compact, Decode, Encode},
        scale_value::{Composite, Value, ValueDef},
    },
};

use crate::{
    error::EngineError,
    system_events::{decode_metadata_strict, decode_system_outcome, DecodedSystemOutcome},
};

/// `twox128("System") ++ twox128("Events")`；与 Substrate 存储合同及现有
/// CitizenApp 实现逐字节一致，不能由宿主输入替换。
pub(crate) const SYSTEM_EVENTS_STORAGE_KEY: [u8; 32] = [
    0x26, 0xaa, 0x39, 0x4e, 0xea, 0x56, 0x30, 0xe0, 0x7c, 0x48, 0xae, 0x0c, 0x95, 0x58, 0xce, 0xf7,
    0x80, 0xd4, 0x1e, 0x5e, 0x16, 0x05, 0x67, 0x65, 0xbc, 0x84, 0x61, 0x85, 0x10, 0x72, 0xc9, 0xd7,
];

/// 当前生产 CitizenChain Runtime v14 的三类转账字段递归类型指纹。
///
/// 这些值由已验证生产 metadata 的 `Metadata::type_hash` 固化。仅比较同一份 metadata
/// 中 call/event 的相对相等是不够的：二者若同时从 u128 漂成 u64 仍会“彼此相等”。
/// 绝对指纹使无转账事件的块也先验证 AccountId32/u128/BoundedVec<u8> 生产形状；正式
/// Runtime 若有有意升级，必须随 SDK 版本与生产 fixture 一起显式更新该合同。
const PRODUCTION_ACCOUNT_ID32_TYPE_HASH: [u8; 32] = [
    0x73, 0xe9, 0x0d, 0xdf, 0x58, 0x14, 0xca, 0x8b, 0x99, 0x1c, 0x9b, 0x9d, 0xe0, 0x42, 0x03, 0xfa,
    0x17, 0x35, 0x58, 0xa8, 0xd3, 0xcc, 0x7a, 0xa6, 0xf8, 0x17, 0xae, 0xe1, 0x63, 0x6c, 0x59, 0x87,
];
const PRODUCTION_BALANCE_U128_TYPE_HASH: [u8; 32] = [
    0x54, 0x9d, 0x8c, 0x04, 0x5d, 0x39, 0x1d, 0x85, 0x69, 0xc8, 0xd6, 0x1b, 0x90, 0xd0, 0xda, 0xa0,
    0x82, 0x6d, 0x65, 0x36, 0xd2, 0x88, 0x47, 0x3f, 0x31, 0xed, 0xea, 0x0f, 0xb2, 0x62, 0x94, 0x9c,
];
const PRODUCTION_BOUNDED_REMARK_TYPE_HASH: [u8; 32] = [
    0x6f, 0xc1, 0xbe, 0x65, 0x86, 0x5a, 0xbd, 0xa2, 0x95, 0x83, 0x1a, 0x9c, 0xf2, 0x07, 0x5f, 0x8c,
    0xbd, 0x2e, 0xe7, 0xb2, 0x8c, 0x21, 0xde, 0x37, 0xe5, 0x0c, 0x20, 0x8e, 0x45, 0xc3, 0xcd, 0xc1,
];

/// 一个 event record 中已经由 metadata 证明类型的转账事实。
#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct DecodedFinalizedTransfer {
    pub(crate) from_account_id: AccountId32,
    pub(crate) to_account_id: AccountId32,
    pub(crate) amount_fen: u128,
    pub(crate) event_record_index: u32,
    pub(crate) extrinsic_index: Option<u32>,
    pub(crate) source_pallet: &'static str,
    pub(crate) remark: Option<String>,
    /// 仅用于把已验证 Runtime bytes 交给 finalized 历史专用构造器；不得作为 call 输入。
    pub(crate) remark_bytes: Option<Vec<u8>>,
}

/// 一个准确 finalized 块中与钱包历史有关的完整事实。
#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct DecodedFinalizedEvents {
    transfers: Vec<DecodedFinalizedTransfer>,
    outcomes: BTreeMap<u32, DecodedSystemOutcome>,
}

impl DecodedFinalizedEvents {
    pub(crate) fn transfers(&self) -> &[DecodedFinalizedTransfer] {
        &self.transfers
    }

    pub(crate) fn outcome(&self, extrinsic_index: u32) -> Option<&DecodedSystemOutcome> {
        self.outcomes.get(&extrinsic_index)
    }
}

/// 使用同一准确块 metadata 严格解码完整 `System.Events`。
pub(crate) fn decode_finalized_events(
    block: FinalizedBlockRef,
    runtime_context: &RuntimeContext,
    events_bytes: &[u8],
) -> Result<DecodedFinalizedEvents, EngineError> {
    if runtime_context.block() != block.verified() {
        return Err(EngineError::BlockContextMismatch(
            "finalized System.Events 与 Runtime context 不属于同一准确块".to_owned(),
        ));
    }
    if events_bytes.is_empty() {
        return Err(EngineError::InvalidEvents(
            "finalized System.Events 不能为空".to_owned(),
        ));
    }

    let metadata = decode_metadata_strict(runtime_context.metadata())?;
    validate_transfer_metadata(&metadata)?;
    let mut prefix_cursor = events_bytes;
    let declared_count = Compact::<u32>::decode(&mut prefix_cursor)
        .map_err(|error| EngineError::InvalidEvents(error.to_string()))?
        .0;
    let prefix_length = events_bytes.len().saturating_sub(prefix_cursor.len());
    if events_bytes.get(..prefix_length) != Some(Compact(declared_count).encode().as_slice()) {
        return Err(EngineError::InvalidEvents(
            "event vector 使用了非规范 Compact 长度".to_owned(),
        ));
    }

    let events = Events::<SubstrateConfig>::decode_from(events_bytes.to_vec(), metadata);
    if events.len() != declared_count {
        return Err(EngineError::InvalidEvents(
            "event vector 长度前缀未被完整保持".to_owned(),
        ));
    }

    let mut decoded_count = 0_u32;
    let mut consumed = prefix_length;
    let mut transfers = Vec::new();
    let mut outcome_indices = BTreeMap::<u32, ()>::new();
    for event in events.iter() {
        let event = event.map_err(|error| EngineError::InvalidEvents(error.to_string()))?;
        let event_record_index = decoded_count;
        decoded_count = decoded_count.checked_add(1).ok_or_else(|| {
            EngineError::contract(ContractErrorCode::Integrity, "System.Events 数量溢出")
        })?;
        consumed = consumed.checked_add(event.bytes().len()).ok_or_else(|| {
            EngineError::contract(ContractErrorCode::Integrity, "System.Events 字节长度溢出")
        })?;

        let relevant_transfer = matches!(
            (event.pallet_name(), event.variant_name()),
            ("Balances", "Transfer") | ("OnchainTransaction", "TransferWithRemark")
        );
        let relevant_outcome = event.pallet_name() == "System"
            && matches!(event.variant_name(), "ExtrinsicSuccess" | "ExtrinsicFailed");
        if !relevant_transfer && !relevant_outcome {
            continue;
        }

        // Balances 可以由 on_initialize/on_finalize 产生，不得把这些合法流水
        // 错绑到某个 extrinsic；执行终态和带备注调用仍必须有准确的调用 index。
        let extrinsic_index = match event.phase() {
            Phase::ApplyExtrinsic(index) => Some(index),
            Phase::Initialization | Phase::Finalization if event.pallet_name() == "Balances" => {
                None
            }
            _ => {
                return Err(EngineError::InvalidEvents(format!(
                    "{}::{} 必须属于 Phase::ApplyExtrinsic",
                    event.pallet_name(),
                    event.variant_name()
                )))
            }
        };
        if relevant_outcome {
            let extrinsic_index = extrinsic_index.ok_or_else(|| {
                EngineError::InvalidEvents("System 终态缺少 extrinsic index".to_owned())
            })?;
            if outcome_indices.insert(extrinsic_index, ()).is_some() {
                return Err(EngineError::InvalidEvents(format!(
                    "extrinsic index {extrinsic_index} 存在多个 System 执行终态"
                )));
            }
            continue;
        }

        let fields = event
            .field_values()
            .map_err(|error| EngineError::InvalidEvents(error.to_string()))?;
        let decoded = match (event.pallet_name(), event.variant_name()) {
            ("Balances", "Transfer") => {
                decode_balances_transfer(&fields, event_record_index, extrinsic_index)?
            }
            ("OnchainTransaction", "TransferWithRemark") => {
                decode_transfer_with_remark(&fields, event_record_index, extrinsic_index)?
            }
            _ => {
                return Err(EngineError::InvalidEvents(
                    "相关转账事件在严格分派时失去 Runtime 身份".to_owned(),
                ));
            }
        };
        transfers.push(decoded);
    }

    if decoded_count != declared_count || consumed != events_bytes.len() {
        return Err(EngineError::InvalidEvents(
            "event vector 未被逐字节完整消费".to_owned(),
        ));
    }

    // DispatchError 的动态结构必须继续复用唯一严格 System 解码器；不能在这里维护
    // 第二套 variant 映射。该调用也会再次完整消费事件向量，避免部分解码提升终态。
    let mut outcomes = BTreeMap::new();
    for extrinsic_index in outcome_indices.into_keys() {
        let outcome =
            decode_system_outcome(runtime_context.metadata(), events_bytes, extrinsic_index)?
                .ok_or_else(|| {
                    EngineError::InvalidEvents(format!(
                        "extrinsic index {extrinsic_index} 的 System 终态在严格复核时丢失"
                    ))
                })?;
        outcomes.insert(extrinsic_index, outcome);
    }

    Ok(DecodedFinalizedEvents {
        transfers,
        outcomes,
    })
}

fn decode_balances_transfer(
    fields: &Composite<u32>,
    event_record_index: u32,
    extrinsic_index: Option<u32>,
) -> Result<DecodedFinalizedTransfer, EngineError> {
    let values = require_named_fields(fields, &["from", "to", "amount"], "Balances::Transfer")?;
    let from_account_id = decode_account_id(values[0], "Balances::Transfer.from")?;
    let to_account_id = decode_account_id(values[1], "Balances::Transfer.to")?;
    let amount_fen = decode_positive_amount(values[2], "Balances::Transfer.amount")?;
    reject_self_transfer(from_account_id, to_account_id, "Balances::Transfer")?;
    Ok(DecodedFinalizedTransfer {
        from_account_id,
        to_account_id,
        amount_fen,
        event_record_index,
        extrinsic_index,
        source_pallet: "Balances",
        remark: None,
        remark_bytes: None,
    })
}

fn decode_transfer_with_remark(
    fields: &Composite<u32>,
    event_record_index: u32,
    extrinsic_index: Option<u32>,
) -> Result<DecodedFinalizedTransfer, EngineError> {
    let values = require_named_fields(
        fields,
        &[
            "from_account_id",
            "beneficiary_account_id",
            "amount",
            "remark",
        ],
        "OnchainTransaction::TransferWithRemark",
    )?;
    let from_account_id = decode_account_id(
        values[0],
        "OnchainTransaction::TransferWithRemark.from_account_id",
    )?;
    let to_account_id = decode_account_id(
        values[1],
        "OnchainTransaction::TransferWithRemark.beneficiary_account_id",
    )?;
    let amount_fen =
        decode_positive_amount(values[2], "OnchainTransaction::TransferWithRemark.amount")?;
    reject_self_transfer(
        from_account_id,
        to_account_id,
        "OnchainTransaction::TransferWithRemark",
    )?;
    let remark_bytes =
        decode_byte_sequence(values[3], "OnchainTransaction::TransferWithRemark.remark")?;
    if remark_bytes.len() > MAX_TRANSFER_REMARK_BYTES {
        return Err(EngineError::InvalidEvents(
            "OnchainTransaction::TransferWithRemark.remark 超过 Runtime 合同上限".to_owned(),
        ));
    }
    // Runtime 合同是有界 bytes，而不是“必须 UTF-8”。完整保留 raw bytes 供历史值对象
    // 复核 99-byte 上限，并与 CitizenApp allowMalformed 显示一致生成标准 U+FFFD 投影。
    let remark = String::from_utf8_lossy(&remark_bytes).into_owned();
    Ok(DecodedFinalizedTransfer {
        from_account_id,
        to_account_id,
        amount_fen,
        event_record_index,
        extrinsic_index,
        source_pallet: "OnchainTransaction",
        remark: Some(remark),
        remark_bytes: Some(remark_bytes),
    })
}

fn require_named_fields<'a>(
    fields: &'a Composite<u32>,
    expected_names: &[&str],
    event_name: &str,
) -> Result<Vec<&'a Value<u32>>, EngineError> {
    let Composite::Named(fields) = fields else {
        return Err(EngineError::InvalidEvents(format!(
            "{event_name} 字段不是命名结构"
        )));
    };
    if fields.len() != expected_names.len()
        || fields
            .iter()
            .zip(expected_names)
            .any(|((actual, _), expected)| actual != expected)
    {
        return Err(EngineError::InvalidEvents(format!(
            "{event_name} 字段名称、顺序或数量偏离 CitizenChain Runtime"
        )));
    }
    Ok(fields.iter().map(|(_, value)| value).collect())
}

fn decode_account_id(value: &Value<u32>, field_name: &str) -> Result<AccountId32, EngineError> {
    let bytes = decode_byte_sequence(value, field_name)?;
    let bytes: [u8; 32] = bytes.try_into().map_err(|_| {
        EngineError::InvalidEvents(format!("{field_name} 必须是准确 32 字节 AccountId"))
    })?;
    Ok(AccountId32::from_bytes(bytes))
}

fn decode_byte_sequence(value: &Value<u32>, field_name: &str) -> Result<Vec<u8>, EngineError> {
    decode_byte_sequence_at_depth(value, field_name, 0)
}

fn decode_byte_sequence_at_depth(
    value: &Value<u32>,
    field_name: &str,
    depth: u8,
) -> Result<Vec<u8>, EngineError> {
    if depth > 2 {
        return Err(EngineError::InvalidEvents(format!(
            "{field_name} 的 newtype 包装层级偏离 CitizenChain Runtime"
        )));
    }
    match &value.value {
        ValueDef::Composite(Composite::Unnamed(values))
            if values.iter().all(|entry| entry.as_u128().is_some()) =>
        {
            values
                .iter()
                .map(|entry| {
                    entry
                        .as_u128()
                        .and_then(|value| u8::try_from(value).ok())
                        .ok_or_else(|| {
                            EngineError::InvalidEvents(format!("{field_name} 包含非 u8 元素"))
                        })
                })
                .collect()
        }
        // AccountId32 等 Runtime newtype 会保留一层单字段 wrapper；只解一条
        // 唯一路径，不遍历兄弟字段，也就不会退化成滑窗猜测。
        ValueDef::Composite(Composite::Unnamed(values)) if values.len() == 1 => {
            decode_byte_sequence_at_depth(&values[0], field_name, depth + 1)
        }
        ValueDef::Composite(Composite::Named(values)) if values.len() == 1 => {
            decode_byte_sequence_at_depth(&values[0].1, field_name, depth + 1)
        }
        ValueDef::BitSequence(_)
        | ValueDef::Composite(_)
        | ValueDef::Primitive(_)
        | ValueDef::Variant(_) => Err(EngineError::InvalidEvents(format!(
            "{field_name} 不是 Runtime 声明的字节序列"
        ))),
    }
}

/// 把事件字段的 metadata type hash 绑定到 SDK 已验证的生产绝对形状及
/// `OnchainTransaction::transfer_with_remark` 调用形状。
///
/// 动态 Value 的外观不足以证明原类型：u8/u64/u128 都会投影为 U128。这里同时要求
/// 正式字段 type name、准确字段数量/顺序、call/event 对应字段递归 hash 相等，并要求
/// 三个 hash 精确等于生产 AccountId32/u128/BoundedVec<u8> 指纹。因此 call 与 event
/// 同步漂移也会在读取 event value 前失败关闭。
fn validate_transfer_metadata(metadata: &subxt_core::Metadata) -> Result<(), EngineError> {
    let onchain = metadata
        .pallet_by_name("OnchainTransaction")
        .ok_or_else(|| invalid_metadata("缺少 OnchainTransaction pallet"))?;
    if onchain.index() != ONCHAIN_TRANSACTION_PALLET_INDEX {
        return Err(invalid_metadata(
            "OnchainTransaction pallet index 偏离 CitizenChain 已验证合同",
        ));
    }
    let onchain_event = onchain
        .event_variants()
        .and_then(|variants| {
            variants
                .iter()
                .find(|variant| variant.name == "TransferWithRemark")
        })
        .ok_or_else(|| invalid_metadata("缺少 OnchainTransaction::TransferWithRemark event"))?;
    let onchain_call = onchain
        .call_variant_by_name("transfer_with_remark")
        .ok_or_else(|| invalid_metadata("缺少 OnchainTransaction::transfer_with_remark call"))?;
    if onchain_call.index != TRANSFER_WITH_REMARK_CALL_INDEX {
        return Err(invalid_metadata(
            "OnchainTransaction::transfer_with_remark call index 偏离已验证合同",
        ));
    }
    let balances_event = metadata
        .pallet_by_name("Balances")
        .and_then(|pallet| {
            pallet
                .event_variants()
                .and_then(|variants| variants.iter().find(|variant| variant.name == "Transfer"))
        })
        .ok_or_else(|| invalid_metadata("缺少 Balances::Transfer event"))?;

    let onchain_event_contract = [
        ("from_account_id", "T::AccountId"),
        ("beneficiary_account_id", "T::AccountId"),
        ("amount", "BalanceOf<T>"),
        ("remark", "TransferRemarkOf<T>"),
    ];
    let onchain_call_contract = [
        ("beneficiary_account_id", "T::AccountId"),
        ("amount", "BalanceOf<T>"),
        ("remark", "TransferRemarkOf<T>"),
    ];
    let balances_event_contract = [
        ("from", "T::AccountId"),
        ("to", "T::AccountId"),
        ("amount", "T::Balance"),
    ];
    macro_rules! require_fields {
        ($fields:expr, $expected:expr, $label:literal) => {{
            let fields = $fields;
            let expected = $expected;
            if fields.len() != expected.len()
                || fields.iter().zip(expected).any(|(field, contract)| {
                    field.name.as_deref() != Some(contract.0)
                        || field.type_name.as_deref() != Some(contract.1)
                })
            {
                return Err(invalid_metadata(concat!(
                    $label,
                    " 字段名称、顺序、数量或声明类型偏离 CitizenChain Runtime"
                )));
            }
        }};
    }
    require_fields!(
        &onchain_event.fields,
        &onchain_event_contract,
        "OnchainTransaction::TransferWithRemark event"
    );
    require_fields!(
        &onchain_call.fields,
        &onchain_call_contract,
        "OnchainTransaction::transfer_with_remark call"
    );
    require_fields!(
        &balances_event.fields,
        &balances_event_contract,
        "Balances::Transfer event"
    );

    let event_hashes = onchain_event
        .fields
        .iter()
        .map(|field| metadata_type_hash(metadata, field.ty.id))
        .collect::<Result<Vec<_>, _>>()?;
    let call_hashes = onchain_call
        .fields
        .iter()
        .map(|field| metadata_type_hash(metadata, field.ty.id))
        .collect::<Result<Vec<_>, _>>()?;
    let balances_hashes = balances_event
        .fields
        .iter()
        .map(|field| metadata_type_hash(metadata, field.ty.id))
        .collect::<Result<Vec<_>, _>>()?;
    let account_hash = call_hashes[0];
    let amount_hash = call_hashes[1];
    let remark_hash = call_hashes[2];
    if account_hash != PRODUCTION_ACCOUNT_ID32_TYPE_HASH
        || amount_hash != PRODUCTION_BALANCE_U128_TYPE_HASH
        || remark_hash != PRODUCTION_BOUNDED_REMARK_TYPE_HASH
        || event_hashes[0] != account_hash
        || event_hashes[1] != account_hash
        || event_hashes[2] != amount_hash
        || event_hashes[3] != remark_hash
        || balances_hashes[0] != account_hash
        || balances_hashes[1] != account_hash
        || balances_hashes[2] != amount_hash
    {
        return Err(invalid_metadata(
            "转账 call/event 的 AccountId32/u128/BoundedVec<u8> type hash 偏离生产绝对合同",
        ));
    }
    Ok(())
}

fn metadata_type_hash(
    metadata: &subxt_core::Metadata,
    type_id: u32,
) -> Result<[u8; 32], EngineError> {
    metadata
        .type_hash(type_id)
        .ok_or_else(|| invalid_metadata("转账字段 metadata type id 无法解析"))
}

fn invalid_metadata(message: impl Into<String>) -> EngineError {
    EngineError::InvalidMetadata(message.into())
}

fn decode_positive_amount(value: &Value<u32>, field_name: &str) -> Result<u128, EngineError> {
    let amount = value
        .as_u128()
        .ok_or_else(|| EngineError::InvalidEvents(format!("{field_name} 不是无符号整数")))?;
    if amount == 0 {
        return Err(EngineError::InvalidEvents(format!("{field_name} 不能为零")));
    }
    Ok(amount)
}

fn reject_self_transfer(
    from: AccountId32,
    to: AccountId32,
    event_name: &str,
) -> Result<(), EngineError> {
    if from == to {
        return Err(EngineError::InvalidEvents(format!(
            "{event_name} 不接受自转账流水"
        )));
    }
    Ok(())
}
