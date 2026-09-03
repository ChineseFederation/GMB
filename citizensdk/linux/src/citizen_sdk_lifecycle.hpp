#ifndef CITIZENSDK_LINUX_LIFECYCLE_HPP
#define CITIZENSDK_LINUX_LIFECYCLE_HPP

#include <cstdint>
#include <mutex>
#include "citizen_sdk_host_record.hpp"

namespace citizen_sdk::linux {

class Lifecycle final {
 public:
  uint64_t reserve_wallet_flow();
  void finish_wallet_flow(uint64_t token) noexcept;
  bool begin_close();
  void cancel_close(bool teardown_started) noexcept;
  void commit_closed() noexcept;
  bool wallet_active() const noexcept;

 private:
  enum class State { kOpen, kWalletOwned, kClosing, kClosed };
  mutable std::mutex lock_;
  State state_{State::kOpen};
  uint64_t next_token_{1};
  bool token_identity_exhausted_{false};
  uint64_t wallet_token_{};
  bool close_attempt_active_{false};
};

}  // namespace citizen_sdk::linux

#endif
