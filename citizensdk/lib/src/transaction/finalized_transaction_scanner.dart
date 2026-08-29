import 'dart:async';

import '../node/chain_event_subscription.dart';
import '../node/sdk_log.dart';
import 'chain_rpc.dart';
import 'chain_transfer_event_decoder.dart';
import 'finalized_transaction_models.dart';
import 'finalized_transaction_repository.dart';
import 'transaction_status.dart';

/// finalized 块高订阅的可替换边界。
abstract interface class FinalizedBlockHeadSource {
  Stream<int> get finalizedBlockNumbers;

  Stream<void> get dropped;

  Future<bool> connect();

  Future<void> disconnect();
}

/// 把 CitizenSDK 的双头订阅收窄为交易扫描器所需的 finalized 块高。
final class ChainEventFinalizedBlockHeadSource
    implements FinalizedBlockHeadSource {
  ChainEventFinalizedBlockHeadSource(this._subscription);

  final ChainEventSubscription _subscription;

  @override
  Stream<int> get finalizedBlockNumbers => _subscription.events
      .where(
        (event) =>
            event.type == ChainEventType.newFinalizedBlock &&
            event.blockNumber != null,
      )
      .map((event) => event.blockNumber!);

  @override
  Stream<void> get dropped => _subscription.dropped;

  @override
  Future<bool> connect() => _subscription.connect();

  @override
  Future<void> disconnect() async => _subscription.disconnect();
}

/// 公民链账户 finalized 转账流水与本机 pending 收敛服务。
///
/// - 只扫描 finalized 链，不写 best/inBlock 流水；
/// - 新账户从纳入监控时的 finalized 高度开始，不回查导入前历史；
/// - 已有游标重启后每轮最多 [maxBlocksPerRun] 块并继续补缺口；
/// - pending 只有 txHash 精确命中且同 index 的
///   `System.ExtrinsicSuccess/Failed` 才进入链上终态；
/// - transfer、pending outcome 与 cursor 由仓储一次 CAS 提交。
final class FinalizedTransactionScanner {
  FinalizedTransactionScanner({
    required ChainRpc rpc,
    required FinalizedTransactionHistory history,
    required FinalizedBlockHeadSource headSource,
    FinalizedTransferEventDecoder decoder = const ChainTransferEventDecoder(),
    CitizenSdkLogger logger = discardCitizenSdkLog,
    this.maxBlocksPerRun = 120,
    this.subscriptionRetryDelay = const Duration(seconds: 5),
    this.syncRetryDelay = const Duration(seconds: 3),
    this.pendingPollInterval = const Duration(seconds: 3),
    this.interBlockDelay = const Duration(milliseconds: 20),
  }) : _rpc = rpc,
       _history = history,
       _headSource = headSource,
       _decoder = decoder,
       _logger = logger {
    if (maxBlocksPerRun <= 0) {
      throw ArgumentError.value(maxBlocksPerRun, 'maxBlocksPerRun');
    }
    for (final entry in <(String, Duration)>[
      ('subscriptionRetryDelay', subscriptionRetryDelay),
      ('syncRetryDelay', syncRetryDelay),
    ]) {
      if (entry.$2 <= Duration.zero) {
        throw ArgumentError.value(entry.$2, entry.$1, '必须大于零');
      }
    }
    for (final entry in <(String, Duration)>[
      ('pendingPollInterval', pendingPollInterval),
      ('interBlockDelay', interBlockDelay),
    ]) {
      if (entry.$2.isNegative) {
        throw ArgumentError.value(entry.$2, entry.$1, '不能为负数');
      }
    }
  }

  final ChainRpc _rpc;
  final FinalizedTransactionHistory _history;
  final FinalizedBlockHeadSource _headSource;
  final FinalizedTransferEventDecoder _decoder;
  final CitizenSdkLogger _logger;

  final int maxBlocksPerRun;
  final Duration subscriptionRetryDelay;
  final Duration syncRetryDelay;
  final Duration pendingPollInterval;
  final Duration interBlockDelay;

  Set<String> _watchedAccountIds = const <String>{};
  bool _running = false;
  bool _subscriptionConnected = false;
  int _generation = 0;
  int _requestedTarget = -1;
  StreamSubscription<int>? _headListener;
  StreamSubscription<void>? _dropListener;
  Timer? _subscriptionRetryTimer;
  Timer? _syncRetryTimer;
  Timer? _syncContinuationTimer;
  Timer? _pendingTimer;
  Future<void>? _connectTask;
  Future<void>? _syncTask;
  Future<void>? _pendingTask;
  Future<void>? _startTask;
  Future<void>? _stopTask;
  Completer<void>? _stoppedSignal;
  final Set<Future<void>> _tasks = <Future<void>>{};

  bool get isRunning => _running;
  bool get subscriptionConnected => _subscriptionConnected;
  Set<String> get watchedAccountIds =>
      Set<String>.unmodifiable(_watchedAccountIds);

  /// 原子替换完整监控集合；先前集合所有已进入的仓储任务排空后才返回。
  Future<void> replaceWatchedAccounts(Iterable<String> accountIds) async {
    final normalized = <String>{};
    for (final accountId in accountIds) {
      // 模型构造器执行严格 AccountId 校验。
      normalized.add(WatchedChainAccount(accountId: accountId).accountId);
    }
    if (_sameSet(normalized, _watchedAccountIds)) return;
    await stop();
    _watchedAccountIds = Set<String>.unmodifiable(normalized);
  }

  /// 启动订阅、初始化首次游标并补扫已有持久游标后的 finalized 缺口。
  ///
  /// 同一轮并发启动共享同一个 Future；初始化失败只有在 listener/连接清理完毕后
  /// 才向所有调用方返回同一个错误。正在停止时的启动会先等待前一代际完整退出。
  Future<void> start() {
    final stopping = _stopTask;
    if (stopping != null) {
      return stopping.then<void>((_) => start());
    }
    final current = _startTask;
    if (current != null) return current;
    late final Future<void> task;
    task = Future<void>.sync(_performStart);
    _startTask = task;
    unawaited(
      task.then<void>(
        (_) {
          if (identical(_startTask, task)) _startTask = null;
        },
        onError: (Object _, StackTrace __) {
          if (identical(_startTask, task)) _startTask = null;
        },
      ),
    );
    return task;
  }

  Future<void> _performStart() async {
    if (_running) return;
    if (_watchedAccountIds.isEmpty) return;
    final generation = ++_generation;
    _stoppedSignal = Completer<void>();
    _running = true;
    _subscriptionConnected = false;
    _requestedTarget = -1;
    final initialization = _track(generation, () async {
      final finalized = await _awaitExternal(
        generation,
        _rpc.fetchFinalizedBlock(),
      );
      if (!_isCurrent(generation)) return;
      await _history.ensureCursors(
        accountIds: _watchedAccountIds,
        startBlock: finalized.blockNumber,
      );
      if (!_isCurrent(generation)) return;
      // 首次 finalized 与游标必须先完整落盘，再暴露订阅 listener。这样启动前
      // 已排队的头事件不能产生缺少游标、且 failed-start 无法归属的后台任务。
      _installListeners(generation);
      _requestSync(generation, finalized.blockNumber);
      _ensureConnected(generation);
      _startPendingPolling(generation);
    });
    try {
      await initialization;
    } on _FinalizedScannerStopped {
      return;
    } on Object {
      if (_isCurrent(generation)) {
        await _abortFailedStart(generation);
      }
      rethrow;
    }
  }

  void _installListeners(int generation) {
    if (!_isCurrent(generation)) return;
    _headListener = _headSource.finalizedBlockNumbers.listen(
      (blockNumber) {
        if (!_isCurrent(generation)) return;
        _requestSync(generation, blockNumber);
      },
      onError: (Object error, StackTrace stackTrace) {
        _debug('finalized 订阅错误: $error');
      },
    );
    _dropListener = _headSource.dropped.listen((_) {
      if (!_isCurrent(generation) || !_subscriptionConnected) return;
      _subscriptionConnected = false;
      _scheduleSubscriptionRetry(generation);
    });
  }

  /// 同步废止当前代际并等待已进入的外部读写真实收口。
  Future<void> stop() {
    final current = _stopTask;
    if (current != null) return current;
    late final Future<void> task;
    task = _performStop();
    _stopTask = task;
    unawaited(
      task.then<void>(
        (_) {
          if (identical(_stopTask, task)) _stopTask = null;
        },
        onError: (Object _, StackTrace __) {
          if (identical(_stopTask, task)) _stopTask = null;
        },
      ),
    );
    return task;
  }

  Future<void> _performStop() async {
    if (!_running && _tasks.isEmpty) return;
    _running = false;
    _subscriptionConnected = false;
    final stoppedSignal = _stoppedSignal;
    if (stoppedSignal != null && !stoppedSignal.isCompleted) {
      stoppedSignal.complete();
    }
    _generation += 1;
    _subscriptionRetryTimer?.cancel();
    _syncRetryTimer?.cancel();
    _syncContinuationTimer?.cancel();
    _pendingTimer?.cancel();
    _subscriptionRetryTimer = null;
    _syncRetryTimer = null;
    _syncContinuationTimer = null;
    _pendingTimer = null;
    final headListener = _headListener;
    final dropListener = _dropListener;
    _headListener = null;
    _dropListener = null;
    final cleanupFailure = await _settleCleanup(<Future<void>>[
      if (headListener != null) Future<void>.sync(headListener.cancel),
      if (dropListener != null) Future<void>.sync(dropListener.cancel),
      Future<void>.sync(_headSource.disconnect),
    ]);
    while (_tasks.isNotEmpty) {
      await Future.wait<void>(List<Future<void>>.of(_tasks));
    }
    _connectTask = null;
    _syncTask = null;
    _pendingTask = null;
    _startTask = null;
    _stoppedSignal = null;
    if (cleanupFailure != null) {
      Error.throwWithStackTrace(
        cleanupFailure.error,
        cleanupFailure.stackTrace,
      );
    }
  }

  Future<void> _abortFailedStart(int generation) async {
    if (!_isCurrent(generation)) return;
    _running = false;
    _subscriptionConnected = false;
    final stoppedSignal = _stoppedSignal;
    if (stoppedSignal != null && !stoppedSignal.isCompleted) {
      stoppedSignal.complete();
    }
    _generation += 1;
    _subscriptionRetryTimer?.cancel();
    _syncRetryTimer?.cancel();
    _syncContinuationTimer?.cancel();
    _pendingTimer?.cancel();
    _subscriptionRetryTimer = null;
    _syncRetryTimer = null;
    _syncContinuationTimer = null;
    _pendingTimer = null;
    final headListener = _headListener;
    final dropListener = _dropListener;
    _headListener = null;
    _dropListener = null;
    final cleanupFailure = await _settleCleanup(<Future<void>>[
      if (headListener != null) Future<void>.sync(headListener.cancel),
      if (dropListener != null) Future<void>.sync(dropListener.cancel),
      Future<void>.sync(_headSource.disconnect),
    ]);
    _connectTask = null;
    _syncTask = null;
    _pendingTask = null;
    _stoppedSignal = null;
    if (cleanupFailure != null) {
      Error.throwWithStackTrace(
        cleanupFailure.error,
        cleanupFailure.stackTrace,
      );
    }
  }

  void _ensureConnected(int generation) {
    if (!_isCurrent(generation) || _subscriptionConnected) return;
    if (_connectTask != null) return;
    late final Future<void> task;
    task = _track(generation, () async {
      var connected = false;
      try {
        connected = await _awaitExternal(generation, _headSource.connect());
      } on _FinalizedScannerStopped {
        return;
      } on Object catch (error) {
        _debug('finalized 订阅连接失败: $error');
      }
      if (!_isCurrent(generation)) return;
      _subscriptionConnected = connected;
      if (connected) {
        _requestLatestSync(generation);
      } else {
        _scheduleSubscriptionRetry(generation);
      }
    });
    _connectTask = task;
    unawaited(
      task.then<void>(
        (_) {
          if (identical(_connectTask, task)) _connectTask = null;
        },
        onError: (Object _, StackTrace __) {
          if (identical(_connectTask, task)) _connectTask = null;
        },
      ),
    );
  }

  void _scheduleSubscriptionRetry(int generation) {
    if (!_isCurrent(generation) || _subscriptionRetryTimer != null) return;
    _subscriptionRetryTimer = Timer(subscriptionRetryDelay, () {
      _subscriptionRetryTimer = null;
      _ensureConnected(generation);
    });
  }

  void _requestLatestSync(int generation) {
    _launch(generation, () async {
      final finalized = await _awaitExternal(
        generation,
        _rpc.fetchFinalizedBlock(),
      );
      if (!_isCurrent(generation)) return;
      _requestSync(generation, finalized.blockNumber);
    });
  }

  void _requestSync(int generation, int targetBlock) {
    if (!_isCurrent(generation)) return;
    if (targetBlock > _requestedTarget) _requestedTarget = targetBlock;
    if (_syncTask != null) return;
    late final Future<void> task;
    task = _track(generation, () => _runSyncBatch(generation));
    _syncTask = task;
    unawaited(
      task.then<void>(
        (_) {
          if (!identical(_syncTask, task)) return;
          _syncTask = null;
          if (!_isCurrent(generation)) return;
          _scheduleContinuationIfNeeded(generation);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!identical(_syncTask, task)) return;
          _syncTask = null;
          if (_isCurrent(generation)) {
            _debug('finalized 同步批次失败: $error');
            _scheduleSyncRetry(generation);
          }
        },
      ),
    );
  }

  Future<void> _runSyncBatch(int generation) async {
    if (!_isCurrent(generation)) return;
    final state = await _history.load();
    if (!_isCurrent(generation)) return;
    final cursors = <TransactionSyncCursor>[
      for (final accountId in _watchedAccountIds)
        if (state.cursors[accountId] case final cursor?) cursor,
    ];
    if (cursors.length != _watchedAccountIds.length) {
      throw StateError('监控账户缺少持久游标');
    }
    final minimumCursor = cursors
        .map((cursor) => cursor.lastSyncedBlock)
        .reduce((left, right) => left < right ? left : right);
    final startBlock = minimumCursor + 1;
    final target = _requestedTarget;
    if (startBlock > target) return;
    final endBlock = startBlock + maxBlocksPerRun - 1 < target
        ? startBlock + maxBlocksPerRun - 1
        : target;
    for (var blockNumber = startBlock; blockNumber <= endBlock; blockNumber++) {
      if (!_isCurrent(generation)) return;
      try {
        await _processBlock(generation, blockNumber, advanceCursors: true);
      } on Object catch (error) {
        if (_isCurrent(generation)) {
          _debug('同步 finalized #$blockNumber 失败，保留游标重试: $error');
          _scheduleSyncRetry(generation);
        }
        return;
      }
      if (!_isCurrent(generation)) return;
      if (interBlockDelay > Duration.zero) {
        await Future<void>.delayed(interBlockDelay);
      }
    }
  }

  void _scheduleContinuationIfNeeded(int generation) {
    if (!_isCurrent(generation) || _syncContinuationTimer != null) return;
    _launch(generation, () async {
      final state = await _history.load();
      if (!_isCurrent(generation)) return;
      final cursors = <int>[
        for (final accountId in _watchedAccountIds)
          if (state.cursors[accountId] case final cursor?)
            cursor.lastSyncedBlock,
      ];
      if (cursors.length != _watchedAccountIds.length || cursors.isEmpty) {
        return;
      }
      final minimum = cursors.reduce(
        (left, right) => left < right ? left : right,
      );
      if (minimum >= _requestedTarget) return;
      _syncContinuationTimer = Timer(Duration.zero, () {
        _syncContinuationTimer = null;
        _requestSync(generation, _requestedTarget);
      });
    });
  }

  void _scheduleSyncRetry(int generation) {
    if (!_isCurrent(generation) || _syncRetryTimer != null) return;
    _syncRetryTimer = Timer(syncRetryDelay, () {
      _syncRetryTimer = null;
      _requestLatestSync(generation);
    });
  }

  Future<void> _processBlock(
    int generation,
    int blockNumber, {
    required bool advanceCursors,
  }) async {
    final blockHash = await _awaitExternal(
      generation,
      _rpc.fetchBlockHash(blockNumber),
    );
    if (!_isCurrent(generation)) return;
    final eventsBytes = await _awaitExternal(
      generation,
      _rpc.fetchSystemEventsAtBlock(blockHash),
    );
    if (!_isCurrent(generation)) return;

    final decodedTransfers = <DecodedFinalizedTransfer>[];
    if (eventsBytes != null) {
      if (eventsBytes.isEmpty) throw const FormatException('System.Events 为空');
      final context = await _awaitExternal(
        generation,
        _rpc.fetchRuntimeContext(blockHashHex: blockHash),
      );
      if (!_isCurrent(generation)) return;
      decodedTransfers.addAll(
        _decoder.decode(
          eventsBytes: eventsBytes,
          runtimeContext: context,
          blockNumber: blockNumber,
          blockHash: blockHash,
        ),
      );
    }

    final state = await _history.load();
    if (!_isCurrent(generation)) return;
    final eligibleAccountIds = <String>{
      for (final accountId in _watchedAccountIds)
        if (state.cursors[accountId] case final cursor?)
          if (blockNumber > cursor.lastSyncedBlock) accountId,
    };
    final openSubmissions = state.submissions.values
        .where(
          (entry) =>
              _watchedAccountIds.contains(entry.accountId) &&
              !entry.hasChainOutcome,
        )
        .toList(growable: false);
    final outcomes = <String, ChainExtrinsicOutcome>{};
    final extrinsicIndexBySubmission = <String, int>{};
    final claimedSenders = <String>{};
    if (openSubmissions.isNotEmpty) {
      // 只在确有 pending 时取一次块体；失败时整个块不提交、不推进游标。
      final extrinsics = await _awaitExternal(
        generation,
        _rpc.fetchBlockExtrinsics(blockHash),
      );
      if (!_isCurrent(generation)) return;
      for (final submission in openSubmissions) {
        final index = await ChainRpc.findExtrinsicIndexInHexList(
          extrinsics,
          txHashHex: submission.txHash,
        );
        if (!_isCurrent(generation)) return;
        if (index == null) continue;
        if (eventsBytes == null) {
          throw StateError('txHash 已命中区块，但没有 System.Events 可核对');
        }
        final outcome = await _awaitExternal(
          generation,
          _rpc.findExtrinsicOutcomeAtBlock(
            eventsBytes: eventsBytes,
            extrinsicIndex: index,
            blockHashHex: blockHash,
          ),
        );
        if (!_isCurrent(generation)) return;
        if (outcome == null) {
          throw StateError('txHash 已命中，但同 index 没有明确 Success/Failed');
        }
        outcomes[submission.recordKey] = outcome;
        extrinsicIndexBySubmission[submission.recordKey] = index;
        claimedSenders.add('${submission.accountId}#$index');
      }
    }

    final accountTransfers = <FinalizedAccountTransfer>[];
    for (final transfer in decodedTransfers) {
      if (eligibleAccountIds.contains(transfer.toAccountId)) {
        accountTransfers.add(
          _accountTransfer(transfer, FinalizedTransferDirection.incoming),
        );
      }
      final claimed = claimedSenders.contains(
        '${transfer.fromAccountId}#${transfer.extrinsicIndex}',
      );
      if (eligibleAccountIds.contains(transfer.fromAccountId) && !claimed) {
        accountTransfers.add(
          _accountTransfer(transfer, FinalizedTransferDirection.outgoing),
        );
      }
    }
    if (!_isCurrent(generation)) return;
    await _history.commitFinalizedBlock(
      blockNumber: blockNumber,
      blockHash: blockHash,
      transfers: accountTransfers,
      outcomes: outcomes,
      extrinsicIndexBySubmissionKey: extrinsicIndexBySubmission,
      advanceCursorAccountIds: advanceCursors
          ? eligibleAccountIds
          : const <String>[],
    );
  }

  FinalizedAccountTransfer _accountTransfer(
    DecodedFinalizedTransfer value,
    FinalizedTransferDirection direction,
  ) {
    final accountId = direction == FinalizedTransferDirection.incoming
        ? value.toAccountId
        : value.fromAccountId;
    return FinalizedAccountTransfer(
      recordKey: FinalizedAccountTransfer.eventRecordKey(
        accountId,
        value.blockHash,
        value.eventRecordIndex,
      ),
      accountId: accountId,
      direction: direction,
      fromAccountId: value.fromAccountId,
      toAccountId: value.toAccountId,
      amountFen: value.amountFen,
      blockNumber: value.blockNumber,
      blockHash: value.blockHash,
      eventRecordIndex: value.eventRecordIndex,
      extrinsicIndex: value.extrinsicIndex,
      sourcePallet: value.sourcePallet,
      remark: value.remark,
    );
  }

  void _startPendingPolling(int generation) {
    if (!_isCurrent(generation) || pendingPollInterval == Duration.zero) return;
    _pendingTimer = Timer.periodic(pendingPollInterval, (_) {
      if (!_isCurrent(generation) || _pendingTask != null) return;
      late final Future<void> task;
      task = _track(generation, () => _pollPending(generation));
      _pendingTask = task;
      unawaited(
        task.then<void>(
          (_) {
            if (identical(_pendingTask, task)) _pendingTask = null;
          },
          onError: (Object _, StackTrace __) {
            if (identical(_pendingTask, task)) _pendingTask = null;
          },
        ),
      );
    });
  }

  Future<void> _pollPending(int generation) async {
    final state = await _history.load();
    if (!_isCurrent(generation)) return;
    final open = state.submissions.values
        .where(
          (entry) =>
              _watchedAccountIds.contains(entry.accountId) &&
              !entry.hasChainOutcome,
        )
        .toList(growable: false);
    if (open.isEmpty) return; // 空闲期只读本地仓储，不打链。

    final finalized = await _awaitExternal(
      generation,
      _rpc.fetchFinalizedBlock(),
    );
    if (!_isCurrent(generation)) return;
    _requestSync(generation, finalized.blockNumber);
    final processedAnchors = <String>{};
    for (final submission in open) {
      final anchor = submission.anchorBlockHash;
      if (anchor == null || !processedAnchors.add(anchor)) continue;
      final blockNumber = await _awaitExternal(
        generation,
        _rpc.fetchBlockNumberByHash(anchor),
      );
      if (!_isCurrent(generation)) return;
      if (blockNumber == null || blockNumber > finalized.blockNumber) continue;
      final canonicalHash = await _awaitExternal(
        generation,
        _rpc.fetchBlockHash(blockNumber),
      );
      if (!_isCurrent(generation)) return;
      if (canonicalHash != anchor) continue;
      try {
        await _processBlock(generation, blockNumber, advanceCursors: false);
      } on Object catch (error) {
        if (_isCurrent(generation)) {
          _debug('pending 锚块 #$blockNumber 尚未能明确核实: $error');
        }
      }
    }
  }

  Future<void> _track(int generation, Future<void> Function() operation) {
    final raw = Future<void>.sync(operation);
    late final Future<void> settled;
    settled = raw.then<void>(
      (_) => _tasks.remove(settled),
      onError: (Object error, StackTrace stackTrace) {
        _tasks.remove(settled);
        if (_isCurrent(generation)) _debug('后台任务失败: $error');
      },
    );
    _tasks.add(settled);
    return raw;
  }

  void _launch(int generation, Future<void> Function() operation) {
    final task = _track(generation, operation);
    unawaited(task.catchError((Object _, StackTrace __) {}));
  }

  bool _isCurrent(int generation) => _running && _generation == generation;

  Future<T> _awaitExternal<T>(int generation, Future<T> external) async {
    final signal = _stoppedSignal;
    if (!_isCurrent(generation) || signal == null || signal.isCompleted) {
      _consumeCleanup(external);
      throw const _FinalizedScannerStopped();
    }
    final externalOutcome = external.then<_ExternalOutcome<T>>(
      _ExternalOutcome<T>.success,
      onError: (Object error, StackTrace stackTrace) =>
          _ExternalOutcome<T>.failure(error, stackTrace),
    );
    final outcome = await Future.any<_ExternalOutcome<T>>(
      <Future<_ExternalOutcome<T>>>[
        externalOutcome,
        signal.future.then((_) => _ExternalOutcome<T>.stopped()),
      ],
    );
    if (outcome.stopped) throw const _FinalizedScannerStopped();
    final error = outcome.error;
    if (error != null) Error.throwWithStackTrace(error, outcome.stackTrace!);
    return outcome.value as T;
  }

  static void _consumeCleanup<T>(Future<T>? future) {
    if (future == null) return;
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
  }

  static Future<_CleanupFailure?> _settleCleanup(
    Iterable<Future<void>> futures,
  ) async {
    final outcomes = await Future.wait<_CleanupFailure?>(
      futures.map(
        (future) => future.then<_CleanupFailure?>(
          (_) => null,
          onError: (Object error, StackTrace stackTrace) =>
              _CleanupFailure(error, stackTrace),
        ),
      ),
    );
    for (final outcome in outcomes) {
      if (outcome != null) return outcome;
    }
    return null;
  }

  void _debug(String message) {
    _logger(
      CitizenSdkLogEvent(
        level: CitizenSdkLogLevel.debug,
        scope: 'finalized_transaction_scanner',
        message: message,
      ),
    );
  }

  static bool _sameSet(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    return left.every(right.contains);
  }
}

final class _FinalizedScannerStopped implements Exception {
  const _FinalizedScannerStopped();
}

final class _ExternalOutcome<T> {
  const _ExternalOutcome.success(T this.value)
    : error = null,
      stackTrace = null,
      stopped = false;

  const _ExternalOutcome.failure(this.error, this.stackTrace)
    : value = null,
      stopped = false;

  const _ExternalOutcome.stopped()
    : value = null,
      error = null,
      stackTrace = null,
      stopped = true;

  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
  final bool stopped;
}

final class _CleanupFailure {
  const _CleanupFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
