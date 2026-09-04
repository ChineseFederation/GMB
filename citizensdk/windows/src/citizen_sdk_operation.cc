#include "citizen_sdk_operation.hpp"

#include <exception>
#include <utility>
#include "citizen_sdk_host_record.hpp"

namespace citizen_sdk::windows {

bool OperationTracker::accept(uint64_t operation_id) {
  if (operation_id == 0) return false;
  std::lock_guard<std::mutex> guard(lock_);
  return pending_.insert(operation_id).second;
}

void OperationTracker::finish(uint64_t operation_id) noexcept {
  std::lock_guard<std::mutex> guard(lock_);
  pending_.erase(operation_id);
}

bool OperationTracker::empty() const noexcept {
  std::lock_guard<std::mutex> guard(lock_);
  return pending_.empty();
}

void RequestRouter::prime(Handler handler) {
  require(static_cast<bool>(handler),
          CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "CitizenSDK private request route is invalid");
  std::lock_guard<std::mutex> guard(lock_);
  if (primed_ || request_ != 0 || static_cast<bool>(handler_)) {
    throw HostError(CITIZENSDK_ERROR_CONFLICT,
                    "CitizenSDK private request route is already occupied");
  }
  handler_ = std::move(handler);
  primed_ = true;
}

void RequestRouter::bind(citizensdk_request_id_t request) noexcept {
  try {
    std::lock_guard<std::mutex> guard(lock_);
    if (!primed_ || !handler_ || request_ != 0 || request == 0) {
      std::terminate();
    }
    request_ = request;
    primed_ = false;
  } catch (...) {
    std::terminate();
  }
}

void RequestRouter::cancel_primed() noexcept {
  try {
    std::lock_guard<std::mutex> guard(lock_);
    if (!primed_ || request_ != 0) std::terminate();
    handler_ = {};
    primed_ = false;
  } catch (...) {
    std::terminate();
  }
}

RequestRouter::Handler RequestRouter::take(const citizensdk_event_t &event) {
  if (event.event_type != CITIZENSDK_EVENT_REQUEST_COMPLETED) return {};
  Handler handler;
  {
    std::lock_guard<std::mutex> guard(lock_);
    if (primed_ || request_ == 0 || request_ != event.request_id) return {};
    // std::function 移动后的源对象只保证有效，未保证变为空。
    // 与已空的本地 handler 交换，确保路由被消费后可关闭或接纳下一请求。
    handler.swap(handler_);
    request_ = 0;
  }
  return handler;
}

bool RequestRouter::empty() const noexcept {
  std::lock_guard<std::mutex> guard(lock_);
  return !primed_ && request_ == 0 && !handler_;
}

void CompletionAdmission::begin() {
  std::lock_guard<std::mutex> guard(lock_);
  require(!in_progress_,
          CITIZENSDK_ERROR_INTEGRITY,
          "CitizenSDK completion admission is already occupied");
  in_progress_ = true;
}

void CompletionAdmission::publish_route() noexcept {
  try {
    {
      std::lock_guard<std::mutex> guard(lock_);
      if (!in_progress_) std::terminate();
      in_progress_ = false;
    }
    ready_.notify_all();
  } catch (...) {
    std::terminate();
  }
}

void CompletionAdmission::await_route(
    citizensdk_request_id_t) noexcept {
  try {
    std::unique_lock<std::mutex> guard(lock_);
    ready_.wait(guard, [&] { return !in_progress_; });
  } catch (...) {
    std::terminate();
  }
}

bool CompletionAdmission::idle() const noexcept {
  try {
    std::lock_guard<std::mutex> guard(lock_);
    return !in_progress_;
  } catch (...) {
    std::terminate();
  }
}

}  // namespace citizen_sdk::windows
