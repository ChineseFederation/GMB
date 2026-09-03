// 验证 Linux 新增的 Host/C++ 公共表面没有另造助记词、口令、DEK 或私钥旁路。
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <set>
#include <string>

#include "citizen_sdk_host_record.hpp"

#ifndef CITIZENSDK_LINUX_TEST_SOURCE_DIR
#error "CITIZENSDK_LINUX_TEST_SOURCE_DIR must point at the Linux source root"
#endif
#ifdef NDEBUG
#error "CitizenSDK Linux contract assertions must remain enabled"
#endif

int main() {
  using citizen_sdk::linux::HostError;
  using citizen_sdk::linux::copy_view;

  const std::filesystem::path public_headers =
      std::filesystem::path(CITIZENSDK_LINUX_TEST_SOURCE_DIR) / "include" /
      "citizen_sdk";
  std::set<std::string> headers;
  for (const auto &entry : std::filesystem::directory_iterator(public_headers)) {
    if (!std::filesystem::is_regular_file(entry.symlink_status())) continue;
    const auto extension = entry.path().extension();
    if (extension != ".h" && extension != ".hpp") continue;
    std::ifstream stream(entry.path(), std::ios::binary);
    assert(stream.good());
    const std::string header((std::istreambuf_iterator<char>(stream)),
                             std::istreambuf_iterator<char>());
    for (const char *forbidden : {
             "private_key", "mini_secret", "plaintext_dek", "unlock_password",
             "mnemonic_utf8", "signed_extrinsic", "getAccountPrivateKey",
         }) {
      assert(header.find(forbidden) == std::string::npos);
    }
    headers.insert(entry.path().filename().string());
  }
  const std::set<std::string> expected_headers{
      "citizensdk_host.h",
      "citizen_sdk.hpp",
      "citizen_sdk_config.hpp",
      "citizen_sdk_error.hpp",
      "citizen_sdk_events.hpp",
      "citizen_sdk_models.hpp",
      "citizen_sdk_wallet_flow.hpp",
  };
  assert(headers == expected_headers);

  bool null_rejected = false;
  try {
    (void)copy_view({nullptr, 1}, 8, "null fixture");
  } catch (const HostError &error) {
    null_rejected = error.code() == CITIZENSDK_ERROR_INVALID_ARGUMENT;
  }
  assert(null_rejected);

  const uint8_t fixture[] = {1, 2, 3};
  assert((copy_view({fixture, 3}, 3, "fixture") ==
          citizen_sdk::linux::Bytes{1, 2, 3}));
  bool oversized_rejected = false;
  try {
    (void)copy_view({fixture, 3}, 2, "oversized fixture");
  } catch (const HostError &error) {
    oversized_rejected = error.code() == CITIZENSDK_ERROR_INVALID_ARGUMENT;
  }
  assert(oversized_rejected);
  return 0;
}
