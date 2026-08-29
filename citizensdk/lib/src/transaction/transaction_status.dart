import 'package:meta/meta.dart';

enum TransactionStatusKind {
  ready,
  broadcast,
  inBlock,
  finalized,
  executionSuccess,
  executionFailed,
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
    this.extrinsicIndex,
    this.dispatchFailure,
  });

  final TransactionStatusKind kind;
  final String description;
  final String raw;
  final String? blockHash;
  final int? extrinsicIndex;
  final ChainExtrinsicFailure? dispatchFailure;

  bool get isIncluded =>
      kind == TransactionStatusKind.inBlock ||
      kind == TransactionStatusKind.finalized ||
      kind == TransactionStatusKind.executionSuccess ||
      kind == TransactionStatusKind.executionFailed;

  /// 只有核对同一 extrinsic 的 `System.ExtrinsicSuccess` 后才为真。
  bool get isExecutionSuccess => kind == TransactionStatusKind.executionSuccess;

  /// dropped/future/retracted 仍可能在其它 peer 传播，不能当作链上终局失败。
  bool get isDefinitiveFailure =>
      kind == TransactionStatusKind.invalid ||
      kind == TransactionStatusKind.usurped ||
      kind == TransactionStatusKind.executionFailed;

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
    TransactionStatusKind.executionSuccess => '链上交易执行成功',
    TransactionStatusKind.executionFailed => '链上交易执行失败',
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
    final normalized = text.startsWith('0x') ? text : '0x$text';
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(normalized)) {
      throw const FormatException('交易状态的区块哈希无效');
    }
    return normalized.toLowerCase();
  }
}

typedef TransactionStatusCallback = void Function(TransactionStatus status);

/// `System.ExtrinsicFailed` 携带的 runtime dispatch error。
///
/// [dispatchErrorVariant] 是 `sp_runtime::DispatchError` 的 SCALE variant。
/// Module 错误时 [moduleIndex] 与 [errorIndex] 分别是 pallet 索引和
/// pallet 内错误索引；其它 variant 不伪造 module 信息。
@immutable
final class ChainExtrinsicFailure {
  const ChainExtrinsicFailure({
    required this.dispatchErrorVariant,
    required this.description,
    this.moduleIndex,
    this.errorIndex,
  });

  final int dispatchErrorVariant;
  final int? moduleIndex;
  final int? errorIndex;
  final String description;
}

enum ChainExtrinsicOutcomeKind { success, failed }

/// 在目标区块的 `System.Events` 中对同一 extrinsic 的执行结果。
@immutable
final class ChainExtrinsicOutcome {
  const ChainExtrinsicOutcome.success()
    : kind = ChainExtrinsicOutcomeKind.success,
      failure = null;

  const ChainExtrinsicOutcome.failed(this.failure)
    : kind = ChainExtrinsicOutcomeKind.failed;

  final ChainExtrinsicOutcomeKind kind;
  final ChainExtrinsicFailure? failure;

  bool get isSuccess => kind == ChainExtrinsicOutcomeKind.success;
}

/// extrinsic 已入块，但 runtime 执行返回 `ExtrinsicFailed`。
final class TransactionDispatchException implements Exception {
  const TransactionDispatchException({
    required this.txHash,
    required this.blockHash,
    required this.extrinsicIndex,
    required this.failure,
  });

  final String txHash;
  final String blockHash;
  final int extrinsicIndex;
  final ChainExtrinsicFailure failure;

  @override
  String toString() => failure.description;
}

/// 已收到入块锚，但在受控重试窗口内无法取得可证明的执行结果。
final class TransactionExecutionUnverifiedException implements Exception {
  const TransactionExecutionUnverifiedException({
    required this.txHash,
    required this.blockHash,
    required this.description,
    this.cause,
  });

  final String txHash;
  final String blockHash;
  final String description;
  final Object? cause;

  @override
  String toString() => cause == null ? description : '$description：$cause';
}

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
    required this.extrinsicIndex,
    required this.executionVerified,
  });

  final String txHash;
  final int usedNonce;
  final String blockHash;
  final bool finalized;
  final int extrinsicIndex;

  /// 为真表示已精确匹配 txHash，并读到同一 extrinsic 的
  /// `System.ExtrinsicSuccess`；不会用“未找到失败”猜测成功。
  final bool executionVerified;
}
