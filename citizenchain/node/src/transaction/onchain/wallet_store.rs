// 钱包 JSON 持久化。
//
// 文件只保存用户显式导入的 Cold 钱包公开信息；Hot 钱包由本机 powr 密钥事实动态生成，
// 不进入该文件。缺失或不属于 Hot/Cold 的签名模式由 serde 严格拒绝。

use crate::shared::security;
use serde::{Deserialize, Serialize};
use std::{fs, io::ErrorKind, path::PathBuf};
use tauri::AppHandle;

/// 重构前唯一已发布的冷钱包条目。
///
/// 该类型只用于把结构完整、账户自洽的旧公开数据原子收口到新格式；
/// 缺少 `kind` 、包含未知字段或不是明确 Cold 的记录不进入迁移。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(deny_unknown_fields)]
struct LegacyWallet {
    id: String,
    name: String,
    kind: String,
    deletable: bool,
    #[serde(rename = "ss58_address")]
    ss58_address: String,
    #[serde(rename = "account_id")]
    account_id: String,
    created_at: u64,
}

/// 旧钱包列表只允许 `wallets + activeId` 这一种确定结构。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(deny_unknown_fields)]
struct LegacyWalletStore {
    wallets: Vec<LegacyWallet>,
    // 不使用 Option，确保旧文件必须显式包含 `activeId`（可为 null）。
    #[serde(rename = "activeId")]
    active_account_id: serde_json::Value,
}

struct DecodedStore {
    store: WalletStore,
    migrated: bool,
}

/// 钱包账户签名模式闭集。
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum SignMode {
    /// 本机 powr 私钥签名。
    Hot,
    /// CitizenWallet 离线扫码签名。
    Cold,
}

/// 单个钱包条目。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
#[serde(deny_unknown_fields)]
pub struct Wallet {
    pub name: String,
    /// 唯一签名路由事实，只允许 Hot/Cold。
    pub sign_mode: SignMode,
    /// 仅用于钱包界面展示的 SS58 地址（prefix 2027）。
    pub ss58_address: String,
    /// 钱包账户 ID，固定为小写 `0x` + 64 位十六进制。
    pub account_id: String,
    pub created_at: u64,
}

/// 钱包列表和当前账户；`account_id` 是唯一钱包标识，不再另设随机钱包 ID。
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
#[serde(deny_unknown_fields)]
pub struct WalletStore {
    pub wallets: Vec<Wallet>,
    pub active_account_id: Option<String>,
}

/// 只将唯一已知旧 Cold 结构转成当前严格结构。
///
/// `id` 仅用于把旧 `activeId` 解析为账户 ID，不写入新文件；
/// `deletable` 是旧 UI 属性，完成结构确认后丢弃，不参与签名模式判定。
fn migrate_legacy_store(raw: &str) -> Result<WalletStore, String> {
    let legacy: LegacyWalletStore = serde_json::from_str(raw)
        .map_err(|error| format!("旧钱包结构不完整或包含未知字段: {error}"))?;
    let mut legacy_ids = std::collections::HashSet::with_capacity(legacy.wallets.len());
    let mut id_to_account_id = std::collections::HashMap::with_capacity(legacy.wallets.len());
    let mut wallets = Vec::with_capacity(legacy.wallets.len());

    for wallet in legacy.wallets {
        if wallet.id.trim().is_empty() || !legacy_ids.insert(wallet.id.clone()) {
            return Err("旧钱包 id 为空或重复，已拒绝迁移".to_string());
        }
        if wallet.kind != "cold" {
            return Err("旧钱包 kind 不是明确 cold，已拒绝迁移".to_string());
        }
        let _ = wallet.deletable;
        id_to_account_id.insert(wallet.id, wallet.account_id.clone());
        wallets.push(Wallet {
            name: wallet.name,
            sign_mode: SignMode::Cold,
            ss58_address: wallet.ss58_address,
            account_id: wallet.account_id,
            created_at: wallet.created_at,
        });
    }

    let active_account_id = match legacy.active_account_id {
        serde_json::Value::String(legacy_id) => Some(
            id_to_account_id
                .get(&legacy_id)
                .cloned()
                .ok_or_else(|| "旧 activeId 没有对应钱包，已拒绝迁移".to_string())?,
        ),
        serde_json::Value::Null => None,
        _ => return Err("旧 activeId 必须为字符串或 null，已拒绝迁移".to_string()),
    };
    let store = WalletStore {
        wallets,
        active_account_id,
    };
    super::validate_persisted_store(&store)?;
    Ok(store)
}

fn decode_store(raw: &str) -> Result<DecodedStore, String> {
    match serde_json::from_str::<WalletStore>(raw) {
        Ok(store) => {
            super::validate_persisted_store(&store)?;
            Ok(DecodedStore {
                store,
                migrated: false,
            })
        }
        Err(current_error) => {
            let store = migrate_legacy_store(raw).map_err(|legacy_error| {
                format!("解析钱包文件失败: {current_error}; {legacy_error}")
            })?;
            Ok(DecodedStore {
                store,
                migrated: true,
            })
        }
    }
}

fn store_path(app: &AppHandle) -> Result<PathBuf, String> {
    Ok(security::app_data_dir(app)?.join("cold-wallets.json"))
}

pub fn load(app: &AppHandle) -> Result<WalletStore, String> {
    let path = store_path(app)?;
    let raw = match fs::read_to_string(&path) {
        Ok(v) => v,
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(WalletStore::default()),
        Err(e) => return Err(format!("读取钱包文件失败: {e}")),
    };
    let decoded = decode_store(&raw)?;
    if !decoded.migrated {
        return Ok(decoded.store);
    }

    // 所有字段和账户一致性已在内存中验证后才原子覆盖旧公开数据；
    // 写入后再用当前结构回读，避免半份迁移在后续调用中被当作成功。
    save(app, &decoded.store)?;
    let rewritten =
        fs::read_to_string(&path).map_err(|e| format!("回读迁移后钱包文件失败: {e}"))?;
    let store: WalletStore =
        serde_json::from_str(&rewritten).map_err(|e| format!("验证迁移后钱包文件失败: {e}"))?;
    super::validate_persisted_store(&store)?;
    Ok(store)
}

pub fn save(app: &AppHandle, store: &WalletStore) -> Result<(), String> {
    let raw =
        serde_json::to_string_pretty(store).map_err(|e| format!("序列化钱包数据失败: {e}"))?;
    security::write_text_atomic(&store_path(app)?, &format!("{raw}\n"))
        .map_err(|e| format!("写入钱包文件失败: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    const ACCOUNT_ID: &str = "0x1111111111111111111111111111111111111111111111111111111111111111";

    fn cold_wallet() -> Wallet {
        cold_wallet_for_account(ACCOUNT_ID)
    }

    #[test]
    fn sign_mode_serializes_only_hot_and_cold() {
        assert_eq!(serde_json::to_string(&SignMode::Hot).unwrap(), "\"hot\"");
        assert_eq!(serde_json::to_string(&SignMode::Cold).unwrap(), "\"cold\"");
        assert!(serde_json::from_str::<SignMode>("\"minerHot\"").is_err());
        assert!(serde_json::from_str::<SignMode>("\"external\"").is_err());
        assert!(serde_json::from_str::<SignMode>("\"local\"").is_err());
    }

    #[test]
    fn wallet_store_uses_account_id_and_required_sign_mode() {
        let store = WalletStore {
            wallets: vec![cold_wallet()],
            active_account_id: Some(ACCOUNT_ID.to_string()),
        };
        let value = serde_json::to_value(&store).unwrap();
        assert_eq!(value["activeAccountId"], ACCOUNT_ID);
        assert_eq!(value["wallets"][0]["signMode"], "cold");
        assert!(value["wallets"][0].get("id").is_none());
    }

    #[test]
    fn wallet_store_rejects_old_or_missing_mode_fields() {
        let old_kind = format!(
            r#"{{"wallets":[{{"name":"旧钱包","kind":"cold","ss58Address":"x","accountId":"{ACCOUNT_ID}","createdAt":1}}],"activeAccountId":null}}"#
        );
        let missing_mode = format!(
            r#"{{"wallets":[{{"name":"旧钱包","ss58Address":"x","accountId":"{ACCOUNT_ID}","createdAt":1}}],"activeAccountId":null}}"#
        );
        let random_id = format!(
            r#"{{"wallets":[{{"id":"legacy","name":"旧钱包","signMode":"cold","ss58Address":"x","accountId":"{ACCOUNT_ID}","createdAt":1}}],"activeAccountId":null}}"#
        );

        assert!(serde_json::from_str::<WalletStore>(&old_kind).is_err());
        assert!(serde_json::from_str::<WalletStore>(&missing_mode).is_err());
        assert!(serde_json::from_str::<WalletStore>(&random_id).is_err());
    }

    fn legacy_store_json(
        kind: &str,
        active_legacy_id: Option<&str>,
        account_id: &str,
        ss58_address: &str,
    ) -> String {
        let active_legacy_id = active_legacy_id
            .map(|value| format!(r#""{value}""#))
            .unwrap_or_else(|| "null".to_string());
        format!(
            r#"{{"wallets":[{{"id":"legacy-1","name":"旧冷钱包","kind":"{kind}","deletable":true,"ss58_address":"{ss58_address}","account_id":"{account_id}","createdAt":1}}],"activeId":{active_legacy_id}}}"#
        )
    }

    #[test]
    fn exact_legacy_cold_store_migrates_to_current_fields() {
        let wallet = cold_wallet();
        let raw = legacy_store_json(
            "cold",
            Some("legacy-1"),
            &wallet.account_id,
            &wallet.ss58_address,
        );
        let decoded = decode_store(&raw).unwrap();

        assert!(decoded.migrated);
        assert_eq!(decoded.store.active_account_id.as_deref(), Some(ACCOUNT_ID));
        assert_eq!(decoded.store.wallets[0].sign_mode, SignMode::Cold);
        let value = serde_json::to_value(decoded.store).unwrap();
        assert_eq!(value["wallets"][0]["signMode"], "cold");
        assert_eq!(value["activeAccountId"], ACCOUNT_ID);
        for old_field in ["id", "kind", "deletable", "ss58_address", "account_id"] {
            assert!(value["wallets"][0].get(old_field).is_none());
        }
        assert!(value.get("activeId").is_none());
    }

    #[test]
    fn current_store_is_not_migrated_again() {
        let store = WalletStore {
            wallets: vec![cold_wallet()],
            active_account_id: Some(ACCOUNT_ID.to_string()),
        };
        let raw = serde_json::to_string(&store).unwrap();
        let decoded = decode_store(&raw).unwrap();
        assert!(!decoded.migrated);
        assert_eq!(decoded.store, store);
    }

    #[test]
    fn legacy_store_rejects_ambiguous_or_invalid_facts() {
        let wallet = cold_wallet();
        let miner_hot = legacy_store_json(
            "minerHot",
            Some("legacy-1"),
            &wallet.account_id,
            &wallet.ss58_address,
        );
        assert!(decode_store(&miner_hot).is_err());

        let missing_kind = legacy_store_json(
            "cold",
            Some("legacy-1"),
            &wallet.account_id,
            &wallet.ss58_address,
        )
        .replace(r#""kind":"cold","#, "");
        assert!(decode_store(&missing_kind).is_err());

        let unknown_field = legacy_store_json(
            "cold",
            Some("legacy-1"),
            &wallet.account_id,
            &wallet.ss58_address,
        )
        .replace(r#""deletable":true"#, r#""deletable":true,"extra":1"#);
        assert!(decode_store(&unknown_field).is_err());

        let mut missing_active_key = serde_json::from_str::<serde_json::Value>(&legacy_store_json(
            "cold",
            Some("legacy-1"),
            &wallet.account_id,
            &wallet.ss58_address,
        ))
        .unwrap();
        missing_active_key
            .as_object_mut()
            .unwrap()
            .remove("activeId");
        assert!(decode_store(&missing_active_key.to_string()).is_err());

        let dangling_active = legacy_store_json(
            "cold",
            Some("missing"),
            &wallet.account_id,
            &wallet.ss58_address,
        );
        assert!(decode_store(&dangling_active).is_err());

        let mismatched_ss58 = legacy_store_json(
            "cold",
            Some("legacy-1"),
            &wallet.account_id,
            &cold_wallet_for_account(
                "0x2222222222222222222222222222222222222222222222222222222222222222",
            )
            .ss58_address,
        );
        assert!(decode_store(&mismatched_ss58).is_err());
    }

    #[test]
    fn legacy_store_rejects_duplicate_ids_and_accounts() {
        let wallet = cold_wallet();
        let one = legacy_store_json(
            "cold",
            Some("legacy-1"),
            &wallet.account_id,
            &wallet.ss58_address,
        );
        let entry = serde_json::from_str::<serde_json::Value>(&one).unwrap()["wallets"][0].clone();

        let mut duplicate_id = serde_json::from_str::<serde_json::Value>(&one).unwrap();
        duplicate_id["wallets"]
            .as_array_mut()
            .unwrap()
            .push(entry.clone());
        assert!(decode_store(&duplicate_id.to_string()).is_err());

        let mut duplicate_account = serde_json::from_str::<serde_json::Value>(&one).unwrap();
        let mut second = entry;
        second["id"] = serde_json::Value::String("legacy-2".to_string());
        duplicate_account["wallets"]
            .as_array_mut()
            .unwrap()
            .push(second);
        assert!(decode_store(&duplicate_account.to_string()).is_err());
    }

    fn cold_wallet_for_account(account_id: &str) -> Wallet {
        let account_id_bytes: [u8; 32] = hex::decode(account_id.trim_start_matches("0x"))
            .unwrap()
            .try_into()
            .unwrap();
        Wallet {
            name: "测试冷钱包".to_string(),
            sign_mode: SignMode::Cold,
            ss58_address: crate::governance::signing::account_id_to_ss58(&account_id_bytes)
                .unwrap(),
            account_id: account_id.to_string(),
            created_at: 1,
        }
    }
}
