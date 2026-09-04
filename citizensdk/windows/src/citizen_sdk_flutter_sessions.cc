#include "citizen_sdk_flutter_sessions.hpp"

#include <windows.h>
#include <bcrypt.h>
#include <array>
#include <exception>
#include <limits>
#include <map>
#include <mutex>
#include <optional>
#include <thread>
#include <utility>
#include <vector>
#include "citizen_sdk/citizen_sdk.hpp"

namespace citizen_sdk::flutter {

bool allow_close_without_core(bool close_attempted,
                              citizensdk_lifecycle_t checkpoint_state,
                              citizensdk_error_code_t host_status,
                              citizensdk_handle_t core) {
  if (host_status == CITIZENSDK_OK) {
    if (core == 0) throw Error(CITIZENSDK_ERROR_INTEGRITY,
                               "CitizenSDK Host returned an empty Core handle");
    return false;
  }
  if (host_status == CITIZENSDK_ERROR_NOT_READY && core == 0 && close_attempted &&
      (checkpoint_state == CITIZENSDK_LIFECYCLE_CREATED ||
       checkpoint_state == CITIZENSDK_LIFECYCLE_START_FAILED ||
       checkpoint_state == CITIZENSDK_LIFECYCLE_STOPPED)) return true;
  throw Error(host_status, "CitizenSDK Host Core ownership is unavailable");
}

namespace {

citizensdk_bytes_view_t view(const std::vector<uint8_t> &bytes) noexcept {
  return {bytes.empty() ? nullptr : bytes.data(), static_cast<uint64_t>(bytes.size())};
}

// This adapter contains no chain/wallet algorithm. Every accepted method goes
// directly to the same installed Host/Core used by the native C/C++ binding.
class HostTransport final : public NativeTransport {
 public:
  explicit HostTransport(const Config &config) : host_(std::make_unique<Host>(config)) {
    host_->open();
  }
  ~HostTransport() override = default;
  void observe(Observer observer) override {
    require_open();
    host_->set_event_observer(std::move(observer));
  }
  citizensdk_error_code_t accept(Method native_method, const DecodedRequest &r,
                                citizensdk_request_id_t *out) override {
    if (!host_ || close_attempted_) return CITIZENSDK_ERROR_INVALID_STATE;
    const auto sdk = host_->native_handle();
    switch (native_method) {
      case Method::start: return citizensdk_start(sdk, out);
      case Method::stop: return citizensdk_stop(sdk, out);
      case Method::get_finalized_head: return citizensdk_get_finalized_head(sdk, out);
      case Method::get_account_balance:
        return citizensdk_get_finalized_account_balance(sdk, &r.account_id, out);
      case Method::get_account_nonce: return citizensdk_get_account_nonce(sdk, &r.account_id, out);
      case Method::get_fee_snapshot: return citizensdk_get_best_fee_snapshot(sdk, out);
      case Method::get_wallet_profile: return citizensdk_get_wallet_profile(sdk, out);
      case Method::set_active_wallet_account:
        return citizensdk_set_active_wallet_account(sdk, &r.account_id, out);
      case Method::rename_wallet_account:
        return citizensdk_rename_wallet_account(sdk, &r.account_id, bytes_view(r.name), out);
      case Method::delete_wallet_account:
        return citizensdk_delete_wallet_account(sdk, &r.account_id, out);
      case Method::delete_wallet: return citizensdk_delete_wallet(sdk, out);
      case Method::reconcile_wallet_cleanup: return citizensdk_reconcile_wallet_cleanup(sdk, out);
      case Method::sign_wallet_payload:
        return citizensdk_sign_wallet_payload(sdk, &r.account_id, view(r.payload), out);
      case Method::transfer_with_remark:
        return citizensdk_transfer_with_remark(sdk, &r.account_id, &r.destination,
                                             r.amount, view(r.remark), out);
      case Method::initialize_finalized_history:
        return citizensdk_initialize_finalized_history(sdk, r.account_ids.data(),
                     static_cast<uint32_t>(r.account_ids.size()), out);
      case Method::sync_finalized_history:
        return citizensdk_sync_finalized_history_batch(sdk, r.account_ids.data(),
                     static_cast<uint32_t>(r.account_ids.size()), out);
      // open/close/capabilities are synchronous Host operations; the three
      // secret-bearing wallet mutations are admitted only by existing Win32 UI.
      case Method::open: case Method::close: case Method::get_capabilities:
      case Method::create_wallet: case Method::import_wallet: case Method::add_wallet_accounts:
        return CITIZENSDK_ERROR_UNSUPPORTED;
    }
    return CITIZENSDK_ERROR_UNSUPPORTED;
  }
  Value copy_result(Method method, citizensdk_result_handle_t result) override {
    return copy_public_result(method, result);
  }
  Value copy_progress(citizensdk_result_handle_t result, int64_t sequence) override {
    return watch_payload(result, sequence);
  }
  citizensdk_lifecycle_t lifecycle_state() override {
    if (!host_) throw Error(CITIZENSDK_ERROR_INVALID_STATE, "CitizenSDK Host is retired");
    citizensdk_handle_t core = 0;
    const auto status = citizensdk_host_sdk(host_->host_handle(), &core);
    if (allow_close_without_core(close_attempted_, checkpoint_state_, status, core)) {
      // 仅供 progress_close 再进 Host::close；不能提前发送 disposed 或重建 Core。
      return checkpoint_state_;
    }
    citizensdk_lifecycle_t state{};
    const auto code = citizensdk_get_lifecycle(core, &state);
    if (code != CITIZENSDK_OK) throw Error(code, "CitizenSDK lifecycle query failed");
    return state;
  }
  Value capability_snapshot() override {
    require_open();
    citizensdk_capability_snapshot_t snapshot{};
    snapshot.struct_size = sizeof(snapshot);
    snapshot.abi_version = CITIZENSDK_ABI_VERSION;
    const auto code = citizensdk_get_capabilities(host_->native_handle(), &snapshot);
    if (code != CITIZENSDK_OK) throw Error(code, "CitizenSDK capability query failed");
    return capabilities(snapshot);
  }
  void cancel(citizensdk_request_id_t request) override {
    require_open();
    const auto code = citizensdk_cancel_request(host_->native_handle(), request);
    if (code != CITIZENSDK_OK && code != CITIZENSDK_ERROR_NOT_FOUND &&
        code != CITIZENSDK_ERROR_INVALID_HANDLE)
      throw Error(code, "CitizenSDK request cancellation failed");
  }
  WalletCancellation present(const WalletFlowRequest &request,
                              WalletFlowCompletion completion) override {
    require_open();
    auto flow = host_->present_wallet_flow(request, std::move(completion));
    return [flow]() mutable { flow.cancel(); };
  }
  void close() override {
    if (!host_) throw Error(CITIZENSDK_ERROR_INVALID_STATE, "CitizenSDK Host is retired");
    if (!close_attempted_) {
      const auto state = lifecycle_state();
      if (state != CITIZENSDK_LIFECYCLE_CREATED &&
          state != CITIZENSDK_LIFECYCLE_START_FAILED &&
          state != CITIZENSDK_LIFECYCLE_STOPPED)
        throw Error(CITIZENSDK_ERROR_BUSY, "CitizenSDK must stop before Host close");
      checkpoint_state_ = state;
      close_attempted_ = true;
    }
    // 调用已存在的公开 Host 所有权实现。失败后只允许再次 close 或 retire，
    // 不接受任何新链操作、能力查询或钱包流程，不另建 Windows teardown。
    host_->close();
  }
  void retire() noexcept override {
    // Host::~Host performs its callback barrier and, if needed, transfers the
    // full Host/Core/store/vault graph to the existing process supervisor.
    host_.reset();
  }
 private:
  void require_open() const {
    if (!host_ || close_attempted_)
      throw Error(CITIZENSDK_ERROR_INVALID_STATE, "CitizenSDK Host is closing or retired");
  }
  std::unique_ptr<Host> host_;
  citizensdk_lifecycle_t checkpoint_state_{};
  bool close_attempted_{};
};

std::string random_session_id() {
  std::array<uint8_t, 16> bytes{};
  // Windows 系统 CSPRNG；session 只是公开路由标识，不是钱包/登录凭据。
  if (::BCryptGenRandom(nullptr, bytes.data(), static_cast<ULONG>(bytes.size()),
                        BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0)
    throw ContractFailure(CITIZENSDK_ERROR_UNAVAILABLE,
                          "CitizenSDK session entropy is unavailable");
  static constexpr char hex[] = "0123456789abcdef";
  std::string value; value.reserve(32);
  for (const auto byte : bytes) {
    value.push_back(hex[static_cast<std::size_t>(byte >> 4)]);
    value.push_back(hex[static_cast<std::size_t>(byte & 15)]);
  }
  return value;
}

Reply failure(citizensdk_error_code_t code, const std::string &message,
              const DecodedRequest &request) {
  const bool open = request.method == Method::open;
  return {false, error_details(code, message,
          open ? std::optional<std::string>{} : request.session,
          open ? std::optional<int64_t>{} : request.sequence), code, message};
}

Reply success(const DecodedRequest &request, Value payload) {
  return {true, response(request.session, request.sequence, std::move(payload)),
          CITIZENSDK_OK, {}};
}

std::mutex &process_mutation_lock() { static std::mutex value; return value; }
std::weak_ptr<void> &process_mutation_owner() {
  static std::weak_ptr<void> value;
  return value;
}
bool acquire_process_mutation(const std::shared_ptr<void> &owner) {
  // 全进程共享，不按 session 或 Flutter engine 分裂；并发变更直接 BUSY。
  std::lock_guard<std::mutex> guard(process_mutation_lock());
  if (!process_mutation_owner().expired()) return false;
  process_mutation_owner() = owner;
  return true;
}
void release_process_mutation(const std::shared_ptr<void> &owner) noexcept {
  std::lock_guard<std::mutex> guard(process_mutation_lock());
  const auto current = process_mutation_owner().lock();
  if (current == owner) process_mutation_owner().reset();
}

}  // namespace

struct Sessions::State final : std::enable_shared_from_this<State> {
  struct Route final {
    DecodedRequest request;
    // Public method/arguments never change. native_method alone advances an
    // approved compound operation to its private profile-read stage.
    Method native_method{Method::open};
    ReplyCallback reply;
    citizensdk_request_id_t native_id{};
    std::optional<Reply> ready;
    bool accepting{};
    bool terminal_seen{};
    bool completed{};
    bool close_stop{};
    bool wallet{};
    bool mutation{};
    bool fetch_profile_after_mutation{};
    std::shared_ptr<void> mutation_owner;
  };
  struct Session final {
    std::string id;
    std::shared_ptr<NativeTransport> transport;
    int64_t next_request{1};
    int64_t next_event{1};
    std::mutex lock;
    std::map<int64_t, std::shared_ptr<Route>> routes;
    std::shared_ptr<Route> admitting;
    bool closing{};
    bool retired{};
    std::optional<DecodedRequest> close_request;
    ReplyCallback close_reply;
  };

  State(EnvironmentFactory source, Scheduler queue, TransportFactory make)
      : environment(std::move(source)), schedule(std::move(queue)),
        factory(std::move(make)), wallets(schedule), owner(std::this_thread::get_id()) {}
  EnvironmentFactory environment;
  Scheduler schedule;
  TransportFactory factory;
  FlutterWalletFlows wallets;
  std::thread::id owner;
  std::map<std::string, std::shared_ptr<Session>> sessions;
  EventSink sink;
  // One process-local gate matches Android/Apple: every profile mutation,
  // including SDK-owned UI and a required post-mutation profile read, is
  // serialized across all sessions and plugin/Flutter-engine instances.
  std::shared_ptr<Route> active_mutation;
  // The callback thread snapshots epoch under this lock; all Flutter objects
  // remain UI-owned and are never accessed from that thread.
  std::mutex epoch_lock;
  uint64_t epoch{};
  bool detached{};
  std::shared_ptr<State> detached_owner;
  void retain_detached_state() {
    // detach 只撤销 Flutter 回调，不等于原生操作完成。自保活无需新增线程或
    // 分配全局队列；待已接受请求排空后解除，再交既有 Host supervisor。
    if (!detached_owner) detached_owner = shared_from_this();
  }
  void release_detached_state_if_empty() {
    if (sessions.empty()) detached_owner.reset();
  }

  void require_owner() const {
    if (std::this_thread::get_id() != owner)
      throw ContractFailure(CITIZENSDK_ERROR_INVALID_STATE,
                            "CitizenSDK Flutter entry point requires the UI thread");
  }

  uint64_t snapshot_epoch() {
    std::lock_guard<std::mutex> guard(epoch_lock);
    return epoch;
  }
  void advance_epoch(bool detach_now = false) {
    std::lock_guard<std::mutex> guard(epoch_lock);
    if (epoch == std::numeric_limits<uint64_t>::max()) {
      detached = true;
      throw ContractFailure(CITIZENSDK_ERROR_INTEGRITY,
                            "CitizenSDK subscription generation is exhausted");
    }
    ++epoch;
    if (detach_now) detached = true;
  }
  bool is_detached() {
    std::lock_guard<std::mutex> guard(epoch_lock);
    return detached;
  }

  bool current(const std::shared_ptr<Session> &session) const {
    const auto found = sessions.find(session->id);
    return found != sessions.end() && found->second == session && !session->retired;
  }
  void emit(const std::shared_ptr<Session> &session, const std::string &type,
            Value payload, uint64_t expected) {
    if (is_detached() || expected != snapshot_epoch() || !sink || !current(session)) return;
    if (session->next_event == std::numeric_limits<int64_t>::max()) {
      // Fail closed instead of wrapping/reusing an event sequence.
      cancel_events();
      throw ContractFailure(CITIZENSDK_ERROR_INTEGRITY,
                            "CitizenSDK event sequence is exhausted");
    }
    const auto sequence = session->next_event++;
    auto callback = sink;
    callback(event(session->id, sequence, type, std::move(payload)));
  }
  void snapshots(const std::shared_ptr<Session> &session, uint64_t expected,
                 citizensdk_event_type_t kind = 0) {
    if (!current(session) || is_detached() || expected != snapshot_epoch()) return;
    // Core callbacks carry only a notification, not an owned snapshot. Query
    // on the UI thread after the callback returns, never re-enter Core while
    // its dispatch thread may hold lifecycle/provider locks.
    if (kind == 0 || kind == CITIZENSDK_EVENT_LIFECYCLE_CHANGED)
      emit(session, "lifecycleChanged",
           Value::list({lifecycle(session->transport->lifecycle_state())}), expected);
    if (kind == 0 || kind == CITIZENSDK_EVENT_CAPABILITIES_CHANGED)
      emit(session, "capabilitiesChanged",
           Value::list({session->transport->capability_snapshot()}), expected);
  }

  void post_drain(const std::shared_ptr<Session> &session) noexcept {
    try {
      std::weak_ptr<State> weak = shared_from_this();
      std::weak_ptr<Session> target = session;
      schedule([weak, target] {
        if (const auto state = weak.lock()) if (const auto value = target.lock()) {
          try { state->drain(value); } catch (...) {}
        }
      });
    } catch (...) {
      // Route::ready remains authoritative until the next UI dispatch/drain.
      // No borrowed result or callback pointer is stored in this recovery path.
    }
  }

  void receive(const std::shared_ptr<Session> &session,
               const citizensdk_event_t &event_value) noexcept {
    const auto expected = snapshot_epoch();
    if (event_value.struct_size < sizeof(event_value) ||
        event_value.abi_version != CITIZENSDK_ABI_VERSION) return;
    if (event_value.event_type == CITIZENSDK_EVENT_LIFECYCLE_CHANGED ||
        event_value.event_type == CITIZENSDK_EVENT_CAPABILITIES_CHANGED) {
      try {
        std::weak_ptr<State> weak = shared_from_this();
        std::weak_ptr<Session> target = session;
        const auto kind = event_value.event_type;
        schedule([weak, target, expected, kind] {
          if (const auto state = weak.lock()) if (const auto value = target.lock()) {
            try { state->snapshots(value, expected, kind); } catch (...) {}
          }
        });
      } catch (...) {}
      return;
    }
    if (event_value.request_id == 0 || event_value.result == 0) return;
    std::shared_ptr<Route> route;
    {
      std::lock_guard<std::mutex> guard(session->lock);
      for (const auto &pair : session->routes) {
        if (pair.second->native_id == event_value.request_id) { route = pair.second; break; }
      }
      // Only one accepting call exists on the owner thread. Its route and
      // projection method were allocated before entering Core. A callback may
      // bind the integer ID first, but the returning call must confirm it.
      if (!route && session->admitting && session->admitting->native_id == 0) {
        route = session->admitting;
        route->native_id = event_value.request_id;
      }
      if (!route || route->terminal_seen) return;
      if (event_value.event_type == CITIZENSDK_EVENT_REQUEST_COMPLETED)
        route->terminal_seen = true;
      else if (event_value.event_type != CITIZENSDK_EVENT_WATCH_UPDATE ||
               route->native_method != Method::transfer_with_remark) return;
    }
    if (event_value.event_type == CITIZENSDK_EVENT_WATCH_UPDATE) {
      try {
        Value payload = session->transport->copy_progress(event_value.result, route->request.sequence);
        std::weak_ptr<State> weak = shared_from_this();
        std::weak_ptr<Session> target = session;
        schedule([weak, target, expected, payload = std::move(payload)]() mutable {
          if (const auto state = weak.lock()) if (const auto value = target.lock()) {
            try { state->emit(value, "transferProgress", std::move(payload), expected); } catch (...) {}
          }
        });
      } catch (...) {}
      return;
    }
    std::optional<Reply> copied;
    try { copied = success(route->request,
                           session->transport->copy_result(route->native_method, event_value.result)); }
    catch (const ContractFailure &error) { copied = failure(error.code, error.what(), route->request); }
    catch (const Error &error) { copied = failure(error.code(), error.what(), route->request); }
    catch (...) {
      try { copied = failure(CITIZENSDK_ERROR_INTERNAL,
                             "CitizenSDK public result copying failed", route->request); }
      catch (...) {
        // Allocation failure cannot release the accepted route's owner. The
        // route remains completed and drain turns the absent copy into error.
      }
    }
    {
      std::lock_guard<std::mutex> guard(session->lock);
      route->ready = std::move(copied);
      // Completion becomes drainable only after public data copying has ended.
      // accept() may return concurrently while its callback is still copying;
      // exposing terminal_seen alone would remove the route too early.
      // 已收到终态与复制完成是两件事；只有 completed 才允许 UI 移除 route。
      route->completed = true;
    }
    // Host's observer wrapper releases the borrowed native result exactly once
    // after this function returns, including every rejected/failed decode.
    post_drain(session);
  }

  void open(ReplyCallback reply) {
    DecodedRequest request;
    std::shared_ptr<Session> session;
    std::optional<Reply> outcome;
    try {
      auto source = environment(); // keeps upgraded parent alive through Host creation
      session = std::make_shared<Session>();
      session->id = random_session_id();
      session->transport = factory(source.config);
      if (!session->transport) throw ContractFailure(CITIZENSDK_ERROR_UNAVAILABLE,
                                                     "CitizenSDK native Host is unavailable");
      std::weak_ptr<State> weak = shared_from_this();
      std::weak_ptr<Session> target = session;
      session->transport->observe([weak, target](const citizensdk_event_t &value) {
        if (const auto state = weak.lock()) if (const auto session = target.lock()) state->receive(session, value);
      });
      const auto initial_state = session->transport->lifecycle_state();
      // open 的固定合同是 created / eventSequence 1；其它合法生命周期也
      // 不能冒充新 session，否则 Dart 会拒绝响应并失去该原生实例的身份。
      if (initial_state != CITIZENSDK_LIFECYCLE_CREATED)
        throw ContractFailure(CITIZENSDK_ERROR_INTEGRITY,
                              "CitizenSDK open requires a newly created native instance");
      if (!sessions.emplace(session->id, session).second)
        throw ContractFailure(CITIZENSDK_ERROR_CONFLICT, "CitizenSDK session identity collision");
      request.session = session->id;
      const auto state = lifecycle(initial_state);
      outcome = success(request, Value::list({state, Value::integer(1)}));
    } catch (const ContractFailure &error) {
      if (session && session->transport) { sessions.erase(session->id); session->transport->retire(); }
      outcome = failure(error.code, error.what(), request);
    } catch (const Error &error) {
      if (session && session->transport) { sessions.erase(session->id); session->transport->retire(); }
      outcome = failure(error.code(), error.what(), request);
    } catch (...) {
      if (session && session->transport) { sessions.erase(session->id); session->transport->retire(); }
      outcome = failure(CITIZENSDK_ERROR_INTERNAL, "CitizenSDK open failed", request);
    }
    // User/messenger code is outside native resource rollback. Once a session
    // was inserted, a throwing test callback must not make us reply twice.
    reply(std::move(*outcome));
    // Match the other official bindings: publish the open response before the
    // first session events, so Dart learns the random session ID first. A
    // reentrant close removes the session and makes snapshots a no-op.
    if (session && current(session)) {
      try { snapshots(session, snapshot_epoch()); } catch (...) {}
    }
  }

  void submit(const std::shared_ptr<Session> &session, const std::shared_ptr<Route> &route) {
    {
      std::lock_guard<std::mutex> guard(session->lock);
      if (session->admitting) throw ContractFailure(CITIZENSDK_ERROR_BUSY,
                                                   "CitizenSDK request admission is busy");
      route->accepting = true;
      session->admitting = route;
    }
    citizensdk_request_id_t native_id = 0;
    citizensdk_error_code_t code = CITIZENSDK_ERROR_INTERNAL;
    try { code = session->transport->accept(route->native_method, route->request, &native_id); }
    catch (...) {
      // Production C ABI is noexcept; finite test transports may throw before
      // acceptance. An observed ID means completion owns the route already.
      code = CITIZENSDK_ERROR_INTERNAL;
    }
    {
      std::lock_guard<std::mutex> guard(session->lock);
      route->accepting = false;
      session->admitting.reset();
      if (code == CITIZENSDK_OK && native_id != 0 &&
          (route->native_id == 0 || route->native_id == native_id)) {
        route->native_id = native_id;
      } else {
        // A contract-violating adapter must not overwrite the early route.
        // Keep any accepted ID for cancellation/retirement, but fail publicly.
        route->completed = true;
        route->ready = failure(code == CITIZENSDK_OK ? CITIZENSDK_ERROR_INTEGRITY : code,
                              "CitizenSDK native request was not accepted", route->request);
      }
    }
    drain(session);
  }

  static bool is_mutation(Method method) noexcept {
    switch (method) {
      case Method::create_wallet: case Method::import_wallet:
      case Method::add_wallet_accounts: case Method::set_active_wallet_account:
      case Method::rename_wallet_account: case Method::delete_wallet_account:
      case Method::delete_wallet: case Method::reconcile_wallet_cleanup:
        return true;
      default: return false;
    }
  }

  static bool needs_profile_read(Method method) noexcept {
    return method == Method::delete_wallet_account ||
           method == Method::delete_wallet ||
           method == Method::reconcile_wallet_cleanup;
  }

  void settle_launch_failure(const std::shared_ptr<Session> &session,
                             const std::shared_ptr<Route> &route,
                             citizensdk_error_code_t code,
                             const std::string &message) {
    {
      std::lock_guard<std::mutex> guard(session->lock);
      route->completed = true;
      route->ready = failure(code, message, route->request);
    }
    drain(session);
  }

  void launch_mutation(const std::shared_ptr<Session> &session,
                       const std::shared_ptr<Route> &route) {
    try {
      switch (route->request.method) {
        case Method::create_wallet: case Method::import_wallet:
        case Method::add_wallet_accounts: wallet(session, route); break;
        default: submit(session, route); break;
      }
    } catch (const ContractFailure &error) {
      settle_launch_failure(session, route, error.code, error.what());
    } catch (const Error &error) {
      settle_launch_failure(session, route, error.code(), error.what());
    } catch (...) {
      settle_launch_failure(session, route, CITIZENSDK_ERROR_INTERNAL,
                            "CitizenSDK wallet mutation dispatch failed");
    }
  }

  void begin_mutation(const std::shared_ptr<Session> &session,
                      const std::shared_ptr<Route> &route) {
    route->mutation = true;
    route->mutation_owner = std::make_shared<uint8_t>(0);
    if (!acquire_process_mutation(route->mutation_owner)) {
      settle_launch_failure(session, route, CITIZENSDK_ERROR_BUSY,
                            "CitizenSDK wallet mutation is already active");
      return;
    }
    active_mutation = route;
    launch_mutation(session, route);
  }

  void finish_mutation(const std::shared_ptr<Route> &route) {
    if (active_mutation == route) active_mutation.reset();
    release_process_mutation(route->mutation_owner);
    route->mutation_owner.reset();
  }

  void retire_detached_session_if_idle(const std::shared_ptr<Session> &session) {
    if (!is_detached() || !current(session)) return;
    {
      std::lock_guard<std::mutex> guard(session->lock);
      if (!session->routes.empty() || session->admitting) return;
    }
    session->transport->retire();
    session->retired = true;
    sessions.erase(session->id);
    release_detached_state_if_empty();
  }

  void wallet(const std::shared_ptr<Session> &session, const std::shared_ptr<Route> &route) {
    route->wallet = true;
    std::weak_ptr<State> weak = shared_from_this();
    std::weak_ptr<Session> target = session;
    wallets.launch(route->request,
      [transport = session->transport](const WalletFlowRequest &request, WalletFlowCompletion done) {
        return transport->present(request, std::move(done));
      },
      [weak, target, route](WalletFlowResult result) {
        const auto state = weak.lock(); const auto session = target.lock();
        if (!state || !session || !state->current(session)) return;
        route->wallet = false;
        try {
          if (result.status == WalletFlowStatus::Completed && result.error_code == CITIZENSDK_OK) {
            // The Win32 flow contains private prepared/import/add operations. Only
            // a new public-profile query is projected onto the original tuple.
            route->native_method = Method::get_wallet_profile;
            state->submit(session, route);
            return;
          }
          throw ContractFailure(
              result.status == WalletFlowStatus::Cancelled
                  ? CITIZENSDK_ERROR_CANCELLED
                  : (result.error_code == CITIZENSDK_OK
                         ? CITIZENSDK_ERROR_INTEGRITY : result.error_code),
              "CitizenSDK wallet flow did not complete");
        } catch (const ContractFailure &error) {
          {
            std::lock_guard<std::mutex> guard(session->lock);
            route->completed = true;
            route->ready = failure(error.code, error.what(), route->request);
          }
          state->drain(session);
        } catch (const Error &error) {
          {
            std::lock_guard<std::mutex> guard(session->lock);
            route->completed = true;
            route->ready = failure(error.code(), error.what(), route->request);
          }
          state->drain(session);
        } catch (...) {
          {
            std::lock_guard<std::mutex> guard(session->lock);
            route->completed = true;
            route->ready = failure(CITIZENSDK_ERROR_INTERNAL,
                                   "CitizenSDK wallet profile query failed", route->request);
          }
          state->drain(session);
        }
      });
  }

  void drain(const std::shared_ptr<Session> &session) {
    require_owner();
    if (!current(session)) return;
    for (;;) {
      std::shared_ptr<Route> route;
      {
        std::lock_guard<std::mutex> guard(session->lock);
        for (auto found = session->routes.begin(); found != session->routes.end(); ++found) {
          if (!found->second->completed || found->second->accepting) continue;
          route = found->second;
          session->routes.erase(found);
          break;
        }
      }
      if (!route) break;
      auto result = route->ready ? std::move(*route->ready)
          : failure(CITIZENSDK_ERROR_INTERNAL, "CitizenSDK result copying failed", route->request);
      if (result.success && (route->native_method == Method::start ||
                             route->native_method == Method::stop)) {
        try { result = success(route->request, Value::list({lifecycle(session->transport->lifecycle_state())})); }
        catch (const ContractFailure &error) { result = failure(error.code, error.what(), route->request); }
        catch (const Error &error) { result = failure(error.code(), error.what(), route->request); }
        catch (...) { result = failure(CITIZENSDK_ERROR_INTERNAL, "CitizenSDK lifecycle query failed", route->request); }
      }
      if (result.success && route->fetch_profile_after_mutation &&
          route->native_method != Method::get_wallet_profile) {
        // delete/deleteAccount/reconcile return EMPTY in the canonical Core.
        // Keep the process mutation gate and original Flutter sequence until
        // a second native request has copied the resulting public profile.
        // EMPTY 不是钱包 profile；保持同一变更锁和公开请求，内部再读一次。
        route->native_method = Method::get_wallet_profile;
        route->native_id = 0;
        route->terminal_seen = false;
        route->completed = false;
        route->ready.reset();
        {
          std::lock_guard<std::mutex> guard(session->lock);
          session->routes.emplace(route->request.sequence, route);
        }
        try { submit(session, route); }
        catch (const ContractFailure &error) {
          settle_launch_failure(session, route, error.code, error.what());
        } catch (const Error &error) {
          settle_launch_failure(session, route, error.code(), error.what());
        } catch (...) {
          settle_launch_failure(session, route, CITIZENSDK_ERROR_INTERNAL,
                                "CitizenSDK wallet profile query failed");
        }
        continue;
      }
      const bool mutation_finished = route->mutation;
      // Release the process gate before exposing terminal completion. A
      // reentrant Flutter reply may immediately begin the next mutation, but
      // never during the canonical Core/Win32/profile chain above.
      if (mutation_finished) finish_mutation(route);
      if (route->close_stop) {
        if (!result.success) close_failed(session, result.error_code, result.message);
      } else if (!is_detached() && route->reply) {
        auto reply = std::move(route->reply);
        // Removal above is the linearization point; a reply may reenter close.
        reply(std::move(result));
      }
    }
    if (is_detached()) {
      retire_detached_session_if_idle(session);
      return;
    }
    if (session->closing) progress_close(session);
  }

  void close_failed(const std::shared_ptr<Session> &session,
                    citizensdk_error_code_t code, const std::string &message) {
    if (!session->close_request) return;
    auto request = std::move(*session->close_request);
    auto reply = std::move(session->close_reply);
    session->close_request.reset();
    session->closing = false;
    if (!is_detached() && reply) reply(failure(code, message, request));
  }

  void progress_close(const std::shared_ptr<Session> &session) {
    if (!current(session) || !session->closing || !session->close_request) return;
    {
      std::lock_guard<std::mutex> guard(session->lock);
      if (!session->routes.empty()) return;
    }
    try {
      const auto state = session->transport->lifecycle_state();
      if (state == CITIZENSDK_LIFECYCLE_RUNNING || state == CITIZENSDK_LIFECYCLE_STARTING ||
          state == CITIZENSDK_LIFECYCLE_IMPORTING_STATE) {
        auto route = std::make_shared<Route>();
        route->request = *session->close_request;
        route->native_method = Method::stop;
        route->close_stop = true;
        {
          std::lock_guard<std::mutex> guard(session->lock);
          session->routes.emplace(route->request.sequence, route);
        }
        submit(session, route);
        return;
      }
      // Host::close rejects still-live result/callback frames as BUSY. This is
      // retryable and retains all ownership; never report disposed beforehand.
      session->transport->close();
      session->retired = true;
      sessions.erase(session->id);
      auto request = std::move(*session->close_request);
      auto reply = std::move(session->close_reply);
      session->close_request.reset();
      if (!is_detached() && reply) reply(success(request, Value::list({Value::string("disposed")})));
    } catch (const ContractFailure &error) { close_failed(session, error.code, error.what()); }
    catch (const Error &error) { close_failed(session, error.code(), error.what()); }
    catch (...) { close_failed(session, CITIZENSDK_ERROR_INTERNAL, "CitizenSDK close failed"); }
  }

  void begin_close(const std::shared_ptr<Session> &session,
                   const DecodedRequest &request, ReplyCallback reply) {
    session->closing = true;
    session->close_request = request;
    session->close_reply = std::move(reply);
    std::exception_ptr first;
    try { wallets.cancel_session(session->id); } catch (...) { first = std::current_exception(); }
    std::vector<citizensdk_request_id_t> cancel;
    {
      std::lock_guard<std::mutex> guard(session->lock);
      for (const auto &pair : session->routes) {
        if (pair.second->request.method == Method::transfer_with_remark &&
            !pair.second->completed && pair.second->native_id != 0)
          cancel.push_back(pair.second->native_id);
      }
    }
    for (const auto id : cancel) {
      try { session->transport->cancel(id); } catch (...) { if (!first) first = std::current_exception(); }
    }
    if (first) {
      try { std::rethrow_exception(first); }
      catch (const Error &error) { close_failed(session, error.code(), error.what()); }
      catch (...) { close_failed(session, CITIZENSDK_ERROR_INTERNAL, "CitizenSDK cancellation failed"); }
      return;
    }
    drain(session);
  }

  void dispatch(DecodedRequest request, ReplyCallback reply) {
    require_owner();
    if (!reply) throw ContractFailure(CITIZENSDK_ERROR_INVALID_ARGUMENT, "CitizenSDK reply is required");
    if (is_detached()) { reply(failure(CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK Flutter engine is detached", request)); return; }
    wallets.drain();
    // A previous failed main-loop allocation may have left a copied completion
    // ready. Retry ownership settlement before admitting another request.
    std::vector<std::shared_ptr<Session>> existing;
    for (const auto &pair : sessions) existing.push_back(pair.second);
    for (const auto &session : existing) drain(session);
    if (request.method == Method::open) { open(std::move(reply)); return; }
    const auto found = sessions.find(request.session);
    if (found == sessions.end()) { reply(failure(CITIZENSDK_ERROR_NOT_FOUND, "CitizenSDK session was not found", request)); return; }
    const auto session = found->second;
    if (session->closing || request.sequence != session->next_request) {
      reply(failure(CITIZENSDK_ERROR_CONFLICT, "CitizenSDK request sequence is not the next session sequence", request)); return;
    }
    if (session->next_request == std::numeric_limits<int64_t>::max()) {
      reply(failure(CITIZENSDK_ERROR_INTEGRITY, "CitizenSDK request sequence is exhausted", request)); return;
    }
    ++session->next_request;
    if (request.method == Method::close) { begin_close(session, request, std::move(reply)); return; }
    if (request.method == Method::get_capabilities) {
      std::optional<Reply> result;
      try { result = success(request, Value::list({session->transport->capability_snapshot()})); }
      catch (const ContractFailure &error) { result = failure(error.code, error.what(), request); }
      catch (const Error &error) { result = failure(error.code(), error.what(), request); }
      catch (...) { result = failure(CITIZENSDK_ERROR_INTERNAL, "CitizenSDK capability query failed", request); }
      // messenger 的回调不属于 native 查询错误域；回调抛错不能被捕获后第二次回复。
      reply(std::move(*result));
      return;
    }
    auto route = std::make_shared<Route>();
    route->request = std::move(request);
    route->native_method = route->request.method;
    route->reply = std::move(reply);
    route->fetch_profile_after_mutation = needs_profile_read(route->request.method);
    {
      std::lock_guard<std::mutex> guard(session->lock);
      session->routes.emplace(route->request.sequence, route);
    }
    try {
      if (is_mutation(route->request.method)) begin_mutation(session, route);
      else submit(session, route);
    } catch (const ContractFailure &error) {
      {
        std::lock_guard<std::mutex> guard(session->lock);
        route->completed = true; route->ready = failure(error.code, error.what(), route->request);
      }
      drain(session);
    } catch (const Error &error) {
      {
        std::lock_guard<std::mutex> guard(session->lock);
        route->completed = true; route->ready = failure(error.code(), error.what(), route->request);
      }
      drain(session);
    } catch (...) {
      {
        std::lock_guard<std::mutex> guard(session->lock);
        route->completed = true;
        route->ready = failure(CITIZENSDK_ERROR_INTERNAL, "CitizenSDK request dispatch failed", route->request);
      }
      drain(session);
    }
  }

  void listen(EventSink value) {
    require_owner();
    if (is_detached()) throw ContractFailure(CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK Flutter engine is detached");
    if (!value) throw ContractFailure(CITIZENSDK_ERROR_INVALID_ARGUMENT, "CitizenSDK event sink is required");
    if (sink) throw ContractFailure(CITIZENSDK_ERROR_BUSY, "CitizenSDK event subscription is already active");
    advance_epoch(); sink = std::move(value);
    std::vector<std::shared_ptr<Session>> current_sessions;
    for (const auto &pair : sessions) current_sessions.push_back(pair.second);
    const auto expected = snapshot_epoch();
    for (const auto &session : current_sessions) {
      try { snapshots(session, expected); } catch (...) {}
    }
  }
  void cancel_events() {
    require_owner();
    if (is_detached()) { sink = {}; return; }
    advance_epoch(); sink = {};
  }

  void detach() noexcept {
    // This method is called synchronously by plugin dispose on its owner
    // thread, before messenger handles are retired. Host callbacks never wait
    // for this UI thread, so Host's callback barrier cannot deadlock it.
    try { advance_epoch(true); } catch (...) {}
    sink = {};
    if (!sessions.empty()) retain_detached_state();
    for (auto found = sessions.begin(); found != sessions.end();) {
      const auto session = (found++)->second;
      session->closing = true;
      session->close_reply = {};
      try { wallets.cancel_session(session->id); } catch (...) {}
      {
        std::lock_guard<std::mutex> guard(session->lock);
        for (auto &route_pair : session->routes) route_pair.second->reply = {};
      }
      int64_t last_sequence = 0;
      for (;;) {
        citizensdk_request_id_t cancellation_id = 0;
        {
          std::lock_guard<std::mutex> guard(session->lock);
          for (auto next = session->routes.upper_bound(last_sequence);
               next != session->routes.end(); ++next) {
            last_sequence = next->first;
            if (next->second->request.method == Method::transfer_with_remark &&
                !next->second->completed && next->second->native_id != 0) {
              cancellation_id = next->second->native_id;
              break;
            }
          }
        }
        if (cancellation_id == 0) break;
        // Never enter Core under the session lock: a finite test transport may
        // complete inline, and the production dispatch thread may race here.
        try { session->transport->cancel(cancellation_id); } catch (...) {}
      }
      retire_detached_session_if_idle(session);
    }
    release_detached_state_if_empty();
  }
};

Sessions::Sessions(std::shared_ptr<State> state) : state_(std::move(state)) {}
std::shared_ptr<Sessions> Sessions::create(EnvironmentFactory environment,
                                          Scheduler scheduler, TransportFactory factory) {
  if (!environment || !scheduler)
    throw ContractFailure(CITIZENSDK_ERROR_INVALID_ARGUMENT, "CitizenSDK environment and scheduler are required");
  if (!factory) factory = [](const Config &config) { return std::make_shared<HostTransport>(config); };
  return std::shared_ptr<Sessions>(new Sessions(
      std::make_shared<State>(std::move(environment), std::move(scheduler), std::move(factory))));
}
Sessions::~Sessions() { state_->detach(); }
void Sessions::dispatch(DecodedRequest request, ReplyCallback reply) { state_->dispatch(std::move(request), std::move(reply)); }
void Sessions::listen(EventSink sink) { state_->listen(std::move(sink)); }
void Sessions::cancel_events() { state_->cancel_events(); }
void Sessions::detach() noexcept { state_->detach(); }
std::size_t Sessions::session_count() const { state_->require_owner(); return state_->sessions.size(); }

}  // namespace citizen_sdk::flutter
