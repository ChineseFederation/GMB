import 'dart:async';
import 'dart:convert';

import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/log/app_log.dart';
import 'package:citizenapp/rpc/pallet_registry.dart';
import 'package:citizenapp/transaction/shared/local_tx_store.dart';
import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart' show Events, Hasher;
import 'package:polkadart_keyring/polkadart_keyring.dart' show Keyring;

import 'chain_event_subscription.dart';
import 'chain_read_cache.dart';
import 'chain_rpc.dart';
import 'smoldot_client.dart';

class _DecodedTransferEvent {
  const _DecodedTransferEvent({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountFen,
    this.remark,
  });

  final String fromAccountId;
  final String toAccountId;
  final String amountFen;
  final String? remark;
}

/// owner 被 stop 同步废止后，用于结束仍在等待外部 RPC/smoldot 的监控任务。
class _ChainTxMonitorStopped implements Exception {
  const _ChainTxMonitorStopped();
}

/// 一次监控启动代次的唯一 owner。
///
/// 所有后台任务都登记在创建它们的 owner 下；stop 同步废止 owner 后，旧任务即使在
/// 外部 RPC 返回，也只能结束自身，不能写库、建订阅或清理新代次的任务字段。
class _ChainTxMonitorOwner {
  _ChainTxMonitorOwner(this.generation, this.watchedAccountsRevision);

  final int generation;
  final int watchedAccountsRevision;
  final Set<Future<void>> pendingTasks = <Future<void>>{};
  final Completer<void> stoppedSignal = Completer<void>();

  bool stopped = false;
  Future<void>? startTask;
  Future<void>? subscriptionConnectTask;
  Future<void>? latestSyncTask;
  Future<void>? syncTask;
  Future<void>? confirmTask;
}

/// 链上交易监控服务（本机增量流水模式）。
///
/// (ADR-017 全端 finalized 单一口径)：citizenapp 不查询钱包导入前
/// 历史，也不让全节点替手机维护交易索引。本服务只按 finalized 游标小步
/// 同步 System.Events 写入流水——交易状态两态(已提交→已确认)，不再扫
/// best 链、不再产生"已出块"中间态；本地页面只读 Isar 缓存。
class ChainTxMonitor {
  ChainTxMonitor._()
      : _subscription = ChainEventSubscription(),
        _chainRpc = ChainRpc(),
        _subscriptionRetryDelay = const Duration(seconds: 5),
        _confirmPollInterval = const Duration(seconds: 3);

  /// 单测专用：注入可控订阅、离线 RPC 和短退避。
  ///
  /// - 真 [ChainRpc] 在单测里会真的去拉起 smoldot（flutter_test 环境没有原生库，
  ///   抛错时机还不确定），必须注入离线 fake，否则用例随机 flaky。
  /// - 退避可注入是因为 `start()` 里有 Isar 真 I/O，用 `fakeAsync` 拨表会卡在
  ///   真实事件循环上；只能走真实定时器，把 5 秒缩到毫秒级。
  @visibleForTesting
  ChainTxMonitor.forTesting({
    required ChainEventSubscription subscription,
    required ChainRpc chainRpc,
    Duration subscriptionRetryDelay = const Duration(milliseconds: 20),
    Duration confirmPollInterval = const Duration(milliseconds: 20),
  })  : _subscription = subscription,
        _chainRpc = chainRpc,
        _subscriptionRetryDelay = subscriptionRetryDelay,
        _confirmPollInterval = confirmPollInterval;

  static final ChainTxMonitor instance = ChainTxMonitor._();

  final ChainEventSubscription _subscription;
  final ChainRpc _chainRpc;
  StreamSubscription<ChainEvent>? _listener;
  StreamSubscription<void>? _dropListener;
  Timer? _subscriptionRetryTimer;
  Timer? _syncRetryTimer;
  bool _running = false;
  bool _subscriptionConnected = false;
  int _generation = 0;
  _ChainTxMonitorOwner? _owner;
  _ChainTxMonitorOwner? _lastStoppedOwner;
  Future<void>? _lastStopDrain;

  /// 订阅重连退避；首次连接失败与运行中断开共用同一条退避路径。
  final Duration _subscriptionRetryDelay;

  /// 待确认记录的确认轮询间隔。
  final Duration _confirmPollInterval;
  Timer? _confirmTimer;

  /// 单测断言用：当前是否认为链事件订阅在线。
  @visibleForTesting
  bool get subscriptionConnectedForTesting => _subscriptionConnected;

  /// 当前监控的钱包：AccountId（小写 0x + 64 位 hex） → SS58 地址。
  Map<String, String> _ss58AddressByAccountId = const <String, String>{};
  int _watchedAccountsRevision = 0;

  /// 余额变动回调：当检测到余额变化（写入新交易记录后）通知外部刷新。
  void Function(String ss58Address, double newBalance)? onBalanceChanged;

  /// SS58 前缀。

  /// 每次补同步最多连续处理的区块数，避免手机长时间离线后一次性压节点。
  static const int _maxBlocksPerRun = 120;

  // ──── 已知事件的 pallet_index + event_index ────

  /// Balances::Transfer (pallet=2, event=2)，仅作为底层余额事件兜底。
  static const int _balancesPallet = PalletRegistry.balancesPallet;
  static const int _transferEvent = 2;
  static const int _onchainTransactionPallet =
      PalletRegistry.onchainTransactionPallet;
  static const int _transferWithRemarkEvent = 2;

  /// System.Events storage key（twox128("System") + twox128("Events")）。
  static final Uint8List _eventsStorageKey = _buildEventsKey();

  static Uint8List _buildEventsKey() {
    final palletHash = Hasher.twoxx128.hashString('System');
    final storageHash = Hasher.twoxx128.hashString('Events');
    final key = Uint8List(palletHash.length + storageHash.length);
    key.setAll(0, palletHash);
    key.setAll(palletHash.length, storageHash);
    return key;
  }

  // ──── 公开 API ────

  /// 原子替换完整监控集合，并排空旧集合所有任务。
  ///
  /// token 在任何 await 前同步推进；旧 RPC/订阅返回后的 owner 立即失效。返回的
  /// Future 只在已进入数据库的旧写入也真实结束后完成，删除事实必须先 await 它。
  Future<void> replaceWatchedAccounts(
    Map<String, String> ss58AddressByAccountId,
  ) {
    final normalized = <String, String>{};
    for (final entry in ss58AddressByAccountId.entries) {
      final accountId = LocalTxStore.requireAccountId(entry.key);
      final ss58Address = entry.value.trim();
      if (ss58Address.isEmpty) {
        throw ArgumentError.value(entry.value, 'ss58Address', '地址不能为空');
      }
      normalized[accountId] = ss58Address;
    }
    if (_sameWatchedAccounts(normalized, _ss58AddressByAccountId)) {
      return _lastStopDrain ?? Future<void>.value();
    }
    _watchedAccountsRevision += 1;
    _ss58AddressByAccountId = Map<String, String>.unmodifiable(normalized);
    return stop();
  }

  @visibleForTesting
  Map<String, String> get watchedAccountsForTesting => _ss58AddressByAccountId;

  /// 页面只在完整钱包快照已登记监控集合后才能启动全局任务；详情页不得凭一张陈旧
  /// 卡片自行补回已删除账户。
  bool get hasWatchedAccounts => _ss58AddressByAccountId.isNotEmpty;

  /// 启动监控。
  Future<void> start() {
    final current = _owner;
    if (current != null && _isCurrent(current)) {
      final starting = current.startTask;
      if (starting != null) return starting;
      _ensureSubscription(current);
      _requestLatestSync(current);
      return Future<void>.value();
    }

    final owner = _ChainTxMonitorOwner(
      ++_generation,
      _watchedAccountsRevision,
    );
    _owner = owner;
    _running = true;
    _subscriptionConnected = false;

    late final Future<void> task;
    task = _track(owner, _start(owner));
    owner.startTask = task;
    task.then<void>(
      (_) {
        if (identical(owner.startTask, task)) owner.startTask = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(owner.startTask, task)) owner.startTask = null;
      },
    );
    return task;
  }

  Future<void> _start(_ChainTxMonitorOwner owner) async {
    try {
      _listener = _subscription.events.listen(
        (event) => _launch(owner, _onEvent(owner, event)),
      );
      // 断开信号必须订阅：自动确认**只有**「finalized 事件 → _syncThrough →
      // _confirmOpenSubmits」这一条通路，订阅断了不重连就等于自动确认永久失效。
      _dropListener = _subscription.dropped.listen(
        (_) => _onSubscriptionDropped(owner),
      );
      _startConfirmPolling(owner);
      _ensureSubscription(owner);
      AppLog.d(
        '[TxMonitor] 交易监控已启动，监控 ${_ss58AddressByAccountId.length} 个钱包',
      );

      // metadata 预热和启动补同步都归属本代；stop 后只允许完成已有外部调用，
      // 返回结果不得再产生状态、订阅或数据库副作用。
      _launch(owner, _warmMetadata(owner));
      _requestLatestSync(owner);
    } catch (_) {
      if (_isCurrent(owner)) {
        _running = false;
        _owner = null;
        _generation += 1;
      }
      rethrow;
    }
  }

  Future<void> _warmMetadata(_ChainTxMonitorOwner owner) async {
    try {
      await _awaitExternal(owner, _chainRpc.fetchMetadata());
    } catch (error) {
      if (_isCurrent(owner)) {
        AppLog.d('[TxMonitor] metadata 预热失败,首次使用时再取: $error');
      }
    }
  }

  bool _isCurrent(_ChainTxMonitorOwner owner) {
    return _running &&
        !owner.stopped &&
        identical(_owner, owner) &&
        owner.generation == _generation &&
        owner.watchedAccountsRevision == _watchedAccountsRevision;
  }

  /// 等待不可取消的外部 Future 时，同时监听 owner 的同步 stop 信号。
  ///
  /// 底层 Future 即使稍后才返回，也已被 [Future.any] 消费且没有继续执行监控逻辑的
  /// continuation；stop 的 drain 因此只等待本代任务真正退出，不会被轻节点长同步卡住。
  Future<T> _awaitExternal<T>(
    _ChainTxMonitorOwner owner,
    Future<T> external,
  ) async {
    if (!_isCurrent(owner)) throw const _ChainTxMonitorStopped();
    final result = await Future.any<T>(<Future<T>>[
      external,
      owner.stoppedSignal.future.then<T>(
        (_) => throw const _ChainTxMonitorStopped(),
      ),
    ]);
    if (!_isCurrent(owner)) throw const _ChainTxMonitorStopped();
    return result;
  }

  Future<T> _track<T>(_ChainTxMonitorOwner owner, Future<T> task) {
    late final Future<void> drainTask;
    drainTask = task
        .then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        )
        .whenComplete(() => owner.pendingTasks.remove(drainTask));
    owner.pendingTasks.add(drainTask);
    return task;
  }

  void _launch(_ChainTxMonitorOwner owner, Future<void> task) {
    final tracked = _track(owner, task);
    unawaited(
      tracked.catchError((Object error, StackTrace stackTrace) {
        if (_isCurrent(owner)) {
          AppLog.d('[TxMonitor] 后台任务失败: $error');
        }
      }),
    );
  }

  /// 同步废止当前代次，并返回全部已登记后台任务和订阅真实结束后的 drain Future。
  Future<void> stop() {
    final owner = _owner;
    _generation += 1;
    _running = false;
    if (owner != null) {
      owner.stopped = true;
      if (!owner.stoppedSignal.isCompleted) owner.stoppedSignal.complete();
    }
    _owner = null;
    _subscriptionConnected = false;
    _subscriptionRetryTimer?.cancel();
    _subscriptionRetryTimer = null;
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
    _confirmTimer?.cancel();
    _confirmTimer = null;
    final listener = _listener;
    _listener = null;
    final dropListener = _dropListener;
    _dropListener = null;
    _subscription.disconnect();
    AppLog.d('[TxMonitor] 交易监控已停止');

    if (owner == null) {
      return _lastStopDrain ?? Future<void>.value();
    }

    final cancellationTasks = <Future<void>>[
      if (listener != null) listener.cancel(),
      if (dropListener != null) dropListener.cancel(),
    ];
    final drain = _drain(owner, cancellationTasks);
    _lastStoppedOwner = owner;
    _lastStopDrain = drain;
    drain.then<void>(
      (_) {
        if (identical(_lastStoppedOwner, owner)) {
          _lastStoppedOwner = null;
          _lastStopDrain = null;
        }
      },
      onError: (Object _, StackTrace __) {
        if (identical(_lastStoppedOwner, owner)) {
          _lastStoppedOwner = null;
          _lastStopDrain = null;
        }
      },
    );
    return drain;
  }

  Future<void> _drain(
    _ChainTxMonitorOwner owner,
    List<Future<void>> cancellationTasks,
  ) async {
    Object? cancellationError;
    StackTrace? cancellationStackTrace;
    try {
      await Future.wait<void>(cancellationTasks);
    } catch (error, stackTrace) {
      cancellationError = error;
      cancellationStackTrace = stackTrace;
    }
    while (owner.pendingTasks.isNotEmpty) {
      final pending = owner.pendingTasks.toList(growable: false);
      await Future.wait<void>(pending);
    }
    if (cancellationError != null) {
      Error.throwWithStackTrace(cancellationError, cancellationStackTrace!);
    }
  }

  // ──── 同步调度 ────

  void _ensureSubscription(_ChainTxMonitorOwner owner) {
    if (!_isCurrent(owner)) return;
    if (_subscriptionConnected) return;
    if (owner.subscriptionConnectTask != null) return;

    late final Future<void> task;
    task = _track(owner, _connectSubscriptionOnce(owner));
    owner.subscriptionConnectTask = task;
    task.then<void>(
      (_) {
        if (identical(owner.subscriptionConnectTask, task)) {
          owner.subscriptionConnectTask = null;
        }
      },
      onError: (Object _, StackTrace __) {
        if (identical(owner.subscriptionConnectTask, task)) {
          owner.subscriptionConnectTask = null;
        }
      },
    );
  }

  Future<void> _connectSubscriptionOnce(_ChainTxMonitorOwner owner) async {
    final connected = await _awaitExternal(owner, _subscription.connect());
    if (!_isCurrent(owner)) {
      // stop 已同步 disconnect；若期间没有新代次，防止晚到 connect 再挂回底层。
      if (_owner == null) _subscription.disconnect();
      return;
    }
    if (connected) {
      _subscriptionConnected = true;
      _subscriptionRetryTimer?.cancel();
      _subscriptionRetryTimer = null;
      _requestLatestSync(owner);
      return;
    }

    _scheduleSubscriptionRetry(owner);
  }

  /// 底层链事件订阅断开：把连接标记落回 false 并排队重连。
  ///
  /// **必须走定时器而不是立即重连**：轻节点持续不可用时，`connect()` 会立刻再失败、
  /// 流也会立刻再结束，立即重连就退化成烧 CPU 的热循环。退避与首次连接失败同一条路径。
  ///
  /// 断连期间漏掉的 finalized 块不需要在这里补扫：重连成功后
  /// [_connectSubscriptionOnce] 既有的 `_syncToLatest()` 会按游标补齐。
  void _onSubscriptionDropped(_ChainTxMonitorOwner owner) {
    if (!_isCurrent(owner)) return;
    // 两条子订阅先后结束会各发一次；第二次已经是断开态，直接忽略。
    if (!_subscriptionConnected) return;
    _subscriptionConnected = false;
    AppLog.d('[TxMonitor] 链事件订阅已断开，排队重连');
    _scheduleSubscriptionRetry(owner);
  }

  void _scheduleSubscriptionRetry(_ChainTxMonitorOwner owner) {
    if (!_isCurrent(owner) || _subscriptionRetryTimer != null) return;
    late final Timer timer;
    timer = Timer(_subscriptionRetryDelay, () {
      if (identical(_subscriptionRetryTimer, timer)) {
        _subscriptionRetryTimer = null;
      }
      if (!_isCurrent(owner)) return;
      _ensureSubscription(owner);
    });
    _subscriptionRetryTimer = timer;
  }

  Future<void> _onEvent(
    _ChainTxMonitorOwner owner,
    ChainEvent event,
  ) async {
    if (!_isCurrent(owner) || _ss58AddressByAccountId.isEmpty) return;
    final blockNumber = event.blockNumber;
    if (blockNumber == null) return;
    switch (event.type) {
      case ChainEventType.newBlock:
        // (ADR-017)：best 头只是链尖竞争中的候选，不作为任何
        // 业务数据来源；流水统一等 finalized 头驱动。
        break;
      case ChainEventType.newFinalizedBlock:
        // (ADR-018 卡⑤)：新 finalized 块=链上状态已更新,立即失效
        // ChainReadCache,让换块后的余额/storage 读取拿到最新 finalized 状态。
        ChainReadCache.instance.invalidate();
        await _syncThrough(
          owner,
          blockNumber,
          missingCursorStartsAt: blockNumber - 1,
        );
        break;
    }
  }

  /// 只要还有未终态的本机提交记录，就按固定间隔重试确认，直到全部翻成终态。
  ///
  /// **为什么必须独立于出块**：确认此前只在「新 finalized 块事件」里跑，而本链
  /// **空块不出块** —— 一笔交易只有它自己那个块这一次确认机会。这一次里任何一步
  /// 慢了或失败了（轻节点还没把该块应用完，`fetchFinalizedBlock` 拿到的还是 N-1、
  /// 账户 nonce 快照还是旧值、或者事件被 `_syncInflight` 合并丢掉），日志打一行
  /// 「下轮再确认」就完了 —— **可根本没有下一轮**，记录永久停在待确认，只能手动刷新。
  ///
  /// 连发多笔时后一笔的块给前一笔当了重试机会，所以联测看起来是好的；单发一笔必卡。
  /// 本轮询把「重试」和「出块」解绑：这是最简单的做法，也是唯一不依赖链活跃度的做法。
  void _startConfirmPolling(_ChainTxMonitorOwner owner) {
    if (!_isCurrent(owner) || _confirmTimer != null) return;
    late final Timer timer;
    timer = Timer.periodic(_confirmPollInterval, (_) {
      if (!_isCurrent(owner)) {
        timer.cancel();
        if (identical(_confirmTimer, timer)) _confirmTimer = null;
        return;
      }
      _requestConfirm(owner);
    });
    _confirmTimer = timer;
  }

  void _requestConfirm(_ChainTxMonitorOwner owner) {
    if (!_isCurrent(owner) || owner.confirmTask != null) return;
    late final Future<void> task;
    task = _track(owner, _pollConfirm(owner));
    owner.confirmTask = task;
    task.then<void>(
      (_) {
        if (identical(owner.confirmTask, task)) owner.confirmTask = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(owner.confirmTask, task)) owner.confirmTask = null;
      },
    );
  }

  Future<void> _pollConfirm(_ChainTxMonitorOwner owner) async {
    if (!_isCurrent(owner)) return;
    if (_ss58AddressByAccountId.isEmpty) return;

    // 无待确认记录时零链上开销：先本地查一次再决定要不要读链，避免空闲期每 3 秒
    // 白发一次 finalized 读（`_confirmOpenSubmits` 第一行就会读链）。
    var hasOpen = false;
    for (final accountId in _ss58AddressByAccountId.keys.toList()) {
      if ((await LocalTxStore.queryOpenLocalSubmit(accountId)).isNotEmpty) {
        if (!_isCurrent(owner)) return;
        hasOpen = true;
        break;
      }
      if (!_isCurrent(owner)) return;
    }
    if (!hasOpen) return;

    try {
      await _confirmOpenSubmits(owner);
    } catch (e) {
      if (_isCurrent(owner)) {
        AppLog.d('[TxMonitor] 轮询确认失败，下次再试: $e');
      }
    }
  }

  void _scheduleSyncRetry(_ChainTxMonitorOwner owner) {
    if (!_isCurrent(owner) || _syncRetryTimer != null) return;
    late final Timer timer;
    timer = Timer(const Duration(seconds: 2), () {
      if (identical(_syncRetryTimer, timer)) _syncRetryTimer = null;
      if (!_isCurrent(owner)) return;
      _requestLatestSync(owner);
    });
    _syncRetryTimer = timer;
  }

  void _requestLatestSync(_ChainTxMonitorOwner owner) {
    if (!_isCurrent(owner) || owner.latestSyncTask != null) return;
    late final Future<void> task;
    task = _track(owner, _syncToLatest(owner));
    owner.latestSyncTask = task;
    task.then<void>(
      (_) {
        if (identical(owner.latestSyncTask, task)) owner.latestSyncTask = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(owner.latestSyncTask, task)) owner.latestSyncTask = null;
      },
    );
  }

  Future<void> _syncToLatest(_ChainTxMonitorOwner owner) async {
    if (!_isCurrent(owner) || _ss58AddressByAccountId.isEmpty) return;
    try {
      final finalized =
          await _awaitExternal(owner, _chainRpc.fetchFinalizedBlock());
      if (!_isCurrent(owner)) return;
      await _syncThrough(
        owner,
        finalized.blockNumber,
        missingCursorStartsAt: finalized.blockNumber,
      );
    } catch (e) {
      if (_isCurrent(owner)) {
        AppLog.d('[TxMonitor] 启动补同步失败: $e');
        _scheduleSyncRetry(owner);
      }
    }
  }

  Future<void> _syncThrough(
    _ChainTxMonitorOwner owner,
    int targetBlock, {
    required int missingCursorStartsAt,
  }) {
    if (!_isCurrent(owner)) return Future<void>.value();
    final existing = owner.syncTask;
    if (existing != null) return existing;

    late final Future<void> task;
    task = _track(
        owner,
        _runSyncThrough(
          owner,
          targetBlock,
          missingCursorStartsAt: missingCursorStartsAt,
        ));
    owner.syncTask = task;
    task.then<void>(
      (_) {
        if (identical(owner.syncTask, task)) owner.syncTask = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(owner.syncTask, task)) owner.syncTask = null;
      },
    );
    return task;
  }

  Future<void> _runSyncThrough(
    _ChainTxMonitorOwner owner,
    int targetBlock, {
    required int missingCursorStartsAt,
  }) async {
    if (!_isCurrent(owner) || _ss58AddressByAccountId.isEmpty) return;

    // 确认先行,与前向扫描互不牵制:前向循环的让路/失败分支会提前 return,
    // 确认若挂在末尾会被跳过(轻节点验证态回炉时前向常年失败 → 确认永不执行,
    // 交易明明已最终却一直停在"待确认")。确认失败也只记日志,绝不挡前向。
    try {
      await _confirmOpenSubmits(owner);
    } catch (e) {
      if (_isCurrent(owner)) {
        AppLog.d('[TxMonitor] 确认待确认记录失败,下轮再试: $e');
      }
    }
    if (!_isCurrent(owner)) return;

    final cursors = await LocalTxStore.ensureCursorsForWallets(
      ss58AddressByAccountId: Map<String, String>.of(
        _ss58AddressByAccountId,
      ),
      startBlock: missingCursorStartsAt,
    );
    if (!_isCurrent(owner)) return;
    final lastByPublicKey = {
      for (final cursor in cursors) cursor.accountId: cursor.lastSyncedBlock,
    };
    final startBlock = lastByPublicKey.values
            .fold<int>(targetBlock, (min, value) => value < min ? value : min) +
        1;
    if (startBlock <= targetBlock) {
      final endBlock = startBlock + _maxBlocksPerRun - 1 < targetBlock
          ? startBlock + _maxBlocksPerRun - 1
          : targetBlock;
      for (var block = startBlock; block <= endBlock; block++) {
        if (!_isCurrent(owner) || _ss58AddressByAccountId.isEmpty) return;
        if (WalletIsar.instance.hasActiveOperation) {
          // 交易流水同步是低优先级后台任务；前台钱包/治理读写繁忙时让路，
          // 游标不推进，下一次新区块或启动补同步会继续补缺口。
          _scheduleSyncRetry(owner);
          return;
        }

        final ok = await _processBlock(owner, block);
        if (!_isCurrent(owner)) return;
        if (!ok) {
          _scheduleSyncRetry(owner);
          return;
        }

        for (final normalizedAccountId
            in _ss58AddressByAccountId.keys.toList()) {
          if (!_isCurrent(owner)) return;
          final last =
              lastByPublicKey[normalizedAccountId] ?? missingCursorStartsAt;
          if (last < block) {
            await LocalTxStore.markCursorSynced(
              accountId: normalizedAccountId,
              blockNumber: block,
            );
            if (!_isCurrent(owner)) return;
            lastByPublicKey[normalizedAccountId] = block;
          }
        }
        await _awaitExternal(
          owner,
          Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        if (!_isCurrent(owner)) return;
      }
    }
  }

  /// 处理一个 finalized 区块的 System.Events。
  ///
  /// 调用方保证 [blockNumber] ≤ finalized 高度，按块哈希钉块读取，
  /// 写入的流水状态恒为 finalized(已确认)。
  Future<bool> _processBlock(
    _ChainTxMonitorOwner owner,
    int blockNumber,
  ) async {
    try {
      final blockHashHex = await _awaitExternal(
        owner,
        SmoldotClientManager.instance.getBlockHash(blockNumber),
      );
      if (!_isCurrent(owner)) return false;
      if (blockHashHex == null || blockHashHex.isEmpty) return false;

      final keyHex = '0x${_hexEncode(_eventsStorageKey)}';
      final result = await _awaitExternal(
        owner,
        SmoldotClientManager.instance.request(
          'state_getStorage',
          [keyHex, blockHashHex],
        ),
      );
      if (!_isCurrent(owner)) return false;
      final eventsHex = result as String?;
      if (eventsHex == null) return true;

      final eventsBytes = _hexDecode(
        eventsHex.startsWith('0x') ? eventsHex.substring(2) : eventsHex,
      );
      if (eventsBytes.isEmpty) return true;

      // 先按 txHash 精确认本机提交的待确认交易（就地翻已确认/失败），并记下
      // 已认领的 accountId#extrinsicIndex；下面转出侧据此跳过、绝不另建第二条。
      final claimedThisBlock = await _confirmSubmittedByTxHash(
        owner,
        blockNumber,
        blockHashHex,
        eventsBytes,
      );
      if (!_isCurrent(owner)) return false;

      await _decodeTransferEvents(
        owner,
        eventsBytes,
        blockNumber,
        blockHashHex,
        claimedThisBlock,
      );
      return _isCurrent(owner);
    } catch (e) {
      if (_isCurrent(owner)) {
        AppLog.d('[TxMonitor] 同步区块 $blockNumber 失败: $e');
      }
      return false;
    }
  }

  /// 按 txHash 精确认本机提交的待确认交易。
  ///
  /// 遍历各监控钱包"未终态"的本机提交记录（[LocalTxStore.queryOpenLocalSubmit]），
  /// 若其 txHash 出现在本最终块 → 就地翻 finalized；若该 extrinsic 链上 ExtrinsicFailed
  /// → 翻 failed。全程只动那一条 txHash 记录，绝不另建。返回已认领的
  /// "accountId#extrinsicIndex" 集合，供转出侧跳过、避免重复建记录。
  ///
  /// 没有待确认记录时直接返回、不取块 extrinsics（省节点负担）。
  Future<Set<String>> _confirmSubmittedByTxHash(
    _ChainTxMonitorOwner owner,
    int blockNumber,
    String blockHashHex,
    Uint8List eventsBytes,
  ) async {
    final claimed = <String>{};
    final openRecords = <LocalTxEntity>[];
    for (final accountId in _ss58AddressByAccountId.keys.toList()) {
      if (!_isCurrent(owner)) return claimed;
      openRecords.addAll(await LocalTxStore.queryOpenLocalSubmit(accountId));
      if (!_isCurrent(owner)) return claimed;
    }
    if (openRecords.isEmpty) return claimed;

    final List<String> extrinsics;
    try {
      extrinsics = await _awaitExternal(
        owner,
        SmoldotClientManager.instance
            .getFinalizedBlockExtrinsicsOnce(blockHashHex)
            .timeout(const Duration(seconds: 8)),
      );
    } catch (e) {
      if (!_isCurrent(owner)) return claimed;
      // 取不到块体(丢 peer / 超时):跳过本块认领、游标照常推进,监视器绝不因此
      // 卡死或重试风暴;确认下限由 [_confirmOpenSubmits](锚比对 + nonce 兜底)
      // 保证,漏掉的记录会在那里翻状态。8s 超时防原生调用无限挂起。
      AppLog.d('[TxMonitor] 取块 $blockNumber extrinsics 失败，跳过 txHash 认领: $e');
      return claimed;
    }
    if (!_isCurrent(owner)) return claimed;

    for (final record in openRecords) {
      if (!_isCurrent(owner)) return claimed;
      final txHash = record.txHash;
      if (txHash == null || txHash.isEmpty) continue;
      final idx = await _awaitExternal(
        owner,
        ChainRpc.findExtrinsicIndexInHexList(
          extrinsics,
          txHashHex: txHash,
        ),
      );
      if (!_isCurrent(owner)) return claimed;
      if (idx == null) continue; // 这笔不在本块，继续等后面的最终块
      final failure = _chainRpc.findExtrinsicFailureInEvents(
        eventsBytes,
        extrinsicIndex: idx,
      );
      if (failure != null) {
        await LocalTxStore.markLocalSubmitFailed(
          accountId: record.accountId,
          txHash: txHash,
          failureReason: failure.description,
        );
      } else {
        await LocalTxStore.markLocalSubmitFinalized(
          accountId: record.accountId,
          txHash: txHash,
          blockHash: blockHashHex,
          blockNumber: blockNumber,
          extrinsicIndex: idx,
        );
      }
      if (!_isCurrent(owner)) return claimed;
      claimed.add('${record.accountId}#$idx');
    }
    return claimed;
  }

  /// 确认所有"未终态"本机提交记录的唯一兜底 —— 与前向游标完全解耦,零扫块。
  ///
  /// 每轮同步末尾执行;无待确认记录时一次本地查询即返回。对每条记录按两级判据:
  ///
  /// - **判据一(锚比对)**:blockHash 是交易池 inBlock 事件写入的"本笔所在块"锚
  ///   (`dropped` 不再清它)。读该块头取块号 N;若 N ≤ finalized 高度且最终链在
  ///   N 高度的块哈希与锚相等 ⇒ 锚块已最终、本笔已上链 → 对这一个块跑一次
  ///   [_processBlock](按 txHash 认领 + ExtrinsicFailed 精查 + 事件补写;单块
  ///   一次性,与前向扫描处理一个新块同量级)。锚不等/块头取不到 → 降级判据二。
  ///
  /// - **判据二(nonce 兜底)**:账户 nonce 单调递增、只有交易上链才被消费。
  ///   finalized 状态下账户 nonce > 记录 usedNonce ⇒ 该 nonce 已被最终链消费 ⇒
  ///   本笔已上链 → 翻 finalized(不带块号,保留原字段)。私钥仅在本机、app 串行
  ///   提交,同 nonce 顶替(usurped)已在交易池 watch 单独判失败,判据严格成立。
  ///   局限:不区分"上链但执行失败"(该情形 nonce 同样被消费;概率极低 ——
  ///   提交前有余额/ED 校验,带锚记录会走判据一精查)。
  ///
  /// 资源账:每条记录至多 2 次读头 + 每账户至多 1 次 System.Account 快照读;
  /// **永不窗口扫块、永不批量下载块体**,绝不挤占链状态轮询(ChainProgressBanner)。
  Future<void> _confirmOpenSubmits(_ChainTxMonitorOwner owner) async {
    if (!_isCurrent(owner) || _ss58AddressByAccountId.isEmpty) return;
    final head = (await _awaitExternal(owner, _chainRpc.fetchFinalizedBlock()))
        .blockNumber;
    if (!_isCurrent(owner)) return;
    for (final accountId in _ss58AddressByAccountId.keys.toList()) {
      if (!_isCurrent(owner)) return;
      var records = await LocalTxStore.queryOpenLocalSubmit(accountId);
      if (!_isCurrent(owner)) return;
      if (records.isEmpty) continue;

      // 判据一:锚比对(同锚块只处理一次)。
      final processedAnchors = <String>{};
      for (final record in records) {
        if (!_isCurrent(owner)) return;
        final anchor = record.blockHash;
        if (anchor == null || anchor.isEmpty) continue;
        if (!processedAnchors.add(anchor)) continue;
        final blockNumber = await _blockNumberByHash(owner, anchor);
        if (!_isCurrent(owner)) return;
        if (blockNumber == null || blockNumber > head) continue;
        final finalizedHash = await _awaitExternal(
          owner,
          SmoldotClientManager.instance.getBlockHash(blockNumber),
        );
        if (!_isCurrent(owner)) return;
        if (finalizedHash == null ||
            LocalTxStore.normalizeBlockHash(finalizedHash) !=
                LocalTxStore.normalizeBlockHash(anchor)) {
          // 锚块被最终链顶掉(交易可能被重排进别的块):交给判据二兜底。
          continue;
        }
        await _processBlock(owner, blockNumber);
        if (!_isCurrent(owner)) return;
      }

      // 判据二:nonce 兜底(锚路径后仍未终态的记录)。
      records = await LocalTxStore.queryOpenLocalSubmit(accountId);
      if (!_isCurrent(owner)) return;
      if (records.isEmpty) continue;
      final int? finalizedNonce;
      try {
        finalizedNonce = (await _awaitExternal(
          owner,
          SmoldotClientManager.instance
              .getFinalizedSystemAccountSnapshot(accountId),
        ))
            ?.nonce;
      } catch (e) {
        if (!_isCurrent(owner)) return;
        AppLog.d('[TxMonitor] 读取账户 nonce 失败,下轮再确认: $e');
        continue;
      }
      if (!_isCurrent(owner)) return;
      if (finalizedNonce == null) continue;
      for (final record in records) {
        if (!_isCurrent(owner)) return;
        final txHash = record.txHash;
        final usedNonce = record.usedNonce;
        if (txHash == null || txHash.isEmpty || usedNonce == null) continue;
        if (finalizedNonce > usedNonce) {
          await LocalTxStore.markLocalSubmitFinalized(
            accountId: record.accountId,
            txHash: txHash,
          );
          if (!_isCurrent(owner)) return;
          AppLog.d('[TxMonitor] nonce 兜底确认: tx=$txHash '
              'usedNonce=$usedNonce < 账户nonce=$finalizedNonce');
        }
      }
    }
  }

  /// 按块哈希取块号（`chain_getHeader.number`）。失败返回 null。
  Future<int?> _blockNumberByHash(
    _ChainTxMonitorOwner owner,
    String blockHashHex,
  ) async {
    try {
      final header = await _awaitExternal(
        owner,
        SmoldotClientManager.instance.request(
          'chain_getHeader',
          [blockHashHex],
        ),
      );
      if (!_isCurrent(owner)) return null;
      if (header is Map) {
        final number = header['number'];
        if (number is String && number.isNotEmpty) {
          final hex = number.startsWith('0x') ? number.substring(2) : number;
          return int.parse(hex, radix: 16);
        }
      }
    } catch (e) {
      if (_isCurrent(owner)) {
        AppLog.d('[TxMonitor] chain_getHeader($blockHashHex) 取块号失败: $e');
      }
    }
    return null;
  }

  /// 解码 System.Events，优先提取 OnchainTransaction 转账事件。
  ///
  /// Balances::Transfer 只作为底层余额事件兜底；外部普通转账入口仍然唯一收口到
  /// OnchainTransaction::transfer_with_remark。
  Future<void> _decodeTransferEvents(
    _ChainTxMonitorOwner owner,
    Uint8List data,
    int blockNumber,
    String blockHash,
    Set<String> claimedThisBlock,
  ) async {
    try {
      final keyHex = '0x${_hexEncode(_eventsStorageKey)}';
      final metadata = await _awaitExternal(owner, _chainRpc.fetchMetadata());
      if (!_isCurrent(owner)) return;
      final events = Events.fromJson({
        'changes': [
          [keyHex, '0x${_hexEncode(data)}']
        ],
      }, metadata.chainInfo);

      for (var index = 0; index < events.eventRecord.length; index++) {
        if (!_isCurrent(owner)) return;
        final record = events.eventRecord[index];
        final transferWithRemark = _readTransferWithRemark(record.event);
        if (transferWithRemark != null) {
          final extrinsicIndex = _readExtrinsicIndex(record.phase);
          await _writeTransferForBothSides(
            owner: owner,
            claimedThisBlock: claimedThisBlock,
            fromAccountId: transferWithRemark.fromAccountId,
            toAccountId: transferWithRemark.toAccountId,
            transferAmountFen: transferWithRemark.amountFen,
            blockNumber: blockNumber,
            blockHash: blockHash,
            eventRecordIndex: index,
            extrinsicIndex: extrinsicIndex,
            remark: transferWithRemark.remark,
          );
          continue;
        }
        final transfer = _readBalancesTransfer(record.event);
        if (transfer == null) continue;
        final extrinsicIndex = _readExtrinsicIndex(record.phase);
        await _writeTransferForBothSides(
          owner: owner,
          claimedThisBlock: claimedThisBlock,
          fromAccountId: transfer.fromAccountId,
          toAccountId: transfer.toAccountId,
          transferAmountFen: transfer.amountFen,
          blockNumber: blockNumber,
          blockHash: blockHash,
          eventRecordIndex: index,
          extrinsicIndex: extrinsicIndex,
        );
      }
      return;
    } catch (e) {
      if (!_isCurrent(owner)) return;
      AppLog.d('[TxMonitor] metadata 事件解码失败，使用兜底解析: $e');
    }

    await _decodeTransferEventsFallback(
      owner,
      data,
      blockNumber,
      blockHash,
      claimedThisBlock,
    );
  }

  Future<void> _decodeTransferEventsFallback(
    _ChainTxMonitorOwner owner,
    Uint8List data,
    int blockNumber,
    String blockHash,
    Set<String> claimedThisBlock,
  ) async {
    var offset = 0;
    var eventRecordIndex = 0;
    if (data.isEmpty) return;
    final (_, countSize) = _decodeCompactU32(data, 0);
    offset += countSize;

    while (offset + 4 < data.length) {
      if (!_isCurrent(owner)) return;
      int? extrinsicIndex;
      final phase = data[offset];
      offset += 1;
      if (phase == 0x00) {
        if (offset + 4 > data.length) break;
        extrinsicIndex = _readU32LE(data, offset);
        offset += 4;
      }

      if (offset + 2 > data.length) break;
      final palletIndex = data[offset];
      final eventIndex = data[offset + 1];
      offset += 2;

      if (palletIndex == _balancesPallet && eventIndex == _transferEvent) {
        // Balances::Transfer { from: AccountId, to: AccountId, amount: u128 }
        if (offset + 80 <= data.length) {
          final from = data.sublist(offset, offset + 32);
          final to = data.sublist(offset + 32, offset + 64);
          final amountBytes = data.sublist(offset + 64, offset + 80);
          offset += 80;

          final fromAccountId = '0x${_hexEncode(from)}';
          final toAccountId = '0x${_hexEncode(to)}';
          final transferAmountFen = _readU128LE(amountBytes, 0).toString();

          await _writeTransferForBothSides(
            owner: owner,
            claimedThisBlock: claimedThisBlock,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            transferAmountFen: transferAmountFen,
            blockNumber: blockNumber,
            blockHash: blockHash,
            eventRecordIndex: eventRecordIndex,
            extrinsicIndex: extrinsicIndex,
          );

          offset = _skipTopics(data, offset);
          eventRecordIndex++;
          continue;
        }
      }
      if (palletIndex == _onchainTransactionPallet &&
          eventIndex == _transferWithRemarkEvent) {
        // OnchainTransaction::TransferWithRemark { from, beneficiary, amount, remark }
        if (offset + 81 <= data.length) {
          final from = data.sublist(offset, offset + 32);
          final to = data.sublist(offset + 32, offset + 64);
          final amountBytes = data.sublist(offset + 64, offset + 80);
          offset += 80;
          final (remarkLen, remarkLenSize) = _decodeCompactU32(data, offset);
          if (remarkLenSize == 0 ||
              offset + remarkLenSize + remarkLen > data.length) {
            break;
          }
          offset += remarkLenSize;
          final remark = remarkLen == 0
              ? null
              : utf8.decode(
                  data.sublist(offset, offset + remarkLen),
                  allowMalformed: true,
                );
          offset += remarkLen;

          await _writeTransferForBothSides(
            owner: owner,
            claimedThisBlock: claimedThisBlock,
            fromAccountId: '0x${_hexEncode(from)}',
            toAccountId: '0x${_hexEncode(to)}',
            transferAmountFen: _readU128LE(amountBytes, 0).toString(),
            blockNumber: blockNumber,
            blockHash: blockHash,
            eventRecordIndex: eventRecordIndex,
            extrinsicIndex: extrinsicIndex,
            remark: remark,
          );

          offset = _skipTopics(data, offset);
          eventRecordIndex++;
          continue;
        }
      }

      final skipped = _skipKnownEventPayload(data, offset, palletIndex,
          eventIndex: eventIndex);
      if (skipped != null) {
        offset = _skipTopics(data, skipped);
        eventRecordIndex++;
        continue;
      }

      // 未识别事件：尝试跳到下一个 EventRecord。
      offset = _skipToNextEvent(data, offset);
      eventRecordIndex++;
    }
  }

  Future<void> _writeTransferForBothSides({
    required _ChainTxMonitorOwner owner,
    required Set<String> claimedThisBlock,
    required String fromAccountId,
    required String toAccountId,
    required String transferAmountFen,
    required int blockNumber,
    required String blockHash,
    required int eventRecordIndex,
    required int? extrinsicIndex,
    String? remark,
  }) async {
    if (!_isCurrent(owner)) return;
    if (fromAccountId == toAccountId) return;
    final fromBytes = _hexDecode(fromAccountId);
    final toBytes = _hexDecode(toAccountId);
    await _writeWalletTransferIfMatched(
      owner: owner,
      accountId: toAccountId,
      blockNumber: blockNumber,
      blockHash: blockHash,
      eventRecordIndex: eventRecordIndex,
      extrinsicIndex: extrinsicIndex,
      amountDeltaFen: transferAmountFen,
      transferAmountFen: transferAmountFen,
      fromSs58Address: _publicKeyToSs58(fromBytes),
      toSs58Address:
          _ss58AddressByAccountId[toAccountId] ?? _publicKeyToSs58(toBytes),
      counterpartySs58Address: _publicKeyToSs58(fromBytes),
      remark: remark,
    );

    // 转出侧：若本笔已被 txHash 认领（本机提交、已在 _confirmSubmittedByTxHash
    // 里就地翻状态）→ 跳过，绝不另建 blockHash 键的第二条记录。收入侧不受影响。
    if (!_isCurrent(owner)) return;
    if (!claimedThisBlock.contains('$fromAccountId#$extrinsicIndex')) {
      await _writeWalletTransferIfMatched(
        owner: owner,
        accountId: fromAccountId,
        blockNumber: blockNumber,
        blockHash: blockHash,
        eventRecordIndex: eventRecordIndex,
        extrinsicIndex: extrinsicIndex,
        amountDeltaFen: LocalTxStore.negateFen(transferAmountFen),
        transferAmountFen: transferAmountFen,
        fromSs58Address: _ss58AddressByAccountId[fromAccountId] ??
            _publicKeyToSs58(fromBytes),
        toSs58Address: _publicKeyToSs58(toBytes),
        counterpartySs58Address: _publicKeyToSs58(toBytes),
        remark: remark,
      );
    }
  }

  _DecodedTransferEvent? _readTransferWithRemark(Map<String, dynamic> event) {
    final onchain = event['OnchainTransaction'] ?? event['onchainTransaction'];
    if (onchain is! Map) return null;
    final transfer = onchain['TransferWithRemark'] ??
        onchain['transferWithRemark'] ??
        onchain['transfer_with_remark'];
    if (transfer == null) return null;

    dynamic from;
    dynamic to;
    dynamic amount;
    dynamic remark;
    if (transfer is Map) {
      from = transfer['from'] ?? transfer['0'];
      to = transfer['beneficiary'] ?? transfer['to'] ?? transfer['1'];
      amount = transfer['amount'] ?? transfer['2'];
      remark = transfer['remark'] ?? transfer['3'];
      if ((from == null || to == null || amount == null || remark == null) &&
          transfer.values.length >= 4) {
        final values = transfer.values.toList(growable: false);
        from ??= values[0];
        to ??= values[1];
        amount ??= values[2];
        remark ??= values[3];
      }
    } else if (transfer is List && transfer.length >= 4) {
      from = transfer[0];
      to = transfer[1];
      amount = transfer[2];
      remark = transfer[3];
    }

    final fromAccountId = _decodeAccountId(from);
    final toAccountId = _decodeAccountId(to);
    final amountFen = _eventAmountToFen(amount);
    if (fromAccountId == null || toAccountId == null || amountFen == null) {
      return null;
    }
    return _DecodedTransferEvent(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountFen: amountFen,
      remark: _eventRemarkToString(remark),
    );
  }

  _DecodedTransferEvent? _readBalancesTransfer(Map<String, dynamic> event) {
    final balances = event['Balances'] ?? event['balances'];
    if (balances is! Map) return null;
    final transfer = balances['Transfer'] ?? balances['transfer'];
    if (transfer == null) return null;

    dynamic from;
    dynamic to;
    dynamic amount;
    if (transfer is Map) {
      from = transfer['from'] ?? transfer['0'];
      to = transfer['to'] ?? transfer['1'];
      amount = transfer['amount'] ?? transfer['value'] ?? transfer['2'];
      if ((from == null || to == null || amount == null) &&
          transfer.values.length >= 3) {
        final values = transfer.values.toList(growable: false);
        from ??= values[0];
        to ??= values[1];
        amount ??= values[2];
      }
    } else if (transfer is List && transfer.length >= 3) {
      from = transfer[0];
      to = transfer[1];
      amount = transfer[2];
    }

    final fromAccountId = _decodeAccountId(from);
    final toAccountId = _decodeAccountId(to);
    final amountFen = _eventAmountToFen(amount);
    if (fromAccountId == null || toAccountId == null || amountFen == null) {
      return null;
    }
    return _DecodedTransferEvent(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountFen: amountFen,
    );
  }

  int? _readExtrinsicIndex(Map<String, dynamic> phase) {
    final value = phase['ApplyExtrinsic'] ?? phase['applyExtrinsic'];
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _decodeAccountId(dynamic raw) {
    if (raw is Uint8List && raw.length == 32) {
      return '0x${_hexEncode(raw)}';
    }
    if (raw is List) {
      final bytes = raw.whereType<int>().toList(growable: false);
      if (bytes.length == 32) {
        return '0x${_hexEncode(Uint8List.fromList(bytes))}';
      }
    }
    if (raw is String) {
      final text = raw.trim();
      final hex = text.startsWith('0x') ? text.substring(2) : text;
      final isHex = RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex);
      if (isHex) return '0x${hex.toLowerCase()}';
      try {
        return '0x${_hexEncode(
          Uint8List.fromList(Keyring().decodeAddress(text)),
        )}';
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _eventAmountToFen(dynamic raw) {
    if (raw is BigInt) return raw.toString();
    if (raw is int) return raw.toString();
    if (raw is String) return BigInt.tryParse(raw)?.toString();
    return null;
  }

  String? _eventRemarkToString(dynamic raw) {
    if (raw == null) return null;
    if (raw is Uint8List) {
      return raw.isEmpty ? null : utf8.decode(raw, allowMalformed: true);
    }
    if (raw is List) {
      final bytes = raw.whereType<int>().toList(growable: false);
      return bytes.isEmpty ? null : utf8.decode(bytes, allowMalformed: true);
    }
    if (raw is Map) {
      final bytes = raw.values.whereType<int>().toList(growable: false);
      if (bytes.isNotEmpty) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      if (RegExp(r'^0x[0-9a-fA-F]*$').hasMatch(text)) {
        final bytes = _hexDecode(text.substring(2));
        return bytes.isEmpty ? null : utf8.decode(bytes, allowMalformed: true);
      }
      return raw;
    }
    return raw.toString();
  }

  int? _skipKnownEventPayload(
    Uint8List data,
    int offset,
    int palletIndex, {
    required int eventIndex,
  }) {
    // metadata 解码正常时不会走到这里；兜底分支只显式跳过
    // 普通转账前后最常见的定长事件，避免旧版“向前扫描”误命中 payload 字节。
    final oneAccountAndAmount = offset + 48 <= data.length ? offset + 48 : null;
    if (palletIndex == _balancesPallet) {
      if (eventIndex == 7 ||
          eventIndex == 8 ||
          eventIndex == 10 ||
          eventIndex == 11) {
        return oneAccountAndAmount;
      }
    }
    // OnchainTransaction::FeePaid { who: AccountId, fee: u128 }
    if (palletIndex == 4 && eventIndex == 0) {
      return oneAccountAndAmount;
    }
    // OnchainTransaction::FeeShareBurnt { reason: BurnReason, amount: u128 }
    if (palletIndex == 4 && eventIndex == 1) {
      return offset + 17 <= data.length ? offset + 17 : null;
    }
    return null;
  }

  Future<void> _writeWalletTransferIfMatched({
    required _ChainTxMonitorOwner owner,
    required String accountId,
    required int blockNumber,
    required String blockHash,
    required int eventRecordIndex,
    required int? extrinsicIndex,
    required String amountDeltaFen,
    required String transferAmountFen,
    required String fromSs58Address,
    required String toSs58Address,
    required String counterpartySs58Address,
    String? remark,
  }) async {
    if (!_isCurrent(owner)) return;
    final normalizedAccountId = LocalTxStore.requireAccountId(accountId);
    final ss58Address = _ss58AddressByAccountId[normalizedAccountId];
    if (ss58Address == null) return;

    if (!_isCurrent(owner)) return;
    await LocalTxStore.upsertBlockTransferEvent(
      ss58Address: ss58Address,
      accountId: normalizedAccountId,
      recordKey: LocalTxStore.blockEventRecordKey(
        normalizedAccountId,
        blockHash,
        eventRecordIndex,
      ),
      // (ADR-017)：监控只扫 finalized 链，写入状态恒为"已确认"。
      status: LocalTxStore.statusFinalized,
      amountDeltaFen: amountDeltaFen,
      transferAmountFen: transferAmountFen,
      fromSs58Address: fromSs58Address,
      toSs58Address: toSs58Address,
      counterpartySs58Address: counterpartySs58Address,
      blockNumber: blockNumber,
      blockHash: blockHash,
      eventIndex: eventRecordIndex,
      extrinsicIndex: extrinsicIndex,
      remark: remark,
    );
    if (!_isCurrent(owner)) return;

    try {
      final balance = await _awaitExternal(
        owner,
        _chainRpc.fetchFinalizedBalance(normalizedAccountId),
      );
      if (!_isCurrent(owner)) return;
      onBalanceChanged?.call(ss58Address, balance);
    } catch (_) {
      if (!_isCurrent(owner)) return;
      // 交易记录已经落库，余额刷新失败不能把钱包余额误写成 0。
      onBalanceChanged?.call(ss58Address, double.nan);
    }
  }

  // ──── 工具方法 ────

  static bool _sameWatchedAccounts(
    Map<String, String> left,
    Map<String, String> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  String _publicKeyToSs58(Uint8List normalizedAccountId) {
    try {
      return Keyring()
          .encodeAddress(normalizedAccountId.toList(), kGmbSs58Prefix);
    } catch (_) {
      return '0x${_hexEncode(normalizedAccountId)}';
    }
  }

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexDecode(String hex) {
    final normalized = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(
        normalized.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
    }
    return result;
  }

  static int _readU32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static BigInt _readU128LE(Uint8List bytes, int offset) {
    var value = BigInt.zero;
    for (var i = 15; i >= 0; i--) {
      value = (value << 8) | BigInt.from(bytes[offset + i]);
    }
    return value;
  }

  static (int, int) _decodeCompactU32(Uint8List bytes, int offset) {
    if (offset >= bytes.length) return (0, 0);
    final mode = bytes[offset] & 0x03;
    switch (mode) {
      case 0:
        return (bytes[offset] >> 2, 1);
      case 1:
        if (offset + 2 > bytes.length) return (0, 0);
        return (((bytes[offset + 1] << 8) | bytes[offset]) >> 2, 2);
      case 2:
        if (offset + 4 > bytes.length) return (0, 0);
        return (
          ((bytes[offset + 3] << 24) |
                  (bytes[offset + 2] << 16) |
                  (bytes[offset + 1] << 8) |
                  bytes[offset]) >>
              2,
          4
        );
      default:
        return (0, 1);
    }
  }

  /// 跳过 topics（Vec<Hash>）。
  static int _skipTopics(Uint8List data, int offset) {
    if (offset >= data.length) return offset;
    final (count, size) = _decodeCompactU32(data, offset);
    offset += size;
    offset += count * 32;
    return offset;
  }

  /// 未识别事件时，向前扫描寻找下一个合法 EventRecord 的 phase 起点。
  static int _skipToNextEvent(Uint8List data, int offset) {
    for (var i = offset; i < data.length - 3; i++) {
      final byte = data[i];
      if (byte == 0x01 || byte == 0x02) {
        final nextPallet = data[i + 1];
        if (nextPallet < 64) return i;
      } else if (byte == 0x00 && i + 5 < data.length) {
        final possiblePallet = data[i + 5];
        if (possiblePallet < 64) return i;
      }
    }
    return data.length;
  }
}
