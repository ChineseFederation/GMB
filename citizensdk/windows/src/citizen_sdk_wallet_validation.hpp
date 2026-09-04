#ifndef CITIZENSDK_WINDOWS_WALLET_VALIDATION_HPP
#define CITIZENSDK_WINDOWS_WALLET_VALIDATION_HPP

#include <cstdint>
#include <vector>
#include "citizen_sdk/citizensdk_host.h"

namespace citizen_sdk::windows {

struct ValidatedWalletRequest final {
  citizensdk_wallet_flow_kind_t kind{};
  citizensdk_wallet_word_count_t word_count{};
  std::vector<uint32_t> account_indices;
};

ValidatedWalletRequest validate_wallet_request(
    const citizensdk_wallet_flow_request_v1_t &request);

}  // namespace citizen_sdk::windows

#endif
