use subxt_core::{
    Metadata,
    config::SubstrateConfig,
    events::{Events, Phase},
    ext::{
        codec::{Compact, Decode},
        scale_value::{Composite, Value, ValueDef},
    },
};

use crate::error::EngineError;

/// Dynamically decoded `DispatchError` evidence from
/// `System.ExtrinsicFailed`.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DecodedDispatchFailure {
    /// Runtime variant name such as `BadOrigin` or `Module`.
    pub variant: String,
    /// Pallet index when the runtime returned `DispatchError::Module`.
    pub module_index: Option<u8>,
    /// First module error byte when the runtime returned `Module`.
    pub error_index: Option<u8>,
    /// Lossless diagnostic rendering of the dynamically decoded error value.
    pub detail: String,
}

/// Explicit System outcome for one exact extrinsic index.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DecodedSystemOutcome {
    /// The runtime emitted `System.ExtrinsicSuccess` for the target index.
    Success,
    /// The runtime emitted `System.ExtrinsicFailed` for the target index.
    Failed(DecodedDispatchFailure),
}

/// Decode all events and return the single explicit System outcome for
/// `extrinsic_index`.
///
/// The entire SCALE vector is consumed even after a candidate outcome is
/// found. A malformed trailing event, trailing byte, or contradictory second
/// outcome invalidates the evidence instead of allowing an early success.
pub fn decode_system_outcome(
    metadata_bytes: &[u8],
    events_bytes: &[u8],
    extrinsic_index: u32,
) -> Result<Option<DecodedSystemOutcome>, EngineError> {
    let metadata = decode_metadata_strict(metadata_bytes)?;
    let mut prefix_cursor = events_bytes;
    let declared_count = Compact::<u32>::decode(&mut prefix_cursor)
        .map_err(|error| EngineError::InvalidEvents(error.to_string()))?
        .0;
    let prefix_length = events_bytes.len().saturating_sub(prefix_cursor.len());
    let events = Events::<SubstrateConfig>::decode_from(events_bytes.to_vec(), metadata);
    if events.len() != declared_count {
        return Err(EngineError::InvalidEvents(
            "event vector length prefix was not preserved".to_owned(),
        ));
    }

    let mut decoded_count = 0_u32;
    let mut consumed = prefix_length;
    let mut outcome = None;
    for event in events.iter() {
        let event = event.map_err(|error| EngineError::InvalidEvents(error.to_string()))?;
        decoded_count = decoded_count.saturating_add(1);
        consumed = consumed.saturating_add(event.bytes().len());
        if event.phase() != Phase::ApplyExtrinsic(extrinsic_index)
            || event.pallet_name() != "System"
        {
            continue;
        }

        let candidate = match event.variant_name() {
            "ExtrinsicSuccess" => Some(DecodedSystemOutcome::Success),
            "ExtrinsicFailed" => {
                let fields = event
                    .field_values()
                    .map_err(|error| EngineError::InvalidEvents(error.to_string()))?;
                Some(DecodedSystemOutcome::Failed(decode_dispatch_failure(
                    &fields,
                )?))
            }
            _ => None,
        };
        if let Some(candidate) = candidate {
            if outcome.is_some() {
                return Err(EngineError::InvalidEvents(format!(
                    "multiple System execution outcomes for extrinsic index {extrinsic_index}"
                )));
            }
            outcome = Some(candidate);
        }
    }

    if decoded_count != declared_count || consumed != events_bytes.len() {
        return Err(EngineError::InvalidEvents(
            "event vector was not consumed exactly".to_owned(),
        ));
    }
    Ok(outcome)
}

fn decode_metadata_strict(bytes: &[u8]) -> Result<Metadata, EngineError> {
    let mut cursor = bytes;
    let metadata = Metadata::decode(&mut cursor)
        .map_err(|error| EngineError::InvalidMetadata(error.to_string()))?;
    if !cursor.is_empty() {
        return Err(EngineError::InvalidMetadata(
            "trailing bytes after RuntimeMetadataPrefixed".to_owned(),
        ));
    }
    Ok(metadata)
}

fn decode_dispatch_failure(
    fields: &Composite<u32>,
) -> Result<DecodedDispatchFailure, EngineError> {
    let Some(dispatch_error) = fields.values().next() else {
        return Err(EngineError::InvalidEvents(
            "ExtrinsicFailed has no DispatchError field".to_owned(),
        ));
    };
    let ValueDef::Variant(variant) = &dispatch_error.value else {
        return Err(EngineError::InvalidEvents(
            "ExtrinsicFailed first field is not DispatchError".to_owned(),
        ));
    };
    let (module_index, error_index) = if variant.name == "Module" {
        decode_module_error(&variant.values)
    } else {
        (None, None)
    };
    Ok(DecodedDispatchFailure {
        variant: variant.name.clone(),
        module_index,
        error_index,
        detail: format!("{dispatch_error:?}"),
    })
}

fn decode_module_error(values: &Composite<u32>) -> (Option<u8>, Option<u8>) {
    match values {
        Composite::Named(fields) => {
            let module_index = fields
                .iter()
                .find(|(name, _)| name == "index")
                .and_then(|(_, value)| value.as_u128())
                .and_then(|value| u8::try_from(value).ok());
            let error_index = fields
                .iter()
                .find(|(name, _)| name == "error")
                .and_then(|(_, value)| first_byte(value));
            (module_index, error_index)
        }
        Composite::Unnamed(fields) => {
            let module_index = fields
                .first()
                .and_then(Value::as_u128)
                .and_then(|value| u8::try_from(value).ok());
            let error_index = fields.get(1).and_then(first_byte);
            (module_index, error_index)
        }
    }
}

fn first_byte(value: &Value<u32>) -> Option<u8> {
    if let Some(value) = value.as_u128() {
        return u8::try_from(value).ok();
    }
    match &value.value {
        ValueDef::Composite(values) => values
            .values()
            .next()
            .and_then(Value::as_u128)
            .and_then(|value| u8::try_from(value).ok()),
        ValueDef::Variant(variant) => variant
            .values
            .values()
            .next()
            .and_then(first_byte),
        ValueDef::BitSequence(_) | ValueDef::Primitive(_) => None,
    }
}
