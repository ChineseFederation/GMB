use std::sync::Mutex;

use crate::{error::EngineError, transaction_builder::TransactionBuilder};
use citizen_sdk_contracts::{
    AccountId32, AccountNonce, AccountNonceSource, ChainIdentity, ChainSigner, ContractError,
    ContractErrorCode, ContractFuture, ContractStream, DerivationJunction, ExportedChainState,
    ExtrinsicWatchEvent, FinalizedBlockRef, Hash32, RuntimeContext, RuntimeVersion, SecretBuffer,
    SignedExtrinsic, Sr25519PublicKey, Sr25519Signature, StateImportReceipt, SubmittedExtrinsic,
    VerifiedBlockRef, VerifiedChainClient,
};
use citizen_signer::Sr25519SoftwareSigner;
use serde_json::Value as JsonValue;

const METADATA_HEX: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex");
const VECTOR_JSON: &str =
    include_str!("../../../test/transaction/fixtures/citizenchain-transfer-build-v1.json");

struct BuildClient {
    identity: ChainIdentity,
    best: VerifiedBlockRef,
    runtime_block: VerifiedBlockRef,
    metadata: Vec<u8>,
}

impl BuildClient {
    fn from_vector(vector: &JsonValue) -> Self {
        let runtime = &vector["runtime"];
        let best = VerifiedBlockRef::best(
            hash32(&runtime["best_block_hash"]),
            runtime["best_block_number"]
                .as_u64()
                .unwrap_or_else(|| panic!("best block number is not u64")),
        );
        Self {
            identity: ChainIdentity::citizenchain(),
            best,
            runtime_block: best,
            metadata: decode_hex(METADATA_HEX),
        }
    }
}

impl VerifiedChainClient for BuildClient {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity> {
        let identity = self.identity.clone();
        Box::pin(async move { Ok(identity) })
    }

    fn get_best_head(&self) -> ContractFuture<'_, VerifiedBlockRef> {
        let best = self.best;
        Box::pin(async move { Ok(best) })
    }

    fn get_finalized_head(&self) -> ContractFuture<'_, FinalizedBlockRef> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "transaction builder test does not read finalized head",
            ))
        })
    }

    fn get_storage_at(
        &self,
        _block: VerifiedBlockRef,
        _key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "transaction builder test does not read storage",
            ))
        })
    }

    fn get_storage_batch_at(
        &self,
        _block: VerifiedBlockRef,
        _keys: Vec<Vec<u8>>,
    ) -> ContractFuture<'_, Vec<Option<Vec<u8>>>> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "transaction builder test does not read storage batch",
            ))
        })
    }

    fn get_runtime_context_at(
        &self,
        _block: VerifiedBlockRef,
    ) -> ContractFuture<'_, RuntimeContext> {
        let block = self.runtime_block;
        let metadata = self.metadata.clone();
        Box::pin(async move { RuntimeContext::try_new(block, RuntimeVersion::new(0, 0), metadata) })
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
                "transaction builder test does not submit",
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
                "transaction builder test does not export",
            ))
        })
    }

    fn import_state(&self, _state: ExportedChainState) -> ContractFuture<'_, StateImportReceipt> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "transaction builder test does not import",
            ))
        })
    }
}

struct FixedNonceSource {
    returned_account: Option<AccountId32>,
    returned_block: Option<VerifiedBlockRef>,
    value: u64,
}

impl AccountNonceSource for FixedNonceSource {
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

struct FixedSigner {
    public_key: Sr25519PublicKey,
    signature: Sr25519Signature,
    verify_result: bool,
    signed_messages: Mutex<Vec<Vec<u8>>>,
}

impl FixedSigner {
    fn from_vector(vector: &JsonValue) -> Self {
        Self {
            public_key: Sr25519PublicKey::from_bytes(fixed_bytes(string(
                &vector["transfer"]["source_account_id"],
            ))),
            signature: Sr25519Signature::from_bytes(fixed_bytes(string(
                &vector["public_test_signature"]["signature"],
            ))),
            verify_result: true,
            signed_messages: Mutex::new(Vec::new()),
        }
    }
}

impl ChainSigner for FixedSigner {
    fn derive_hard<'a>(
        &'a self,
        _parent: &'a SecretBuffer,
        _junction: DerivationJunction,
    ) -> ContractFuture<'a, SecretBuffer> {
        Box::pin(async {
            Err(ContractError::new(
                ContractErrorCode::Unsupported,
                "fixed transaction signer does not derive",
            ))
        })
    }

    fn public_key<'a>(&'a self, _secret: &'a SecretBuffer) -> ContractFuture<'a, Sr25519PublicKey> {
        let public_key = self.public_key;
        Box::pin(async move { Ok(public_key) })
    }

    fn sign<'a>(
        &'a self,
        _secret: &'a SecretBuffer,
        message: Vec<u8>,
    ) -> ContractFuture<'a, Sr25519Signature> {
        self.signed_messages
            .lock()
            .unwrap_or_else(|error| panic!("message lock poisoned: {error}"))
            .push(message);
        let signature = self.signature;
        Box::pin(async move { Ok(signature) })
    }

    fn verify(
        &self,
        public_key: Sr25519PublicKey,
        message: Vec<u8>,
        signature: Sr25519Signature,
    ) -> ContractFuture<'_, bool> {
        let message_was_signed = self.verify_result
            && public_key == self.public_key
            && signature == self.signature
            && self
                .signed_messages
                .lock()
                .unwrap_or_else(|error| panic!("message lock poisoned: {error}"))
                .last()
                .is_some_and(|signed| signed == &message);
        Box::pin(async move {
            if !message_was_signed {
                return Ok(false);
            }
            Sr25519SoftwareSigner
                .verify(public_key, message, signature)
                .await
        })
    }
}

#[test]
fn production_metadata_build_matches_the_frozen_immortal_v4_vector() {
    let vector = vector();
    let client = BuildClient::from_vector(&vector);
    let nonce = FixedNonceSource {
        returned_account: None,
        returned_block: None,
        value: vector["runtime"]["nonce"]
            .as_u64()
            .unwrap_or_else(|| panic!("nonce is not u64")),
    };
    let signer = FixedSigner::from_vector(&vector);
    let secret = SecretBuffer::try_new(vec![0x99; 32])
        .unwrap_or_else(|error| panic!("secret fixture failed: {error}"));
    let transfer = &vector["transfer"];
    let build = futures::executor::block_on(
        TransactionBuilder::new(&client, &nonce, &signer).build_transfer_with_remark(
            &secret,
            account_id(&transfer["source_account_id"]),
            account_id(&transfer["destination_account_id"]),
            integer(&transfer["amount_fen"]),
            string(&transfer["remark_utf8"]),
        ),
    )
    .unwrap_or_else(|error| panic!("transaction build failed: {error}"));

    let expected = &vector["expected"];
    assert_eq!(
        hex(build.signed().payload().call_data()),
        string(&expected["call_data"])
    );
    assert_eq!(
        hex(build.signed().payload().signing_message()),
        string(&expected["signing_message"])
    );
    assert_eq!(
        hex(build.signed().extrinsic_bytes()),
        string(&expected["signed_extrinsic"])
    );
    assert_eq!(
        build.source_account_id(),
        account_id(&transfer["source_account_id"])
    );
    assert_eq!(
        build.call().destination(),
        account_id(&transfer["destination_account_id"])
    );
    assert_eq!(build.call().amount_fen(), integer(&transfer["amount_fen"]));
    assert_eq!(build.call().remark(), string(&transfer["remark_utf8"]));
    assert_eq!(build.signed().payload().block(), client.best);
    assert_eq!(build.signed().payload().nonce(), nonce.value);
    assert_eq!(
        build.signed().payload().genesis_hash(),
        ChainIdentity::citizenchain().genesis_hash()
    );
    assert_eq!(build.signed().signature(), signer.signature);
}

#[test]
fn production_sr25519_signer_stays_inside_rust_and_verifies_the_built_payload() {
    let vector = vector();
    let client = BuildClient::from_vector(&vector);
    let nonce = FixedNonceSource {
        returned_account: None,
        returned_block: None,
        value: 9,
    };
    let signer = Sr25519SoftwareSigner;
    let secret = SecretBuffer::try_new(vec![0x71; 32])
        .unwrap_or_else(|error| panic!("secret fixture failed: {error}"));
    let public_key = futures::executor::block_on(signer.public_key(&secret))
        .unwrap_or_else(|error| panic!("public key failed: {error}"));
    let source = AccountId32::from_bytes(*public_key.as_bytes());
    let destination = AccountId32::from_bytes([0x72; 32]);
    let build = futures::executor::block_on(
        TransactionBuilder::new(&client, &nonce, &signer).build_transfer_with_remark(
            &secret,
            source,
            destination,
            1,
            "Rust-only secret",
        ),
    )
    .unwrap_or_else(|error| panic!("real signer build failed: {error}"));
    let verifies = futures::executor::block_on(signer.verify(
        public_key,
        build.signed().payload().signing_message().to_vec(),
        build.signed().signature(),
    ))
    .unwrap_or_else(|error| panic!("signature verification failed: {error}"));
    assert!(verifies);
    assert_eq!(build.signed().payload().signer_account_id(), source);
    assert!(!build.signed().extrinsic_bytes().is_empty());
}

#[test]
fn source_secret_nonce_and_runtime_context_must_all_share_one_identity() {
    let vector = vector();
    let source = account_id(&vector["transfer"]["source_account_id"]);
    let destination = account_id(&vector["transfer"]["destination_account_id"]);
    let secret = SecretBuffer::try_new(vec![0x99; 32])
        .unwrap_or_else(|error| panic!("secret fixture failed: {error}"));

    let client = BuildClient::from_vector(&vector);
    let nonce = FixedNonceSource {
        returned_account: Some(AccountId32::from_bytes([0x51; 32])),
        returned_block: None,
        value: 7,
    };
    let signer = FixedSigner::from_vector(&vector);
    assert_integrity(futures::executor::block_on(
        TransactionBuilder::new(&client, &nonce, &signer).build_transfer_with_remark(
            &secret,
            source,
            destination,
            1,
            "nonce mismatch",
        ),
    ));

    let mut client = BuildClient::from_vector(&vector);
    client.runtime_block = VerifiedBlockRef::best(Hash32::from_bytes([0x52; 32]), 78);
    let nonce = FixedNonceSource {
        returned_account: None,
        returned_block: None,
        value: 7,
    };
    let error = futures::executor::block_on(
        TransactionBuilder::new(&client, &nonce, &signer).build_transfer_with_remark(
            &secret,
            source,
            destination,
            1,
            "runtime mismatch",
        ),
    )
    .err()
    .unwrap_or_else(|| panic!("runtime block mismatch must fail"));
    assert!(matches!(error, EngineError::BlockContextMismatch(_)));
}

#[test]
fn signer_public_key_mismatch_and_failed_self_verification_are_rejected() {
    let vector = vector();
    let client = BuildClient::from_vector(&vector);
    let nonce = FixedNonceSource {
        returned_account: None,
        returned_block: None,
        value: 7,
    };
    let source = account_id(&vector["transfer"]["source_account_id"]);
    let destination = account_id(&vector["transfer"]["destination_account_id"]);
    let secret = SecretBuffer::try_new(vec![0x99; 32])
        .unwrap_or_else(|error| panic!("secret fixture failed: {error}"));

    let mut signer = FixedSigner::from_vector(&vector);
    signer.public_key = Sr25519PublicKey::from_bytes([0x61; 32]);
    let error = futures::executor::block_on(
        TransactionBuilder::new(&client, &nonce, &signer).build_transfer_with_remark(
            &secret,
            source,
            destination,
            1,
            "public mismatch",
        ),
    )
    .err()
    .unwrap_or_else(|| panic!("public mismatch must fail"));
    assert!(
        matches!(error, EngineError::Contract(ref value) if value.code() == ContractErrorCode::InvalidArgument)
    );

    let mut signer = FixedSigner::from_vector(&vector);
    signer.verify_result = false;
    assert_integrity(futures::executor::block_on(
        TransactionBuilder::new(&client, &nonce, &signer).build_transfer_with_remark(
            &secret,
            source,
            destination,
            1,
            "bad signature",
        ),
    ));
}

fn vector() -> JsonValue {
    serde_json::from_str(VECTOR_JSON)
        .unwrap_or_else(|error| panic!("transfer build vector JSON failed: {error}"))
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
