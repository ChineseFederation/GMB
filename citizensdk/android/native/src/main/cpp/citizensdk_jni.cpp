#include "citizensdk_jni_support.hpp"

#include <algorithm>
#include <array>
#include <cstring>
#include <limits>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "citizensdk_host_bridge.hpp"

namespace citizen::sdk::jni {
namespace {

constexpr uint32_t kWireVersion = 1;
constexpr int32_t kOk = CITIZENSDK_OK;
constexpr jsize kMaxWalletSecretBytes = 1024;
constexpr jsize kMaxTransferRemarkBytes = 99;
constexpr jsize kMaxWalletAccountIndices = 1989;
std::mutex g_bridges_mutex;
std::unordered_map<intptr_t, std::shared_ptr<CitizenSdkHostBridge>> g_bridges;

std::shared_ptr<CitizenSdkHostBridge> bridge_from(JNIEnv *env, jlong raw) {
  const intptr_t key = static_cast<intptr_t>(raw);
  std::lock_guard<std::mutex> lock(g_bridges_mutex);
  const auto found = g_bridges.find(key);
  if (key == 0 || found == g_bridges.end()) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_HANDLE,
              "CitizenSDK native session is closed");
    return {};
  }
  return found->second;
}

citizensdk_bytes_view_t view(const std::vector<uint8_t> &bytes) {
  return {bytes.empty() ? nullptr : bytes.data(),
          static_cast<uint64_t>(bytes.size())};
}

void secure_zero(std::vector<uint8_t> *bytes) {
  volatile uint8_t *cursor = bytes->data();
  for (size_t index = 0; index < bytes->size(); ++index) cursor[index] = 0;
  bytes->clear();
}

/** Owns a JNI secret copy and clears it on every success/error return path. */
class SensitiveBytes final {
 public:
  SensitiveBytes() = default;
  ~SensitiveBytes() { secure_zero(&value_); }
  SensitiveBytes(const SensitiveBytes &) = delete;
  SensitiveBytes &operator=(const SensitiveBytes &) = delete;

  std::vector<uint8_t> *out() { return &value_; }
  const std::vector<uint8_t> &value() const { return value_; }

 private:
  std::vector<uint8_t> value_;
};

bool take_wallet_secret(JNIEnv *env, jbyteArray source,
                        std::vector<uint8_t> *out) {
  if (source == nullptr) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "Wallet secret must not be null");
    return false;
  }
  const jsize length = env->GetArrayLength(source);
  if (env->ExceptionCheck()) return false;
  if (length < 0 || length > kMaxWalletSecretBytes) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "Wallet secret exceeds 1024 UTF-8 bytes");
    return false;
  }
  out->resize(static_cast<size_t>(length));
  if (length != 0) {
    env->GetByteArrayRegion(source, 0, length,
                            reinterpret_cast<jbyte *>(out->data()));
  }
  return !env->ExceptionCheck();
}

template <typename Info>
Info info_value() {
  Info value{};
  value.struct_size = sizeof(Info);
  value.abi_version = CITIZENSDK_ABI_VERSION;
  return value;
}

bool copy_error(citizensdk_result_handle_t result,
                std::vector<uint8_t> *message) {
  uint64_t required = 0;
  int32_t code = citizensdk_result_copy_error_message(result, nullptr, 0,
                                                       &required);
  if (code != kOk || required > 64 * 1024) return false;
  message->resize(static_cast<size_t>(required));
  return citizensdk_result_copy_error_message(
             result, message->empty() ? nullptr : message->data(), required,
             &required) == kOk;
}

bool copy_wallet_account(citizensdk_result_handle_t result, uint32_t index,
                         citizensdk_wallet_account_info_t *info,
                         std::vector<uint8_t> *ss58,
                         std::vector<uint8_t> *name) {
  uint64_t ss58_required = 0;
  uint64_t name_required = 0;
  *info = info_value<citizensdk_wallet_account_info_t>();
  int32_t code = citizensdk_result_get_wallet_account(
      result, index, info, nullptr, 0, &ss58_required, nullptr, 0,
      &name_required);
  if (code != kOk || ss58_required > 1024 || name_required > 1024) return false;
  ss58->resize(static_cast<size_t>(ss58_required));
  name->resize(static_cast<size_t>(name_required));
  *info = info_value<citizensdk_wallet_account_info_t>();
  return citizensdk_result_get_wallet_account(
             result, index, info, ss58->empty() ? nullptr : ss58->data(),
             ss58_required, &ss58_required,
             name->empty() ? nullptr : name->data(), name_required,
             &name_required) == kOk;
}

bool write_wallet_account(citizensdk_result_handle_t result, uint32_t index,
                          WireWriter *payload) {
  citizensdk_wallet_account_info_t account{};
  std::vector<uint8_t> ss58;
  std::vector<uint8_t> name;
  if (!copy_wallet_account(result, index, &account, &ss58, &name)) return false;
  payload->u32(account.index);
  payload->fixed(account.account_id.bytes, 32);
  payload->text(ss58);
  payload->u8(name.empty() ? 0 : 1);
  if (!name.empty()) payload->text(name);
  payload->u64(account.created_at_millis);
  payload->u8(account.is_active == 0 ? 0 : 1);
  return true;
}

bool write_wallet_profile(citizensdk_result_handle_t result,
                          WireWriter *payload) {
  auto info = info_value<citizensdk_wallet_profile_info_t>();
  if (citizensdk_result_get_wallet_profile(result, &info) != kOk) return false;
  payload->u8(info.present == 0 ? 0 : 1);
  if (info.present == 0) return true;
  uint32_t count = 0;
  if (citizensdk_result_get_wallet_account_count(result, &count) != kOk ||
      count != info.account_count || count > 1990) {
    return false;
  }
  payload->u32(info.origin);
  payload->u32(info.wallet_index);
  payload->u64(info.created_at_millis);
  payload->fixed(info.master_account_id.bytes, 32);
  payload->fixed(info.active_account_id.bytes, 32);
  payload->u32(count);
  for (uint32_t index = 0; index < count; ++index) {
    if (!write_wallet_account(result, index, payload)) return false;
  }
  return true;
}

bool write_wallet_accounts(citizensdk_result_handle_t result,
                           WireWriter *payload) {
  uint32_t count = 0;
  if (citizensdk_result_get_wallet_account_count(result, &count) != kOk ||
      count > 1990) {
    return false;
  }
  payload->u32(count);
  for (uint32_t index = 0; index < count; ++index) {
    if (!write_wallet_account(result, index, payload)) return false;
  }
  return true;
}

bool copy_wallet_transfer(citizensdk_result_handle_t result,
                          WireWriter *payload) {
  auto info = info_value<citizensdk_wallet_transfer_info_t>();
  uint64_t required = 0;
  int32_t code = citizensdk_result_get_wallet_transfer(
      result, &info, nullptr, 0, &required);
  if (code != kOk || required > 64 * 1024) return false;
  std::vector<uint8_t> reason(static_cast<size_t>(required));
  info = info_value<citizensdk_wallet_transfer_info_t>();
  if (citizensdk_result_get_wallet_transfer(
          result, &info, reason.empty() ? nullptr : reason.data(), required,
          &required) != kOk) {
    return false;
  }
  payload->fixed(info.transaction_hash, 32);
  payload->u32(info.resolution);
  payload->u8(info.has_execution == 0 ? 0 : 1);
  if (info.has_execution != 0) write_execution(payload, info.execution);
  payload->u8(reason.empty() ? 0 : 1);
  if (!reason.empty()) payload->text(reason);
  return true;
}

bool copy_history_record(citizensdk_result_handle_t result, uint32_t index,
                         WireWriter *payload) {
  auto info = info_value<citizensdk_history_record_info_t>();
  uint64_t remark_required = 0;
  uint64_t reason_required = 0;
  int32_t code = citizensdk_result_get_history_record(
      result, index, &info, nullptr, 0, &remark_required, nullptr, 0,
      &reason_required);
  if (code != kOk || remark_required > 64 * 1024 ||
      reason_required > 64 * 1024) return false;
  std::vector<uint8_t> remark(static_cast<size_t>(remark_required));
  std::vector<uint8_t> reason(static_cast<size_t>(reason_required));
  info = info_value<citizensdk_history_record_info_t>();
  if (citizensdk_result_get_history_record(
          result, index, &info, remark.empty() ? nullptr : remark.data(),
          remark_required, &remark_required,
          reason.empty() ? nullptr : reason.data(), reason_required,
          &reason_required) != kOk) {
    return false;
  }
  payload->fixed(info.account_id.bytes, 32);
  payload->fixed(info.transaction_hash, 32);
  payload->u64(info.nonce);
  payload->fixed(info.destination_account_id.bytes, 32);
  payload->u64(info.amount_fen.low);
  payload->u64(info.amount_fen.high);
  payload->u32(info.status);
  payload->u8(info.has_block == 0 ? 0 : 1);
  if (info.has_block != 0) write_block(payload, info.block);
  payload->u8(info.has_execution == 0 ? 0 : 1);
  if (info.has_execution != 0) write_execution(payload, info.execution);
  payload->u64(info.created_at_millis);
  payload->u64(info.updated_at_millis);
  payload->bytes(remark.data(), remark.size());
  payload->u8(reason.empty() ? 0 : 1);
  if (!reason.empty()) payload->text(reason);
  return true;
}

bool copy_finalized_transfer(citizensdk_result_handle_t result, uint32_t index,
                             WireWriter *payload) {
  auto info = info_value<citizensdk_finalized_transfer_info_t>();
  uint64_t pallet_required = 0;
  uint64_t display_required = 0;
  uint64_t remark_required = 0;
  int32_t code = citizensdk_result_get_finalized_transfer(
      result, index, &info, nullptr, 0, &pallet_required, nullptr, 0,
      &display_required, nullptr, 0, &remark_required);
  if (code != kOk || pallet_required > 1024 || display_required > 64 * 1024 ||
      remark_required > 64 * 1024) return false;
  std::vector<uint8_t> pallet(static_cast<size_t>(pallet_required));
  std::vector<uint8_t> display(static_cast<size_t>(display_required));
  std::vector<uint8_t> remark(static_cast<size_t>(remark_required));
  info = info_value<citizensdk_finalized_transfer_info_t>();
  if (citizensdk_result_get_finalized_transfer(
          result, index, &info, pallet.empty() ? nullptr : pallet.data(),
          pallet_required, &pallet_required,
          display.empty() ? nullptr : display.data(), display_required,
          &display_required, remark.empty() ? nullptr : remark.data(),
          remark_required, &remark_required) != kOk) {
    return false;
  }
  payload->fixed(info.tracked_account_id.bytes, 32);
  payload->fixed(info.from_account_id.bytes, 32);
  payload->fixed(info.to_account_id.bytes, 32);
  payload->u64(info.amount_fen.low);
  payload->u64(info.amount_fen.high);
  write_block(payload, info.block);
  payload->u32(info.event_record_index);
  payload->u8(info.has_extrinsic_index == 0 ? 0 : 1);
  if (info.has_extrinsic_index != 0) payload->u32(info.extrinsic_index);
  payload->u32(info.direction);
  payload->text(pallet);
  payload->text(display);
  payload->bytes(remark.data(), remark.size());
  return true;
}

bool write_history(citizensdk_result_handle_t result, WireWriter *payload) {
  auto info = info_value<citizensdk_history_info_t>();
  if (citizensdk_result_get_history_info(result, &info) != kOk ||
      info.cursor_count > 1990 || info.record_count > 100000 ||
      info.transfer_count > 100000) return false;
  payload->u64(info.revision);
  payload->u32(info.cursor_count);
  for (uint32_t index = 0; index < info.cursor_count; ++index) {
    auto cursor = info_value<citizensdk_history_cursor_info_t>();
    if (citizensdk_result_get_history_cursor(result, index, &cursor) != kOk)
      return false;
    payload->fixed(cursor.account_id.bytes, 32);
    write_block(payload, cursor.tracking_start_block);
    write_block(payload, cursor.last_synced_block);
  }
  payload->u32(info.record_count);
  for (uint32_t index = 0; index < info.record_count; ++index) {
    if (!copy_history_record(result, index, payload)) return false;
  }
  payload->u32(info.transfer_count);
  for (uint32_t index = 0; index < info.transfer_count; ++index) {
    if (!copy_finalized_transfer(result, index, payload)) return false;
  }
  return true;
}

void write_failure(WireWriter *writer, int32_t code, uint32_t kind,
                   const std::vector<uint8_t> &message) {
  writer->u32(kWireVersion);
  writer->i32(code);
  writer->u32(kind);
  writer->text(message);
}

void write_internal_decode_failure(WireWriter *writer) {
  static const std::vector<uint8_t> message = {
      'J','N','I',' ','c','o','u','l','d',' ','n','o','t',' ','d','e','c','o','d','e',' ',
      't','h','e',' ','C','o','r','e',' ','r','e','s','u','l','t'};
  write_failure(writer, CITIZENSDK_ERROR_INTEGRITY, 0, message);
}

template <typename Call>
jlong begin_request(JNIEnv *env,
                    const std::shared_ptr<CitizenSdkHostBridge> &bridge,
                    Call call) {
  citizensdk_request_id_t request = 0;
  const int32_t code = call(bridge->handle(), &request);
  if (code != kOk || request == 0 ||
      request > static_cast<uint64_t>(std::numeric_limits<jlong>::max())) {
    if (code == kOk && request != 0) {
      // The Core accepted the work but its identity cannot cross the Java
      // boundary. Cancel that exact request instead of creating an orphan.
      citizensdk_cancel_request(bridge->handle(), request);
    }
    throw_sdk(env, code == kOk ? CITIZENSDK_ERROR_INTERNAL : code,
              "CitizenSDK request was rejected");
    return 0;
  }
  return static_cast<jlong>(request);
}

bool account(JNIEnv *env, jbyteArray source, citizensdk_account_id_t *out) {
  std::vector<uint8_t> bytes;
  if (!take_bytes(env, source, &bytes) || bytes.size() != 32) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "CitizenChain AccountId must contain 32 bytes");
    return false;
  }
  std::memcpy(out->bytes, bytes.data(), 32);
  return true;
}

bool accounts(JNIEnv *env, jbyteArray source, jint count,
              std::vector<citizensdk_account_id_t> *out) {
  std::vector<uint8_t> bytes;
  if (count <= 0 || count > 1990 || !take_bytes(env, source, &bytes) ||
      bytes.size() != static_cast<size_t>(count) * 32) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "CitizenChain account array is invalid");
    return false;
  }
  out->resize(static_cast<size_t>(count));
  std::memcpy(out->data(), bytes.data(), bytes.size());
  return true;
}

// JNI methods ----------------------------------------------------------------

jlong native_create(JNIEnv *env, jobject, jobject host_services,
                    jbyteArray manifest, jbyteArray chain_spec,
                    jbyteArray sync_state) {
  std::vector<uint8_t> manifest_bytes;
  std::vector<uint8_t> chain_bytes;
  std::vector<uint8_t> sync_bytes;
  if (host_services == nullptr || !take_bytes(env, manifest, &manifest_bytes) ||
      !take_bytes(env, chain_spec, &chain_bytes) ||
      !take_bytes(env, sync_state, &sync_bytes)) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "CitizenSDK assets or host services are invalid");
    return 0;
  }
  JavaVM *vm = nullptr;
  if (env->GetJavaVM(&vm) != JNI_OK) return 0;
  auto bridge = std::shared_ptr<CitizenSdkHostBridge>(
      new (std::nothrow) CitizenSdkHostBridge(vm, env, host_services));
  if (!bridge) {
    throw_sdk(env, CITIZENSDK_ERROR_INTERNAL, "CitizenSDK JNI allocation failed");
    return 0;
  }
  if (!bridge->create(env, manifest_bytes, chain_bytes, sync_bytes)) {
    return 0;
  }
  {
    std::lock_guard<std::mutex> lock(g_bridges_mutex);
    g_bridges.emplace(reinterpret_cast<intptr_t>(bridge.get()), bridge);
  }
  return static_cast<jlong>(reinterpret_cast<intptr_t>(bridge.get()));
}

void native_bind(JNIEnv *env, jobject owner, jlong raw) {
  if (auto bridge = bridge_from(env, raw)) bridge->bind(env, owner);
}

jint native_lifecycle(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  if (bridge == nullptr) return 0;
  citizensdk_lifecycle_t lifecycle = 0;
  const int32_t code = citizensdk_get_lifecycle(bridge->handle(), &lifecycle);
  if (code != kOk) {
    throw_sdk(env, code, "CitizenSDK lifecycle query failed");
    return 0;
  }
  return static_cast<jint>(lifecycle);
}

jbyteArray native_capabilities(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  if (bridge == nullptr) return nullptr;
  WireWriter writer;
  if (!encode_capabilities(bridge->handle(), &writer)) {
    throw_sdk(env, CITIZENSDK_ERROR_INTERNAL,
              "CitizenSDK capability query failed");
    return nullptr;
  }
  return to_byte_array(env, writer.data());
}

jlong native_refresh_capabilities(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(
      env, bridge, [](auto handle, auto *out) {
        return citizensdk_refresh_capabilities(handle, out);
      });
}

jlong native_start(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(
      env, bridge, [](auto handle, auto *out) { return citizensdk_start(handle, out); });
}

jlong native_stop(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(
      env, bridge, [](auto handle, auto *out) { return citizensdk_stop(handle, out); });
}

jboolean native_cancel(JNIEnv *env, jobject, jlong raw, jlong request_id) {
  auto bridge = bridge_from(env, raw);
  if (bridge == nullptr || request_id <= 0) return JNI_FALSE;
  const int32_t code = citizensdk_cancel_request(
      bridge->handle(), static_cast<uint64_t>(request_id));
  if (code == kOk) return JNI_TRUE;
  if (code == CITIZENSDK_ERROR_NOT_FOUND || code == CITIZENSDK_ERROR_INVALID_STATE)
    return JNI_FALSE;
  throw_sdk(env, code, "CitizenSDK request cannot be cancelled");
  return JNI_FALSE;
}

jlong native_finalized_head(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(
      env, bridge, [](auto handle, auto *out) { return citizensdk_get_finalized_head(handle, out); });
}

jlong native_balance(JNIEnv *env, jobject, jlong raw, jbyteArray account_bytes) {
  auto bridge = bridge_from(env, raw);
  citizensdk_account_id_t value{};
  if (bridge == nullptr || !account(env, account_bytes, &value)) return 0;
  return begin_request(env, bridge, [&value](auto handle, auto *out) {
    return citizensdk_get_finalized_account_balance(handle, &value, out);
  });
}

jlong native_nonce(JNIEnv *env, jobject, jlong raw, jbyteArray account_bytes) {
  auto bridge = bridge_from(env, raw);
  citizensdk_account_id_t value{};
  if (bridge == nullptr || !account(env, account_bytes, &value)) return 0;
  return begin_request(env, bridge, [&value](auto handle, auto *out) {
    return citizensdk_get_account_nonce(handle, &value, out);
  });
}

jlong native_fee(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(env, bridge, [](auto handle, auto *out) {
    return citizensdk_get_best_fee_snapshot(handle, out);
  });
}

jlong native_wallet_profile(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(env, bridge, [](auto handle, auto *out) {
    return citizensdk_get_wallet_profile(handle, out);
  });
}

jlong native_set_active(JNIEnv *env, jobject, jlong raw, jbyteArray account_bytes) {
  auto bridge = bridge_from(env, raw);
  citizensdk_account_id_t value{};
  if (bridge == nullptr || !account(env, account_bytes, &value)) return 0;
  return begin_request(env, bridge, [&value](auto handle, auto *out) {
    return citizensdk_set_active_wallet_account(handle, &value, out);
  });
}

jlong native_rename(JNIEnv *env, jobject, jlong raw, jbyteArray account_bytes,
                    jbyteArray name_bytes) {
  auto bridge = bridge_from(env, raw);
  citizensdk_account_id_t value{};
  std::vector<uint8_t> name;
  if (bridge == nullptr || !account(env, account_bytes, &value) ||
      !take_bytes(env, name_bytes, &name)) return 0;
  return begin_request(env, bridge, [&value, &name](auto handle, auto *out) {
    return citizensdk_rename_wallet_account(handle, &value, view(name), out);
  });
}

jlong native_delete_account(JNIEnv *env, jobject, jlong raw,
                            jbyteArray account_bytes) {
  auto bridge = bridge_from(env, raw);
  citizensdk_account_id_t value{};
  if (bridge == nullptr || !account(env, account_bytes, &value)) return 0;
  return begin_request(env, bridge, [&value](auto handle, auto *out) {
    return citizensdk_delete_wallet_account(handle, &value, out);
  });
}

jlong native_delete_wallet(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(env, bridge, [](auto handle, auto *out) {
    return citizensdk_delete_wallet(handle, out);
  });
}

jlong native_reconcile(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  return bridge == nullptr ? 0 : begin_request(env, bridge, [](auto handle, auto *out) {
    return citizensdk_reconcile_wallet_cleanup(handle, out);
  });
}

jlong native_sign(JNIEnv *env, jobject, jlong raw, jbyteArray account_bytes,
                  jbyteArray message_bytes) {
  auto bridge = bridge_from(env, raw);
  citizensdk_account_id_t value{};
  std::vector<uint8_t> message;
  if (message_bytes == nullptr ||
      env->GetArrayLength(message_bytes) > 16 * 1024 * 1024) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "Sign payload exceeds 16 MiB");
    return 0;
  }
  if (bridge == nullptr || !account(env, account_bytes, &value) ||
      !take_bytes(env, message_bytes, &message)) return 0;
  return begin_request(env, bridge, [&value, &message](auto handle, auto *out) {
    return citizensdk_sign_wallet_payload(handle, &value, view(message), out);
  });
}

jlong native_transfer(JNIEnv *env, jobject, jlong raw, jbyteArray source_bytes,
                      jbyteArray destination_bytes, jlong low, jlong high,
                      jbyteArray remark_bytes) {
  auto bridge = bridge_from(env, raw);
  citizensdk_account_id_t source{};
  citizensdk_account_id_t destination{};
  std::vector<uint8_t> remark;
  if (remark_bytes == nullptr ||
      env->GetArrayLength(remark_bytes) > kMaxTransferRemarkBytes) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "Transfer remark exceeds 99 UTF-8 bytes");
    return 0;
  }
  if (bridge == nullptr || !account(env, source_bytes, &source) ||
      !account(env, destination_bytes, &destination) ||
      !take_bytes(env, remark_bytes, &remark)) return 0;
  citizensdk_u128_t amount{static_cast<uint64_t>(low), static_cast<uint64_t>(high)};
  return begin_request(env, bridge,
                       [&source, &destination, amount, &remark](auto handle, auto *out) {
    return citizensdk_transfer_with_remark(handle, &source, &destination,
                                           amount, view(remark), out);
  });
}

jlong native_history(JNIEnv *env, jlong raw, jbyteArray account_bytes,
                     jint count, bool initialize) {
  auto bridge = bridge_from(env, raw);
  std::vector<citizensdk_account_id_t> values;
  if (bridge == nullptr || !accounts(env, account_bytes, count, &values)) return 0;
  return begin_request(env, bridge, [&values, initialize](auto handle, auto *out) {
    return initialize
               ? citizensdk_initialize_finalized_history(
                     handle, values.data(), static_cast<uint32_t>(values.size()), out)
               : citizensdk_sync_finalized_history_batch(
                     handle, values.data(), static_cast<uint32_t>(values.size()), out);
  });
}

jlong native_history_initialize(JNIEnv *env, jobject, jlong raw,
                                jbyteArray values, jint count) {
  return native_history(env, raw, values, count, true);
}

jlong native_history_sync(JNIEnv *env, jobject, jlong raw, jbyteArray values,
                          jint count) {
  return native_history(env, raw, values, count, false);
}

// 输入检查无持久化副作用，错误消息来自 Core 固定模板，不回显秘密。
void wallet_input_error(JNIEnv *env, int32_t code) {
  if (code == kOk) return;
  uint64_t required = 0;
  std::vector<uint8_t> message;
  if (citizensdk_last_error_copy(nullptr, 0, &required) == kOk && required < 4096) {
    message.resize(static_cast<size_t>(required) + 1, 0);
    if (citizensdk_last_error_copy(message.data(), required, &required) == kOk) {
      throw_sdk(env, code, reinterpret_cast<const char *>(message.data()));
      return;
    }
  }
  throw_sdk(env, code, "Wallet input validation failed");
}

void native_validate_password(JNIEnv *env, jobject, jbyteArray input) {
  SensitiveBytes bytes;
  if (!take_wallet_secret(env, input, bytes.out())) return;
  wallet_input_error(env, citizensdk_validate_wallet_password(view(bytes.value())));
}

void native_validate_mnemonic(JNIEnv *env, jobject, jbyteArray input, jint words) {
  SensitiveBytes bytes;
  if (!take_wallet_secret(env, input, bytes.out())) return;
  wallet_input_error(env, citizensdk_validate_wallet_mnemonic(view(bytes.value()), static_cast<uint32_t>(words)));
}

jbyteArray native_word_suggestions(JNIEnv *env, jobject, jbyteArray input) {
  SensitiveBytes bytes;
  if (!take_wallet_secret(env, input, bytes.out())) return nullptr;
  uint64_t required = 0;
  auto code = citizensdk_wallet_word_suggestions(view(bytes.value()), nullptr, 0, &required);
  if (code != kOk) { wallet_input_error(env, code); return nullptr; }
  if (required > 128) { throw_sdk(env, CITIZENSDK_ERROR_INTEGRITY, "Wallet suggestions exceed limit"); return nullptr; }
  SensitiveBytes output;
  output.out()->resize(static_cast<size_t>(required));
  code = citizensdk_wallet_word_suggestions(view(bytes.value()), output.out()->data(), required, &required);
  if (code != kOk) { wallet_input_error(env, code); return nullptr; }
  auto result = env->NewByteArray(static_cast<jsize>(required));
  if (result != nullptr && required != 0) env->SetByteArrayRegion(result, 0, static_cast<jsize>(required), reinterpret_cast<const jbyte *>(output.value().data()));
  return result;
}

jlong native_prepare(JNIEnv *env, jobject, jlong raw, jint words,
                     jbyteArray password_bytes) {
  auto bridge = bridge_from(env, raw);
  SensitiveBytes password;
  if (bridge == nullptr || !take_wallet_secret(env, password_bytes, password.out())) return 0;
  return begin_request(env, bridge, [&password, words](auto handle, auto *out) {
    return citizensdk_prepare_wallet_creation(handle, static_cast<uint32_t>(words),
                                              view(password.value()), out);
  });
}

jlong native_import(JNIEnv *env, jobject, jlong raw, jbyteArray mnemonic_bytes,
                    jbyteArray password_bytes) {
  auto bridge = bridge_from(env, raw);
  SensitiveBytes mnemonic;
  SensitiveBytes password;
  if (bridge == nullptr ||
      !take_wallet_secret(env, mnemonic_bytes, mnemonic.out()) ||
      !take_wallet_secret(env, password_bytes, password.out())) return 0;
  return begin_request(env, bridge,
                                     [&mnemonic, &password](auto handle, auto *out) {
    return citizensdk_import_wallet(handle, view(mnemonic.value()),
                                    view(password.value()), out);
  });
}

jlong native_add_accounts(JNIEnv *env, jobject, jlong raw,
                          jbyteArray mnemonic_bytes, jbyteArray password_bytes,
                          jintArray index_values) {
  auto bridge = bridge_from(env, raw);
  SensitiveBytes mnemonic;
  SensitiveBytes password;
  std::vector<uint32_t> indices;
  if (bridge == nullptr ||
      !take_wallet_secret(env, mnemonic_bytes, mnemonic.out()) ||
      !take_wallet_secret(env, password_bytes, password.out()) ||
      !take_ints(env, index_values, &indices)) return 0;
  return begin_request(
      env, bridge, [&mnemonic, &password, &indices](auto handle, auto *out) {
        return citizensdk_add_wallet_accounts(
            handle, view(mnemonic.value()), view(password.value()), indices.data(),
            static_cast<uint32_t>(indices.size()), out);
      });
}

jbyteArray native_copy_prepared(JNIEnv *env, jobject, jlong raw, jlong token) {
  auto bridge = bridge_from(env, raw);
  citizensdk_prepared_wallet_handle_t prepared = 0;
  if (bridge == nullptr || !bridge->prepared(static_cast<uint64_t>(token), &prepared)) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_HANDLE,
              "Prepared wallet is unknown or consumed");
    return nullptr;
  }
  uint64_t required = 0;
  int32_t code = citizensdk_prepared_wallet_copy_mnemonic(
      bridge->handle(), prepared, nullptr, 0, &required);
  if (code != kOk || required > 1024) {
    throw_sdk(env, code == kOk ? CITIZENSDK_ERROR_INTEGRITY : code,
              "Prepared recovery phrase is invalid");
    return nullptr;
  }
  std::vector<uint8_t> bytes(static_cast<size_t>(required));
  code = citizensdk_prepared_wallet_copy_mnemonic(
      bridge->handle(), prepared, bytes.data(), required, &required);
  if (code != kOk) {
    secure_zero(&bytes);
    throw_sdk(env, code, "Prepared recovery phrase could not be copied");
    return nullptr;
  }
  jbyteArray result = to_byte_array(env, bytes);
  secure_zero(&bytes);
  return result;
}

jlong native_commit_prepared(JNIEnv *env, jobject, jlong raw, jlong token) {
  auto bridge = bridge_from(env, raw);
  citizensdk_prepared_wallet_handle_t prepared = 0;
  if (bridge == nullptr || !bridge->prepared(static_cast<uint64_t>(token), &prepared)) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_HANDLE,
              "Prepared wallet is unknown or consumed");
    return 0;
  }
  citizensdk_request_id_t request = 0;
  const int32_t code = citizensdk_commit_wallet_creation(
      bridge->handle(), prepared, &request);
  if (code != kOk) {
    throw_sdk(env, code, "Prepared wallet commit was rejected");
    return 0;
  }
  citizensdk_prepared_wallet_handle_t removed = 0;
  bridge->forget_prepared(static_cast<uint64_t>(token), &removed);
  if (request == 0 ||
      request > static_cast<citizensdk_request_id_t>(
                    std::numeric_limits<jlong>::max())) {
    if (request != 0) citizensdk_cancel_request(bridge->handle(), request);
    throw_sdk(env, CITIZENSDK_ERROR_INTERNAL,
              "Core returned a request ID outside the Android contract");
    return 0;
  }
  return static_cast<jlong>(request);
}

void native_release_prepared(JNIEnv *env, jobject, jlong raw, jlong token) {
  auto bridge = bridge_from(env, raw);
  citizensdk_prepared_wallet_handle_t prepared = 0;
  if (bridge == nullptr ||
      !bridge->forget_prepared(static_cast<uint64_t>(token), &prepared)) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_HANDLE,
              "Prepared wallet is unknown or consumed");
    return;
  }
  const int32_t code = citizensdk_prepared_wallet_release(bridge->handle(), prepared);
  if (code != kOk) {
    // A rejected release did not consume the Core handle. Restore the opaque
    // facade token so the caller can retry instead of orphaning the secret.
    bridge->remember_prepared(static_cast<uint64_t>(token), prepared);
    throw_sdk(env, code, "Prepared wallet release failed");
  }
}

void native_destroy(JNIEnv *env, jobject, jlong raw) {
  auto bridge = bridge_from(env, raw);
  if (bridge == nullptr || !bridge->destroy(env)) return;
  {
    std::lock_guard<std::mutex> lock(g_bridges_mutex);
    g_bridges.erase(static_cast<intptr_t>(raw));
  }
}

void native_complete_unwrap(JNIEnv *env, jclass, jlong raw,
                            jlong operation_id, jint error_code) {
  if (auto bridge = bridge_from(env, raw)) {
    bridge->complete_unwrap(static_cast<uint64_t>(operation_id), error_code);
  }
}

const JNINativeMethod kMethods[] = {
    {const_cast<char *>("nativeCreate"),
     const_cast<char *>("(Lorg/citizen/sdk/internal/CitizenSdkHostServices;[B[B[B)J"),
     reinterpret_cast<void *>(native_create)},
    {const_cast<char *>("nativeBind"), const_cast<char *>("(J)V"), reinterpret_cast<void *>(native_bind)},
    {const_cast<char *>("nativeLifecycle"), const_cast<char *>("(J)I"), reinterpret_cast<void *>(native_lifecycle)},
    {const_cast<char *>("nativeCapabilities"), const_cast<char *>("(J)[B"), reinterpret_cast<void *>(native_capabilities)},
    {const_cast<char *>("nativeRefreshCapabilities"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_refresh_capabilities)},
    {const_cast<char *>("nativeStart"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_start)},
    {const_cast<char *>("nativeStop"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_stop)},
    {const_cast<char *>("nativeCancel"), const_cast<char *>("(JJ)Z"), reinterpret_cast<void *>(native_cancel)},
    {const_cast<char *>("nativeGetFinalizedHead"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_finalized_head)},
    {const_cast<char *>("nativeGetAccountBalance"), const_cast<char *>("(J[B)J"), reinterpret_cast<void *>(native_balance)},
    {const_cast<char *>("nativeGetAccountNonce"), const_cast<char *>("(J[B)J"), reinterpret_cast<void *>(native_nonce)},
    {const_cast<char *>("nativeGetFeeSnapshot"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_fee)},
    {const_cast<char *>("nativeGetWalletProfile"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_wallet_profile)},
    {const_cast<char *>("nativeSetActiveWalletAccount"), const_cast<char *>("(J[B)J"), reinterpret_cast<void *>(native_set_active)},
    {const_cast<char *>("nativeRenameWalletAccount"), const_cast<char *>("(J[B[B)J"), reinterpret_cast<void *>(native_rename)},
    {const_cast<char *>("nativeDeleteWalletAccount"), const_cast<char *>("(J[B)J"), reinterpret_cast<void *>(native_delete_account)},
    {const_cast<char *>("nativeDeleteWallet"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_delete_wallet)},
    {const_cast<char *>("nativeReconcileWalletCleanup"), const_cast<char *>("(J)J"), reinterpret_cast<void *>(native_reconcile)},
    {const_cast<char *>("nativeSignWalletPayload"), const_cast<char *>("(J[B[B)J"), reinterpret_cast<void *>(native_sign)},
    {const_cast<char *>("nativeTransferWithRemark"), const_cast<char *>("(J[B[BJJ[B)J"), reinterpret_cast<void *>(native_transfer)},
    {const_cast<char *>("nativeInitializeFinalizedHistory"), const_cast<char *>("(J[BI)J"), reinterpret_cast<void *>(native_history_initialize)},
    {const_cast<char *>("nativeSyncFinalizedHistory"), const_cast<char *>("(J[BI)J"), reinterpret_cast<void *>(native_history_sync)},
    {const_cast<char *>("nativePrepareWalletCreation"), const_cast<char *>("(JI[B)J"), reinterpret_cast<void *>(native_prepare)},
    {const_cast<char *>("nativeValidateWalletPassword"), const_cast<char *>("([B)V"), reinterpret_cast<void *>(native_validate_password)},
    {const_cast<char *>("nativeValidateWalletMnemonic"), const_cast<char *>("([BI)V"), reinterpret_cast<void *>(native_validate_mnemonic)},
    {const_cast<char *>("nativeWalletWordSuggestions"), const_cast<char *>("([B)[B"), reinterpret_cast<void *>(native_word_suggestions)},
    {const_cast<char *>("nativeImportWallet"), const_cast<char *>("(J[B[B)J"), reinterpret_cast<void *>(native_import)},
    {const_cast<char *>("nativeAddWalletAccounts"), const_cast<char *>("(J[B[B[I)J"), reinterpret_cast<void *>(native_add_accounts)},
    {const_cast<char *>("nativeCopyPreparedMnemonic"), const_cast<char *>("(JJ)[B"), reinterpret_cast<void *>(native_copy_prepared)},
    {const_cast<char *>("nativeCommitPreparedWallet"), const_cast<char *>("(JJ)J"), reinterpret_cast<void *>(native_commit_prepared)},
    {const_cast<char *>("nativeReleasePreparedWallet"), const_cast<char *>("(JJ)V"), reinterpret_cast<void *>(native_release_prepared)},
    {const_cast<char *>("nativeDestroy"), const_cast<char *>("(J)V"), reinterpret_cast<void *>(native_destroy)},
    {const_cast<char *>("completeVaultUnwrap"), const_cast<char *>("(JJI)V"), reinterpret_cast<void *>(native_complete_unwrap)},
};

}  // namespace

void throw_sdk(JNIEnv *env, citizensdk_error_code_t code,
               const char *fallback_message) {
  jclass code_class = env->FindClass("org/citizen/sdk/CitizenSdkErrorCode");
  jmethodID from = code_class == nullptr
                       ? nullptr
                       : env->GetStaticMethodID(
                             code_class, "fromValue",
                             "(I)Lorg/citizen/sdk/CitizenSdkErrorCode;");
  jobject code_value = from == nullptr
                           ? nullptr
                           : env->CallStaticObjectMethod(code_class, from, code);
  jclass exception_class = env->FindClass("org/citizen/sdk/CitizenSdkException");
  jmethodID constructor = exception_class == nullptr
                              ? nullptr
                              : env->GetMethodID(
                                    exception_class, "<init>",
                                    "(Lorg/citizen/sdk/CitizenSdkErrorCode;Ljava/lang/String;Ljava/lang/Throwable;)V");
  jstring message = env->NewStringUTF(fallback_message);
  if (!env->ExceptionCheck() && constructor != nullptr && code_value != nullptr &&
      message != nullptr) {
    jobject exception = env->NewObject(exception_class, constructor, code_value,
                                       message, nullptr);
    if (exception != nullptr) env->Throw(static_cast<jthrowable>(exception));
  }
  if (!env->ExceptionCheck()) {
    jclass fallback = env->FindClass("java/lang/IllegalStateException");
    if (fallback != nullptr) env->ThrowNew(fallback, fallback_message);
  }
}

bool take_bytes(JNIEnv *env, jbyteArray source, std::vector<uint8_t> *out) {
  if (source == nullptr) return false;
  const jsize length = env->GetArrayLength(source);
  out->resize(static_cast<size_t>(length));
  if (length != 0) {
    env->GetByteArrayRegion(source, 0, length,
                            reinterpret_cast<jbyte *>(out->data()));
  }
  return !env->ExceptionCheck();
}

bool take_ints(JNIEnv *env, jintArray source, std::vector<uint32_t> *out) {
  if (source == nullptr) return false;
  const jsize length = env->GetArrayLength(source);
  if (length <= 0 || length > kMaxWalletAccountIndices) {
    throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "Wallet index list must contain 1..1989 items");
    return false;
  }
  std::vector<jint> values(static_cast<size_t>(length));
  env->GetIntArrayRegion(source, 0, length, values.data());
  if (env->ExceptionCheck()) return false;
  out->reserve(values.size());
  std::array<bool, 1990> seen{};
  for (const jint value : values) {
    if (value < 1 || value > 1989 || seen[static_cast<size_t>(value)]) {
      throw_sdk(env, CITIZENSDK_ERROR_INVALID_ARGUMENT,
                "Wallet indices must be unique values in 1..1989");
      return false;
    }
    seen[static_cast<size_t>(value)] = true;
    out->push_back(static_cast<uint32_t>(value));
  }
  return true;
}

jbyteArray to_byte_array(JNIEnv *env, const std::vector<uint8_t> &bytes) {
  if (bytes.size() > static_cast<size_t>(std::numeric_limits<jsize>::max())) return nullptr;
  jbyteArray result = env->NewByteArray(static_cast<jsize>(bytes.size()));
  if (result != nullptr && !bytes.empty()) {
    env->SetByteArrayRegion(result, 0, static_cast<jsize>(bytes.size()),
                            reinterpret_cast<const jbyte *>(bytes.data()));
  }
  return result;
}

void WireWriter::u8(uint8_t value) { data_.push_back(value); }
void WireWriter::u32(uint32_t value) {
  for (uint32_t shift = 0; shift < 32; shift += 8)
    data_.push_back(static_cast<uint8_t>(value >> shift));
}
void WireWriter::i32(int32_t value) { u32(static_cast<uint32_t>(value)); }
void WireWriter::u64(uint64_t value) {
  for (uint32_t shift = 0; shift < 64; shift += 8)
    data_.push_back(static_cast<uint8_t>(value >> shift));
}
void WireWriter::fixed(const uint8_t *bytes, size_t length) {
  if (length == 0) return;
  data_.insert(data_.end(), bytes, bytes + length);
}
void WireWriter::bytes(const uint8_t *value, size_t length) {
  u32(static_cast<uint32_t>(length));
  if (length != 0) fixed(value, length);
}
void WireWriter::text(const std::vector<uint8_t> &value) {
  bytes(value.data(), value.size());
}

void write_block(WireWriter *writer, const citizensdk_block_ref_t &block) {
  writer->fixed(block.hash, 32);
  writer->u64(block.number);
  writer->u32(block.finality);
}

void write_execution(WireWriter *writer,
                     const citizensdk_execution_info_t &execution) {
  writer->u32(execution.status);
  writer->u32(execution.reason_or_dispatch_variant);
  writer->u8(execution.has_block == 0 ? 0 : 1);
  if (execution.has_block != 0) write_block(writer, execution.block);
  writer->u8(execution.has_extrinsic_index == 0 ? 0 : 1);
  if (execution.has_extrinsic_index != 0) writer->u32(execution.extrinsic_index);
  writer->u8(execution.has_module == 0 ? 0 : 1);
  if (execution.has_module != 0) {
    writer->u32(execution.pallet_index);
    writer->u32(execution.error_index);
  }
}

bool encode_result(citizensdk_result_handle_t result, uint64_t prepared_token,
                   WireWriter *writer,
                   citizensdk_prepared_wallet_handle_t *prepared) {
  *prepared = 0;
  auto info = info_value<citizensdk_result_info_t>();
  if (citizensdk_result_get_info(result, &info) != kOk) {
    write_internal_decode_failure(writer);
    return true;
  }
  std::vector<uint8_t> message;
  if (!copy_error(result, &message)) {
    write_internal_decode_failure(writer);
    return true;
  }
  if (info.error_code != kOk) {
    write_failure(writer, info.error_code, info.kind, message);
    return true;
  }

  WireWriter payload;
  bool valid = true;
  switch (info.kind) {
    case CITIZENSDK_RESULT_EMPTY:
      break;
    case CITIZENSDK_RESULT_BLOCK_REF: {
      auto block = info_value<citizensdk_block_ref_t>();
      valid = citizensdk_result_get_block_ref(result, &block) == kOk;
      if (valid) write_block(&payload, block);
      break;
    }
    case CITIZENSDK_RESULT_ACCOUNT_BALANCE: {
      auto value = info_value<citizensdk_account_balance_info_t>();
      valid = citizensdk_result_get_account_balance(result, &value) == kOk;
      if (valid) {
        write_block(&payload, value.block);
        payload.fixed(value.account_id.bytes, 32);
        payload.u64(value.free_fen.low); payload.u64(value.free_fen.high);
        payload.u64(value.reserved_fen.low); payload.u64(value.reserved_fen.high);
        payload.u64(value.total_fen.low); payload.u64(value.total_fen.high);
      }
      break;
    }
    case CITIZENSDK_RESULT_ACCOUNT_NONCE: {
      auto value = info_value<citizensdk_account_nonce_info_t>();
      valid = citizensdk_result_get_account_nonce(result, &value) == kOk;
      if (valid) {
        write_block(&payload, value.best_block);
        payload.fixed(value.account_id.bytes, 32);
        payload.u64(value.nonce);
      }
      break;
    }
    case CITIZENSDK_RESULT_FEE_SNAPSHOT: {
      auto value = info_value<citizensdk_fee_snapshot_info_t>();
      valid = citizensdk_result_get_fee_snapshot(result, &value) == kOk;
      if (valid) {
        write_block(&payload, value.best_block);
        payload.u32(value.fee_rate_parts);
        payload.u64(value.minimum_fee_fen.low); payload.u64(value.minimum_fee_fen.high);
        payload.u64(value.existential_deposit_fen.low); payload.u64(value.existential_deposit_fen.high);
      }
      break;
    }
    case CITIZENSDK_RESULT_WALLET_PROFILE:
      valid = write_wallet_profile(result, &payload);
      break;
    case CITIZENSDK_RESULT_WALLET_ACCOUNTS:
      valid = write_wallet_accounts(result, &payload);
      break;
    case CITIZENSDK_RESULT_SIGNATURE: {
      uint8_t signature[64]{};
      valid = citizensdk_result_get_signature(result, signature) == kOk;
      if (valid) payload.fixed(signature, sizeof(signature));
      std::memset(signature, 0, sizeof(signature));
      break;
    }
    case CITIZENSDK_RESULT_PREPARED_WALLET: {
      auto value = info_value<citizensdk_prepared_wallet_info_t>();
      const bool copied = citizensdk_result_get_prepared_wallet(result, &value) == kOk;
      if (copied) {
        *prepared = value.prepared_wallet;
      }
      valid = copied && prepared_token != 0;
      if (valid) {
        payload.u64(prepared_token);
      }
      break;
    }
    case CITIZENSDK_RESULT_WALLET_TRANSFER:
      valid = copy_wallet_transfer(result, &payload);
      break;
    case CITIZENSDK_RESULT_TRANSACTION_HISTORY:
      valid = write_history(result, &payload);
      break;
    default:
      valid = false;
      break;
  }
  if (!valid) {
    write_internal_decode_failure(writer);
    return true;
  }
  writer->u32(kWireVersion);
  writer->i32(kOk);
  writer->u32(info.kind);
  writer->text(message);
  writer->fixed(payload.data().data(), payload.data().size());
  return true;
}

bool encode_capabilities(citizensdk_handle_t handle, WireWriter *writer) {
  auto snapshot = info_value<citizensdk_capability_snapshot_t>();
  if (citizensdk_get_capabilities(handle, &snapshot) != kOk ||
      snapshot.count != CITIZENSDK_CAPABILITY_COUNT) return false;
  writer->u32(kWireVersion);
  writer->u64(snapshot.revision);
  writer->u32(snapshot.count);
  for (uint32_t index = 0; index < snapshot.count; ++index) {
    const auto &status = snapshot.statuses[index];
    writer->u32(status.name);
    writer->u32(status.reason);
    writer->u8(status.supported); writer->u8(status.available);
    writer->u8(status.enabled); writer->u8(status.ready);
  }
  return true;
}

bool encode_watch(citizensdk_result_handle_t result, WireWriter *writer) {
  auto info = info_value<citizensdk_watch_event_info_t>();
  if (citizensdk_result_get_watch_event(result, &info) != kOk) return false;
  writer->u32(kWireVersion);
  writer->u32(info.status);
  writer->u32(info.peer_count);
  writer->u8(info.has_block == 0 ? 0 : 1);
  if (info.has_block != 0) write_block(writer, info.block);
  writer->u8(info.has_replacement_hash == 0 ? 0 : 1);
  if (info.has_replacement_hash != 0)
    writer->fixed(info.replacement_hash, 32);
  return true;
}

}  // namespace citizen::sdk::jni

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
  JNIEnv *env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK)
    return JNI_ERR;
  jclass type = env->FindClass("org/citizen/sdk/internal/CitizenSdkNative");
  if (type == nullptr) return JNI_ERR;
  const jint result = env->RegisterNatives(
      type, citizen::sdk::jni::kMethods,
      static_cast<jint>(sizeof(citizen::sdk::jni::kMethods) /
                        sizeof(citizen::sdk::jni::kMethods[0])));
  env->DeleteLocalRef(type);
  return result == JNI_OK ? JNI_VERSION_1_6 : JNI_ERR;
}
