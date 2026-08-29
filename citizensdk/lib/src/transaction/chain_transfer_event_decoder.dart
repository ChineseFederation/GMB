import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:polkadart/polkadart.dart' show Events, Hasher;

import '../crypto/account_codec.dart';
import 'chain_rpc.dart';
import 'finalized_transaction_models.dart';

/// metadata 解码后仍保留的产品无关 EventRecord 视图。
@immutable
final class DecodedChainEventRecord {
  const DecodedChainEventRecord({
    required this.eventRecordIndex,
    required this.phase,
    required this.event,
  });

  final int eventRecordIndex;
  final Map<String, dynamic> phase;
  final Map<String, dynamic> event;
}

/// 公民链 finalized `System.Events` 的转账解码器。
///
/// 解码只能使用目标块的 [ChainRuntimeContext]。metadata 不匹配或 EventRecord 无法
/// 完整解码时直接抛错，调用方不得推进游标；禁止在未知 payload 中滑窗猜事件。
abstract interface class FinalizedTransferEventDecoder {
  List<DecodedFinalizedTransfer> decode({
    required Uint8List eventsBytes,
    required ChainRuntimeContext runtimeContext,
    required int blockNumber,
    required String blockHash,
  });
}

final class ChainTransferEventDecoder implements FinalizedTransferEventDecoder {
  const ChainTransferEventDecoder();

  static final Uint8List _systemEventsKey = _buildStorageValueKey(
    'System',
    'Events',
  );

  @override
  List<DecodedFinalizedTransfer> decode({
    required Uint8List eventsBytes,
    required ChainRuntimeContext runtimeContext,
    required int blockNumber,
    required String blockHash,
  }) {
    final normalizedBlockHash = normalizeCitizenChainHash(blockHash);
    if (runtimeContext.blockHash != normalizedBlockHash) {
      throw StateError('System.Events 与 runtime context 不属于同一块');
    }
    if (eventsBytes.isEmpty) throw const FormatException('System.Events 不能为空');
    final decoded = Events.fromJson(<String, dynamic>{
      'changes': <Object?>[
        <Object?>['0x${_hex(_systemEventsKey)}', '0x${_hex(eventsBytes)}'],
      ],
    }, runtimeContext.metadata.chainInfo);
    final records = <DecodedChainEventRecord>[
      for (var index = 0; index < decoded.eventRecord.length; index++)
        DecodedChainEventRecord(
          eventRecordIndex: index,
          phase: Map<String, dynamic>.from(decoded.eventRecord[index].phase),
          event: Map<String, dynamic>.from(decoded.eventRecord[index].event),
        ),
    ];
    return decodeRecords(
      records: records,
      blockNumber: blockNumber,
      blockHash: normalizedBlockHash,
    );
  }

  /// 归一第三方 metadata 解码器的 Map/List 容器形态，并做业务/底层双事件去重。
  ///
  /// 该入口公开是为了让 SDK 宿主能够复核已经由同一 metadata registry 解出的事件；
  /// 它不接受原始 bytes，也不能替代上面的正式 SCALE 解码入口。
  @visibleForTesting
  List<DecodedFinalizedTransfer> decodeRecords({
    required Iterable<DecodedChainEventRecord> records,
    required int blockNumber,
    required String blockHash,
  }) {
    final normalizedBlockHash = normalizeCitizenChainHash(blockHash);
    final candidates = <DecodedFinalizedTransfer>[];
    for (final record in records) {
      final extrinsicIndex = _readExtrinsicIndex(record.phase);
      final onchain = _readTransferWithRemark(record.event);
      if (onchain != null && onchain.$1 != onchain.$2) {
        candidates.add(
          DecodedFinalizedTransfer(
            fromAccountId: onchain.$1,
            toAccountId: onchain.$2,
            amountFen: onchain.$3,
            remark: onchain.$4,
            blockNumber: blockNumber,
            blockHash: normalizedBlockHash,
            eventRecordIndex: record.eventRecordIndex,
            extrinsicIndex: extrinsicIndex,
            sourcePallet: 'OnchainTransaction',
          ),
        );
        continue;
      }
      final balances = _readBalancesTransfer(record.event);
      if (balances != null && balances.$1 != balances.$2) {
        candidates.add(
          DecodedFinalizedTransfer(
            fromAccountId: balances.$1,
            toAccountId: balances.$2,
            amountFen: balances.$3,
            blockNumber: blockNumber,
            blockHash: normalizedBlockHash,
            eventRecordIndex: record.eventRecordIndex,
            extrinsicIndex: extrinsicIndex,
            sourcePallet: 'Balances',
          ),
        );
      }
    }

    // transfer_with_remark 内部转账通常同时产生 Balances::Transfer。只在两个
    // 不同 pallet、同一 extrinsic、同账户和同金额时一对一合并；phase 缺失时
    // 不武断去重，避免把同块两笔同额转账合并。
    final onchainByIdentity = <String, List<DecodedFinalizedTransfer>>{};
    for (final candidate in candidates) {
      if (candidate.sourcePallet != 'OnchainTransaction' ||
          candidate.extrinsicIndex == null) {
        continue;
      }
      onchainByIdentity
          .putIfAbsent(
            _dedupeIdentity(candidate),
            () => <DecodedFinalizedTransfer>[],
          )
          .add(candidate);
    }
    final matchedOnchainCount = <String, int>{};
    final result = <DecodedFinalizedTransfer>[];
    for (final candidate in candidates) {
      if (candidate.sourcePallet != 'Balances' ||
          candidate.extrinsicIndex == null) {
        result.add(candidate);
        continue;
      }
      final identity = _dedupeIdentity(candidate);
      final onchain = onchainByIdentity[identity];
      final matched = matchedOnchainCount[identity] ?? 0;
      if (onchain != null && matched < onchain.length) {
        matchedOnchainCount[identity] = matched + 1;
        continue;
      }
      result.add(candidate);
    }
    return List<DecodedFinalizedTransfer>.unmodifiable(result);
  }

  static String _dedupeIdentity(DecodedFinalizedTransfer value) =>
      '${value.extrinsicIndex}:${value.fromAccountId}:${value.toAccountId}:'
      '${value.amountFen}';

  static (String, String, BigInt, String?)? _readTransferWithRemark(
    Map<String, dynamic> event,
  ) {
    final pallet = event['OnchainTransaction'] ?? event['onchainTransaction'];
    if (pallet is! Map) return null;
    final raw =
        pallet['TransferWithRemark'] ??
        pallet['transferWithRemark'] ??
        pallet['transfer_with_remark'];
    if (raw == null) return null;
    final values = _eventValues(raw, const <List<String>>[
      <String>['from_account_id', 'fromAccountId', 'from', '0'],
      <String>[
        'beneficiary_account_id',
        'beneficiaryAccountId',
        'beneficiary',
        'to',
        '1',
      ],
      <String>['amount', '2'],
      <String>['remark', '3'],
    ]);
    if (values == null) return null;
    final from = _decodeAccountId(values[0]);
    final to = _decodeAccountId(values[1]);
    final amount = _decodeAmount(values[2]);
    if (from == null || to == null || amount == null || amount <= BigInt.zero) {
      return null;
    }
    return (from, to, amount, _decodeRemark(values[3]));
  }

  static (String, String, BigInt)? _readBalancesTransfer(
    Map<String, dynamic> event,
  ) {
    final pallet = event['Balances'] ?? event['balances'];
    if (pallet is! Map) return null;
    final raw = pallet['Transfer'] ?? pallet['transfer'];
    if (raw == null) return null;
    final values = _eventValues(raw, const <List<String>>[
      <String>['from', '0'],
      <String>['to', '1'],
      <String>['amount', 'value', '2'],
    ]);
    if (values == null) return null;
    final from = _decodeAccountId(values[0]);
    final to = _decodeAccountId(values[1]);
    final amount = _decodeAmount(values[2]);
    if (from == null || to == null || amount == null || amount <= BigInt.zero) {
      return null;
    }
    return (from, to, amount);
  }

  static List<Object?>? _eventValues(
    Object? raw,
    List<List<String>> fieldNames,
  ) {
    if (raw is List && raw.length >= fieldNames.length) {
      return raw
          .take(fieldNames.length)
          .cast<Object?>()
          .toList(growable: false);
    }
    if (raw is! Map) return null;
    final result = <Object?>[];
    final fallback = raw.values.toList(growable: false);
    for (var index = 0; index < fieldNames.length; index++) {
      Object? value;
      var found = false;
      for (final name in fieldNames[index]) {
        if (raw.containsKey(name)) {
          value = raw[name];
          found = true;
          break;
        }
      }
      if (!found && fallback.length >= fieldNames.length) {
        value = fallback[index];
        found = true;
      }
      if (!found) return null;
      result.add(value);
    }
    return result;
  }

  static int? _readExtrinsicIndex(Map<String, dynamic> phase) {
    final value = phase['ApplyExtrinsic'] ?? phase['applyExtrinsic'];
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _decodeAccountId(Object? raw) {
    if (raw is Uint8List && raw.length == 32) {
      return citizenAccountIdFromBytes(raw);
    }
    if (raw is List) {
      final values = raw.whereType<int>().toList(growable: false);
      if (values.length == 32) return citizenAccountIdFromBytes(values);
    }
    if (raw is String) {
      if (isCitizenAccountId(raw)) return raw;
      try {
        return citizenAccountIdFromBytes(citizenPublicKeyFromSs58(raw));
      } on Object {
        return null;
      }
    }
    return null;
  }

  static BigInt? _decodeAmount(Object? raw) {
    if (raw is BigInt) return raw;
    if (raw is int) return BigInt.from(raw);
    if (raw is String) return BigInt.tryParse(raw);
    return null;
  }

  static String? _decodeRemark(Object? raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return _decodeRemarkBytes(raw);
    if (raw is List) {
      final values = raw.whereType<int>().toList(growable: false);
      if (values.length == raw.length) return _decodeRemarkBytes(values);
    }
    if (raw is Map) {
      final values = raw.values.whereType<int>().toList(growable: false);
      if (values.isNotEmpty) return _decodeRemarkBytes(values);
    }
    if (raw is String) {
      if (raw.isEmpty) return null;
      if (RegExp(r'^0x(?:[0-9a-fA-F]{2})*$').hasMatch(raw)) {
        return _decodeRemarkBytes(_hexDecode(raw));
      }
      return raw;
    }
    return '$raw';
  }

  static String? _decodeRemarkBytes(List<int> bytes) =>
      bytes.isEmpty ? null : utf8.decode(bytes, allowMalformed: true);

  static Uint8List _buildStorageValueKey(String pallet, String storage) {
    final palletHash = Hasher.twoxx128.hashString(pallet);
    final storageHash = Hasher.twoxx128.hashString(storage);
    return Uint8List(palletHash.length + storageHash.length)
      ..setAll(0, palletHash)
      ..setAll(palletHash.length, storageHash);
  }

  static Uint8List _hexDecode(String value) {
    final hex = value.startsWith('0x') ? value.substring(2) : value;
    if (hex.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(hex)) {
      throw const FormatException('remark hex 无效');
    }
    return Uint8List.fromList(<int>[
      for (var offset = 0; offset < hex.length; offset += 2)
        int.parse(hex.substring(offset, offset + 2), radix: 16),
    ]);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
