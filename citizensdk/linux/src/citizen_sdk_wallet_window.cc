#include "citizen_sdk_wallet_window.hpp"

#include <charconv>
#include <cstring>
#include <exception>
#include <sstream>
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

// 仅把当前末词前缀交给 Rust 官方词表；候选是公开数据，原输入缓冲随即清零。
std::string complete_last_word(const char *text, std::size_t size) {
  std::size_t begin = size;
  while (begin != 0 && text[begin - 1] != ' ' && text[begin - 1] != '\n' &&
         text[begin - 1] != '\t') --begin;
  if (begin == size) return {};
  for (std::size_t index = begin; index < size; ++index) {
    if (text[index] < 'a' || text[index] > 'z') return {};
  }
  const citizensdk_bytes_view_t prefix{
      reinterpret_cast<const uint8_t *>(text + begin), size - begin};
  uint64_t required = 0;
  if (citizensdk_wallet_word_suggestions(prefix, nullptr, 0, &required) !=
          CITIZENSDK_OK || required == 0 || required > 256) return {};
  std::string result(static_cast<std::size_t>(required), '\0');
  if (citizensdk_wallet_word_suggestions(
          prefix, reinterpret_cast<uint8_t *>(result.data()), result.size(),
          &required) != CITIZENSDK_OK || required != result.size()) return {};
  for (char &value : result) if (value == '\n') value = ' ';
  return result;
}

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
      "CitizenSDK 钱包", static_cast<GtkWindow *>(parent),
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

  mnemonic_state_ = gtk_label_new("当前 0 / 选择 12；校验和尚未通过");
  gtk_label_set_xalign(GTK_LABEL(mnemonic_state_), 0.0F);
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(mnemonic_state_), FALSE, FALSE, 0);
  suggestions_ = gtk_combo_box_text_new();
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(suggestions_), FALSE, FALSE, 0);
  suggestion_apply_ = gtk_button_new_with_label("使用所选离线词表候选");
  gtk_widget_set_sensitive(static_cast<GtkWidget *>(suggestion_apply_), FALSE);
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(suggestion_apply_), FALSE, FALSE, 0);

  word_count_ = gtk_combo_box_text_new();
  for (const char *count : {"12", "18", "24"}) {
    gtk_combo_box_text_append(GTK_COMBO_BOX_TEXT(word_count_), count, count);
  }
  const std::string initial_words = std::to_string(
      request.word_count == 0 ? CITIZENSDK_WALLET_WORDS_12 : request.word_count);
  require(gtk_combo_box_set_active_id(GTK_COMBO_BOX(word_count_),
                                      initial_words.c_str()) != FALSE,
          CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "CitizenSDK wallet word count is unsupported");
  gtk_box_pack_start(GTK_BOX(box), gtk_label_new("助记词数量"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(word_count_), FALSE, FALSE, 0);

  password_ = gtk_entry_new();
  gtk_entry_set_visibility(GTK_ENTRY(password_), FALSE);
  gtk_entry_set_input_purpose(GTK_ENTRY(password_), GTK_INPUT_PURPOSE_PASSWORD);
  gtk_box_pack_start(GTK_BOX(box), gtk_label_new("钱包密码（选填）"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(password_), FALSE, FALSE, 0);
  gtk_entry_set_placeholder_text(GTK_ENTRY(password_), "钱包密码（选填）");

  next_account_ = gtk_check_button_new_with_label("自动添加下一个可用账户索引");
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(next_account_), FALSE, FALSE, 0);
  account_indices_ = gtk_entry_new();
  gtk_entry_set_placeholder_text(GTK_ENTRY(account_indices_), "指定账户索引，例如 1,2,3");
  std::ostringstream initial_indices;
  for (std::size_t index = 0; index < request.account_indices.size(); ++index) {
    if (index != 0) initial_indices << ',';
    initial_indices << request.account_indices[index];
  }
  gtk_entry_set_text(GTK_ENTRY(account_indices_), initial_indices.str().c_str());
  gtk_box_pack_start(GTK_BOX(box), static_cast<GtkWidget *>(account_indices_), FALSE, FALSE, 0);
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
    gtk_widget_hide(static_cast<GtkWidget *>(backup_));
    gtk_button_set_label(GTK_BUTTON(action_button_),
                         request.kind == CITIZENSDK_WALLET_FLOW_IMPORT ? "导入钱包" : "添加账户");
    gtk_label_set_text(GTK_LABEL(status_),
                       "助记词与钱包密码只在本机 CitizenSDK 原生界面和 Rust Core 内使用。");
  }
  if (request.kind != CITIZENSDK_WALLET_FLOW_ADD_ACCOUNTS) {
    gtk_widget_hide(static_cast<GtkWidget *>(next_account_));
    gtk_widget_hide(static_cast<GtkWidget *>(account_indices_));
  }
  g_signal_connect(gtk_text_view_get_buffer(GTK_TEXT_VIEW(mnemonic_)), "changed",
      G_CALLBACK((+[](GtkTextBuffer *buffer, gpointer data) {
        try {
          auto *self = static_cast<WalletWindow *>(data);
          if (self->suggestions_ == nullptr) return;
          GtkTextIter begin{}, end{};
          gtk_text_buffer_get_bounds(buffer, &begin, &end);
          GtkTextIter cursor{};
          gtk_text_buffer_get_iter_at_mark(buffer, &cursor,
                                           gtk_text_buffer_get_insert(buffer));
          GtkTextIter selection_begin{}, selection_end{};
          const bool has_selection = gtk_text_buffer_get_selection_bounds(
              buffer, &selection_begin, &selection_end) != FALSE;
          GtkSecretText text{gtk_text_buffer_get_text(buffer, &begin, &end, FALSE), 0};
          text.size = text.value == nullptr ? 0 : std::strlen(text.value);
          uint32_t word_total = 0;
          bool separated = true;
          for (std::size_t index = 0; index < text.size; ++index) {
            const bool whitespace = text.value[index] == ' ' || text.value[index] == '\n' ||
                                    text.value[index] == '\t' || text.value[index] == '\r';
            if (!whitespace && separated) ++word_total;
            separated = whitespace;
          }
          const citizensdk_wallet_word_count_t selected = self->word_count();
          const bool checksum = word_total == selected && text.value != nullptr &&
              citizensdk_validate_wallet_mnemonic(
                  {reinterpret_cast<const uint8_t *>(text.value), text.size},
                  selected) == CITIZENSDK_OK;
          const std::string state = "当前 " + std::to_string(word_total) + " / 选择 " +
              std::to_string(selected) + (checksum ? "；校验和有效" : "；校验和尚未通过");
          gtk_label_set_text(GTK_LABEL(self->mnemonic_state_), state.c_str());
          const std::string candidates =
              text.value == nullptr || has_selection ||
                      !gtk_text_iter_equal(&cursor, &end) ? std::string{} :
              complete_last_word(text.value, text.size);
          gtk_combo_box_text_remove_all(GTK_COMBO_BOX_TEXT(self->suggestions_));
          std::istringstream candidate_stream(candidates);
          for (std::string word; candidate_stream >> word;)
            gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(self->suggestions_), word.c_str());
          if (!candidates.empty()) gtk_combo_box_set_active(GTK_COMBO_BOX(self->suggestions_), 0);
          gtk_widget_set_sensitive(static_cast<GtkWidget *>(self->suggestion_apply_),
                                   !candidates.empty());
        } catch (...) {}
      })), this);
  g_signal_connect(suggestion_apply_, "clicked",
      G_CALLBACK((+[](GtkButton *, gpointer data) {
        auto *self = static_cast<WalletWindow *>(data);
        if (self->mnemonic_ == nullptr || self->suggestions_ == nullptr) return;
        gchar *word = gtk_combo_box_text_get_active_text(
            GTK_COMBO_BOX_TEXT(self->suggestions_));
        if (word == nullptr) return;
        GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(self->mnemonic_));
        GtkTextIter end{}, cursor{}, selection_begin{}, selection_end{};
        gtk_text_buffer_get_end_iter(buffer, &end);
        gtk_text_buffer_get_iter_at_mark(buffer, &cursor, gtk_text_buffer_get_insert(buffer));
        const bool has_selection = gtk_text_buffer_get_selection_bounds(
            buffer, &selection_begin, &selection_end) != FALSE;
        if (!has_selection && gtk_text_iter_equal(&cursor, &end)) {
          GtkTextIter begin = end;
          while (gtk_text_iter_backward_char(&begin)) {
            const gunichar value = gtk_text_iter_get_char(&begin);
            if (g_unichar_isspace(value)) { gtk_text_iter_forward_char(&begin); break; }
          }
          gtk_text_buffer_delete(buffer, &begin, &end);
          gtk_text_buffer_insert_at_cursor(buffer, word, -1);
        }
        g_free(word);
      })), this);
  g_signal_connect(word_count_, "changed", G_CALLBACK((+[](GtkComboBox *, gpointer data) {
    auto *self = static_cast<WalletWindow *>(data);
    if (self->mnemonic_ != nullptr)
      g_signal_emit_by_name(gtk_text_view_get_buffer(GTK_TEXT_VIEW(self->mnemonic_)),
                            "changed");
  })), this);
  g_signal_connect(next_account_, "toggled",
      G_CALLBACK((+[](GtkToggleButton *button, gpointer data) {
        auto *self = static_cast<WalletWindow *>(data);
        if (self->account_indices_ != nullptr) {
          gtk_widget_set_sensitive(static_cast<GtkWidget *>(self->account_indices_),
              gtk_toggle_button_get_active(button) == FALSE);
        }
      })), this);
  g_signal_connect(action_button_, "clicked", G_CALLBACK((+[](GtkButton *, gpointer data) {
    try { static_cast<WalletWindow *>(data)->action_(); } catch (...) {}
  })), this);
  g_signal_connect(dialog, "response", G_CALLBACK((+[](GtkDialog *, gint response, gpointer data) {
    try {
      auto *self = static_cast<WalletWindow *>(data);
      if (response == GTK_RESPONSE_CANCEL ||
          response == GTK_RESPONSE_DELETE_EVENT) {
        self->cancel_();
      }
    } catch (...) {}
  })), this);
  g_signal_connect(dialog, "delete-event", G_CALLBACK(delete_requested), &cancel_);
  g_signal_connect(dialog, "destroy", G_CALLBACK((+[](GtkWidget *widget,
                                                      gpointer data) noexcept {
    auto *self = static_cast<WalletWindow *>(data);
    try {
      if (self->window_ != widget) return;
      self->clear_secrets();
      const bool notify_cancel = !self->destroying_;
      self->window_ = nullptr;
      self->mnemonic_scroll_ = nullptr;
      self->mnemonic_ = nullptr;
      self->mnemonic_state_ = nullptr;
      self->suggestions_ = nullptr;
      self->suggestion_apply_ = nullptr;
      self->word_count_ = nullptr;
      self->password_ = nullptr;
      self->next_account_ = nullptr;
      self->account_indices_ = nullptr;
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
  })), this);
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
    gtk_widget_hide(static_cast<GtkWidget *>(mnemonic_state_));
    gtk_widget_hide(static_cast<GtkWidget *>(suggestions_));
    gtk_widget_hide(static_cast<GtkWidget *>(suggestion_apply_));
    gtk_widget_hide(static_cast<GtkWidget *>(backup_));
  } else {
    gtk_widget_hide(static_cast<GtkWidget *>(backup_));
  }
  if (kind_ != CITIZENSDK_WALLET_FLOW_ADD_ACCOUNTS) {
    gtk_widget_hide(static_cast<GtkWidget *>(next_account_));
    gtk_widget_hide(static_cast<GtkWidget *>(account_indices_));
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
  // 错误重试若仍为空，必须由用户明确确认，不能把清空/未输入静默当作选择。
  password_reentry_required_ = true;
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
  gtk_widget_show(static_cast<GtkWidget *>(mnemonic_state_));
  gtk_widget_show(static_cast<GtkWidget *>(backup_));
  gtk_widget_hide(static_cast<GtkWidget *>(password_));
  gtk_widget_hide(static_cast<GtkWidget *>(word_count_));
  gtk_widget_hide(static_cast<GtkWidget *>(suggestions_));
  gtk_widget_hide(static_cast<GtkWidget *>(suggestion_apply_));
  gtk_widget_hide(static_cast<GtkWidget *>(next_account_));
  gtk_widget_hide(static_cast<GtkWidget *>(account_indices_));
  gtk_button_set_label(GTK_BUTTON(action_button_), "确认备份并创建");
  gtk_widget_set_sensitive(static_cast<GtkWidget *>(action_button_), TRUE);
  gtk_label_set_text(GTK_LABEL(status_),
      "请断网抄写并在离线安全位置核对助记词。热钱包不保存助记词，关闭后无法再次显示。若使用了非空钱包密码，还必须单独记住；不同密码会得到不同账户。设备 TPM 认证是独立的金库保护，不是钱包密码。");
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

citizensdk_wallet_word_count_t WalletWindow::word_count() const {
#if !CITIZENSDK_ENABLE_WALLET_UI
  return CITIZENSDK_WALLET_WORDS_12;
#else
  require(window_ != nullptr && word_count_ != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK wallet word count control is unavailable");
  const char *selected = gtk_combo_box_get_active_id(GTK_COMBO_BOX(word_count_));
  require(selected != nullptr, CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "请选择 12、18 或 24 个助记词");
  citizensdk_wallet_word_count_t count = 0;
  if (std::strcmp(selected, "12") == 0) count = CITIZENSDK_WALLET_WORDS_12;
  if (std::strcmp(selected, "18") == 0) count = CITIZENSDK_WALLET_WORDS_18;
  if (std::strcmp(selected, "24") == 0) count = CITIZENSDK_WALLET_WORDS_24;
  input_limits::validate_word_count(count);
  return count;
#endif
}

bool WalletWindow::use_next_account() const noexcept {
#if CITIZENSDK_ENABLE_WALLET_UI
  return window_ != nullptr && next_account_ != nullptr &&
      gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(next_account_)) != FALSE;
#else
  return false;
#endif
}

std::vector<uint32_t> WalletWindow::account_indices() const {
#if !CITIZENSDK_ENABLE_WALLET_UI
  return {};
#else
  require(window_ != nullptr && account_indices_ != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK account index control is unavailable");
  const char *text = gtk_entry_get_text(GTK_ENTRY(account_indices_));
  require(text != nullptr, CITIZENSDK_ERROR_INTEGRITY,
          "CitizenSDK account index control is unavailable");
  std::vector<uint32_t> values;
  const char *cursor = text;
  while (*cursor != '\0') {
    const char *end = cursor;
    while (*end != '\0' && *end != ',') ++end;
    uint32_t value = 0;
    const auto parsed = std::from_chars(cursor, end, value);
    require(parsed.ec == std::errc{} && parsed.ptr == end,
            CITIZENSDK_ERROR_INVALID_ARGUMENT,
            "指定账户索引必须是以逗号分隔的 1...1989 整数");
    values.push_back(value);
    if (*end == ',') {
      require(end[1] != '\0', CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "指定账户索引不能以逗号结尾");
      cursor = end + 1;
    } else {
      cursor = end;
    }
  }
  input_limits::validate_wallet_indices(values.data(),
      static_cast<uint32_t>(values.size()));
  return values;
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
  // 先清控件，再校验副本；任何错误重试都不复用上一次秘密输入。
  gtk_text_buffer_set_text(buffer, "", 0);
  require(text.size > 0 &&
              text.size <= input_limits::kMaximumUnlockPasswordBytes,
          CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "wallet mnemonic input is empty or too large");
  SensitiveBuffer result(reinterpret_cast<const uint8_t *>(text.value),
                         text.size);
  return result;
#endif
}

SensitiveBuffer WalletWindow::take_password() {
#if !CITIZENSDK_ENABLE_WALLET_UI
  return {};
#else
  require(window_ != nullptr && password_ != nullptr,
          CITIZENSDK_ERROR_UNAVAILABLE,
          "CitizenSDK wallet window is no longer available");
  const char *first = gtk_entry_get_text(GTK_ENTRY(password_));
  require(first != nullptr, CITIZENSDK_ERROR_INTEGRITY,
          "wallet derivation password control is unavailable");
  const std::size_t size = first == nullptr ? 0 : std::strlen(first);
  if (size > input_limits::kMaximumUnlockPasswordBytes) {
    gtk_entry_set_text(GTK_ENTRY(password_), "");
    throw HostError(CITIZENSDK_ERROR_INVALID_ARGUMENT,
                    "wallet password is too large");
  }
  try {
    SensitiveBuffer result(reinterpret_cast<const uint8_t *>(first), size);
    gtk_entry_set_text(GTK_ENTRY(password_), "");
    const citizensdk_error_code_t validation = citizensdk_validate_wallet_password(
        {result.data(), static_cast<uint64_t>(result.size())});
    require(validation == CITIZENSDK_OK, validation,
            "钱包密码不符合 CitizenSDK 派生规则");
    if (!result.empty()) {
      if (kind_ != CITIZENSDK_WALLET_FLOW_ADD_ACCOUNTS) {
        GtkWidget *dialog = gtk_message_dialog_new(
            GTK_WINDOW(window_), GTK_DIALOG_MODAL, GTK_MESSAGE_WARNING,
            GTK_BUTTONS_YES_NO,
            "非空钱包密码不会被保存；忘记它或输入不同密码会得到不同账户。是否继续？");
        const gint response = gtk_dialog_run(GTK_DIALOG(dialog));
        gtk_widget_destroy(dialog);
        require(window_ != nullptr && password_ != nullptr,
                CITIZENSDK_ERROR_UNAVAILABLE,
                "钱包窗口已在风险确认期间关闭");
        require(response == GTK_RESPONSE_YES,
                CITIZENSDK_ERROR_INVALID_ARGUMENT,
                "已取消使用非空钱包密码");
      }
    } else if (password_reentry_required_) {
      GtkWidget *dialog = gtk_message_dialog_new(
          GTK_WINDOW(window_), GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION,
          GTK_BUTTONS_YES_NO,
          "当前钱包密码为空。确认本次明确使用空钱包密码继续重试？");
      const gint response = gtk_dialog_run(GTK_DIALOG(dialog));
      gtk_widget_destroy(dialog);
      require(window_ != nullptr && password_ != nullptr,
              CITIZENSDK_ERROR_UNAVAILABLE,
              "钱包窗口已在空密码确认期间关闭");
      require(response == GTK_RESPONSE_YES,
              CITIZENSDK_ERROR_INVALID_ARGUMENT,
              "请重新输入钱包密码，或明确确认使用空钱包密码");
    }
    password_reentry_required_ = false;
    return result;
  } catch (...) {
    if (password_ != nullptr) gtk_entry_set_text(GTK_ENTRY(password_), "");
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
