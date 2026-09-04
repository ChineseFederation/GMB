#include <cassert>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include "citizen_sdk_flutter_test_support.hpp"

#ifndef CITIZENSDK_WINDOWS_TEST_SOURCE_DIR
#error "CITIZENSDK_WINDOWS_TEST_SOURCE_DIR must identify the Windows source tree"
#endif

int main() {
  namespace csf = citizen_sdk::flutter;
  const auto creation = csf::test::fl(csf::test::list({csf::Value::integer(1),
      csf::Value::string("session"), csf::Value::integer(1), csf::Value::integer(24)}));
  const auto created = csf::decode_request("createWallet", &creation);
  assert(created.method == csf::Method::create_wallet && created.word_count == 24);
  assert(created.payload.empty() && created.name.empty());
  const auto import_arguments = csf::test::fl(csf::test::list({csf::Value::integer(1),
      csf::Value::string("session"), csf::Value::integer(2)}));
  const auto imported = csf::decode_request("importWallet", &import_arguments);
  assert(imported.method == csf::Method::import_wallet && imported.payload.empty());
  const auto extra = csf::test::fl(csf::test::list({csf::Value::integer(1),
      csf::Value::string("session"), csf::Value::integer(2), csf::Value::null()}));
  csf::test::expect_failure([&] { (void)csf::decode_request("importWallet", &extra); },
                           CITIZENSDK_ERROR_INVALID_ARGUMENT);
  const auto open_extra = csf::test::fl(csf::test::list({csf::Value::integer(1),
      csf::Value::string("org.example.caller")}));
  csf::test::expect_failure([&] { (void)csf::decode_request("open", &open_extra); },
                           CITIZENSDK_ERROR_INVALID_ARGUMENT);

  // 实际解码验证在上；以下源码扫描只是额外防止秘密/裸句柄/路径入口重新出现。
  const std::filesystem::path root(CITIZENSDK_WINDOWS_TEST_SOURCE_DIR);
  for (const auto *relative : {"include/citizen_sdk/citizen_sdk_plugin.h",
       "src/citizen_sdk_plugin.cc", "src/citizen_sdk_flutter_environment.hpp",
       "src/citizen_sdk_flutter_environment.cc", "src/citizen_sdk_flutter_codec.hpp",
       "src/citizen_sdk_flutter_sessions.hpp", "src/citizen_sdk_flutter_wallet_flow.hpp"}) {
    std::ifstream stream(root / relative, std::ios::binary);
    assert(stream.good());
    const std::string source((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
    for (const auto *forbidden : {"dart_asset_root", "dart_storage_root", "dart_application_id",
         "dart_hwnd", "exportMnemonic", "exportPrivateKey", "prepared_wallet_handle",
         "plaintext_dek", "citizen_sdk_secret_vault.hpp", "citizen_sdk_cng.hpp"}) {
      assert(source.find(forbidden) == std::string::npos);
    }
  }
  return 0;
}
