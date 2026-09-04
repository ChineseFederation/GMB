// 验证 Windows SDK-owned 钱包流程严格复用 Core 的 prepare/commit 和输入门禁。
#include <cassert>
#include <fstream>
#include <iterator>
#include <string>
#include <windows.h>
#include <atomic>
#include <chrono>
#include <cwchar>
#include <functional>
#include <thread>

#include "citizen_sdk/citizen_sdk_wallet_flow.hpp"
#include "citizen_sdk_host_record.hpp"
#include "citizen_sdk_wallet_validation.hpp"
#include "citizen_sdk_wallet_window.hpp"

#ifndef CITIZENSDK_WINDOWS_TEST_SOURCE_DIR
#error "CITIZENSDK_WINDOWS_TEST_SOURCE_DIR must point at the Windows source root"
#endif
#ifdef NDEBUG
#error "CitizenSDK Windows contract assertions must remain enabled"
#endif

namespace {

void pump_until(const std::function<bool()> &complete) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
  while (!complete()) {
    assert(std::chrono::steady_clock::now() < deadline);
    MSG message{};
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      assert(message.message != WM_QUIT);
      TranslateMessage(&message); DispatchMessageW(&message);
    }
    MsgWaitForMultipleObjects(0, nullptr, FALSE, 5, QS_ALLINPUT);
  }
}

HWND wallet_window() {
  HWND found{};
  EnumThreadWindows(GetCurrentThreadId(), +[](HWND hwnd, LPARAM context) -> BOOL {
    wchar_t type[128]{};
    constexpr wchar_t prefix[] = L"CitizenSDK.Wallet.";
    if (GetClassNameW(hwnd, type, 128) > 0 &&
        std::wcsncmp(type, prefix, sizeof(prefix) / sizeof(wchar_t) - 1) == 0) {
      *reinterpret_cast<HWND *>(context) = hwnd;
      return FALSE;
    }
    return TRUE;
  }, reinterpret_cast<LPARAM>(&found));
  return found;
}

void exercise_windows_ui() {
  namespace csw = citizen_sdk::windows;
  HWND owner = CreateWindowExW(0, L"STATIC", L"CitizenSDK wallet contract owner",
      WS_OVERLAPPEDWINDOW, 0, 0, 700, 700, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  assert(owner != nullptr);
  {
    csw::SensitiveInput input(owner, 200, 0, 0, 400, 80, true, false);
    const HWND control = static_cast<HWND>(input.native_handle());
    // 仅验证 Unicode 标量与长度，不保存口令/助记词测试向量。
    SendMessageW(control, WM_CHAR, 0xd83c, 0);
    SendMessageW(control, WM_CHAR, 0xdf31, 0);
    wchar_t unavailable[8]{};
    assert(SendMessageW(control, WM_GETTEXT, 8, reinterpret_cast<LPARAM>(unavailable)) == 0);
    assert(SendMessageW(control, WM_GETTEXTLENGTH, 0, 0) == 0);
    auto unicode = input.take_utf8();
    assert(unicode.size() == 4);
    unicode.clear();
    assert(input.take_utf8().empty());
    for (std::size_t i = 0; i < 1100; ++i) SendMessageW(control, WM_CHAR, 0x20 + (i % 80), 0);
    auto bounded = input.take_utf8();
    assert(bounded.size() == 1024);
    bounded.clear();
    SendMessageW(control, WM_CHAR, 0xd83c, 0);
    bool incomplete_rejected = false;
    try { (void)input.take_utf8(); }
    catch (const csw::HostError &error) { incomplete_rejected = error.code() == CITIZENSDK_ERROR_INVALID_ARGUMENT; }
    assert(incomplete_rejected && input.take_utf8().empty());
    const uint8_t malformed[] = {0xff};
    csw::SensitiveBuffer invalid(malformed, sizeof(malformed));
    bool malformed_rejected = false;
    try { input.set_utf8(invalid); }
    catch (const csw::HostError &error) { malformed_rejected = error.code() == CITIZENSDK_ERROR_INVALID_ARGUMENT; }
    assert(malformed_rejected && input.take_utf8().empty());
    input.clear();
    assert(input.take_utf8().empty());
  }
  csw::WindowRef reference(owner, std::this_thread::get_id());
  csw::ValidatedWalletRequest request{};
  request.kind = CITIZENSDK_WALLET_FLOW_CREATE;
  request.word_count = CITIZENSDK_WALLET_WORDS_12;
  unsigned actions = 0;
  unsigned cancelled = 0;
  {
    csw::WalletWindow window(reference.acquire(), request, [&] { ++actions; }, [&] { ++cancelled; });
    window.show();
    HWND dialog = wallet_window();
    assert(dialog != nullptr && !window.backup_confirmed());
    SendMessageW(dialog, WM_COMMAND, IDOK, 0);
    assert(actions == 1);
    window.set_busy("正在验证窗口合同");
    SendMessageW(dialog, WM_COMMAND, IDOK, 0);
    assert(actions == 1);
    window.set_error("窗口合同允许继续");
    SendMessageW(dialog, WM_COMMAND, IDOK, 0);
    assert(actions == 2);
    assert(window.take_password(true).empty());
    bool empty_rejected = false;
    try { (void)window.take_mnemonic(); }
    catch (const csw::HostError &error) { empty_rejected = error.code() == CITIZENSDK_ERROR_INVALID_ARGUMENT; }
    assert(empty_rejected);
    // 销毁 owner 后仍可通过独立 dispatcher 完成清理，但不能取得新 rootless 租约。
    assert(DestroyWindow(owner));
    owner = nullptr;
    assert(cancelled == 1 && wallet_window() == nullptr);
    assert(!reference.acquire().valid());
    std::atomic<bool> invoked{false};
    std::thread worker([&] { assert(window.invoke([&] { invoked.store(true); })); });
    worker.join();
    pump_until([&] { return invoked.load(); });
    window.clear_secrets();
    window.destroy();
    assert(cancelled == 1);
  }
  assert(reference.retire() == CITIZENSDK_OK);
}

bool rejected(const citizensdk_wallet_flow_request_v1_t &request) {
  try {
    (void)citizen_sdk::windows::validate_wallet_request(request);
    return false;
  } catch (const citizen_sdk::windows::HostError &error) {
    return error.code() == CITIZENSDK_ERROR_INVALID_ARGUMENT;
  }
}

citizensdk_wallet_flow_request_v1_t request(
    citizensdk_wallet_flow_kind_t kind) {
  citizensdk_wallet_flow_request_v1_t value{};
  value.struct_size = sizeof(value);
  value.abi_version = CITIZENSDK_HOST_ABI_VERSION;
  value.kind = kind;
  return value;
}

}  // namespace

int main() {
  exercise_windows_ui();
  const citizen_sdk::WalletFlowRequest public_default{};
  assert(public_default.kind == citizen_sdk::WalletFlowKind::Create);
  assert(public_default.word_count == 12);

  auto create12 = request(CITIZENSDK_WALLET_FLOW_CREATE);
  create12.word_count = CITIZENSDK_WALLET_WORDS_12;
  assert(citizen_sdk::windows::validate_wallet_request(create12).word_count ==
         CITIZENSDK_WALLET_WORDS_12);
  auto create24 = create12;
  create24.word_count = CITIZENSDK_WALLET_WORDS_24;
  assert(!rejected(create24));
  auto create18 = create12;
  create18.word_count = 18;
  assert(rejected(create18));

  uint32_t indices[] = {1, 1989};
  auto create_with_indices = create12;
  create_with_indices.account_indices = indices;
  create_with_indices.account_index_count = 2;
  assert(rejected(create_with_indices));

  auto import = request(CITIZENSDK_WALLET_FLOW_IMPORT);
  assert(!rejected(import));
  import.word_count = CITIZENSDK_WALLET_WORDS_12;
  assert(rejected(import));
  import.word_count = 0;
  import.account_indices = indices;
  import.account_index_count = 2;
  assert(rejected(import));

  auto add = request(CITIZENSDK_WALLET_FLOW_ADD_ACCOUNTS);
  assert(rejected(add));
  add.account_indices = indices;
  add.account_index_count = 2;
  add.word_count = CITIZENSDK_WALLET_WORDS_12;
  assert(rejected(add));
  add.word_count = 0;
  const auto validated = citizen_sdk::windows::validate_wallet_request(add);
  assert(validated.account_indices.size() == 2);
  assert(validated.account_indices[0] == 1);
  assert(validated.account_indices[1] == 1989);
  uint32_t duplicate[] = {1, 1};
  add.account_indices = duplicate;
  assert(rejected(add));
  uint32_t anchor[] = {0};
  add.account_indices = anchor;
  add.account_index_count = 1;
  assert(rejected(add));
  uint32_t out_of_range[] = {1990};
  add.account_indices = out_of_range;
  assert(rejected(add));

  auto wrong_version = create12;
  wrong_version.abi_version = CITIZENSDK_HOST_ABI_VERSION + 1;
  assert(rejected(wrong_version));
  auto short_struct = create12;
  short_struct.struct_size = sizeof(short_struct) - 1;
  assert(rejected(short_struct));

  const std::string source_path =
      std::string(CITIZENSDK_WINDOWS_TEST_SOURCE_DIR) +
      "/src/citizen_sdk_wallet_flow.cc";
  std::ifstream stream(source_path, std::ios::binary);
  assert(stream.good());
  const std::string source((std::istreambuf_iterator<char>(stream)),
                           std::istreambuf_iterator<char>());
  for (const char *required : {
           "citizensdk_prepare_wallet_creation",
           "citizensdk_prepared_wallet_copy_mnemonic",
           "citizensdk_commit_wallet_creation",
           "citizensdk_prepared_wallet_release",
           "class ResultLease final",
           "void WalletFlow::receive_prepare(citizensdk_result_handle_t result) noexcept",
           "void WalletFlow::receive_terminal(citizensdk_result_handle_t result) noexcept",
           "const citizensdk_error_code_t release_code = result_owner.release()",
           "if (result_owner.release() != CITIZENSDK_OK)",
           "if (!scheduled)",
           "if (request != 0)",
           "finish(CITIZENSDK_WALLET_FLOW_FAILED, code)",
           "if (finished_.exchange(true)) return",
           "host_->finish_wallet_flow(lifecycle_token_)",
           "if (host->public_sdk() == 0) return CITIZENSDK_ERROR_NOT_READY",
           "if (vault == CITIZENSDK_HOST_VAULT_UNSUPPORTED)",
           "return CITIZENSDK_ERROR_UNSUPPORTED",
           "if (vault != CITIZENSDK_HOST_VAULT_AVAILABLE)",
           "return CITIZENSDK_ERROR_UNAVAILABLE",
           "for (unsigned attempt = 0; attempt < 8; ++attempt)",
           "std::terminate()",
           "irreversible_.store(true)",
           "window_->clear_secrets()",
           "WalletFlow::release_prepared_or_supervise",
           "WalletFlow::supervise_prepared_release",
           "if (prepared_ != 0) std::terminate()",
           "cleanup_supervised_.exchange(true)",
       }) {
    assert(source.find(required) != std::string::npos);
  }
  assert(source.find("getAccountPrivateKey") == std::string::npos);

  // prepared handle 的 release 失败不能抹掉唯一所有者或提前释放钱包
  // lifecycle token；supervisor 只有在 Core 确认 release 后才收口 flow。
  const auto release_supervisor =
      source.find("void WalletFlow::supervise_prepared_release(");
  const auto retry_loop = source.find("for (;;) {", release_supervisor);
  const auto retry_release = source.find(
      "citizensdk_prepared_wallet_release(sdk, prepared)", retry_loop);
  const auto clear_prepared =
      source.find("self->prepared_ = 0", retry_release);
  const auto finish_lifecycle = source.find(
      "self->host_->finish_wallet_flow(self->lifecycle_token_)",
      clear_prepared);
  const auto erase_flow =
      source.find("self->terminal_(self->handle_)", finish_lifecycle);
  assert(release_supervisor != std::string::npos &&
         retry_loop != std::string::npos &&
         retry_release != std::string::npos &&
         clear_prepared != std::string::npos &&
         finish_lifecycle != std::string::npos &&
         erase_flow != std::string::npos && release_supervisor < retry_loop &&
         retry_loop < retry_release && retry_release < clear_prepared &&
         clear_prepared < finish_lifecycle && finish_lifecycle < erase_flow);

  const std::string window_path =
      std::string(CITIZENSDK_WINDOWS_TEST_SOURCE_DIR) +
      "/src/citizen_sdk_wallet_window.cc";
  std::ifstream window_stream(window_path, std::ios::binary);
  assert(window_stream.good());
  const std::string window_source(
      (std::istreambuf_iterator<char>(window_stream)),
      std::istreambuf_iterator<char>());
  for (const char *required : {"case WM_GETTEXT: case WM_GETTEXTLENGTH: case WM_SETTEXT:",
                               "secure_zero(text.data(), sizeof(text))",
                               "WDA_EXCLUDEFROMCAPTURE",
                               "if (!parent.on_ui_thread()) std::terminate()"}) {
    assert(window_source.find(required) != std::string::npos);
  }
  return 0;
}
