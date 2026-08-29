import 'dart:async';

import 'finalized_transaction_models.dart';
import 'transaction_status.dart';

/// finalized 流水、待确认提交和逐账户游标的原子仓储。
///
/// [commit] 必须以 [expectedRevision] 做 CAS，并在一次原子变更中同时保存三类事实。
/// 写调用可能已经提交后才抛错；实现必须回读，回读精确等于候选状态时按成功收敛。
/// 助记词、私钥、child mini-secret 与签名不得进入本仓储。
abstract interface class FinalizedTransactionRepository {
  Future<FinalizedTransactionState> load();

  Future<FinalizedTransactionState> commit({
    required int expectedRevision,
    required Map<String, TransactionSyncCursor> cursors,
    required Map<String, FinalizedAccountTransfer> transfers,
    required Map<String, PendingSubmittedTransaction> submissions,
  });
}

final class FinalizedTransactionRepositoryConflict implements Exception {
  const FinalizedTransactionRepositoryConflict();

  @override
  String toString() => 'finalized 交易仓储 revision 冲突';
}

/// 仓储之上的单调状态机；扫描器和转账服务共享这一入口。
final class FinalizedTransactionHistory {
  FinalizedTransactionHistory({
    required FinalizedTransactionRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now;

  final FinalizedTransactionRepository _repository;
  final DateTime Function() _clock;
  static Future<void> _mutationTail = Future<void>.value();

  Future<FinalizedTransactionState> load() => _repository.load();

  Future<void> ensureCursors({
    required Iterable<String> accountIds,
    required int startBlock,
  }) => _serialize(() async {
    if (startBlock < 0) throw ArgumentError('startBlock 不能为负数');
    await _mutate((state) {
      final cursors = Map<String, TransactionSyncCursor>.of(state.cursors);
      var changed = false;
      for (final accountId in accountIds.toSet()) {
        if (cursors.containsKey(accountId)) continue;
        cursors[accountId] = TransactionSyncCursor(
          accountId: accountId,
          trackingStartBlock: startBlock,
          lastSyncedBlock: startBlock,
        );
        changed = true;
      }
      return changed
          ? _Candidate(
              cursors: cursors,
              transfers: state.transfers,
              submissions: state.submissions,
            )
          : null;
    });
  });

  /// 在广播前持久化本机已签名交易；相同 txHash 重试必须幂等。
  Future<void> recordPendingSubmission({
    required String accountId,
    required String txHash,
    required int usedNonce,
    required String toAccountId,
    required BigInt amountFen,
    required String remark,
  }) => _serialize(() async {
    final normalizedTxHash = normalizeCitizenChainHash(txHash);
    final recordKey = PendingSubmittedTransaction.submitRecordKey(
      accountId,
      normalizedTxHash,
    );
    await _mutate((state) {
      final existing = state.submissions[recordKey];
      if (existing != null) {
        if (existing.accountId != accountId ||
            existing.txHash != normalizedTxHash ||
            existing.usedNonce != usedNonce ||
            existing.toAccountId != toAccountId ||
            existing.amountFen != amountFen ||
            existing.remark != remark) {
          throw StateError('同一 txHash 的本机提交事实不一致');
        }
        return null;
      }
      final now = _clock().millisecondsSinceEpoch;
      final submissions = Map<String, PendingSubmittedTransaction>.of(
        state.submissions,
      );
      submissions[recordKey] = PendingSubmittedTransaction(
        recordKey: recordKey,
        accountId: accountId,
        txHash: normalizedTxHash,
        usedNonce: usedNonce,
        fromAccountId: accountId,
        toAccountId: toAccountId,
        amountFen: amountFen,
        remark: remark,
        status: PendingSubmittedTransactionStatus.pending,
        createdAtMillis: now,
        updatedAtMillis: now,
      );
      return _Candidate(
        cursors: state.cursors,
        transfers: state.transfers,
        submissions: submissions,
      );
    });
  });

  /// 保存交易池给出的块锚；finalized/inBlock 本身都不被当作执行成功。
  Future<void> markSubmissionInBlock({
    required String accountId,
    required String txHash,
    required String blockHash,
  }) => _serialize(() async {
    final normalizedTxHash = normalizeCitizenChainHash(txHash);
    final key = PendingSubmittedTransaction.submitRecordKey(
      accountId,
      normalizedTxHash,
    );
    final anchor = normalizeCitizenChainHash(blockHash);
    await _mutate((state) {
      final current = state.submissions[key];
      if (current == null || current.isTerminal) return null;
      if (current.anchorBlockHash == anchor &&
          current.status == PendingSubmittedTransactionStatus.inBlock) {
        return null;
      }
      final submissions = Map<String, PendingSubmittedTransaction>.of(
        state.submissions,
      );
      submissions[key] = _copySubmission(
        current,
        status: PendingSubmittedTransactionStatus.inBlock,
        anchorBlockHash: anchor,
        updatedAtMillis: _clock().millisecondsSinceEpoch,
      );
      return _Candidate(
        cursors: state.cursors,
        transfers: state.transfers,
        submissions: submissions,
      );
    });
  });

  /// 只记录交易池的确定拒绝；断线、dropped、retracted 与超时不走本入口。
  Future<void> markPoolRejected({
    required String accountId,
    required String txHash,
    required String reason,
  }) => _serialize(() async {
    final normalizedTxHash = normalizeCitizenChainHash(txHash);
    final key = PendingSubmittedTransaction.submitRecordKey(
      accountId,
      normalizedTxHash,
    );
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) throw ArgumentError('reason 不能为空');
    await _mutate((state) {
      final current = state.submissions[key];
      if (current == null || current.isTerminal) return null;
      final submissions = Map<String, PendingSubmittedTransaction>.of(
        state.submissions,
      );
      // 交易池确定拒绝与 runtime ExtrinsicFailed 是两个不同终态。前者不伪造
      // finalized 块号、extrinsic index 或 DispatchError。
      submissions[key] = _copySubmission(
        current,
        status: PendingSubmittedTransactionStatus.poolRejected,
        failureReason: normalizedReason,
        updatedAtMillis: _clock().millisecondsSinceEpoch,
      );
      return _Candidate(
        cursors: state.cursors,
        transfers: state.transfers,
        submissions: submissions,
      );
    });
  });

  /// 原子提交一个 finalized 区块的全部账户流水、明确 pending 终态和游标。
  ///
  /// [outcomes] 只能包含由同 extrinsic index 的 System.Events 解出的明确结果；
  /// 未核实、nonce 消费或“没看到 Failed”均不得出现在这里。
  Future<void> commitFinalizedBlock({
    required int blockNumber,
    required String blockHash,
    required Iterable<FinalizedAccountTransfer> transfers,
    required Map<String, ChainExtrinsicOutcome> outcomes,
    required Map<String, int> extrinsicIndexBySubmissionKey,
    required Iterable<String> advanceCursorAccountIds,
  }) => _serialize(() async {
    final normalizedBlockHash = normalizeCitizenChainHash(blockHash);
    if (blockNumber < 0) throw ArgumentError('blockNumber 不能为负数');
    final transferList = List<FinalizedAccountTransfer>.unmodifiable(transfers);
    final outcomeKeys = outcomes.keys.toSet();
    final indexKeys = extrinsicIndexBySubmissionKey.keys.toSet();
    if (outcomeKeys.length != indexKeys.length ||
        !outcomeKeys.every(indexKeys.contains)) {
      throw StateError('outcomes 与 extrinsic index 映射的 key 集合必须精确一致');
    }
    for (final entry in extrinsicIndexBySubmissionKey.entries) {
      if (entry.value < 0) {
        throw StateError('pending 明确终态的 extrinsic index 不能为负数');
      }
    }
    for (final entry in outcomes.entries) {
      if (!entry.value.isSuccess && entry.value.failure == null) {
        throw StateError('failed outcome 必须携带 runtime failure');
      }
    }
    for (final transfer in transferList) {
      if (transfer.blockNumber != blockNumber ||
          transfer.blockHash != normalizedBlockHash) {
        throw StateError('finalized 转账与本次提交的区块锚不一致');
      }
    }
    await _mutate((state) {
      final nextTransfers = Map<String, FinalizedAccountTransfer>.of(
        state.transfers,
      );
      final nextSubmissions = Map<String, PendingSubmittedTransaction>.of(
        state.submissions,
      );
      final nextCursors = Map<String, TransactionSyncCursor>.of(state.cursors);
      var changed = false;

      for (final transfer in transferList) {
        final existing = nextTransfers[transfer.recordKey];
        if (existing != null) {
          if (!_sameTransfer(existing, transfer)) {
            throw StateError('同一 finalized 事件键对应不同转账事实');
          }
          continue;
        }
        nextTransfers[transfer.recordKey] = transfer;
        changed = true;
      }

      for (final entry in outcomes.entries) {
        final current = nextSubmissions[entry.key];
        if (current == null) {
          throw StateError('outcome 引用了不存在的 pending submission');
        }
        final expectedKey = PendingSubmittedTransaction.submitRecordKey(
          current.accountId,
          current.txHash,
        );
        if (entry.key != current.recordKey || entry.key != expectedKey) {
          throw StateError('outcome key 与当前 pending submission 身份不一致');
        }
        final extrinsicIndex = extrinsicIndexBySubmissionKey[entry.key]!;
        final outcome = entry.value;
        final hasChainTerminal =
            current.status == PendingSubmittedTransactionStatus.finalized ||
            current.status == PendingSubmittedTransactionStatus.failed;
        // 交易池拒绝只是本地 pool 证据；同 txHash/index 后续出现明确的
        // System.ExtrinsicSuccess/Failed 时，finalized 链上事实优先。
        if (hasChainTerminal) {
          if (!_terminalSubmissionMatches(
            current,
            outcome: outcome,
            blockNumber: blockNumber,
            blockHash: normalizedBlockHash,
            extrinsicIndex: extrinsicIndex,
          )) {
            throw StateError('pending 已有终态与本次 outcome 不一致');
          }
          continue;
        }
        nextSubmissions[entry.key] = _copySubmission(
          current,
          status: outcome.isSuccess
              ? PendingSubmittedTransactionStatus.finalized
              : PendingSubmittedTransactionStatus.failed,
          anchorBlockHash: normalizedBlockHash,
          blockNumber: blockNumber,
          extrinsicIndex: extrinsicIndex,
          failure: outcome.failure,
          updatedAtMillis: _clock().millisecondsSinceEpoch,
        );
        changed = true;
      }

      // 游标最后构造并与上面的事实一起提交；仓储 CAS 只有全体成功才落位。
      for (final accountId in advanceCursorAccountIds.toSet()) {
        final current = nextCursors[accountId];
        if (current == null) throw StateError('推进了尚未初始化的账户游标');
        if (current.lastSyncedBlock >= blockNumber) continue;
        nextCursors[accountId] = TransactionSyncCursor(
          accountId: accountId,
          trackingStartBlock: current.trackingStartBlock,
          lastSyncedBlock: blockNumber,
        );
        changed = true;
      }
      return changed
          ? _Candidate(
              cursors: nextCursors,
              transfers: nextTransfers,
              submissions: nextSubmissions,
            )
          : null;
    });
  });

  Future<void> deleteAccountHistory(String accountId) => _serialize(() async {
    await _mutate((state) {
      final cursors = Map<String, TransactionSyncCursor>.of(state.cursors)
        ..remove(accountId);
      final transfers = Map<String, FinalizedAccountTransfer>.of(
        state.transfers,
      )..removeWhere((_, value) => value.accountId == accountId);
      final submissions = Map<String, PendingSubmittedTransaction>.of(
        state.submissions,
      )..removeWhere((_, value) => value.accountId == accountId);
      if (cursors.length == state.cursors.length &&
          transfers.length == state.transfers.length &&
          submissions.length == state.submissions.length) {
        return null;
      }
      return _Candidate(
        cursors: cursors,
        transfers: transfers,
        submissions: submissions,
      );
    });
  });

  Future<void> _mutate(
    _Candidate? Function(FinalizedTransactionState state) build,
  ) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final state = await _repository.load();
      final candidate = build(state);
      if (candidate == null) return;
      try {
        await _repository.commit(
          expectedRevision: state.revision,
          cursors: candidate.cursors,
          transfers: candidate.transfers,
          submissions: candidate.submissions,
        );
        return;
      } on FinalizedTransactionRepositoryConflict {
        if (attempt == 7) rethrow;
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final previous = _mutationTail;
    _mutationTail = () async {
      try {
        await previous;
      } on Object {
        // 前一次失败不能永久污染后续 mutation 队列。
      }
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }
}

final class _Candidate {
  const _Candidate({
    required this.cursors,
    required this.transfers,
    required this.submissions,
  });

  final Map<String, TransactionSyncCursor> cursors;
  final Map<String, FinalizedAccountTransfer> transfers;
  final Map<String, PendingSubmittedTransaction> submissions;
}

PendingSubmittedTransaction _copySubmission(
  PendingSubmittedTransaction value, {
  required PendingSubmittedTransactionStatus status,
  required int updatedAtMillis,
  String? anchorBlockHash,
  int? blockNumber,
  int? extrinsicIndex,
  ChainExtrinsicFailure? failure,
  String? failureReason,
}) => PendingSubmittedTransaction(
  recordKey: value.recordKey,
  accountId: value.accountId,
  txHash: value.txHash,
  usedNonce: value.usedNonce,
  fromAccountId: value.fromAccountId,
  toAccountId: value.toAccountId,
  amountFen: value.amountFen,
  remark: value.remark,
  status: status,
  createdAtMillis: value.createdAtMillis,
  updatedAtMillis: updatedAtMillis,
  anchorBlockHash: anchorBlockHash,
  blockNumber: blockNumber,
  extrinsicIndex: extrinsicIndex,
  failure: failure,
  failureReason: failureReason,
);

bool _terminalSubmissionMatches(
  PendingSubmittedTransaction current, {
  required ChainExtrinsicOutcome outcome,
  required int blockNumber,
  required String blockHash,
  required int extrinsicIndex,
}) {
  final expectedStatus = outcome.isSuccess
      ? PendingSubmittedTransactionStatus.finalized
      : PendingSubmittedTransactionStatus.failed;
  return current.status == expectedStatus &&
      current.anchorBlockHash == blockHash &&
      current.blockNumber == blockNumber &&
      current.extrinsicIndex == extrinsicIndex &&
      _sameFailure(current.failure, outcome.failure);
}

bool _sameFailure(ChainExtrinsicFailure? left, ChainExtrinsicFailure? right) =>
    identical(left, right) ||
    (left != null &&
        right != null &&
        left.dispatchErrorVariant == right.dispatchErrorVariant &&
        left.moduleIndex == right.moduleIndex &&
        left.errorIndex == right.errorIndex &&
        left.description == right.description);

bool _sameTransfer(
  FinalizedAccountTransfer left,
  FinalizedAccountTransfer right,
) =>
    left.recordKey == right.recordKey &&
    left.accountId == right.accountId &&
    left.direction == right.direction &&
    left.fromAccountId == right.fromAccountId &&
    left.toAccountId == right.toAccountId &&
    left.amountFen == right.amountFen &&
    left.blockNumber == right.blockNumber &&
    left.blockHash == right.blockHash &&
    left.eventRecordIndex == right.eventRecordIndex &&
    left.extrinsicIndex == right.extrinsicIndex &&
    left.sourcePallet == right.sourcePallet &&
    left.remark == right.remark;
