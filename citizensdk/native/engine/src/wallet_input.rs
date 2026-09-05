//! SDK 安全界面的本地输入能力；词表、checksum 与派生使用同一个 BIP-39 依赖。
//! 不生成钱包、不访问金库、不持久化输入，错误仅携带位置而不包含单词或秘密。

use bip39::{Language, Mnemonic};
use citizen_sdk_contracts::ContractErrorCode;

use crate::{EngineError, WalletWordCount};

const MAX_INPUT_BYTES: usize = 1024;
const MAX_SUGGESTIONS: usize = 6;

/// 校验所选词数和 English BIP-39 checksum；成功不返回助记词副本。
pub fn validate_wallet_mnemonic(
    sentence: &str,
    word_count: WalletWordCount,
) -> Result<(), EngineError> {
    parse_wallet_mnemonic(sentence, Some(word_count)).map(|_| ())
}

/// 只返回官方词表中的静态候选词，最多六项；不会返回调用方输入。
/// 空前缀无建议。前缀仅接受小写 ASCII，不隐式改写用户正在输入的单词。
pub fn wallet_word_suggestions(prefix: &str) -> Result<Vec<&'static str>, EngineError> {
    if prefix.len() > MAX_INPUT_BYTES || !prefix.bytes().all(|byte| byte.is_ascii_lowercase()) {
        return Err(invalid("助记词前缀必须是小写英文字母"));
    }
    if prefix.is_empty() {
        return Ok(Vec::new());
    }
    Ok(Language::English
        .word_list()
        .iter()
        .copied()
        .filter(|word| word.starts_with(prefix))
        .take(MAX_SUGGESTIONS)
        .collect())
}

/// `None` 仅供核心派生从输入识别词数；安全界面必须传入显式选择值。
/// Mnemonic 开启上游 zeroize 特性，验证和派生返回后其内部索引也会清零。
pub(crate) fn parse_wallet_mnemonic(
    sentence: &str,
    selected: Option<WalletWordCount>,
) -> Result<Mnemonic, EngineError> {
    if sentence.len() > MAX_INPUT_BYTES {
        return Err(invalid("助记词输入超过长度上限"));
    }
    let count = sentence.split_whitespace().count();
    if !matches!(count, 12 | 18 | 24) {
        return Err(invalid("助记词只允许 12、18 或 24 词"));
    }
    if selected.is_some_and(|word_count| word_count.words() != count) {
        return Err(invalid("助记词数量与所选词数不一致"));
    }
    Mnemonic::parse_in(Language::English, sentence.trim()).map_err(|error| match error {
        bip39::Error::UnknownWord(index) => {
            invalid(format!("第 {} 个助记词不在英文词表中", index + 1))
        }
        bip39::Error::InvalidChecksum => invalid("助记词校验和不正确"),
        _ => invalid("助记词无效"),
    })
}

fn invalid(message: impl Into<String>) -> EngineError {
    EngineError::contract(ContractErrorCode::InvalidArgument, message)
}
