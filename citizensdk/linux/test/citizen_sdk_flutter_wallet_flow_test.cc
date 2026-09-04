#include <cassert>
#include <functional>
#include <string>
#include <utility>
#include <vector>

#include "citizen_sdk_flutter_wallet_flow.hpp"

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

  // No secret-bearing field exists in either the decoded public request or
  // wallet contract; import receives all secrets only inside Host-owned GTK.
  static_assert(sizeof(citizen_sdk::WalletFlowRequest) < 128);
  return 0;
}
