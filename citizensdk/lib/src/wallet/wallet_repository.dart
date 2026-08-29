import 'models.dart';

/// 钱包公开资料与清理计划的原子存储。
///
/// 实现必须以 [expectedRevision] 做 compare-and-swap；不匹配时抛
/// `WalletRepositoryConflict`。助记词、母种子、child mini-secret 和签名不得进入
/// 本仓储。
abstract interface class WalletRepository {
  Future<WalletState> load();

  Future<WalletState> commit({
    required int expectedRevision,
    required WalletProfile? profile,
    required WalletCleanupPlan? cleanup,
  });
}
