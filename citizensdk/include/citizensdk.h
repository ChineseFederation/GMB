#ifndef CITIZENSDK_H
#define CITIZENSDK_H

#include "citizensdk_types.h"

#if defined(_WIN32) && defined(CITIZENSDK_SHARED)
#if defined(CITIZENSDK_BUILDING)
#define CITIZENSDK_API __declspec(dllexport)
#else
#define CITIZENSDK_API __declspec(dllimport)
#endif
#else
#define CITIZENSDK_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

CITIZENSDK_API uint32_t citizensdk_abi_version(void);
CITIZENSDK_API uint32_t citizensdk_create_options_size(void);

/* All input views are copied before return. Empty system_name/system_version
 * select CitizenSDK/1.0.0 defaults. The three verified chain assets are
 * mandatory and are revalidated before a smoldot provider is constructed. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_create(const citizensdk_create_options_t *options,
                  citizensdk_handle_t *out_handle);

/* Creates the wallet-capable product composition. CitizenSDK copies all three
 * pointed-to vtables before return. public_store is mandatory; secure_store
 * and secret_vault are an all-or-none wallet bundle. Callback contexts remain
 * host-owned and must live through successful instance destruction. */
CITIZENSDK_API citizensdk_error_code_t citizensdk_create_with_host(
    const citizensdk_create_options_t *options,
    const citizensdk_host_services_v1_t *host_services,
    citizensdk_handle_t *out_handle);

/* Destroy rejects outstanding requests/results and calls from the instance's
 * own callback with BUSY before teardown, leaving the handle usable. If a live
 * handle returns another error after teardown begins, it is teardown-only:
 * issue no new requests/callback changes/subscriptions and retry destroy.
 * Success guarantees no later callback. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_destroy(citizensdk_handle_t handle);

/* Callback execution uses one dedicated dispatch thread. Replacement waits
 * for an old callback to return; queued old-generation events never use the
 * new context. Clear only after capability unsubscription and after releasing
 * every result. Request acceptance and callback control are linearized; a
 * conflicting transition returns BUSY. Registration is the commit point and
 * its immediate state notifications are best-effort/queryable synchronously.
 * HISTORY_CHANGED (5) is a payloadless history invalidation from SDK-owned
 * wallet monitoring; read the existing history API for the latest snapshot.
 * It carries only sequence; request_id/result/capability_revision/reserved are
 * zero. Stop drains the monitor, pending host writes and owned subscriptions
 * before removing the provider. The event pointer is valid only during the callback. */
CITIZENSDK_API citizensdk_error_code_t citizensdk_set_event_callback(
    citizensdk_handle_t handle, citizensdk_event_callback_t callback,
    void *context);

CITIZENSDK_API citizensdk_error_code_t citizensdk_get_capabilities(
    citizensdk_handle_t handle,
    citizensdk_capability_snapshot_t *out_snapshot);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_get_lifecycle(citizensdk_handle_t handle,
                         citizensdk_lifecycle_t *out_lifecycle);
/* Subscribe and unsubscribe publish/join through the bounded event path.
 * Calling either from inside that instance's callback returns BUSY before
 * changing monitor state; perform the control call after callback return.
 * Monitor installation/removal is linearized with callback control, request
 * acceptance and destroy. Initial capability publication is best-effort. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_subscribe_capability_changes(citizensdk_handle_t handle);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_unsubscribe_capability_changes(citizensdk_handle_t handle);

/* Accepted asynchronous requests return exactly one REQUEST_COMPLETED event.
 * The callback may race with and run before the accepting function returns;
 * route by event.request_id and do not rely on out_request_id being observed
 * first. Acceptance pre-reserves its event capacity and unique nonzero result
 * handle; monotonic-space exhaustion fails before a request ID is returned.
 * Every completion event.result must be inspected and released once. Raw
 * extrinsic watch and high-level wallet transfer watch are cancellable after
 * acceptance; cancel on other state-mutating or atomic requests returns
 * UNSUPPORTED, so it never falsely promises rollback. Wallet transfer
 * cancellation is cooperative: REQUEST_COMPLETED waits for any already-entered
 * host store/CAS or vault operation to return. Cancellation is not withdrawal
 * and never clears a durable Pending/InBlock or proven execution record. */
/* For create_with_host instances, start restores the typed chain database
 * before provider start. Stop first persists an exact revisioned snapshot;
 * persistence failure leaves unsubscribe/services/provider untouched. The
 * legacy create path retains its original lifecycle semantics. Host start,
 * stop and import use exclusive request admission: prior requests must finish,
 * and later requests, controls and destroy return BUSY through completion. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_start(citizensdk_handle_t handle,
                 citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_stop(citizensdk_handle_t handle,
                citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_cancel_request(citizensdk_handle_t handle,
                          citizensdk_request_id_t request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_refresh_capabilities(
    citizensdk_handle_t handle, citizensdk_request_id_t *out_request_id);

CITIZENSDK_API citizensdk_error_code_t citizensdk_get_best_head(
    citizensdk_handle_t handle, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_get_finalized_head(
    citizensdk_handle_t handle, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_get_storage_at(
    citizensdk_handle_t handle, const citizensdk_block_ref_t *block,
    citizensdk_bytes_view_t key, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_get_storage_batch_at(
    citizensdk_handle_t handle, const citizensdk_block_ref_t *block,
    const citizensdk_bytes_view_t *keys, uint32_t key_count,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_get_runtime_context_at(
    citizensdk_handle_t handle, const citizensdk_block_ref_t *block,
    citizensdk_request_id_t *out_request_id);

/* Typed public account state. Nonce is exact-best Runtime state, not a
 * transaction-pool lease. The retained fee snapshot can be reused with
 * citizensdk_result_estimate_fee for the SDK's exact rounding semantics. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_get_finalized_account_balance(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_id,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_get_account_nonce(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_id,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_get_best_fee_snapshot(
    citizensdk_handle_t handle, citizensdk_request_id_t *out_request_id);

/* SDK 安全界面的同步纯校验，不需要已启动实例，不写钱包或金库。
 * 输入为最多 1024 字节的 UTF-8，不含 NUL 终止符；不返回密码或助记词。
 * 空密码有效；非空原文及 NFKD 后按同一派生规则校验。
 * 助记词必须匹配显式选择的 12、18 或 24 词及 English BIP-39 checksum。
 * 错误通过既有 last_error 返回，只说明原因/位置，不回显输入。 */
CITIZENSDK_API citizensdk_error_code_t citizensdk_validate_wallet_password(
    citizensdk_bytes_view_t password);
CITIZENSDK_API citizensdk_error_code_t citizensdk_validate_wallet_mnemonic(
    citizensdk_bytes_view_t mnemonic, citizensdk_wallet_word_count_t word_count);
/* 前缀仅接受小写 ASCII，空前缀返回空。最多六个官方词表候选，以 LF 分隔，
 * 无尾随 LF/NUL。NULL/0 查询字节数；容量不足仅写 out_required，不部分写。
 * 候选是公开词表内容，不是输入、助记词或规范化密码的回传。 */
CITIZENSDK_API citizensdk_error_code_t citizensdk_wallet_word_suggestions(
    citizensdk_bytes_view_t prefix, uint8_t *buffer, uint64_t capacity,
    uint64_t *out_required);

/* Wallet secret inputs are borrowed only for the accepting call and copied
 * immediately into Rust zeroizing buffers. They are raw UTF-8 bytes without a
 * NUL terminator. No mini-secret/private key or standalone signed extrinsic is
 * returned. */
CITIZENSDK_API citizensdk_error_code_t citizensdk_get_wallet_profile(
    citizensdk_handle_t handle, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_prepare_wallet_creation(
    citizensdk_handle_t handle, citizensdk_wallet_word_count_t word_count,
    citizensdk_bytes_view_t password,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_prepared_wallet_copy_mnemonic(
    citizensdk_handle_t handle,
    citizensdk_prepared_wallet_handle_t prepared_wallet, uint8_t *buffer,
    uint64_t capacity, uint64_t *out_required);
CITIZENSDK_API citizensdk_error_code_t citizensdk_prepared_wallet_release(
    citizensdk_handle_t handle,
    citizensdk_prepared_wallet_handle_t prepared_wallet);
CITIZENSDK_API citizensdk_error_code_t citizensdk_commit_wallet_creation(
    citizensdk_handle_t handle,
    citizensdk_prepared_wallet_handle_t prepared_wallet,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_import_wallet(
    citizensdk_handle_t handle, citizensdk_bytes_view_t mnemonic,
    citizensdk_bytes_view_t password,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_add_wallet_accounts(
    citizensdk_handle_t handle, citizensdk_bytes_view_t mnemonic,
    citizensdk_bytes_view_t password, const uint32_t *indices,
    uint32_t index_count, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_set_active_wallet_account(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_id,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_rename_wallet_account(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_id,
    citizensdk_bytes_view_t name,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_delete_wallet_account(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_id,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_delete_wallet(
    citizensdk_handle_t handle, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_reconcile_wallet_cleanup(
    citizensdk_handle_t handle, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_sign_wallet_payload(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_id,
    citizensdk_bytes_view_t message,
    citizensdk_request_id_t *out_request_id);

/* One high-level wallet transaction owns build, sr25519 signing,
 * pending-before-broadcast, submission, watch and finalized execution proof.
 * It never returns signed-extrinsic bytes. The terminal watch runs on the
 * dedicated long-lived pool. Cancellation completes with CANCELLED and drops
 * the active future without clearing durable pending/in-block history. */
CITIZENSDK_API citizensdk_error_code_t citizensdk_transfer_with_remark(
    citizensdk_handle_t handle,
    const citizensdk_account_id_t *source_account_id,
    const citizensdk_account_id_t *destination_account_id,
    citizensdk_u128_t amount_fen, citizensdk_bytes_view_t remark,
    citizensdk_request_id_t *out_request_id);

CITIZENSDK_API citizensdk_error_code_t
citizensdk_initialize_finalized_history(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_ids,
    uint32_t account_count, citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_sync_finalized_history_batch(
    citizensdk_handle_t handle, const citizensdk_account_id_t *account_ids,
    uint32_t account_count, citizensdk_request_id_t *out_request_id);

CITIZENSDK_API citizensdk_error_code_t citizensdk_submit_extrinsic(
    citizensdk_handle_t handle, citizensdk_bytes_view_t signed_extrinsic,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_watch_extrinsic(
    citizensdk_handle_t handle, citizensdk_bytes_view_t signed_extrinsic,
    citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_verify_transaction_at(
    citizensdk_handle_t handle, const citizensdk_block_ref_t *block,
    citizensdk_bytes_view_t signed_extrinsic, const uint8_t *submitted_hash_32,
    citizensdk_request_id_t *out_request_id);

/* Host-backed export persists the same stable snapshot before completion;
 * legacy session export remains non-durable. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_export_state(citizensdk_handle_t handle,
                        citizensdk_request_id_t *out_request_id);
CITIZENSDK_API citizensdk_error_code_t citizensdk_import_state(
    citizensdk_handle_t handle, const citizensdk_block_ref_t *finalized,
    uint32_t format_version, citizensdk_bytes_view_t database,
    citizensdk_request_id_t *out_request_id);

CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_info(
    citizensdk_result_handle_t result, citizensdk_result_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_result_copy_error_message(citizensdk_result_handle_t result,
                                     uint8_t *buffer, uint64_t capacity,
                                     uint64_t *out_required);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_block_ref(
    citizensdk_result_handle_t result, citizensdk_block_ref_t *out_block);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_copy_storage(
    citizensdk_result_handle_t result, uint8_t *out_present, uint8_t *buffer,
    uint64_t capacity, uint64_t *out_required);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_result_get_storage_batch_count(citizensdk_result_handle_t result,
                                          uint32_t *out_count);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_result_copy_storage_batch_item(citizensdk_result_handle_t result,
                                          uint32_t index,
                                          uint8_t *out_present,
                                          uint8_t *buffer, uint64_t capacity,
                                          uint64_t *out_required);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_runtime_context(
    citizensdk_result_handle_t result,
    citizensdk_runtime_context_info_t *out_info, uint8_t *metadata_buffer,
    uint64_t metadata_capacity, uint64_t *out_required);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_result_get_hash(citizensdk_result_handle_t result,
                           uint8_t *out_hash_32);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_execution(
    citizensdk_result_handle_t result, citizensdk_execution_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_watch_event(
    citizensdk_result_handle_t result, citizensdk_watch_event_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_exported_state(
    citizensdk_result_handle_t result,
    citizensdk_exported_state_info_t *out_info, uint8_t *database_buffer,
    uint64_t database_capacity, uint64_t *out_required);

CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_account_balance(
    citizensdk_result_handle_t result,
    citizensdk_account_balance_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_account_nonce(
    citizensdk_result_handle_t result,
    citizensdk_account_nonce_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_fee_snapshot(
    citizensdk_result_handle_t result,
    citizensdk_fee_snapshot_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_estimate_fee(
    citizensdk_result_handle_t result, citizensdk_u128_t amount_fen,
    citizensdk_u128_t *out_estimated_fee_fen,
    citizensdk_u128_t *out_minimum_self_pay_fen);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_wallet_profile(
    citizensdk_result_handle_t result,
    citizensdk_wallet_profile_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_result_get_wallet_account_count(citizensdk_result_handle_t result,
                                           uint32_t *out_count);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_wallet_account(
    citizensdk_result_handle_t result, uint32_t index,
    citizensdk_wallet_account_info_t *out_info, uint8_t *ss58_buffer,
    uint64_t ss58_capacity, uint64_t *out_ss58_required,
    uint8_t *name_buffer, uint64_t name_capacity,
    uint64_t *out_name_required);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_signature(
    citizensdk_result_handle_t result, uint8_t *out_signature_64);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_prepared_wallet(
    citizensdk_result_handle_t result,
    citizensdk_prepared_wallet_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_wallet_transfer(
    citizensdk_result_handle_t result,
    citizensdk_wallet_transfer_info_t *out_info, uint8_t *reason_buffer,
    uint64_t reason_capacity, uint64_t *out_reason_required);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_history_info(
    citizensdk_result_handle_t result, citizensdk_history_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_history_cursor(
    citizensdk_result_handle_t result, uint32_t index,
    citizensdk_history_cursor_info_t *out_info);
CITIZENSDK_API citizensdk_error_code_t citizensdk_result_get_history_record(
    citizensdk_result_handle_t result, uint32_t index,
    citizensdk_history_record_info_t *out_info, uint8_t *remark_buffer,
    uint64_t remark_capacity, uint64_t *out_remark_required,
    uint8_t *reason_buffer, uint64_t reason_capacity,
    uint64_t *out_reason_required);
CITIZENSDK_API citizensdk_error_code_t
citizensdk_result_get_finalized_transfer(
    citizensdk_result_handle_t result, uint32_t index,
    citizensdk_finalized_transfer_info_t *out_info,
    uint8_t *source_pallet_buffer, uint64_t source_pallet_capacity,
    uint64_t *out_source_pallet_required, uint8_t *remark_display_buffer,
    uint64_t remark_display_capacity, uint64_t *out_remark_display_required,
    uint8_t *remark_bytes_buffer, uint64_t remark_bytes_capacity,
    uint64_t *out_remark_bytes_required);

/* Double release is a stable INVALID_HANDLE error, not undefined behavior. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_result_release(citizensdk_result_handle_t result);

/* Synchronous-call diagnostic. Query with buffer=NULL/capacity=0 returns OK
 * after writing out_required. Copied UTF-8 bytes are not NUL-terminated. */
CITIZENSDK_API citizensdk_error_code_t
citizensdk_last_error_copy(uint8_t *buffer, uint64_t capacity,
                           uint64_t *out_required);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* CITIZENSDK_H */
