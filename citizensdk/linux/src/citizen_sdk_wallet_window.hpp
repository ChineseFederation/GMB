#ifndef CITIZENSDK_LINUX_WALLET_WINDOW_HPP
#define CITIZENSDK_LINUX_WALLET_WINDOW_HPP

#include <functional>
#include <string>
#include <thread>
#include "citizen_sdk_sensitive_buffer.hpp"
#include "citizen_sdk_wallet_validation.hpp"

namespace citizen_sdk::linux {

class WalletWindow final {
 public:
  using Action = std::function<void()>;
  WalletWindow(void *parent, const ValidatedWalletRequest &request,
               Action action, Action cancel);
  WalletWindow(const WalletWindow &) = delete;
  WalletWindow &operator=(const WalletWindow &) = delete;
  ~WalletWindow();

  void show();
  void destroy() noexcept;
  void set_busy(const std::string &message);
  void set_error(const std::string &message);
  void show_prepared_mnemonic(const SensitiveBuffer &mnemonic);
  bool backup_confirmed() const noexcept;
  SensitiveBuffer take_mnemonic();
  SensitiveBuffer take_password(bool require_confirmation);
  void clear_secrets() noexcept;
  bool invoke(std::function<void()> action) noexcept;
  bool on_ui_thread() const noexcept {
    return std::this_thread::get_id() == ui_thread_;
  }

 private:
  void *window_{};
  void *ui_context_{};
  void *mnemonic_scroll_{};
  void *mnemonic_{};
  void *password_{};
  void *confirmation_{};
  void *backup_{};
  void *action_button_{};
  void *status_{};
  Action action_;
  Action cancel_;
  citizensdk_wallet_flow_kind_t kind_{};
  std::thread::id ui_thread_;
  bool destroying_{false};
};

}  // namespace citizen_sdk::linux

#endif
