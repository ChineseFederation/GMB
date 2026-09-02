use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
};

use citizen_sdk_contracts::{
    AccountId32, AccountNonce, AccountNonceSource, ChainIdentity, ContractError, ContractErrorCode,
    ContractFuture, ContractStream, ExportedChainState, ExtrinsicWatchEvent, FinalizedBlockRef,
    Hash32, RuntimeContext, RuntimeVersion, SignedExtrinsic, StateImportReceipt,
    SubmittedExtrinsic, VerifiedBlockRef, VerifiedChainClient,
};
use citizen_sdk_engine::{
    account_state::{
        decode_best_fee_snapshot, decode_finalized_account_balance, system_account_storage_key,
        AccountStateService,
    },
    EngineError,
};
use serde_json::Value as JsonValue;
use subxt_core::{ext::codec::Decode, Metadata};

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex");
const VECTOR_JSON: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-balance-fee-v1.json");

struct TestClient {
    identity: ChainIdentity,
    best: VerifiedBlockRef,
    finalized: FinalizedBlockRef,
    runtime_block_override: Option<VerifiedBlockRef>,
    metadata: Vec<u8>,
    values: Mutex<BTreeMap<Vec<u8>, Vec<u8>>>,
    batch_widths: Mutex<Vec<usize>>,
}

impl TestClient {
    fn new(best: VerifiedBlockRef, finalized: FinalizedBlockRef) -> Self {
        Self {
            identity: ChainIdentity::citizenchain(),
            best,
            finalized,
            runtime_block_override: None,
            metadata: decode_hex(METADATA_HEX),
            values: Mutex::new(BTreeMap::new()),
            batch_widths: Mutex::new(Vec::new()),
        }
    }

    fn insert(&self, key: Vec<u8>, value: Vec<u8>) {
        self.values
            .lock()
            .unwrap_or_else(|error| panic!("values lock poisoned: {error}"))
            .insert(key, value);
    }
}

impl VerifiedChainClient for TestClient {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity> {
        let identity = self.identity.clone();
        Box::pin(async move { Ok(identity) })
    }

    fn get_best_head(&self) -> ContractFuture<'_, VerifiedBlockRef> {
        let best = self.best;
        Box::pin(async move { Ok(best) })
    }

    fn get_finalized_head(&self) -> ContractFuture<'_, FinalizedBlockRef> {
        let finalized = self.finalized;
        Box::pin(async move { Ok(finalized) })
    }

    fn get_storage_at(
        &self,
        _block: VerifiedBlockRef,
        key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>> {
        let value = self
            .values
            .lock()
            .unwrap_or_else(|error| panic!("values lock poisoned: {error}"))
            .get(&key)
            .cloned();
        Box::pin(async move { Ok(value) })
    }

    fn get_storage_batch_at(
        &self,
        _block: VerifiedBlockRef,
        keys: Vec<Vec<u8>>,
    ) -> ContractFuture<'_, Vec<Option<Vec<u8>>>> {
        self.batch_widths
            .lock()
            .unwrap_or_else(|error| panic!("batch lock poisoned: {error}"))
            .push(keys.len());
        let values = self
            .values
            .lock()
            .unwrap_or_else(|error| panic!("values lock poisoned: {error}"));
        let result = keys
            .iter()
            .map(|key| values.get(key).cloned())
            .collect::<Vec<_>>();
        Box::pin(async move { Ok(result) })
    }

    fn get_runtime_context_at(
        &self,
        block: VerifiedBlockRef,
    ) -> ContractFuture<'_, RuntimeContext> {
        let returned_block = self.runtime_block_override.unwrap_or(block);
        let metadata = self.metadata.clone();
        Box::pin(async move {
            RuntimeContext::try_new(returned_block, RuntimeVersion::new(0, 0), metadata)
        })
    }

    fn get_block_extrinsics_at(
        &self,
        _block: VerifiedBlockRef,
    ) -> ContractFuture<'_, Vec<Vec<u8>>> {
        Box::pin(async { Ok(Vec::new()) })
    }

    fn submit_extrinsic(
        &self,
        _extrinsic: SignedExtrinsic,
    ) -> ContractFuture<'_, SubmittedExtrinsic> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "account-state test does not submit",
            ))
        })
    }

    fn watch_extrinsic(
        &self,
        _extrinsic: SignedExtrinsic,
    ) -> ContractStream<'_, ExtrinsicWatchEvent> {
        Box::pin(futures::stream::empty())
    }

    fn export_state(&self) -> ContractFuture<'_, ExportedChainState> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "account-state test does not export",
            ))
        })
    }

    fn import_state(&self, _state: ExportedChainState) -> ContractFuture<'_, StateImportReceipt> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "account-state test does not import",
            ))
        })
    }
}

struct TestNonceSource {
    returned_account: Option<AccountId32>,
    returned_block: Option<VerifiedBlockRef>,
    value: u64,
}

impl AccountNonceSource for TestNonceSource {
    fn account_next_index(
        &self,
        account_id: AccountId32,
        at_best: VerifiedBlockRef,
    ) -> ContractFuture<'_, AccountNonce> {
        let account = self.returned_account.unwrap_or(account_id);
        let block = self.returned_block.unwrap_or(at_best);
        let value = self.value;
        Box::pin(async move {
            AccountNonce::try_new(&ChainIdentity::citizenchain(), block, account, value)
        })
    }
}

#[test]
fn production_metadata_and_balance_bytes_match_the_frozen_vector() {
    let vector = vector();
    let account = account_id(&vector["account_balance"]["account_id"]);
    let finalized = finalized_from_vector(&vector);
    let best = VerifiedBlockRef::best(Hash32::from_bytes([0xbb; 32]), 78);
    let client = Arc::new(TestClient::new(best, finalized));

    let metadata = decode_metadata(&client.metadata);
    let key = system_account_storage_key(&metadata, account)
        .unwrap_or_else(|error| panic!("storage key failed: {error}"));
    assert_eq!(
        hex(&key),
        string(&vector["account_balance"]["system_account_storage_key"])
    );
    client.insert(
        key,
        decode_hex(string(&vector["account_balance"]["account_info"])),
    );

    let service = AccountStateService::new(client.as_ref(), None);
    let balance = futures::executor::block_on(service.finalized_account_balance(account))
        .unwrap_or_else(|error| panic!("balance failed: {error}"));
    assert_eq!(balance.block(), finalized);
    assert_eq!(balance.account_id(), account);
    assert_eq!(
        balance.free_fen(),
        integer(&vector["account_balance"]["free_fen"])
    );
    assert_eq!(
        balance.reserved_fen(),
        integer(&vector["account_balance"]["reserved_fen"])
    );
    assert_eq!(
        balance.total_fen(),
        integer(&vector["account_balance"]["total_fen"])
    );
}

#[test]
fn finalized_batch_deduplicates_provider_keys_but_preserves_order_and_duplicates() {
    let vector = vector();
    let first = account_id(&vector["account_balance"]["account_id"]);
    let second = AccountId32::from_bytes([0x55; 32]);
    let finalized = finalized_from_vector(&vector);
    let best = VerifiedBlockRef::best(Hash32::from_bytes([0xbb; 32]), 78);
    let client = Arc::new(TestClient::new(best, finalized));
    let metadata = decode_metadata(&client.metadata);
    client.insert(
        system_account_storage_key(&metadata, first)
            .unwrap_or_else(|error| panic!("storage key failed: {error}")),
        decode_hex(string(&vector["account_balance"]["account_info"])),
    );

    let service = AccountStateService::new(client.as_ref(), None);
    let balances =
        futures::executor::block_on(service.finalized_account_balances(vec![first, second, first]))
            .unwrap_or_else(|error| panic!("batch balance failed: {error}"));
    assert_eq!(balances.len(), 3);
    assert_eq!(balances[0], balances[2]);
    assert_eq!(balances[0].free_fen(), 123_456);
    assert_eq!(balances[1].account_id(), second);
    assert_eq!(balances[1].total_fen(), 0);
    assert_eq!(
        *client
            .batch_widths
            .lock()
            .unwrap_or_else(|error| panic!("batch lock poisoned: {error}")),
        vec![2]
    );
}

#[test]
fn missing_and_short_account_info_are_zero_without_partial_field_guessing() {
    let identity = ChainIdentity::citizenchain();
    let block = FinalizedBlockRef::from_parts(Hash32::from_bytes([0x91; 32]), 9);
    let account = AccountId32::from_bytes([0x22; 32]);
    for raw in [None, Some(&[0_u8; 47][..])] {
        let balance = decode_finalized_account_balance(&identity, block, account, raw)
            .unwrap_or_else(|error| panic!("zero balance decode failed: {error}"));
        assert_eq!(balance.free_fen(), 0);
        assert_eq!(balance.reserved_fen(), 0);
        assert_eq!(balance.total_fen(), 0);
    }
}

#[test]
fn fee_policy_is_decoded_only_from_one_exact_production_runtime_context() {
    let vector = vector();
    let fee = &vector["fee_policy"];
    let best = VerifiedBlockRef::best(
        hash32(&fee["best_block_hash"]),
        fee["best_block_number"]
            .as_u64()
            .unwrap_or_else(|| panic!("best block number is not u64")),
    );
    let finalized = FinalizedBlockRef::from_parts(Hash32::from_bytes([0xaa; 32]), 77);
    let client = TestClient::new(best, finalized);
    let service = AccountStateService::new(&client, None);
    let snapshot = futures::executor::block_on(service.best_fee_snapshot())
        .unwrap_or_else(|error| panic!("fee snapshot failed: {error}"));

    assert_eq!(snapshot.block(), best);
    assert_eq!(
        snapshot.policy().fee_rate_parts(),
        fee["fee_rate_parts"]
            .as_u64()
            .and_then(|value| u32::try_from(value).ok())
            .unwrap_or_else(|| panic!("fee rate is not u32"))
    );
    assert_eq!(
        snapshot.policy().minimum_fee_fen(),
        integer(&fee["minimum_fee_fen"])
    );
    assert_eq!(
        snapshot.existential_deposit_fen(),
        integer(&fee["existential_deposit_fen"])
    );
    assert_eq!(
        snapshot
            .minimum_self_pay_fen()
            .unwrap_or_else(|error| panic!("minimum self pay failed: {error}")),
        integer(&fee["minimum_self_pay_fen"])
    );
    for estimate in fee["estimates"]
        .as_array()
        .unwrap_or_else(|| panic!("estimates is not an array"))
    {
        assert_eq!(
            snapshot
                .estimate_fee_fen(integer(&estimate["amount_fen"]))
                .unwrap_or_else(|error| panic!("fee estimate failed: {error}")),
            integer(&estimate["fee_fen"])
        );
    }

    let finalized_context = RuntimeContext::try_new(
        VerifiedBlockRef::finalized(best.hash(), best.number()),
        RuntimeVersion::new(0, 0),
        client.metadata.clone(),
    )
    .unwrap_or_else(|error| panic!("finalized context fixture failed: {error}"));
    let error = decode_best_fee_snapshot(&ChainIdentity::citizenchain(), &finalized_context)
        .err()
        .unwrap_or_else(|| panic!("fee policy must reject a finalized-only anchor"));
    assert!(matches!(
        error,
        EngineError::Contract(ref value) if value.code() == ContractErrorCode::InvalidArgument
    ));
}

#[test]
fn nonce_is_exact_best_runtime_typed_and_cross_block_or_cross_account_results_are_rejected() {
    let account = AccountId32::from_bytes([0x31; 32]);
    let best = VerifiedBlockRef::best(Hash32::from_bytes([0x32; 32]), 32);
    let finalized = FinalizedBlockRef::from_parts(Hash32::from_bytes([0x30; 32]), 30);
    let client = TestClient::new(best, finalized);
    let valid_source = TestNonceSource {
        returned_account: None,
        returned_block: None,
        value: 8,
    };
    let service = AccountStateService::new(&client, Some(&valid_source));
    let nonce = futures::executor::block_on(service.account_next_index(account))
        .unwrap_or_else(|error| panic!("nonce failed: {error}"));
    assert_eq!(nonce.account_id(), account);
    assert_eq!(nonce.best_block(), best);
    assert_eq!(nonce.value(), 8);

    let wrong_account = TestNonceSource {
        returned_account: Some(AccountId32::from_bytes([0x44; 32])),
        returned_block: None,
        value: 8,
    };
    let service = AccountStateService::new(&client, Some(&wrong_account));
    assert_integrity(futures::executor::block_on(
        service.account_next_index(account),
    ));

    let wrong_block = TestNonceSource {
        returned_account: None,
        returned_block: Some(VerifiedBlockRef::best(Hash32::from_bytes([0x45; 32]), 33)),
        value: 8,
    };
    let service = AccountStateService::new(&client, Some(&wrong_block));
    assert_integrity(futures::executor::block_on(
        service.account_next_index(account),
    ));
}

#[test]
fn mismatched_runtime_context_is_rejected_before_chain_state_is_decoded() {
    let account = AccountId32::from_bytes([0x61; 32]);
    let best = VerifiedBlockRef::best(Hash32::from_bytes([0x62; 32]), 62);
    let finalized = FinalizedBlockRef::from_parts(Hash32::from_bytes([0x60; 32]), 60);
    let mut client = TestClient::new(best, finalized);
    client.runtime_block_override = Some(VerifiedBlockRef::finalized(
        Hash32::from_bytes([0x63; 32]),
        60,
    ));
    let service = AccountStateService::new(&client, None);
    let error = futures::executor::block_on(service.finalized_account_balance(account))
        .err()
        .unwrap_or_else(|| panic!("mismatched runtime block must fail"));
    assert!(matches!(error, EngineError::BlockContextMismatch(_)));
}

fn vector() -> JsonValue {
    serde_json::from_str(VECTOR_JSON)
        .unwrap_or_else(|error| panic!("balance/fee vector JSON failed: {error}"))
}

fn finalized_from_vector(vector: &JsonValue) -> FinalizedBlockRef {
    let balance = &vector["account_balance"];
    FinalizedBlockRef::from_parts(
        hash32(&balance["finalized_block_hash"]),
        balance["finalized_block_number"]
            .as_u64()
            .unwrap_or_else(|| panic!("finalized block number is not u64")),
    )
}

fn account_id(value: &JsonValue) -> AccountId32 {
    AccountId32::from_bytes(fixed_bytes(string(value)))
}

fn hash32(value: &JsonValue) -> Hash32 {
    Hash32::from_bytes(fixed_bytes(string(value)))
}

fn fixed_bytes<const N: usize>(value: &str) -> [u8; N] {
    let bytes = decode_hex(value);
    bytes
        .try_into()
        .unwrap_or_else(|bytes: Vec<u8>| panic!("expected {N} bytes, got {}", bytes.len()))
}

fn integer(value: &JsonValue) -> u128 {
    string(value)
        .parse()
        .unwrap_or_else(|error| panic!("u128 string failed: {error}"))
}

fn string(value: &JsonValue) -> &str {
    value
        .as_str()
        .unwrap_or_else(|| panic!("JSON value is not a string"))
}

fn decode_metadata(bytes: &[u8]) -> Metadata {
    let mut cursor = bytes;
    let metadata = Metadata::decode(&mut cursor)
        .unwrap_or_else(|error| panic!("metadata decode failed: {error}"));
    assert!(cursor.is_empty(), "metadata has trailing bytes");
    metadata
}

fn decode_hex(value: &str) -> Vec<u8> {
    let compact = value.trim().strip_prefix("0x").unwrap_or(value.trim());
    assert_eq!(compact.len() % 2, 0, "hex length must be even");
    (0..compact.len())
        .step_by(2)
        .map(|offset| {
            u8::from_str_radix(&compact[offset..offset + 2], 16)
                .unwrap_or_else(|error| panic!("hex decode failed at {offset}: {error}"))
        })
        .collect()
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn assert_integrity<T>(result: Result<T, EngineError>) {
    match result {
        Err(EngineError::Contract(error)) => {
            assert_eq!(error.code(), ContractErrorCode::Integrity)
        }
        Err(other) => panic!("unexpected error: {other}"),
        Ok(_) => panic!("integrity mismatch must fail"),
    }
}
