import 'package:meta/meta.dart';

enum TransactionStatusKind {
  ready,
  broadcast,
  inBlock,
  finalized,
  future,
  invalid,
  dropped,
  usurped,
  retracted,
  finalityTimeout,
  timeout,
  error,
  unknown,
}

@immutable
final class TransactionStatus {
  const TransactionStatus({
    required this.kind,
    required this.description,
    required this.raw,
    this.blockHash,
  });

  final TransactionStatusKind kind;
  final String description;
  final String raw;
  final String? blockHash;

  bool get isIncluded =>
      kind == TransactionStatusKind.inBlock ||
      kind == TransactionStatusKind.finalized;

  /// dropped/future/retracted 仍可能在其它 peer 传播，不能当作链上终局失败。
  bool get isDefinitiveFailure =>
      kind == TransactionStatusKind.invalid ||
      kind == TransactionStatusKind.usurped;

  factory TransactionStatus.fromRpc(Object? value) {
    if (value is String) {
      final kind = switch (value) {
        'ready' => TransactionStatusKind.ready,
        'broadcast' => TransactionStatusKind.broadcast,
        'future' => TransactionStatusKind.future,
        'invalid' => TransactionStatusKind.invalid,
        'dropped' => TransactionStatusKind.dropped,
        'finalityTimeout' => TransactionStatusKind.finalityTimeout,
        _ => TransactionStatusKind.unknown,
      };
      return TransactionStatus(
        kind: kind,
        description: _description(kind),
        raw: value,
      );
    }
    if (value is Map) {
      for (final entry in const <(String, TransactionStatusKind)>[
        ('inBlock', TransactionStatusKind.inBlock),
        ('finalized', TransactionStatusKind.finalized),
        ('broadcast', TransactionStatusKind.broadcast),
        ('future', TransactionStatusKind.future),
        ('invalid', TransactionStatusKind.invalid),
        ('dropped', TransactionStatusKind.dropped),
        ('usurped', TransactionStatusKind.usurped),
        ('retracted', TransactionStatusKind.retracted),
        ('finalityTimeout', TransactionStatusKind.finalityTimeout),
      ]) {
        if (value.containsKey(entry.$1)) {
          final blockHash =
              entry.$2 == TransactionStatusKind.inBlock ||
                  entry.$2 == TransactionStatusKind.finalized
              ? _normalizeHash(value[entry.$1])
              : null;
          return TransactionStatus(
            kind: entry.$2,
            description: _description(entry.$2),
            raw: '$value',
            blockHash: blockHash,
          );
        }
      }
    }
    return TransactionStatus(
      kind: TransactionStatusKind.unknown,
      description: '$value',
      raw: '$value',
    );
  }

  static String _description(TransactionStatusKind kind) => switch (kind) {
    TransactionStatusKind.ready => '交易已进入交易池',
    TransactionStatusKind.broadcast => '交易已广播给 peer',
    TransactionStatusKind.inBlock => '交易已进入区块',
    TransactionStatusKind.finalized => '交易已经最终确认',
    TransactionStatusKind.future => 'nonce 尚未就绪，交易暂留',
    TransactionStatusKind.invalid => '交易无效',
    TransactionStatusKind.dropped => '当前交易池停止跟踪该交易',
    TransactionStatusKind.usurped => '交易被同 nonce 的另一笔交易替代',
    TransactionStatusKind.retracted => '交易所在区块被回退',
    TransactionStatusKind.finalityTimeout => '最终化等待超时',
    TransactionStatusKind.timeout => '交易状态等待超时',
    TransactionStatusKind.error => '交易状态订阅异常',
    TransactionStatusKind.unknown => '未知交易状态',
  };

  static String? _normalizeHash(Object? value) {
    if (value == null || '$value'.isEmpty) return null;
    final text = '$value';
    return text.startsWith('0x') ? text : '0x$text';
  }
}

typedef TransactionStatusCallback = void Function(TransactionStatus status);

@immutable
final class SubmittedTransaction {
  const SubmittedTransaction({required this.txHash, required this.usedNonce});

  final String txHash;
  final int usedNonce;
}

@immutable
final class IncludedTransaction {
  const IncludedTransaction({
    required this.txHash,
    required this.usedNonce,
    required this.blockHash,
    required this.finalized,
  });

  final String txHash;
  final int usedNonce;
  final String blockHash;
  final bool finalized;
}
