#ifndef CITIZENSDK_CPP_MODELS_HPP
#define CITIZENSDK_CPP_MODELS_HPP

#include <array>
#include <cstdint>
#include <string>
#include <vector>
#include "citizensdk_types.h"

namespace citizen_sdk {

struct CapabilityStatus {
  citizensdk_capability_name_t name{};
  citizensdk_capability_reason_t reason{};
  bool supported{};
  bool available{};
  bool enabled{};
  bool ready{};
};

struct Capabilities {
  uint64_t revision{};
  std::vector<CapabilityStatus> statuses;
};

struct BlockRef {
  std::array<uint8_t, 32> hash{};
  uint64_t number{};
  citizensdk_finality_t finality{CITIZENSDK_FINALITY_FINALIZED};
};

struct AccountId { std::array<uint8_t, 32> bytes{}; };

}  // namespace citizen_sdk

#endif
