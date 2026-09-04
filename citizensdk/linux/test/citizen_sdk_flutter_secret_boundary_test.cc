#include <cassert>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include "citizen_sdk_flutter_codec.hpp"
#include "citizen_sdk_flutter_test_support.hpp"

#ifndef CITIZENSDK_LINUX_TEST_SOURCE_DIR
#error "CITIZENSDK_LINUX_TEST_SOURCE_DIR must point at the Linux source root"
#endif

int main() {
  using citizen_sdk::flutter::Method;
  using citizen_sdk::flutter::Value;
  using citizen_sdk::flutter::decode_request;
  using citizen_sdk::flutter::test::fl;
  using citizen_sdk::flutter::test::list;

  // Wallet creation/import cross the channel only as intent; mnemonic,
  // password, secret and prepared-wallet ownership stay in native UI/Host.
  auto create = fl(list({Value::integer(1), Value::string("session"),
                         Value::integer(7), Value::integer(24)}));
  const auto create_request = decode_request("createWallet", create.get());
  assert(create_request.method == Method::create_wallet);
  assert(create_request.word_count == 24);
  assert(create_request.payload.empty());
  assert(create_request.name.empty());

  auto import = fl(list({Value::integer(1), Value::string("session"),
                         Value::integer(8)}));
  const auto import_request = decode_request("importWallet", import.get());
  assert(import_request.method == Method::import_wallet);
  assert(import_request.payload.empty());
  assert(import_request.indices.empty());

  // Guard the actual adapter sources against a future Dart-controlled path,
  // application identity, raw GTK pointer or secret-bearing transport method.
  const std::filesystem::path root(CITIZENSDK_LINUX_TEST_SOURCE_DIR);
  const std::vector<std::string> sources{
      "include/citizen_sdk/citizen_sdk_plugin.h",
      "src/citizen_sdk_plugin.cc",
      "src/citizen_sdk_flutter_environment.hpp",
      "src/citizen_sdk_flutter_environment.cc",
      "src/citizen_sdk_flutter_codec.hpp",
      "src/citizen_sdk_flutter_sessions.hpp",
      "src/citizen_sdk_flutter_wallet_flow.hpp",
  };
  for (const auto &relative : sources) {
    std::ifstream stream(root / relative, std::ios::binary);
    assert(stream.good());
    const std::string text((std::istreambuf_iterator<char>(stream)),
                           std::istreambuf_iterator<char>());
    for (const char *forbidden : {
             "dart_asset_root", "dart_storage_root", "dart_application_id",
             "dart_gtk_parent", "exportMnemonic", "exportPrivateKey",
             "prepared_wallet_handle", "plaintext_dek",
         }) {
      assert(text.find(forbidden) == std::string::npos);
    }
  }
  return 0;
}
