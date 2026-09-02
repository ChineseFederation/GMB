//! CitizenChain `OnchainTransaction::transfer_with_remark` 与 immortal extrinsic 构造值对象。
//!
//! 本模块固定现有 Dart 已验证的 call bytes、runtime/genesis/nonce 同锚约束及公开构造轨迹。
//! 它只携带公开载荷、签名和 extrinsic，不包含或序列化任何秘密材料。

use crate::{
    account::require_citizenchain_identity, AccountId32, AccountNonce, ChainIdentity,
    ContractError, ContractErrorCode, ContractResult, Hash32, RuntimeContext, RuntimeVersion,
    SignedExtrinsic, Sr25519PublicKey, Sr25519Signature, VerifiedBlockRef,
};

/// 当前正式 Runtime 中 `OnchainTransaction` pallet index。
pub const ONCHAIN_TRANSACTION_PALLET_INDEX: u8 = 4;
/// 当前正式 Runtime 中 `transfer_with_remark` call index。
pub const TRANSFER_WITH_REMARK_CALL_INDEX: u8 = 0;
/// 与现有公民链热钱包一致的备注 UTF-8 字节上限。
pub const MAX_TRANSFER_REMARK_BYTES: usize = 99;
/// 当前 SDK 只构造 immortal era。
pub const IMMORTAL_ERA: u8 = 0;

/// 一笔产品无关的公民链带备注转账调用。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TransferWithRemarkCall {
    destination: AccountId32,
    amount_fen: u128,
    remark: String,
}

impl TransferWithRemarkCall {
    pub fn try_new(
        destination: AccountId32,
        amount_fen: u128,
        remark: impl Into<String>,
    ) -> ContractResult<Self> {
        if amount_fen == 0 {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "转账金额必须大于 0 分",
            ));
        }
        let remark = remark.into();
        if remark.len() > MAX_TRANSFER_REMARK_BYTES {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "转账备注不能超过 99 个 UTF-8 字节",
            ));
        }
        Ok(Self {
            destination,
            amount_fen,
            remark,
        })
    }

    pub const fn destination(&self) -> AccountId32 {
        self.destination
    }

    pub const fn amount_fen(&self) -> u128 {
        self.amount_fen
    }

    pub fn remark(&self) -> &str {
        &self.remark
    }

    /// 逐字节复现现有 Dart `TransferService.buildTransferWithRemarkCall`：
    /// pallet/call、32B AccountId、u128 LE、SCALE Compact 长度和 UTF-8 正文。
    pub fn encode_call_data(&self) -> Vec<u8> {
        let remark = self.remark.as_bytes();
        let mut encoded = Vec::with_capacity(2 + 32 + 16 + 2 + remark.len());
        encoded.push(ONCHAIN_TRANSACTION_PALLET_INDEX);
        encoded.push(TRANSFER_WITH_REMARK_CALL_INDEX);
        encoded.extend_from_slice(self.destination.as_bytes());
        encoded.extend_from_slice(&self.amount_fen.to_le_bytes());
        encode_compact_u32(remark.len() as u32, &mut encoded);
        encoded.extend_from_slice(remark);
        encoded
    }
}

/// Engine 交给 sr25519 的最终 immortal 签名消息及其完整公开来源轨迹。
///
/// `signing_message` 是经过 metadata registry 编码、并已应用 Substrate 长载荷规则的最终
/// 消息；绑定层不得自行重编码。该对象刻意不实现任何秘密接口。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ImmortalSigningPayload {
    block: VerifiedBlockRef,
    runtime_version: RuntimeVersion,
    genesis_hash: Hash32,
    signer_account_id: AccountId32,
    signer_public_key: Sr25519PublicKey,
    nonce: u64,
    call_data: Vec<u8>,
    signing_message: Vec<u8>,
}

impl ImmortalSigningPayload {
    #[allow(clippy::too_many_arguments)]
    pub fn try_new(
        identity: &ChainIdentity,
        runtime_context: &RuntimeContext,
        nonce: AccountNonce,
        signer_account_id: AccountId32,
        signer_public_key: Sr25519PublicKey,
        call_data: Vec<u8>,
        signing_message: Vec<u8>,
    ) -> ContractResult<Self> {
        require_citizenchain_identity(identity)?;
        if runtime_context.block() != nonce.best_block() {
            return Err(ContractError::new(
                ContractErrorCode::Integrity,
                "runtime context 与 accountNextIndex nonce 不属于同一准确 best 块",
            ));
        }
        if signer_account_id != nonce.account_id()
            || signer_account_id.as_bytes() != signer_public_key.as_bytes()
        {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "签名账户、公钥与 nonce 账户不一致",
            ));
        }
        if call_data.is_empty() || signing_message.is_empty() {
            return Err(ContractError::new(
                ContractErrorCode::InvalidArgument,
                "call data 与最终签名消息均不能为空",
            ));
        }
        Ok(Self {
            block: runtime_context.block(),
            runtime_version: runtime_context.version(),
            genesis_hash: identity.genesis_hash(),
            signer_account_id,
            signer_public_key,
            nonce: nonce.value(),
            call_data,
            signing_message,
        })
    }

    pub const fn block(&self) -> VerifiedBlockRef {
        self.block
    }

    pub const fn runtime_version(&self) -> RuntimeVersion {
        self.runtime_version
    }

    pub const fn genesis_hash(&self) -> Hash32 {
        self.genesis_hash
    }

    pub const fn signer_account_id(&self) -> AccountId32 {
        self.signer_account_id
    }

    pub const fn signer_public_key(&self) -> Sr25519PublicKey {
        self.signer_public_key
    }

    pub const fn nonce(&self) -> u64 {
        self.nonce
    }

    pub fn call_data(&self) -> &[u8] {
        &self.call_data
    }

    pub fn signing_message(&self) -> &[u8] {
        &self.signing_message
    }
}

/// 一笔已完成 sr25519 签名和 SCALE extrinsic 编码的构造结果。
///
/// 构造器只封装 Engine 已核验的公开结果；密码学验签仍由 `ChainSigner` 完成，合同层不另造
/// 第二份 sr25519 实现。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SignedTransactionBuild {
    payload: ImmortalSigningPayload,
    signature: Sr25519Signature,
    extrinsic: SignedExtrinsic,
}

impl SignedTransactionBuild {
    pub const fn new(
        payload: ImmortalSigningPayload,
        signature: Sr25519Signature,
        extrinsic: SignedExtrinsic,
    ) -> Self {
        Self {
            payload,
            signature,
            extrinsic,
        }
    }

    pub const fn payload(&self) -> &ImmortalSigningPayload {
        &self.payload
    }

    pub const fn signature(&self) -> Sr25519Signature {
        self.signature
    }

    pub const fn extrinsic(&self) -> &SignedExtrinsic {
        &self.extrinsic
    }

    pub fn extrinsic_bytes(&self) -> &[u8] {
        self.extrinsic.as_bytes()
    }
}

fn encode_compact_u32(value: u32, output: &mut Vec<u8>) {
    debug_assert!(value <= MAX_TRANSFER_REMARK_BYTES as u32);
    if value < 1 << 6 {
        output.push((value as u8) << 2);
    } else {
        output.extend_from_slice(&(((value << 2) | 0b01) as u16).to_le_bytes());
    }
}
