import '../models/citizen_capability.dart';
import '../models/citizen_chain_state.dart';

sealed class CitizenSdkEvent {
  const CitizenSdkEvent({required this.sequence});

  final int sequence;
}

/// 历史已变化；通过现有历史查询读取最新快照，不携带账户秘密或借用能力版本。
final class CitizenSdkHistoryChanged extends CitizenSdkEvent {
  const CitizenSdkHistoryChanged({required super.sequence});
}

final class CitizenSdkLifecycleChanged extends CitizenSdkEvent {
  const CitizenSdkLifecycleChanged({
    required super.sequence,
    required this.lifecycle,
  });

  final CitizenSdkLifecycle lifecycle;
}

final class CitizenSdkCapabilitiesChanged extends CitizenSdkEvent {
  const CitizenSdkCapabilitiesChanged({
    required super.sequence,
    required this.snapshot,
  });

  final CitizenCapabilitySnapshot snapshot;
}

enum CitizenTransferProgressStatus {
  ready,
  broadcast,
  future,
  inBlock,
  finalized,
  retracted,
  finalityTimeout,
  dropped,
  invalid,
  usurped,
}

/// 一次高层转账请求的进度与终态观察事件。
///
/// [requestSequence] 只是当前 Dart session 的公开关联号，不是原生 request/result handle。
final class CitizenSdkTransferProgress extends CitizenSdkEvent {
  const CitizenSdkTransferProgress({
    required super.sequence,
    required this.requestSequence,
    required this.status,
    required this.block,
    required this.replacementHash,
    required this.peerCount,
  });

  final int requestSequence;
  final CitizenTransferProgressStatus status;
  final CitizenBlockRef? block;
  final String? replacementHash;
  final int peerCount;
}
