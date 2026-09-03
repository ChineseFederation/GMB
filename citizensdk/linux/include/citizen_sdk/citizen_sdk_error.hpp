#ifndef CITIZENSDK_CPP_ERROR_HPP
#define CITIZENSDK_CPP_ERROR_HPP

#include <stdexcept>
#include <string>
#include <utility>
#include <vector>
#include "citizen_sdk/citizensdk_host.h"

namespace citizen_sdk {

class Error final : public std::runtime_error {
 public:
  Error(citizensdk_error_code_t code, std::string message)
      : std::runtime_error(std::move(message)), code_(code) {}
  citizensdk_error_code_t code() const noexcept { return code_; }

 private:
  citizensdk_error_code_t code_;
};

inline std::string last_host_error(const char *fallback) {
  uint64_t needed = 0;
  if (citizensdk_host_last_error_copy(nullptr, 0, &needed) != CITIZENSDK_OK || needed == 0) {
    return fallback;
  }
  std::vector<uint8_t> bytes(static_cast<std::size_t>(needed));
  if (citizensdk_host_last_error_copy(bytes.data(), needed, &needed) != CITIZENSDK_OK) {
    return fallback;
  }
  return std::string(bytes.begin(), bytes.end());
}

inline void throw_if_error(citizensdk_error_code_t code, const char *fallback) {
  if (code != CITIZENSDK_OK) throw Error(code, last_host_error(fallback));
}

}  // namespace citizen_sdk

#endif
