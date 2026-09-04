#ifndef CITIZENSDK_WINDOWS_USER_AUTH_HPP
#define CITIZENSDK_WINDOWS_USER_AUTH_HPP

#include <mutex>
#include "citizen_sdk_sensitive_buffer.hpp"
#include "citizen_sdk_window.hpp"

namespace citizen_sdk::windows {
struct AuthenticationResult final {
  citizensdk_error_code_t code{CITIZENSDK_ERROR_INTERNAL};
  SensitiveBuffer password;
};

class UserAuth final {
 public:
  explicit UserAuth(WindowRef &parent);
  UserAuth(const UserAuth &) = delete;
  UserAuth &operator=(const UserAuth &) = delete;
  ~UserAuth();
  bool available() const noexcept;
  AuthenticationResult create_vault_password();
  AuthenticationResult unlock_vault_password();

 private:
  AuthenticationResult prompt(bool confirmation);
  std::mutex prompt_lock_;
  WindowRef &parent_;
};
}  // namespace citizen_sdk::windows
#endif
