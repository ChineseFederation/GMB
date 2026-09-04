#ifndef CITIZENSDK_WINDOWS_OPERATION_HPP
#define CITIZENSDK_WINDOWS_OPERATION_HPP

#include <condition_variable>
#include <functional>
#include <mutex>
#include <unordered_set>
#include "citizensdk_types.h"

namespace citizen_sdk::windows {

class OperationTracker final {
 public:
  bool accept(uint64_t operation_id);
  void finish(uint64_t operation_id) noexcept;
  bool empty() const noexcept;

 private:
  mutable std::mutex lock_;
  std::unordered_set<uint64_t> pending_;
};

class RequestRouter final {
 public:
  /* Routing transfers ownership of every nonzero result handle to Handler
   * before invocation. Production handlers are noexcept and must release that
   * handle exactly once, including every failure path. */
  using Handler = std::function<void(citizensdk_result_handle_t)>;
  // There is exactly one SDK-owned wallet flow per Host. Prime its completion
  // handler before crossing into Core, then bind the returned request identity
  // without allocating after Core has accepted irreversible ownership.
  void prime(Handler handler);
  void bind(citizensdk_request_id_t request) noexcept;
  void cancel_primed() noexcept;
  Handler take(const citizensdk_event_t &event);
  bool empty() const noexcept;

 private:
  mutable std::mutex lock_;
  Handler handler_;
  citizensdk_request_id_t request_{};
  bool primed_{false};
};

// Serializes the short interval in which Core has accepted a request but has
// not yet returned its identity to the submitter. Core's dedicated dispatch
// thread waits here, preserving callback-thread affinity without a bounded
// event buffer. Tests can drive arbitrarily many waiters through this internal
// contract; production has one Core dispatch waiter per SDK instance.
class CompletionAdmission final {
 public:
  void begin();
  void publish_route() noexcept;
  void await_route(citizensdk_request_id_t request) noexcept;
  bool idle() const noexcept;

 private:
  mutable std::mutex lock_;
  std::condition_variable ready_;
  bool in_progress_{false};
};

}  // namespace citizen_sdk::windows

#endif
