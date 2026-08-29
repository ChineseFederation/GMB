import 'dart:async';
import 'dart:convert';

import '../transaction/finalized_transaction_models.dart';
import '../transaction/finalized_transaction_repository.dart';
import '../transaction/transaction_status.dart';
import 'preferences_data_store.dart';

/// Android/iOS 标准装配使用的 finalized 交易仓储。
///
/// 三类公开事实放在同一个严格 JSON 信封中，因而 finalized 流水、pending 终态和
/// 游标不会发生半提交。所有实例在同一 Dart isolate 共用 mutation 队列；底层写入
/// 后即使抛错，也以完整回读结果收敛。需要跨 isolate/进程 CAS 或大容量索引的宿主
/// 可以注入自己的 [FinalizedTransactionRepository]。
final class PreferencesFinalizedTransactionRepository
    implements FinalizedTransactionRepository {
  PreferencesFinalizedTransactionRepository({PreferencesDataStore? preferences})
    : _preferences = preferences ?? SharedPreferencesDataStore();

  static const String storageKey = 'citizensdk.transactions.state.v1';
  static const String schema = 'citizen_sdk.transactions.state.v1';

  final PreferencesDataStore _preferences;
  static Future<void> _mutationTail = Future<void>.value();

  @override
  Future<FinalizedTransactionState> load() async {
    final raw = await _preferences.getString(storageKey);
    return raw == null ? FinalizedTransactionState.empty() : _decodeState(raw);
  }

  @override
  Future<FinalizedTransactionState> commit({
    required int expectedRevision,
    required Map<String, TransactionSyncCursor> cursors,
    required Map<String, FinalizedAccountTransfer> transfers,
    required Map<String, PendingSubmittedTransaction> submissions,
  }) => _serialize(() async {
    final current = await load();
    if (current.revision != expectedRevision) {
      throw const FinalizedTransactionRepositoryConflict();
    }
    final candidate = FinalizedTransactionState(
      revision: current.revision + 1,
      cursors: cursors,
      transfers: transfers,
      submissions: submissions,
    );
    final encoded = _encodeState(candidate);
    Object? writeError;
    StackTrace? writeStackTrace;
    try {
      await _preferences.setString(storageKey, encoded);
    } on Object catch (error, stackTrace) {
      writeError = error;
      writeStackTrace = stackTrace;
    }

    String? persisted;
    try {
      persisted = await _preferences.getString(storageKey);
    } on Object catch (error, stackTrace) {
      if (writeError != null) {
        Error.throwWithStackTrace(writeError, writeStackTrace!);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (persisted != encoded) {
      if (writeError != null) {
        Error.throwWithStackTrace(writeError, writeStackTrace!);
      }
      throw const FinalizedTransactionRepositoryConflict();
    }
    // 返回持久字节的严格解码结果，禁止确认截断或畸形写入。
    return _decodeState(persisted!);
  });

  static String _encodeState(FinalizedTransactionState state) {
    final cursors = state.cursors.values.toList(growable: false)
      ..sort((left, right) => left.accountId.compareTo(right.accountId));
    final transfers = state.transfers.values.toList(growable: false)
      ..sort((left, right) => left.recordKey.compareTo(right.recordKey));
    final submissions = state.submissions.values.toList(growable: false)
      ..sort((left, right) => left.recordKey.compareTo(right.recordKey));
    return jsonEncode(<String, Object?>{
      'schema': schema,
      'revision': state.revision,
      'cursors': cursors.map(_encodeCursor).toList(growable: false),
      'transfers': transfers.map(_encodeTransfer).toList(growable: false),
      'submissions': submissions.map(_encodeSubmission).toList(growable: false),
    });
  }

  static Map<String, Object> _encodeCursor(TransactionSyncCursor value) =>
      <String, Object>{
        'account_id': value.accountId,
        'tracking_start_block': value.trackingStartBlock,
        'last_synced_block': value.lastSyncedBlock,
      };

  static Map<String, Object?> _encodeTransfer(FinalizedAccountTransfer value) =>
      <String, Object?>{
        'record_key': value.recordKey,
        'account_id': value.accountId,
        'direction': value.direction.name,
        'from_account_id': value.fromAccountId,
        'to_account_id': value.toAccountId,
        'amount_fen': value.amountFen.toString(),
        'block_number': value.blockNumber,
        'block_hash': value.blockHash,
        'event_record_index': value.eventRecordIndex,
        'extrinsic_index': value.extrinsicIndex,
        'source_pallet': value.sourcePallet,
        'remark': value.remark,
      };

  static Map<String, Object?> _encodeSubmission(
    PendingSubmittedTransaction value,
  ) => <String, Object?>{
    'record_key': value.recordKey,
    'account_id': value.accountId,
    'tx_hash': value.txHash,
    'used_nonce': value.usedNonce,
    'from_account_id': value.fromAccountId,
    'to_account_id': value.toAccountId,
    'amount_fen': value.amountFen.toString(),
    'remark': value.remark,
    'status': value.status.name,
    'created_at_millis': value.createdAtMillis,
    'updated_at_millis': value.updatedAtMillis,
    'anchor_block_hash': value.anchorBlockHash,
    'block_number': value.blockNumber,
    'extrinsic_index': value.extrinsicIndex,
    'failure': _encodeFailure(value.failure),
    'failure_reason': value.failureReason,
  };

  static Map<String, Object?>? _encodeFailure(ChainExtrinsicFailure? value) {
    if (value == null) return null;
    return <String, Object?>{
      'dispatch_error_variant': value.dispatchErrorVariant,
      'module_index': value.moduleIndex,
      'error_index': value.errorIndex,
      'description': value.description,
    };
  }

  static FinalizedTransactionState _decodeState(String raw) {
    try {
      final root = _strictMap(jsonDecode(raw), const <String>{
        'schema',
        'revision',
        'cursors',
        'transfers',
        'submissions',
      }, '交易状态');
      if (root['schema'] != schema || root['revision'] is! int) {
        throw const FormatException('交易状态 schema 或 revision 无效');
      }
      final revision = root['revision']! as int;
      final cursorValues = _strictList(root['cursors'], '游标');
      final transferValues = _strictList(root['transfers'], '转账');
      final submissionValues = _strictList(root['submissions'], 'pending');
      final cursors = <String, TransactionSyncCursor>{};
      for (final rawCursor in cursorValues) {
        final cursor = _decodeCursor(rawCursor);
        if (cursors.putIfAbsent(cursor.accountId, () => cursor) != cursor) {
          throw const FormatException('游标账户重复');
        }
      }
      final transfers = <String, FinalizedAccountTransfer>{};
      for (final rawTransfer in transferValues) {
        final transfer = _decodeTransfer(rawTransfer);
        if (transfers.putIfAbsent(transfer.recordKey, () => transfer) !=
            transfer) {
          throw const FormatException('转账 recordKey 重复');
        }
      }
      final submissions = <String, PendingSubmittedTransaction>{};
      for (final rawSubmission in submissionValues) {
        final submission = _decodeSubmission(rawSubmission);
        if (submissions.putIfAbsent(submission.recordKey, () => submission) !=
            submission) {
          throw const FormatException('pending recordKey 重复');
        }
      }
      return FinalizedTransactionState(
        revision: revision,
        cursors: cursors,
        transfers: transfers,
        submissions: submissions,
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('交易公开状态 JSON 无效');
    }
  }

  static TransactionSyncCursor _decodeCursor(Object? raw) {
    final value = _strictMap(raw, const <String>{
      'account_id',
      'tracking_start_block',
      'last_synced_block',
    }, '游标');
    return TransactionSyncCursor(
      accountId: _string(value['account_id'], '游标 account_id'),
      trackingStartBlock: _integer(
        value['tracking_start_block'],
        'tracking_start_block',
      ),
      lastSyncedBlock: _integer(
        value['last_synced_block'],
        'last_synced_block',
      ),
    );
  }

  static FinalizedAccountTransfer _decodeTransfer(Object? raw) {
    final value = _strictMap(raw, const <String>{
      'record_key',
      'account_id',
      'direction',
      'from_account_id',
      'to_account_id',
      'amount_fen',
      'block_number',
      'block_hash',
      'event_record_index',
      'extrinsic_index',
      'source_pallet',
      'remark',
    }, '转账');
    final directionName = _string(value['direction'], 'direction');
    final directions = FinalizedTransferDirection.values.where(
      (entry) => entry.name == directionName,
    );
    if (directions.length != 1) throw const FormatException('转账方向无效');
    return FinalizedAccountTransfer(
      recordKey: _string(value['record_key'], 'record_key'),
      accountId: _string(value['account_id'], 'account_id'),
      direction: directions.single,
      fromAccountId: _string(value['from_account_id'], 'from_account_id'),
      toAccountId: _string(value['to_account_id'], 'to_account_id'),
      amountFen: _positiveBigInt(value['amount_fen'], 'amount_fen'),
      blockNumber: _integer(value['block_number'], 'block_number'),
      blockHash: _string(value['block_hash'], 'block_hash'),
      eventRecordIndex: _integer(
        value['event_record_index'],
        'event_record_index',
      ),
      extrinsicIndex: _nullableInteger(
        value['extrinsic_index'],
        'extrinsic_index',
      ),
      sourcePallet: _string(value['source_pallet'], 'source_pallet'),
      remark: _nullableString(value['remark'], 'remark'),
    );
  }

  static PendingSubmittedTransaction _decodeSubmission(Object? raw) {
    final value = _strictMap(raw, const <String>{
      'record_key',
      'account_id',
      'tx_hash',
      'used_nonce',
      'from_account_id',
      'to_account_id',
      'amount_fen',
      'remark',
      'status',
      'created_at_millis',
      'updated_at_millis',
      'anchor_block_hash',
      'block_number',
      'extrinsic_index',
      'failure',
      'failure_reason',
    }, 'pending');
    final statusName = _string(value['status'], 'status');
    final statuses = PendingSubmittedTransactionStatus.values.where(
      (entry) => entry.name == statusName,
    );
    if (statuses.length != 1) throw const FormatException('pending status 无效');
    return PendingSubmittedTransaction(
      recordKey: _string(value['record_key'], 'record_key'),
      accountId: _string(value['account_id'], 'account_id'),
      txHash: _string(value['tx_hash'], 'tx_hash'),
      usedNonce: _integer(value['used_nonce'], 'used_nonce'),
      fromAccountId: _string(value['from_account_id'], 'from_account_id'),
      toAccountId: _string(value['to_account_id'], 'to_account_id'),
      amountFen: _positiveBigInt(value['amount_fen'], 'amount_fen'),
      remark: _string(value['remark'], 'remark'),
      status: statuses.single,
      createdAtMillis: _integer(
        value['created_at_millis'],
        'created_at_millis',
      ),
      updatedAtMillis: _integer(
        value['updated_at_millis'],
        'updated_at_millis',
      ),
      anchorBlockHash: _nullableString(
        value['anchor_block_hash'],
        'anchor_block_hash',
      ),
      blockNumber: _nullableInteger(value['block_number'], 'block_number'),
      extrinsicIndex: _nullableInteger(
        value['extrinsic_index'],
        'extrinsic_index',
      ),
      failure: _decodeFailure(value['failure']),
      failureReason: _nullableString(value['failure_reason'], 'failure_reason'),
    );
  }

  static ChainExtrinsicFailure? _decodeFailure(Object? raw) {
    if (raw == null) return null;
    final value = _strictMap(raw, const <String>{
      'dispatch_error_variant',
      'module_index',
      'error_index',
      'description',
    }, 'failure');
    return ChainExtrinsicFailure(
      dispatchErrorVariant: _integer(
        value['dispatch_error_variant'],
        'dispatch_error_variant',
      ),
      moduleIndex: _nullableInteger(value['module_index'], 'module_index'),
      errorIndex: _nullableInteger(value['error_index'], 'error_index'),
      description: _string(value['description'], 'description'),
    );
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final previous = _mutationTail;
    _mutationTail = () async {
      try {
        await previous;
      } on Object {
        // 前一次失败不能永久污染后续提交。
      }
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  static Map<String, dynamic> _strictMap(
    Object? value,
    Set<String> keys,
    String label,
  ) {
    if (value is! Map<String, dynamic> ||
        value.length != keys.length ||
        !keys.every(value.containsKey)) {
      throw FormatException('$label 字段集合无效');
    }
    return value;
  }

  static List<Object?> _strictList(Object? value, String label) {
    if (value is! List<Object?>) throw FormatException('$label 必须是数组');
    return value;
  }

  static String _string(Object? value, String label) {
    if (value is! String) throw FormatException('$label 必须是字符串');
    return value;
  }

  static String? _nullableString(Object? value, String label) {
    if (value == null) return null;
    return _string(value, label);
  }

  static int _integer(Object? value, String label) {
    if (value is! int) throw FormatException('$label 必须是整数');
    return value;
  }

  static int? _nullableInteger(Object? value, String label) {
    if (value == null) return null;
    return _integer(value, label);
  }

  static BigInt _positiveBigInt(Object? value, String label) {
    if (value is! String || !RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
      throw FormatException('$label 必须是正十进制字符串');
    }
    return BigInt.parse(value);
  }
}
