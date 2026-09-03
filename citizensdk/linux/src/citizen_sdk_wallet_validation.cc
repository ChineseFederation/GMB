#include "citizen_sdk_wallet_validation.hpp"

#include "citizen_sdk_host_record.hpp"
#include "citizen_sdk_input_limits.hpp"

namespace citizen_sdk::linux {

ValidatedWalletRequest validate_wallet_request(
    const citizensdk_wallet_flow_request_v1_t &request) {
  require(request.struct_size >= sizeof(request) && request.abi_version == 1,
          CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "wallet-flow request ABI is invalid");
  ValidatedWalletRequest result{};
  result.kind = request.kind;
  switch (request.kind) {
    case CITIZENSDK_WALLET_FLOW_CREATE:
      input_limits::validate_word_count(request.word_count);
      require(request.account_indices == nullptr && request.account_index_count == 0,
              CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "wallet creation must not include account indices");
      result.word_count = request.word_count;
      break;
    case CITIZENSDK_WALLET_FLOW_IMPORT:
      require(request.word_count == 0 && request.account_indices == nullptr &&
                  request.account_index_count == 0,
              CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "wallet import contains fields for another flow kind");
      break;
    case CITIZENSDK_WALLET_FLOW_ADD_ACCOUNTS:
      require(request.word_count == 0, CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "add-accounts must not include a wallet word count");
      input_limits::validate_wallet_indices(request.account_indices,
                                            request.account_index_count);
      result.account_indices.assign(request.account_indices,
                                    request.account_indices + request.account_index_count);
      break;
    default:
      throw HostError(CITIZENSDK_ERROR_INVALID_ARGUMENT,
                      "wallet-flow kind is invalid");
  }
  return result;
}

}  // namespace citizen_sdk::linux
