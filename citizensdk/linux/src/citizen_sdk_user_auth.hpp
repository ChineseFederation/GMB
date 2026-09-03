#ifndef CITIZENSDK_LINUX_USER_AUTH_HPP
#define CITIZENSDK_LINUX_USER_AUTH_HPP

#include <mutex>
#include <thread>
#include "citizen_sdk_gtk_parent.hpp"
#include "citizen_sdk_sensitive_buffer.hpp"
#include "citizensdk_types.h"

namespace citizen_sdk::linux {

struct AuthenticationResult final {
  citizensdk_error_code_t code{CITIZENSDK_ERROR_INTERNAL};
  SensitiveBuffer password;
};

class UserAuth final {
 public:
  explicit UserAuth(GtkParentRef &parent);
  UserAuth(const UserAuth &) = delete;
  UserAuth &operator=(const UserAuth &) = delete;
  ~UserAuth();

  bool available() const noexcept;
  AuthenticationResult create_vault_password();
  AuthenticationResult unlock_vault_password();

 private:
  AuthenticationResult prompt(bool confirmation);
  std::mutex prompt_lock_;
  GtkParentRef &parent_;
  void *ui_context_{};
  std::thread::id ui_thread_;
  bool ui_available_{false};
};

}  // namespace citizen_sdk::linux

#endif
