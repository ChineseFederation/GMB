import 'models.dart';

/// 钱包公开资料与清理计划的原子存储。
///
/// 实现必须以 [expectedRevision] 做 compare-and-swap；不匹配时抛
/// `WalletRepositoryConflict`。助记词、母种子、child mini-secret 和签名不得进入
/// 本仓储。同一 Dart isolate 内、指向同一逻辑存储的全部实现实例
/// 必须共享同一条 mutation 队列，禁止各实例分别加锁后形成可同时
/// 通过的伪 CAS；跨 isolate / 进程的原子性只有在底层存储另有保证
/// 时才成立。
///
/// [commit] 只有在写入后完整回读并确认 revision、profile 与 cleanup
/// 全部等于目标状态时才能成功返回。底层写调用可能已经提交却随后
/// 抛错；此时实现必须回读收敛：回读精确等于目标状态就按成功返回，
/// 否则保留失败，禁止调用方误回滚已经提交的事实。
abstract interface class WalletRepository {
  /// 读取底层当前完整状态，不得返回仅存在于实现内存中的候选值。
  Future<WalletState> load();

  /// 以 [expectedRevision] 原子提交并返回写后回读确认的完整状态。
  Future<WalletState> commit({
    required int expectedRevision,
    required WalletProfile? profile,
    required WalletCleanupPlan? cleanup,
  });
}
