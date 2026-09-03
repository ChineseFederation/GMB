#include "citizen_sdk_lifecycle.hpp"

#include <limits>

namespace citizen_sdk::linux {

uint64_t Lifecycle::reserve_wallet_flow() {
  std::lock_guard<std::mutex> guard(lock_);
  if (state_ == State::kWalletOwned) {
    throw HostError(CITIZENSDK_ERROR_BUSY,
                    "a CitizenSDK wallet flow is already active");
  }
  if (state_ != State::kOpen) {
    throw HostError(CITIZENSDK_ERROR_INVALID_STATE,
                    "CitizenSDK Host is closing or closed");
  }
  if (token_identity_exhausted_) {
    throw HostError(CITIZENSDK_ERROR_UNAVAILABLE,
                    "CitizenSDK wallet-flow token space is exhausted");
  }
  wallet_token_ = next_token_;
  if (next_token_ == std::numeric_limits<uint64_t>::max()) {
    token_identity_exhausted_ = true;
  } else {
    ++next_token_;
  }
  state_ = State::kWalletOwned;
  return wallet_token_;
}

void Lifecycle::finish_wallet_flow(uint64_t token) noexcept {
  std::lock_guard<std::mutex> guard(lock_);
  if (state_ == State::kWalletOwned && wallet_token_ == token) {
    wallet_token_ = 0;
    state_ = State::kOpen;
  }
}

bool Lifecycle::begin_close() {
  std::lock_guard<std::mutex> guard(lock_);
  if (state_ == State::kClosed) return false;
  if (state_ == State::kWalletOwned || close_attempt_active_) {
    throw HostError(CITIZENSDK_ERROR_BUSY,
                    "CitizenSDK Host still owns a wallet flow or close attempt");
  }
  state_ = State::kClosing;
  close_attempt_active_ = true;
  return true;
}

void Lifecycle::cancel_close(bool teardown_started) noexcept {
  std::lock_guard<std::mutex> guard(lock_);
  close_attempt_active_ = false;
  if (state_ == State::kClosing && !teardown_started) state_ = State::kOpen;
}

void Lifecycle::commit_closed() noexcept {
  std::lock_guard<std::mutex> guard(lock_);
  close_attempt_active_ = false;
  state_ = State::kClosed;
}

bool Lifecycle::wallet_active() const noexcept {
  std::lock_guard<std::mutex> guard(lock_);
  return state_ == State::kWalletOwned;
}

}  // namespace citizen_sdk::linux
