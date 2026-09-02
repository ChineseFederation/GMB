import 'dart:typed_data';

import 'citizen_chain_state.dart';

enum CitizenTransferResolution {
  finalizedSuccess,
  finalizedFailed,
  poolRejected,
}

enum CitizenExecutionStatus { success, failed }

/// finalized 块中与确切 extrinsic index 对应的 Runtime 执行结论。
final class CitizenExecution {
  const CitizenExecution({
    required this.status,
    required this.block,
    required this.extrinsicIndex,
    required this.dispatchVariant,
    required this.palletIndex,
    required this.errorIndex,
  });

  final CitizenExecutionStatus status;
  final CitizenBlockRef block;
  final int extrinsicIndex;
  final int? dispatchVariant;
  final int? palletIndex;
  final int? errorIndex;
}

/// 高层钱包转账的唯一终态；不会携带已签名 extrinsic。
final class CitizenWalletTransfer {
  const CitizenWalletTransfer({
    required this.transactionHash,
    required this.resolution,
    required this.execution,
    required this.poolRejectionReason,
  });

  final String transactionHash;
  final CitizenTransferResolution resolution;
  final CitizenExecution? execution;
  final String? poolRejectionReason;
}

enum CitizenHistoryStatus {
  pending,
  inBlock,
  poolRejected,
  finalizedSuccess,
  finalizedFailed,
}

final class CitizenHistoryCursor {
  const CitizenHistoryCursor({
    required this.accountId,
    required this.trackingStartBlock,
    required this.lastSyncedBlock,
  });

  final String accountId;
  final CitizenBlockRef trackingStartBlock;
  final CitizenBlockRef lastSyncedBlock;
}

final class CitizenHistoryRecord {
  const CitizenHistoryRecord({
    required this.accountId,
    required this.transactionHash,
    required this.nonce,
    required this.destinationAccountId,
    required this.amountFen,
    required this.status,
    required this.block,
    required this.execution,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    required this.remark,
    required this.poolRejectionReason,
  });

  final String accountId;
  final String transactionHash;
  final BigInt nonce;
  final String destinationAccountId;
  final BigInt amountFen;
  final CitizenHistoryStatus status;
  final CitizenBlockRef? block;
  final CitizenExecution? execution;
  final BigInt createdAtMillis;
  final BigInt updatedAtMillis;
  final String remark;
  final String? poolRejectionReason;
}

enum CitizenTransferDirection { outgoing, incoming }

final class CitizenFinalizedTransfer {
  CitizenFinalizedTransfer({
    required this.trackedAccountId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountFen,
    required this.block,
    required this.eventRecordIndex,
    required this.extrinsicIndex,
    required this.direction,
    required this.sourcePallet,
    required this.remarkDisplay,
    required Uint8List remarkBytes,
  }) : remarkBytes = Uint8List.fromList(remarkBytes);

  final String trackedAccountId;
  final String fromAccountId;
  final String toAccountId;
  final BigInt amountFen;
  final CitizenBlockRef block;
  final int eventRecordIndex;
  final int? extrinsicIndex;
  final CitizenTransferDirection direction;
  final String sourcePallet;
  final String remarkDisplay;
  final Uint8List remarkBytes;
}

/// 一次显式 finalized 历史同步的完整持久快照。
final class CitizenTransactionHistory {
  CitizenTransactionHistory({
    required this.revision,
    required List<CitizenHistoryCursor> cursors,
    required List<CitizenHistoryRecord> records,
    required List<CitizenFinalizedTransfer> transfers,
  }) : cursors = List<CitizenHistoryCursor>.unmodifiable(cursors),
       records = List<CitizenHistoryRecord>.unmodifiable(records),
       transfers = List<CitizenFinalizedTransfer>.unmodifiable(transfers);

  final BigInt revision;
  final List<CitizenHistoryCursor> cursors;
  final List<CitizenHistoryRecord> records;
  final List<CitizenFinalizedTransfer> transfers;
}
