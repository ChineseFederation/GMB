import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/transaction/chain_rpc.dart';
import 'package:citizen_sdk/src/transaction/signed_extrinsic_builder.dart';
import 'package:citizen_sdk/src/transaction/transaction_status.dart';
import 'package:citizen_sdk/src/transaction/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:polkadart_keyring/polkadart_keyring.dart' show Keyring;

const _constantMetadataHex =
    '0x6d6574610e100000000507000400000500000800000400000c000005050008484f'
    '6e636861696e5472616e73616374696f6e00000008344f6e636861696e4d696e46'
    '656500400a00000000000000000000000000000000384f6e636861696e46656552'
    '6174650c1040420f000000002042616c616e63657300000008484578697374656e'
    '7469616c4465706f73697400406f0000000000000000000000000000000020536f'
    '6d65466c616704040100000108040008';

const _constantMetadataWithoutFeeRateHex =
    '0x6d6574610e0c00000005070004000005000008000004000008484f6e636861696e'
    '5472616e73616374696f6e00000004344f6e636861696e4d696e46656500400a00'
    '00000000000000000000000000000000002042616c616e63657300000008484578'
    '697374656e7469616c4465706f73697400406f0000000000000000000000000000'
    '000020536f6d65466c616704040100000108040008';

// 真实 v14 metadata 带有 System.Event、Phase、DispatchInfo 与 topics 类型；
// 正式执行确认测试不得再使用只有常量、无法解码 EventRecord 的最小 metadata。
final _eventMetadataHex = File(
  'test/transaction/fixtures/substrate-v14-system-events-metadata.hex',
).readAsStringSync().trim();

void main() {
  group('CitizenApp 交易真源行为', () {
    test('runtime context 在同一块绑定 metadata 并按 specVersion 自动换代', () async {
      final oldBlock = _hash(0x41);
      final newBlock = _hash(0x42);
      final transport = _FakeTransport(
        bestHead: oldBlock,
        runtimeVersionsByBlock: <String, Map<String, dynamic>>{
          oldBlock: _runtimeVersionJson(1, 3),
          newBlock: _runtimeVersionJson(2, 4),
        },
        metadataByBlock: <String, String>{
          oldBlock: _constantMetadataHex,
          newBlock: _eventMetadataHex,
        },
      );
      final rpc = ChainRpc.withTransport(transport);

      final oldContext = await rpc.fetchRuntimeContext();
      transport.bestHead = newBlock;
      final newContext = await rpc.fetchRuntimeContext();
      final cachedNewContext = await rpc.fetchRuntimeContext();

      expect(oldContext.blockHash, oldBlock);
      expect(oldContext.runtimeVersion.specVersion, 1);
      expect(oldContext.runtimeVersion.transactionVersion, 3);
      expect(newContext.blockHash, newBlock);
      expect(newContext.runtimeVersion.specVersion, 2);
      expect(newContext.runtimeVersion.transactionVersion, 4);
      expect(cachedNewContext.runtimeVersion.specVersion, 2);
      expect(transport.runtimeVersionBlockRequests, <String>[
        oldBlock,
        newBlock,
        newBlock,
      ]);
      expect(transport.metadataBlockRequests, <String>[oldBlock, newBlock]);
      expect(transport.metadataCalls, 2);
    });

    test('独立 runtime version 读取不被 metadata 永不完成阻塞', () async {
      final blockHash = _hash(0x40);
      final transport = _FakeTransport(
        bestHead: blockHash,
        runtimeVersionsByBlock: <String, Map<String, dynamic>>{
          blockHash: _runtimeVersionJson(8, 11),
        },
        metadataFuture: Completer<String>().future,
      );
      final rpc = ChainRpc.withTransport(transport);

      final version = await rpc.fetchRuntimeVersion().timeout(
        const Duration(milliseconds: 100),
      );

      expect(version.specVersion, 8);
      expect(version.transactionVersion, 11);
      expect(transport.runtimeVersionBlockRequests, <String>[blockHash]);
      expect(transport.metadataBlockRequests, isEmpty);
      expect(transport.metadataCalls, 0);
    });

    test('前一代 spec metadata in-flight 迟到不得覆盖新 runtime 缓存', () async {
      final oldBlock = _hash(0x43);
      final newBlock = _hash(0x44);
      final oldMetadata = Completer<String>();
      final transport = _FakeTransport(
        bestHead: oldBlock,
        runtimeVersionsByBlock: <String, Map<String, dynamic>>{
          oldBlock: _runtimeVersionJson(1, 1),
          newBlock: _runtimeVersionJson(2, 2),
        },
        metadataFuture: oldMetadata.future,
      );
      final rpc = ChainRpc.withTransport(transport);

      final oldContextFuture = rpc.fetchRuntimeContext();
      while (transport.metadataCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      transport.bestHead = newBlock;
      transport.metadataFuture = Future<String>.value(_constantMetadataHex);
      final newContext = await rpc.fetchRuntimeContext();
      oldMetadata.complete(_eventMetadataHex);
      final oldContext = await oldContextFuture;

      expect(oldContext.runtimeVersion.specVersion, 1);
      expect(newContext.runtimeVersion.specVersion, 2);
      expect(transport.metadataCalls, 2);

      // 若迟到的前一代 Future 倒灌为 spec=1，这次 spec=2 会错误地再拉 metadata。
      transport.metadataFuture = Completer<String>().future;
      final stillNew = await rpc.fetchRuntimeContext().timeout(
        const Duration(milliseconds: 100),
      );
      expect(stillNew.runtimeVersion.specVersion, 2);
      expect(transport.metadataCalls, 2);
    });

    test('手续费的费率与最低费始终来自同一个 runtime context', () async {
      final oldBlock = _hash(0x45);
      final newBlock = _hash(0x46);
      late final _FakeTransport transport;
      transport = _FakeTransport(
        bestHead: oldBlock,
        runtimeVersionsByBlock: <String, Map<String, dynamic>>{
          oldBlock: _runtimeVersionJson(1, 1),
          newBlock: _runtimeVersionJson(2, 2),
        },
        metadataByBlock: <String, String>{
          oldBlock: _feePolicyMetadataHex(
            feeRateParts: 1000000,
            minimumFeeFen: BigInt.from(10),
          ),
          newBlock: _feePolicyMetadataHex(
            feeRateParts: 2000000,
            minimumFeeFen: BigInt.from(17),
          ),
        },
        onRuntimeVersionRequest: (blockHash) {
          if (blockHash == oldBlock) transport.bestHead = newBlock;
        },
      );
      final rpc = ChainRpc.withTransport(transport);

      expect(
        await rpc.estimateOnchainTransactionFeeFen(BigInt.from(50000)),
        BigInt.from(50),
      );
      expect(
        await rpc.estimateOnchainTransactionFeeFen(BigInt.from(50000)),
        BigInt.from(100),
      );
      expect(transport.metadataBlockRequests, <String>[oldBlock, newBlock]);
    });

    test('SignedExtrinsicBuilder 使用同一块的 registry 与 runtime 版本', () async {
      final blockHash = _hash(0x47);
      final publicKey = Uint8List(32);
      final address = citizenSs58FromAccountId(
        citizenAccountIdFromBytes(publicKey),
      );
      final transport = _FakeTransport(
        bestHead: blockHash,
        runtimeVersionsByBlock: <String, Map<String, dynamic>>{
          blockHash: _runtimeVersionJson(7, 9),
        },
        metadataByBlock: <String, String>{blockHash: _eventMetadataHex},
      );
      final rpc = ChainRpc.withTransport(transport);
      SignedExtrinsicTrace? trace;

      await SignedExtrinsicBuilder(rpc).signAndSubmit(
        callData: Uint8List.fromList(<int>[4, 0]),
        fromSs58Address: address,
        signerPublicKey: publicKey,
        sign: (_) async => Uint8List(64),
        onTrace: (value) => trace = value,
      );

      expect(trace, isNotNull);
      expect(trace!.runtimeVersion.specVersion, 7);
      expect(trace!.runtimeVersion.transactionVersion, 9);
      expect(transport.runtimeVersionBlockRequests, <String>[blockHash]);
      expect(transport.metadataBlockRequests, <String>[blockHash]);
    });

    test('metadata 真实 SCALE 常量解码不使用本地默认值', () async {
      final rpc = ChainRpc.withTransport(
        _FakeTransport(metadataHex: _constantMetadataHex),
      );

      expect(
        await rpc.fetchPalletConstantU128(
          'OnchainTransaction',
          'OnchainMinFee',
        ),
        BigInt.from(10),
      );
      expect(
        await rpc.fetchPalletConstantU128('Balances', 'ExistentialDeposit'),
        BigInt.from(111),
      );
      expect(
        await rpc.fetchPalletConstantU32(
          'OnchainTransaction',
          'OnchainFeeRate',
        ),
        1000000,
      );
      expect(await rpc.fetchMinimumSelfPayBalanceFen(), BigInt.from(121));
      await expectLater(
        rpc.fetchPalletConstant('Balances', 'Missing'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        rpc.fetchPalletConstantU128('Balances', 'SomeFlag'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        rpc.fetchPalletConstantU32('Balances', 'SomeFlag'),
        throwsA(isA<StateError>()),
      );
    });

    test('转账手续费以 BigInt 分复现 runtime 最低费、half-up 与 u128 上界', () async {
      final service = TransferService(
        ChainRpc.withTransport(
          _FakeTransport(metadataHex: _constantMetadataHex),
        ),
      );
      final u128Max = (BigInt.one << 128) - BigInt.one;

      expect(
        await service.estimateTransferFeeFen(BigInt.zero),
        BigInt.from(10),
      );
      expect(
        await service.estimateTransferFeeFen(BigInt.from(499)),
        BigInt.from(10),
      );
      expect(
        await service.estimateTransferFeeFen(BigInt.from(10499)),
        BigInt.from(10),
      );
      expect(
        await service.estimateTransferFeeFen(BigInt.from(10500)),
        BigInt.from(11),
      );
      expect(
        await service.estimateTransferFeeFen(BigInt.from(50000)),
        BigInt.from(50),
      );
      expect(
        await service.estimateTransferFeeFen(u128Max),
        BigInt.parse('340282366920938463463374607431768211'),
      );

      final fullRateService = TransferService(
        ChainRpc.withTransport(
          _FakeTransport(
            metadataHex: _feePolicyMetadataHex(feeRateParts: 1000000000),
          ),
        ),
      );
      expect(await fullRateService.estimateTransferFeeFen(u128Max), u128Max);
    });

    test('手续费参数逐次来自 metadata 而不是本地硬编码', () async {
      final service = TransferService(
        ChainRpc.withTransport(
          _FakeTransport(
            metadataHex: _feePolicyMetadataHex(
              feeRateParts: 2000000,
              minimumFeeFen: BigInt.from(17),
            ),
          ),
        ),
      );

      expect(
        await service.estimateTransferFeeFen(BigInt.zero),
        BigInt.from(17),
      );
      expect(
        await service.estimateTransferFeeFen(BigInt.from(50000)),
        BigInt.from(100),
      );
    });

    test('手续费 metadata 缺失、类型或协议范围错误全部失败关闭', () async {
      final invalidMetadata = <String>[
        _constantMetadataWithoutFeeRateHex,
        _feeRateBooleanMetadataHex(),
        _feePolicyMetadataHex(feeRateParts: 0),
        _feePolicyMetadataHex(feeRateParts: 1000000001),
        _feePolicyMetadataHex(minimumFeeFen: BigInt.zero),
      ];
      for (final metadataHex in invalidMetadata) {
        final service = TransferService(
          ChainRpc.withTransport(_FakeTransport(metadataHex: metadataHex)),
        );
        await expectLater(
          service.estimateTransferFeeFen(BigInt.from(50000)),
          throwsA(isA<StateError>()),
        );
      }
    });

    test('手续费估算拒绝负数和超出 u128 的金额', () async {
      final service = TransferService(
        ChainRpc.withTransport(
          _FakeTransport(metadataHex: _constantMetadataHex),
        ),
      );
      for (final amountFen in <BigInt>[-BigInt.one, BigInt.one << 128]) {
        await expectLater(
          service.estimateTransferFeeFen(amountFen),
          throwsArgumentError,
        );
      }
    });

    test(
      'finalized System.Account 一次解码 BigInt free、reserved 与 total',
      () async {
        final accountId = '0x${List<String>.filled(64, '1').join()}';
        final address = citizenSs58FromAccountId(accountId);
        final freeFen = BigInt.parse('900719925474099312345');
        final reservedFen = BigInt.parse('18446744073709551617');
        final transport = _FakeTransport(
          finalizedStorageResponses: <String?>[
            _accountInfoHex(freeFen: freeFen, reservedFen: reservedFen),
            _accountInfoHex(freeFen: freeFen, reservedFen: reservedFen),
            _accountInfoHex(freeFen: freeFen, reservedFen: reservedFen),
          ],
        );
        final rpc = ChainRpc.withTransport(transport);

        final balance = await rpc.fetchFinalizedAccountBalance(accountId);

        expect(balance.requestedAccount, accountId);
        expect(balance.accountId, accountId);
        expect(balance.freeFen, freeFen);
        expect(balance.reservedFen, reservedFen);
        expect(balance.totalFen, freeFen + reservedFen);
        expect(
          await rpc.fetchFinalizedTotalBalanceFen(address),
          freeFen + reservedFen,
        );
        expect(await rpc.fetchFinalizedBalanceFen(accountId), freeFen);
        expect(transport.finalizedStorageKeys, hasLength(3));
        expect(
          transport.finalizedStorageKeys[0],
          transport.finalizedStorageKeys[1],
          reason: '同一账户的 AccountId 与 SS58 必须落到同一 storage key',
        );
        expect(
          transport.finalizedStorageKeys[1],
          transport.finalizedStorageKeys[2],
        );
      },
    );

    test('finalized System.Account 不存在或短数据统一返回零余额', () async {
      final first = '0x${List<String>.filled(64, '2').join()}';
      final second = '0x${List<String>.filled(64, '3').join()}';
      final transport = _FakeTransport(
        finalizedStorageResponses: <String?>[null, '0x${_hex(Uint8List(47))}'],
      );
      final rpc = ChainRpc.withTransport(transport);

      final balances = await rpc.fetchFinalizedAccountBalances(<String>[
        first,
        second,
      ]);

      expect(balances, hasLength(2));
      for (final balance in balances) {
        expect(balance.freeFen, BigInt.zero);
        expect(balance.reservedFen, BigInt.zero);
        expect(balance.totalFen, BigInt.zero);
      }
      expect(transport.finalizedStorageBatchCalls, 1);
      expect(transport.finalizedStorageKeys, isEmpty);
      expect(transport.finalizedStorageBatchKeys.single, hasLength(2));
    });

    test('批量 finalized 逐项读取并按原始键顺序保留重复账户', () async {
      final first = '0x${List<String>.filled(64, '4').join()}';
      final second = '0x${List<String>.filled(64, '5').join()}';
      final secondSs58 = citizenSs58FromAccountId(second);
      final inputs = <String>[first, secondSs58, first];
      final responses = <String?>[
        _accountInfoHex(freeFen: BigInt.one, reservedFen: BigInt.from(10)),
        _accountInfoHex(freeFen: BigInt.two, reservedFen: BigInt.from(20)),
      ];
      final transport = _FakeTransport(finalizedStorageResponses: responses);
      final rpc = ChainRpc.withTransport(transport);

      final balances = await rpc.fetchFinalizedAccountBalances(inputs);

      expect(
        balances.map((balance) => balance.requestedAccount),
        orderedEquals(inputs),
      );
      expect(
        balances.map((balance) => balance.accountId),
        orderedEquals(<String>[first, second, first]),
      );
      expect(
        balances.map((balance) => balance.freeFen),
        orderedEquals(<BigInt>[BigInt.one, BigInt.two, BigInt.one]),
      );
      expect(
        balances.map((balance) => balance.totalFen),
        orderedEquals(<BigInt>[
          BigInt.from(11),
          BigInt.from(22),
          BigInt.from(11),
        ]),
      );
      expect(transport.finalizedStorageBatchCalls, 1);
      expect(transport.finalizedStorageKeys, isEmpty);
      expect(transport.finalizedStorageBatchKeys.single, hasLength(2));
      expect(
        transport.finalizedStorageBatchKeys.single[0],
        isNot(transport.finalizedStorageBatchKeys.single[1]),
      );

      final freeRpc = ChainRpc.withTransport(
        _FakeTransport(finalizedStorageResponses: responses),
      );
      expect(
        await freeRpc.fetchFinalizedBalancesFen(inputs),
        orderedEquals(<BigInt>[BigInt.one, BigInt.two, BigInt.one]),
      );
      final totalRpc = ChainRpc.withTransport(
        _FakeTransport(finalizedStorageResponses: responses),
      );
      expect(
        await totalRpc.fetchFinalizedTotalBalancesFen(inputs),
        orderedEquals(<BigInt>[
          BigInt.from(11),
          BigInt.from(22),
          BigInt.from(11),
        ]),
      );
    });

    test('finalized 余额在存储读取前严格拒绝非规范 AccountId 与外链 SS58', () async {
      final transport = _FakeTransport();
      final rpc = ChainRpc.withTransport(transport);
      final uppercase = '0x${List<String>.filled(64, 'A').join()}';
      final foreignSs58 = Keyring().encodeAddress(Uint8List(32), 42);

      await expectLater(
        rpc.fetchFinalizedAccountBalance(uppercase),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        rpc.fetchFinalizedBalancesFen(<String>[foreignSs58]),
        throwsA(isA<FormatException>()),
      );
      expect(transport.finalizedStorageKeys, isEmpty);
      expect(transport.finalizedStorageBatchCalls, 0);
    });

    test('txHash 只按完整 extrinsic 的 blake2b256 定位', () {
      final first = Uint8List.fromList(<int>[1, 2, 3]);
      final target = Uint8List.fromList(<int>[4, 5, 6]);
      final targetHash = Hasher.blake2b256.hash(target);

      final index = ChainRpc.findExtrinsicIndexInHexListSync(<String>[
        '0x${_hex(first)}',
        '0x${_hex(target)}',
      ], txHashHex: '0x${_hex(targetHash)}');

      expect(index, 1);
    });
  });

  group('提交、包含与 runtime 执行确认', () {
    test('生产 CitizenChain System.Events 同时证明 index 0 成功与 index 1 失败', () async {
      final metadataHex = File(
        'test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex',
      ).readAsStringSync().trim();
      final eventsHex = File(
        'test/transaction/fixtures/citizenchain-runtime-system-events.hex',
      ).readAsStringSync().trim();
      final blockHash = _hash(0xcf);
      final rpc = ChainRpc.withTransport(
        _FakeTransport(metadataHex: metadataHex, bestHead: blockHash),
      );
      final eventsBytes = _hexBytes(eventsHex);

      final success = await rpc.findExtrinsicOutcomeAtBlock(
        eventsBytes: eventsBytes,
        extrinsicIndex: 0,
        blockHashHex: blockHash,
      );
      final failed = await rpc.findExtrinsicOutcomeAtBlock(
        eventsBytes: eventsBytes,
        extrinsicIndex: 1,
        blockHashHex: blockHash,
      );

      expect(success, isNotNull);
      expect(success!.isSuccess, isTrue);
      expect(failed, isNotNull);
      expect(failed!.isSuccess, isFalse);
      expect(failed.failure!.dispatchErrorVariant, 2);
      expect(failed.failure!.description, contains('BadOrigin'));
    });

    test('dropped 不是终局，finalized 后核对 ExtrinsicSuccess', () async {
      final encoded = Uint8List.fromList(<int>[4, 5, 6]);
      final blockHash = _hash(0xaa);
      final transport = _FakeTransport(
        events: <Object?>[
          <String, Object?>{'dropped': null},
          <String, Object?>{'inBlock': _hash(0xab)},
          <String, Object?>{'finalized': blockHash},
        ],
        blockExtrinsics: <String>['0x010203', '0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(1)])}',
        ],
      );
      final statuses = <TransactionStatus>[];
      final rpc = ChainRpc.withTransport(transport);

      final result = await rpc.submitAndWait(
        encoded,
        waitForFinalized: true,
        timeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(seconds: 1),
        executionRetryInterval: Duration.zero,
        onStatus: statuses.add,
      );

      expect(result.txHash, '0x${_hex(Hasher.blake2b256.hash(encoded))}');
      expect(result.included.kind, TransactionStatusKind.finalized);
      expect(result.extrinsicIndex, 1);
      expect(
        statuses.map((status) => status.kind),
        orderedEquals(<TransactionStatusKind>[
          TransactionStatusKind.dropped,
          TransactionStatusKind.inBlock,
          TransactionStatusKind.finalized,
          TransactionStatusKind.executionSuccess,
        ]),
      );
      expect(transport.chainGetBlockCalls, 1);
      expect(transport.systemEventsCalls, 1);
    });

    test('等待式 finalized 与执行成功回调抛错仍返回单一成功终态并清理订阅', () async {
      final encoded = Uint8List.fromList(<int>[4, 6, 8]);
      final blockHash = _hash(0xa1);
      final cancelled = Completer<void>();
      final controller = StreamController<Object?>(
        onCancel: () {
          if (!cancelled.isCompleted) cancelled.complete();
        },
      );
      final statuses = <TransactionStatus>[];
      final transport = _FakeTransport(
        watchStream: controller.stream,
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
      );
      final rpc = ChainRpc.withTransport(transport);

      final resultFuture = rpc.submitAndWait(
        encoded,
        waitForFinalized: true,
        timeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(seconds: 1),
        executionRetryInterval: Duration.zero,
        onStatus: (status) {
          statuses.add(status);
          throw StateError('observer failure: ${status.kind.name}');
        },
      );
      await Future<void>.delayed(Duration.zero);
      controller.add(<String, Object?>{'finalized': blockHash});

      final result = await resultFuture.timeout(const Duration(seconds: 1));
      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(result.included.kind, TransactionStatusKind.finalized);
      expect(result.extrinsicIndex, 0);
      expect(
        statuses.map((status) => status.kind),
        orderedEquals(<TransactionStatusKind>[
          TransactionStatusKind.finalized,
          TransactionStatusKind.executionSuccess,
        ]),
      );
      expect(controller.hasListener, isFalse);
      await controller.close();
    });

    test('等待式交易达到目标块后忽略订阅迟到消息与错误，只发执行终态', () async {
      final encoded = Uint8List.fromList(<int>[7, 8, 9]);
      final blockHash = _hash(0xac);
      final controller = StreamController<Object?>();
      final executionGate = Completer<void>();
      final included = Completer<void>();
      final statuses = <TransactionStatus>[];
      final transport = _FakeTransport(
        watchStream: controller.stream,
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
        blockExtrinsicsGate: executionGate.future,
      );
      final rpc = ChainRpc.withTransport(transport);

      final resultFuture = rpc.submitAndWait(
        encoded,
        waitForFinalized: true,
        timeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(seconds: 1),
        executionRetryInterval: Duration.zero,
        onStatus: (status) {
          statuses.add(status);
          if (status.kind == TransactionStatusKind.finalized &&
              !included.isCompleted) {
            included.complete();
          }
        },
      );
      await Future<void>.delayed(Duration.zero);
      controller.add(<String, Object?>{'finalized': blockHash});
      await included.future.timeout(const Duration(seconds: 1));

      controller.add(Object());
      controller.addError(StateError('late subscription failure'));
      await Future<void>.delayed(Duration.zero);
      expect(
        statuses.where((status) => status.kind == TransactionStatusKind.error),
        isEmpty,
      );

      executionGate.complete();
      final result = await resultFuture.timeout(const Duration(seconds: 1));
      expect(result.extrinsicIndex, 0);
      expect(
        statuses.map((status) => status.kind),
        orderedEquals(<TransactionStatusKind>[
          TransactionStatusKind.finalized,
          TransactionStatusKind.executionSuccess,
        ]),
      );
      await controller.close();
    });

    test('inBlock 不等于成功，ExtrinsicFailed 抛出真实 dispatch error', () async {
      final encoded = Uint8List.fromList(<int>[7, 8, 9]);
      final blockHash = _hash(0xbb);
      final transport = _FakeTransport(
        events: <Object?>[
          <String, Object?>{'inBlock': blockHash},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._moduleFailureEvent(0, module: 4, error: 2)])}',
        ],
      );
      final statuses = <TransactionStatus>[];
      final rpc = ChainRpc.withTransport(transport);

      Object? caught;
      try {
        await rpc.submitAndWait(
          encoded,
          timeout: const Duration(seconds: 1),
          executionLookupTimeout: const Duration(seconds: 1),
          executionRetryInterval: Duration.zero,
          onStatus: statuses.add,
        );
      } on Object catch (error) {
        caught = error;
      }

      expect(caught, isA<TransactionDispatchException>());
      final failure = (caught! as TransactionDispatchException).failure;
      expect(failure.moduleIndex, 4);
      expect(failure.errorIndex, 2);
      expect(failure.description, contains('TransferFailed'));
      expect(statuses.last.kind, TransactionStatusKind.executionFailed);
    });

    test('等待式执行失败回调抛错仍保留 dispatch failure 单一终态并清理订阅', () async {
      final encoded = Uint8List.fromList(<int>[7, 9, 11]);
      final blockHash = _hash(0xb1);
      final cancelled = Completer<void>();
      final controller = StreamController<Object?>(
        onCancel: () {
          if (!cancelled.isCompleted) cancelled.complete();
        },
      );
      final statuses = <TransactionStatus>[];
      final transport = _FakeTransport(
        watchStream: controller.stream,
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._moduleFailureEvent(0, module: 4, error: 2)])}',
        ],
      );
      final rpc = ChainRpc.withTransport(transport);

      Object? caught;
      final resultFuture = rpc.submitAndWait(
        encoded,
        timeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(seconds: 1),
        executionRetryInterval: Duration.zero,
        onStatus: (status) {
          statuses.add(status);
          throw StateError('observer failure: ${status.kind.name}');
        },
      );
      await Future<void>.delayed(Duration.zero);
      controller.add(<String, Object?>{'inBlock': blockHash});
      try {
        await resultFuture.timeout(const Duration(seconds: 1));
      } on Object catch (error) {
        caught = error;
      }

      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(caught, isA<TransactionDispatchException>());
      expect(
        statuses.map((status) => status.kind),
        orderedEquals(<TransactionStatusKind>[
          TransactionStatusKind.inBlock,
          TransactionStatusKind.executionFailed,
        ]),
      );
      expect(controller.hasListener, isFalse);
      await controller.close();
    });

    test('未找到 Success/Failed 时受控重试，不猜测成功', () async {
      final encoded = Uint8List.fromList(<int>[10, 11, 12]);
      final blockHash = _hash(0xcc);
      final transport = _FakeTransport(
        events: <Object?>[
          <String, Object?>{'finalized': blockHash},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(9)])}',
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
      );
      final rpc = ChainRpc.withTransport(transport);

      final result = await rpc.submitAndWait(
        encoded,
        waitForFinalized: true,
        timeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(seconds: 1),
        executionRetryInterval: Duration.zero,
      );

      expect(result.extrinsicIndex, 0);
      expect(transport.chainGetBlockCalls, 1);
      expect(transport.systemEventsCalls, 2);
    });

    test('重试窗口结束仍无事件时返回未核实，不返回成功', () async {
      final encoded = Uint8List.fromList(<int>[13, 14, 15]);
      final blockHash = _hash(0xdd);
      final transport = _FakeTransport(
        events: <Object?>[
          <String, Object?>{'finalized': blockHash},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[null],
      );
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc.submitAndWait(
          encoded,
          waitForFinalized: true,
          timeout: const Duration(seconds: 1),
          executionLookupTimeout: const Duration(milliseconds: 20),
          executionRetryInterval: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TransactionExecutionUnverifiedException>()),
      );
      expect(transport.systemEventsCalls, 1);
    });

    test('等待式 System.Events RPC 永不返回时仍按执行总预算结束', () async {
      final encoded = Uint8List.fromList(<int>[13, 15, 17]);
      final blockHash = _hash(0xd1);
      final transport = _FakeTransport(
        events: <Object?>[
          <String, Object?>{'finalized': blockHash},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventRequestFuture: Completer<Object?>().future,
      );
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc
            .submitAndWait(
              encoded,
              waitForFinalized: true,
              timeout: const Duration(seconds: 1),
              executionLookupTimeout: const Duration(milliseconds: 20),
              executionRetryInterval: Duration.zero,
            )
            .timeout(const Duration(seconds: 1)),
        throwsA(isA<TransactionExecutionUnverifiedException>()),
      );
      expect(transport.systemEventsCalls, 1);
    });

    test('等待式 metadata RPC 永不返回时仍按执行总预算结束且可重试', () async {
      final encoded = Uint8List.fromList(<int>[13, 17, 19]);
      final blockHash = _hash(0xd3);
      final transport = _FakeTransport(
        events: <Object?>[
          <String, Object?>{'finalized': blockHash},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
        metadataFuture: Completer<String>().future,
      );
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc
            .submitAndWait(
              encoded,
              waitForFinalized: true,
              timeout: const Duration(seconds: 1),
              executionLookupTimeout: const Duration(milliseconds: 20),
              executionRetryInterval: Duration.zero,
            )
            .timeout(const Duration(seconds: 1)),
        throwsA(isA<TransactionExecutionUnverifiedException>()),
      );
      expect(transport.metadataCalls, 1);
      expect(transport.systemEventsCalls, greaterThanOrEqualTo(1));
      transport.metadataFuture = Future<String>.value(_eventMetadataHex);
      await rpc.fetchMetadata().timeout(const Duration(seconds: 1));
      expect(transport.metadataCalls, 2);
    });

    test('零执行预算下区块体 RPC 永不返回时立即受控结束', () async {
      final encoded = Uint8List.fromList(<int>[14, 16, 18]);
      final transport = _FakeTransport(
        events: <Object?>[
          <String, Object?>{'finalized': _hash(0xd2)},
        ],
        blockExtrinsicsGate: Completer<void>().future,
      );
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc
            .submitAndWait(
              encoded,
              waitForFinalized: true,
              timeout: const Duration(seconds: 1),
              executionLookupTimeout: Duration.zero,
              executionRetryInterval: Duration.zero,
            )
            .timeout(const Duration(seconds: 1)),
        throwsA(isA<TransactionExecutionUnverifiedException>()),
      );
      expect(transport.chainGetBlockCalls, 1);
      expect(transport.systemEventsCalls, 0);
    });

    test('metadata 失败时 payload 伪造的 Success 字节不能证明执行成功', () async {
      final encoded = Uint8List.fromList(<int>[16, 17, 18]);
      final blockHash = _hash(0xde);
      final collision = <int>[
        0x04,
        0x02, // Phase::Initialization，后续视为任意未知事件 payload。
        0x3f,
        0x7f,
        ..._successEvent(0),
      ];
      final transport = _FakeTransport(
        metadataHex: '0x00',
        events: <Object?>[
          <String, Object?>{'finalized': blockHash},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>['0x${_hex(collision)}'],
      );
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc.submitAndWait(
          encoded,
          waitForFinalized: true,
          timeout: const Duration(seconds: 1),
          executionLookupTimeout: const Duration(milliseconds: 20),
          executionRetryInterval: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TransactionExecutionUnverifiedException>()),
      );
      expect(transport.systemEventsCalls, 1);
    });

    test('invalid 与 usurped 是确定失败，不读块体', () async {
      for (final event in <Object?>[
        'invalid',
        <String, Object?>{'usurped': _hash(0xee)},
      ]) {
        final transport = _FakeTransport(events: <Object?>[event]);
        final rpc = ChainRpc.withTransport(transport);

        await expectLater(
          rpc.submitAndWait(
            Uint8List.fromList(<int>[1]),
            timeout: const Duration(seconds: 1),
          ),
          throwsA(isA<StateError>()),
        );
        expect(transport.requestCalls, 0);
      }
    });

    test('状态订阅不产生事件时按等待窗口超时', () async {
      final controller = StreamController<Object?>();
      final transport = _FakeTransport(watchStream: controller.stream);
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc.submitAndWait(Uint8List.fromList(<int>[1]), timeout: Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      await controller.close();
    });

    test('submit-only 等待超时回调抛错仍完成定时器收口并取消订阅', () async {
      final cancelled = Completer<void>();
      final controller = StreamController<Object?>(
        onCancel: () {
          if (!cancelled.isCompleted) cancelled.complete();
        },
      );
      final statuses = <TransactionStatus>[];
      final transport = _FakeTransport(watchStream: controller.stream);
      final rpc = ChainRpc.withTransport(transport);

      await rpc.submitExtrinsic(
        Uint8List.fromList(<int>[20]),
        watchTimeout: Duration.zero,
        onStatus: (status) {
          statuses.add(status);
          throw StateError('timeout observer failure');
        },
      );

      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(
        statuses.map((status) => status.kind),
        orderedEquals(<TransactionStatusKind>[TransactionStatusKind.timeout]),
      );
      expect(controller.hasListener, isFalse);
      await controller.close();
    });

    test('等待式订阅 cancel Future 异步失败不泄漏宿主 Zone 或覆盖成功', () async {
      final encoded = Uint8List.fromList(<int>[20, 21]);
      final blockHash = _hash(0xe1);
      final controller = StreamController<Object?>(
        onCancel: () =>
            Future<void>.error(StateError('waiting cancel cleanup failed')),
      );
      final transport = _FakeTransport(
        watchStream: controller.stream,
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
      );
      final zoneErrors = <Object>[];

      final body = runZonedGuarded<Future<void>>(
        () async {
          final resultFuture = ChainRpc.withTransport(transport).submitAndWait(
            encoded,
            waitForFinalized: true,
            timeout: const Duration(seconds: 1),
            executionLookupTimeout: const Duration(seconds: 1),
            executionRetryInterval: Duration.zero,
          );
          while (!controller.hasListener) {
            await Future<void>.delayed(Duration.zero);
          }
          controller.add(<String, Object?>{'finalized': blockHash});
          final result = await resultFuture;
          expect(result.extrinsicIndex, 0);
          // 保留一个明确的 await 点，让 cancel Future 的异步错误有机会进入 Zone。
          await Future<void>.delayed(Duration.zero);
        },
        (error, _) {
          zoneErrors.add(error);
        },
      );
      expect(body, isNotNull);
      await body!;

      expect(zoneErrors, isEmpty);
      expect(controller.hasListener, isFalse);
      await controller.close();
    });

    test('submit-only 订阅 cancel Future 异步失败被消费且终态唯一', () async {
      final encoded = Uint8List.fromList(<int>[20, 22]);
      final blockHash = _hash(0xe2);
      final controller = StreamController<Object?>(
        onCancel: () =>
            Future<void>.error(StateError('background cancel cleanup failed')),
      );
      final transport = _FakeTransport(
        submittedHash: '0x${_hex(Hasher.blake2b256.hash(encoded))}',
        watchStream: controller.stream,
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
      );
      final terminal = Completer<TransactionStatus>();
      final statuses = <TransactionStatus>[];
      final zoneErrors = <Object>[];

      final body = runZonedGuarded<Future<void>>(
        () async {
          await ChainRpc.withTransport(transport).submitExtrinsic(
            encoded,
            watchTimeout: const Duration(seconds: 1),
            executionLookupTimeout: const Duration(seconds: 1),
            executionRetryInterval: Duration.zero,
            onStatus: (status) {
              statuses.add(status);
              if (status.kind == TransactionStatusKind.executionSuccess &&
                  !terminal.isCompleted) {
                terminal.complete(status);
              }
            },
          );
          while (!controller.hasListener) {
            await Future<void>.delayed(Duration.zero);
          }
          controller.add(<String, Object?>{'finalized': blockHash});
          await terminal.future.timeout(const Duration(seconds: 1));
          while (controller.hasListener) {
            await Future<void>.delayed(Duration.zero);
          }
          await Future<void>.delayed(Duration.zero);
        },
        (error, _) {
          zoneErrors.add(error);
        },
      );
      expect(body, isNotNull);
      await body!;

      expect(zoneErrors, isEmpty);
      expect(
        statuses.where(
          (status) =>
              status.kind == TransactionStatusKind.executionSuccess ||
              status.kind == TransactionStatusKind.executionFailed ||
              status.kind == TransactionStatusKind.error ||
              status.kind == TransactionStatusKind.timeout,
        ),
        hasLength(1),
      );
      await controller.close();
    });

    test('submit-only 后台通路也在 finalized 后核对执行成功', () async {
      final encoded = Uint8List.fromList(<int>[21, 22, 23]);
      final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
      final blockHash = _hash(0xfa);
      final transport = _FakeTransport(
        submittedHash: txHash,
        events: <Object?>[
          <String, Object?>{'finalized': blockHash},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
      );
      final verified = Completer<TransactionStatus>();
      final rpc = ChainRpc.withTransport(transport);

      final returned = await rpc.submitExtrinsic(
        encoded,
        watchTimeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(seconds: 1),
        executionRetryInterval: Duration.zero,
        onStatus: (status) {
          if (status.kind == TransactionStatusKind.executionSuccess &&
              !verified.isCompleted) {
            verified.complete(status);
          }
        },
      );

      expect(returned, txHash);
      final status = await verified.future.timeout(const Duration(seconds: 1));
      expect(status.extrinsicIndex, 0);
      expect(transport.submittedExtrinsics, <String>['0x${_hex(encoded)}']);
    });

    test('submit-only 后台 finalized 与执行终态回调异步抛错仍只发一个终态并取消订阅', () async {
      for (final succeeds in <bool>[true, false]) {
        final encoded = Uint8List.fromList(<int>[succeeds ? 22 : 23, 24, 25]);
        final blockHash = _hash(succeeds ? 0xf1 : 0xf2);
        final cancelled = Completer<void>();
        final controller = StreamController<Object?>(
          onCancel: () {
            if (!cancelled.isCompleted) cancelled.complete();
          },
        );
        final statuses = <TransactionStatus>[];
        final event = succeeds
            ? <int>[0x04, ..._successEvent(0)]
            : <int>[0x04, ..._moduleFailureEvent(0, module: 4, error: 2)];
        final transport = _FakeTransport(
          submittedHash: '0x${_hex(Hasher.blake2b256.hash(encoded))}',
          watchStream: controller.stream,
          blockExtrinsics: <String>['0x${_hex(encoded)}'],
          eventResponses: <Object?>['0x${_hex(event)}'],
        );
        final rpc = ChainRpc.withTransport(transport);

        await rpc.submitExtrinsic(
          encoded,
          watchTimeout: const Duration(seconds: 1),
          executionLookupTimeout: const Duration(seconds: 1),
          executionRetryInterval: Duration.zero,
          onStatus: (status) async {
            statuses.add(status);
            await Future<void>.delayed(Duration.zero);
            throw StateError('async observer failure: ${status.kind.name}');
          },
        );
        controller.add(<String, Object?>{'finalized': blockHash});

        await cancelled.future.timeout(const Duration(seconds: 1));
        final terminalStatuses = statuses
            .where(
              (status) =>
                  status.kind == TransactionStatusKind.executionSuccess ||
                  status.kind == TransactionStatusKind.executionFailed ||
                  status.kind == TransactionStatusKind.error ||
                  status.kind == TransactionStatusKind.timeout,
            )
            .toList(growable: false);
        expect(statuses.first.kind, TransactionStatusKind.finalized);
        expect(terminalStatuses, hasLength(1));
        expect(
          terminalStatuses.single.kind,
          succeeds
              ? TransactionStatusKind.executionSuccess
              : TransactionStatusKind.executionFailed,
        );
        expect(controller.hasListener, isFalse);
        await controller.close();
      }
    });

    test('submit-only finalized 后忽略订阅迟到消息与错误，只发执行终态', () async {
      final encoded = Uint8List.fromList(<int>[24, 25, 26]);
      final blockHash = _hash(0xfb);
      final controller = StreamController<Object?>();
      final executionGate = Completer<void>();
      final finalized = Completer<void>();
      final terminal = Completer<TransactionStatus>();
      final statuses = <TransactionStatus>[];
      final transport = _FakeTransport(
        submittedHash: '0x${_hex(Hasher.blake2b256.hash(encoded))}',
        watchStream: controller.stream,
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
        blockExtrinsicsGate: executionGate.future,
      );
      final rpc = ChainRpc.withTransport(transport);

      await rpc.submitExtrinsic(
        encoded,
        watchTimeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(seconds: 1),
        executionRetryInterval: Duration.zero,
        onStatus: (status) {
          statuses.add(status);
          if (status.kind == TransactionStatusKind.finalized &&
              !finalized.isCompleted) {
            finalized.complete();
          }
          if (status.kind == TransactionStatusKind.executionSuccess &&
              !terminal.isCompleted) {
            terminal.complete(status);
          }
        },
      );
      controller.add(<String, Object?>{'finalized': blockHash});
      await finalized.future.timeout(const Duration(seconds: 1));

      controller.add(Object());
      controller.addError(StateError('late subscription failure'));
      await Future<void>.delayed(Duration.zero);
      expect(
        statuses.where((status) => status.kind == TransactionStatusKind.error),
        isEmpty,
      );

      executionGate.complete();
      final result = await terminal.future.timeout(const Duration(seconds: 1));
      expect(result.extrinsicIndex, 0);
      expect(
        statuses.map((status) => status.kind),
        orderedEquals(<TransactionStatusKind>[
          TransactionStatusKind.finalized,
          TransactionStatusKind.executionSuccess,
        ]),
      );
      await controller.close();
    });

    test('submit-only System.Events RPC 永不返回时发出单一未核实终态', () async {
      final encoded = Uint8List.fromList(<int>[27, 28, 29]);
      final terminal = Completer<TransactionStatus>();
      final statuses = <TransactionStatus>[];
      final transport = _FakeTransport(
        submittedHash: '0x${_hex(Hasher.blake2b256.hash(encoded))}',
        events: <Object?>[
          <String, Object?>{'finalized': _hash(0xfc)},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventRequestFuture: Completer<Object?>().future,
      );
      final rpc = ChainRpc.withTransport(transport);

      await rpc.submitExtrinsic(
        encoded,
        watchTimeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(milliseconds: 20),
        executionRetryInterval: Duration.zero,
        onStatus: (status) {
          statuses.add(status);
          if (status.kind == TransactionStatusKind.error &&
              !terminal.isCompleted) {
            terminal.complete(status);
          }
        },
      );

      final result = await terminal.future.timeout(const Duration(seconds: 1));
      expect(result.description, contains('链上执行结果未能核实'));
      expect(transport.systemEventsCalls, 1);
      expect(
        statuses.where(
          (status) =>
              status.kind == TransactionStatusKind.error ||
              status.kind == TransactionStatusKind.executionSuccess ||
              status.kind == TransactionStatusKind.executionFailed ||
              status.kind == TransactionStatusKind.timeout,
        ),
        hasLength(1),
      );
    });

    test('submit-only metadata RPC 永不返回时发出单一未核实终态', () async {
      final encoded = Uint8List.fromList(<int>[27, 29, 31]);
      final terminal = Completer<TransactionStatus>();
      final statuses = <TransactionStatus>[];
      final transport = _FakeTransport(
        submittedHash: '0x${_hex(Hasher.blake2b256.hash(encoded))}',
        events: <Object?>[
          <String, Object?>{'finalized': _hash(0xfd)},
        ],
        blockExtrinsics: <String>['0x${_hex(encoded)}'],
        eventResponses: <Object?>[
          '0x${_hex(<int>[0x04, ..._successEvent(0)])}',
        ],
        metadataFuture: Completer<String>().future,
      );
      final rpc = ChainRpc.withTransport(transport);

      await rpc.submitExtrinsic(
        encoded,
        watchTimeout: const Duration(seconds: 1),
        executionLookupTimeout: const Duration(milliseconds: 20),
        executionRetryInterval: Duration.zero,
        onStatus: (status) {
          statuses.add(status);
          if (status.kind == TransactionStatusKind.error &&
              !terminal.isCompleted) {
            terminal.complete(status);
          }
        },
      );

      final result = await terminal.future.timeout(const Duration(seconds: 1));
      expect(result.description, contains('链上执行结果未能核实'));
      expect(transport.metadataCalls, greaterThanOrEqualTo(1));
      expect(
        statuses.where(
          (status) =>
              status.kind == TransactionStatusKind.error ||
              status.kind == TransactionStatusKind.executionSuccess ||
              status.kind == TransactionStatusKind.executionFailed ||
              status.kind == TransactionStatusKind.timeout,
        ),
        hasLength(1),
      );
    });

    test('submit-only 收到 ready 或 dropped 后仍以 timeout 报告未核实终态', () async {
      for (final pendingStatus in <Object?>[
        'ready',
        <String, Object?>{'dropped': null},
      ]) {
        final controller = StreamController<Object?>();
        final transport = _FakeTransport(watchStream: controller.stream);
        final terminal = Completer<TransactionStatus>();
        final rpc = ChainRpc.withTransport(transport);

        await rpc.submitExtrinsic(
          Uint8List.fromList(<int>[31]),
          watchTimeout: const Duration(milliseconds: 20),
          onStatus: (status) {
            if (status.kind == TransactionStatusKind.timeout &&
                !terminal.isCompleted) {
              terminal.complete(status);
            }
          },
        );
        controller.add(pendingStatus);

        final status = await terminal.future.timeout(
          const Duration(seconds: 1),
        );
        expect(status.description, contains('交易成功性未确定'));
        await controller.close();
      }
    });

    test('submit-only 订阅在 finalized 前关闭时报告未核实错误', () async {
      final transport = _FakeTransport(events: const <Object?>['ready']);
      final terminal = Completer<TransactionStatus>();
      final rpc = ChainRpc.withTransport(transport);

      await rpc.submitExtrinsic(
        Uint8List.fromList(<int>[32]),
        watchTimeout: const Duration(seconds: 1),
        onStatus: (status) {
          if (status.kind == TransactionStatusKind.error &&
              !terminal.isCompleted) {
            terminal.complete(status);
          }
        },
      );

      final status = await terminal.future.timeout(const Duration(seconds: 1));
      expect(status.raw, 'subscription-closed-before-finalized');
      expect(status.description, contains('交易成功性未确定'));
    });

    test('本机轻节点广播失败原样返回，不启动远程中继', () async {
      final transport = _FakeTransport(
        submitError: StateError('p2p unavailable'),
      );
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc.submitExtrinsic(Uint8List.fromList(<int>[1, 2, 3])),
        throwsA(isA<StateError>()),
      );

      expect(transport.submittedExtrinsics, hasLength(1));
      expect(transport.subscribeCalls, 0);
      expect(transport.requestCalls, 0);
    });

    test('轻节点返回的 txHash 必须是 32 字节 hex', () async {
      final transport = _FakeTransport(submittedHash: '0x1234');
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc.submitExtrinsic(Uint8List.fromList(<int>[1, 2, 3])),
        throwsA(isA<StateError>()),
      );
      expect(transport.subscribeCalls, 0);
    });

    test('未装配本地流水仓储时也拒绝节点返回的错误交易身份', () async {
      final transport = _FakeTransport(submittedHash: _hash(0x22));
      final rpc = ChainRpc.withTransport(transport);

      await expectLater(
        rpc.submitExtrinsic(Uint8List.fromList(<int>[1, 2, 3])),
        throwsStateError,
      );
      expect(transport.submittedExtrinsics, hasLength(1));
      expect(transport.subscribeCalls, 0);
    });
  });
}

final class _FakeTransport implements ChainRpcTransport {
  _FakeTransport({
    String? metadataHex,
    String? bestHead,
    Map<String, Map<String, dynamic>> runtimeVersionsByBlock = const {},
    Map<String, String> metadataByBlock = const {},
    this.onRuntimeVersionRequest,
    this.submittedHash,
    this.submitError,
    this.events = const <Object?>[],
    this.watchStream,
    this.blockExtrinsics = const <String>[],
    this.blockExtrinsicsGate,
    this.eventRequestFuture,
    this.metadataFuture,
    List<Object?> eventResponses = const <Object?>[],
    List<String?> finalizedStorageResponses = const <String?>[],
  }) : _metadataHex = metadataHex ?? _eventMetadataHex,
       bestHead = bestHead ?? _hash(0),
       runtimeVersionsByBlock = Map<String, Map<String, dynamic>>.from(
         runtimeVersionsByBlock,
       ),
       metadataByBlock = Map<String, String>.from(metadataByBlock),
       eventResponses = List<Object?>.from(eventResponses),
       finalizedStorageResponses = List<String?>.from(
         finalizedStorageResponses,
       );

  final String _metadataHex;
  String bestHead;
  final Map<String, Map<String, dynamic>> runtimeVersionsByBlock;
  final Map<String, String> metadataByBlock;
  final void Function(String blockHash)? onRuntimeVersionRequest;
  final String? submittedHash;
  final Object? submitError;
  final List<Object?> events;
  final Stream<Object?>? watchStream;
  final List<String> blockExtrinsics;
  final Future<void>? blockExtrinsicsGate;
  final Future<Object?>? eventRequestFuture;
  Future<String>? metadataFuture;
  final List<Object?> eventResponses;
  final List<String?> finalizedStorageResponses;
  final List<String> submittedExtrinsics = <String>[];
  final List<String> finalizedStorageKeys = <String>[];
  final List<List<String>> finalizedStorageBatchKeys = <List<String>>[];
  final List<String> runtimeVersionBlockRequests = <String>[];
  final List<String> metadataBlockRequests = <String>[];
  int requestCalls = 0;
  int metadataCalls = 0;
  int runtimeVersionCalls = 0;
  int bestHeadCalls = 0;
  int finalizedStorageBatchCalls = 0;
  int chainGetBlockCalls = 0;
  int systemEventsCalls = 0;
  int subscribeCalls = 0;

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<int> accountNextIndex(String accountIdHex) async => 0;

  @override
  Future<Map<String, dynamic>> runtimeVersion() async =>
      _runtimeVersionJson(1, 1);

  @override
  Future<String> blockHash(int blockNumber) async => _hash(0);

  @override
  Future<String> metadataHex() async {
    metadataCalls += 1;
    final pending = metadataFuture;
    return pending == null ? _metadataHex : await pending;
  }

  @override
  Future<String?> finalizedStorage(String storageKeyHex) async {
    finalizedStorageKeys.add(storageKeyHex);
    return _nextFinalizedStorageResponse();
  }

  @override
  Future<Map<String, String?>> finalizedStorageValues(
    List<String> storageKeyHexList,
  ) async {
    finalizedStorageBatchCalls += 1;
    finalizedStorageBatchKeys.add(List<String>.of(storageKeyHexList));
    return <String, String?>{
      for (final key in storageKeyHexList) key: _nextFinalizedStorageResponse(),
    };
  }

  String? _nextFinalizedStorageResponse() {
    if (finalizedStorageResponses.isEmpty) return null;
    return finalizedStorageResponses.length == 1
        ? finalizedStorageResponses.first
        : finalizedStorageResponses.removeAt(0);
  }

  @override
  Future<String> submitExtrinsic(String extrinsicHex) async {
    submittedExtrinsics.add(extrinsicHex);
    final error = submitError;
    if (error != null) throw error;
    return submittedHash ??
        '0x${_hex(Hasher.blake2b256.hash(_hexBytes(extrinsicHex)))}';
  }

  @override
  Future<List<String>> blockExtrinsicsOnce(String blockHashHex) async {
    chainGetBlockCalls += 1;
    final gate = blockExtrinsicsGate;
    if (gate != null) await gate;
    return blockExtrinsics;
  }

  @override
  Future<Object?> request(String method, List<Object?> params) async {
    requestCalls += 1;
    if (method == 'chain_getBlockHash') {
      bestHeadCalls += 1;
      expect(params, isEmpty);
      return bestHead;
    }
    if (method == 'state_getRuntimeVersion') {
      runtimeVersionCalls += 1;
      final blockHash = params.single as String;
      runtimeVersionBlockRequests.add(blockHash);
      onRuntimeVersionRequest?.call(blockHash);
      return runtimeVersionsByBlock[blockHash] ?? _runtimeVersionJson(1, 1);
    }
    if (method == 'state_getMetadata') {
      metadataCalls += 1;
      final blockHash = params.single as String;
      metadataBlockRequests.add(blockHash);
      final byBlock = metadataByBlock[blockHash];
      if (byBlock != null) return byBlock;
      final pending = metadataFuture;
      return pending == null ? _metadataHex : await pending;
    }
    if (method == 'state_getStorage') {
      systemEventsCalls += 1;
      final pending = eventRequestFuture;
      if (pending != null) return await pending;
      if (eventResponses.isEmpty) return null;
      return eventResponses.length == 1
          ? eventResponses.first
          : eventResponses.removeAt(0);
    }
    throw StateError('未预期 RPC：$method');
  }

  @override
  Stream<Object?> subscribe(String method, List<Object?> params) {
    subscribeCalls += 1;
    expect(method, 'author_submitAndWatchExtrinsic');
    return watchStream ?? Stream<Object?>.fromIterable(events);
  }
}

Uint8List _hexBytes(String value) {
  final body = value.startsWith('0x') ? value.substring(2) : value;
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < body.length; offset += 2)
      int.parse(body.substring(offset, offset + 2), radix: 16),
  ]);
}

List<int> _successEvent(int extrinsicIndex) => <int>[
  0x00,
  ..._u32(extrinsicIndex),
  0x00,
  0x00,
  ..._dispatchInfo(),
  0x00,
];

List<int> _moduleFailureEvent(
  int extrinsicIndex, {
  required int module,
  required int error,
}) => <int>[
  0x00,
  ..._u32(extrinsicIndex),
  0x00,
  0x01,
  0x03,
  module,
  error,
  ..._dispatchInfo(),
  0x00,
];

// substrate v14 测试 metadata 中 DispatchInfo = u64 Weight +
// DispatchClass + Pays；全零分别表示 Normal 与 Pays::Yes。
List<int> _dispatchInfo() => <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

List<int> _u32(int value) => <int>[
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

String _accountInfoHex({
  required BigInt freeFen,
  required BigInt reservedFen,
}) =>
    '0x${List<String>.filled(16, '00').join()}'
    '${_littleEndianHex(freeFen, 16)}'
    '${_littleEndianHex(reservedFen, 16)}';

String _feePolicyMetadataHex({
  int feeRateParts = 1000000,
  BigInt? minimumFeeFen,
}) {
  final minimum = minimumFeeFen ?? BigInt.from(10);
  final encodedMinimum = _littleEndianHex(minimum, 16);
  final encodedRate = _littleEndianHex(BigInt.from(feeRateParts), 4);
  const originalMinimum = '0a000000000000000000000000000000';
  const originalRate = '40420f00';
  if (!_constantMetadataHex.contains(originalMinimum) ||
      !_constantMetadataHex.contains(originalRate)) {
    throw StateError('手续费 metadata 金标结构已漂移');
  }
  return _constantMetadataHex
      .replaceFirst(originalMinimum, encodedMinimum)
      .replaceFirst(originalRate, encodedRate);
}

String _feeRateBooleanMetadataHex() {
  const original = '0c1040420f00';
  if (!_constantMetadataHex.contains(original)) {
    throw StateError('手续费费率 metadata 金标结构已漂移');
  }
  // ConstantMetadata: type=u32(3), value=[4 bytes] 改为 type=bool(1), value=[true]。
  return _constantMetadataHex.replaceFirst(original, '040401');
}

String _littleEndianHex(BigInt value, int byteLength) {
  final maximum = BigInt.one << (byteLength * 8);
  if (value < BigInt.zero || value >= maximum) {
    throw ArgumentError.value(value, 'value', '超出 $byteLength 字节无符号整数范围');
  }
  final bytes = <int>[];
  var remaining = value;
  for (var index = 0; index < byteLength; index++) {
    bytes.add((remaining & BigInt.from(0xff)).toInt());
    remaining >>= 8;
  }
  return _hex(bytes);
}

String _hash(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';

Map<String, dynamic> _runtimeVersionJson(
  int specVersion,
  int transactionVersion,
) => <String, dynamic>{
  'specName': 'citizen',
  'implName': 'citizen',
  'authoringVersion': 1,
  'specVersion': specVersion,
  'implVersion': 1,
  'apis': <Object?>[],
  'transactionVersion': transactionVersion,
  'stateVersion': 1,
};

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
