#ifndef CITIZENSDK_WINDOWS_WALLET_WINDOW_HPP
#define CITIZENSDK_WINDOWS_WALLET_WINDOW_HPP

#include <functional>
#include <memory>
#include <string>
#include "citizen_sdk_sensitive_buffer.hpp"
#include "citizen_sdk_wallet_validation.hpp"
#include "citizen_sdk_window.hpp"

namespace citizen_sdk::windows {

// 仅 SDK 原生界面内部使用。秘密从不存入系统 EDIT 的文本/撤销存储，
// 也不响应 WM_GETTEXT；输入与转换缓冲的实际容量均有界并主动清零。
class SensitiveInput final {
 public:
  SensitiveInput(void *parent, int identity, int x, int y, int width, int height,
                 bool masked, bool multiline);
  SensitiveInput(const SensitiveInput &) = delete;
  SensitiveInput &operator=(const SensitiveInput &) = delete;
  ~SensitiveInput();
  void *native_handle() const noexcept;
  SensitiveBuffer take_utf8();
  void set_utf8(const SensitiveBuffer &value);
  void clear() noexcept;
  void set_read_only(bool value) noexcept;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

class WalletWindow final {
 public:
  using Action = std::function<void()>;
  WalletWindow(WindowLease parent, const ValidatedWalletRequest &request,
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
  bool on_ui_thread() const noexcept;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace citizen_sdk::windows
#endif
