import 'package:meta/meta.dart';

/// 公民链轻节点生命周期状态。
enum ChainHealthStatus {
  uninitialized,
  starting,
  syncing,
  operational,
  degraded,
  offline,
  disposed,
}

/// 面向宿主应用的只读健康快照。
@immutable
final class ChainHealthSnapshot {
  const ChainHealthSnapshot({
    required this.status,
    required this.peerCount,
    required this.isUsable,
    required this.currentVerifiedFinalizedBlockNumber,
    required this.currentVerifiedFinalizedBlockHash,
    this.bestBlockNumber,
    this.bestBlockHash,
    this.lastError,
  });

  const ChainHealthSnapshot.uninitialized()
    : status = ChainHealthStatus.uninitialized,
      peerCount = 0,
      isUsable = false,
      currentVerifiedFinalizedBlockNumber = 0,
      currentVerifiedFinalizedBlockHash = '',
      bestBlockNumber = null,
      bestBlockHash = null,
      lastError = null;

  final ChainHealthStatus status;
  final int peerCount;
  final bool isUsable;
  final int currentVerifiedFinalizedBlockNumber;
  final String currentVerifiedFinalizedBlockHash;
  final int? bestBlockNumber;
  final String? bestBlockHash;
  final String? lastError;
}
