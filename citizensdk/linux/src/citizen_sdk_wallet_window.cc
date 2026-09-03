#include "citizen_sdk_wallet_window.hpp"

#include <cstring>
#include <exception>
#include <utility>
#include "citizen_sdk_host_record.hpp"
#include "citizen_sdk_input_limits.hpp"

#if CITIZENSDK_ENABLE_WALLET_UI
#include <gtk/gtk.h>
#endif

namespace citizen_sdk::linux {

#if CITIZENSDK_ENABLE_WALLET_UI
namespace {
gboolean delete_requested(GtkWidget *, GdkEvent *, gpointer context) {
  auto *callback = static_cast<WalletWindow::Action *>(context);
  try { (*callback)(); } catch (...) {}
  return TRUE;
}

struct GtkSecretText final {
  gchar *value{};
  std::size_t size{};
  ~GtkSecretText() {
    if (value != nullptr) {
      secure_zero(value, size);
      g_free(value);
    }
  }
};

}  // namespace
#endif

WalletWindow::WalletWindow(void *parent, const ValidatedWalletRequest &request,
                           Action action, Action cancel)
    : action_(std::move(action)), cancel_(std::move(cancel)) {
  kind_ = request.kind;
  ui_thread_ = std::this_thread::get_id();
#if !CITIZENSDK_ENABLE_WALLET_UI
  (void)parent; (void)request;
  throw HostError(CITIZENSDK_ERROR_UNSUPPORTED,
                  "CitizenSDK wallet UI was not built");
#else
  require(gtk_init_check(nullptr, nullptr) != FALSE,
          CITIZENSDK_ERROR_UNAVAILABLE,
          "GTK display is unavailable for CitizenSDK wallet UI");
  ui_context_ = g_main_context_ref_thread_default();
  require(ui_context_ != nullptr, CITIZENSDK_ERROR_UNAVAILABLE,
          "GTK thread-default context is unavailable for CitizenSDK wallet UI");
  GtkWidget *dialog = gtk_dialog_new_with_buttons(
      "公民钱包", static_cast<GtkWindow *>(parent),
      static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT),
      "取消", GTK_RESPONSE_CANCEL, nullptr);
  window_ = dialog;
  gtk_window_set_default_size(GTK_WINDOW(dialog), 560, 560);
  gtk_window_set_resizable(GTK_WINDOW(dialog), TRUE);
  GtkWidget *area = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
  gtk_container_set_border_width(GTK_CONTAINER(box), 20);
  gtk_container_add(GTK_CONTAINER(area), box);
  status_ = gtk_label_new("");
  gtk_label_set_line_wrap(GTK_LABEL(status_), TRUE);
  gtk_label_set_xalign(GTK_LABEL(status_), 0.0F);
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(status_), FALSE, FALSE, 0);

  GtkWidget *scroll = gtk_scrolled_window_new(nullptr, nullptr);
  mnemonic_scroll_ = scroll;
  gtk_widget_set_size_request(scroll, -1, 240);
  mnemonic_ = gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(mnemonic_), GTK_WRAP_WORD_CHAR);
  gtk_text_view_set_accepts_tab(GTK_TEXT_VIEW(mnemonic_), FALSE);
  gtk_container_add(GTK_CONTAINER(scroll), static_cast<GtkWidget *>(mnemonic_));
  gtk_box_pack_start(GTK_BOX(box), scroll, TRUE, TRUE, 0);

  password_ = gtk_entry_new();
  confirmation_ = gtk_entry_new();
  for (void *entry : {password_, confirmation_}) {
    gtk_entry_set_visibility(GTK_ENTRY(entry), FALSE);
    gtk_entry_set_input_purpose(GTK_ENTRY(entry), GTK_INPUT_PURPOSE_PASSWORD);
    gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(entry), FALSE, FALSE, 0);
  }
  gtk_entry_set_placeholder_text(GTK_ENTRY(password_), "可选的助记词派生密码");
  gtk_entry_set_placeholder_text(GTK_ENTRY(confirmation_), "再次输入派生密码");
  backup_ = gtk_check_button_new_with_label("我已在离线安全位置备份助记词");
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(backup_), FALSE, FALSE, 0);
  action_button_ = gtk_button_new();
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(action_button_), FALSE, FALSE, 0);

  if (request.kind == CITIZENSDK_WALLET_FLOW_CREATE) {
    gtk_widget_hide(scroll);
    gtk_widget_hide(static_cast<GtkWidget *>(backup_));
    gtk_button_set_label(GTK_BUTTON(action_button_), "生成钱包");
    gtk_label_set_text(GTK_LABEL(status_),
                       "助记词只在本设备生成。显示后必须离线备份。\n设备 TPM 金库口令将在提交时由 CitizenSDK 单独询问。");
  } else {
    gtk_widget_hide(static_cast<GtkWidget *>(confirmation_));
    gtk_widget_hide(static_cast<GtkWidget *>(backup_));
    gtk_button_set_label(GTK_BUTTON(action_button_),
                         request.kind == CITIZENSDK_WALLET_FLOW_IMPORT ? "导入钱包" : "添加账户");
    gtk_label_set_text(GTK_LABEL(status_),
                       "助记词与派生密码只在本机 CitizenSDK 原生界面和 Rust Core 内使用。");
  }
  g_signal_connect(action_button_, "clicked", G_CALLBACK(+[](GtkButton *, gpointer data) {
    try { static_cast<WalletWindow *>(data)->action_(); } catch (...) {}
  }), this);
  g_signal_connect(dialog, "response", G_CALLBACK(+[](GtkDialog *, gint response, gpointer data) {
    try {
      auto *self = static_cast<WalletWindow *>(data);
      if (response == GTK_RESPONSE_CANCEL ||
          response == GTK_RESPONSE_DELETE_EVENT) {
        self->cancel_();
      }
    } catch (...) {}
  }), this);
  g_signal_connect(dialog, "delete-event", G_CALLBACK(delete_requested), &cancel_);
  g_signal_connect(dialog, "destroy", G_CALLBACK(+[](GtkWidget *widget,
                                                      gpointer data) noexcept {
    auto *self = static_cast<WalletWindow *>(data);
    try {
      if (self->window_ != widget) return;
      self->clear_secrets();
      const bool notify_cancel = !self->destroying_;
      self->window_ = nullptr;
      self->mnemonic_scroll_ = nullptr;
      self->mnemonic_ = nullptr;
      self->password_ = nullptr;
      self->confirmation_ = nullptr;
      self->backup_ = nullptr;
      self->action_button_ = nullptr;
      self->status_ = nullptr;
      // GTK destroys modal children with their parent. Convert that external
      // terminal event into the normal wallet cancellation path before any
      // raw child widget pointer can be observed again.
      if (notify_cancel) self->cancel_();
    } catch (...) {
      std::terminate();
    }
  }), this);
#endif
}

WalletWindow::~WalletWindow() {
  // GTK widgets are thread-affine. Losing the captured UI executor is a
  // fail-closed host violation: destroying a widget from a worker would risk
  // both use-after-free and leaving secret entry buffers in an undefined
  // state.
  if (window_ != nullptr && !on_ui_thread()) std::terminate();
  destroy();
#if CITIZENSDK_ENABLE_WALLET_UI
  if (ui_context_ != nullptr) {
    g_main_context_unref(static_cast<GMainContext *>(ui_context_));
    ui_context_ = nullptr;
  }
#endif
}

void WalletWindow::show() {
#if CITIZENSDK_ENABLE_WALLET_UI
  require(window_ != nullptr, CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK wallet window is no longer available");
  gtk_widget_show_all(static_cast<GtkWidget *>(window_));
  if (kind_ == CITIZENSDK_WALLET_FLOW_CREATE) {
    gtk_widget_hide(static_cast<GtkWidget *>(mnemonic_scroll_));
    gtk_widget_hide(static_cast<GtkWidget *>(backup_));
  } else {
    gtk_widget_hide(static_cast<GtkWidget *>(confirmation_));
    gtk_widget_hide(static_cast<GtkWidget *>(backup_));
  }
#endif
}

void WalletWindow::destroy() noexcept {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (window_ != nullptr) {
    if (!on_ui_thread()) std::terminate();
    destroying_ = true;
    clear_secrets();
    gtk_widget_destroy(static_cast<GtkWidget *>(window_));
    window_ = nullptr;
    destroying_ = false;
  }
#endif
}

void WalletWindow::set_busy(const std::string &message) {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (window_ == nullptr || status_ == nullptr || action_button_ == nullptr) {
    return;
  }
  gtk_label_set_text(GTK_LABEL(status_), message.c_str());
  gtk_widget_set_sensitive(static_cast<GtkWidget *>(action_button_), FALSE);
#else
  (void)message;
#endif
}

void WalletWindow::set_error(const std::string &message) {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (window_ == nullptr || status_ == nullptr || action_button_ == nullptr) {
    return;
  }
  gtk_label_set_text(GTK_LABEL(status_), message.c_str());
  gtk_widget_set_sensitive(static_cast<GtkWidget *>(action_button_), TRUE);
#else
  (void)message;
#endif
}

void WalletWindow::show_prepared_mnemonic(const SensitiveBuffer &mnemonic) {
#if CITIZENSDK_ENABLE_WALLET_UI
  require(window_ != nullptr && mnemonic_ != nullptr &&
              mnemonic_scroll_ != nullptr && backup_ != nullptr &&
              action_button_ != nullptr && status_ != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK wallet window was destroyed before preparation completed");
  GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(mnemonic_));
  gtk_text_buffer_set_text(buffer, reinterpret_cast<const char *>(mnemonic.data()),
                           static_cast<int>(mnemonic.size()));
  gtk_text_view_set_editable(GTK_TEXT_VIEW(mnemonic_), FALSE);
  gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(mnemonic_), FALSE);
  gtk_widget_show(static_cast<GtkWidget *>(mnemonic_scroll_));
  gtk_widget_show(static_cast<GtkWidget *>(backup_));
  gtk_widget_hide(static_cast<GtkWidget *>(password_));
  gtk_widget_hide(static_cast<GtkWidget *>(confirmation_));
  gtk_button_set_label(GTK_BUTTON(action_button_), "确认备份并创建");
  gtk_widget_set_sensitive(static_cast<GtkWidget *>(action_button_), TRUE);
  gtk_label_set_text(GTK_LABEL(status_), "请离线备份助记词并确认。CitizenSDK 不会再次显示它。");
#else
  (void)mnemonic;
#endif
}

bool WalletWindow::backup_confirmed() const noexcept {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (window_ == nullptr || backup_ == nullptr) return false;
  return gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(backup_)) != FALSE;
#else
  return false;
#endif
}

SensitiveBuffer WalletWindow::take_mnemonic() {
#if !CITIZENSDK_ENABLE_WALLET_UI
  return {};
#else
  require(window_ != nullptr && mnemonic_ != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK wallet window is no longer available");
  GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(mnemonic_));
  GtkTextIter begin{}, end{};
  gtk_text_buffer_get_bounds(buffer, &begin, &end);
  GtkSecretText text{gtk_text_buffer_get_text(buffer, &begin, &end, FALSE), 0};
  text.size = text.value == nullptr ? 0 : std::strlen(text.value);
  require(text.size > 0 &&
              text.size <= input_limits::kMaximumUnlockPasswordBytes,
          CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "wallet mnemonic input is empty or too large");
  SensitiveBuffer result(reinterpret_cast<const uint8_t *>(text.value),
                         text.size);
  gtk_text_buffer_set_text(buffer, "", 0);
  return result;
#endif
}

SensitiveBuffer WalletWindow::take_password(bool require_confirmation) {
#if !CITIZENSDK_ENABLE_WALLET_UI
  (void)require_confirmation; return {};
#else
  require(window_ != nullptr && password_ != nullptr && confirmation_ != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK wallet window is no longer available");
  const char *first = gtk_entry_get_text(GTK_ENTRY(password_));
  require(first != nullptr, CITIZENSDK_ERROR_INTEGRITY,
          "wallet derivation password control is unavailable");
  const std::size_t size = first == nullptr ? 0 : std::strlen(first);
  require(size <= input_limits::kMaximumUnlockPasswordBytes,
          CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "wallet derivation password is too large");
  if (require_confirmation) {
    const char *second = gtk_entry_get_text(GTK_ENTRY(confirmation_));
    require(second != nullptr && std::strcmp(first, second) == 0,
            CITIZENSDK_ERROR_INVALID_ARGUMENT,
            "wallet derivation passwords do not match");
  }
  try {
    SensitiveBuffer result(reinterpret_cast<const uint8_t *>(first), size);
    gtk_entry_set_text(GTK_ENTRY(password_), "");
    gtk_entry_set_text(GTK_ENTRY(confirmation_), "");
    return result;
  } catch (...) {
    gtk_entry_set_text(GTK_ENTRY(password_), "");
    gtk_entry_set_text(GTK_ENTRY(confirmation_), "");
    throw;
  }
#endif
}

void WalletWindow::clear_secrets() noexcept {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (mnemonic_ != nullptr) {
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(mnemonic_));
    gtk_text_buffer_set_text(buffer, "", 0);
  }
  if (password_ != nullptr) gtk_entry_set_text(GTK_ENTRY(password_), "");
  if (confirmation_ != nullptr) gtk_entry_set_text(GTK_ENTRY(confirmation_), "");
#endif
}

bool WalletWindow::invoke(std::function<void()> action) noexcept {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (std::this_thread::get_id() == ui_thread_) {
    try { action(); return true; } catch (...) { return false; }
  }
  struct Invocation final {
    std::thread::id ui_thread;
    std::function<void()> action;
    unsigned wrong_thread_dispatches{};
  };
  GSource *source = g_idle_source_new();
  if (source == nullptr) return false;
  try {
    auto *invocation = new Invocation{ui_thread_, std::move(action), 0};
    g_source_set_callback(
        source,
        +[](gpointer context) noexcept -> gboolean {
          auto *invocation = static_cast<Invocation *>(context);
          if (std::this_thread::get_id() != invocation->ui_thread) {
            // A GMainContext can technically be acquired by a foreign thread.
            // Never execute or discard a GTK action there: retain the source
            // and retry it when the captured owner resumes dispatching. This
            // keeps terminal wallet ownership fail closed instead of silently
            // losing the only UI-thread cleanup action.
            if (++invocation->wrong_thread_dispatches >= 8) std::terminate();
            GSource *current = g_main_current_source();
            if (current != nullptr) {
              g_source_set_ready_time(
                  current, g_get_monotonic_time() + G_TIME_SPAN_MILLISECOND * 100);
            }
            return G_SOURCE_CONTINUE;
          }
          try { invocation->action(); } catch (...) { std::terminate(); }
          return G_SOURCE_REMOVE;
        },
        invocation,
        +[](gpointer context) noexcept {
          delete static_cast<Invocation *>(context);
        });
    const guint identity = g_source_attach(
        source, static_cast<GMainContext *>(ui_context_));
    if (identity == 0) g_source_destroy(source);
    g_source_unref(source);
    return identity != 0;
  } catch (...) {
    g_source_destroy(source);
    g_source_unref(source);
    return false;
  }
#else
  try { action(); return true; } catch (...) { return false; }
#endif
}

}  // namespace citizen_sdk::linux
