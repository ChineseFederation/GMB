#ifndef CITIZENSDK_LINUX_SECRET_VAULT_HPP
#define CITIZENSDK_LINUX_SECRET_VAULT_HPP

#include <array>
#include <mutex>
#include "citizen_sdk_operation.hpp"
#include "citizen_sdk_secure_store.hpp"
#include "citizen_sdk_tpm2.hpp"
#include "citizen_sdk_user_auth.hpp"

namespace citizen_sdk::linux {

class SecretVault final {
 public:
  SecretVault(SecureStore &secure_store, GtkParentRef &parent);

  citizensdk_host_vault_availability_t availability() const noexcept;
  void ensure_wallet_kek(const WalletKey &key,
                         const std::array<uint8_t, 16> &operation_id);
  bool has_wallet_kek(const WalletKey &key);
  Bytes wrap_dek(const WalletKey &key,
                 const std::array<uint8_t, 16> &operation_id,
                 const uint8_t plaintext_dek[32]);
  void unwrap_dek(uint64_t host_operation_id, const WalletKey &key,
                  const Bytes &wrapped_dek, uint8_t plaintext_dek_out[32]);
  void retire_wallet_kek(const WalletKey &key,
                         const std::array<uint8_t, 16> &operation_id);
  bool idle() const noexcept;

 private:
  SecureStore &secure_store_;
  Tpm2 tpm_;
  UserAuth user_auth_;
  OperationTracker operations_;
  mutable std::recursive_mutex generation_lock_;
};

}  // namespace citizen_sdk::linux

#endif
