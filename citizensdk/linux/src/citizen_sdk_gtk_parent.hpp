#ifndef CITIZENSDK_LINUX_GTK_PARENT_HPP
#define CITIZENSDK_LINUX_GTK_PARENT_HPP

#include <memory>
#include <thread>
#include "citizensdk_types.h"

namespace citizen_sdk::linux {

// A short-lived strong GTK reference. It is created and destroyed only on the
// Host's captured UI thread so GTK widget finalization can never migrate to a
// Core worker.
class GtkParentLease final {
 public:
  GtkParentLease() = default;
  GtkParentLease(void *window, std::thread::id ui_thread) noexcept;
  GtkParentLease(const GtkParentLease &) = delete;
  GtkParentLease &operator=(const GtkParentLease &) = delete;
  GtkParentLease(GtkParentLease &&other) noexcept;
  GtkParentLease &operator=(GtkParentLease &&other) noexcept;
  ~GtkParentLease();

  void *get() const noexcept { return window_; }
  explicit operator bool() const noexcept { return window_ != nullptr; }

 private:
  void clear() noexcept;
  void *window_{};
  std::thread::id ui_thread_{};
};

// Host parent windows are never retained as raw pointers. GWeakRef removes the
// reference automatically when the embedding application destroys its window;
// acquire() temporarily promotes it only while CitizenSDK creates a child UI.
class GtkParentRef final {
 public:
  GtkParentRef(void *window, std::thread::id ui_thread);
  GtkParentRef(const GtkParentRef &) = delete;
  GtkParentRef &operator=(const GtkParentRef &) = delete;
  ~GtkParentRef();

  citizensdk_error_code_t set(void *window) noexcept;
  GtkParentLease acquire() const noexcept;
  bool on_ui_thread() const noexcept;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
  std::thread::id ui_thread_;
};

}  // namespace citizen_sdk::linux

#endif
