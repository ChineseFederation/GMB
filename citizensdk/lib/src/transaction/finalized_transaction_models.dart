import 'package:meta/meta.dart';

import '../crypto/account_codec.dart';
import 'transaction_status.dart';

/// SDK 开始跟踪的一条公民链账户。
///
/// 账户身份始终使用规范的小写 AccountId；SS58 只用于宿主展示，不进入同步游标或
/// 流水唯一键。
@immutable
final class WatchedChainAccount {
  WatchedChainAccount({required this.accountId}) {
    citizenAccountIdBytes(accountId);
  }

  final String accountId;
}

/// 已最终块中的一条产品无关转账事件。
///
/// 该对象表示链上事件本身；若发送方和接收方都在本机跟踪，仓储会为两个账户分别
/// 生成 [FinalizedAccountTransfer]，但本对象仍只有一条。
@immutable
final class DecodedFinalizedTransfer {
  DecodedFinalizedTransfer({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountFen,
    required this.blockNumber,
    required this.blockHash,
    required this.eventRecordIndex,
    required this.extrinsicIndex,
    required this.sourcePallet,
    this.remark,
  }) {
    citizenAccountIdBytes(fromAccountId);
    citizenAccountIdBytes(toAccountId);
    if (amountFen <= BigInt.zero) throw ArgumentError('转账金额必须大于 0 分');
    if (blockNumber < 0) throw ArgumentError('区块号不能为负数');
    if (eventRecordIndex < 0) throw ArgumentError('事件序号不能为负数');
    if (extrinsicIndex != null && extrinsicIndex! < 0) {
      throw const FormatException('extrinsic index 不能为负数');
    }
    _requireHash(blockHash, 'blockHash');
    _requireTransferSource(sourcePallet, remark);
  }

  final String fromAccountId;
  final String toAccountId;
  final BigInt amountFen;
  final int blockNumber;
  final String blockHash;
  final int eventRecordIndex;
  final int? extrinsicIndex;
  final String sourcePallet;
  final String? remark;
}

enum FinalizedTransferDirection { incoming, outgoing }

/// 面向单个被跟踪账户持久化的 finalized 转账流水。
@immutable
final class FinalizedAccountTransfer {
  FinalizedAccountTransfer({
    required this.recordKey,
    required this.accountId,
    required this.direction,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountFen,
    required this.blockNumber,
    required this.blockHash,
    required this.eventRecordIndex,
    required this.extrinsicIndex,
    required this.sourcePallet,
    this.remark,
  }) {
    citizenAccountIdBytes(accountId);
    citizenAccountIdBytes(fromAccountId);
    citizenAccountIdBytes(toAccountId);
    if (recordKey != eventRecordKey(accountId, blockHash, eventRecordIndex)) {
      throw const FormatException('finalized 转账 recordKey 与链事件身份不一致');
    }
    if (amountFen <= BigInt.zero) throw ArgumentError('转账金额必须大于 0 分');
    if (blockNumber < 0) throw ArgumentError('区块号不能为负数');
    if (eventRecordIndex < 0) throw ArgumentError('事件序号不能为负数');
    if (extrinsicIndex != null && extrinsicIndex! < 0) {
      throw const FormatException('extrinsic index 不能为负数');
    }
    _requireHash(blockHash, 'blockHash');
    _requireTransferSource(sourcePallet, remark);
    final expected = direction == FinalizedTransferDirection.incoming
        ? toAccountId
        : fromAccountId;
    if (accountId != expected) {
      throw const FormatException('转账方向与所属账户不一致');
    }
  }

  final String recordKey;
  final String accountId;
  final FinalizedTransferDirection direction;
  final String fromAccountId;
  final String toAccountId;
  final BigInt amountFen;
  final int blockNumber;
  final String blockHash;
  final int eventRecordIndex;
  final int? extrinsicIndex;
  final String sourcePallet;
  final String? remark;

  /// 只表示转账本金方向；手续费必须由独立链上事实提供，不能在这里猜测。
  BigInt get signedPrincipalFen =>
      direction == FinalizedTransferDirection.incoming ? amountFen : -amountFen;

  static String eventRecordKey(
    String accountId,
    String blockHash,
    int eventRecordIndex,
  ) {
    citizenAccountIdBytes(accountId);
    return '$accountId:${_normalizeHash(blockHash)}:$eventRecordIndex';
  }
}

enum PendingSubmittedTransactionStatus {
  pending,
  inBlock,
  poolRejected,
  finalized,
  failed,
}

/// SDK 本机已签名提交的一笔转账。
///
/// [recordKey] 在 pending → inBlock → finalized/failed 全周期保持不变。只有同一
/// extrinsic index 的 `System.ExtrinsicSuccess/Failed` 可以写入两个链上终态。nonce
/// 消费本身不证明该笔 extrinsic 成功或失败，不进入本状态机。
@immutable
final class PendingSubmittedTransaction {
  PendingSubmittedTransaction({
    required this.recordKey,
    required this.accountId,
    required this.txHash,
    required this.usedNonce,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountFen,
    required this.remark,
    required this.status,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.anchorBlockHash,
    this.blockNumber,
    this.extrinsicIndex,
    this.failure,
    this.failureReason,
  }) {
    citizenAccountIdBytes(accountId);
    citizenAccountIdBytes(fromAccountId);
    citizenAccountIdBytes(toAccountId);
    _requireHash(txHash, 'txHash');
    if (recordKey != submitRecordKey(accountId, txHash)) {
      throw const FormatException('pending recordKey 与 accountId/txHash 不一致');
    }
    if (accountId != fromAccountId) {
      throw const FormatException('pending 所属账户必须是转出账户');
    }
    if (usedNonce < 0) throw ArgumentError('nonce 不能为负数');
    if (amountFen <= BigInt.zero) throw ArgumentError('转账金额必须大于 0 分');
    if (createdAtMillis < 0 || updatedAtMillis < createdAtMillis) {
      throw const FormatException('pending 时间戳无效');
    }
    if (anchorBlockHash != null) {
      _requireHash(anchorBlockHash!, 'anchorBlockHash');
    }
    if (blockNumber != null && blockNumber! < 0) {
      throw const FormatException('pending 区块号无效');
    }
    if (extrinsicIndex != null && extrinsicIndex! < 0) {
      throw const FormatException('pending extrinsic index 无效');
    }
    _requirePendingStatusFields(
      status: status,
      anchorBlockHash: anchorBlockHash,
      blockNumber: blockNumber,
      extrinsicIndex: extrinsicIndex,
      failure: failure,
      failureReason: failureReason,
    );
  }

  final String recordKey;
  final String accountId;
  final String txHash;
  final int usedNonce;
  final String fromAccountId;
  final String toAccountId;
  final BigInt amountFen;
  final String remark;
  final PendingSubmittedTransactionStatus status;
  final int createdAtMillis;
  final int updatedAtMillis;
  final String? anchorBlockHash;
  final int? blockNumber;
  final int? extrinsicIndex;
  final ChainExtrinsicFailure? failure;
  final String? failureReason;

  bool get isTerminal =>
      status == PendingSubmittedTransactionStatus.poolRejected ||
      hasChainOutcome;

  /// 是否已经由 finalized 链上 System outcome 给出不可逆终态。
  ///
  /// `poolRejected` 只是交易池线索，后续仍可被同 txHash 的明确链上事实覆盖。
  bool get hasChainOutcome =>
      status == PendingSubmittedTransactionStatus.finalized ||
      status == PendingSubmittedTransactionStatus.failed;

  static String submitRecordKey(String accountId, String txHash) {
    citizenAccountIdBytes(accountId);
    return '$accountId:tx:${_normalizeHash(txHash)}';
  }
}

/// 单个账户的 finalized 增量同步游标。
@immutable
final class TransactionSyncCursor {
  TransactionSyncCursor({
    required this.accountId,
    required this.trackingStartBlock,
    required this.lastSyncedBlock,
  }) {
    citizenAccountIdBytes(accountId);
    if (trackingStartBlock < 0 || lastSyncedBlock < trackingStartBlock) {
      throw const FormatException('交易同步游标无效');
    }
  }

  final String accountId;
  final int trackingStartBlock;
  final int lastSyncedBlock;
}

/// finalized 交易仓储的完整公开状态。
@immutable
final class FinalizedTransactionState {
  FinalizedTransactionState({
    required this.revision,
    required Map<String, TransactionSyncCursor> cursors,
    required Map<String, FinalizedAccountTransfer> transfers,
    required Map<String, PendingSubmittedTransaction> submissions,
  }) : cursors = Map<String, TransactionSyncCursor>.unmodifiable(cursors),
       transfers = Map<String, FinalizedAccountTransfer>.unmodifiable(
         transfers,
       ),
       submissions = Map<String, PendingSubmittedTransaction>.unmodifiable(
         submissions,
       ) {
    if (revision < 0) throw const FormatException('交易仓储 revision 无效');
    for (final entry in this.cursors.entries) {
      if (entry.key != entry.value.accountId) {
        throw const FormatException('游标 Map key 与账户身份不一致');
      }
    }
    for (final entry in this.transfers.entries) {
      if (entry.key != entry.value.recordKey) {
        throw const FormatException('转账 Map key 与 recordKey 不一致');
      }
    }
    for (final entry in this.submissions.entries) {
      if (entry.key != entry.value.recordKey) {
        throw const FormatException('pending Map key 与 recordKey 不一致');
      }
    }
  }

  const FinalizedTransactionState.empty()
    : revision = 0,
      cursors = const <String, TransactionSyncCursor>{},
      transfers = const <String, FinalizedAccountTransfer>{},
      submissions = const <String, PendingSubmittedTransaction>{};

  final int revision;
  final Map<String, TransactionSyncCursor> cursors;
  final Map<String, FinalizedAccountTransfer> transfers;
  final Map<String, PendingSubmittedTransaction> submissions;
}

String normalizeCitizenChainHash(String value) => _normalizeHash(value);

String _normalizeHash(String value) {
  if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('链哈希必须是规范小写 32 字节 hex');
  }
  return value;
}

void _requireHash(String value, String name) {
  try {
    _normalizeHash(value);
  } on FormatException catch (error) {
    throw FormatException('$name 无效：$error');
  }
}

void _requireTransferSource(String sourcePallet, String? remark) {
  if (sourcePallet != 'OnchainTransaction' && sourcePallet != 'Balances') {
    throw const FormatException(
      'sourcePallet 只能是 OnchainTransaction 或 Balances',
    );
  }
  if (sourcePallet == 'Balances' && remark != null) {
    throw const FormatException('Balances.Transfer 不得携带 remark');
  }
}

void _requirePendingStatusFields({
  required PendingSubmittedTransactionStatus status,
  required String? anchorBlockHash,
  required int? blockNumber,
  required int? extrinsicIndex,
  required ChainExtrinsicFailure? failure,
  required String? failureReason,
}) {
  final hasReason = failureReason != null && failureReason.trim().isNotEmpty;
  switch (status) {
    case PendingSubmittedTransactionStatus.pending:
      if (anchorBlockHash != null ||
          blockNumber != null ||
          extrinsicIndex != null ||
          failure != null ||
          failureReason != null) {
        throw const FormatException('pending 不得携带块锚或终态字段');
      }
      return;
    case PendingSubmittedTransactionStatus.inBlock:
      if (anchorBlockHash == null ||
          blockNumber != null ||
          extrinsicIndex != null ||
          failure != null ||
          failureReason != null) {
        throw const FormatException('inBlock 必须仅携带 anchorBlockHash');
      }
      return;
    case PendingSubmittedTransactionStatus.poolRejected:
      if (!hasReason ||
          anchorBlockHash != null ||
          blockNumber != null ||
          extrinsicIndex != null ||
          failure != null) {
        throw const FormatException('poolRejected 必须仅携带非空 failureReason');
      }
      return;
    case PendingSubmittedTransactionStatus.finalized:
      if (anchorBlockHash == null ||
          blockNumber == null ||
          extrinsicIndex == null ||
          failure != null ||
          failureReason != null) {
        throw const FormatException('finalized 必须仅携带明确块锚、区块号和 extrinsic index');
      }
      return;
    case PendingSubmittedTransactionStatus.failed:
      if (anchorBlockHash == null ||
          blockNumber == null ||
          extrinsicIndex == null ||
          failure == null ||
          failureReason != null) {
        throw const FormatException(
          'failed 必须携带明确块锚、区块号、extrinsic index 和 failure',
        );
      }
      return;
  }
}
