import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/platform/preferences_data_store.dart';
import 'package:citizen_sdk/src/platform/preferences_finalized_transaction_repository.dart';
import 'package:citizen_sdk/src/transaction/chain_rpc.dart';
import 'package:citizen_sdk/src/transaction/finalized_transaction_models.dart';
import 'package:citizen_sdk/src/transaction/finalized_transaction_repository.dart';
import 'package:citizen_sdk/src/transaction/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/polkadart.dart' show Hasher;

void main() {
  test('transfer_with_remark call 保持 pallet/call 与 u128 分单位', () {
    final call = TransferService.buildTransferWithRemarkCall(
      destinationPublicKey: Uint8List.fromList(
        List<int>.generate(32, (i) => i),
      ),
      amountFen: BigInt.from(100),
      remark: 'hi',
    );
    expect(call[0], 4);
    expect(call[1], 0);
    expect(
      call.sublist(2, 34),
      orderedEquals(List<int>.generate(32, (i) => i)),
    );
    expect(call[34], 100);
    expect(call[35], 0);
    expect(call[50], 8); // Compact(2) = 2 << 2
    expect(call.sublist(51), orderedEquals(<int>[0x68, 0x69]));
  });

  test('备注超 99 字节与非正金额必须拒绝', () {
    expect(
      () => TransferService.buildTransferWithRemarkCall(
        destinationPublicKey: Uint8List(32),
        amountFen: BigInt.one,
        remark: List<String>.filled(100, 'a').join(),
      ),
      throwsArgumentError,
    );
    expect(
      () => TransferService.buildTransferWithRemarkCall(
        destinationPublicKey: Uint8List(32),
        amountFen: BigInt.zero,
        remark: '',
      ),
      throwsArgumentError,
    );
  });

  test('备注限制按 UTF-8 字节而不是 Dart 字符数计算', () {
    expect(
      () => TransferService.buildTransferWithRemarkCall(
        destinationPublicKey: Uint8List(32),
        amountFen: BigInt.one,
        remark: List<String>.filled(34, '中').join(),
      ),
      throwsArgumentError,
    );
    final accepted = TransferService.buildTransferWithRemarkCall(
      destinationPublicKey: Uint8List(32),
      amountFen: BigInt.one,
      remark: List<String>.filled(33, '中').join(),
    );
    expect(accepted[50], 0x8d); // Compact(99) little-endian 的第一字节。
    expect(accepted[51], 0x01);
  });

  test('收款公钥长度与 u128 上界必须精确拒绝', () {
    expect(
      () => TransferService.buildTransferWithRemarkCall(
        destinationPublicKey: Uint8List(31),
        amountFen: BigInt.one,
        remark: '',
      ),
      throwsArgumentError,
    );
    expect(
      () => TransferService.buildTransferWithRemarkCall(
        destinationPublicKey: Uint8List(32),
        amountFen: BigInt.one << 128,
        remark: '',
      ),
      throwsArgumentError,
    );
  });

  group('广播前 pending 原子闭环', () {
    late Uint8List fromPublicKey;
    late Uint8List toPublicKey;
    late String fromAddress;
    late String toAddress;
    late String fromAccountId;
    late String toAccountId;

    setUp(() {
      fromPublicKey = Uint8List(32);
      toPublicKey = Uint8List.fromList(<int>[1, ...List<int>.filled(31, 0)]);
      fromAccountId = citizenAccountIdFromBytes(fromPublicKey);
      toAccountId = citizenAccountIdFromBytes(toPublicKey);
      fromAddress = citizenSs58FromAccountId(fromAccountId);
      toAddress = citizenSs58FromAccountId(toAccountId);
    });

    test('广播调用发生前 txHash/nonce/转账事实已经持久化', () async {
      final preferences = _TransferMemoryPreferences();
      final history = FinalizedTransactionHistory(
        repository: PreferencesFinalizedTransactionRepository(
          preferences: preferences,
        ),
      );
      late final _TransferTransport transport;
      var sawPendingBeforeSubmit = false;
      transport = _TransferTransport(
        onSubmit: () async {
          final state = await history.load();
          sawPendingBeforeSubmit =
              state.submissions.values.single.status ==
              PendingSubmittedTransactionStatus.pending;
        },
      );
      final service = TransferService(
        ChainRpc.withTransport(transport),
        transactionHistory: history,
      );

      final submitted = await service.transferWithRemark(
        fromSs58Address: fromAddress,
        signerPublicKey: fromPublicKey,
        toSs58Address: toAddress,
        amountFen: BigInt.from(123),
        remark: 'fixture',
        sign: (_) async => Uint8List(64),
        watchTimeout: Duration.zero,
      );

      expect(sawPendingBeforeSubmit, isTrue);
      expect(transport.submitCalls, 1);
      final pending = (await history.load()).submissions.values.single;
      expect(pending.txHash, submitted.txHash);
      expect(pending.usedNonce, 7);
      expect(pending.accountId, fromAccountId);
      expect(pending.toAccountId, toAccountId);
      expect(pending.amountFen, BigInt.from(123));
      expect(pending.remark, 'fixture');
    });

    test('pending 写入后平台抛错但完整回读一致时仍广播且无孤儿窗口', () async {
      final preferences = _TransferMemoryPreferences()..throwAfterWrite = true;
      final history = FinalizedTransactionHistory(
        repository: PreferencesFinalizedTransactionRepository(
          preferences: preferences,
        ),
      );
      final transport = _TransferTransport();
      final service = TransferService(
        ChainRpc.withTransport(transport),
        transactionHistory: history,
      );

      await service.transferWithRemark(
        fromSs58Address: fromAddress,
        signerPublicKey: fromPublicKey,
        toSs58Address: toAddress,
        amountFen: BigInt.one,
        remark: '',
        sign: (_) async => Uint8List(64),
        watchTimeout: Duration.zero,
      );

      expect(transport.submitCalls, 1);
      expect((await history.load()).submissions, hasLength(1));
    });

    test('pending 真实未写入时禁止广播', () async {
      final preferences = _TransferMemoryPreferences()
        ..throwWithoutWrite = true;
      final history = FinalizedTransactionHistory(
        repository: PreferencesFinalizedTransactionRepository(
          preferences: preferences,
        ),
      );
      final transport = _TransferTransport();
      final service = TransferService(
        ChainRpc.withTransport(transport),
        transactionHistory: history,
      );

      await expectLater(
        service.transferWithRemark(
          fromSs58Address: fromAddress,
          signerPublicKey: fromPublicKey,
          toSs58Address: toAddress,
          amountFen: BigInt.one,
          remark: '',
          sign: (_) async => Uint8List(64),
          watchTimeout: Duration.zero,
        ),
        throwsStateError,
      );
      expect(transport.submitCalls, 0);
      expect((await history.load()).submissions, isEmpty);
    });

    test('invalid/usurped 保存 poolRejected；finalized 只保存锚不冒充成功', () async {
      for (final status in <Object?>[
        'invalid',
        <String, Object?>{'usurped': _hash(0x91)},
      ]) {
        final history = FinalizedTransactionHistory(
          repository: PreferencesFinalizedTransactionRepository(
            preferences: _TransferMemoryPreferences(),
          ),
        );
        final service = TransferService(
          ChainRpc.withTransport(_TransferTransport(events: <Object?>[status])),
          transactionHistory: history,
        );
        await service.transferWithRemark(
          fromSs58Address: fromAddress,
          signerPublicKey: fromPublicKey,
          toSs58Address: toAddress,
          amountFen: BigInt.one,
          remark: '',
          sign: (_) async => Uint8List(64),
          watchTimeout: const Duration(seconds: 1),
        );
        await _waitForHistory(
          history,
          (value) =>
              value.status == PendingSubmittedTransactionStatus.poolRejected,
        );
      }

      final history = FinalizedTransactionHistory(
        repository: PreferencesFinalizedTransactionRepository(
          preferences: _TransferMemoryPreferences(),
        ),
      );
      final anchor = _hash(0x77);
      final service = TransferService(
        ChainRpc.withTransport(
          _TransferTransport(
            events: <Object?>[
              <String, Object?>{'finalized': anchor},
            ],
          ),
        ),
        transactionHistory: history,
      );
      await service.transferWithRemark(
        fromSs58Address: fromAddress,
        signerPublicKey: fromPublicKey,
        toSs58Address: toAddress,
        amountFen: BigInt.one,
        remark: '',
        sign: (_) async => Uint8List(64),
        watchTimeout: const Duration(seconds: 1),
        executionLookupTimeout: Duration.zero,
        executionRetryInterval: Duration.zero,
      );
      final anchored = await _waitForHistory(
        history,
        (value) => value.anchorBlockHash == anchor,
      );
      expect(anchored.status, PendingSubmittedTransactionStatus.inBlock);
      expect(anchored.isTerminal, isFalse);
    });
  });
}

final class _TransferTransport implements ChainRpcTransport {
  _TransferTransport({this.onSubmit, this.events = const <Object?>[]})
    : _metadata = File(
        'test/transaction/fixtures/substrate-v14-system-events-metadata.hex',
      ).readAsStringSync().trim();

  final Future<void> Function()? onSubmit;
  final List<Object?> events;
  final String _metadata;
  int submitCalls = 0;

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<int> accountNextIndex(String accountIdHex) async => 7;

  @override
  Future<Map<String, dynamic>> runtimeVersion() async => _runtimeVersion();

  @override
  Future<String> blockHash(int blockNumber) async => _hash(0x01);

  @override
  Future<String> metadataHex() async => _metadata;

  @override
  Future<String?> finalizedStorage(String storageKeyHex) async => null;

  @override
  Future<Map<String, String?>> finalizedStorageValues(
    List<String> storageKeyHexList,
  ) async => <String, String?>{for (final key in storageKeyHexList) key: null};

  @override
  Future<String> submitExtrinsic(String extrinsicHex) async {
    final callback = onSubmit;
    if (callback != null) await callback();
    submitCalls += 1;
    return '0x${_hex(Hasher.blake2b256.hash(_hexDecode(extrinsicHex)))}';
  }

  @override
  Future<List<String>> blockExtrinsicsOnce(String blockHashHex) async =>
      const <String>[];

  @override
  Future<Object?> request(String method, List<Object?> params) async {
    switch (method) {
      case 'chain_getBlockHash':
        return _hash(0x02);
      case 'state_getRuntimeVersion':
        return _runtimeVersion();
      case 'state_getMetadata':
        return _metadata;
      case 'state_getStorage':
        return null;
      case 'chain_getHeader':
        return const <String, Object?>{'number': '0x1'};
    }
    throw StateError('未预期 RPC：$method');
  }

  @override
  Stream<Object?> subscribe(String method, List<Object?> params) =>
      Stream<Object?>.fromIterable(events);
}

final class _TransferMemoryPreferences implements PreferencesDataStore {
  final Map<String, String> values = <String, String>{};
  bool throwAfterWrite = false;
  bool throwWithoutWrite = false;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (throwWithoutWrite) throw StateError('write rejected');
    values[key] = value;
    if (throwAfterWrite) throw StateError('late write error');
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

Future<PendingSubmittedTransaction> _waitForHistory(
  FinalizedTransactionHistory history,
  bool Function(PendingSubmittedTransaction value) predicate,
) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    final values = (await history.load()).submissions.values;
    if (values.isNotEmpty && predicate(values.single)) return values.single;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  throw StateError('等待 pending 状态超时');
}

Map<String, dynamic> _runtimeVersion() => <String, dynamic>{
  'specName': 'citizen',
  'implName': 'citizen',
  'authoringVersion': 1,
  'specVersion': 1,
  'implVersion': 1,
  'apis': <Object?>[],
  'transactionVersion': 1,
  'stateVersion': 1,
};

String _hash(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List _hexDecode(String value) {
  final hex = value.startsWith('0x') ? value.substring(2) : value;
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < hex.length; offset += 2)
      int.parse(hex.substring(offset, offset + 2), radix: 16),
  ]);
}
