#include "citizen_sdk_gtk_parent.hpp"

#include <exception>
#include <mutex>
#include <utility>
#include "citizen_sdk_host_record.hpp"

#if CITIZENSDK_ENABLE_WALLET_UI
#include <gtk/gtk.h>
#endif

namespace citizen_sdk::linux {

struct GtkParentRef::Impl final {
  std::mutex lock;
#if CITIZENSDK_ENABLE_WALLET_UI
  GWeakRef weak{};
  bool initialized{false};
#endif
};

GtkParentLease::GtkParentLease(void *window,
                               std::thread::id ui_thread) noexcept
    : window_(window), ui_thread_(ui_thread) {}

GtkParentLease::GtkParentLease(GtkParentLease &&other) noexcept
    : window_(other.window_), ui_thread_(other.ui_thread_) {
  other.window_ = nullptr;
}

GtkParentLease &GtkParentLease::operator=(GtkParentLease &&other) noexcept {
  if (this != &other) {
    clear();
    window_ = other.window_;
    ui_thread_ = other.ui_thread_;
    other.window_ = nullptr;
  }
  return *this;
}

GtkParentLease::~GtkParentLease() { clear(); }

void GtkParentLease::clear() noexcept {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (window_ != nullptr) {
    if (std::this_thread::get_id() != ui_thread_) std::terminate();
    g_object_unref(window_);
    window_ = nullptr;
  }
#else
  window_ = nullptr;
#endif
}

GtkParentRef::GtkParentRef(void *window, std::thread::id ui_thread)
    : impl_(std::make_unique<Impl>()), ui_thread_(ui_thread) {
#if CITIZENSDK_ENABLE_WALLET_UI
  g_weak_ref_init(&impl_->weak, nullptr);
  impl_->initialized = true;
#endif
  const citizensdk_error_code_t code = set(window);
  if (code != CITIZENSDK_OK) {
    throw HostError(code, "CitizenSDK GTK parent window is invalid");
  }
}

GtkParentRef::~GtkParentRef() {
#if CITIZENSDK_ENABLE_WALLET_UI
  if (impl_ && impl_->initialized) {
    std::lock_guard<std::mutex> guard(impl_->lock);
    g_weak_ref_clear(&impl_->weak);
    impl_->initialized = false;
  }
#endif
}

citizensdk_error_code_t GtkParentRef::set(void *window) noexcept {
  if (!on_ui_thread()) return CITIZENSDK_ERROR_BUSY;
#if !CITIZENSDK_ENABLE_WALLET_UI
  return window == nullptr ? CITIZENSDK_OK : CITIZENSDK_ERROR_UNSUPPORTED;
#else
  if (window != nullptr &&
      (!GTK_IS_WINDOW(window) ||
       gtk_widget_in_destruction(GTK_WIDGET(window)))) {
    return CITIZENSDK_ERROR_INVALID_ARGUMENT;
  }
  try {
    std::lock_guard<std::mutex> guard(impl_->lock);
    g_weak_ref_set(&impl_->weak,
                   window == nullptr ? nullptr : G_OBJECT(window));
    return CITIZENSDK_OK;
  } catch (...) {
    return CITIZENSDK_ERROR_INTERNAL;
  }
#endif
}

GtkParentLease GtkParentRef::acquire() const noexcept {
  if (!on_ui_thread()) return {};
#if !CITIZENSDK_ENABLE_WALLET_UI
  return {};
#else
  try {
    std::lock_guard<std::mutex> guard(impl_->lock);
    GObject *object = static_cast<GObject *>(g_weak_ref_get(&impl_->weak));
    if (object == nullptr) return {};
    if (!GTK_IS_WINDOW(object) ||
        gtk_widget_in_destruction(GTK_WIDGET(object))) {
      g_object_unref(object);
      return {};
    }
    return GtkParentLease(object, ui_thread_);
  } catch (...) {
    return {};
  }
#endif
}

bool GtkParentRef::on_ui_thread() const noexcept {
  return std::this_thread::get_id() == ui_thread_;
}

}  // namespace citizen_sdk::linux
