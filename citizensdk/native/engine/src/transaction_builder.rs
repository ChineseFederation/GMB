//! CitizenChain `transfer_with_remark` 的准确 Runtime 构造、sr25519 签名与 extrinsic 编码。
//!
//! 本模块只公开产品无关的公民链转账原语。Runtime metadata、spec/transaction version、
//! genesis、准确 best Runtime nonce 和 call shape 会在同一构造路径中核对；秘密只以 Rust
//! [`SecretBuffer`] 借用进入 [`ChainSigner`]，不会进入语言绑定或公开构造轨迹。

use std::panic::{catch_unwind, AssertUnwindSafe};

use citizen_sdk_contracts::{
    AccountId32, AccountNonceSource, ChainSigner, ContractErrorCode, ImmortalSigningPayload,
    SecretBuffer, SignedExtrinsic, SignedTransactionBuild, TransferWithRemarkCall,
    VerifiedChainClient,
};
use subxt_core::{
    config::{substrate::H256, SubstrateConfig, SubstrateExtrinsicParamsBuilder},
    dynamic::Value,
    tx::{self, ClientState, RuntimeVersion as SubxtRuntimeVersion, TransactionVersion},
    utils::{AccountId32 as SubxtAccountId32, MultiSignature},
    Metadata,
};

use crate::{
    account_state::{verified_identity, verified_runtime_context},
    error::EngineError,
    system_events::decode_metadata_strict,
};

/// 一笔已构造转账及其不可分离的业务事实。
///
/// 历史仓储必须直接使用这里的 source/destination/amount/remark 与 signed build，禁止
/// 广播前由绑定层重新拼装一份可能不一致的 pending 记录。
#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct BuiltTransferWithRemark {
    source_account_id: AccountId32,
    call: TransferWithRemarkCall,
    signed: SignedTransactionBuild,
}

impl BuiltTransferWithRemark {
    pub(crate) const fn source_account_id(&self) -> AccountId32 {
        self.source_account_id
    }

    pub(crate) const fn call(&self) -> &TransferWithRemarkCall {
        &self.call
    }

    pub(crate) const fn signed(&self) -> &SignedTransactionBuild {
        &self.signed
    }
}

/// Engine 内部完整转账构造器。
///
/// `AccountNonceSource` 必须提供同一次已固定 Runtime 调用的准确 best nonce；本层随后由
/// 历史仓储的 durable single-flight pending 门阻止同账户并发复用该值。
/// `ChainSigner` 必须使用固定 `substrate` context。两者均为强类型合同，调用方不能注入
/// 任意 RPC method 或签名 context。
pub(crate) struct TransactionBuilder<'a> {
    chain_client: &'a dyn VerifiedChainClient,
    nonce_source: &'a dyn AccountNonceSource,
    signer: &'a dyn ChainSigner,
}

impl<'a> TransactionBuilder<'a> {
    pub(crate) const fn new(
        chain_client: &'a dyn VerifiedChainClient,
        nonce_source: &'a dyn AccountNonceSource,
        signer: &'a dyn ChainSigner,
    ) -> Self {
        Self {
            chain_client,
            nonce_source,
            signer,
        }
    }

    /// 创建、签名并编码一笔公民链带备注转账。
    pub(crate) async fn build_transfer_with_remark(
        &self,
        account_secret: &SecretBuffer,
        source_account_id: AccountId32,
        destination: AccountId32,
        amount_fen: u128,
        remark: impl Into<String>,
    ) -> Result<BuiltTransferWithRemark, EngineError> {
        let call = TransferWithRemarkCall::try_new(destination, amount_fen, remark)
            .map_err(EngineError::from)?;
        let signed = self
            .build(account_secret, source_account_id, call.clone())
            .await?;
        Ok(BuiltTransferWithRemark {
            source_account_id,
            call,
            signed,
        })
    }

    /// 构造已通过合同验证的 `transfer_with_remark` call。
    pub(crate) async fn build(
        &self,
        account_secret: &SecretBuffer,
        source_account_id: AccountId32,
        call: TransferWithRemarkCall,
    ) -> Result<SignedTransactionBuild, EngineError> {
        let identity = verified_identity(self.chain_client).await?;
        let best = self
            .chain_client
            .get_best_head()
            .await
            .map_err(EngineError::from)?;
        let runtime_context = verified_runtime_context(self.chain_client, best).await?;
        let metadata = decode_metadata_strict(runtime_context.metadata())?;

        let signer_public_key = self
            .signer
            .public_key(account_secret)
            .await
            .map_err(EngineError::from)?;
        if signer_public_key.as_bytes() != source_account_id.as_bytes() {
            return Err(EngineError::contract(
                ContractErrorCode::InvalidArgument,
                "source AccountId 与 Rust 金库解锁秘密的 sr25519 公钥不一致",
            ));
        }

        let nonce = self
            .nonce_source
            .account_next_index(source_account_id, best)
            .await
            .map_err(EngineError::from)?;
        if nonce.account_id() != source_account_id || nonce.best_block() != best {
            return Err(EngineError::contract(
                ContractErrorCode::Integrity,
                "AccountNonceSource 返回了不同账户或不同 best 块的 nonce",
            ));
        }

        let call_data = validate_and_encode_call(&metadata, &call)?;
        if tx::suggested_version(&metadata)
            .map_err(|error| EngineError::InvalidMetadata(error.to_string()))?
            != TransactionVersion::V4
        {
            return Err(EngineError::contract(
                ContractErrorCode::Unsupported,
                "当前 Runtime 不再支持 CitizenSDK 已验证的 signed extrinsic V4",
            ));
        }
        let state = ClientState::<SubstrateConfig> {
            genesis_hash: H256::from(identity.genesis_hash().into_bytes()),
            runtime_version: SubxtRuntimeVersion {
                spec_version: runtime_context.version().spec_version(),
                transaction_version: runtime_context.version().transaction_version(),
            },
            metadata,
        };
        let params = SubstrateExtrinsicParamsBuilder::<SubstrateConfig>::new()
            .immortal()
            .nonce(nonce.value())
            .tip(0)
            .build();
        let raw_call = ExactCallData(call_data.clone());
        let partial = tx::create_v4_signed(&raw_call, &state, params)
            .map_err(|error| EngineError::InvalidMetadata(error.to_string()))?;
        if partial.call_data() != call_data {
            return Err(EngineError::contract(
                ContractErrorCode::Integrity,
                "Subxt 构造器改写了已验证的 transfer_with_remark call bytes",
            ));
        }

        // Subxt 在这里执行现有 V4 长载荷规则：<=256 直接签名，>256 签 blake2_256。
        let signing_message = partial.signer_payload();
        let payload = ImmortalSigningPayload::try_new(
            &identity,
            &runtime_context,
            nonce,
            source_account_id,
            signer_public_key,
            call_data,
            signing_message.clone(),
        )
        .map_err(EngineError::from)?;
        let signature = self
            .signer
            .sign(account_secret, signing_message.clone())
            .await
            .map_err(EngineError::from)?;
        let verified = self
            .signer
            .verify(signer_public_key, signing_message, signature)
            .await
            .map_err(EngineError::from)?;
        if !verified {
            return Err(EngineError::contract(
                ContractErrorCode::Integrity,
                "ChainSigner 产生的 sr25519 签名未能由同一公钥验证",
            ));
        }

        let account = SubxtAccountId32(source_account_id.into_bytes());
        let signature_bytes = *signature.as_bytes();
        let extrinsic = partial
            .sign_with_account_and_signature(account, &MultiSignature::Sr25519(signature_bytes));
        let extrinsic =
            SignedExtrinsic::try_new(extrinsic.into_encoded()).map_err(EngineError::from)?;
        Ok(SignedTransactionBuild::new(payload, signature, extrinsic))
    }
}

/// 用准确 metadata 对 call 的 pallet/call index、参数类型和最终 bytes 做双重核对。
fn validate_and_encode_call(
    metadata: &Metadata,
    call: &TransferWithRemarkCall,
) -> Result<Vec<u8>, EngineError> {
    let dynamic_call = tx::payload::dynamic(
        "OnchainTransaction",
        "transfer_with_remark",
        vec![
            Value::from_bytes(call.destination().as_bytes()),
            Value::u128(call.amount_fen()),
            Value::from_bytes(call.remark().as_bytes()),
        ],
    );
    // `EncodeAsFields` 假定 metadata 内部自洽；用 unwind 边界把意外的 Runtime shape
    // 不兼容收口为确定错误，不能让动态 metadata 触发宿主进程 panic。
    let encoded = catch_unwind(AssertUnwindSafe(|| {
        tx::call_data(&dynamic_call, metadata).map_err(|error| error.to_string())
    }))
    .map_err(|_| {
        EngineError::InvalidMetadata(
            "OnchainTransaction.transfer_with_remark 参数 shape 不兼容".to_owned(),
        )
    })?
    .map_err(EngineError::InvalidMetadata)?;
    let expected = call.encode_call_data();
    if encoded != expected {
        return Err(EngineError::contract(
            ContractErrorCode::Integrity,
            "Runtime metadata 的 transfer_with_remark 编码偏离 CitizenChain 已验证合同",
        ));
    }
    Ok(encoded)
}

/// 已由 metadata 动态编码并与合同 bytes 比对完成的 call。
struct ExactCallData(Vec<u8>);

impl tx::payload::Payload for ExactCallData {
    fn encode_call_data_to(
        &self,
        _metadata: &Metadata,
        output: &mut Vec<u8>,
    ) -> Result<(), subxt_core::Error> {
        output.extend_from_slice(&self.0);
        Ok(())
    }
}
