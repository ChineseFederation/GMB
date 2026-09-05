#ifndef CITIZENSDK_LINUX_WALLET_WINDOW_HPP
#define CITIZENSDK_LINUX_WALLET_WINDOW_HPP

#include <functional>
#include <string>
#include <thread>
#include <vector>
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
  // 词数、账户模式和显式索引只存在于 SDK 原生窗口，不扩大 Flutter/C 公共协议。
  citizensdk_wallet_word_count_t word_count() const;
  bool use_next_account() const noexcept;
  std::vector<uint32_t> account_indices() const;
  SensitiveBuffer take_mnemonic();
  // 返回后立即清空控件；非空值只在创建/导入时进行一次风险确认。
  SensitiveBuffer take_password();
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
  void *mnemonic_state_{};
  void *suggestions_{};
  void *suggestion_apply_{};
  void *word_count_{};
  void *password_{};
  void *next_account_{};
  void *account_indices_{};
  void *backup_{};
  void *action_button_{};
  void *status_{};
  Action action_;
  Action cancel_;
  citizensdk_wallet_flow_kind_t kind_{};
  std::thread::id ui_thread_;
  bool destroying_{false};
  bool password_reentry_required_{false};
};

}  // namespace citizen_sdk::linux

#endif
