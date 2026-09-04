#include "citizen_sdk_wallet_window.hpp"

#include <windows.h>
#include <algorithm>
#include <array>
#include <cstring>
#include <exception>
#include <limits>
#include <thread>
#include <utility>
#include "citizen_sdk_host_record.hpp"
#include "citizen_sdk_input_limits.hpp"

namespace citizen_sdk::windows {
namespace {
constexpr int kMnemonic = 100;
constexpr int kPassword = 101;
constexpr int kConfirmation = 102;
constexpr int kBackup = 103;
constexpr int kAction = IDOK;
constexpr std::size_t kInputUnits = input_limits::kMaximumUnlockPasswordBytes;

HINSTANCE module_for(WNDPROC procedure) {
  HINSTANCE module{};
  require(GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                                GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(procedure), &module) != FALSE,
          CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK UI module is unavailable");
  return module;
}

void register_class(const std::wstring &name, HINSTANCE module, WNDPROC procedure) {
  WNDCLASSEXW type{};
  type.cbSize = sizeof(type);
  type.hInstance = module;
  type.lpfnWndProc = procedure;
  type.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  type.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  type.lpszClassName = name.c_str();
  require(RegisterClassExW(&type) != 0, CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK UI class could not be registered");
}

// 此函数只转换非秘密状态文案；秘密始终使用下方 SensitiveInput 的有界缓冲。
std::wstring public_text(const std::string &value) {
  require(value.size() <= 65536, CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "CitizenSDK status text is too large");
  if (value.empty()) return {};
  const int required = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      value.data(), static_cast<int>(value.size()), nullptr, 0);
  require(required > 0, CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "CitizenSDK status text is not UTF-8");
  std::wstring result(static_cast<std::size_t>(required), L'\0');
  require(MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
              static_cast<int>(value.size()), result.data(), required) == required,
          CITIZENSDK_ERROR_INTERNAL, "CitizenSDK status conversion failed");
  return result;
}

HWND control(HWND parent, HINSTANCE module, const wchar_t *type,
             const wchar_t *text, DWORD style, int id, int x, int y, int w, int h) {
  HWND result = CreateWindowExW(0, type, text, WS_CHILD | WS_VISIBLE | style,
      x, y, w, h, parent, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)), module, nullptr);
  require(result != nullptr, CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK UI control is unavailable");
  SendMessageW(result, WM_SETFONT, reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)), TRUE);
  return result;
}
}  // namespace

struct SensitiveInput::Impl final {
  HWND hwnd{};
  HINSTANCE module{};
  std::wstring class_name;  // 非秘密：每实例 Win32 类名，销毁后注销。
  std::thread::id ui_thread{std::this_thread::get_id()};
  std::array<wchar_t, kInputUnits + 1> text{};
  std::size_t size{};
  wchar_t high{};
  bool masked{};
  bool multiline{};
  bool read_only{};
  bool registered{};

  ~Impl() {
    if (std::this_thread::get_id() != ui_thread) std::terminate();
    clear();
    if (hwnd != nullptr && !DestroyWindow(hwnd)) std::terminate();
    if (registered && !UnregisterClassW(class_name.c_str(), module)) std::terminate();
  }
  void clear() noexcept {
    secure_zero(text.data(), sizeof(text));
    secure_zero(&high, sizeof(high));
    size = 0;
    if (hwnd != nullptr) InvalidateRect(hwnd, nullptr, TRUE);
  }
  void append(wchar_t value) noexcept {
    if (read_only || value == 0) return;
    if (value >= 0xd800 && value <= 0xdbff) {
      high = value;
      return;
    }
    wchar_t pair[2]{};
    std::size_t count = 1;
    if (value >= 0xdc00 && value <= 0xdfff) {
      if (high == 0) return;
      pair[0] = high; pair[1] = value; count = 2;
    } else {
      pair[0] = value;
    }
    secure_zero(&high, sizeof(high));
    if (size + count <= kInputUnits) {
      for (std::size_t i = 0; i < count; ++i) text[size + i] = pair[i];
      const int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
          text.data(), static_cast<int>(size + count), nullptr, 0, nullptr, nullptr);
      if (bytes > 0 && static_cast<std::size_t>(bytes) <= input_limits::kMaximumUnlockPasswordBytes) {
        size += count;
      } else {
        secure_zero(text.data() + size, count * sizeof(wchar_t));
      }
    }
    secure_zero(pair, sizeof(pair));
    InvalidateRect(hwnd, nullptr, TRUE);
  }
  static LRESULT CALLBACK procedure(HWND hwnd, UINT message, WPARAM wp, LPARAM lp) noexcept {
    auto *self = reinterpret_cast<Impl *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      self = static_cast<Impl *>(reinterpret_cast<CREATESTRUCTW *>(lp)->lpCreateParams);
      self->hwnd = hwnd;
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (self == nullptr) return DefWindowProcW(hwnd, message, wp, lp);
    switch (message) {
      case WM_GETTEXT: case WM_GETTEXTLENGTH: case WM_SETTEXT:
      case WM_COPY: case WM_CUT: case WM_PASTE: case WM_CLEAR:
      case WM_UNDO: case EM_GETLINE: case EM_GETHANDLE:
      case EM_SETHANDLE: case EM_REPLACESEL:
        // 不给窗口消息或系统剪贴板提供秘密读写捷径。
        return 0;
      case WM_GETDLGCODE:
        return DLGC_WANTCHARS | DLGC_WANTARROWS;
      case WM_LBUTTONDOWN:
        SetFocus(hwnd); return 0;
      case WM_SETFOCUS:
        InvalidateRect(hwnd, nullptr, FALSE); return 0;
      case WM_KILLFOCUS:
        secure_zero(&self->high, sizeof(self->high));
        InvalidateRect(hwnd, nullptr, FALSE); return 0;
      case WM_KEYDOWN:
        if (wp == VK_TAB) {
          HWND next = GetNextDlgTabItem(GetParent(hwnd), hwnd,
              (GetKeyState(VK_SHIFT) & 0x8000) != 0);
          if (next != nullptr) SetFocus(next);
          return 0;
        }
        if (wp == VK_ESCAPE) {
          PostMessageW(GetParent(hwnd), WM_COMMAND, IDCANCEL, 0); return 0;
        }
        break;
      case WM_CHAR:
        if (self->read_only) return 0;
        if (wp == L'\b') {
          secure_zero(&self->high, sizeof(self->high));
          if (self->size != 0) {
            std::size_t count = 1;
            if (self->size >= 2 && self->text[self->size - 1] >= 0xdc00 &&
                self->text[self->size - 1] <= 0xdfff) count = 2;
            self->size -= count;
            secure_zero(self->text.data() + self->size, count * sizeof(wchar_t));
            InvalidateRect(hwnd, nullptr, TRUE);
          }
          return 0;
        }
        if (wp == L'\r') {
          if (self->multiline) self->append(L'\n');
          else PostMessageW(GetParent(hwnd), WM_COMMAND, IDOK, 0);
          return 0;
        }
        if (wp >= 0x20 && wp <= 0xffff) self->append(static_cast<wchar_t>(wp));
        return 0;
      case WM_UNICHAR:
        if (wp == UNICODE_NOCHAR) return TRUE;
        if (self->read_only) return 0;
        if (wp >= 0x20 && wp < 0xd800) self->append(static_cast<wchar_t>(wp));
        else if (wp > 0xdfff && wp <= 0xffff) self->append(static_cast<wchar_t>(wp));
        else if (wp >= 0x10000 && wp <= 0x10ffff) {
          const auto scalar = static_cast<uint32_t>(wp - 0x10000);
          self->append(static_cast<wchar_t>(0xd800 + (scalar >> 10)));
          self->append(static_cast<wchar_t>(0xdc00 + (scalar & 0x3ff)));
        }
        return 0;
      case WM_PAINT: {
        PAINTSTRUCT paint{};
        HDC dc = BeginPaint(hwnd, &paint);
        if (dc == nullptr) return 0;
        RECT area{};
        GetClientRect(hwnd, &area);
        FillRect(dc, &area, reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1));
        FrameRect(dc, &area, reinterpret_cast<HBRUSH>(GetStockObject(GRAY_BRUSH)));
        InflateRect(&area, -8, -8);
        auto old = SelectObject(dc, GetStockObject(DEFAULT_GUI_FONT));
        SetBkMode(dc, TRANSPARENT);
        if (self->masked) {
          std::array<wchar_t, kInputUnits> mask{};
          std::fill_n(mask.data(), self->size, L'\x2022');
          DrawTextW(dc, mask.data(), static_cast<int>(self->size), &area, DT_LEFT | DT_WORDBREAK | DT_NOPREFIX);
        } else {
          DrawTextW(dc, self->text.data(), static_cast<int>(self->size), &area,
                    DT_LEFT | DT_WORDBREAK | DT_NOPREFIX);
        }
        if (GetFocus() == hwnd) DrawFocusRect(dc, &area);
        SelectObject(dc, old);
        EndPaint(hwnd, &paint);
        return 0;
      }
      case WM_DESTROY:
        self->clear();
        self->hwnd = nullptr;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
        return 0;
      default: break;
    }
    return DefWindowProcW(hwnd, message, wp, lp);
  }
};

SensitiveInput::SensitiveInput(void *parent, int identity, int x, int y,
                               int width, int height, bool masked, bool multiline)
    : impl_(std::make_unique<Impl>()) {
  impl_->masked = masked;
  impl_->multiline = multiline;
  impl_->module = module_for(Impl::procedure);
  impl_->class_name = L"CitizenSDK.Input." + std::to_wstring(reinterpret_cast<UINT_PTR>(impl_.get()));
  register_class(impl_->class_name, impl_->module, Impl::procedure);
  impl_->registered = true;
  impl_->hwnd = CreateWindowExW(0, impl_->class_name.c_str(), L"", WS_CHILD | WS_VISIBLE | WS_TABSTOP,
      x, y, width, height, static_cast<HWND>(parent),
      reinterpret_cast<HMENU>(static_cast<INT_PTR>(identity)), impl_->module, impl_.get());
  require(impl_->hwnd != nullptr, CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK sensitive input is unavailable");
}
SensitiveInput::~SensitiveInput() = default;
void *SensitiveInput::native_handle() const noexcept { return impl_->hwnd; }
void SensitiveInput::clear() noexcept {
  if (std::this_thread::get_id() != impl_->ui_thread) std::terminate();
  impl_->clear();
}
void SensitiveInput::set_read_only(bool value) noexcept {
  if (std::this_thread::get_id() != impl_->ui_thread) std::terminate();
  impl_->read_only = value;
}
SensitiveBuffer SensitiveInput::take_utf8() {
  require(std::this_thread::get_id() == impl_->ui_thread && impl_->hwnd != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK sensitive input is unavailable");
  try {
    require(impl_->high == 0, CITIZENSDK_ERROR_INVALID_ARGUMENT, "input contains incomplete Unicode");
    if (impl_->size == 0) { clear(); return {}; }
    const int required = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
        impl_->text.data(), static_cast<int>(impl_->size), nullptr, 0, nullptr, nullptr);
    require(required > 0 && static_cast<std::size_t>(required) <= input_limits::kMaximumUnlockPasswordBytes,
            CITIZENSDK_ERROR_INVALID_ARGUMENT, "sensitive input exceeds its UTF-8 limit");
    SensitiveBuffer result(static_cast<std::size_t>(required));
    require(WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, impl_->text.data(),
                static_cast<int>(impl_->size), reinterpret_cast<char *>(result.data()),
                required, nullptr, nullptr) == required,
            CITIZENSDK_ERROR_INTERNAL, "sensitive input conversion failed");
    clear();
    return result;
  } catch (...) { clear(); throw; }
}
void SensitiveInput::set_utf8(const SensitiveBuffer &value) {
  require(std::this_thread::get_id() == impl_->ui_thread && impl_->hwnd != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK sensitive input is unavailable");
  clear();
  try {
    require(value.size() <= input_limits::kMaximumUnlockPasswordBytes,
            CITIZENSDK_ERROR_INVALID_ARGUMENT, "sensitive display exceeds its limit");
    if (value.empty()) return;
    require(std::memchr(value.data(), 0, value.size()) == nullptr,
            CITIZENSDK_ERROR_INVALID_ARGUMENT, "sensitive display contains NUL");
    const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
        reinterpret_cast<const char *>(value.data()), static_cast<int>(value.size()),
        impl_->text.data(), static_cast<int>(kInputUnits));
    require(count > 0, CITIZENSDK_ERROR_INVALID_ARGUMENT, "sensitive display is not UTF-8");
    impl_->size = static_cast<std::size_t>(count);
    InvalidateRect(impl_->hwnd, nullptr, TRUE);
  } catch (...) { clear(); throw; }
}

struct WalletWindow::Impl final {
  WindowLease parent;
  HWND hwnd{};
  HWND status{};
  HWND backup{};
  HWND action_button{};
  HINSTANCE module{};
  std::wstring class_name;
  std::unique_ptr<SensitiveInput> mnemonic;
  std::unique_ptr<SensitiveInput> password;
  std::unique_ptr<SensitiveInput> confirmation;
  Action action;
  Action cancel;
  citizensdk_wallet_flow_kind_t kind{};
  bool registered{};
  bool destroying{};
  bool owner_disabled{};
  bool busy{};
  ~Impl() {
    if ((hwnd != nullptr || registered || mnemonic || password || confirmation) &&
        !parent.on_ui_thread()) std::terminate();
    if (hwnd != nullptr || mnemonic || password || confirmation) destroy();
    confirmation.reset(); password.reset(); mnemonic.reset();
    if (registered && !UnregisterClassW(class_name.c_str(), module)) std::terminate();
  }
  void clear() noexcept {
    if (mnemonic) mnemonic->clear();
    if (password) password->clear();
    if (confirmation) confirmation->clear();
  }
  void restore_owner() noexcept {
    if (owner_disabled && parent.valid() && parent.get() != nullptr) {
      EnableWindow(static_cast<HWND>(parent.get()), TRUE);
    }
    owner_disabled = false;
  }
  void destroy() noexcept {
    if (!parent.on_ui_thread()) std::terminate();
    destroying = true;
    clear();
    if (hwnd != nullptr && !DestroyWindow(hwnd)) std::terminate();
    restore_owner();
    destroying = false;
  }
  static LRESULT CALLBACK procedure(HWND hwnd, UINT message, WPARAM wp, LPARAM lp) noexcept {
    auto *self = reinterpret_cast<Impl *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      self = static_cast<Impl *>(reinterpret_cast<CREATESTRUCTW *>(lp)->lpCreateParams);
      self->hwnd = hwnd;
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (self == nullptr) return DefWindowProcW(hwnd, message, wp, lp);
    try {
      if (message == WM_COMMAND) {
        const int identity = LOWORD(wp);
        if (identity == IDCANCEL) { const auto callback = self->cancel; callback(); return 0; }
        if (identity == kAction && !self->busy) { const auto callback = self->action; callback(); return 0; }
      }
      if (message == WM_CLOSE) { const auto callback = self->cancel; callback(); return 0; }
      if (message == WM_DESTROY) {
        self->clear();
        const bool notify = !self->destroying;
        const auto callback = self->cancel;
        self->hwnd = nullptr;
        self->status = nullptr; self->backup = nullptr; self->action_button = nullptr;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
        self->restore_owner();
        // callback 可完成 flow 并销毁当前 C++ 对象；此后绝不再读取 self。
        if (notify) callback();
        return 0;
      }
    } catch (...) { std::terminate(); }
    return DefWindowProcW(hwnd, message, wp, lp);
  }
};

WalletWindow::WalletWindow(WindowLease parent, const ValidatedWalletRequest &request,
                           Action action, Action cancel)
    : impl_(std::make_unique<Impl>()) {
  impl_->parent = std::move(parent);
  require(impl_->parent.valid(), CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK parent window was destroyed");
  impl_->kind = request.kind;
  impl_->action = std::move(action); impl_->cancel = std::move(cancel);
  impl_->module = module_for(Impl::procedure);
  impl_->class_name = L"CitizenSDK.Wallet." + std::to_wstring(reinterpret_cast<UINT_PTR>(impl_.get()));
  register_class(impl_->class_name, impl_->module, Impl::procedure);
  impl_->registered = true;
  impl_->hwnd = CreateWindowExW(WS_EX_DLGMODALFRAME, impl_->class_name.c_str(), L"公民钱包",
      WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU, CW_USEDEFAULT, CW_USEDEFAULT, 600, 650,
      static_cast<HWND>(impl_->parent.get()), nullptr, impl_->module, impl_.get());
  require(impl_->hwnd != nullptr, CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK wallet window is unavailable");
  require(SetWindowDisplayAffinity(impl_->hwnd, WDA_EXCLUDEFROMCAPTURE) != FALSE,
          CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK sensitive display protection is unavailable");
  impl_->status = control(impl_->hwnd, impl_->module, L"STATIC", L"", SS_LEFT, 0, 20, 18, 550, 70);
  impl_->mnemonic = std::make_unique<SensitiveInput>(impl_->hwnd, kMnemonic, 20, 95, 550, 220, false, true);
  control(impl_->hwnd, impl_->module, L"STATIC", L"可选的助记词派生密码（不是设备金库口令）", SS_LEFT, 0, 20, 330, 550, 24);
  impl_->password = std::make_unique<SensitiveInput>(impl_->hwnd, kPassword, 20, 358, 550, 45, true, false);
  impl_->confirmation = std::make_unique<SensitiveInput>(impl_->hwnd, kConfirmation, 20, 413, 550, 45, true, false);
  impl_->backup = control(impl_->hwnd, impl_->module, L"BUTTON", L"我已在离线安全位置备份助记词",
      BS_AUTOCHECKBOX | WS_TABSTOP, kBackup, 20, 475, 550, 30);
  impl_->action_button = control(impl_->hwnd, impl_->module, L"BUTTON", L"", BS_DEFPUSHBUTTON | WS_TABSTOP,
      kAction, 320, 535, 250, 40);
  control(impl_->hwnd, impl_->module, L"BUTTON", L"取消", BS_PUSHBUTTON | WS_TABSTOP, IDCANCEL, 20, 535, 130, 40);
  if (request.kind == CITIZENSDK_WALLET_FLOW_CREATE) {
    SetWindowTextW(impl_->status, L"助记词只在本设备生成，显示后必须离线备份。\n设备 TPM 金库口令将在提交时由 CitizenSDK 单独询问。");
    SetWindowTextW(impl_->action_button, L"生成钱包");
    ShowWindow(static_cast<HWND>(impl_->mnemonic->native_handle()), SW_HIDE);
  } else {
    SetWindowTextW(impl_->status, L"助记词与派生密码只在本机 CitizenSDK 原生界面和 Rust Core 内使用。");
    SetWindowTextW(impl_->action_button, request.kind == CITIZENSDK_WALLET_FLOW_IMPORT ? L"导入钱包" : L"添加账户");
    ShowWindow(static_cast<HWND>(impl_->confirmation->native_handle()), SW_HIDE);
  }
  ShowWindow(impl_->backup, SW_HIDE);
}
WalletWindow::~WalletWindow() = default;
bool WalletWindow::on_ui_thread() const noexcept { return impl_->parent.on_ui_thread(); }
void WalletWindow::show() {
  require(on_ui_thread() && impl_->hwnd != nullptr && impl_->parent.valid(),
          CITIZENSDK_ERROR_UNAVAILABLE, "CitizenSDK wallet window is unavailable");
  HWND owner = static_cast<HWND>(impl_->parent.get());
  if (owner != nullptr && IsWindowEnabled(owner)) {
    EnableWindow(owner, FALSE); impl_->owner_disabled = true;
  }
  ShowWindow(impl_->hwnd, SW_SHOW);
  SetFocus(static_cast<HWND>((impl_->kind == CITIZENSDK_WALLET_FLOW_CREATE ?
      impl_->password : impl_->mnemonic)->native_handle()));
}
void WalletWindow::destroy() noexcept { impl_->destroy(); }
void WalletWindow::set_busy(const std::string &message) {
  require(on_ui_thread(), CITIZENSDK_ERROR_BUSY, "wallet UI requires its owner thread");
  if (impl_->hwnd == nullptr) return;
  const auto text = public_text(message);
  SetWindowTextW(impl_->status, text.c_str());
  EnableWindow(impl_->action_button, FALSE);
  impl_->busy = true;
}
void WalletWindow::set_error(const std::string &message) {
  require(on_ui_thread(), CITIZENSDK_ERROR_BUSY, "wallet UI requires its owner thread");
  if (impl_->hwnd == nullptr) return;
  const auto text = public_text(message);
  SetWindowTextW(impl_->status, text.c_str());
  EnableWindow(impl_->action_button, TRUE);
  impl_->busy = false;
}
void WalletWindow::show_prepared_mnemonic(const SensitiveBuffer &mnemonic) {
  require(on_ui_thread() && impl_->hwnd != nullptr && impl_->parent.valid(),
          CITIZENSDK_ERROR_UNAVAILABLE, "wallet window was destroyed before preparation completed");
  impl_->mnemonic->set_utf8(mnemonic);
  impl_->mnemonic->set_read_only(true);
  ShowWindow(static_cast<HWND>(impl_->mnemonic->native_handle()), SW_SHOW);
  ShowWindow(impl_->backup, SW_SHOW);
  ShowWindow(static_cast<HWND>(impl_->password->native_handle()), SW_HIDE);
  ShowWindow(static_cast<HWND>(impl_->confirmation->native_handle()), SW_HIDE);
  SetWindowTextW(impl_->action_button, L"确认备份并创建");
  SetWindowTextW(impl_->status, L"请离线备份助记词并确认。CitizenSDK 不会再次显示它。");
  EnableWindow(impl_->action_button, TRUE);
  impl_->busy = false;
}
bool WalletWindow::backup_confirmed() const noexcept {
  return on_ui_thread() && impl_->backup != nullptr &&
      SendMessageW(impl_->backup, BM_GETCHECK, 0, 0) == BST_CHECKED;
}
SensitiveBuffer WalletWindow::take_mnemonic() {
  auto value = impl_->mnemonic->take_utf8();
  require(!value.empty(), CITIZENSDK_ERROR_INVALID_ARGUMENT, "wallet mnemonic input is empty");
  return value;
}
SensitiveBuffer WalletWindow::take_password(bool require_confirmation) {
  auto first = impl_->password->take_utf8();
  auto second = impl_->confirmation->take_utf8();
  if (require_confirmation) {
    require(first.size() == second.size() &&
                (first.empty() || std::memcmp(first.data(), second.data(), first.size()) == 0),
            CITIZENSDK_ERROR_INVALID_ARGUMENT, "wallet derivation passwords do not match");
  }
  return first;
}
void WalletWindow::clear_secrets() noexcept { impl_->clear(); }
bool WalletWindow::invoke(std::function<void()> action) noexcept {
  return impl_->parent.invoke(std::move(action));
}

}  // namespace citizen_sdk::windows
