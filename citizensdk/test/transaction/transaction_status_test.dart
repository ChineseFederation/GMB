import 'package:citizen_sdk/src/transaction/transaction_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('交易池状态的终局语义', () {
    test('只有 invalid 与 usurped 是确定的交易池失败', () {
      for (final kind in <TransactionStatusKind>[
        TransactionStatusKind.invalid,
        TransactionStatusKind.usurped,
      ]) {
        expect(
          TransactionStatus(
            kind: kind,
            description: kind.name,
            raw: kind.name,
          ).isDefinitiveFailure,
          isTrue,
        );
      }
    });

    test('dropped/future/retracted/订阅错误必须继续最终对账', () {
      for (final kind in <TransactionStatusKind>[
        TransactionStatusKind.future,
        TransactionStatusKind.dropped,
        TransactionStatusKind.retracted,
        TransactionStatusKind.finalityTimeout,
        TransactionStatusKind.timeout,
        TransactionStatusKind.error,
      ]) {
        expect(
          TransactionStatus(
            kind: kind,
            description: kind.name,
            raw: kind.name,
          ).isDefinitiveFailure,
          isFalse,
        );
      }
    });

    test('inBlock/finalized 不伪装成 runtime executionSuccess', () {
      for (final kind in <TransactionStatusKind>[
        TransactionStatusKind.inBlock,
        TransactionStatusKind.finalized,
      ]) {
        final status = TransactionStatus(
          kind: kind,
          description: kind.name,
          raw: kind.name,
          blockHash: _hash,
        );
        expect(status.isIncluded, isTrue);
        expect(status.isExecutionSuccess, isFalse);
      }

      const executed = TransactionStatus(
        kind: TransactionStatusKind.executionSuccess,
        description: 'success',
        raw: 'System.ExtrinsicSuccess',
        blockHash: _hash,
        extrinsicIndex: 3,
      );
      expect(executed.isIncluded, isTrue);
      expect(executed.isExecutionSuccess, isTrue);
    });
  });

  group('RPC TransactionStatus 解码', () {
    test('保留 inBlock/finalized 的区块哈希', () {
      final inBlock = TransactionStatus.fromRpc(<String, Object?>{
        'inBlock': _hash.substring(2),
      });
      final finalized = TransactionStatus.fromRpc(<String, Object?>{
        'finalized': _hash,
      });

      expect(inBlock.kind, TransactionStatusKind.inBlock);
      expect(inBlock.blockHash, _hash);
      expect(finalized.kind, TransactionStatusKind.finalized);
      expect(finalized.blockHash, _hash);
    });

    test('未知字符串与未知 map 不被猜测为成功', () {
      final unknownStatus = <String>['unexpected', 'status'].join('_');
      expect(
        TransactionStatus.fromRpc(unknownStatus).kind,
        TransactionStatusKind.unknown,
      );
      expect(
        TransactionStatus.fromRpc(<String, Object?>{unknownStatus: true}).kind,
        TransactionStatusKind.unknown,
      );
    });

    test('入块状态携带的非 32 字节哈希必须拒绝', () {
      expect(
        () => TransactionStatus.fromRpc(<String, Object?>{'inBlock': '0x1234'}),
        throwsFormatException,
      );
    });
  });
}

const _hash =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
