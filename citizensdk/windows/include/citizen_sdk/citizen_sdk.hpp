#ifndef CITIZENSDK_CPP_HPP
#define CITIZENSDK_CPP_HPP

#include <exception>
#include <limits>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include "citizen_sdk/citizen_sdk_config.hpp"
#include "citizen_sdk/citizen_sdk_error.hpp"
#include "citizen_sdk/citizen_sdk_events.hpp"
#include "citizen_sdk/citizen_sdk_models.hpp"
#include "citizen_sdk/citizen_sdk_wallet_flow.hpp"

namespace citizen_sdk {
namespace detail {

struct EventContext final {
  std::mutex lock;
  EventObserver observer;
};

struct EventResultScope final {
  explicit EventResultScope(citizensdk_result_handle_t value) noexcept
      : value(value) {}
  EventResultScope(const EventResultScope &) = delete;
  EventResultScope &operator=(const EventResultScope &) = delete;
  ~EventResultScope() {
    if (value != 0) (void)citizensdk_result_release(value);
  }
  citizensdk_result_handle_t value{};
};

struct WalletCompletionContext final { WalletFlowCompletion completion; };

inline void event_trampoline(void *context,
                             const citizensdk_event_t *event) noexcept {
  if (event == nullptr) return;
  EventResultScope result_owner(event->result);
  if (context == nullptr) return;
  EventObserver observer;
  try {
    auto *state = static_cast<EventContext *>(context);
    {
      std::lock_guard<std::mutex> guard(state->lock);
      observer = state->observer;
    }
    if (observer) observer(*event);
  } catch (...) {}
}

inline void wallet_trampoline(
    void *context, const citizensdk_wallet_flow_result_v1_t *result) noexcept {
  std::unique_ptr<WalletCompletionContext> state(
      static_cast<WalletCompletionContext *>(context));
  if (!state) return;
  try {
    if (result == nullptr || result->struct_size < sizeof(*result) ||
        result->abi_version != CITIZENSDK_HOST_ABI_VERSION) {
      state->completion(
          {WalletFlowStatus::Failed, CITIZENSDK_ERROR_INTEGRITY});
    } else {
      state->completion({static_cast<WalletFlowStatus>(result->status),
                         result->error_code});
    }
  } catch (...) {}
}

}  // namespace detail

/* Header-only ownership wrapper. Construction owns only Host resources; open()
 * is explicit so a Core setup error never loses the still-retryable Host
 * handle. Applications must stop and await Core before close(). */
class Host final {
 public:
  explicit Host(const Config &config) {
    const std::string storage = config.storage_root.u8string();
    const std::string assets = config.asset_root.u8string();
    citizensdk_host_config_v1_t native{};
    native.struct_size = sizeof(native);
    native.abi_version = CITIZENSDK_HOST_ABI_VERSION;
    native.storage_root_utf8 = bytes_view(storage);
    native.asset_root_utf8 = bytes_view(assets);
    native.application_id_utf8 = bytes_view(config.application_id);
    native.hwnd = config.hwnd;
    native.enable_wallet = config.enable_wallet ? 1 : 0;
    throw_if_error(citizensdk_host_create(&native, &host_),
                   "CitizenSDK Host creation failed");
  }

  Host(const Host &) = delete;
  Host &operator=(const Host &) = delete;
  Host(Host &&other) noexcept
      : host_(other.host_), sdk_(other.sdk_),
        event_context_(std::move(other.event_context_)) {
    other.host_ = 0;
    other.sdk_ = 0;
  }
  Host &operator=(Host &&other) noexcept {
    if (this != &other) {
      close_noexcept();
      host_ = other.host_;
      sdk_ = other.sdk_;
      event_context_ = std::move(other.event_context_);
      other.host_ = 0;
      other.sdk_ = 0;
    }
    return *this;
  }
  ~Host() { close_noexcept(); }

  void open() {
    if (sdk_ != 0) return;
    throw_if_error(citizensdk_host_create_sdk(host_, &sdk_),
                   "CitizenSDK Core creation failed");
  }

  citizensdk_handle_t native_handle() const noexcept { return sdk_; }
  citizensdk_host_handle_t host_handle() const noexcept { return host_; }

  void set_parent_window(void *window) {
    throw_if_error(citizensdk_host_set_parent_window(host_, window),
                   "CitizenSDK parent window update failed");
  }

  void set_event_observer(EventObserver observer) {
    if (!observer) {
      throw_if_error(citizensdk_host_set_event_callback(host_, nullptr, nullptr),
                     "CitizenSDK event observer clear failed");
      event_context_.reset();
      return;
    }
    auto state = std::make_unique<detail::EventContext>();
    state->observer = std::move(observer);
    throw_if_error(citizensdk_host_set_event_callback(
                       host_, detail::event_trampoline, state.get()),
                   "CitizenSDK event observer registration failed");
    event_context_ = std::move(state);
  }

  Capabilities capabilities() const {
    citizensdk_capability_snapshot_t snapshot{};
    snapshot.struct_size = sizeof(snapshot);
    snapshot.abi_version = CITIZENSDK_ABI_VERSION;
    const auto code = citizensdk_get_capabilities(sdk_, &snapshot);
    if (code != CITIZENSDK_OK) {
      throw Error(code, "CitizenSDK capability query failed");
    }
    if (snapshot.count != CITIZENSDK_CAPABILITY_COUNT) {
      throw Error(CITIZENSDK_ERROR_INTEGRITY,
                  "CitizenSDK capability snapshot has an incompatible size");
    }
    Capabilities result;
    result.revision = snapshot.revision;
    result.statuses.reserve(snapshot.count);
    for (uint32_t index = 0; index < snapshot.count; ++index) {
      const auto &value = snapshot.statuses[index];
      result.statuses.push_back({value.name, value.reason,
                                 value.supported != 0, value.available != 0,
                                 value.enabled != 0, value.ready != 0});
    }
    return result;
  }

  citizensdk_host_vault_availability_t vault_availability() const {
    citizensdk_host_vault_availability_t value{};
    throw_if_error(citizensdk_host_vault_availability(host_, &value),
                   "CitizenSDK vault availability query failed");
    return value;
  }

  WalletFlow present_wallet_flow(const WalletFlowRequest &request,
                                 WalletFlowCompletion completion) {
    if (!completion) {
      throw Error(CITIZENSDK_ERROR_INVALID_ARGUMENT,
                  "wallet-flow completion is required");
    }
    citizensdk_wallet_flow_request_v1_t native{};
    native.struct_size = sizeof(native);
    native.abi_version = CITIZENSDK_HOST_ABI_VERSION;
    native.kind = static_cast<uint32_t>(request.kind);
    native.word_count = request.word_count;
    if (request.account_indices.size() >
        static_cast<std::size_t>(std::numeric_limits<uint32_t>::max())) {
      throw Error(CITIZENSDK_ERROR_INVALID_ARGUMENT,
                  "wallet-flow account index count exceeds the C ABI");
    }
    native.account_indices = request.account_indices.empty()
                                 ? nullptr : request.account_indices.data();
    native.account_index_count =
        static_cast<uint32_t>(request.account_indices.size());
    auto state = std::make_unique<detail::WalletCompletionContext>();
    state->completion = std::move(completion);
    citizensdk_wallet_flow_handle_t flow = 0;
    const auto code = citizensdk_host_present_wallet_flow(
        host_, &native, state.get(), detail::wallet_trampoline, &flow);
    if (code != CITIZENSDK_OK) {
      throw Error(code, last_host_error("CitizenSDK wallet flow failed"));
    }
    (void)state.release();
    return WalletFlow(host_, flow);
  }

  void close() {
    if (host_ == 0) return;
    // Windows 窗口退休可以晚于 Core 销毁。上次 BUSY 后不能再查询已经
    // 释放的缓存 Core handle；以仍然存活的 Host 为唯一所有权真源。
    refresh_core_handle();
    if (sdk_ != 0) {
      citizensdk_lifecycle_t lifecycle = 0;
      const auto code = citizensdk_get_lifecycle(sdk_, &lifecycle);
      if (code != CITIZENSDK_OK) throw Error(code, "CitizenSDK lifecycle query failed");
      if (lifecycle == CITIZENSDK_LIFECYCLE_RUNNING ||
          lifecycle == CITIZENSDK_LIFECYCLE_STARTING ||
          lifecycle == CITIZENSDK_LIFECYCLE_IMPORTING_STATE) {
        throw Error(CITIZENSDK_ERROR_BUSY,
                    "stop CitizenSDK and await its checkpoint before close");
      }
    }
    // Preserve the observer when close is rejected as BUSY. Once the lifecycle
    // gate passes, clearing it is the synchronization barrier that makes the
    // EventContext safe to destroy.
    if (event_context_) {
      throw_if_error(citizensdk_host_set_event_callback(host_, nullptr, nullptr),
                     "CitizenSDK event observer clear failed");
      event_context_.reset();
    }
    const auto closed = citizensdk_host_destroy(host_);
    if (closed != CITIZENSDK_OK) {
      refresh_core_handle();
      throw_if_error(closed, "CitizenSDK Host close failed");
    }
    host_ = 0;
    sdk_ = 0;
  }

 private:
  void refresh_core_handle() {
    citizensdk_handle_t current = 0;
    const auto code = citizensdk_host_sdk(host_, &current);
    if (code == CITIZENSDK_OK) sdk_ = current;
    else if (code == CITIZENSDK_ERROR_NOT_READY) sdk_ = 0;
    else throw_if_error(code, "CitizenSDK Host ownership query failed");
  }

  void close_noexcept() noexcept {
    if (host_ == 0) return;
    // Clearing the Host callback is a synchronization barrier: success waits
    // for every callback frame, including a std::function copy, to retire. A
    // destructor running inside its own callback is also supported by Host.
    // A failed barrier transfers the Host to its supervisor; if ownership
    // cannot be transferred, terminate rather than leak or free a still-
    // borrowed raw context. Long-lived retries belong only to the supervisor.
    bool transferred = false;
    if (event_context_) {
      const auto clear =
          citizensdk_host_set_event_callback(host_, nullptr, nullptr);
      if (clear != CITIZENSDK_OK &&
          clear != CITIZENSDK_ERROR_INVALID_HANDLE) {
        const auto abandon = citizensdk_host_abandon(host_);
        if (abandon != CITIZENSDK_OK &&
            abandon != CITIZENSDK_ERROR_INVALID_HANDLE) {
          std::terminate();
        }
        transferred = true;
      }
      event_context_.reset();
    }
    const auto code = transferred ? CITIZENSDK_OK
                                  : citizensdk_host_destroy(host_);
    if (!transferred && code != CITIZENSDK_OK &&
        code != CITIZENSDK_ERROR_INVALID_HANDLE) {
      // abandon transfers the complete Host/Core/store/vault graph to its
      // process supervisor; it never borrows this C++ object or event context.
      const auto abandon = citizensdk_host_abandon(host_);
      if (abandon != CITIZENSDK_OK &&
          abandon != CITIZENSDK_ERROR_INVALID_HANDLE) {
        std::terminate();
      }
    }
    host_ = 0;
    sdk_ = 0;
  }

  citizensdk_host_handle_t host_{};
  citizensdk_handle_t sdk_{};
  std::unique_ptr<detail::EventContext> event_context_;
};

}  // namespace citizen_sdk

#endif
