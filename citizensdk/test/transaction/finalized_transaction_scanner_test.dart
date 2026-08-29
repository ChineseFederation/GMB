import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_sdk/src/platform/preferences_data_store.dart';
import 'package:citizen_sdk/src/platform/preferences_finalized_transaction_repository.dart';
import 'package:citizen_sdk/src/transaction/chain_rpc.dart';
import 'package:citizen_sdk/src/transaction/chain_transfer_event_decoder.dart';
import 'package:citizen_sdk/src/transaction/finalized_transaction_models.dart';
import 'package:citizen_sdk/src/transaction/finalized_transaction_repository.dart';
import 'package:citizen_sdk/src/transaction/finalized_transaction_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/polkadart.dart' show Hasher;

void main() {
  final accountA = _account(0xaa);
  final accountB = _account(0xbb);
  late _MemoryPreferences preferences;
  late FinalizedTransactionHistory history;
  late _ScannerTransport transport;
  late _FakeHeadSource headSource;
  late _FakeTransferDecoder decoder;
  late FinalizedTransactionScanner scanner;

  void assemble({
    int finalizedHeight = 5,
    int maxBlocksPerRun = 120,
    Duration pendingPollInterval = Duration.zero,
    Duration syncRetryDelay = const Duration(hours: 1),
  }) {
    preferences = _MemoryPreferences();
    history = FinalizedTransactionHistory(
      repository: PreferencesFinalizedTransactionRepository(
        preferences: preferences,
      ),
    );
    transport = _ScannerTransport(finalizedHeight: finalizedHeight);
    headSource = _FakeHeadSource();
    decoder = _FakeTransferDecoder();
    scanner = FinalizedTransactionScanner(
      rpc: ChainRpc.withTransport(transport),
      history: history,
      headSource: headSource,
      decoder: decoder,
      maxBlocksPerRun: maxBlocksPerRun,
      subscriptionRetryDelay: const Duration(milliseconds: 5),
      syncRetryDelay: syncRetryDelay,
      pendingPollInterval: pendingPollInterval,
      interBlockDelay: Duration.zero,
    );
  }

  tearDown(() async {
    await scanner.stop().catchError((Object _) {});
    await headSource.close();
  });

  test('首次账户从当前 finalized 起步，不扫描加入前历史', () async {
    assemble(finalizedHeight: 10);
    decoder.transfersByBlock[10] = <_TransferSpec>[
      _TransferSpec(accountA, accountB, 10),
    ];
    await scanner.replaceWatchedAccounts(<String>[accountA, accountB]);
    await scanner.start();
    await _settle();

    final state = await history.load();
    expect(state.cursors[accountA]!.trackingStartBlock, 10);
    expect(state.cursors[accountA]!.lastSyncedBlock, 10);
    expect(state.cursors[accountB]!.trackingStartBlock, 10);
    expect(state.transfers, isEmpty);
    expect(transport.blockHashRequests, isEmpty);
  });

  test('已有账户补缺口时新账户不接收其 trackingStartBlock 之前流水', () async {
    assemble(finalizedHeight: 10);
    await history.ensureCursors(accountIds: <String>[accountA], startBlock: 5);
    for (var block = 6; block <= 10; block++) {
      decoder.transfersByBlock[block] = <_TransferSpec>[
        _TransferSpec(accountA, accountB, block),
      ];
    }

    await scanner.replaceWatchedAccounts(<String>[accountA, accountB]);
    await scanner.start();
    await _waitUntil(
      () async =>
          (await history.load()).cursors[accountA]!.lastSyncedBlock == 10,
    );

    final state = await history.load();
    expect(state.cursors[accountA]!.trackingStartBlock, 5);
    expect(state.cursors[accountB]!.trackingStartBlock, 10);
    expect(
      state.transfers.values.where((entry) => entry.accountId == accountA),
      hasLength(5),
    );
    expect(
      state.transfers.values.where((entry) => entry.accountId == accountB),
      isEmpty,
    );
  });

  test('每轮上限后继续调度直到已有游标补到 finalized 头', () async {
    assemble(finalizedHeight: 8, maxBlocksPerRun: 3);
    await history.ensureCursors(accountIds: <String>[accountA], startBlock: 0);
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();

    await _waitUntil(
      () async =>
          (await history.load()).cursors[accountA]!.lastSyncedBlock == 8,
    );
    expect(transport.blockHashRequests, <int>[1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('txHash 命中且显式 Success 才 finalized，并认领发送方避免第二条', () async {
    assemble(finalizedHeight: 5);
    final encoded = Uint8List.fromList(<int>[7, 9, 11]);
    final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 1,
      toAccountId: accountB,
      amountFen: BigInt.from(123),
      remark: 'fixture',
    );
    transport.blockExtrinsicsByNumber[6] = <String>['0x${_hex(encoded)}'];
    transport.eventsByNumber[6] = '0x${_hex(<int>[0x04, ..._successEvent(0)])}';
    decoder.transfersByBlock[6] = <_TransferSpec>[
      _TransferSpec(accountA, accountB, 123, extrinsicIndex: 0),
    ];
    await scanner.replaceWatchedAccounts(<String>[accountA, accountB]);
    await scanner.start();
    transport.finalizedHeight = 6;
    headSource.emit(6);

    await _waitUntil(() async {
      final value = (await history.load()).submissions.values.single;
      return value.status == PendingSubmittedTransactionStatus.finalized;
    });
    final state = await history.load();
    expect(state.submissions.values.single.extrinsicIndex, 0);
    expect(
      state.transfers.values.where((entry) => entry.accountId == accountA),
      isEmpty,
      reason: '本机 sender 已由稳定 :tx: 记录认领，不能再建 event 流水',
    );
    expect(
      state.transfers.values.where((entry) => entry.accountId == accountB),
      hasLength(1),
    );
    expect(state.cursors[accountA]!.lastSyncedBlock, 6);
  });

  test('显式 ExtrinsicFailed 保存结构化失败并推进已完整处理的块', () async {
    assemble(finalizedHeight: 5);
    final encoded = Uint8List.fromList(<int>[1, 2, 3]);
    final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 2,
      toAccountId: accountB,
      amountFen: BigInt.one,
      remark: '',
    );
    transport.blockExtrinsicsByNumber[6] = <String>['0x${_hex(encoded)}'];
    transport.eventsByNumber[6] =
        '0x${_hex(<int>[0x04, ..._failureEvent(0, module: 4, error: 0)])}';
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    transport.finalizedHeight = 6;
    headSource.emit(6);

    await _waitUntil(() async {
      final value = (await history.load()).submissions.values.single;
      return value.status == PendingSubmittedTransactionStatus.failed;
    });
    final state = await history.load();
    expect(state.submissions.values.single.failure!.moduleIndex, 4);
    expect(state.submissions.values.single.failure!.errorIndex, 0);
    expect(state.cursors[accountA]!.lastSyncedBlock, 6);
  });

  test('无块锚 poolRejected 仍随 finalized 补扫并由明确链上事实覆盖', () async {
    assemble(finalizedHeight: 5);
    final encoded = Uint8List.fromList(<int>[31, 32, 33]);
    final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 8,
      toAccountId: accountB,
      amountFen: BigInt.from(9),
      remark: '',
    );
    await history.markPoolRejected(
      accountId: accountA,
      txHash: txHash,
      reason: 'usurped',
    );
    transport.blockExtrinsicsByNumber[6] = <String>['0x${_hex(encoded)}'];
    transport.eventsByNumber[6] = '0x${_hex(<int>[0x04, ..._successEvent(0)])}';
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    transport.finalizedHeight = 6;
    headSource.emit(6);

    await _waitUntil(() async {
      final value = (await history.load()).submissions.values.single;
      return value.status == PendingSubmittedTransactionStatus.finalized;
    });
    final submission = (await history.load()).submissions.values.single;
    expect(submission.anchorBlockHash, _blockHash(6));
    expect(submission.extrinsicIndex, 0);
    expect(transport.blockBodyCalls, greaterThan(0));
  });

  test('txHash 命中但无同 index Success/Failed 时 fail closed 且游标不动', () async {
    assemble(finalizedHeight: 5);
    final encoded = Uint8List.fromList(<int>[4, 5, 6]);
    final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 3,
      toAccountId: accountB,
      amountFen: BigInt.one,
      remark: '',
    );
    transport.blockExtrinsicsByNumber[6] = <String>['0x${_hex(encoded)}'];
    transport.eventsByNumber[6] = '0x${_hex(<int>[0x04, ..._successEvent(9)])}';
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    transport.finalizedHeight = 6;
    headSource.emit(6);
    await _waitUntil(() async => transport.blockBodyCalls > 0);
    await _settle();

    final state = await history.load();
    expect(state.cursors[accountA]!.lastSyncedBlock, 5);
    expect(
      state.submissions.values.single.status,
      PendingSubmittedTransactionStatus.pending,
    );
  });

  test('没有 open pending 时不下载任何区块体', () async {
    assemble(finalizedHeight: 5);
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    transport.finalizedHeight = 6;
    headSource.emit(6);
    await _waitUntil(
      () async =>
          (await history.load()).cursors[accountA]!.lastSyncedBlock == 6,
    );

    expect(transport.blockBodyCalls, 0);
  });

  test('没有新区块事件也按 finalized 锚独立轮询收敛 pending', () async {
    assemble(
      finalizedHeight: 6,
      pendingPollInterval: const Duration(milliseconds: 10),
    );
    final encoded = Uint8List.fromList(<int>[12, 13]);
    final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 4,
      toAccountId: accountB,
      amountFen: BigInt.one,
      remark: '',
    );
    await history.markSubmissionInBlock(
      accountId: accountA,
      txHash: txHash,
      blockHash: _blockHash(6),
    );
    transport.blockExtrinsicsByNumber[6] = <String>['0x${_hex(encoded)}'];
    transport.eventsByNumber[6] = '0x${_hex(<int>[0x04, ..._successEvent(0)])}';
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();

    await _waitUntil(() async {
      final value = (await history.load()).submissions.values.single;
      return value.status == PendingSubmittedTransactionStatus.finalized;
    });
    expect(headSource.emittedCount, 0);
  });

  test('空闲轮询只读本地仓储，不持续打链', () async {
    assemble(
      finalizedHeight: 5,
      pendingPollInterval: const Duration(milliseconds: 10),
    );
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    await _settle();
    final baseline = transport.finalizedHeadCalls;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(transport.finalizedHeadCalls, baseline);
  });

  test('永不返回的外部 RPC 被 stop signal 抢占，迟到 Future 不阻塞停止', () async {
    assemble(finalizedHeight: 5);
    final never = Completer<Object?>();
    transport.eventFutureByNumber[6] = never.future;
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    transport.finalizedHeight = 6;
    headSource.emit(6);
    await _waitUntil(() async => transport.storageCalls > 0);

    await scanner.stop().timeout(const Duration(milliseconds: 200));
    expect(scanner.isRunning, isFalse);
    never.complete('0x00');
    await _settle();
    expect((await history.load()).cursors[accountA]!.lastSyncedBlock, 5);
  });

  test('首个 finalized RPC 永不返回时 stop 后仍能干净重启', () async {
    assemble(finalizedHeight: 5);
    final never = Completer<Object?>();
    transport.finalizedHeadFuture = never.future;
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    final startFuture = scanner.start();
    await _waitUntil(() async => transport.finalizedHeadCalls > 0);

    await scanner.stop().timeout(const Duration(milliseconds: 200));
    await startFuture.timeout(const Duration(milliseconds: 200));
    transport.finalizedHeadFuture = null;
    await scanner.start();
    expect(scanner.isRunning, isTrue);
    never.complete(_blockHash(5));
  });

  test('并发 start 共享同一轮初始化成功', () async {
    assemble(finalizedHeight: 5);
    final finalizedGate = Completer<Object?>();
    transport.finalizedHeadFuture = finalizedGate.future;
    await scanner.replaceWatchedAccounts(<String>[accountA]);

    final first = scanner.start();
    final second = scanner.start();
    expect(identical(first, second), isTrue);
    await _waitUntil(() async => transport.finalizedHeadCalls == 1);
    finalizedGate.complete(_blockHash(5));
    await Future.wait<void>(<Future<void>>[first, second]);

    expect(transport.finalizedHeadCalls, greaterThanOrEqualTo(1));
    expect(scanner.isRunning, isTrue);
    expect((await history.load()).cursors[accountA]!.lastSyncedBlock, 5);
  });

  test('并发 start 共享失败，且失败清理完成后才允许重启', () async {
    assemble(finalizedHeight: 5);
    final finalizedGate = Completer<Object?>();
    final disconnectGate = Completer<void>();
    transport.finalizedHeadFuture = finalizedGate.future;
    headSource.disconnectGate = disconnectGate.future;
    await scanner.replaceWatchedAccounts(<String>[accountA]);

    final first = scanner.start();
    final second = scanner.start();
    expect(identical(first, second), isTrue);
    var completed = false;
    final observed = first.then<void>(
      (_) => completed = true,
      onError: (Object _, StackTrace __) => completed = true,
    );
    final firstExpectation = expectLater(first, throwsStateError);
    final secondExpectation = expectLater(second, throwsStateError);
    finalizedGate.completeError(StateError('initial finalized failed'));
    await _waitUntil(() async => headSource.disconnectCount == 1);
    expect(completed, isFalse, reason: '失败必须等待 disconnect 真正收口');

    disconnectGate.complete();
    await Future.wait<void>(<Future<void>>[
      observed,
      firstExpectation,
      secondExpectation,
    ]);
    expect(scanner.isRunning, isFalse);
    transport.finalizedHeadFuture = null;
    headSource.disconnectGate = null;
    await scanner.start();
    expect(scanner.isRunning, isTrue);
  });

  test('首次游标落盘前的头事件不会启动无归属后台同步', () async {
    assemble(finalizedHeight: 5);
    final finalizedGate = Completer<Object?>();
    transport.finalizedHeadFuture = finalizedGate.future;
    await scanner.replaceWatchedAccounts(<String>[accountA]);

    final starting = scanner.start();
    await _waitUntil(() async => transport.finalizedHeadCalls == 1);
    headSource.emit(99);
    finalizedGate.complete(_blockHash(5));
    await starting;
    await _settle();

    expect(transport.blockHashRequests, isNot(contains(99)));
    expect((await history.load()).cursors[accountA]!.lastSyncedBlock, 5);
  });

  test('stop 必须等待 disconnect 真收口，重启不能与先前清理交叉', () async {
    assemble(finalizedHeight: 5);
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    final disconnectGate = Completer<void>();
    headSource.disconnectGate = disconnectGate.future;

    final stopping = scanner.stop();
    final restarting = scanner.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(headSource.connectCount, 1);
    disconnectGate.complete();
    await stopping;
    headSource.disconnectGate = null;
    await restarting;
    expect(headSource.connectCount, 2);
  });

  test('cleanup 异常在全部清理完成后抛出且不会留下 running 状态', () async {
    assemble(finalizedHeight: 5);
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();
    headSource.disconnectError = StateError('disconnect failed');

    await expectLater(scanner.stop(), throwsStateError);
    expect(scanner.isRunning, isFalse);
    expect(headSource.disconnectCount, 1);
    headSource.disconnectError = null;
    await Future<void>.delayed(Duration.zero);
    await scanner.start();
    expect(scanner.isRunning, isTrue);
  });

  test('listener cancel 同步抛错时仍排空另一个 listener 与 disconnect', () async {
    assemble(finalizedHeight: 5);
    headSource.headCancelError = StateError('head cancel failed');
    await scanner.replaceWatchedAccounts(<String>[accountA]);
    await scanner.start();

    await expectLater(scanner.stop(), throwsStateError);
    expect(headSource.headCancelCount, 1);
    expect(headSource.dropCancelCount, 1);
    expect(headSource.disconnectCount, 1);
    expect(scanner.isRunning, isFalse);
    headSource.headCancelError = null;
  });

  test('subscription 与 sync 退避必须严格大于零', () {
    assemble(finalizedHeight: 5);
    FinalizedTransactionScanner build({
      Duration subscriptionRetryDelay = const Duration(seconds: 1),
      Duration syncRetryDelay = const Duration(seconds: 1),
    }) => FinalizedTransactionScanner(
      rpc: ChainRpc.withTransport(transport),
      history: history,
      headSource: headSource,
      decoder: decoder,
      subscriptionRetryDelay: subscriptionRetryDelay,
      syncRetryDelay: syncRetryDelay,
      pendingPollInterval: Duration.zero,
      interBlockDelay: Duration.zero,
    );

    expect(
      () => build(subscriptionRetryDelay: Duration.zero),
      throwsArgumentError,
    );
    expect(() => build(syncRetryDelay: Duration.zero), throwsArgumentError);
  });
}

final class _FakeTransferDecoder implements FinalizedTransferEventDecoder {
  final Map<int, List<_TransferSpec>> transfersByBlock =
      <int, List<_TransferSpec>>{};

  @override
  List<DecodedFinalizedTransfer> decode({
    required Uint8List eventsBytes,
    required ChainRuntimeContext runtimeContext,
    required int blockNumber,
    required String blockHash,
  }) => <DecodedFinalizedTransfer>[
    for (
      var index = 0;
      index < (transfersByBlock[blockNumber]?.length ?? 0);
      index++
    )
      DecodedFinalizedTransfer(
        fromAccountId: transfersByBlock[blockNumber]![index].from,
        toAccountId: transfersByBlock[blockNumber]![index].to,
        amountFen: BigInt.from(transfersByBlock[blockNumber]![index].amount),
        blockNumber: blockNumber,
        blockHash: blockHash,
        eventRecordIndex: index,
        extrinsicIndex: transfersByBlock[blockNumber]![index].extrinsicIndex,
        sourcePallet: 'OnchainTransaction',
        remark: 'fixture',
      ),
  ];
}

final class _TransferSpec {
  const _TransferSpec(
    this.from,
    this.to,
    this.amount, {
    this.extrinsicIndex = 0,
  });

  final String from;
  final String to;
  final int amount;
  final int? extrinsicIndex;
}

final class _FakeHeadSource implements FinalizedBlockHeadSource {
  final StreamController<int> _heads = StreamController<int>.broadcast();
  final StreamController<void> _dropped = StreamController<void>.broadcast();
  int connectCount = 0;
  int disconnectCount = 0;
  int emittedCount = 0;
  bool connectResult = true;
  Future<void>? disconnectGate;
  Object? disconnectError;
  Object? headCancelError;
  Object? dropCancelError;
  int headCancelCount = 0;
  int dropCancelCount = 0;

  @override
  Stream<int> get finalizedBlockNumbers =>
      _CancelInterceptStream<int>(_heads.stream, () {
        headCancelCount += 1;
        final error = headCancelError;
        if (error != null) throw error;
      });

  @override
  Stream<void> get dropped => _CancelInterceptStream<void>(_dropped.stream, () {
    dropCancelCount += 1;
    final error = dropCancelError;
    if (error != null) throw error;
  });

  @override
  Future<bool> connect() async {
    connectCount += 1;
    return connectResult;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    final gate = disconnectGate;
    if (gate != null) await gate;
    final error = disconnectError;
    if (error != null) throw error;
  }

  void emit(int blockNumber) {
    emittedCount += 1;
    _heads.add(blockNumber);
  }

  Future<void> close() async {
    await _heads.close();
    await _dropped.close();
  }
}

final class _CancelInterceptStream<T> extends Stream<T> {
  const _CancelInterceptStream(this._delegate, this._beforeCancel);

  final Stream<T> _delegate;
  final void Function() _beforeCancel;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _CancelInterceptSubscription<T>(
    _delegate.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
    _beforeCancel,
  );
}

final class _CancelInterceptSubscription<T> implements StreamSubscription<T> {
  const _CancelInterceptSubscription(this._delegate, this._beforeCancel);

  final StreamSubscription<T> _delegate;
  final void Function() _beforeCancel;

  @override
  Future<void> cancel() {
    final cancellation = _delegate.cancel();
    _beforeCancel();
    return cancellation;
  }

  @override
  void onData(void Function(T data)? handleData) =>
      _delegate.onData(handleData);

  @override
  void onError(Function? handleError) => _delegate.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _delegate.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _delegate.pause(resumeSignal);

  @override
  void resume() => _delegate.resume();

  @override
  bool get isPaused => _delegate.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _delegate.asFuture<E>(futureValue);
}

final class _ScannerTransport implements ChainRpcTransport {
  _ScannerTransport({required this.finalizedHeight})
    : _metadataHex = File(
        'test/transaction/fixtures/substrate-v14-system-events-metadata.hex',
      ).readAsStringSync().trim();

  int finalizedHeight;
  final String _metadataHex;
  Future<Object?>? finalizedHeadFuture;
  final Map<int, String?> eventsByNumber = <int, String?>{};
  final Map<int, Future<Object?>> eventFutureByNumber =
      <int, Future<Object?>>{};
  final Map<int, List<String>> blockExtrinsicsByNumber = <int, List<String>>{};
  final List<int> blockHashRequests = <int>[];
  int finalizedHeadCalls = 0;
  int storageCalls = 0;
  int blockBodyCalls = 0;

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<int> accountNextIndex(String accountIdHex) async => 0;

  @override
  Future<Map<String, dynamic>> runtimeVersion() async => _runtimeVersionJson();

  @override
  Future<String> blockHash(int blockNumber) async {
    blockHashRequests.add(blockNumber);
    return _blockHash(blockNumber);
  }

  @override
  Future<String> metadataHex() async => _metadataHex;

  @override
  Future<String?> finalizedStorage(String storageKeyHex) async => null;

  @override
  Future<Map<String, String?>> finalizedStorageValues(
    List<String> storageKeyHexList,
  ) async => <String, String?>{for (final key in storageKeyHexList) key: null};

  @override
  Future<String> submitExtrinsic(String extrinsicHex) async => _hash(1);

  @override
  Future<List<String>> blockExtrinsicsOnce(String blockHashHex) async {
    blockBodyCalls += 1;
    return blockExtrinsicsByNumber[_blockNumber(blockHashHex)] ??
        const <String>[];
  }

  @override
  Future<Object?> request(String method, List<Object?> params) async {
    switch (method) {
      case 'chain_getFinalizedHead':
        finalizedHeadCalls += 1;
        final pending = finalizedHeadFuture;
        return pending == null ? _blockHash(finalizedHeight) : await pending;
      case 'chain_getHeader':
        return <String, Object?>{
          'number':
              '0x${_blockNumber(params.single! as String).toRadixString(16)}',
        };
      case 'state_getRuntimeVersion':
        return _runtimeVersionJson();
      case 'state_getMetadata':
        return _metadataHex;
      case 'state_getStorage':
        storageCalls += 1;
        final blockNumber = _blockNumber(params[1]! as String);
        final pending = eventFutureByNumber[blockNumber];
        if (pending != null) return await pending;
        return eventsByNumber.containsKey(blockNumber)
            ? eventsByNumber[blockNumber]
            : '0x00';
      case 'chain_getBlockHash':
        return _blockHash(finalizedHeight);
    }
    throw StateError('未预期 RPC：$method');
  }

  @override
  Stream<Object?> subscribe(String method, List<Object?> params) =>
      const Stream<Object?>.empty();
}

final class _MemoryPreferences implements PreferencesDataStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

Future<void> _waitUntil(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 500; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('等待异步条件超时');
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

List<int> _successEvent(int extrinsicIndex) => <int>[
  0x00,
  ..._u32(extrinsicIndex),
  0x00,
  0x00,
  ...List<int>.filled(10, 0),
  0x00,
];

List<int> _failureEvent(
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
  ...List<int>.filled(10, 0),
  0x00,
];

List<int> _u32(int value) => <int>[
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

String _account(int byte) => _hash(byte);

String _hash(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';

String _blockHash(int blockNumber) =>
    '0x${blockNumber.toRadixString(16).padLeft(64, '0')}';

int _blockNumber(String blockHash) =>
    int.parse(blockHash.substring(2), radix: 16);

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Map<String, dynamic> _runtimeVersionJson() => <String, dynamic>{
  'specName': 'citizen',
  'implName': 'citizen',
  'authoringVersion': 1,
  'specVersion': 1,
  'implVersion': 1,
  'apis': <Object?>[],
  'transactionVersion': 1,
  'stateVersion': 1,
};
