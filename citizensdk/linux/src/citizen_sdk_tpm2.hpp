#ifndef CITIZENSDK_LINUX_TPM2_HPP
#define CITIZENSDK_LINUX_TPM2_HPP

#include <array>
#include "citizen_sdk_secure_store.hpp"
#include "citizen_sdk_sensitive_buffer.hpp"

namespace citizen_sdk::linux {

enum class TpmAvailability { kAvailable, kUnsupported, kUnavailable };

class Tpm2 final {
 public:
  TpmAvailability availability() const noexcept;
  VaultObject create_key(const SensitiveBuffer &password) const;
  bool validate_key(const VaultObject &object) const;
  Bytes encrypt_dek(const VaultObject &object,
                    const uint8_t plaintext_dek[32]) const;
  void decrypt_dek(const VaultObject &object, const Bytes &wrapped_dek,
                   const SensitiveBuffer &password,
                   uint8_t plaintext_dek_out[32]) const;

 private:
  static SensitiveBuffer derive_auth(const SensitiveBuffer &password,
                                     const Bytes &salt);
};

}  // namespace citizen_sdk::linux

#endif
