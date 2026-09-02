import '../models/citizen_capability.dart';
import '../models/citizen_chain_state.dart';

/// 经过 CitizenSDK Core 验证的类型化公民链读取接口。
///
/// 这里没有任意 RPC 入口，应用不能绕过 finalized/runtime 安全语义。
abstract interface class CitizenChain {
  Future<CitizenCapabilitySnapshot> getCapabilities();

  Future<CitizenBlockRef> getFinalizedHead();

  Future<CitizenAccountBalance> getAccountBalance(String accountId);

  Future<CitizenAccountNonce> getAccountNonce(String accountId);

  Future<CitizenFeeSnapshot> getFeeSnapshot();
}
