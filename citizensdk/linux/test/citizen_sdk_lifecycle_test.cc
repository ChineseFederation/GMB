// 验证钱包流程与关闭 admission 使用同一个单调状态机。
#include <cassert>
#include <fstream>
#include <iterator>
#include <string>

#include "citizen_sdk_lifecycle.hpp"

#ifndef CITIZENSDK_LINUX_TEST_SOURCE_DIR
#error "CITIZENSDK_LINUX_TEST_SOURCE_DIR must point at the Linux source root"
#endif
#ifdef NDEBUG
#error "CitizenSDK Linux contract assertions must remain enabled"
#endif

int main() {
  using citizen_sdk::linux::HostError;
  using citizen_sdk::linux::Lifecycle;

  Lifecycle lifecycle;
  const uint64_t wallet = lifecycle.reserve_wallet_flow();
  assert(wallet != 0);
  assert(lifecycle.wallet_active());

  bool second_wallet_busy = false;
  try {
    (void)lifecycle.reserve_wallet_flow();
  } catch (const HostError &error) {
    second_wallet_busy = error.code() == CITIZENSDK_ERROR_BUSY;
  }
  assert(second_wallet_busy);

  lifecycle.finish_wallet_flow(wallet + 1);
  assert(lifecycle.wallet_active());
  bool close_busy = false;
  try {
    (void)lifecycle.begin_close();
  } catch (const HostError &error) {
    close_busy = error.code() == CITIZENSDK_ERROR_BUSY;
  }
  assert(close_busy);

  lifecycle.finish_wallet_flow(wallet);
  assert(!lifecycle.wallet_active());
  assert(lifecycle.begin_close());
  lifecycle.cancel_close(false);
  const uint64_t retry_wallet = lifecycle.reserve_wallet_flow();
  lifecycle.finish_wallet_flow(retry_wallet);

  assert(lifecycle.begin_close());
  lifecycle.cancel_close(true);
  bool teardown_rejected_wallet = false;
  try {
    (void)lifecycle.reserve_wallet_flow();
  } catch (const HostError &error) {
    teardown_rejected_wallet =
        error.code() == CITIZENSDK_ERROR_INVALID_STATE;
  }
  assert(teardown_rejected_wallet);
  assert(lifecycle.begin_close());
  lifecycle.commit_closed();
  assert(!lifecycle.begin_close());
  bool closed_rejected = false;
  try {
    (void)lifecycle.reserve_wallet_flow();
  } catch (const HostError &error) {
    closed_rejected = error.code() == CITIZENSDK_ERROR_INVALID_STATE;
  }
  assert(closed_rejected);

  const auto read = [](const char *relative) {
    const std::string path = std::string(CITIZENSDK_LINUX_TEST_SOURCE_DIR) +
                             relative;
    std::ifstream stream(path, std::ios::binary);
    assert(stream.good());
    return std::string((std::istreambuf_iterator<char>(stream)),
                       std::istreambuf_iterator<char>());
  };
  const std::string host_api = read("/src/citizen_sdk_host_api.cc");
  const std::string host_bridge =
      read("/src/citizen_sdk_host_bridge.cc");
  const std::string cpp_api =
      read("/include/citizen_sdk/citizen_sdk.hpp");
  const auto wallet_index_guard =
      host_bridge.find("value.wallet_index == 0");
  const auto secret_index_guard = host_bridge.find(
      "value.wallet_index == 0", wallet_index_guard + 1);
  assert(wallet_index_guard != std::string::npos &&
         secret_index_guard != std::string::npos);
  assert(host_api.find("citizensdk_host_abandon") != std::string::npos);
  assert(host_api.find("citizensdk_stop(sdk") != std::string::npos);
  assert(host_api.find("std::min(delay * 2") != std::string::npos);

  // 每个带 Host handle 的公开入口都先取得 registry lease。retirement
  // 封闭新 admission 后只等待既有 lease，Host 真正关闭成功后才从
  // registry 移除；等待时 condition_variable 会释放 registry lock，
  // 因而 callback 重入不会被 close 持锁死锁。
  assert(host_api.find("class HostLease final") != std::string::npos);
  assert(host_api.find("(!include_retiring && found->second->retiring)") !=
         std::string::npos);
  assert(host_api.find("++found->second->active_calls") !=
         std::string::npos);
  assert(host_api.find("--entry_->active_calls") != std::string::npos);
  assert(host_api.find(
             "registry_idle().wait(guard, [&] { return entry->active_calls == 1; })") !=
         std::string::npos);
  std::size_t leased_entry_points = 0;
  std::size_t lease_cursor = 0;
  while ((lease_cursor = host_api.find("auto host = acquire_host(",
                                       lease_cursor)) != std::string::npos) {
    ++leased_entry_points;
    ++lease_cursor;
  }
  assert(leased_entry_points == 9);
  const auto retirement = host_api.find("begin_retirement(host_handle, host, false)");
  const auto host_close = host_api.find("code = host->close()", retirement);
  const auto registry_erase = host_api.find("registry().erase(found)", host_close);
  assert(retirement != std::string::npos && host_close != std::string::npos &&
         registry_erase != std::string::npos && retirement < host_close &&
         host_close < registry_erase);

  // HostBridge 不跨 root ABI 调用持有 call_lock_；Core 销毁成功后才按
  // Vault -> secure store -> public store 的顺序退休宿主资源。
  const auto foreign_boundary = host_bridge.find(
      "Never hold call_lock_ across that foreign boundary");
  const auto lifecycle_query =
      host_bridge.find("citizensdk_get_lifecycle(sdk", foreign_boundary);
  const auto unsubscribe = host_bridge.find(
      "citizensdk_unsubscribe_capability_changes(sdk)", lifecycle_query);
  const auto clear_core_callback = host_bridge.find(
      "citizensdk_set_event_callback(sdk, nullptr, nullptr)", unsubscribe);
  const auto destroy_core =
      host_bridge.find("citizensdk_destroy(sdk)", clear_core_callback);
  const auto retire_services =
      host_bridge.find("services_retired_ = true", destroy_core);
  const auto retire_vault = host_bridge.find("vault_.reset()", retire_services);
  const auto retire_secure =
      host_bridge.find("secure_store_->close()", retire_vault);
  const auto retire_public =
      host_bridge.find("public_store_.close()", retire_secure);
  assert(foreign_boundary != std::string::npos &&
         lifecycle_query != std::string::npos &&
         unsubscribe != std::string::npos &&
         clear_core_callback != std::string::npos &&
         destroy_core != std::string::npos &&
         retire_services != std::string::npos &&
         retire_vault != std::string::npos &&
         retire_secure != std::string::npos &&
         retire_public != std::string::npos &&
         foreign_boundary < lifecycle_query && lifecycle_query < unsubscribe &&
         unsubscribe < clear_core_callback &&
         clear_core_callback < destroy_core && destroy_core < retire_services &&
         retire_services < retire_vault && retire_vault < retire_secure &&
         retire_secure < retire_public);
  assert(host_bridge.find(
             "callback_thread_ == std::this_thread::get_id()") !=
         std::string::npos);

  const auto close_noexcept = cpp_api.find("void close_noexcept() noexcept");
  const auto clear = cpp_api.find(
      "citizensdk_host_set_event_callback(host_, nullptr, nullptr)",
      close_noexcept);
  const auto first_abandon = cpp_api.find(
      "const auto abandon = citizensdk_host_abandon(host_)", clear);
  const auto reset = cpp_api.find("event_context_.reset()", first_abandon);
  const auto destroy =
      cpp_api.find("citizensdk_host_destroy(host_)", reset);
  const auto second_abandon = cpp_api.find(
      "const auto abandon = citizensdk_host_abandon(host_)", destroy);
  assert(close_noexcept != std::string::npos && clear != std::string::npos &&
         first_abandon != std::string::npos && reset != std::string::npos &&
         destroy != std::string::npos && second_abandon != std::string::npos);
  assert(close_noexcept < clear && clear < first_abandon &&
         first_abandon < reset && reset < destroy &&
         destroy < second_abandon);
  assert(cpp_api.find("std::terminate()", first_abandon) < reset);
  assert(cpp_api.find("std::terminate()", second_abandon) !=
         std::string::npos);
  assert(cpp_api.find("event_context_.release()") == std::string::npos);
  assert(cpp_api.find("abandon_delay") == std::string::npos);

  const auto trampoline = cpp_api.find("inline void event_trampoline");
  const auto result_scope = cpp_api.find(
      "EventResultScope result_owner(event->result)", trampoline);
  const auto observer = cpp_api.find("if (observer) observer(*event)",
                                     result_scope);
  assert(trampoline != std::string::npos && result_scope != std::string::npos &&
         observer != std::string::npos && result_scope < observer);
  assert(cpp_api.find("(void)citizensdk_result_release(value)") !=
         std::string::npos);
  return 0;
}
