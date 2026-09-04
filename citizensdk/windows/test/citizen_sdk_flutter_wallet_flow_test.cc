#include <cassert>
#include <functional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include "citizen_sdk_flutter_wallet_flow.hpp"
#include "citizen_sdk_flutter_test_support.hpp"

#ifdef NDEBUG
#error "CitizenSDK Flutter wallet-flow contract assertions must remain enabled"
#endif

using citizen_sdk::WalletFlowKind;
using citizen_sdk::WalletFlowResult;
using citizen_sdk::WalletFlowStatus;
using citizen_sdk::flutter::DecodedRequest;
using citizen_sdk::flutter::FlutterWalletFlows;
using citizen_sdk::flutter::Method;

int main() {
  std::vector<std::function<void()>> queue;
  FlutterWalletFlows flows([&](std::function<void()> work) {
    queue.push_back(std::move(work));
  });

  DecodedRequest create;
  create.method = Method::create_wallet;
  create.session = "session-a";
  create.sequence = 1;
  create.word_count = 24;
  auto contract = FlutterWalletFlows::contract(create);
  assert(contract.kind == WalletFlowKind::Create && contract.word_count == 24);

  int completions = 0;
  // Deliberately complete before the presenter returns. The production bridge
  // must have preallocated the route and must settle it exactly once.
  flows.launch(create,
    [](const auto &request, auto completion) {
      assert(request.kind == WalletFlowKind::Create);
      completion({WalletFlowStatus::Completed, CITIZENSDK_OK});
      completion({WalletFlowStatus::Failed, CITIZENSDK_ERROR_INTERNAL});
      return [] {};
    },
    [&](WalletFlowResult result) {
      ++completions;
      assert(result.status == WalletFlowStatus::Completed);
    });
  assert(completions == 1);
  assert(flows.active_count() == 0);
  for (auto &work : queue) work();
  assert(completions == 1);

  DecodedRequest imported;
  imported.method = Method::import_wallet;
  imported.session = "session-b";
  imported.sequence = 9;
  bool cancelled = false;
  citizen_sdk::WalletFlowCompletion late;
  flows.launch(imported,
    [&](const auto &request, auto completion) {
      assert(request.kind == WalletFlowKind::Import);
      late = std::move(completion);
      return [&] { cancelled = true; };
    },
    [&](WalletFlowResult result) {
      ++completions;
      assert(result.status == WalletFlowStatus::Cancelled);
    });
  flows.cancel_session("session-b");
  assert(cancelled);
  assert(flows.active_count() == 1);  // cancel is not a terminal promise
  late({WalletFlowStatus::Cancelled, CITIZENSDK_OK});
  assert(completions == 1);
  assert(!queue.empty());
  queue.back()();
  assert(completions == 2 && flows.active_count() == 0);

  DecodedRequest add;
  add.method = Method::add_wallet_accounts;
  add.indices = {1, 1989};
  contract = FlutterWalletFlows::contract(add);
  assert(contract.kind == WalletFlowKind::AddAccounts);
  assert(contract.account_indices == add.indices);

  auto invalid = create;
  invalid.word_count = 15;
  citizen_sdk::flutter::test::expect_failure(
      [&] { (void)FlutterWalletFlows::contract(invalid); }, CITIZENSDK_ERROR_INVALID_ARGUMENT);
  invalid = create;
  invalid.method = Method::sign_wallet_payload;
  citizen_sdk::flutter::test::expect_failure(
      [&] { (void)FlutterWalletFlows::contract(invalid); }, CITIZENSDK_ERROR_INVALID_ARGUMENT);

  // presenter 拒绝发生在接纳之前，不能留下 active entry 或伪造一次完成。
  bool presenter_failed = false;
  try {
    flows.launch(create,
      [](const auto &, auto) -> citizen_sdk::flutter::WalletCancellation {
        throw std::runtime_error("synthetic presenter rejection");
      }, [](WalletFlowResult) { assert(false); });
  } catch (const std::runtime_error &) { presenter_failed = true; }
  assert(presenter_failed && flows.active_count() == 0);

  // 接纳期间同步请求取消：cancel capability 尚未返回也必须记住请求，不能丢掉。
  citizen_sdk::WalletFlowCompletion waiting;
  int native_cancellations = 0;
  flows.launch(create,
    [&](const auto &, auto completion) {
      waiting = std::move(completion);
      flows.cancel_session(create.session);
      return [&] { ++native_cancellations; };
    }, [&](WalletFlowResult result) {
      assert(result.status == WalletFlowStatus::Cancelled);
      ++completions;
    });
  assert(native_cancellations == 1 && flows.active_count() == 1);
  waiting({WalletFlowStatus::Cancelled, CITIZENSDK_ERROR_AUTHENTICATION_CANCELLED});
  flows.drain();
  assert(completions == 3 && flows.active_count() == 0);

  // 取消调用失败不是流程完成；真实晚结果仍恰好结算一次且允许 completion 重入。
  flows.launch(create,
    [&](const auto &, auto completion) {
      waiting = std::move(completion);
      return [] { throw std::runtime_error("synthetic cancel failure"); };
    }, [&](WalletFlowResult result) {
      assert(result.status == WalletFlowStatus::Cancelled && flows.active_count() == 0);
      ++completions;
      flows.launch(create,
        [](const auto &, auto completion) {
          completion({WalletFlowStatus::Completed, CITIZENSDK_OK});
          return [] {};
        }, [&](WalletFlowResult inner) {
          assert(inner.status == WalletFlowStatus::Completed);
          ++completions;
        });
    });
  bool cancel_failed = false;
  try { flows.cancel_session(create.session); }
  catch (const std::runtime_error &) { cancel_failed = true; }
  assert(cancel_failed && flows.active_count() == 1);
  waiting({WalletFlowStatus::Cancelled, CITIZENSDK_ERROR_CANCELLED});
  flows.drain();
  waiting({WalletFlowStatus::Completed, CITIZENSDK_OK});
  flows.drain();
  assert(completions == 5 && flows.active_count() == 0);

  citizen_sdk::flutter::test::FiniteScheduler recovering_queue;
  FlutterWalletFlows recovering(recovering_queue.scheduler());
  citizen_sdk::WalletFlowCompletion recover_result;
  int recovered = 0;
  recovering.launch(create,
    [&](const auto &, auto completion) {
      recover_result = std::move(completion);
      return [] {};
    }, [&](WalletFlowResult result) {
      assert(result.status == WalletFlowStatus::Completed);
      ++recovered;
    });
  recovering_queue.fail_next();
  recover_result({WalletFlowStatus::Completed, CITIZENSDK_OK});
  assert(recovered == 0 && recovering.active_count() == 1);
  recovering.drain();
  assert(recovered == 1 && recovering.active_count() == 0);

  // No secret-bearing field exists in either the decoded public request or
  // wallet contract; import receives all secrets only inside Host-owned Win32.
  static_assert(sizeof(citizen_sdk::WalletFlowRequest) < 128);
  return 0;
}
