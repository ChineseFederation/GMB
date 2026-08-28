import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart' as crypto_hash;

import '../8964/services/square_api_client.dart';
import '../my/myid/current_user_context.dart';
import '../rpc/chain_bootstrap_api.dart';
import '../wallet/core/default_account_service.dart';
import '../wallet/core/device_subkey.dart';
import '../security/local_data_key.dart';
import 'media/attachment_vault.dart';
import '../wallet/core/wallet_manager.dart';
import 'crypto/mls_boundary.dart';
import 'crypto/mls_group_boundary.dart';
import 'crypto/mls_native.dart';
import 'crypto/mls_state_store.dart';
import 'chat_flow.dart';
import 'chat_media_limits.dart';
import 'chat_models.dart';
import 'chat_payload.dart';
import 'chat_push_service.dart';
import 'group/group_flow.dart';
import 'group/group_model.dart';
import 'proto/chat_envelope.pb.dart';
import 'storage/chat_store.dart';
import 'transport/chat_cloud_transport.dart';
import 'transport/chat_transport.dart';
import 'transport/chat_webrtc_transport.dart';

typedef ChatLoginSigner = Future<String> Function({
  required String cidNumber,
  required String accountId,
  required Uint8List loginMessage,
});

typedef ChatCloudTransportFactory = ChatCloudTransport Function({
  required String accountId,
  required String localCidNumber,
  required String localDeviceId,
  Uri? serviceBaseUrl,
  String? sessionToken,
});

typedef ChatPushTokenProvider = Future<ChatPushToken> Function();

typedef MlsStateStoreFactory = Future<MlsStateStore> Function(
    String ownerCidNumber, String deviceId);

/// Documents 根下持久擦除门闩的启动态。
enum ChatPersistentWipeState {
  none,
  pending,
  complete,
}

/// 系统推送唤醒后的短时后台收发窗口。
///
/// Cloudflare 不代存消息，因此接收设备被唤醒后必须主动建立瞬时连接。若发送设备
/// 此刻离线，`peer_ready` 会反向唤醒发送设备，由其本机队列继续投递。
@pragma('vm:entry-point')
Future<void> chatRuntimeBackgroundHandler(RemoteMessage message) async {
  final sender = ChatPushService.wakeSenderFromData(message.data);
  if (sender == null) return;
  try {
    await ChatRuntime._runProcessOperation(() async {
      final push = ChatPushService();
      ChatRuntime? runtime;
      try {
        await ChatPushService.storeWakeSender(sender);
        await ensureChatFirebaseReady();
        runtime = ChatRuntime(
          pushService: push,
          pushTokenProvider: () => push.readToken(requestPermission: false),
        );
        final accountId = await runtime.readAccountId();
        if (accountId == null) return;
        final stop = await runtime.startRealtimeSync(onNotice: () async {});
        if (stop == null) return;
        await Future<void>.delayed(const Duration(seconds: 20));
        await stop();
      } catch (_) {
        // 网络/系统后台时限失败不得跳过 finally 的运行态收口。
      } finally {
        // stop 只取消新 socket 事件；已触发的 message/token/file
        // callback 可能仍在途。跨 isolate lease 只能在实例全部 drain
        // 成功后释放，否则留下孤儿 lease 使 AppLock fail-closed。
        final cleanupFailures = <String>[];
        final currentRuntime = runtime;
        if (currentRuntime != null) {
          await ChatRuntime._captureCleanupFailure(
            '收口 Chat 后台运行态',
            currentRuntime._closeForWipe,
            cleanupFailures,
          );
        }
        await ChatRuntime._captureCleanupFailure(
          '关闭 Chat 后台推送订阅',
          push.dispose,
          cleanupFailures,
        );
        if (cleanupFailures.isNotEmpty) {
          throw StateError(cleanupFailures.join('\n'));
        }
      }
    });
  } catch (_) {
    // 后台执行时间由系统控制；擦除终态或网络失败后不得重新保存 Chat 状态。
  }
}

/// 成功后复用同一完成 Future，失败后只清除本次 task，允许下一次 AppLock 真正重试。
class _RetryableAsyncDisposer {
  _RetryableAsyncDisposer(this._operation);

  final Future<void> Function() _operation;
  Future<void>? _running;

  Future<void> dispose() {
    final running = _running;
    if (running != null) return running;

    late final Future<void> source;
    try {
      source = _operation();
    } catch (error, stackTrace) {
      return Future<void>.error(error, stackTrace);
    }
    late final Future<void> task;
    task = source.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_running, task)) _running = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _running = task;
    return task;
  }
}

/// 一次实时同步持有的全部可关闭资源。
///
/// 初始化尚未完成时收到 AppLock 擦除也必须等待初始化收口；后续才出现的 socket 或
/// subscription 会被同一 disposer 接管。每个子资源独立记忆成功、独立重试失败，
/// 避免某一 cancel 失败后重复打开或遗漏其它资源。
class _ChatRealtimeSession {
  _ChatRealtimeSession({this.accountId, this.ownerCidNumber});

  final String? accountId;
  final String? ownerCidNumber;
  final Completer<void> _initializationDone = Completer<void>();
  _RetryableAsyncDisposer? _socketDisposer;
  _RetryableAsyncDisposer? _wakeSubscriptionDisposer;
  _RetryableAsyncDisposer? _tokenSubscriptionDisposer;
  final Set<Future<void>> _callbacks = <Future<void>>{};
  Future<void> _callbackTail = Future<void>.value();
  bool _acceptingCallbacks = true;
  late final _RetryableAsyncDisposer _disposer =
      _RetryableAsyncDisposer(_dispose);

  void attachSocket(Future<void> Function() stopSocket) {
    if (_socketDisposer != null) {
      throw StateError('Chat 实时 socket 已登记');
    }
    _socketDisposer = _RetryableAsyncDisposer(stopSocket);
  }

  void attachWakeSubscription(Future<void> Function() cancel) {
    if (_wakeSubscriptionDisposer != null) {
      throw StateError('Chat 唤醒订阅已登记');
    }
    _wakeSubscriptionDisposer = _RetryableAsyncDisposer(cancel);
  }

  void attachTokenSubscription(Future<void> Function() cancel) {
    if (_tokenSubscriptionDisposer != null) {
      throw StateError('Chat Token 订阅已登记');
    }
    _tokenSubscriptionDisposer = _RetryableAsyncDisposer(cancel);
  }

  void markInitializationDone() {
    if (!_initializationDone.isCompleted) _initializationDone.complete();
  }

  bool belongsToAccount(String value) => accountId == value;

  void ensureOpen() {
    if (!_acceptingCallbacks) {
      throw StateError('Chat 实时会话已停止接收新回调');
    }
  }

  Future<void> runCallback(Future<void> Function() operation) {
    if (!_acceptingCallbacks) return Future<void>.value();
    // WebSocket 可能在上一个 callback 尚未完成时继续推送 Welcome/Application；
    // MLS ratchet 必须严格按到达顺序推进，因此所有实时来源共用一条串行尾链。
    final previous = _callbackTail;
    final running = previous.then<void>(
      (_) => operation(),
      onError: (Object _, StackTrace __) => operation(),
    );
    _callbacks.add(running);
    _callbackTail = running.then<void>((_) {}, onError: (_, __) {});
    return running.whenComplete(() => _callbacks.remove(running));
  }

  Future<void> dispose() {
    // 必须在任何 await 前同步拒绝 transport/stream 新回调。
    _acceptingCallbacks = false;
    return _disposer.dispose();
  }

  Future<void> _dispose() async {
    await _initializationDone.future;
    final failures = <String>[];
    await Future.wait<void>(<Future<void>>[
      if (_wakeSubscriptionDisposer != null)
        _captureFailure(
          '取消 Chat 唤醒订阅',
          _wakeSubscriptionDisposer!.dispose,
          failures,
        ),
      if (_tokenSubscriptionDisposer != null)
        _captureFailure(
          '取消 Chat Token 订阅',
          _tokenSubscriptionDisposer!.dispose,
          failures,
        ),
      if (_socketDisposer != null)
        _captureFailure(
          '关闭 Chat 实时 socket',
          _socketDisposer!.dispose,
          failures,
        ),
    ]);
    while (_callbacks.isNotEmpty) {
      await Future.wait<void>(_callbacks.toList(growable: false));
    }
    if (failures.isNotEmpty) throw StateError(failures.join('\n'));
  }

  static Future<void> _captureFailure(
    String label,
    Future<void> Function() action,
    List<String> failures,
  ) async {
    try {
      await action();
    } catch (error) {
      failures.add('$label：$error');
    }
  }
}

class _ChatRealtimeListener {
  const _ChatRealtimeListener({
    required this.onNotice,
    required this.onDisconnected,
  });

  final Future<void> Function() onNotice;
  final Future<void> Function()? onDisconnected;
}

/// 一个账户在当前 isolate 内唯一的前台实时通道。聊天 Tab、私聊页和群聊页只
/// 增减监听者，不再各自创建 WebSocket；物理断线由本通道退避重连。
class _ChatRealtimeHub {
  _ChatRealtimeHub(this.account);

  final _ChatAccount account;
  final Set<_ChatRealtimeListener> listeners = <_ChatRealtimeListener>{};
  Future<bool>? connecting;
  Future<void> Function()? stopPhysical;
  ChatCloudTransport? transport;
  Timer? reconnectTimer;
  int reconnectAttempt = 0;
  bool retryOutgoingOnConnect = false;
  bool closed = false;
}

class _ChatRealtimePhysical {
  const _ChatRealtimePhysical({required this.stop, required this.transport});

  final Future<void> Function() stop;
  final ChatCloudTransport transport;
}

/// FlutterFire Android 后台消息运行在独立 Dart isolate，静态集合无法跨
/// isolate 阻止擦除后晚写。因此用 Documents 根目录直属 marker + lease
/// 双检协议协调：后台任务全程持有独占创建的 lease，擦除先落盘
/// marker，再等待当前进程的全部 lease 消失。
class _ChatCrossIsolateCoordinator {
  static const String _pendingMarkerName = '.citizenapp_data_wipe.pending';
  static const String _pendingMarkerPayload = 'pending\n';
  static const String _completeMarkerName = '.citizenapp_data_wipe.complete';
  static const String _completeMarkerPayload = 'complete\n';
  static const String _leasePrefix = '.citizenapp_chat_lease_';
  static const String _leaseSuffix = '.lease';
  static const String _cidMutationLeasePrefix = '.citizenapp_chat_cid_';
  static const String _cidMutationLeaseSuffix = '.mutation_lease';
  static const String _cidMutationStaleSuffix = '.stale';
  static const String _startupBarrierName = '.citizenapp_chat_startup.barrier';
  static const Duration _leaseDrainTimeout = Duration(seconds: 5);
  static const Duration _leasePollInterval = Duration(milliseconds: 20);
  static const Duration _leaseStaleAfter = Duration(seconds: 30);
  static const Duration _leaseHeartbeatInterval = Duration(seconds: 3);
  static const Duration _cidMutationAcquireTimeout = Duration(seconds: 8);
  static const Duration _cidMutationStaleAfter = Duration(seconds: 30);
  static const Duration _cidMutationHeartbeatInterval = Duration(seconds: 3);
  static final String _cidMutationProcessGeneration = _newNonce();
  static final String _backgroundProcessGeneration = _newNonce();

  static String get _currentLeasePrefix => '$_leasePrefix${pid}_';

  static Future<_ChatCidMutationLease> acquireCidMutationLease(
    Directory documentsRoot,
    String cidNumber,
  ) async {
    if (cidNumber.isEmpty) throw StateError('Chat CID 文件协调键不能为空');
    await _throwIfCurrentProcessWipeRequested(documentsRoot);
    final digest =
        crypto_hash.sha256.convert(utf8.encode(cidNumber)).toString();
    final leaseFile = _directFile(
      documentsRoot,
      '$_cidMutationLeasePrefix$digest$_cidMutationLeaseSuffix',
    );
    final deadline = DateTime.now().add(_cidMutationAcquireTimeout);
    while (true) {
      final nonce = _newNonce();
      try {
        await leaseFile.create(exclusive: true);
        final owner = _ChatCidLeaseOwner(
          processId: pid,
          processGeneration: _cidMutationProcessGeneration,
          nonce: nonce,
        );
        try {
          await leaseFile.writeAsString(owner.encode(), flush: true);
          await _throwIfCurrentProcessWipeRequested(documentsRoot);
          return _ChatCidMutationLease(
            file: leaseFile,
            owner: owner,
            heartbeatInterval: _cidMutationHeartbeatInterval,
          );
        } catch (_) {
          await _deleteOwnedCidLeaseFile(leaseFile, owner);
          rethrow;
        }
      } on FileSystemException {
        final type = await FileSystemEntity.type(
          leaseFile.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) {
          rethrow;
        }
        if (type != FileSystemEntityType.file) {
          throw StateError('Chat CID 文件协调 lease 类型异常');
        }
        if (await _reapExpiredCidMutationLease(leaseFile)) {
          continue;
        }
        if (!DateTime.now().isBefore(deadline)) {
          throw StateError('同一 CID 的 Chat 文件操作持续占用，请重试');
        }
        await Future<void>.delayed(_leasePollInterval);
      }
    }
  }

  static Future<Directory> resolveDocumentsRoot(
    Future<Directory> Function() provider,
  ) async {
    final root = (await provider()).absolute;
    if (root.path == root.parent.path) {
      throw StateError('Chat 跨 isolate 协调目录不能是文件系统根目录');
    }
    var type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await root.create(recursive: true);
      type = await FileSystemEntity.type(root.path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('Chat 跨 isolate 协调目录不是真实目录');
    }
    return root;
  }

  static Future<_ChatCrossIsolateLease> acquireBackgroundLease(
    Directory documentsRoot,
  ) async {
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (true) {
      await _waitForStartupBarrier(documentsRoot, deadline: deadline);
      await _removeArtifactsFromOtherProcesses(documentsRoot);
      await _throwIfCurrentProcessWipeRequested(documentsRoot);

      final nonce = _newNonce();
      final leaseFile = _directFile(
        documentsRoot,
        '$_currentLeasePrefix$nonce$_leaseSuffix',
      );
      final owner = _ChatCidLeaseOwner(
        processId: pid,
        processGeneration: _backgroundProcessGeneration,
        nonce: nonce,
      );
      try {
        await leaseFile.create(exclusive: true);
        await leaseFile.writeAsString(owner.encode(), flush: true);
        // 二次检查封住“首检后、lease 创建前”的 startup/wipe 竞态窗口。
        if (await _hasStartupBarrier(documentsRoot)) {
          await _deleteOwnedLeaseFile(leaseFile, owner);
          if (!DateTime.now().isBefore(deadline)) {
            throw StateError('Chat 启动预检持续占用，后台任务拒绝进入');
          }
          continue;
        }
        await _throwIfCurrentProcessWipeRequested(documentsRoot);
        return _ChatCrossIsolateLease(
          file: leaseFile,
          owner: owner,
          heartbeatInterval: _leaseHeartbeatInterval,
        );
      } catch (_) {
        await _deleteOwnedLeaseFile(leaseFile, owner, allowMissing: true);
        rethrow;
      }
    }
  }

  static Future<void> ensureWipePending(Directory documentsRoot) async {
    await _removeArtifactsFromOtherProcesses(
      documentsRoot,
      removeStagedComplete: true,
    );
    final marker = _directFile(documentsRoot, _pendingMarkerName);
    final type = await FileSystemEntity.type(marker.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      try {
        await marker.create(exclusive: true);
      } on FileSystemException {
        // 另一个当前进程擦除调用可能已经创建，下面按真实类型验真。
      }
    }
    if (await FileSystemEntity.type(marker.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('本机数据擦除 pending marker 不是真实文件');
    }
    // 文件存在就是 fail-closed pending 状态；固定载荷 + flush 让目录项
    // 与 inode 在平台存储清理前尽快落盘，崩溃后仍可无鉴权恢复。
    final handle = await marker.open(mode: FileMode.write);
    try {
      await handle.writeString(_pendingMarkerPayload);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  static Future<void> drainBackgroundLeases(
    Directory documentsRoot,
  ) async {
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (await _hasCurrentProcessLease(documentsRoot)) {
      if (!DateTime.now().isBefore(deadline)) {
        throw StateError('Chat 后台 isolate 未在有界时间内收口');
      }
      await Future<void>.delayed(_leasePollInterval);
    }
  }

  static Future<void> _drainAllBackgroundLeases(
    Directory documentsRoot,
  ) async {
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (await _hasLiveBackgroundLease(documentsRoot)) {
      if (!DateTime.now().isBefore(deadline)) {
        throw StateError('Chat 后台 isolate 未在启动预检前有界收口');
      }
      await Future<void>.delayed(_leasePollInterval);
    }
  }

  static Future<bool> _hasLiveBackgroundLease(
    Directory documentsRoot,
  ) async {
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (!name.startsWith(_leasePrefix) || !name.endsWith(_leaseSuffix)) {
        continue;
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw StateError('Chat 后台 lease 类型异常');
      }
      if (!await _reapExpiredOwnedLease(
        File(entity.path),
        allowSameProcess: false,
      )) {
        return true;
      }
    }
    return false;
  }

  static Future<void> beginWipe(Directory documentsRoot) async {
    await ensureWipePending(documentsRoot);
    await drainBackgroundLeases(documentsRoot);
  }

  static Future<void> resetForTest(
    Future<Directory> Function() provider,
  ) async {
    final root = await resolveDocumentsRoot(provider);
    await for (final entity in root.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (name == _pendingMarkerName ||
          name == _completeMarkerName ||
          name == _startupBarrierName ||
          name.startsWith('.$_completeMarkerName.') ||
          (name.startsWith(_leasePrefix) && name.endsWith(_leaseSuffix)) ||
          (name.startsWith(_cidMutationLeasePrefix) &&
              (name.endsWith(_cidMutationLeaseSuffix) ||
                  name.endsWith(_cidMutationStaleSuffix)))) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.file ||
            type == FileSystemEntityType.link) {
          try {
            await entity.delete();
          } on FileSystemException {
            // 并发 finally 已经删除即等价于 reset 成功。
          }
        }
      }
    }
  }

  /// 启动预检持有 Documents 直属 barrier：新后台任务在建 lease 前后双检，已有
  /// 后台任务必须先收口；只有确认无生产者后才清上一进程 CID artifact。
  static Future<T> runStartupPreflight<T>(
    Directory documentsRoot,
    Future<T> Function() operation,
  ) async {
    final barrier = await _acquireStartupBarrier(documentsRoot);
    try {
      await _drainAllBackgroundLeases(documentsRoot);
      await _clearCidMutationLeasesWhileStartupBarrierHeld(documentsRoot);
      return await operation();
    } finally {
      await barrier.release();
    }
  }

  static Future<void> _clearCidMutationLeasesWhileStartupBarrierHeld(
    Directory documentsRoot,
  ) async {
    final activePattern = RegExp(
      '^${RegExp.escape(_cidMutationLeasePrefix)}[0-9a-f]{64}'
      '${RegExp.escape(_cidMutationLeaseSuffix)}\$',
    );
    final stalePattern = RegExp(
      '^${RegExp.escape(_cidMutationLeasePrefix)}[0-9a-f]{64}'
      '${RegExp.escape(_cidMutationLeaseSuffix)}\\.[0-9]+\\.[0-9a-f]+'
      '${RegExp.escape(_cidMutationStaleSuffix)}\$',
    );
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (!activePattern.hasMatch(name) && !stalePattern.hasMatch(name)) {
        continue;
      }
      final type = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.link) {
        throw StateError('Chat 启动预检发现异常 CID lease 类型');
      }
      if (type == FileSystemEntityType.file && activePattern.hasMatch(name)) {
        final owner = await _readCidLeaseOwner(File(entity.path));
        if (owner == null) {
          throw StateError('Chat 启动预检发现损坏的 CID lease owner');
        }
        if (owner.processGeneration == _cidMutationProcessGeneration) {
          throw StateError('Chat 启动预检发现当前进程仍持有 CID lease');
        }
        // 两端产品都没有承载 Chat writer 的第二 OS 进程：Android 未声明
        // android:process，iOS 也没有运行本协调器的 App Extension。main 又在注册
        // 后台入口和构造 ChatRuntime 前执行本预检，因此不同 PID，或 PID 被系统复用但
        // generation 不同的合法 lease，只可能属于已经退出的上一应用进程。这里按 owner
        // 二次验真后原子退役，不能复用运行态“30 秒判旧”规则把覆盖安装锁死在启动页。
        await _retireStartupOrphanCidMutationLease(File(entity.path), owner);
        continue;
      }
      await entity.delete();
    }
  }

  static Future<bool> _hasStartupBarrier(Directory documentsRoot) async {
    final barrier = _directFile(documentsRoot, _startupBarrierName);
    final type = await FileSystemEntity.type(barrier.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat 启动 barrier 类型异常');
    }
    return true;
  }

  static Future<void> _waitForStartupBarrier(
    Directory documentsRoot, {
    required DateTime deadline,
  }) async {
    while (await _hasStartupBarrier(documentsRoot)) {
      if (!DateTime.now().isBefore(deadline)) {
        throw StateError('Chat 启动预检持续占用');
      }
      await Future<void>.delayed(_leasePollInterval);
    }
  }

  static Future<_ChatCrossIsolateLease> _acquireStartupBarrier(
    Directory documentsRoot,
  ) async {
    final file = _directFile(documentsRoot, _startupBarrierName);
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (true) {
      final owner = _ChatCidLeaseOwner(
        processId: pid,
        processGeneration: _backgroundProcessGeneration,
        nonce: _newNonce(),
      );
      try {
        await file.create(exclusive: true);
        await file.writeAsString(owner.encode(), flush: true);
        return _ChatCrossIsolateLease(
          file: file,
          owner: owner,
          heartbeatInterval: _leaseHeartbeatInterval,
        );
      } on FileSystemException {
        if (await _reapExpiredOwnedLease(file, allowSameProcess: false)) {
          continue;
        }
        if (!DateTime.now().isBefore(deadline)) {
          throw StateError('Chat 启动 barrier 被其它预检持续占用');
        }
        await Future<void>.delayed(_leasePollInterval);
      }
    }
  }

  static Future<void> _throwIfCurrentProcessWipeRequested(
    Directory documentsRoot,
  ) async {
    for (final name in <String>[_pendingMarkerName, _completeMarkerName]) {
      final marker = _directFile(documentsRoot, name);
      final type = await FileSystemEntity.type(marker.path, followLinks: false);
      if (type != FileSystemEntityType.notFound) {
        throw StateError('Chat 已进入跨 isolate 擦除终态');
      }
    }
  }

  static Future<ChatPersistentWipeState> readPersistentWipeState(
    Directory documentsRoot,
  ) async {
    final pending = _directFile(documentsRoot, _pendingMarkerName);
    final complete = _directFile(documentsRoot, _completeMarkerName);
    final completeType =
        await FileSystemEntity.type(complete.path, followLinks: false);
    if (completeType == FileSystemEntityType.file) {
      try {
        if (await complete.readAsString() == _completeMarkerPayload) {
          return ChatPersistentWipeState.complete;
        }
      } catch (_) {
        return ChatPersistentWipeState.pending;
      }
    } else if (completeType != FileSystemEntityType.notFound) {
      return ChatPersistentWipeState.pending;
    }
    final pendingType =
        await FileSystemEntity.type(pending.path, followLinks: false);
    return pendingType == FileSystemEntityType.notFound
        ? ChatPersistentWipeState.none
        : ChatPersistentWipeState.pending;
  }

  static Future<void> markWipeComplete(Directory documentsRoot) async {
    final state = await readPersistentWipeState(documentsRoot);
    if (state == ChatPersistentWipeState.none) {
      throw StateError('缺少 pending marker，禁止标记数据擦除完成');
    }
    if (state == ChatPersistentWipeState.complete) return;

    final complete = _directFile(documentsRoot, _completeMarkerName);
    final nonce = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final staged = _directFile(
      documentsRoot,
      '.$_completeMarkerName.$pid.$nonce',
    );
    try {
      await staged.create(exclusive: true);
      final handle = await staged.open(mode: FileMode.write);
      try {
        await handle.writeString(_completeMarkerPayload);
        await handle.flush();
      } finally {
        await handle.close();
      }
      if (await FileSystemEntity.type(complete.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('数据擦除 complete marker 目标已被占用');
      }
      await staged.rename(complete.path);
    } finally {
      if (await FileSystemEntity.type(staged.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await staged.delete();
      }
    }
  }

  static Future<void> clearCompletedWipe(Directory documentsRoot) async {
    if (await readPersistentWipeState(documentsRoot) !=
        ChatPersistentWipeState.complete) {
      throw StateError('只有已完整擦除的 marker 才允许清理');
    }
    if (await _hasCurrentProcessLease(documentsRoot)) {
      throw StateError('Chat 当前进程仍有未收口 lease，禁止清理擦除门闩');
    }
    final complete = _directFile(documentsRoot, _completeMarkerName);
    final pending = _directFile(documentsRoot, _pendingMarkerName);
    // 先删 complete：中途崩溃会留 pending 并重试擦除，不会误放行。
    await complete.delete();
    if (await FileSystemEntity.type(pending.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('数据擦除 pending marker 类型异常');
    }
    await pending.delete();
    await _removeArtifactsFromOtherProcesses(
      documentsRoot,
      removeStagedComplete: true,
    );
  }

  static Future<bool> _hasCurrentProcessLease(
    Directory documentsRoot,
  ) async {
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (name.startsWith(_leasePrefix) && name.endsWith(_leaseSuffix)) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.file) return true;
        if (!await _reapExpiredOwnedLease(
          File(entity.path),
          allowSameProcess: false,
        )) {
          return true;
        }
      }
      if (name.startsWith(_cidMutationLeasePrefix) &&
          name.endsWith(_cidMutationLeaseSuffix)) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.file) return true;
        if (!await _reapExpiredCidMutationLease(File(entity.path))) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<void> _removeArtifactsFromOtherProcesses(
    Directory documentsRoot, {
    bool removeStagedComplete = false,
  }) async {
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      final isProtocolArtifact = (name.startsWith(_leasePrefix) &&
              name.endsWith(_leaseSuffix)) ||
          (removeStagedComplete && name.startsWith('.$_completeMarkerName.'));
      final belongsToCurrentProcess = name.startsWith(_currentLeasePrefix);
      if (!isProtocolArtifact || belongsToCurrentProcess) continue;
      final type = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );
      if (name.startsWith(_leasePrefix) && name.endsWith(_leaseSuffix)) {
        if (type != FileSystemEntityType.file) {
          throw StateError('Chat 后台 lease 类型异常');
        }
        // 活跃的其它 pid 后台动作只能等待/超时，绝不能因进程号不同直接偷锁。
        await _reapExpiredOwnedLease(
          File(entity.path),
          allowSameProcess: false,
        );
      } else if (type == FileSystemEntityType.file ||
          type == FileSystemEntityType.link) {
        try {
          await entity.delete();
        } on FileSystemException {
          // 被并发清理时已不存在即可；仍存在时下次协议会继续清理。
        }
      }
    }
  }

  static Future<_ChatCidLeaseOwner?> _readLeaseOwner(File leaseFile) async {
    try {
      return _ChatCidLeaseOwner.decode(await leaseFile.readAsString());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<bool> _reapExpiredOwnedLease(
    File leaseFile, {
    required bool allowSameProcess,
  }) async {
    final firstType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (firstType == FileSystemEntityType.notFound) return true;
    if (firstType != FileSystemEntityType.file) {
      throw StateError('Chat 跨 isolate lease 类型异常');
    }
    final firstStat = await leaseFile.stat();
    if (DateTime.now().difference(firstStat.modified) <= _leaseStaleAfter) {
      return false;
    }
    final firstOwner = await _readLeaseOwner(leaseFile);
    if (firstOwner == null ||
        (!allowSameProcess && firstOwner.processId == pid)) {
      return false;
    }
    await Future<void>.delayed(
      _leaseHeartbeatInterval + _leasePollInterval,
    );
    final secondType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (secondType == FileSystemEntityType.notFound) return true;
    if (secondType != FileSystemEntityType.file) {
      throw StateError('Chat 跨 isolate lease 类型异常');
    }
    final secondStat = await leaseFile.stat();
    final secondOwner = await _readLeaseOwner(leaseFile);
    if (secondOwner?.encode() != firstOwner.encode() ||
        secondStat.modified.millisecondsSinceEpoch !=
            firstStat.modified.millisecondsSinceEpoch ||
        DateTime.now().difference(secondStat.modified) <= _leaseStaleAfter) {
      return false;
    }
    final stale = _directFile(
      leaseFile.parent,
      '${_basename(leaseFile.path)}.$pid.${_newNonce()}.stale',
    );
    try {
      final renamed = await leaseFile.rename(stale.path);
      await renamed.delete();
      return true;
    } on FileSystemException {
      return await FileSystemEntity.type(
            leaseFile.path,
            followLinks: false,
          ) ==
          FileSystemEntityType.notFound;
    }
  }

  static Future<void> _deleteOwnedLeaseFile(
    File leaseFile,
    _ChatCidLeaseOwner owner, {
    bool allowMissing = false,
  }) async {
    final type = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound && allowMissing) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat 跨 isolate lease 已丢失或类型异常');
    }
    final actual = await _readLeaseOwner(leaseFile);
    if (actual?.encode() != owner.encode()) {
      throw StateError('Chat 跨 isolate lease 所有权已变化');
    }
    await leaseFile.delete();
    if (await FileSystemEntity.type(leaseFile.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Chat 跨 isolate lease 释放失败');
    }
  }

  static Future<bool> _reapExpiredCidMutationLease(File leaseFile) async {
    final firstType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (firstType == FileSystemEntityType.notFound) return true;
    if (firstType != FileSystemEntityType.file) {
      throw StateError('Chat CID 文件协调 lease 类型异常');
    }
    final firstStat = await leaseFile.stat();
    if (DateTime.now().difference(firstStat.modified) <=
        _cidMutationStaleAfter) {
      return false;
    }
    final firstOwner = await _readCidLeaseOwner(leaseFile);
    // native/OpenMLS 或大文件同步调用可能阻塞 owner isolate 的事件循环超过 stale
    // 阈值。同一 pid 的任何 lease 都必须视为仍可能存活，运行中绝不偷锁；同 pid
    // isolate 崩溃残留只在下一次 main 启动 preflight、确认旧动作不存在后清理。
    if (firstOwner?.processId == pid) {
      return false;
    }

    // stale 判定后再跨过一个完整 heartbeat 周期复核，封住 owner 正在续租的竞态。
    await Future<void>.delayed(
      _cidMutationHeartbeatInterval + _leasePollInterval,
    );
    final secondType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (secondType == FileSystemEntityType.notFound) return true;
    if (secondType != FileSystemEntityType.file) {
      throw StateError('Chat CID 文件协调 lease 类型异常');
    }
    final secondStat = await leaseFile.stat();
    final secondOwner = await _readCidLeaseOwner(leaseFile);
    if (secondOwner?.encode() != firstOwner?.encode() ||
        secondStat.modified.millisecondsSinceEpoch !=
            firstStat.modified.millisecondsSinceEpoch ||
        DateTime.now().difference(secondStat.modified) <=
            _cidMutationStaleAfter) {
      return false;
    }

    final stale = _directFile(
      leaseFile.parent,
      '${_basename(leaseFile.path)}.$pid.${_newNonce()}'
      '$_cidMutationStaleSuffix',
    );
    try {
      final renamed = await leaseFile.rename(stale.path);
      await renamed.delete();
      return true;
    } on FileSystemException {
      return await FileSystemEntity.type(
            leaseFile.path,
            followLinks: false,
          ) ==
          FileSystemEntityType.notFound;
    }
  }

  static Future<void> _retireStartupOrphanCidMutationLease(
    File leaseFile,
    _ChatCidLeaseOwner expectedOwner,
  ) async {
    final type = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat 启动预检发现异常 CID lease 类型');
    }
    final actualOwner = await _readCidLeaseOwner(leaseFile);
    if (actualOwner?.encode() != expectedOwner.encode()) {
      throw StateError('Chat 启动预检期间 CID lease 所有权已变化');
    }
    if (actualOwner!.processGeneration == _cidMutationProcessGeneration) {
      throw StateError('Chat 启动预检拒绝退役当前进程 CID lease');
    }

    // rename 是退役的原子边界；若进程在 delete 前退出，下一次预检会按 .stale
    // artifact 继续删除，不会把半清理文件重新解释为活跃 lease。
    final stale = _directFile(
      leaseFile.parent,
      '${_basename(leaseFile.path)}.$pid.${_newNonce()}'
      '$_cidMutationStaleSuffix',
    );
    try {
      final retired = await leaseFile.rename(stale.path);
      await retired.delete();
    } on FileSystemException {
      if (await FileSystemEntity.type(leaseFile.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        return;
      }
      rethrow;
    }
  }

  static Future<_ChatCidLeaseOwner?> _readCidLeaseOwner(File leaseFile) async {
    try {
      return _ChatCidLeaseOwner.decode(await leaseFile.readAsString());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> _deleteOwnedCidLeaseFile(
    File leaseFile,
    _ChatCidLeaseOwner owner, {
    bool allowMissing = false,
  }) async {
    final type = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound && allowMissing) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat CID 文件协调 lease 已丢失或类型异常');
    }
    final actual = await _readCidLeaseOwner(leaseFile);
    if (actual?.encode() != owner.encode()) {
      throw StateError('Chat CID 文件协调 lease 所有权已变化');
    }
    await leaseFile.delete();
    if (await FileSystemEntity.type(leaseFile.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Chat CID 文件协调 lease 释放失败');
    }
  }

  static File _directFile(Directory root, String name) {
    if (name.contains(Platform.pathSeparator)) {
      throw StateError('Chat 跨 isolate 协调文件名不合法');
    }
    final file = File('${root.path}${Platform.pathSeparator}$name').absolute;
    if (file.parent.path != root.path) {
      throw StateError('Chat 跨 isolate 协调文件越过 Documents 根目录');
    }
    return file;
  }

  static String _basename(String path) =>
      path.split(Platform.pathSeparator).last;
}

class _ChatCidLeaseOwner {
  const _ChatCidLeaseOwner({
    required this.processId,
    required this.processGeneration,
    required this.nonce,
  });

  final int processId;
  final String processGeneration;
  final String nonce;

  String encode() => '$processId\n$processGeneration\n$nonce\n';

  static _ChatCidLeaseOwner? decode(String raw) {
    final lines = raw.split('\n');
    if (lines.length != 4 || lines.last.isNotEmpty) return null;
    final processId = int.tryParse(lines[0]);
    if (processId == null ||
        processId <= 0 ||
        lines[1].isEmpty ||
        lines[2].isEmpty) {
      return null;
    }
    return _ChatCidLeaseOwner(
      processId: processId,
      processGeneration: lines[1],
      nonce: lines[2],
    );
  }
}

class _ChatCidMutationLease {
  _ChatCidMutationLease({
    required File file,
    required _ChatCidLeaseOwner owner,
    required Duration heartbeatInterval,
  })  : _file = file,
        _owner = owner {
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _scheduleHeartbeat());
  }

  final File _file;
  final _ChatCidLeaseOwner _owner;
  late final Timer _heartbeat;
  Future<void> _heartbeatTail = Future<void>.value();
  Object? _heartbeatError;
  StackTrace? _heartbeatStackTrace;
  bool _released = false;

  void _scheduleHeartbeat() {
    if (_released || _heartbeatError != null) return;
    _heartbeatTail = _heartbeatTail.then<void>((_) async {
      if (_released || _heartbeatError != null) return;
      final actual = await _ChatCrossIsolateCoordinator._readCidLeaseOwner(
        _file,
      );
      if (actual?.encode() != _owner.encode()) {
        throw StateError('Chat CID 文件协调 lease 所有权已变化');
      }
      await _file.setLastModified(DateTime.now());
    }).catchError((Object error, StackTrace stackTrace) {
      _heartbeatError = error;
      _heartbeatStackTrace = stackTrace;
    });
  }

  Future<void> validateHealthy() async {
    await _heartbeatTail;
    final error = _heartbeatError;
    if (error != null) {
      Error.throwWithStackTrace(
        error,
        _heartbeatStackTrace ?? StackTrace.current,
      );
    }
    final actual = await _ChatCrossIsolateCoordinator._readCidLeaseOwner(
      _file,
    );
    if (actual?.encode() != _owner.encode()) {
      throw StateError('Chat CID 文件协调 lease 所有权已变化');
    }
  }

  Future<void> release() async {
    if (_released) return;
    _heartbeat.cancel();
    await _heartbeatTail;
    Object? healthError = _heartbeatError;
    StackTrace? healthStackTrace = _heartbeatStackTrace;
    try {
      await _ChatCrossIsolateCoordinator._deleteOwnedCidLeaseFile(
        _file,
        _owner,
      );
      _released = true;
    } catch (error, stackTrace) {
      healthError ??= error;
      healthStackTrace ??= stackTrace;
    }
    if (healthError != null) {
      Error.throwWithStackTrace(
        healthError,
        healthStackTrace ?? StackTrace.current,
      );
    }
  }
}

class _ChatCidMutationGate {
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> run<T>(String cidNumber, Future<T> Function() action) {
    final previous = _tails[cidNumber] ?? Future<void>.value();
    final completer = Completer<T>();
    final tail = completer.future.then<void>((_) {}, onError: (_) {});
    _tails[cidNumber] = tail;

    () async {
      try {
        try {
          await previous;
        } catch (_) {
          // 前一操作失败不能毒化同一 CID 的后续本地队列。
        }
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (identical(_tails[cidNumber], tail)) {
          _tails.remove(cidNumber);
        }
      }
    }();
    return completer.future;
  }
}

class _ChatCidLeaseScope {
  _ChatCidLeaseScope(this.cidNumber, this.bindingToken);

  final String cidNumber;
  final ChatBindingFenceToken? bindingToken;
  bool _active = true;
  final Set<Future<void>> _nestedOperations = <Future<void>>{};

  bool get isActive => _active;

  Future<T> track<T>(Future<T> operation) {
    final drained = operation.then<void>((_) {}, onError: (_) {});
    _nestedOperations.add(drained);
    drained.whenComplete(() => _nestedOperations.remove(drained));
    return operation;
  }

  void stopAccepting() => _active = false;

  Future<void> drain() async {
    while (_nestedOperations.isNotEmpty) {
      await Future.wait<void>(_nestedOperations.toList(growable: false));
    }
  }
}

/// 把每一次 OpenMLS 状态读写都绑定到创建上下文时捕获的持久 fence。
///
/// Runtime 的上层流程仍会把“密码学状态推进 + Isar 最终 CAS”包在同一 CID lease
/// 内；本代理是最后一道边界，避免后来新增的直接 crypto 调用绕过跨 isolate 协调。
class _ChatBindingFencedMlsCrypto implements MlsCrypto, MlsGroupCrypto {
  const _ChatBindingFencedMlsCrypto({
    required ChatRuntime runtime,
    required ChatBindingFenceToken bindingToken,
    required MlsCrypto delegate,
  })  : _runtime = runtime,
        _bindingToken = bindingToken,
        _delegate = delegate;

  final ChatRuntime _runtime;
  final ChatBindingFenceToken _bindingToken;
  final MlsCrypto _delegate;

  Future<T> _run<T>(Future<T> Function() operation) =>
      _runtime._runBindingFileMutation(_bindingToken, operation);

  MlsGroupCrypto get _groupDelegate {
    final delegate = _delegate;
    if (delegate is! MlsGroupCrypto) {
      throw StateError('当前 OpenMLS 实现不支持私密小群');
    }
    return delegate as MlsGroupCrypto;
  }

  void dispose() {
    final delegate = _delegate;
    if (delegate is NativeMlsCrypto) delegate.dispose();
  }

  @override
  Future<String> readDevicePublicKey(ChatDevice identity) =>
      _run(() => _delegate.readDevicePublicKey(identity));

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = false,
  }) =>
      _run(
        () => _delegate.createKeyPackage(identity, lastResort: lastResort),
      );

  @override
  Future<MlsOutboundMessage> encrypt({
    required String conversationId,
    required String recipientCidNumber,
    MlsKeyPackage? recipientKeyPackage,
    required List<int> plaintext,
  }) =>
      _run(
        () => _delegate.encrypt(
          conversationId: conversationId,
          recipientCidNumber: recipientCidNumber,
          recipientKeyPackage: recipientKeyPackage,
          plaintext: plaintext,
        ),
      );

  @override
  Future<List<int>> decrypt(MlsWireMessage message) =>
      _run(() => _delegate.decrypt(message));

  @override
  Future<MlsInboundMessage> processIncoming(MlsWireMessage message) =>
      _run(() => _delegate.processIncoming(message));

  @override
  Future<GroupCreated> createGroup(String groupId) =>
      _run(() => _groupDelegate.createGroup(groupId));

  @override
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  ) =>
      _run(() => _groupDelegate.addMembers(groupId, keyPackages));

  @override
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberCidNumbers,
  ) =>
      _run(() => _groupDelegate.removeMembers(groupId, memberCidNumbers));

  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) =>
      _run(() => _groupDelegate.groupCreateMessage(groupId, plaintext));

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) =>
      _run(() => _groupDelegate.groupProcess(wire));

  @override
  Future<GroupState> groupState(String groupId) =>
      _run(() => _groupDelegate.groupState(groupId));
}

class _ChatCrossIsolateLease {
  _ChatCrossIsolateLease({
    required File file,
    required _ChatCidLeaseOwner owner,
    required Duration heartbeatInterval,
  })  : _file = file,
        _owner = owner {
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _scheduleHeartbeat());
  }

  final File _file;
  final _ChatCidLeaseOwner _owner;
  late final Timer _heartbeat;
  Future<void> _heartbeatTail = Future<void>.value();
  Object? _heartbeatError;
  StackTrace? _heartbeatStackTrace;
  bool _released = false;

  void _scheduleHeartbeat() {
    if (_released || _heartbeatError != null) return;
    _heartbeatTail = _heartbeatTail.then<void>((_) async {
      if (_released || _heartbeatError != null) return;
      final actual = await _ChatCrossIsolateCoordinator._readLeaseOwner(_file);
      if (actual?.encode() != _owner.encode()) {
        throw StateError('Chat 跨 isolate lease 所有权已变化');
      }
      await _file.setLastModified(DateTime.now());
    }).catchError((Object error, StackTrace stackTrace) {
      _heartbeatError = error;
      _heartbeatStackTrace = stackTrace;
    });
  }

  Future<void> release() async {
    if (_released) return;
    _heartbeat.cancel();
    await _heartbeatTail;
    Object? error = _heartbeatError;
    StackTrace? stackTrace = _heartbeatStackTrace;
    try {
      await _ChatCrossIsolateCoordinator._deleteOwnedLeaseFile(
        _file,
        _owner,
      );
      _released = true;
    } catch (caught, caughtStackTrace) {
      error ??= caught;
      stackTrace ??= caughtStackTrace;
    }
    if (error != null) {
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
    }
  }
}

class _ChatAccountContext {
  _ChatAccountContext({
    required this.account,
    required this.bindingToken,
    required this.deviceId,
    required this.devicePublicKey,
    required this.crypto,
    required this.transport,
    required this.webrtc,
    required this.sessionExpiresAt,
  });

  final _ChatAccount account;
  final ChatBindingFenceToken bindingToken;
  final String deviceId;
  final String devicePublicKey;
  final MlsCrypto crypto;
  final ChatCloudTransport transport;
  final ChatWebrtcTransport webrtc;
  final int sessionExpiresAt;
  late final _RetryableAsyncDisposer _disposer =
      _RetryableAsyncDisposer(_dispose);

  bool get isUsable =>
      sessionExpiresAt - ChatRuntime._sessionRefreshSkewMillis >
      DateTime.now().millisecondsSinceEpoch;

  /// 当前绑定失效后主动清零 MLS 状态钥并关闭网络上下文。
  Future<void> dispose() => _disposer.dispose();

  Future<void> _dispose() async {
    // 先停止会产生新附件/网络回调的资源并等待其 tail，再清零 MLS 状态钥；禁止
    // 正在执行的回调观察到已 dispose 的 crypto/stateStore。
    transport.dispose();
    await webrtc.dispose();
    final currentCrypto = crypto;
    if (currentCrypto is _ChatBindingFencedMlsCrypto) {
      currentCrypto.dispose();
    } else if (currentCrypto is NativeMlsCrypto) {
      currentCrypto.dispose();
    }
  }

  ChatDevice get identity => ChatDevice(
        cidNumber: account.cidNumber,
        deviceId: deviceId,
        devicePublicKey: devicePublicKey,
      );
}

/// 前台常驻只持有账户、设备标识、会话与WSS传输，不打开ChatIsar、MLS或WebRTC。
class _ChatSignalContext {
  const _ChatSignalContext({
    required this.account,
    required this.identity,
    required this.transport,
  });

  final _ChatAccount account;
  final ChatDevice identity;
  final ChatCloudTransport transport;
}

class _ChatAccount {
  const _ChatAccount({
    required this.walletIndex,
    required this.genesisHash,
    required this.cidNumber,
    required this.bindingRevision,
    required this.accountId,
    required this.walletName,
  });

  final int walletIndex;
  final String genesisHash;
  final String cidNumber;
  final int bindingRevision;
  final String accountId;
  final String walletName;
}

/// 公民 Chat 运行态编排服务。
///
/// 页面层不直接操作 OpenMLS、Cloudflare 瞬时转发、近场通道和 Isar。
/// 这个服务负责读取身份账户所在钱包、建立设备身份，并把聊天发送
/// /同步接到正式 transport。已有 P-256 设备子钥和数据用途钥均静默使用；实际登录由
/// Worker 确认 P-256 未登记后才登记，实际数据访问确认数据钥缺失后才生成，两条流程
/// 独立且页面门禁均不参与。
class ChatRuntime {
  ChatRuntime({
    ChatStore? store,
    WalletManager? walletManager,
    SharedPreferences? preferences,
    SquareApiClient? squareApiClient,
    ChatLoginSigner? loginSigner,
    DeviceSubkey? deviceSubkey,
    MlsStateStoreFactory? stateStoreFactory,
    MlsCrypto Function(ChatDevice identity, MlsStateStore stateStore)?
        cryptoFactory,
    ChatCloudTransportFactory? cloudTransportFactory,
    ChatPushService? pushService,
    ChatPushTokenProvider? pushTokenProvider,
    CurrentUserContext? currentUserContext,
    ChainBootstrapApi? bootstrapApi,
    Future<Directory> Function()? documentsDirectoryProvider,
    @visibleForTesting bool debugUseIndependentCidMutationGate = false,
  })  : _store = _initializeWhileProcessActive(() => store ?? ChatStore()),
        _walletManager = walletManager ?? WalletManager(),
        _currentUserContext = currentUserContext,
        _bootstrapApi = bootstrapApi ?? ChainBootstrapApi(),
        _preferences = preferences,
        _squareApiClient = squareApiClient ?? SquareApiClient(),
        _loginSigner = loginSigner,
        _deviceSubkey = deviceSubkey ?? DeviceSubkey(),
        _stateStoreFactory = stateStoreFactory,
        _cryptoFactory = cryptoFactory,
        _cloudTransportFactory = cloudTransportFactory,
        _pushService = pushService ?? ChatPushService(),
        _pushTokenProvider = pushTokenProvider,
        _cidMutationGate = debugUseIndependentCidMutationGate
            ? _ChatCidMutationGate()
            : _sharedCidMutationGate,
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory {
    if (debugUseIndependentCidMutationGate &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许使用独立 Chat CID gate');
    }
    _ensureProcessActive();
    _liveInstances.removeWhere((reference) => reference.target == null);
    _liveInstances.add(WeakReference<ChatRuntime>(this));
  }

  static const _kDevicePrefix = 'chat.by_cid';
  static const _kPushRegistrationPrefix = 'chat.push.registration';
  static const _pushEndpointTtl = Duration(days: 90);
  static const _pushEndpointRefreshSkewMillis = 24 * 60 * 60 * 1000;
  static const _sessionRefreshSkewMillis = 60 * 1000;
  static const String _fileHandoverMacDomain =
      'citizenapp.local/chat-file-handover|';

  /// 测试专用：并发提交实时 callback，验证内部仍按提交顺序串行完成。
  @visibleForTesting
  static Future<void> debugRunRealtimeCallbacksForTest(
    List<Future<void> Function()> callbacks,
  ) async {
    final session = _ChatRealtimeSession();
    await Future.wait<void>(callbacks.map(session.runCallback));
  }

  /// AppLock 擦除意图是进程级终态：一旦置位，现有和新建 ChatRuntime 都不得再建立
  /// 网络、MLS 或文件上下文。正常恢复只能依赖进程重启，禁止在擦除后重新生成目录。
  static bool _processWipeRequested = false;
  static Future<void>? _localFileWipeInFlight;
  static final List<WeakReference<ChatRuntime>> _liveInstances =
      <WeakReference<ChatRuntime>>[];

  /// close 失败的 Runtime 必须被强引用到下一次 AppLock 重试；否则 UI 放弃最后一个
  /// 引用后 GC 会让 WeakReference 消失，仍存活的 native/socket 生产者可能被漏关。
  static final Set<ChatRuntime> _instancesPendingClose = <ChatRuntime>{};
  static final Set<Future<void>> _processOperations = <Future<void>>{};
  static final _ChatCidMutationGate _sharedCidMutationGate =
      _ChatCidMutationGate();
  static final Object _cidMutationZoneKey = Object();

  bool _closedForWipe = false;
  final Set<Future<void>> _contextDisposals = <Future<void>>{};
  final Set<_ChatAccountContext> _contextsPendingDisposal =
      <_ChatAccountContext>{};
  final Set<Future<void>> _fileMutations = <Future<void>>{};
  final Set<Future<void>> _runtimeOperations = <Future<void>>{};
  final Set<Future<_ChatAccountContext>> _readyFlightsPendingInvalidation =
      <Future<_ChatAccountContext>>{};
  final Set<_ChatRealtimeSession> _realtimeSessions = <_ChatRealtimeSession>{};
  final Map<String, _ChatRealtimeHub> _realtimeHubs =
      <String, _ChatRealtimeHub>{};
  _RetryableAsyncDisposer? _debugContextDisposerForTest;

  @visibleForTesting
  static String deviceIdPreferenceKey(String cidNumber) =>
      '$_kDevicePrefix.${Uri.encodeComponent(cidNumber)}.device.id';

  @visibleForTesting
  static String devicePublicKeyCachePreferenceKey(String cidNumber) =>
      '$_kDevicePrefix.${Uri.encodeComponent(cidNumber)}.device.public_key_cache_hex';

  final ChatStore _store;
  final WalletManager _walletManager;
  final CurrentUserContext? _currentUserContext;
  final ChainBootstrapApi _bootstrapApi;

  /// 身份账户单源(CID 绑定账户);chat 自身 accountId 一律取此,walletIndex 保持钱包级。
  CurrentUserContext get _currentUser =>
      _currentUserContext ?? CurrentUserContext.instance;

  final SharedPreferences? _preferences;
  final SquareApiClient _squareApiClient;
  final ChatLoginSigner? _loginSigner;
  final DeviceSubkey _deviceSubkey;
  final MlsStateStoreFactory? _stateStoreFactory;
  final MlsCrypto Function(ChatDevice identity, MlsStateStore stateStore)?
      _cryptoFactory;
  final ChatCloudTransportFactory? _cloudTransportFactory;
  final ChatPushService _pushService;
  final ChatPushTokenProvider? _pushTokenProvider;
  final _ChatCidMutationGate _cidMutationGate;
  final _ChatCidMutationGate _outboundDeliveryGate = _ChatCidMutationGate();
  final Future<Directory> Function() _documentsDirectoryProvider;

  /// 正在经 WebRTC 传输字节的媒体 attachmentId(初始发送或补发中),用于去重:
  /// peer_ready 触发的补发不得对在途媒体再整块重传。
  final Set<String> _mediaBytesInFlight = {};

  /// WSS 在线帧与连接后补拉可能命中同一密文；进程内先按既有 envelope_id 去重，
  /// 本机处理成功后只重试云端 ACK，不得再次推进同一个 OpenMLS 控制消息。
  final Set<String> _mailboxEnvelopeReceipts = <String>{};
  final Set<String> _incomingConvergenceInFlight = <String>{};

  /// 同一账户/设备只允许一条初始化链。成功上下文复用到 session 临近过期；
  /// 失败只释放命中的 future，不得误删后来创建的新初始化。
  final Map<String, Future<_ChatAccountContext>> _readyFlights = {};
  final Map<String, _ChatAccountContext> _readyContexts = {};
  final Map<String, String> _accountContextKeys = {};
  final Map<String, int> _accountGenerations = {};
  final Set<String> _blockedAccountIds = <String>{};

  /// AppLock 在触碰任何业务存储前先落盘 pending marker。
  ///
  /// 本 isolate 终态在返回 Future 前生效；marker 保留到全域成功后的
  /// complete 状态，部分失败跨重启仍无鉴权继续擦除。
  static Future<void> beginPersistentAppDataWipe({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) {
    _processWipeRequested = true;
    return _resolveWipeDocumentsRoot(documentsDirectoryProvider).then(
      _ChatCrossIsolateCoordinator.ensureWipePending,
    );
  }

  static Future<ChatPersistentWipeState> readPersistentAppDataWipeState({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(
      documentsDirectoryProvider,
    );
    return _ChatCrossIsolateCoordinator.readPersistentWipeState(root);
  }

  /// main 在构造任何 ChatRuntime 或启动后台操作前调用一次。
  static Future<void> preflightCidMutationLeasesAtStartup({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    await runStartupPreflight(
      operation: () async {},
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
  }

  /// 持有当前进程 generation 的真实 CID lease，验证启动预检不会误删活锁。
  /// 仅供 Flutter 测试使用；生产启动仍只能从 [runStartupPreflight] 进入。
  @visibleForTesting
  static Future<T> debugRunCidMutationLeaseForTest<T>({
    required String cidNumber,
    required Future<T> Function() operation,
    required Future<Directory> Function() documentsDirectoryProvider,
  }) async {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许持有 Chat CID lease');
    }
    final root = await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
      documentsDirectoryProvider,
    );
    final lease = await _ChatCrossIsolateCoordinator.acquireCidMutationLease(
      root,
      cidNumber,
    );
    try {
      return await operation();
    } finally {
      await lease.release();
    }
  }

  /// AppLock 整段启动恢复都持有 startup barrier；不能只在 CID artifact 清理时短持，
  /// 否则 marker 读取/恢复 wipe 的间隙仍可能有后台 isolate 进入。
  static Future<T> runStartupPreflight<T>({
    required Future<T> Function() operation,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(
      documentsDirectoryProvider,
    );
    return _ChatCrossIsolateCoordinator.runStartupPreflight(root, operation);
  }

  /// 启动与退后台只按 Chat 文件域结构清除短命明文，不构造 Runtime、不读取默认账户、
  /// WalletIsar 或任何密钥。每个物理 CID 分区仍取得同一跨 isolate lease。
  static Future<void> purgePlainAttachmentsWithoutAccount({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    _ensureProcessActive();
    final documentsRoot = await _resolveWipeDocumentsRoot(
      documentsDirectoryProvider,
    );
    final byCid = Directory(
      '${documentsRoot.path}${Platform.pathSeparator}chat'
      '${Platform.pathSeparator}by_cid',
    );
    final byCidType = await FileSystemEntity.type(
      byCid.path,
      followLinks: false,
    );
    if (byCidType == FileSystemEntityType.notFound) return;
    if (byCidType != FileSystemEntityType.directory) {
      throw StateError('Chat 明文清扫根路径类型异常');
    }
    await for (final cidEntity in byCid.list(followLinks: false)) {
      final cidType = await FileSystemEntity.type(
        cidEntity.path,
        followLinks: false,
      );
      if (cidType != FileSystemEntityType.directory) {
        throw StateError('Chat 明文清扫发现非目录 CID 分区');
      }
      final cidDirectory = Directory(cidEntity.path);
      final cidPathKey = cidDirectory.path.split(Platform.pathSeparator).last;
      if (cidPathKey.isEmpty) throw StateError('Chat 明文清扫 CID 分区名为空');
      final lease = await _ChatCrossIsolateCoordinator.acquireCidMutationLease(
        documentsRoot,
        cidPathKey,
      );
      try {
        await _purgePlainAttachmentsInCidDirectory(cidDirectory);
        await lease.validateHealthy();
      } finally {
        await lease.release();
      }
    }
  }

  static Future<void> _purgePlainAttachmentsInCidDirectory(
    Directory cidDirectory,
  ) async {
    final byBinding = Directory(
      '${cidDirectory.path}${Platform.pathSeparator}by_binding',
    );
    final byBindingType = await FileSystemEntity.type(
      byBinding.path,
      followLinks: false,
    );
    if (byBindingType == FileSystemEntityType.notFound) return;
    if (byBindingType != FileSystemEntityType.directory) {
      throw StateError('Chat 明文清扫 binding 根路径类型异常');
    }
    await for (final revision in byBinding.list(followLinks: false)) {
      if (await FileSystemEntity.type(revision.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw StateError('Chat 明文清扫发现非目录 binding revision');
      }
      await for (final account in Directory(revision.path).list(
        followLinks: false,
      )) {
        if (await FileSystemEntity.type(account.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw StateError('Chat 明文清扫发现非目录 account binding');
        }
        final plain = Directory(
          '${account.path}${Platform.pathSeparator}attachments'
          '${Platform.pathSeparator}${AttachmentVault.plainDirName}',
        );
        final plainType = await FileSystemEntity.type(
          plain.path,
          followLinks: false,
        );
        if (plainType == FileSystemEntityType.notFound) continue;
        if (plainType != FileSystemEntityType.directory) {
          throw StateError('Chat 明文附件路径类型异常');
        }
        await plain.delete(recursive: true);
        if (await FileSystemEntity.type(plain.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw StateError('Chat 明文附件目录清除失败');
        }
      }
    }
  }

  static Future<void> markPersistentAppDataWipeComplete({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(
      documentsDirectoryProvider,
    );
    await _ChatCrossIsolateCoordinator.markWipeComplete(root);
  }

  /// 只有新前台进程在启动预检确认 complete 后才能清理门闩。
  static Future<void> clearCompletedPersistentAppDataWipe({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(
      documentsDirectoryProvider,
    );
    await _ChatCrossIsolateCoordinator.clearCompletedWipe(root);
  }

  static Future<Directory> _resolveWipeDocumentsRoot(
    Future<Directory> Function()? documentsDirectoryProvider,
  ) {
    return _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
      documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
    );
  }

  /// 让 AppLock 把整个 `${documentsRoot}/chat` 作为一个独立擦除域。
  ///
  /// 终态在本方法返回 Future 前同步生效。先关闭已建立上下文并等待已有 ready flight
  /// 收口，再删除唯一 Chat 根目录；任一步失败都上抛给 AppLock 聚合，绝不扩大删除目标。
  static Future<void> closeAndDeleteLocalFiles({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) {
    _processWipeRequested = true;
    final running = _localFileWipeInFlight;
    if (running != null) return running;

    final provider =
        documentsDirectoryProvider ?? getApplicationDocumentsDirectory;
    final instances = <ChatRuntime>[];
    for (final reference in _liveInstances) {
      final instance = reference.target;
      if (instance != null) {
        _instancesPendingClose.add(instance);
      }
    }
    _liveInstances.removeWhere((reference) => reference.target == null);
    instances.addAll(_instancesPendingClose);

    late final Future<void> task;
    task = _closeInstancesAndDeleteRoot(instances, provider).whenComplete(() {
      if (identical(_localFileWipeInFlight, task)) {
        _localFileWipeInFlight = null;
      }
    });
    _localFileWipeInFlight = task;
    return task;
  }

  static Future<void> _closeInstancesAndDeleteRoot(
    List<ChatRuntime> instances,
    Future<Directory> Function() documentsDirectoryProvider,
  ) async {
    final failures = <String>[];
    Directory? documentsRoot;
    try {
      documentsRoot = await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
        documentsDirectoryProvider,
      );
      await _ChatCrossIsolateCoordinator.beginWipe(documentsRoot);
    } catch (error) {
      failures.add('Chat 跨 isolate 生产者收口失败：$error');
    }
    final processOperations = _processOperations.toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final operation in processOperations)
        _captureCleanupFailure(
          '等待 Chat 后台进程操作',
          () => operation,
          failures,
        ),
      for (final instance in instances)
        _closeInstanceForWipe(instance, failures),
    ]);

    // 任一运行态关闭失败时不得先删文件树；否则旧上下文可能续写并复活目录。
    if (failures.isEmpty && documentsRoot != null) {
      try {
        if (documentsRoot.path == documentsRoot.parent.path) {
          throw StateError('Chat 文档根目录不能是文件系统根目录');
        }
        final chatRoot = Directory(
          '${documentsRoot.path}${Platform.pathSeparator}chat',
        ).absolute;
        if (chatRoot.parent.path != documentsRoot.path) {
          throw StateError('Chat 擦除目录越过文档根目录');
        }
        final chatRootType = await FileSystemEntity.type(
          chatRoot.path,
          followLinks: false,
        );
        if (chatRootType == FileSystemEntityType.link) {
          // 目录位被符号链接占用时只删除链接本身，禁止跟随到文档根目录之外。
          await Link(chatRoot.path).delete();
        } else if (chatRootType != FileSystemEntityType.notFound) {
          await chatRoot.delete(recursive: true);
        }
      } catch (error) {
        failures.add('删除 Chat 文件树失败：$error');
      }
    }

    if (failures.isNotEmpty) {
      throw StateError(failures.join('\n'));
    }
  }

  static Future<void> _captureCleanupFailure(
    String label,
    Future<void> Function() action,
    List<String> failures,
  ) async {
    try {
      await action();
    } catch (error) {
      failures.add('$label：$error');
    }
  }

  static Future<void> _closeInstanceForWipe(
    ChatRuntime instance,
    List<String> failures,
  ) async {
    try {
      await instance._closeForWipe();
      _instancesPendingClose.remove(instance);
    } catch (error) {
      // 保持强引用，下一次 AppLock 擦除必须继续关闭同一个失败实例。
      _instancesPendingClose.add(instance);
      failures.add('关闭 ChatRuntime：$error');
    }
  }

  @visibleForTesting
  static int get debugPendingCloseInstanceCount =>
      _instancesPendingClose.length;

  @visibleForTesting
  static int get debugLiveInstanceCount {
    _liveInstances.removeWhere((reference) => reference.target == null);
    return _liveInstances
        .map((reference) => reference.target)
        .whereType<ChatRuntime>()
        .toSet()
        .union(_instancesPendingClose)
        .length;
  }

  /// Flutter 测试在同一进程内运行多条用例，只能显式模拟“进程重启”。旧 runtime
  /// 实例仍保持终态，重置后只允许新实例参与下一条测试。
  @visibleForTesting
  static Future<void> debugResetProcessWipeForTest({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许重置 ChatRuntime 擦除终态');
    }
    final running = _localFileWipeInFlight;
    if (running != null) {
      try {
        await running;
      } catch (_) {
        // 上一用例已经断言错误；这里只模拟新进程，不吞生产路径错误。
      }
    }
    _localFileWipeInFlight = null;
    _liveInstances.clear();
    _instancesPendingClose.clear();
    _processWipeRequested = false;
    final provider = documentsDirectoryProvider;
    if (provider != null) {
      await _ChatCrossIsolateCoordinator.resetForTest(provider);
    }
  }

  static void _ensureProcessActive() {
    if (_processWipeRequested) {
      throw StateError('ChatRuntime 已进入本机数据擦除终态，进程重启前禁止恢复。');
    }
  }

  /// 当前 isolate 仍在首次 await 前登记本地 token；真正的 FlutterFire
  /// 后台 isolate 则额外通过 Documents lease 与 AppLock marker 跨 isolate 互斥。
  static Future<T> _runProcessOperation<T>(
    Future<T> Function() operation, {
    Future<Directory> Function()? documentsDirectoryProvider,
  }) {
    try {
      _ensureProcessActive();
    } catch (error, stackTrace) {
      return Future<T>.error(error, stackTrace);
    }

    final drained = Completer<void>();
    final token = drained.future;
    _processOperations.add(token);

    void release() {
      _processOperations.remove(token);
      if (!drained.isCompleted) drained.complete();
    }

    late final Future<T> running;
    try {
      running = _runCrossIsolateBackgroundOperation(
        operation,
        documentsDirectoryProvider:
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
        checkLocalTerminal: true,
      );
    } catch (error, stackTrace) {
      release();
      return Future<T>.error(error, stackTrace);
    }
    return running.whenComplete(release);
  }

  static Future<T> _runCrossIsolateBackgroundOperation<T>(
    Future<T> Function() operation, {
    required Future<Directory> Function() documentsDirectoryProvider,
    required bool checkLocalTerminal,
  }) async {
    final root = await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
      documentsDirectoryProvider,
    );
    final lease =
        await _ChatCrossIsolateCoordinator.acquireBackgroundLease(root);
    if (checkLocalTerminal) _ensureProcessActive();
    // operation 必须把业务错误内部收敛，只在所有 runtime/push 清理成功
    // 后返回。任何 cleanup 异常均故意保留 lease，禁止 wipe 误报成功。
    final result = await operation();
    await lease.release();
    return result;
  }

  /// 用同一 isolate 模拟 FlutterFire 独立 isolate，故敏感地绕过本 isolate
  /// 的静态终态，只依赖 marker + lease 协议。
  @visibleForTesting
  static Future<T> debugRunBackgroundLeaseForTest<T>(
    Future<T> Function() operation, {
    required Future<Directory> Function() documentsDirectoryProvider,
  }) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<T>.error(
        UnsupportedError('仅 Flutter 测试允许模拟 Chat 后台 isolate'),
      );
    }
    return _runCrossIsolateBackgroundOperation(
      operation,
      documentsDirectoryProvider: documentsDirectoryProvider,
      checkLocalTerminal: false,
    );
  }

  static T _initializeWhileProcessActive<T>(T Function() factory) {
    _ensureProcessActive();
    return factory();
  }

  void _ensureActive() {
    _ensureProcessActive();
    if (_closedForWipe) {
      throw StateError('ChatRuntime 已关闭，禁止重新建立聊天运行态。');
    }
  }

  /// 网络回调和不直接改文件的 Chat 操作同样属于擦除前生产者；平台存储最终清理前
  /// 必须等它们收口，防止 ready/push 操作在 clear 之后重新写入偏好值。
  Future<T> _runRuntimeOperation<T>(Future<T> Function() operation) {
    try {
      _ensureActive();
    } catch (error, stackTrace) {
      return Future<T>.error(error, stackTrace);
    }

    final drained = Completer<void>();
    final token = drained.future;
    _runtimeOperations.add(token);

    void release() {
      _runtimeOperations.remove(token);
      if (!drained.isCompleted) drained.complete();
    }

    late final Future<T> running;
    try {
      running = operation();
    } catch (error, stackTrace) {
      release();
      return Future<T>.error(error, stackTrace);
    }
    return running.whenComplete(release);
  }

  Future<void> _closeForWipe() async {
    _closedForWipe = true;
    final accountIds = <String>{
      ..._accountGenerations.keys,
      ..._accountContextKeys.keys,
    };
    for (final accountId in accountIds) {
      _accountGenerations[accountId] =
          (_accountGenerations[accountId] ?? 0) + 1;
    }

    final realtimeHubs = _realtimeHubs.values.toList(growable: false);
    for (final hub in realtimeHubs) {
      try {
        await _closeRealtimeHub(hub);
      } catch (_) {
        // 物理 session 仍在下方统一快照中，终态清理会再次收口并报告失败。
      }
    }

    final flights = <Future<_ChatAccountContext>>{
      ..._readyFlights.values,
      ..._readyFlightsPendingInvalidation,
    }.toList(growable: false);
    final initialContexts = <_ChatAccountContext>{
      ..._readyContexts.values,
      ..._contextsPendingDisposal,
    };
    final realtimeSessions = _realtimeSessions.toList(growable: false);
    _readyContexts.clear();
    _readyFlights.clear();
    _accountContextKeys.clear();
    _mediaBytesInFlight.clear();
    _mailboxEnvelopeReceipts.clear();
    _incomingConvergenceInFlight.clear();

    final failures = <String>[];
    // 第一阶段只停止所有实时生产源。session 会同步拒绝新 callback，关闭
    // socket/subscription，并等待已经登记的 callback；此时绝不 dispose crypto。
    await Future.wait<void>(<Future<void>>[
      for (final session in realtimeSessions)
        _captureCleanupFailure(
          '关闭 Chat 实时会话',
          () => _disposeRealtimeSession(session),
          failures,
        ),
    ]);

    // 第二阶段等待所有已登记 action/build 收口。终态已经同步置位，session 也已
    // 拒绝新 callback，所以这份快照之后不会再合法产生新的业务生产者。
    final fileMutations = _fileMutations.toList(growable: false);
    final runtimeOperations = _runtimeOperations.toList(growable: false);
    final earlierDisposals = _contextDisposals.toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final mutation in fileMutations)
        _captureCleanupFailure(
          '等待 Chat 文件改写',
          () => mutation,
          failures,
        ),
      for (final operation in runtimeOperations)
        _captureCleanupFailure(
          '等待 Chat 运行操作',
          () => operation,
          failures,
        ),
      for (final flight in flights)
        _captureCleanupFailure(
          '失效 Chat 初始化任务',
          () => _settleReadyFlightForWipe(flight),
          failures,
        ),
      for (final disposal in earlierDisposals)
        _captureCleanupFailure(
          '等待此前 Chat 上下文关闭',
          () => disposal,
          failures,
        ),
    ]);

    // 第三阶段才关闭 context：此时没有 action 会继续使用 NativeMlsCrypto、
    // state key 或 WebRTC。flight 晚到 context 与此前失败的 pending 一并重试。
    final contexts = <_ChatAccountContext>{
      ...initialContexts,
      ..._contextsPendingDisposal,
    }.toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final context in contexts)
        _captureCleanupFailure(
          '关闭 Chat 上下文',
          () => _disposeContext(context),
          failures,
        ),
      if (_debugContextDisposerForTest != null)
        _captureCleanupFailure(
          '关闭 Chat 测试上下文',
          _debugContextDisposerForTest!.dispose,
          failures,
        ),
    ]);
    if (failures.isNotEmpty) {
      throw StateError(failures.join('\n'));
    }
  }

  Future<void> _settleReadyFlightForWipe(
    Future<_ChatAccountContext> flight,
  ) async {
    try {
      final context = await flight;
      await _disposeContext(context);
    } catch (_) {
      // 初始化自身失败时没有可复用上下文；若失败发生在 dispose，context 会留在
      // _contextsPendingDisposal，并由调用方的第二轮快照显式重试和验真。
    }
  }

  Future<void> _disposeContext(_ChatAccountContext context) {
    _contextsPendingDisposal.add(context);
    final disposal = context.dispose();
    _contextDisposals.add(disposal);
    disposal.then<void>(
      (_) {
        _contextDisposals.remove(disposal);
        _contextsPendingDisposal.remove(context);
      },
      onError: (Object _, StackTrace __) {
        _contextDisposals.remove(disposal);
      },
    );
    return disposal;
  }

  Future<void> _disposeRealtimeSession(_ChatRealtimeSession session) async {
    await session.dispose();
    _realtimeSessions.remove(session);
  }

  /// 文件改写在调用者拿到 Future 前就登记，与 AppLock 终态之间不留窗口。
  ///
  /// 已登记的改写可以收口，擦除会等它们结束后才删除 `Documents/chat`；
  /// 终态置位后的新改写直接返回失败 Future，禁止复活目录。
  Future<T> _runFileMutation<T>(Future<T> Function() operation) {
    try {
      _ensureActive();
    } catch (error, stackTrace) {
      return Future<T>.error(error, stackTrace);
    }

    final drained = Completer<void>();
    final token = drained.future;
    _fileMutations.add(token);

    void release() {
      _fileMutations.remove(token);
      if (!drained.isCompleted) drained.complete();
    }

    late final Future<T> running;
    try {
      running = operation();
    } catch (error, stackTrace) {
      release();
      return Future<T>.error(error, stackTrace);
    }
    return running.whenComplete(release);
  }

  Future<T> _runBindingFileMutation<T>(
    ChatBindingFenceToken bindingToken,
    Future<T> Function() operation,
  ) {
    return _runFileMutation(
      () => _runCidMutation(
        cidNumber: bindingToken.ownerCidNumber,
        bindingToken: bindingToken,
        operation: operation,
      ),
    );
  }

  Future<T> _runCidFileMutation<T>({
    required String cidNumber,
    required Future<T> Function() operation,
    ChatBindingFenceToken? bindingToken,
    bool validateTokenAfter = true,
  }) {
    return _runFileMutation(
      () => _runCidMutation(
        cidNumber: cidNumber,
        bindingToken: bindingToken,
        validateTokenAfter: validateTokenAfter,
        operation: operation,
      ),
    );
  }

  Future<T> _runCidMutation<T>({
    required String cidNumber,
    required Future<T> Function() operation,
    ChatBindingFenceToken? bindingToken,
    bool validateTokenAfter = true,
  }) {
    final existing = Zone.current[_cidMutationZoneKey];
    if (existing is _ChatCidLeaseScope &&
        existing.isActive &&
        existing.cidNumber == cidNumber) {
      final outerToken = existing.bindingToken;
      final sameNullability = (outerToken == null) == (bindingToken == null);
      if (!sameNullability ||
          (outerToken != null &&
              !_sameBindingToken(outerToken, bindingToken!))) {
        return Future<T>.error(
          StateError('同一 CID 的嵌套文件操作必须复用完全相同的 binding token'),
        );
      }
      try {
        return existing.track(operation());
      } catch (error, stackTrace) {
        return Future<T>.error(error, stackTrace);
      }
    }
    return _cidMutationGate.run(cidNumber, () async {
      final documentsRoot =
          await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
        _documentsDirectoryProvider,
      );
      final lease = await _ChatCrossIsolateCoordinator.acquireCidMutationLease(
        documentsRoot,
        // 文件目录本身按 safe path 分区；跨 isolate lease 必须使用同一物理分区键，
        // 否则启动静态清扫无法从目录名恢复原 CID，也无法与运行态互斥。
        _safePath(cidNumber),
      );
      final scope = _ChatCidLeaseScope(cidNumber, bindingToken);
      try {
        if (bindingToken != null) {
          await _store.validateBindingFenceToken(bindingToken);
        }
        final result = await runZoned<Future<T>>(
          operation,
          zoneValues: <Object, Object>{
            _cidMutationZoneKey: scope,
          },
        );
        // 保持 fast path 到已登记 nested action 全部完成，避免 nested callback 后半段
        // 再进入同 CID wrapper 时排到 outer 后面自锁；集合排空后的同步 continuation
        // 立即封口，后来才触发的旧 Zone 回调会重新取得正式 lease。
        await scope.drain();
        scope.stopAccepting();
        if (bindingToken != null && validateTokenAfter) {
          await _store.validateBindingFenceToken(bindingToken);
        }
        await lease.validateHealthy();
        return result;
      } finally {
        // 异步回调会继承注册时 Zone；先让 scope 失效，避免 lease 释放后长寿命
        // 回调继续命中嵌套 fast path 而永久绕过下一次跨 isolate 协调。
        scope.stopAccepting();
        // 释放失败必须上抛；遗留 lease 由下一进程启动 preflight 恢复。
        await lease.release();
      }
    });
  }

  static bool _sameBindingToken(
    ChatBindingFenceToken left,
    ChatBindingFenceToken right,
  ) =>
      left.ownerCidNumber == right.ownerCidNumber &&
      left.bindingRevision == right.bindingRevision &&
      left.accountId == right.accountId &&
      left.genesisHash == right.genesisHash &&
      left.generation == right.generation;

  Future<ChatBindingFenceToken> _convergeBindingFence(
    _ChatAccount account,
  ) {
    return _runCidFileMutation(
      cidNumber: account.cidNumber,
      operation: () async {
        final token = await _store.convergeFinalizedBinding(
          _bindingForAccount(account),
        );
        await _store.validateBindingFenceToken(token);
        return token;
      },
    );
  }

  Future<T> _runWithReadyBinding<T>(
    Future<T> Function(_ChatAccountContext context) operation,
  ) async {
    final context = await _readyContext(await _readAccount());
    return _runBindingFileMutation(
      context.bindingToken,
      () => operation(context),
    );
  }

  /// 发送只要求账户上下文在动作期间保持存活；MLS 与附件文件改写已经在各自
  /// 边界取得 CID lease。网络投递绝不能再被外层文件锁包住。
  Future<T> _runWithReadyContext<T>(
    Future<T> Function(_ChatAccountContext context) operation,
  ) {
    return _runRuntimeOperation(() async {
      final context = await _readyContext(await _readAccount());
      return operation(context);
    });
  }

  /// 已可靠落盘的密文按“当前绑定 + 会话”保序后台投递。页面和 CID 文件锁
  /// 均不等待网络；失败时本地出站队列继续保留，交由既有重试链路收敛。
  void _scheduleOutboundDelivery(
    _ChatAccountContext context,
    String conversationId,
    Future<void> Function() delivery,
  ) {
    final key = '${context.bindingToken.accountId}|$conversationId';
    unawaited(
      _runRuntimeOperation(
        () => _outboundDeliveryGate.run(key, delivery),
      ).catchError((Object _) {
        // 静默后台投递失败不覆盖本地消息；队列事实仍在，下次重试继续发送。
      }),
    );
  }

  /// 仅用于验证 AppLock 与已在途文件改写的时序，生产代码不得调用。
  @visibleForTesting
  Future<T> debugRunFileMutationForTest<T>(Future<T> Function() operation) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<T>.error(
        UnsupportedError('仅 Flutter 测试允许注入 Chat 文件改写'),
      );
    }
    return _runFileMutation(operation);
  }

  /// 验证终态会拒绝新的实时回调，仅用于 Flutter 测试。
  @visibleForTesting
  Future<T> debugRunRuntimeOperationForTest<T>(
    Future<T> Function() operation,
  ) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<T>.error(
        UnsupportedError('仅 Flutter 测试允许注入 Chat 运行回调'),
      );
    }
    return _runRuntimeOperation(operation);
  }

  /// 模拟后台 handler 在释放 lease 前对已触发回调执行实例级 drain。
  @visibleForTesting
  Future<void> debugDrainBackgroundRuntimeForTest() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<void>.error(
        UnsupportedError('仅 Flutter 测试允许收口 Chat 后台运行态'),
      );
    }
    return _closeForWipe();
  }

  /// 注入一组完整实时资源，验证 socket 与两个订阅的可重试关闭。
  @visibleForTesting
  Future<void> Function() debugRegisterRealtimeSessionForTest({
    required Future<void> Function() stopSocket,
    required Future<void> Function() cancelWakeSubscription,
    required Future<void> Function() cancelTokenSubscription,
  }) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许注入 Chat 实时资源');
    }
    _ensureActive();
    final session = _ChatRealtimeSession()
      ..attachSocket(stopSocket)
      ..attachWakeSubscription(cancelWakeSubscription)
      ..attachTokenSubscription(cancelTokenSubscription)
      ..markInitializationDone();
    _realtimeSessions.add(session);
    return () => _disposeRealtimeSession(session);
  }

  /// 把可控关闭操作注入真实 runtime 擦除链，仅用于验证失败后重试。
  @visibleForTesting
  void debugRegisterContextDisposerForTest(
    Future<void> Function() operation,
  ) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许注入 Chat 上下文关闭操作');
    }
    _ensureActive();
    if (_debugContextDisposerForTest != null) {
      throw StateError('Chat 测试上下文关闭操作已注入');
    }
    _debugContextDisposerForTest = _RetryableAsyncDisposer(operation);
  }

  /// 注入一个尚未完成的 ready flight，验证账户失效后 AppLock 仍能追踪它。
  @visibleForTesting
  void debugRegisterReadyFlightForTest(
    String accountId,
    Future<void> operation,
  ) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许注入 Chat 初始化任务');
    }
    _ensureActive();
    final key = 'debug-ready-flight|$accountId';
    if (_readyFlights.containsKey(key)) {
      throw StateError('Chat 测试初始化任务已注入');
    }
    _readyFlights[key] = operation.then<_ChatAccountContext>(
      (_) => throw StateError('Chat 测试初始化任务不生成真实上下文'),
    );
  }

  Future<SharedPreferences> get _prefs async {
    _ensureActive();
    final provided = _preferences;
    if (provided != null) {
      return provided;
    }
    return SharedPreferences.getInstance();
  }

  Future<ChatInboxOverview> readOverview({
    String? cidNumber,
    required int pendingOutgoing,
    required int unreadCount,
  }) async {
    _ensureActive();
    final resolvedCidNumber = cidNumber ?? await readCidNumber();
    return ChatInboxOverview(
      cidNumber: resolvedCidNumber,
      pendingOutgoing: pendingOutgoing,
      unreadCount: unreadCount,
    );
  }

  /// 页面成功展示当前会话后，经 finalized 绑定门禁清零当前设备的本地未读数。
  Future<void> markConversationRead({
    required String conversationId,
    required int readThroughMillis,
  }) {
    return _runWithReadyBinding((context) async {
      final cleared = await _store.markConversationRead(
        bindingToken: context.bindingToken,
        ownerCidNumber: context.account.cidNumber,
        conversationId: conversationId,
        readThroughMillis: readThroughMillis,
      );
      // 本机未读真源已经原子清零后，再按同一 conversation_id 清理系统通知。
      // 原生通知清理失败不能撤销已读事实，也不能误清其它会话或广场通知。
      if (cleared) {
        await _pushService
            .clearConversationNotifications(conversationId)
            .catchError((Object _) {});
      }
    });
  }

  Future<String?> readAccountId() async {
    _ensureActive();
    return _currentUser.accountId();
  }

  Future<String?> readCidNumber() async {
    final cidNumber = (await readCurrentUser()).cidNumber;
    return cidNumber.isEmpty ? null : cidNumber;
  }

  /// 解析普通 Chat 当前用户：优先本机逐账户绑定；本机首次无缓存时用 Cloudflare
  /// 登录挑战恢复。Worker 明确返回未绑定时保留当前默认账户并返回空 CID，绝不扫描
  /// 其它账户；网络故障继续上抛，不能伪装成未注册。
  Future<({String accountId, String cidNumber})> readCurrentUser() {
    return _runRuntimeOperation(_readCurrentUser);
  }

  Future<({String accountId, String cidNumber})> _readCurrentUser() async {
    _ensureActive();
    final current = await _currentUser.resolve();
    if (current == null) return (accountId: '', cidNumber: '');
    if (current.isRegistered) {
      return (accountId: current.accountId, cidNumber: current.cidNumber);
    }
    try {
      final account = await _readAccount();
      return (accountId: account.accountId, cidNumber: account.cidNumber);
    } on SquareApiException catch (error) {
      if (error.errorCode == 'cid_not_bound') {
        return (accountId: current.accountId, cidNumber: '');
      }
      rethrow;
    }
  }

  /// 已捕获 binding token 对应账户派生的附件本地静止态密钥。
  Future<List<int>> _attachmentKeyForBinding(
    ChatBindingFenceToken bindingToken,
  ) async {
    if (bindingToken.accountId.isEmpty) {
      throw StateError('无身份账户，无法读取附件加密密钥');
    }
    return (await _walletManager.readDataKeysForBinding(
      AccountDataBinding(
        genesisHash: bindingToken.genesisHash,
        cidNumber: bindingToken.ownerCidNumber,
        bindingRevision: bindingToken.bindingRevision,
        accountId: bindingToken.accountId,
      ),
      const <({LocalKeyPurpose purpose, String? context})>[
        (purpose: LocalKeyPurpose.attachment, context: null),
      ],
    ))
        .single;
  }

  /// 短命明文目录：解密出来的附件只落这里，与密文缓存物理分开。
  Future<Directory> _plainDirectoryForBinding(
    ChatBindingFenceToken bindingToken,
  ) async {
    final attachmentDirectory = await _attachmentDirectoryForToken(
      bindingToken,
    );
    return Directory(
      '${attachmentDirectory.path}/${AttachmentVault.plainDirName}',
    );
  }

  /// 附件密文缓存以 CID 为属主，并按 finalized 绑定版本与账户隔离加密上下文。
  Future<Directory> _attachmentDirectoryForToken(
    ChatBindingFenceToken bindingToken,
  ) {
    return _attachmentDirectoryForBinding(
      cidNumber: bindingToken.ownerCidNumber,
      bindingRevision: bindingToken.bindingRevision,
      accountId: bindingToken.accountId,
    );
  }

  Future<Directory> _attachmentDirectoryForBinding({
    required String cidNumber,
    required int bindingRevision,
    required String accountId,
  }) async {
    final bindingDirectory = await _bindingDirectory(
      cidNumber: cidNumber,
      bindingRevision: bindingRevision,
      accountId: accountId,
    );
    return Directory('${bindingDirectory.path}/attachments');
  }

  /// 清空短命明文附件。
  ///
  /// 明文按「**只在前台存活**」管理：App 启动、退到后台、删会话/退出账户三处
  /// 各 purge 一次。不做逐处所有权交接——UI 侧预览/播放/打开/转发路径太多，
  /// 漏一处这份明文就永久留在盘上。
  Future<void> purgePlainAttachments() async {
    final account = await _readAccount();
    final bindingToken = await _convergeBindingFence(account);
    return _runBindingFileMutation(
      bindingToken,
      () async => AttachmentVault.purgePlainDirectory(
        await _plainDirectoryForBinding(bindingToken),
      ),
    );
  }

  /// 在 CID 钱包换绑签名前预演全部 Chat 私有数据交接。
  ///
  /// 聊天正文暂存在 Isar 的目标密文清单；附件逐块重加密；MLS 状态由 Rust 原生
  /// 加密边界重封。三者都保留正式的此前密文，且不会生成任何明文文件。
  Future<void> stageAccountHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) async {
    _validateHandover(source, target);
    await _invalidateAccountContext(source.accountId);
    await _invalidateAccountContext(target.accountId);
    ChatBindingFenceToken sourceToken;
    try {
      sourceToken = await _store.captureBindingFenceToken(source);
    } on StateError {
      // stage 返回前崩溃会留下 pending 但没有文件完成收据；明确重试必须复用
      // 同一 source/target generation 的 handover 专属能力。
      sourceToken = await _store.captureStagedAccountHandoverFenceToken(
        source: source,
        target: target,
      );
    }
    return _runCidFileMutation(
      cidNumber: source.cidNumber,
      operation: () async {
        await _stageAccountHandover(source: source, target: target);
        await _store.validateStagedAccountHandoverFence(
          source: source,
          target: target,
          sourceToken: sourceToken,
        );
      },
    );
  }

  Future<void> _stageAccountHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) async {
    _ensureActive();
    _validateHandover(source, target);
    List<Uint8List>? sourceKeys;
    List<Uint8List>? targetKeys;
    try {
      sourceKeys = await _walletManager.deriveDataKeysForBindingHandover(
        source,
        const <({LocalKeyPurpose purpose, String? context})>[
          (purpose: LocalKeyPurpose.attachment, context: null),
          (purpose: LocalKeyPurpose.mls, context: null),
        ],
      );
      targetKeys = await _walletManager.deriveDataKeysForBindingHandover(
        target,
        const <({LocalKeyPurpose purpose, String? context})>[
          (purpose: LocalKeyPurpose.attachment, context: null),
          (purpose: LocalKeyPurpose.mls, context: null),
        ],
      );
      if (sourceKeys.length != 2 || targetKeys.length != 2) {
        throw StateError('Chat 文件交接用途密钥数量不完整');
      }
      _ensureActive();
      await _store.stageAccountHandover(source: source, target: target);
      final sourceDirectory = await _bindingDirectory(
        cidNumber: source.cidNumber,
        bindingRevision: source.bindingRevision,
        accountId: source.accountId,
      );
      final targetDirectory = await _bindingDirectory(
        cidNumber: target.cidNumber,
        bindingRevision: target.bindingRevision,
        accountId: target.accountId,
      );
      final sourceExists = await sourceDirectory.exists();
      final targetExists = await targetDirectory.exists();
      if (sourceExists && targetExists) {
        throw StateError('Chat 新旧绑定目录同时存在，禁止重试 stage');
      }
      final existingReceipt = await _locateFileHandoverReceipt(
        sourceDirectory: sourceDirectory,
        targetDirectory: targetDirectory,
        target: target,
      );
      if (existingReceipt != null) {
        final receipt = await _readFileHandoverReceipt(
          marker: existingReceipt,
          source: source,
          target: target,
          macKey: targetKeys[1],
        );
        if (receipt.state == _ChatFileHandoverState.committing) {
          throw StateError('Chat 文件交接已经进入 committing，只能重试 commit');
        }
        if (!sourceExists ||
            targetExists ||
            existingReceipt.parent.path != sourceDirectory.path) {
          throw StateError('Chat staged 文件 receipt 不在来源 binding 目录');
        }
        // 模糊重试只能认证并复核此前完成快照，绝不再次运行文件重封、覆盖 receipt
        // 或把 committing 状态降回 staged。
        await _requireStagedFileHandoverSnapshot(
          sourceDirectory: sourceDirectory,
          source: source,
          target: target,
          receipt: receipt,
        );
        return;
      }
      if (targetExists) {
        throw StateError('Chat 目标 binding 目录已存在但缺少 committing receipt');
      }
      final attachmentDirectory = await _attachmentDirectoryForBinding(
        cidNumber: source.cidNumber,
        bindingRevision: source.bindingRevision,
        accountId: source.accountId,
      );
      // Store pending 已经形成跨实例阻断；写完成收据前严格清除全部明文与 `.part`。
      await AttachmentVault.purgeTransientDirectoriesForHandover(
        attachmentDirectory,
      );
      await AttachmentVault.stageAccountHandover(
        attachmentDirectory: attachmentDirectory,
        handoverId: _handoverId(target),
        currentKey: sourceKeys[0],
        newKey: targetKeys[0],
      );
      final mlsDirs = await _mlsDeviceDirectories(source);
      final bindings = mlsDirs.isEmpty ? null : MlsNativeBindings.load();
      for (final deviceDir in mlsDirs) {
        await _stageMlsDeviceHandover(
          deviceDirectory: deviceDir,
          ownerCidNumber: source.cidNumber,
          sourceStateKey: sourceKeys[1],
          targetStateKey: targetKeys[1],
          bindings: bindings!,
        );
      }
      await AttachmentVault.requireNoTransientDirectoriesForHandover(
        attachmentDirectory,
      );
      await _writeFileHandoverReceipt(
        sourceDirectory: sourceDirectory,
        source: source,
        target: target,
        mlsDeviceDirectories: mlsDirs,
        macKey: targetKeys[1],
        state: _ChatFileHandoverState.staged,
      );
    } finally {
      for (final key in <Uint8List>[
        ...?sourceKeys,
        ...?targetKeys,
      ]) {
        key.fillRange(0, key.length, 0);
      }
    }
  }

  /// MLS 换绑的两份短命钥只存活于单个设备预演，native、Dart 成功
  /// 或任意一边失败都显式清零；[MlsStateStore.dispose] 是 source 副本的唯一终态。
  static Future<void> _stageMlsDeviceHandover({
    required Directory deviceDirectory,
    required String ownerCidNumber,
    required Uint8List sourceStateKey,
    required Uint8List targetStateKey,
    MlsNativeBindings? bindings,
    void Function(Uint8List sourceCopy, Uint8List targetCopy)?
        debugRunNativeRekey,
    Future<void> Function(MlsStateStore store, Uint8List targetCopy)?
        debugStagePending,
  }) async {
    final sourceCopy = Uint8List.fromList(sourceStateKey);
    final targetCopy = Uint8List.fromList(targetStateKey);
    final store = MlsStateStore(
      deviceDirectory,
      ownerCidNumber: ownerCidNumber,
      stateKey: sourceCopy,
    );
    try {
      final runNative = debugRunNativeRekey;
      if (runNative != null) {
        runNative(sourceCopy, targetCopy);
      } else {
        (bindings ?? MlsNativeBindings.load()).runStateRekey(
          stateStoreDir: deviceDirectory.path,
          action: 'stage',
          currentStateKeyHex: _hexKey(sourceCopy),
          newStateKeyHex: _hexKey(targetCopy),
        );
      }
      final stagePending = debugStagePending;
      if (stagePending != null) {
        await stagePending(store, targetCopy);
      } else {
        await store.stageAccountHandover(targetCopy);
      }
    } finally {
      store.dispose();
      targetCopy.fillRange(0, targetCopy.length, 0);
    }
  }

  /// 只验证临时 MLS 钥副本的生命周期，不调用 native 也不写真实状态。
  @visibleForTesting
  static Future<void> debugStageMlsDeviceHandoverForTest({
    required Directory deviceDirectory,
    required String ownerCidNumber,
    required Uint8List sourceStateKey,
    required Uint8List targetStateKey,
    required void Function(Uint8List sourceCopy, Uint8List targetCopy)
        runNativeRekey,
    required Future<void> Function(
      MlsStateStore store,
      Uint8List targetCopy,
    ) stagePending,
  }) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<void>.error(
        UnsupportedError('仅 Flutter 测试允许注入 MLS 换绑阶段'),
      );
    }
    return _stageMlsDeviceHandover(
      deviceDirectory: deviceDirectory,
      ownerCidNumber: ownerCidNumber,
      sourceStateKey: sourceStateKey,
      targetStateKey: targetStateKey,
      debugRunNativeRekey: runNativeRekey,
      debugStagePending: stagePending,
    );
  }

  /// finalized 后提交全部 Chat 目标密文；每个子步骤均可幂等重试。
  Future<void> commitAccountHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) async {
    _validateHandover(source, target);
    await _invalidateAccountContext(source.accountId);
    await _invalidateAccountContext(target.accountId);
    ChatBindingFenceToken fenceToken;
    var alreadyCompleted = false;
    try {
      fenceToken = await _store.captureStagedAccountHandoverFenceToken(
        source: source,
        target: target,
      );
    } on StateError {
      // 崩溃可能发生在 Store 已推进 target fence、调用者尚未收到成功之后。
      // 只有精确 target token 能进入幂等复核，任意其它状态仍会直接失败。
      fenceToken = await _store.captureCompletedAccountHandoverFenceToken(
        source: source,
        target: target,
      );
      alreadyCompleted = true;
    }
    return _runCidFileMutation(
      cidNumber: source.cidNumber,
      operation: () async {
        if (alreadyCompleted) {
          await _store.validateCompletedAccountHandoverFence(
            source: source,
            target: target,
            targetToken: fenceToken,
          );
        } else {
          await _store.validateStagedAccountHandoverFence(
            source: source,
            target: target,
            sourceToken: fenceToken,
          );
        }
        await _commitAccountHandover(
          source: source,
          target: target,
          alreadyCompleted: alreadyCompleted,
        );
      },
    );
  }

  Future<void> _commitAccountHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
    required bool alreadyCompleted,
  }) async {
    _ensureActive();
    _validateHandover(source, target);
    final sourceDirectory = await _bindingDirectory(
      cidNumber: source.cidNumber,
      bindingRevision: source.bindingRevision,
      accountId: source.accountId,
    );
    final targetDirectory = await _bindingDirectory(
      cidNumber: target.cidNumber,
      bindingRevision: target.bindingRevision,
      accountId: target.accountId,
    );
    List<Uint8List>? targetKeys;
    try {
      targetKeys = await _walletManager.deriveDataKeysForBindingHandover(
        target,
        const <({LocalKeyPurpose purpose, String? context})>[
          (purpose: LocalKeyPurpose.mls, context: null),
        ],
      );
      if (targetKeys.length != 1) {
        throw StateError('Chat 文件交接认证密钥数量不完整');
      }
      final sourceExists = await sourceDirectory.exists();
      final targetExists = await targetDirectory.exists();
      if (sourceExists && targetExists) {
        throw StateError('Chat 新旧绑定目录同时存在，禁止猜测覆盖');
      }
      final marker = await _locateFileHandoverReceipt(
        sourceDirectory: sourceDirectory,
        targetDirectory: targetDirectory,
        target: target,
      );
      if (marker == null && !alreadyCompleted) {
        throw StateError('Chat 文件域缺少认证 stage-complete receipt，禁止提交');
      }
      if (marker != null) {
        final receipt = await _readFileHandoverReceipt(
          marker: marker,
          source: source,
          target: target,
          macKey: targetKeys.single,
        );
        if (receipt.state == _ChatFileHandoverState.staged) {
          if (marker.parent.path != sourceDirectory.path || !sourceExists) {
            throw StateError('Chat staged 文件 receipt 不在来源 binding 目录');
          }
          await _requireStagedFileHandoverSnapshot(
            sourceDirectory: sourceDirectory,
            source: source,
            target: target,
            receipt: receipt,
          );
          await _writeFileHandoverReceiptFromSnapshot(
            directory: sourceDirectory,
            source: source,
            target: target,
            receipt: receipt,
            macKey: targetKeys.single,
            state: _ChatFileHandoverState.committing,
          );
        }
        final activeDirectory =
            sourceExists ? sourceDirectory : targetDirectory;
        await AttachmentVault.requireNoTransientDirectoriesForHandover(
          Directory('${activeDirectory.path}/attachments'),
        );
      }
      if (sourceExists) {
        await AttachmentVault.commitAccountHandover(
          attachmentDirectory: Directory(
            '${sourceDirectory.path}/attachments',
          ),
          handoverId: _handoverId(target),
        );
        final mlsDirs = await _mlsDeviceDirectories(source);
        final bindings = mlsDirs.isEmpty ? null : MlsNativeBindings.load();
        for (final deviceDir in mlsDirs) {
          bindings!.runStateRekey(
            stateStoreDir: deviceDir.path,
            action: 'commit',
          );
          await MlsStateStore.commitAccountHandoverFiles(deviceDir);
        }
        await _moveBindingDirectory(source, target);
      }
      // 文件域先完整切到 target，最后一个 Store 事务才迁移全部密文、删除 manifest
      // 并推进 fence generation。此前任何失败都保留 committing receipt 供明确重试。
      await _store.commitAccountHandover(source: source, target: target);
      final targetToken = await _store.captureBindingFenceToken(target);
      await _store.validateBindingFenceToken(targetToken);
      await _deleteFileHandoverReceipt(
        directory: targetDirectory,
        target: target,
      );
      await _deleteFileHandoverReceipt(
        directory: sourceDirectory,
        target: target,
      );
      _blockedAccountIds.remove(target.accountId);
    } finally {
      for (final key in targetKeys ?? const <Uint8List>[]) {
        key.fillRange(0, key.length, 0);
      }
    }
  }

  Future<void> discardAccountHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) async {
    _validateHandover(source, target);
    await _invalidateAccountContext(source.accountId);
    await _invalidateAccountContext(target.accountId);
    ChatBindingFenceToken sourceToken;
    var alreadyDiscarded = false;
    try {
      sourceToken = await _store.captureStagedAccountHandoverFenceToken(
        source: source,
        target: target,
      );
    } on StateError {
      sourceToken = await _store.captureBindingFenceToken(source);
      alreadyDiscarded = true;
    }
    return _runCidFileMutation(
      cidNumber: source.cidNumber,
      operation: () async {
        if (!alreadyDiscarded) {
          await _store.validateStagedAccountHandoverFence(
            source: source,
            target: target,
            sourceToken: sourceToken,
          );
        } else {
          // 重复 discard 只允许 source 已恢复为普通 active/no-pending。
          await _store.validateBindingFenceToken(sourceToken);
        }
        await _discardAccountHandover(source: source, target: target);
      },
    );
  }

  Future<void> _discardAccountHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) async {
    _ensureActive();
    _validateHandover(source, target);
    final sourceDirectory = await _bindingDirectory(
      cidNumber: source.cidNumber,
      bindingRevision: source.bindingRevision,
      accountId: source.accountId,
    );
    final targetDirectory = await _bindingDirectory(
      cidNumber: target.cidNumber,
      bindingRevision: target.bindingRevision,
      accountId: target.accountId,
    );
    if (await targetDirectory.exists()) {
      throw StateError('Chat 文件交接已经进入目标目录，只能重试 commit');
    }
    List<Uint8List>? targetKeys;
    try {
      final marker = await _locateFileHandoverReceipt(
        sourceDirectory: sourceDirectory,
        targetDirectory: targetDirectory,
        target: target,
      );
      if (marker != null) {
        targetKeys = await _walletManager.deriveDataKeysForBindingHandover(
          target,
          const <({LocalKeyPurpose purpose, String? context})>[
            (purpose: LocalKeyPurpose.mls, context: null),
          ],
        );
        if (targetKeys.length != 1) {
          throw StateError('Chat 文件交接认证密钥数量不完整');
        }
        final receipt = await _readFileHandoverReceipt(
          marker: marker,
          source: source,
          target: target,
          macKey: targetKeys.single,
        );
        if (receipt.state == _ChatFileHandoverState.committing) {
          throw StateError('Chat 文件交接已开始 commit，禁止回退为 source');
        }
        await _requireStagedFileHandoverSnapshot(
          sourceDirectory: sourceDirectory,
          source: source,
          target: target,
          receipt: receipt,
        );
      }
      await AttachmentVault.discardAccountHandover(
        attachmentDirectory: Directory(
          '${sourceDirectory.path}/attachments',
        ),
        handoverId: _handoverId(target),
      );
      final mlsDirs = await _mlsDeviceDirectories(source);
      final bindings = mlsDirs.isEmpty ? null : MlsNativeBindings.load();
      for (final deviceDir in mlsDirs) {
        bindings!.runStateRekey(
          stateStoreDir: deviceDir.path,
          action: 'discard',
        );
        await MlsStateStore.discardAccountHandoverFiles(deviceDir);
      }
      await _deleteFileHandoverReceipt(
        directory: sourceDirectory,
        target: target,
      );
      // pending fence 必须覆盖全部文件回滚窗口；文件域清理成功后才与 manifest
      // 在同一 Store 事务中一并清除。
      await _store.discardAccountHandover(target);
      _blockedAccountIds.remove(source.accountId);
      _blockedAccountIds.remove(target.accountId);
    } finally {
      for (final key in targetKeys ?? const <Uint8List>[]) {
        key.fillRange(0, key.length, 0);
      }
    }
  }

  /// 没有当前账户签名的换绑完成后隔离不可继承的 Chat 状态。
  ///
  /// 绑定分区目录天然让新账户使用全新的附件与 MLS 状态；本方法只清理不能跨 MLS
  /// 上下文续用的本地队列和派生镜像，历史正文密文仍留在 Isar 且对新账户不可见。
  Future<void> isolateInaccessibleBinding({
    required AccountDataBinding previous,
    required AccountDataBinding current,
  }) async {
    _validateHandover(previous, current);
    await _invalidateAccountContext(previous.accountId);
    await _invalidateAccountContext(current.accountId);
    ChatBindingFenceToken fenceToken;
    var alreadyIsolated = false;
    try {
      fenceToken = await _store.captureBindingFenceToken(previous);
    } on StateError {
      fenceToken = await _store.captureBindingFenceToken(current);
      alreadyIsolated = true;
    }
    await _runCidFileMutation(
      cidNumber: previous.cidNumber,
      operation: () async {
        _ensureActive();
        await _store.validateBindingFenceToken(fenceToken);
        if (alreadyIsolated &&
            (fenceToken.bindingRevision != current.bindingRevision ||
                fenceToken.accountId != current.accountId)) {
          throw StateError('Chat 隔离完成 token 与 current binding 不一致');
        }
        await _store.isolateInaccessibleBinding(
          previous: previous,
          current: current,
        );
        final currentToken = await _store.captureBindingFenceToken(current);
        await _store.validateBindingFenceToken(currentToken);
        _blockedAccountIds.remove(current.accountId);
      },
    );
  }

  /// finalized 当前绑定完成端内交接后，关闭非当前账户上下文并建立当前 Chat 设备。
  Future<void> convergeFinalizedBinding(AccountDataBinding current) async {
    current.validate();
    final accountIds = <String>{
      current.accountId,
      ..._accountContextKeys.keys,
      ..._blockedAccountIds,
      for (final context in _contextsPendingDisposal) context.account.accountId,
    };
    for (final accountId in accountIds) {
      await _invalidateAccountContext(accountId);
    }
    await _runCidFileMutation(
      cidNumber: current.cidNumber,
      operation: () async {
        _ensureActive();
        final token = await _store.convergeFinalizedBinding(current);
        await _store.validateBindingFenceToken(token);
        _blockedAccountIds.remove(current.accountId);
      },
    );
  }

  Future<List<Directory>> _mlsDeviceDirectories(
    AccountDataBinding binding,
  ) async {
    final bindingDirectory = await _bindingDirectory(
      cidNumber: binding.cidNumber,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
    );
    final mlsRoot = Directory('${bindingDirectory.path}/mls');
    if (!await mlsRoot.exists()) return const <Directory>[];
    final out = <Directory>[];
    await for (final entity in mlsRoot.list()) {
      if (entity is Directory) out.add(entity);
    }
    return out;
  }

  Future<Directory> _bindingDirectory({
    required String cidNumber,
    required int bindingRevision,
    required String accountId,
  }) async {
    _ensureActive();
    final root = await _documentsDirectoryProvider();
    _ensureActive();
    return Directory(
      '${root.path}/chat/by_cid/${_safePath(cidNumber)}/by_binding/'
      '$bindingRevision/${_safePath(accountId)}',
    );
  }

  /// 交接密文全部提交后，原子把文件树切换到新绑定目录。
  Future<void> _moveBindingDirectory(
    AccountDataBinding source,
    AccountDataBinding target,
  ) async {
    final sourceDirectory = await _bindingDirectory(
      cidNumber: source.cidNumber,
      bindingRevision: source.bindingRevision,
      accountId: source.accountId,
    );
    final targetDirectory = await _bindingDirectory(
      cidNumber: target.cidNumber,
      bindingRevision: target.bindingRevision,
      accountId: target.accountId,
    );
    if (!await sourceDirectory.exists()) return;
    if (await targetDirectory.exists()) {
      throw StateError('Chat 新绑定目录已存在，禁止覆盖');
    }
    await targetDirectory.parent.create(recursive: true);
    await sourceDirectory.rename(targetDirectory.path);
  }

  static void _validateHandover(
    AccountDataBinding source,
    AccountDataBinding target,
  ) {
    source.validate();
    target.validate();
    if (source.genesisHash != target.genesisHash ||
        source.cidNumber != target.cidNumber ||
        target.bindingRevision != source.bindingRevision + 1 ||
        source.accountId == target.accountId) {
      throw const FormatException('Chat 换绑交接上下文不合法');
    }
  }

  static String _handoverId(AccountDataBinding target) =>
      '${target.bindingRevision}-${target.accountId.substring(2)}';

  static String _hexKey(List<int> key) =>
      key.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  static File _fileHandoverReceiptFile(
    Directory bindingDirectory,
    AccountDataBinding target,
  ) {
    final identity = jsonEncode(<String, Object>{
      'genesis_hash': target.genesisHash,
      'cid_number': target.cidNumber,
      'binding_revision': target.bindingRevision,
      'account_id': target.accountId,
    });
    final digest = crypto_hash.sha256.convert(utf8.encode(identity)).toString();
    return File(
      '${bindingDirectory.path}${Platform.pathSeparator}'
      '.account-handover-$digest.json',
    );
  }

  static File _fileHandoverReceiptTempFile(File marker) =>
      File('${marker.path}.writing');

  @visibleForTesting
  static String debugFileHandoverReceiptPathForTest({
    required Directory bindingDirectory,
    required AccountDataBinding target,
  }) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许读取 Chat 文件交接 receipt 路径');
    }
    return _fileHandoverReceiptFile(bindingDirectory, target).path;
  }

  static Map<String, Object> _fileHandoverBindingJson(
    AccountDataBinding binding,
  ) =>
      <String, Object>{
        'genesis_hash': binding.genesisHash,
        'cid_number': binding.cidNumber,
        'binding_revision': binding.bindingRevision,
        'account_id': binding.accountId,
      };

  static String _fileHandoverPayloadJson({
    required _ChatFileHandoverState state,
    required AccountDataBinding source,
    required AccountDataBinding target,
    required List<String> mlsDevicePaths,
    required List<_ChatFileHandoverInventoryItem> files,
  }) =>
      jsonEncode(<String, Object>{
        'state': state.name,
        'source': _fileHandoverBindingJson(source),
        'target': _fileHandoverBindingJson(target),
        'mls_devices': mlsDevicePaths,
        'files': files.map((item) => item.toJson()).toList(growable: false),
      });

  static String _fileHandoverMac(List<int> key, String payloadJson) =>
      crypto_hash.Hmac(crypto_hash.sha256, key)
          .convert(utf8.encode('$_fileHandoverMacDomain$payloadJson'))
          .toString();

  static bool _constantTimeStringEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    var difference = leftBytes.length ^ rightBytes.length;
    final length = max(leftBytes.length, rightBytes.length);
    for (var index = 0; index < length; index += 1) {
      final leftByte = index < leftBytes.length ? leftBytes[index] : 0;
      final rightByte = index < rightBytes.length ? rightBytes[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }

  static String _relativeFileHandoverPath(
    Directory root,
    String path,
  ) {
    final prefix = '${root.path}${Platform.pathSeparator}';
    if (!path.startsWith(prefix)) {
      throw StateError('Chat 文件交接清单路径越界');
    }
    final relative = path.substring(prefix.length).replaceAll(
          Platform.pathSeparator,
          '/',
        );
    if (relative.isEmpty ||
        relative.startsWith('/') ||
        relative
            .split('/')
            .any((segment) => segment.isEmpty || segment == '..')) {
      throw StateError('Chat 文件交接清单相对路径非法');
    }
    return relative;
  }

  static Future<List<_ChatFileHandoverInventoryItem>> _fileHandoverInventory({
    required Directory bindingDirectory,
    required AccountDataBinding target,
  }) async {
    if (!await bindingDirectory.exists()) {
      return const <_ChatFileHandoverInventoryItem>[];
    }
    final marker = _fileHandoverReceiptFile(bindingDirectory, target);
    final markerTemp = _fileHandoverReceiptTempFile(marker);
    final files = <_ChatFileHandoverInventoryItem>[];
    await for (final entity in bindingDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw StateError('Chat binding 目录含符号链接，禁止账户交接');
      }
      if (type != FileSystemEntityType.file) continue;
      if (entity.path == marker.path || entity.path == markerTemp.path) {
        continue;
      }
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.account-handover-') &&
          (name.endsWith('.json') || name.endsWith('.json.writing'))) {
        throw StateError('Chat binding 目录存在其它文件交接 receipt');
      }
      final file = File(entity.path);
      final before = await file.stat();
      final digest = await crypto_hash.sha256.bind(file.openRead()).first;
      final after = await file.stat();
      if (before.type != FileSystemEntityType.file ||
          after.type != FileSystemEntityType.file ||
          before.size != after.size ||
          before.modified != after.modified) {
        throw StateError('Chat 文件交接清单生成期间文件发生变化');
      }
      files.add(
        _ChatFileHandoverInventoryItem(
          relativePath: _relativeFileHandoverPath(
            bindingDirectory,
            file.path,
          ),
          byteSize: after.size,
          sha256: digest.toString(),
        ),
      );
    }
    files
        .sort((left, right) => left.relativePath.compareTo(right.relativePath));
    return List<_ChatFileHandoverInventoryItem>.unmodifiable(files);
  }

  static List<String> _fileHandoverMlsDevicePaths({
    required Directory bindingDirectory,
    required List<Directory> deviceDirectories,
  }) {
    final paths = deviceDirectories
        .map(
          (directory) => _relativeFileHandoverPath(
            bindingDirectory,
            directory.path,
          ),
        )
        .toList(growable: false)
      ..sort();
    if (paths.toSet().length != paths.length) {
      throw StateError('Chat MLS 设备目录清单存在重复项');
    }
    return List<String>.unmodifiable(paths);
  }

  static Future<void> _writeFileHandoverReceiptBytes({
    required File marker,
    required String payloadJson,
    required List<int> macKey,
  }) async {
    final temp = _fileHandoverReceiptTempFile(marker);
    await marker.parent.create(recursive: true);
    final markerType = await FileSystemEntity.type(
      marker.path,
      followLinks: false,
    );
    if (markerType != FileSystemEntityType.notFound &&
        markerType != FileSystemEntityType.file) {
      throw StateError('Chat 文件交接 receipt 路径类型异常');
    }
    final tempType = await FileSystemEntity.type(
      temp.path,
      followLinks: false,
    );
    if (tempType == FileSystemEntityType.file) {
      await temp.delete();
    } else if (tempType != FileSystemEntityType.notFound) {
      throw StateError('Chat 文件交接临时 receipt 路径类型异常');
    }
    final bytes = utf8.encode(
      jsonEncode(<String, String>{
        'payload_json': payloadJson,
        'mac': _fileHandoverMac(macKey, payloadJson),
      }),
    );
    await temp.create(exclusive: true);
    if (await FileSystemEntity.type(temp.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Chat 文件交接临时 receipt 创建后类型异常');
    }
    final handle = await temp.open(mode: FileMode.write);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
    // 同目录 rename 是唯一发布点：不得先删正式 marker。平台无法替换时直接失败，
    // 此前正式 marker 仍完整保留，下一次明确重试只清真实 file 类型的 `.writing`。
    await temp.rename(marker.path);
    if (await FileSystemEntity.type(marker.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await FileSystemEntity.type(temp.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw StateError('Chat 文件交接 receipt 原子发布失败');
    }
  }

  Future<void> _writeFileHandoverReceipt({
    required Directory sourceDirectory,
    required AccountDataBinding source,
    required AccountDataBinding target,
    required List<Directory> mlsDeviceDirectories,
    required List<int> macKey,
    required _ChatFileHandoverState state,
  }) async {
    await sourceDirectory.create(recursive: true);
    final devicePaths = _fileHandoverMlsDevicePaths(
      bindingDirectory: sourceDirectory,
      deviceDirectories: mlsDeviceDirectories,
    );
    final files = await _fileHandoverInventory(
      bindingDirectory: sourceDirectory,
      target: target,
    );
    final payloadJson = _fileHandoverPayloadJson(
      state: state,
      source: source,
      target: target,
      mlsDevicePaths: devicePaths,
      files: files,
    );
    await _writeFileHandoverReceiptBytes(
      marker: _fileHandoverReceiptFile(sourceDirectory, target),
      payloadJson: payloadJson,
      macKey: macKey,
    );
  }

  static Future<File?> _locateFileHandoverReceipt({
    required Directory sourceDirectory,
    required Directory targetDirectory,
    required AccountDataBinding target,
  }) async {
    final sourceMarker = _fileHandoverReceiptFile(sourceDirectory, target);
    final targetMarker = _fileHandoverReceiptFile(targetDirectory, target);
    final sourceType = await FileSystemEntity.type(
      sourceMarker.path,
      followLinks: false,
    );
    final targetType = await FileSystemEntity.type(
      targetMarker.path,
      followLinks: false,
    );
    if ((sourceType != FileSystemEntityType.notFound &&
            sourceType != FileSystemEntityType.file) ||
        (targetType != FileSystemEntityType.notFound &&
            targetType != FileSystemEntityType.file)) {
      throw StateError('Chat 文件交接 receipt 类型异常');
    }
    if (sourceType == FileSystemEntityType.file &&
        targetType == FileSystemEntityType.file) {
      throw StateError('Chat 新旧绑定目录同时存在文件交接 receipt');
    }
    if (sourceType == FileSystemEntityType.file) return sourceMarker;
    if (targetType == FileSystemEntityType.file) return targetMarker;
    return null;
  }

  static Future<_ChatFileHandoverReceipt> _readFileHandoverReceipt({
    required File marker,
    required AccountDataBinding source,
    required AccountDataBinding target,
    required List<int> macKey,
  }) async {
    if (await FileSystemEntity.type(marker.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Chat 文件交接 receipt 路径类型异常');
    }
    final raw = jsonDecode(await marker.readAsString());
    if (raw is! Map<String, dynamic> ||
        raw.keys
            .toSet()
            .difference(<String>{'payload_json', 'mac'}).isNotEmpty ||
        raw.length != 2 ||
        raw['payload_json'] is! String ||
        raw['mac'] is! String) {
      throw const FormatException('Chat 文件交接 receipt 外层结构损坏');
    }
    final payloadJson = raw['payload_json'] as String;
    final mac = raw['mac'] as String;
    if (!_constantTimeStringEquals(
      mac,
      _fileHandoverMac(macKey, payloadJson),
    )) {
      throw const FormatException('Chat 文件交接 receipt 认证失败');
    }
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 5 ||
        decoded.keys.toSet().difference(<String>{
          'state',
          'source',
          'target',
          'mls_devices',
          'files',
        }).isNotEmpty ||
        jsonEncode(decoded['source']) !=
            jsonEncode(_fileHandoverBindingJson(source)) ||
        jsonEncode(decoded['target']) !=
            jsonEncode(_fileHandoverBindingJson(target))) {
      throw const FormatException('Chat 文件交接 receipt 绑定结构损坏');
    }
    final state = _ChatFileHandoverState.fromName(decoded['state']);
    final rawDevices = decoded['mls_devices'];
    final rawFiles = decoded['files'];
    if (rawDevices is! List || rawFiles is! List) {
      throw const FormatException('Chat 文件交接 receipt 清单结构损坏');
    }
    final devicePaths = rawDevices.map((value) {
      if (value is! String || value.isEmpty || value.contains('..')) {
        throw const FormatException('Chat 文件交接 MLS 设备路径损坏');
      }
      return value;
    }).toList(growable: false);
    final files = rawFiles
        .map((value) => _ChatFileHandoverInventoryItem.fromJson(value))
        .toList(growable: false);
    final sortedDevices = List<String>.from(devicePaths)..sort();
    final sortedFiles = List<_ChatFileHandoverInventoryItem>.from(files)
      ..sort((left, right) => left.relativePath.compareTo(right.relativePath));
    if (devicePaths.toSet().length != devicePaths.length ||
        !listEquals(devicePaths, sortedDevices) ||
        files.map((item) => item.relativePath).toSet().length != files.length ||
        !listEquals(
          files.map((item) => item.relativePath).toList(growable: false),
          sortedFiles.map((item) => item.relativePath).toList(growable: false),
        )) {
      throw const FormatException('Chat 文件交接 receipt 清单顺序或唯一性损坏');
    }
    return _ChatFileHandoverReceipt(
      state: state,
      payloadJson: payloadJson,
      mlsDevicePaths: List<String>.unmodifiable(devicePaths),
      files: List<_ChatFileHandoverInventoryItem>.unmodifiable(files),
    );
  }

  Future<void> _requireStagedFileHandoverSnapshot({
    required Directory sourceDirectory,
    required AccountDataBinding source,
    required AccountDataBinding target,
    required _ChatFileHandoverReceipt receipt,
  }) async {
    if (receipt.state != _ChatFileHandoverState.staged) {
      throw StateError('Chat 文件交接 receipt 已不是 staged 状态');
    }
    final mlsDirs = await _mlsDeviceDirectories(source);
    final devicePaths = _fileHandoverMlsDevicePaths(
      bindingDirectory: sourceDirectory,
      deviceDirectories: mlsDirs,
    );
    final files = await _fileHandoverInventory(
      bindingDirectory: sourceDirectory,
      target: target,
    );
    final expected = _fileHandoverPayloadJson(
      state: _ChatFileHandoverState.staged,
      source: source,
      target: target,
      mlsDevicePaths: devicePaths,
      files: files,
    );
    if (!_constantTimeStringEquals(expected, receipt.payloadJson)) {
      throw StateError('Chat 文件域在 stage-complete receipt 后发生变化');
    }
  }

  static Future<void> _writeFileHandoverReceiptFromSnapshot({
    required Directory directory,
    required AccountDataBinding source,
    required AccountDataBinding target,
    required _ChatFileHandoverReceipt receipt,
    required List<int> macKey,
    required _ChatFileHandoverState state,
  }) {
    final payloadJson = _fileHandoverPayloadJson(
      state: state,
      source: source,
      target: target,
      mlsDevicePaths: receipt.mlsDevicePaths,
      files: receipt.files,
    );
    return _writeFileHandoverReceiptBytes(
      marker: _fileHandoverReceiptFile(directory, target),
      payloadJson: payloadJson,
      macKey: macKey,
    );
  }

  static Future<void> _deleteFileHandoverReceipt({
    required Directory directory,
    required AccountDataBinding target,
  }) async {
    final marker = _fileHandoverReceiptFile(directory, target);
    final temp = _fileHandoverReceiptTempFile(marker);
    for (final file in <File>[marker, temp]) {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('Chat 文件交接 receipt 路径类型异常');
      }
      await file.delete();
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('Chat 文件交接 receipt 删除后仍存在');
      }
    }
  }

  /// 页面、轮询、WebSocket 和发送入口共享的唯一就绪入口。
  Future<void> ensureReady(String accountId) async {
    _ensureActive();
    final account = await _readAccount(expectedAccountId: accountId);
    await _readyContext(account);
  }

  /// 默认账户切换或本机 Chat 数据清理时精确失效该账户上下文。
  Future<void> invalidateAccount(String accountId) {
    _ensureActive();
    return _invalidateAccountContext(accountId, keepBlocked: false);
  }

  /// finalized 接管路径必须等此前网络与 MLS 上下文全部关闭后再建立新上下文。
  Future<void> _invalidateAccountContext(
    String accountId, {
    bool keepBlocked = true,
  }) async {
    _ensureActive();
    // 同步封住新 ready/realtime 入口，再开始任何 await；转换失败时保持 blocked，
    // 只能由明确的 converge/commit/discard 成功路径重新放行。
    _blockedAccountIds.add(accountId);
    _accountGenerations[accountId] = (_accountGenerations[accountId] ?? 0) + 1;
    final realtimeHub = _realtimeHubs[accountId];
    if (realtimeHub != null) await _closeRealtimeHub(realtimeHub);
    final invalidatedFlights = _readyFlights.entries
        .where((entry) => entry.key.endsWith('|$accountId'))
        .toList(growable: false);
    for (final entry in invalidatedFlights) {
      if (identical(_readyFlights[entry.key], entry.value)) {
        _readyFlights.remove(entry.key);
        _trackInvalidatedReadyFlight(entry.value);
      }
    }
    final sessions = _realtimeSessions
        .where((session) => session.belongsToAccount(accountId))
        .toList(growable: false);
    final contexts = <_ChatAccountContext>{
      for (final context in _readyContexts.values)
        if (context.account.accountId == accountId) context,
      for (final context in _contextsPendingDisposal)
        if (context.account.accountId == accountId) context,
    };
    final key = _accountContextKeys.remove(accountId);
    if (key != null) {
      final context = _readyContexts.remove(key);
      if (context != null) contexts.add(context);
    }
    final failures = <String>[];
    for (final session in sessions) {
      await _captureCleanupFailure(
        '关闭账户 Chat 实时会话',
        () => _disposeRealtimeSession(session),
        failures,
      );
    }
    // 这里尚未持有 CID lease，等待旧 build 完成不会与它自锁；generation 会让
    // 完成结果在登记前自行 dispose，随后下面再复核 pending disposal。
    for (final entry in invalidatedFlights) {
      try {
        await entry.value;
      } catch (_) {
        // 初始化自身失败没有可复用上下文；dispose 失败会留在 pending 集合并重试。
      }
    }
    contexts.addAll(
      _contextsPendingDisposal.where(
        (context) => context.account.accountId == accountId,
      ),
    );
    final byCidNumber = <String, List<_ChatAccountContext>>{};
    for (final context in contexts) {
      byCidNumber
          .putIfAbsent(context.account.cidNumber, () => <_ChatAccountContext>[])
          .add(context);
    }
    for (final entry in byCidNumber.entries) {
      await _captureCleanupFailure(
        '排空账户 Chat 文件操作',
        () => _runCidFileMutation(
          cidNumber: entry.key,
          operation: () async {},
        ),
        failures,
      );
    }
    // barrier 已确认此前 flow/build/file action 全部离开；此时不持 CID lease 关闭
    // WebRTC KeyPackage 控制连接可自行取得旧 token lease 并收口，
    // 避免“持 admin lease 等待一个正在等同一 lease 的 tail”自锁。
    for (final context in contexts) {
      await _captureCleanupFailure(
        '关闭账户 Chat 上下文',
        () => _disposeContext(context),
        failures,
      );
    }
    _squareApiClient.clearSession(accountId);
    if (failures.isNotEmpty) throw StateError(failures.join('\n'));
    if (!keepBlocked) _blockedAccountIds.remove(accountId);
  }

  void _trackInvalidatedReadyFlight(
    Future<_ChatAccountContext> flight,
  ) {
    if (!_readyFlightsPendingInvalidation.add(flight)) return;
    unawaited(
      flight.then<void>(
        (_) {
          _readyFlightsPendingInvalidation.remove(flight);
        },
        onError: (Object _, StackTrace __) {
          _readyFlightsPendingInvalidation.remove(flight);
        },
      ),
    );
  }

  static String directConversationId(
    String senderCidNumber,
    String peerCidNumber,
  ) {
    final members = [senderCidNumber, peerCidNumber]..sort();
    return 'dm:${members[0]}:${members[1]}';
  }

  Future<List<ChatDeliveryResult>> sendText({
    required String peerCidNumber,
    required String conversationId,
    required String text,
  }) async {
    final payload = ChatPayloadCodec.encode(ChatContent.text(text));
    await _savePendingDirectPayload(
      peerCidNumber: peerCidNumber,
      conversationId: conversationId,
      messageKind: ChatMessageKind.text,
      payload: payload,
    );
    return const <ChatDeliveryResult>[];
  }

  /// 用户点击发送后的第一持久边界。这里只依赖当前 finalized 账户和本机用途钥，
  /// 不等待 Firebase、Worker 登录、系统唤醒端点、直连 KeyPackage 或 WebSocket。
  Future<String> _savePendingDirectPayload({
    required String peerCidNumber,
    required String conversationId,
    required ChatMessageKind messageKind,
    required String payload,
    ChatMediaDraft? media,
    ChatMediaLocalCommitNotifier? onLocalCommitted,
    bool scheduleDelivery = true,
  }) async {
    _ensureActive();
    final account = await _readAccount();
    if (!ChatMediaLimits.chatAuthorizedFor(account.cidNumber)) {
      throw StateError('当前会话尚未通过 CitizenServe 会员鉴权');
    }
    final bindingToken = await _convergeBindingFence(account);
    final createdAtMillis = DateTime.now().millisecondsSinceEpoch;
    final localMessageId = _newPendingMessageId(
      conversationId,
      createdAtMillis,
    );
    await _runBindingFileMutation(bindingToken, () async {
      if (media != null) {
        final content = ChatPayloadCodec.decode(payload);
        final attachmentId = content.attachmentId ?? '';
        if (!content.isMedia || attachmentId.isEmpty) {
          throw const FormatException('Chat 本地媒体待发送载荷无效');
        }
        await _copySentAttachmentToCacheMutation(
          bindingToken: bindingToken,
          conversationId: conversationId,
          attachmentId: attachmentId,
          fileName: media.fileName,
          contentType: media.contentType,
          sourcePath: media.sourcePath,
          byteSize: media.byteSize,
        );
      }
      await _store.savePendingOutgoingMessage(
        bindingToken: bindingToken,
        ownerCidNumber: account.cidNumber,
        currentAccountId: account.accountId,
        localMessageId: localMessageId,
        conversationId: conversationId,
        recipientCidNumber: peerCidNumber,
        messageKind: messageKind,
        payload: payload,
        createdAtMillis: createdAtMillis,
      );
    });
    await onLocalCommitted?.call();
    if (scheduleDelivery) {
      _schedulePendingOutgoing(
        account: account,
        recipientCidNumber: peerCidNumber,
        conversationId: conversationId,
      );
    }
    return localMessageId;
  }

  /// 本地待发送行已经成立后，网络/MLS 转换在后台按账户+会话保序执行。失败不删除
  /// 本地消息；实时重连、轮询、网络恢复或推送唤醒都会再次进入同一收敛入口。
  void _schedulePendingOutgoing({
    required _ChatAccount account,
    required String recipientCidNumber,
    required String conversationId,
  }) {
    final key = '${account.accountId}|$conversationId';
    unawaited(
      _runRuntimeOperation(
        () => _outboundDeliveryGate.run(key, () async {
          final current =
              await _readAccount(expectedAccountId: account.accountId);
          final context = await _readyContext(current);
          await _flushPendingOutgoing(
            context,
            recipientCidNumber: recipientCidNumber,
            conversationId: conversationId,
          );
          await _retryQueuedEnvelopes(
            context,
            recipientCidNumber: recipientCidNumber,
            conversationId: conversationId,
          );
        }),
      ).catchError((Object _) {
        // 本地密文行是可靠真值；任何网络或初始化失败只等待下次统一补发。
      }),
    );
  }

  Future<List<ChatDeliveryResult>> sendMedia({
    required String peerCidNumber,
    required String conversationId,
    required ChatMediaDraft media,
    ChatMediaLocalCommitNotifier? onLocalCommitted,
  }) async {
    if (ChatMediaLimits.exceedsForKind(media.kind, media.byteSize)) {
      throw ChatMediaTooLargeException(
        byteSize: media.byteSize,
        limitBytes: ChatMediaLimits.forKind(media.kind),
        kind: media.kind,
      );
    }
    final attachmentId = _newPendingAttachmentId(
      conversationId,
      DateTime.now().millisecondsSinceEpoch,
    );
    final account = await _readAccount();
    final bindingToken = await _convergeBindingFence(account);
    final content = await _prepareEncryptedMedia(
      bindingToken: bindingToken,
      conversationId: conversationId,
      attachmentId: attachmentId,
      media: media,
    );
    try {
      await _savePendingDirectPayload(
        peerCidNumber: peerCidNumber,
        conversationId: conversationId,
        messageKind: media.kind,
        payload: ChatPayloadCodec.encode(content),
        media: media,
        onLocalCommitted: onLocalCommitted,
        scheduleDelivery: false,
      );
      // 本机消息和待上传密文均已持久成立；网络初始化、R2 multipart 与 MLS
      // 控制信封统一交给后台保序队列，上传失败只保留这一条待重试消息。
      _schedulePendingOutgoing(
        account: account,
        recipientCidNumber: peerCidNumber,
        conversationId: conversationId,
      );
      return const <ChatDeliveryResult>[];
    } catch (_) {
      final staged = await _pendingAttachmentUploadFile(
        bindingToken,
        conversationId,
        attachmentId,
      );
      if (await staged.exists()) await staged.delete();
      rethrow;
    }
  }

  /// 用户点击发送时只生成持久待上传密文，不等待 CitizenServe、R2 或接收设备。
  /// 随机密钥进入本机加密 payload；Worker 与 R2 永远收不到明文密钥。
  Future<ChatContent> _prepareEncryptedMedia({
    required ChatBindingFenceToken bindingToken,
    required String conversationId,
    required String attachmentId,
    required ChatMediaDraft media,
  }) async {
    final random = Random.secure();
    final transferKey = List<int>.generate(32, (_) => random.nextInt(256));
    final cipherTarget = await _pendingAttachmentUploadFile(
      bindingToken,
      conversationId,
      attachmentId,
    );
    await cipherTarget.parent.create(recursive: true);
    try {
      final cipher = await AttachmentVault.sealForTransport(
        plainSource: File(media.sourcePath),
        cipherTarget: cipherTarget,
        key: transferKey,
      );
      return ChatContent.media(
        kind: media.kind,
        attachmentId: attachmentId,
        fileName: media.fileName,
        mime: media.contentType,
        byteSize: media.byteSize,
        width: media.width,
        height: media.height,
        durationMs: media.durationMs,
        blurhash: media.blurhash,
        cipherKey: base64UrlEncode(transferKey).replaceAll('=', ''),
        cipherByteSize: cipher.byteSize,
        cipherSha256: cipher.sha256,
      );
    } catch (_) {
      if (await cipherTarget.exists()) await cipherTarget.delete();
      rethrow;
    } finally {
      transferKey.fillRange(0, transferKey.length, 0);
    }
  }

  Future<File> _pendingAttachmentUploadFile(
    ChatBindingFenceToken bindingToken,
    String conversationId,
    String attachmentId,
  ) async =>
      File(
        '${(await _attachmentDirectoryForToken(bindingToken)).path}'
        '/${_safePath(conversationId)}/.pending_upload/'
        '${_safePath(attachmentId)}.cipher',
      );

  Future<File> _pendingAttachmentUploadedMarker(
    ChatBindingFenceToken bindingToken,
    String conversationId,
    String attachmentId,
  ) async =>
      File(
        '${(await _pendingAttachmentUploadFile(
          bindingToken,
          conversationId,
          attachmentId,
        )).path}.uploaded',
      );

  /// 发送内置贴纸:只走控制信封,不经 WebRTC。首次会话缺 KeyPackage 时同样
  /// 领取后重试。
  Future<List<ChatDeliveryResult>> sendSticker({
    required String peerCidNumber,
    required String conversationId,
    required String packId,
    required String stickerId,
  }) async {
    final payload = ChatPayloadCodec.encode(
      ChatContent.sticker(packId: packId, stickerId: stickerId),
    );
    await _savePendingDirectPayload(
      peerCidNumber: peerCidNumber,
      conversationId: conversationId,
      messageKind: ChatMessageKind.sticker,
      payload: payload,
    );
    return const <ChatDeliveryResult>[];
  }

  // ==== 私密小群 ====

  /// 建群：选联系人 CID，领其 KeyPackage 批量加入，创建者为 admin。
  Future<ChatGroup> createGroup({
    required String name,
    List<String> inviteeCidNumbers = const [],
  }) {
    return _runWithReadyBinding((context) async {
      final invitees =
          await _fetchInviteeKeyPackages(context, inviteeCidNumbers);
      final groupId = newGroupId(context.account.cidNumber);
      return _groupFlow(context).createGroup(
        groupId: groupId,
        name: name,
        cidNumber: context.account.cidNumber,
        localDeviceId: context.deviceId,
        invitees: invitees,
      );
    });
  }

  /// 加人(仅 admin)。
  Future<void> addGroupMembers({
    required String groupId,
    required List<String> inviteeCidNumbers,
  }) {
    return _runWithReadyBinding((context) async {
      final invitees =
          await _fetchInviteeKeyPackages(context, inviteeCidNumbers);
      await _groupFlow(context).addMembers(
        groupId: groupId,
        actorCidNumber: context.account.cidNumber,
        actorDeviceId: context.deviceId,
        invitees: invitees,
      );
    });
  }

  /// 删人（仅 admin，按 CID）。
  Future<void> removeGroupMembers({
    required String groupId,
    required List<String> targetCidNumbers,
  }) {
    return _runWithReadyBinding((context) async {
      await _groupFlow(context).removeMembers(
        groupId: groupId,
        actorCidNumber: context.account.cidNumber,
        actorDeviceId: context.deviceId,
        targetCidNumbers: targetCidNumbers,
      );
    });
  }

  /// 退群(本机标记已退,并发退群请求让 admin 重钥)。
  Future<void> leaveGroup(String groupId) {
    return _runWithReadyBinding((context) async {
      await _groupFlow(context).leaveGroup(groupId);
    });
  }

  /// 改群名(仅 admin)。
  Future<void> renameGroup({
    required String groupId,
    required String name,
  }) {
    return _runWithReadyBinding((context) async {
      await _groupFlow(context).renameGroup(groupId, name);
    });
  }

  /// 群发文本。
  Future<List<ChatDeliveryResult>> sendGroupText({
    required String groupId,
    required String text,
  }) {
    return _runWithReadyContext((context) async {
      if (!ChatMediaLimits.chatAuthorizedFor(context.account.cidNumber)) {
        throw StateError('当前会话尚未通过 CitizenServe 会员鉴权');
      }
      return _groupFlow(context).sendGroupText(
        groupId: groupId,
        senderCidNumber: context.account.cidNumber,
        senderDeviceId: context.deviceId,
        text: text,
      );
    });
  }

  /// 群发内置贴纸(零字节,收端本地渲染)。
  Future<List<ChatDeliveryResult>> sendGroupSticker({
    required String groupId,
    required String packId,
    required String stickerId,
  }) {
    return _runWithReadyContext((context) async {
      if (!ChatMediaLimits.chatAuthorizedFor(context.account.cidNumber)) {
        throw StateError('当前会话尚未通过 CitizenServe 会员鉴权');
      }
      return _groupFlow(context).sendGroupSticker(
        groupId: groupId,
        senderCidNumber: context.account.cidNumber,
        senderDeviceId: context.deviceId,
        packId: packId,
        stickerId: stickerId,
      );
    });
  }

  /// 群附件与直聊统一先落本机待发消息，再后台上传一次并扇出控制信封。
  Future<List<ChatDeliveryResult>> sendGroupMedia({
    required String groupId,
    required ChatMediaDraft media,
    ChatMediaLocalCommitNotifier? onLocalCommitted,
  }) {
    if (ChatMediaLimits.exceedsForKind(media.kind, media.byteSize)) {
      throw ChatMediaTooLargeException(
        byteSize: media.byteSize,
        limitBytes: ChatMediaLimits.forKind(media.kind),
        kind: media.kind,
      );
    }
    return () async {
      final account = await _readAccount();
      if (!ChatMediaLimits.chatAuthorizedFor(account.cidNumber)) {
        throw StateError('当前会话尚未通过 CitizenServe 会员鉴权');
      }
      final bindingToken = await _convergeBindingFence(account);
      final attachmentId = _newPendingAttachmentId(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      );
      final content = await _prepareEncryptedMedia(
        bindingToken: bindingToken,
        conversationId: groupId,
        attachmentId: attachmentId,
        media: media,
      );
      try {
        await _savePendingDirectPayload(
          peerCidNumber: groupId,
          conversationId: groupId,
          messageKind: media.kind,
          payload: ChatPayloadCodec.encode(content),
          media: media,
          onLocalCommitted: onLocalCommitted,
          scheduleDelivery: false,
        );
        _schedulePendingOutgoing(
          account: account,
          recipientCidNumber: groupId,
          conversationId: groupId,
        );
        return const <ChatDeliveryResult>[];
      } catch (_) {
        final staged = await _pendingAttachmentUploadFile(
          bindingToken,
          groupId,
          attachmentId,
        );
        if (await staged.exists()) await staged.delete();
        rethrow;
      }
    }();
  }

  /// 逐个被邀请 CID 建立直连并请求一枚一次性 KeyPackage。
  Future<List<MlsKeyPackage>> _fetchInviteeKeyPackages(
    _ChatAccountContext context,
    List<String> inviteeCidNumbers,
  ) async {
    final packages = <MlsKeyPackage>[];
    for (final cidNumber in inviteeCidNumbers) {
      final consumed = await _claimKeyPackage(context, cidNumber);
      if (consumed.cidNumber != cidNumber) {
        throw StateError('直连返回的 KeyPackage CID 与请求目标不一致');
      }
      packages.add(consumed);
    }
    return packages;
  }

  Future<MlsKeyPackage> _claimKeyPackage(
    _ChatAccountContext context,
    String targetCidNumber,
  ) async {
    final claimed = await context.webrtc.requestKeyPackage(targetCidNumber);
    if (claimed.cidNumber != targetCidNumber) {
      throw StateError('直连返回的 KeyPackage CID 与请求目标不一致');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (claimed.notBeforeMillis >= now || claimed.notAfterMillis <= now) {
      throw StateError('直连返回的 KeyPackage Lifetime 当前不可用');
    }
    return claimed;
  }

  ChatGroupFlow _groupFlow(_ChatAccountContext context) {
    return ChatGroupFlow(
      crypto: context.crypto as MlsGroupCrypto,
      store: _store,
      bindingToken: context.bindingToken,
      ownerCidNumber: context.account.cidNumber,
      cidNumber: context.account.cidNumber,
      currentAccountId: context.account.accountId,
      localDeviceId: context.deviceId,
      deliveryScheduler: (conversationId, delivery) =>
          _scheduleOutboundDelivery(context, conversationId, delivery),
      beforeIncomingStore: (envelope, content) =>
          _cacheIncomingCloudAttachment(context, envelope, content),
      deliverer: (envelope, _, recipientCidNumber) {
        return ChatFlow.deliverWithTransport(
          transport: context.transport,
          envelope: envelope,
          recipientCidNumber: recipientCidNumber,
        );
      },
    );
  }

  /// 批量解析媒体在本机缓存中的绝对路径。字节未到达时不入结果，由 UI 显示占位。
  /// 同一页面批次只解封一次附件用途钥，避免每条媒体重复进入硬件钥通道。
  Future<Map<String, String>> resolveCachedMediaPaths({
    required String conversationId,
    required List<ChatContent> contents,
  }) async {
    if (contents.isEmpty) return const <String, String>{};
    try {
      final account = await _readAccount();
      final bindingToken = await _convergeBindingFence(account);
      return await _runBindingFileMutation(bindingToken, () async {
        final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
        final plainDirectory = await _plainDirectoryForBinding(bindingToken);
        final attachmentKey = await _attachmentKeyForBinding(bindingToken);
        try {
          final paths = <String, String>{};
          // 文件仍逐项执行大小、密文和缓存校验；这里只复用当前批次的短命钥。
          for (final content in contents) {
            final attachmentId = content.attachmentId ?? '';
            if (!content.isMedia || attachmentId.isEmpty) continue;
            try {
              final cached = await ChatFlow.readCachedAttachment(
                conversationId: conversationId,
                attachmentId: attachmentId,
                fileName: content.fileName ?? '',
                contentType: content.mime ?? 'application/octet-stream',
                clearByteSize: content.byteSize ?? 0,
                cacheDirectory: cacheDirectory,
                attachmentKey: attachmentKey,
                plainDirectory: plainDirectory,
              );
              final path = cached?.filePath;
              if (path != null && path.isNotEmpty) paths[attachmentId] = path;
            } catch (_) {
              // 单个缓存损坏或仍未完整到达时跳过该项，不能拖累同批其它媒体。
            }
          }
          return Map<String, String>.unmodifiable(paths);
        } finally {
          attachmentKey.fillRange(0, attachmentKey.length, 0);
        }
      });
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<ChatDownloadedAttachment> downloadAttachment({
    required String conversationId,
    required String controlPlaintext,
  }) {
    return _runWithReadyBinding(
      (context) => _downloadAttachment(
        context,
        conversationId,
        controlPlaintext,
      ),
    );
  }

  Future<ChatDownloadedAttachment> _downloadAttachment(
    _ChatAccountContext context,
    String conversationId,
    String controlPlaintext,
  ) async {
    final bindingToken = context.bindingToken;
    final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
    return ChatFlow.downloadAttachment(
      conversationId: conversationId,
      controlPlaintext: controlPlaintext,
      cacheDirectory: cacheDirectory,
      attachmentKey: await _attachmentKeyForBinding(bindingToken),
      plainDirectory: await _plainDirectoryForBinding(bindingToken),
    );
  }

  Future<void> deleteLocalConversation(String conversationId) {
    return _runWithReadyBinding(
      (context) => _deleteLocalConversation(context, conversationId),
    );
  }

  /// 服务端账户注销成功后，协调关闭该 CID 的 Chat 上下文并清除全部本机 Chat 数据。
  ///
  /// Square 只调用本运行态边界，禁止直接绕过上下文/文件收口去删 ChatStore。
  Future<void> clearAllForCidNumber({
    required String cidNumber,
    required String accountId,
  }) async {
    final accountIds = <String>{accountId};
    for (final context in <_ChatAccountContext>{
      ..._readyContexts.values,
      ..._contextsPendingDisposal,
    }) {
      if (context.account.cidNumber == cidNumber) {
        accountIds.add(context.account.accountId);
      }
    }
    for (final session in _realtimeSessions) {
      if (session.ownerCidNumber == cidNumber && session.accountId != null) {
        accountIds.add(session.accountId!);
      }
    }
    for (final id in accountIds) {
      await _invalidateAccountContext(id);
    }
    return _runCidFileMutation(
        cidNumber: cidNumber,
        operation: () async {
          _ensureActive();
          await _store.clearAllForCidNumber(cidNumber);

          final documentsRoot = (await _documentsDirectoryProvider()).absolute;
          final cidDirectory = Directory(
            '${documentsRoot.path}${Platform.pathSeparator}chat'
            '${Platform.pathSeparator}by_cid'
            '${Platform.pathSeparator}${_safePath(cidNumber)}',
          ).absolute;
          if (cidDirectory.path == cidDirectory.parent.path ||
              !cidDirectory.path.startsWith(
                '${documentsRoot.path}${Platform.pathSeparator}chat'
                '${Platform.pathSeparator}by_cid${Platform.pathSeparator}',
              )) {
            throw StateError('Chat CID 清理目录越过本机 Chat 边界');
          }
          final type = await FileSystemEntity.type(
            cidDirectory.path,
            followLinks: false,
          );
          if (type == FileSystemEntityType.link) {
            await Link(cidDirectory.path).delete();
          } else if (type != FileSystemEntityType.notFound) {
            await cidDirectory.delete(recursive: true);
          }

          final prefs = await _prefs;
          final safeCid = _safePath(cidNumber);
          final staleKeys = prefs.getKeys().where(
                (key) =>
                    key == deviceIdPreferenceKey(cidNumber) ||
                    key == devicePublicKeyCachePreferenceKey(cidNumber) ||
                    (key.startsWith('$_kPushRegistrationPrefix.') &&
                        key.contains('.$safeCid.')),
              );
          for (final key in staleKeys.toList(growable: false)) {
            await prefs.remove(key);
          }
        });
  }

  Future<void> _deleteLocalConversation(
    _ChatAccountContext context,
    String conversationId,
  ) async {
    final bindingToken = context.bindingToken;
    await _store.deleteConversation(
      context.account.cidNumber,
      conversationId,
      bindingToken: bindingToken,
    );
    final attachmentDir = Directory(
      '${(await _attachmentDirectoryForToken(bindingToken)).path}/${_safePath(conversationId)}',
    );
    if (await attachmentDir.exists()) {
      await attachmentDir.delete(recursive: true);
    }
    // purge 点之三:删会话同时清掉可能已解密出来的短命明文。
    await AttachmentVault.purgePlainDirectory(
      await _plainDirectoryForBinding(bindingToken),
    );
  }

  /// 重试发送设备本机队列中的密文,并补发待设备投递的媒体字节。
  /// 应用密文只有收到接收设备“已成功处理”确认后才删队列项；Worker 的 socket
  /// 写入结果只更新内部尝试状态。媒体字节仍在收到 WebRTC ack 后删待投递行。
  Future<int> retryOutgoing({
    String? recipientCidNumber,
    String? conversationId,
  }) {
    return _runWithReadyBinding((context) async {
      await _flushPendingOutgoing(
        context,
        recipientCidNumber: recipientCidNumber,
        conversationId: conversationId,
      );
      final sent = await _retryQueuedEnvelopes(
        context,
        recipientCidNumber: recipientCidNumber,
        conversationId: conversationId,
      );
      return sent;
    });
  }

  /// 把本机用途钥密文待发送行按会话顺序转换为正式 MLS Envelope。某条失败时
  /// 立即停止该批，禁止后一条越过它推进 ratchet；原行保留到下一次补发。
  Future<void> _flushPendingOutgoing(
    _ChatAccountContext context, {
    String? recipientCidNumber,
    String? conversationId,
  }) async {
    if (!ChatMediaLimits.chatAuthorizedFor(context.account.cidNumber)) return;
    final pending = await _store.readPendingOutgoingMessages(
      bindingToken: context.bindingToken,
      ownerCidNumber: context.account.cidNumber,
      currentAccountId: context.account.accountId,
      recipientCidNumber: recipientCidNumber,
      conversationId: conversationId,
    );
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    for (final item in pending) {
      if (nowMillis - item.createdAtMillis >= chatMailboxTtlMillis) {
        await _expirePendingOutgoing(context, item);
        continue;
      }
      try {
        await _sendPendingOutgoing(context, item);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> _expirePendingOutgoing(
    _ChatAccountContext context,
    ChatPendingOutgoingMessage pending,
  ) async {
    await _store.markPendingOutgoingFailed(
      bindingToken: context.bindingToken,
      ownerCidNumber: context.account.cidNumber,
      localMessageId: pending.localMessageId,
    );
    final content = ChatPayloadCodec.decode(pending.payload);
    final attachmentId = content.attachmentId ?? '';
    if (!content.isMedia || attachmentId.isEmpty) return;
    final staged = await _pendingAttachmentUploadFile(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    final uploaded = await _pendingAttachmentUploadedMarker(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    if (await uploaded.exists()) {
      await context.transport
          .abortAttachment(attachmentId)
          .catchError((Object _) {});
      try {
        await uploaded.delete();
      } catch (_) {
        // 过期状态已经落库；残留标记随会话本地清理收口。
      }
    }
    try {
      if (await staged.exists()) await staged.delete();
    } catch (_) {
      // 过期状态已经落库；残留密文随会话本地清理收口。
    }
  }

  Future<void> _sendPendingOutgoing(
    _ChatAccountContext context,
    ChatPendingOutgoingMessage pending,
  ) async {
    final content = ChatPayloadCodec.decode(pending.payload);
    if (content.kind != pending.messageKind) {
      throw StateError('Chat 本地待发送消息类型与载荷不一致');
    }
    if (pending.conversationId.startsWith('grp:')) {
      if (!content.isMedia) {
        throw StateError('Chat 群本地待发送载荷类型不合法');
      }
      await _sendPendingGroupMedia(context, pending, content);
      return;
    }
    final flow = _messageFlow(context, scheduleDelivery: false);

    Future<void> send({MlsKeyPackage? keyPackage}) async {
      switch (content.kind) {
        case ChatMessageKind.text:
          await flow.sendText(
            conversationId: pending.conversationId,
            senderCidNumber: context.account.cidNumber,
            recipientCidNumber: pending.recipientCidNumber,
            senderDeviceId: context.deviceId,
            recipientKeyPackage: keyPackage,
            text: content.text ?? '',
            pendingLocalMessageId: pending.localMessageId,
            createdAtMillis: pending.createdAtMillis,
          );
        case ChatMessageKind.sticker:
          await flow.sendSticker(
            conversationId: pending.conversationId,
            senderCidNumber: context.account.cidNumber,
            recipientCidNumber: pending.recipientCidNumber,
            senderDeviceId: context.deviceId,
            recipientKeyPackage: keyPackage,
            packId: content.packId ?? '',
            stickerId: content.stickerId ?? '',
            pendingLocalMessageId: pending.localMessageId,
            createdAtMillis: pending.createdAtMillis,
          );
        case ChatMessageKind.image:
        case ChatMessageKind.video:
        case ChatMessageKind.file:
        case ChatMessageKind.audio:
          await _sendPendingMedia(
            context: context,
            flow: flow,
            pending: pending,
            content: content,
            keyPackage: keyPackage,
          );
      }
    }

    try {
      await send();
    } catch (error) {
      if (!_needsFirstKeyPackage(error)) rethrow;
      await send(
        keyPackage: await _claimKeyPackage(
          context,
          pending.recipientCidNumber,
        ),
      );
    }
  }

  Future<void> _sendPendingMedia({
    required _ChatAccountContext context,
    required ChatFlow flow,
    required ChatPendingOutgoingMessage pending,
    required ChatContent content,
    MlsKeyPackage? keyPackage,
  }) async {
    final attachmentId = content.attachmentId ?? '';
    final cipherByteSize = content.cipherByteSize ?? -1;
    final cipherSha256 = content.cipherSha256 ?? '';
    if (attachmentId.isEmpty || cipherByteSize < 1 || cipherSha256.isEmpty) {
      throw StateError('Chat 本地待发送附件密文元数据无效');
    }
    final staged = await _pendingAttachmentUploadFile(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    final uploaded = await _pendingAttachmentUploadedMarker(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    if (!await uploaded.exists()) {
      if (!await staged.exists() || await staged.length() != cipherByteSize) {
        throw StateError('Chat 本地待上传附件密文缺失');
      }
      try {
        await context.transport.uploadEncryptedAttachment(
          attachmentId: attachmentId,
          recipientCidNumbers: <String>[pending.recipientCidNumber],
          cipherFile: staged,
          cipherByteSize: cipherByteSize,
          cipherSha256: cipherSha256,
        );
        await uploaded.writeAsString('uploaded', flush: true);
      } catch (_) {
        await context.transport
            .abortAttachment(attachmentId)
            .catchError((Object _) {});
        rethrow;
      }
      try {
        await staged.delete();
      } catch (_) {
        // 已持久写入上传标记后，缓存清理失败不能撤销已经可投递的远端密文。
      }
    }
    await flow.sendMediaControl(
      conversationId: pending.conversationId,
      senderCidNumber: context.account.cidNumber,
      recipientCidNumber: pending.recipientCidNumber,
      senderDeviceId: context.deviceId,
      recipientKeyPackage: keyPackage,
      media: content,
      pendingLocalMessageId: pending.localMessageId,
      createdAtMillis: pending.createdAtMillis,
    );
    if (await uploaded.exists()) await uploaded.delete();
  }

  Future<void> _sendPendingGroupMedia(
    _ChatAccountContext context,
    ChatPendingOutgoingMessage pending,
    ChatContent content,
  ) async {
    final attachmentId = content.attachmentId ?? '';
    final cipherByteSize = content.cipherByteSize ?? -1;
    final cipherSha256 = content.cipherSha256 ?? '';
    if (attachmentId.isEmpty || cipherByteSize < 1 || cipherSha256.isEmpty) {
      throw StateError('Chat 群待发送附件密文元数据无效');
    }
    final flow = _groupFlow(context);
    final recipients = await flow.recipientCidNumbers(
      groupId: pending.conversationId,
      senderCidNumber: context.account.cidNumber,
    );
    final staged = await _pendingAttachmentUploadFile(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    final uploaded = await _pendingAttachmentUploadedMarker(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    if (!await uploaded.exists()) {
      if (!await staged.exists() || await staged.length() != cipherByteSize) {
        throw StateError('Chat 群待上传附件密文缺失');
      }
      try {
        await context.transport.uploadEncryptedAttachment(
          attachmentId: attachmentId,
          recipientCidNumbers: recipients,
          cipherFile: staged,
          cipherByteSize: cipherByteSize,
          cipherSha256: cipherSha256,
        );
        await uploaded.writeAsString('uploaded', flush: true);
      } catch (_) {
        await context.transport
            .abortAttachment(attachmentId)
            .catchError((Object _) {});
        rethrow;
      }
      try {
        await staged.delete();
      } catch (_) {
        // 上传标记是远端成功真值，缓存清理留给会话删除统一收口。
      }
    }
    await flow.sendGroupMediaControl(
      groupId: pending.conversationId,
      senderCidNumber: context.account.cidNumber,
      senderDeviceId: context.deviceId,
      content: content,
      pendingLocalMessageId: pending.localMessageId,
      createdAtMillis: pending.createdAtMillis,
    );
    if (await uploaded.exists()) await uploaded.delete();
  }

  Future<int> _retryQueuedEnvelopes(
    _ChatAccountContext context, {
    String? recipientCidNumber,
    String? conversationId,
  }) async {
    final queued = await _store.readQueuedEnvelopes(
      bindingToken: context.bindingToken,
      ownerCidNumber: context.account.cidNumber,
      recipientCidNumber: recipientCidNumber,
      conversationId: conversationId,
    );
    var sent = 0;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    for (final item in queued) {
      ChatEnvelope envelope;
      try {
        envelope = ChatEnvelope.fromBuffer(item.envelopeBytes);
      } catch (_) {
        await _store.markOutgoingDelivery(
          bindingToken: context.bindingToken,
          ownerCidNumber: context.account.cidNumber,
          envelopeId: item.envelopeId,
          state: ChatMessageDeliveryState.failed,
          errorMessage: 'chat_envelope_invalid',
        );
        continue;
      }
      if (envelope.createdAtMillis.toInt() + envelope.ttlMillis.toInt() <=
          nowMillis) {
        // 七天 TTL 是原信封的固定终点；过期后直接失败并清队列，禁止继续请求
        // CitizenServe，也禁止重试时给旧消息续期。
        await _store.markOutgoingDelivery(
          bindingToken: context.bindingToken,
          ownerCidNumber: context.account.cidNumber,
          envelopeId: item.envelopeId,
          state: ChatMessageDeliveryState.failed,
          errorMessage: 'chat_envelope_expired',
        );
        continue;
      }
      final result = await context.transport.sendEncryptedEnvelope(
        envelopeId: item.envelopeId,
        envelopeBytes: item.envelopeBytes,
        recipientCidNumber: item.recipientCidNumber,
      );
      await _store.markOutgoingDelivery(
        bindingToken: context.bindingToken,
        ownerCidNumber: context.account.cidNumber,
        envelopeId: item.envelopeId,
        state: result.state,
        errorMessage: result.errorMessage,
      );
      if (result.state == ChatMessageDeliveryState.sent) sent += 1;
    }
    return sent;
  }

  /// 接收端下载、验哈希和解密成功后，把明文重新写入账户绑定的本机加密缓存。
  Future<void> _saveReceivedAttachmentToCacheMutation({
    required ChatBindingFenceToken bindingToken,
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String filePath,
    required int byteSize,
  }) async {
    final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
    await ChatFlow.acceptReceivedMediaToCache(
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: contentType,
      tempFilePath: filePath,
      byteSize: byteSize,
      cacheDirectory: cacheDirectory,
      attachmentKey: await _attachmentKeyForBinding(bindingToken),
      plainDirectory: await _plainDirectoryForBinding(bindingToken),
    );
  }

  Future<void> _copySentAttachmentToCacheMutation({
    required ChatBindingFenceToken bindingToken,
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String sourcePath,
    required int byteSize,
  }) async {
    final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
    await ChatFlow.importAttachmentFileToCache(
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: contentType,
      sourcePath: sourcePath,
      byteSize: byteSize,
      moveSource: false,
      cacheDirectory: cacheDirectory,
      attachmentKey: await _attachmentKeyForBinding(bindingToken),
      plainDirectory: await _plainDirectoryForBinding(bindingToken),
    );
  }

  Future<Future<void> Function()?> startRealtimeSync({
    required Future<void> Function() onNotice,
    Future<void> Function()? onDisconnected,
    bool retryOutgoingOnConnect = true,
  }) async {
    _ensureActive();
    final account = await _readAccount();
    if (_blockedAccountIds.contains(account.accountId)) {
      throw StateError('Chat 账户上下文正在失效，禁止启动实时会话');
    }
    final hub = _realtimeHubs.putIfAbsent(
      account.accountId,
      () => _ChatRealtimeHub(account),
    );
    if (hub.account.cidNumber != account.cidNumber ||
        hub.account.bindingRevision != account.bindingRevision) {
      await _closeRealtimeHub(hub);
      return startRealtimeSync(
        onNotice: onNotice,
        onDisconnected: onDisconnected,
        retryOutgoingOnConnect: retryOutgoingOnConnect,
      );
    }
    final listener = _ChatRealtimeListener(
      onNotice: onNotice,
      onDisconnected: onDisconnected,
    );
    hub.listeners.add(listener);
    hub.retryOutgoingOnConnect =
        hub.retryOutgoingOnConnect || retryOutgoingOnConnect;
    try {
      if (!await _ensureRealtimeHubConnected(hub)) {
        // 初次网络失败也保留前台订阅，由同一Hub退避重连；禁止依赖下一次页面进入。
        _scheduleRealtimeHubReconnect(hub);
      }
    } catch (_) {
      // 会话刷新、设备证明或连接初始化的瞬时失败也必须保留订阅；否则某一平台
      // 首次启动失败后会在整个前台周期永久失去信令连接。
      _scheduleRealtimeHubReconnect(hub);
    }
    var active = true;
    return () async {
      if (!active) return;
      active = false;
      hub.listeners.remove(listener);
      if (hub.listeners.isEmpty) await _closeRealtimeHub(hub);
    };
  }

  /// 系统点击通知时直接收敛发送方；失败由AppShell持久保存，等待下一次WSS重连。
  Future<void> handleWakeSender(String senderCidNumber) async {
    if (senderCidNumber.isEmpty) return;
    final context = await _readyContext(await _readAccount());
    await _convergeWithWakeSender(context, senderCidNumber);
  }

  Future<bool> _ensureRealtimeHubConnected(_ChatRealtimeHub hub) {
    if (hub.closed || hub.listeners.isEmpty) return Future<bool>.value(false);
    if (hub.stopPhysical != null) return Future<bool>.value(true);
    final existing = hub.connecting;
    if (existing != null) return existing;
    late final Future<bool> created;
    created = _connectRealtimeHub(hub).whenComplete(() {
      if (identical(hub.connecting, created)) hub.connecting = null;
    });
    hub.connecting = created;
    return created;
  }

  Future<bool> _connectRealtimeHub(_ChatRealtimeHub hub) async {
    final session = _ChatRealtimeSession(
      accountId: hub.account.accountId,
      ownerCidNumber: hub.account.cidNumber,
    );
    _realtimeSessions.add(session);
    final physical = await _startRealtimeSync(
      session: session,
      account: hub.account,
      onNotice: () => _notifyRealtimeHub(hub, disconnected: false),
      onDisconnected: () async {
        // 当前回调仍登记在 session 中，不能在这里同步 dispose 自己；放到下一个
        // microtask 后，session callback 先正常退出，再关闭旧资源并开始退避重连。
        scheduleMicrotask(() => unawaited(_handleRealtimeHubDisconnected(hub)));
      },
      retryOutgoingOnConnect: hub.retryOutgoingOnConnect,
      onTransportChanged: (transport) => hub.transport = transport,
    );
    if (physical == null) return false;
    if (hub.closed || hub.listeners.isEmpty) {
      hub.transport = null;
      await physical.stop();
      return false;
    }
    hub.transport = physical.transport;
    hub.stopPhysical = physical.stop;
    hub.reconnectAttempt = 0;
    return true;
  }

  Future<void> _notifyRealtimeHub(
    _ChatRealtimeHub hub, {
    required bool disconnected,
  }) async {
    final listeners = hub.listeners.toList(growable: false);
    for (final listener in listeners) {
      try {
        if (disconnected) {
          await listener.onDisconnected?.call();
        } else {
          await listener.onNotice();
        }
      } catch (_) {
        // 一个页面已销毁或刷新失败不得中断其它订阅者与物理连接。
      }
    }
  }

  Future<void> _handleRealtimeHubDisconnected(_ChatRealtimeHub hub) async {
    if (hub.closed || !identical(_realtimeHubs[hub.account.accountId], hub)) {
      return;
    }
    // 极短连接可能在 `_connectRealtimeHub` 交接 stop closure 前就触发 onDone；
    // 先等本次连接 Future 收口，避免漏关已经返回但尚未登记的物理 session。
    if (hub.stopPhysical == null && hub.connecting != null) {
      try {
        await hub.connecting;
      } catch (_) {}
    }
    final stop = hub.stopPhysical;
    hub.stopPhysical = null;
    hub.transport = null;
    if (stop != null) {
      try {
        await stop();
      } catch (_) {
        // 旧 socket 已经断开；清理失败由 Runtime 终态的 session 集合再次兜底。
      }
    }
    await _notifyRealtimeHub(hub, disconnected: true);
    _scheduleRealtimeHubReconnect(hub);
  }

  void _scheduleRealtimeHubReconnect(_ChatRealtimeHub hub) {
    if (hub.closed || hub.listeners.isEmpty || hub.reconnectTimer != null) {
      return;
    }
    final exponent = hub.reconnectAttempt.clamp(0, 5);
    final delay = Duration(seconds: 1 << exponent);
    hub.reconnectAttempt += 1;
    hub.reconnectTimer = Timer(delay, () {
      hub.reconnectTimer = null;
      unawaited(() async {
        try {
          if (!await _ensureRealtimeHubConnected(hub)) {
            _scheduleRealtimeHubReconnect(hub);
          }
        } catch (_) {
          _scheduleRealtimeHubReconnect(hub);
        }
      }());
    });
  }

  Future<void> _closeRealtimeHub(_ChatRealtimeHub hub) async {
    if (hub.closed) return;
    hub.closed = true;
    hub.reconnectTimer?.cancel();
    hub.reconnectTimer = null;
    hub.listeners.clear();
    if (identical(_realtimeHubs[hub.account.accountId], hub)) {
      _realtimeHubs.remove(hub.account.accountId);
    }
    try {
      await hub.connecting;
    } catch (_) {
      // connect 自身失败时 `_startRealtimeSync` 已回收尚未交接的 session。
    }
    final stop = hub.stopPhysical;
    hub.stopPhysical = null;
    hub.transport = null;
    if (stop != null) await stop();
  }

  Future<_ChatRealtimePhysical?> _startRealtimeSync({
    required _ChatRealtimeSession session,
    required _ChatAccount account,
    required Future<void> Function() onNotice,
    required Future<void> Function()? onDisconnected,
    required bool retryOutgoingOnConnect,
    required void Function(ChatCloudTransport? transport) onTransportChanged,
  }) async {
    var handedOff = false;
    ChatCloudTransport? looseSignalTransport;
    try {
      final signalContext = await _buildSignalContext(account);
      looseSignalTransport = signalContext.transport;
      _ensureActive();
      session.ensureOpen();

      Future<void> handleMessage(Map<String, dynamic> message) {
        return session.runCallback(() async {
          try {
            await _runRuntimeOperation(() async {
              final type = message['type'];
              if (type == 'citizen_chat_signal') {
                final senderCidNumber = message['sender_cid_number'];
                if (senderCidNumber is! String || senderCidNumber.isEmpty) {
                  return;
                }
                final context = await _readyContext(account);
                if (message['signal_kind'] == 'peer_ready') {
                  await retryOutgoing(recipientCidNumber: senderCidNumber);
                } else {
                  await context.webrtc.handleSignal(senderCidNumber, message);
                }
              } else if (type == 'citizen_chat_envelope') {
                await _consumeMailboxEnvelope(
                  account,
                  signalContext.transport,
                  ChatMailboxEnvelope.fromJson(
                    message,
                    localCidNumber: account.cidNumber,
                    realtime: true,
                  ),
                );
              }
            });
          } catch (_) {
            // socket 回调无上层 await 者；只记录安全阶段码，正文、CID 与 SDP 均不入日志。
            signalContext.transport.lastRealtimeDiagnosticCode =
                'chat_signal_handle_failed';
          }
        });
      }

      Future<void> handleDisconnected() {
        return session.runCallback(() async {
          final callback = onDisconnected;
          if (callback == null) return;
          try {
            await _runRuntimeOperation(callback);
          } catch (_) {
            // 擦除终态后不再交付断开回调。
          }
        });
      }

      session.ensureOpen();
      // 注册长寿命 socket callback 时不能处于 CID Zone；每次 callback 由 session
      // registry 跟踪，并在其内部显式取得 binding lease。
      final stopSocket = await signalContext.transport.connectRealtime(
        onMessage: handleMessage,
        onDisconnected: onDisconnected == null ? null : handleDisconnected,
      );
      if (stopSocket == null) return null;
      // disposer 必须在任何可能抛错的后验检查前同步接管新 socket。
      final signalTransport = signalContext.transport;
      session.attachSocket(() async {
        try {
          await stopSocket();
        } finally {
          signalTransport.dispose();
        }
      });
      looseSignalTransport = null;
      onTransportChanged(signalTransport);
      _ensureActive();
      session.ensureOpen();

      // 先建立 WSS 再补拉，避免 GET 与建连之间产生离线窗口；在线帧和补拉重复由
      // envelope_id 去重，且只有本机 OpenMLS/数据库事务成功后才确认删除云端密文。
      for (final envelope in await signalTransport.fetchMailbox()) {
        await _consumeMailboxEnvelope(account, signalTransport, envelope);
      }

      Future<void> notifySenderReadyFromCallback(String sender) async {
        await session.runCallback(() async {
          try {
            await _runRuntimeOperation(() async {
              final context = await _readyContext(account);
              await _convergeWithWakeSender(context, sender);
            });
          } catch (_) {
            // 该 sender 仍由本机待发队列/下次推送驱动重试。
          }
        });
      }

      Future<void> refreshPushFromCallback() async {
        await session.runCallback(() async {
          try {
            await _runRuntimeOperation(
              () async => _ensurePushEndpoint(
                account: signalContext.account,
                identity: signalContext.identity,
                prefs: await _prefs,
                transport: signalContext.transport,
              ),
            );
          } catch (_) {
            // 终态不得回写 Token，普通失败等下次 token 变化。
          }
        });
      }

      final pushSubscription = _pushService.wakeSenders.listen(
        (sender) => unawaited(notifySenderReadyFromCallback(sender)),
      );
      session.attachWakeSubscription(pushSubscription.cancel);
      final pendingSenders = await _pushService.takePendingWakeSenders();
      _ensureActive();
      for (final sender in pendingSenders) {
        final context = await _readyContext(account);
        await _convergeWithWakeSender(context, sender);
        _ensureActive();
      }
      final tokenSubscription = _pushService.tokenChanges.listen(
        (_) => unawaited(refreshPushFromCallback()),
      );
      session.attachTokenSubscription(tokenSubscription.cancel);
      // Chat Tab 与后台唤醒保留账户级补发；具体聊天窗口已经按 conversationId
      // 独立重试，建连时不得再次串行扫描并发送整个账户的队列。
      if (retryOutgoingOnConnect) {
        await retryOutgoing();
      }
      _ensureActive();
      session.ensureOpen();
      handedOff = true;
      return _ChatRealtimePhysical(
        stop: () => _disposeRealtimeSession(session),
        transport: signalTransport,
      );
    } finally {
      looseSignalTransport?.dispose();
      session.markInitializationDone();
      if (!handedOff) {
        onTransportChanged(null);
        await _disposeRealtimeSession(session);
      }
    }
  }

  Future<_ChatSignalContext> _buildSignalContext(_ChatAccount account) async {
    final prefs = await _prefs;
    final deviceIdKey = deviceIdPreferenceKey(account.cidNumber);
    var deviceId = prefs.getString(deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'chat-${_newNonce()}';
      await prefs.setString(deviceIdKey, deviceId);
    }
    final identity = ChatDevice(
      cidNumber: account.cidNumber,
      deviceId: deviceId,
      devicePublicKey: prefs.getString(
              devicePublicKeyCachePreferenceKey(account.cidNumber)) ??
          '',
    );
    final service = await _ensureServiceReady(
      account: account,
      identity: identity,
      prefs: prefs,
    );
    return _ChatSignalContext(
      account: account,
      identity: identity,
      transport: service.transport,
    );
  }

  Future<bool> _sendRealtimeSignal(
    _ChatAccount account, {
    required String recipientCidNumber,
    required Map<String, Object?> signal,
  }) async {
    final hub = _realtimeHubs[account.accountId];
    if (hub == null ||
        hub.closed ||
        hub.account.cidNumber != account.cidNumber ||
        hub.account.bindingRevision != account.bindingRevision) {
      throw StateError('Chat 账户级 WSS 尚未启动');
    }
    if (hub.transport == null && hub.listeners.isNotEmpty) {
      await _ensureRealtimeHubConnected(hub);
    }
    final transport = hub.transport;
    if (transport == null) throw StateError('Chat 账户级 WSS 尚未连接');
    return transport.sendSignal(
      recipientCidNumber: recipientCidNumber,
      signal: signal,
    );
  }

  Future<void> _consumeMailboxEnvelope(
    _ChatAccount account,
    ChatCloudTransport transport,
    ChatMailboxEnvelope item,
  ) async {
    final receiptKey = '${account.accountId}|${item.envelopeId}';
    var processedNow = false;
    if (!_mailboxEnvelopeReceipts.contains(receiptKey)) {
      try {
        final context = await _readyContext(account);
        await _runBindingFileMutation(
          context.bindingToken,
          () => _processMailboxEnvelope(
            context,
            item.senderCidNumber,
            item.envelopeBytes,
          ),
        );
        _mailboxEnvelopeReceipts.add(receiptKey);
        processedNow = true;
        // 单邮箱最多 1000 条；保留四倍窗口足以覆盖 ACK 瞬时失败，同时限制内存。
        while (_mailboxEnvelopeReceipts.length > 4000) {
          _mailboxEnvelopeReceipts.remove(_mailboxEnvelopeReceipts.first);
        }
      } catch (_) {
        _mailboxEnvelopeReceipts.remove(receiptKey);
        rethrow;
      }
    }
    if (processedNow) {
      _scheduleIncomingConvergence(account, item.senderCidNumber);
    }
    await transport.acknowledgeMailbox(<String>[item.envelopeId]);
  }

  /// 新密文完成本机验密落盘后，按发送方合并一次反向收敛。该任务不阻塞邮箱 ACK；
  /// 重复 Envelope 只确认删除云端副本，不再次触发发送或形成 peer_ready 风暴。
  void _scheduleIncomingConvergence(
    _ChatAccount account,
    String senderCidNumber,
  ) {
    if (senderCidNumber.isEmpty) return;
    final key = '${account.accountId}|$senderCidNumber';
    if (!_incomingConvergenceInFlight.add(key)) return;
    unawaited(
      _runRuntimeOperation(() async {
        final current = await _readAccount(
          expectedAccountId: account.accountId,
        );
        final context = await _readyContext(current);
        await _convergeWithWakeSender(context, senderCidNumber);
      }).catchError((Object _) {
        // 本机可靠队列保留到下一次 WSS、推送或心跳收敛。
      }).whenComplete(() {
        _incomingConvergenceInFlight.remove(key);
      }),
    );
  }

  /// 任一端收到无内容唤醒，都先发送peer_ready，再检查本机待发队列。
  Future<void> _convergeWithWakeSender(
    _ChatAccountContext context,
    String senderCidNumber,
  ) async {
    if (senderCidNumber.isEmpty) return;
    try {
      await _runBindingFileMutation(
        context.bindingToken,
        () => _sendRealtimeSignal(
          context.account,
          recipientCidNumber: senderCidNumber,
          signal: const <String, Object?>{'signal_kind': 'peer_ready'},
        ),
      );
    } catch (_) {
      // 反向信令失败仍检查本机队列，自己的Offer也可能直接连通对端。
    }
    await retryOutgoing(recipientCidNumber: senderCidNumber);
  }

  Future<_ChatAccountContext> _readyContext(_ChatAccount account) async {
    _ensureActive();
    if (_blockedAccountIds.contains(account.accountId)) {
      return Future<_ChatAccountContext>.error(
        StateError('Chat 账户上下文正在失效，禁止重新初始化'),
      );
    }
    final knownKey = _accountContextKeys[account.accountId];
    final cached = knownKey == null ? null : _readyContexts[knownKey];
    if (cached != null && cached.isUsable) {
      return cached;
    }
    if (knownKey != null) {
      // session 过期也必须走完整失效屏障：停实时回调、排空旧 CID action、关闭
      // WebRTC/crypto 后才允许同一 MlsStateStore 建立新上下文。
      await _invalidateAccountContext(account.accountId, keepBlocked: false);
      return _readyContext(account);
    }

    final flightKey =
        '${account.cidNumber}|${account.bindingRevision}|${account.accountId}';
    final existing = _readyFlights[flightKey];
    if (existing != null) {
      return existing;
    }

    final generation = _accountGenerations[account.accountId] ?? 0;
    late final Future<_ChatAccountContext> created;
    created = _buildAccountContext(account).then((context) async {
      if (_processWipeRequested ||
          _closedForWipe ||
          (_accountGenerations[account.accountId] ?? 0) != generation) {
        await _disposeContext(context);
        throw StateError('CID 当前绑定已切换，本次旧初始化结果已丢弃');
      }
      final contextKey = _contextKey(
        context.account,
        context.identity,
        context.bindingToken,
      );
      final previousKey = _accountContextKeys[account.accountId];
      if (previousKey != null && previousKey != contextKey) {
        final previous = _readyContexts.remove(previousKey);
        if (previous != null) await _disposeContext(previous);
      }
      _accountContextKeys[account.accountId] = contextKey;
      _readyContexts[contextKey] = context;
      return context;
    }).whenComplete(() {
      if (identical(_readyFlights[flightKey], created)) {
        _readyFlights.remove(flightKey);
      }
    });
    _readyFlights[flightKey] = created;
    return created;
  }

  Future<_ChatAccountContext> _buildAccountContext(_ChatAccount account) async {
    final bindingToken = await _convergeBindingFence(account);
    return _runBindingFileMutation(
      bindingToken,
      () => _buildAccountContextForBinding(account, bindingToken),
    );
  }

  Future<_ChatAccountContext> _buildAccountContextForBinding(
    _ChatAccount account,
    ChatBindingFenceToken bindingToken,
  ) async {
    final prefs = await _prefs;
    final deviceIdKey = deviceIdPreferenceKey(account.cidNumber);
    final devicePublicKeyCacheKey = devicePublicKeyCachePreferenceKey(
      account.cidNumber,
    );
    var deviceId = prefs.getString(deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'chat-${_newNonce()}';
      await prefs.setString(deviceIdKey, deviceId);
    }

    final cachedDevicePublicKey =
        prefs.getString(devicePublicKeyCacheKey) ?? '';
    final stateStore = await _stateStore(
      _bindingForAccount(account),
      deviceId,
    );
    ChatCloudTransport? transport;
    var keepStateStore = false;
    try {
      final bootstrapIdentity = ChatDevice(
        cidNumber: account.cidNumber,
        deviceId: deviceId,
        devicePublicKey:
            cachedDevicePublicKey.isEmpty ? '00' : cachedDevicePublicKey,
      );
      final identityReader = _cryptoFactory?.call(
              bootstrapIdentity, stateStore) ??
          NativeMlsCrypto(identity: bootstrapIdentity, stateStore: stateStore);
      final devicePublicKey = await identityReader.readDevicePublicKey(
        bootstrapIdentity,
      );
      if (devicePublicKey.isEmpty) {
        throw const MlsNativeException(
          MlsNativeErrorCode.invalidResponse,
          'OpenMLS native 未返回 Chat 设备公钥',
        );
      }
      if (cachedDevicePublicKey.isNotEmpty &&
          cachedDevicePublicKey.toLowerCase() !=
              devicePublicKey.toLowerCase()) {
        // MLS 设备公钥轮换只影响本机状态；推送端点由会话设备键和 Token 独立维护。
      }
      await prefs.setString(devicePublicKeyCacheKey, devicePublicKey);
      final identity = ChatDevice(
        cidNumber: account.cidNumber,
        deviceId: deviceId,
        devicePublicKey: devicePublicKey,
      );
      final finalCrypto = _cryptoFactory?.call(identity, stateStore) ??
          NativeMlsCrypto(identity: identity, stateStore: stateStore);
      final service = await _ensureServiceReady(
        account: account,
        identity: identity,
        prefs: prefs,
      );
      transport = service.transport;
      final fencedCrypto = _ChatBindingFencedMlsCrypto(
        runtime: this,
        bindingToken: bindingToken,
        delegate: finalCrypto,
      );
      late final _ChatAccountContext context;
      final webrtc = ChatWebrtcTransport(
        accountId: account.accountId,
        localCidNumber: account.cidNumber,
        cloud: transport,
        sendSignal: ({required recipientCidNumber, required signal}) =>
            _sendRealtimeSignal(
          account,
          recipientCidNumber: recipientCidNumber,
          signal: signal,
        ),
        runBindingMutation: <T>(Future<T> Function() operation) =>
            _runBindingFileMutation(bindingToken, operation),
        createKeyPackage: () => _createDirectKeyPackage(context),
      );
      keepStateStore = true;
      context = _ChatAccountContext(
        account: account,
        bindingToken: bindingToken,
        deviceId: deviceId,
        devicePublicKey: identity.devicePublicKey,
        crypto: fencedCrypto,
        transport: transport,
        webrtc: webrtc,
        sessionExpiresAt: service.session.expiresAt,
      );
      return context;
    } finally {
      if (!keepStateStore) {
        transport?.dispose();
        stateStore.dispose();
      }
    }
  }

  Future<_ChatServiceContext> _ensureServiceReady({
    required _ChatAccount account,
    required ChatDevice identity,
    required SharedPreferences prefs,
  }) async {
    // 这是用户实际进入 Chat 后的会话需求：已有 P-256 子钥静默登录；Worker 明确报告
    // device_not_registered 时才鉴权一次生成并登记。普通 App 启动不预热 Chat。
    var session = await _squareApiClient.ensureSession(
      accountId: account.accountId,
      signLoginPayload: (context, payload) =>
          _signSquareLoginPayload(context, payload, expected: account),
      onDeviceNotRegistered: _registerMissingDeviceSubkey,
    );
    if (session.cidNumber != account.cidNumber ||
        session.bindingRevision != account.bindingRevision ||
        session.accountId != account.accountId) {
      _squareApiClient.clearSession(account.accountId);
      session = await _squareApiClient.ensureSession(
        accountId: account.accountId,
        signLoginPayload: (context, payload) =>
            _signSquareLoginPayload(context, payload, expected: account),
        onDeviceNotRegistered: _registerMissingDeviceSubkey,
      );
    }
    if (session.cidNumber != account.cidNumber ||
        session.bindingRevision != account.bindingRevision ||
        session.accountId != account.accountId) {
      throw StateError('聊天会话与 Cloudflare 当前用户投影不一致');
    }
    final transport = _cloudTransportFactory?.call(
          accountId: account.accountId,
          localCidNumber: account.cidNumber,
          localDeviceId: identity.deviceId,
          serviceBaseUrl: _squareApiClient.baseUri,
          sessionToken: session.sessionToken,
        ) ??
        ChatCloudTransport(
          accountId: account.accountId,
          localCidNumber: account.cidNumber,
          localDeviceId: identity.deviceId,
          serviceBaseUrl: _squareApiClient.baseUri,
          sessionToken: session.sessionToken,
          requestSigner: session.signRequest,
        );
    try {
      await _ensurePushEndpoint(
        account: account,
        identity: identity,
        prefs: prefs,
        transport: transport,
      );
    } catch (_) {
      // CID 会话与前台 WebRTC 建连不能被 APNs/FCM Token 暂时不可用阻断。
      // 唤醒端点只提高“对端 App 未运行”时的可达性，后续 Token 回调和重连会重试。
    }
    return _ChatServiceContext(
      baseUri: _squareApiClient.baseUri,
      session: session,
      transport: transport,
    );
  }

  Future<void> _ensurePushEndpoint({
    required _ChatAccount account,
    required ChatDevice identity,
    required SharedPreferences prefs,
    required ChatCloudTransport transport,
  }) async {
    final pushCacheKey = _pushRegistrationCacheKey(account, identity);
    final expiresCacheKey = '$pushCacheKey.expires_at';
    final cachedExpiresAt = prefs.getInt(expiresCacheKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedPushRegistration = prefs.getString(pushCacheKey) ?? '';
    ChatPushToken? pushToken;
    if (cachedExpiresAt - _pushEndpointRefreshSkewMillis > now &&
        cachedPushRegistration.isNotEmpty) {
      try {
        pushToken = await _readPushToken();
      } catch (_) {
        // 已有未临期推送端点时，平台暂时取不到 Token 不能让整个 Chat 上下文失效。
        return;
      }
      // 本机缓存只能证明上一次输入相同，不能证明 CitizenServe 端点仍存在。
      // Token 可读时继续幂等登记，修复服务端删除失效端点后的永久失联。
      // Token 可读时始终继续幂等登记，不能用本机缓存推断服务端端点仍存在。
    }
    // 首次登记仍必须取得真实平台 Token；失败交由本地待发送
    // 队列保留消息并在下一次重连重试，禁止伪造占位 Token。
    pushToken ??= await _readPushToken();

    final expiresAt = DateTime.now().toUtc().add(_pushEndpointTtl);
    await transport.registerPushEndpoint(
      pushProvider: pushToken.provider,
      pushToken: pushToken.token,
      apnsEnvironment: pushToken.apnsEnvironment,
      expiresAtMillis: expiresAt.millisecondsSinceEpoch,
    );
    await prefs.setInt(expiresCacheKey, expiresAt.millisecondsSinceEpoch);
    await prefs.setString(pushCacheKey, pushToken.registrationCacheValue);
  }

  Future<ChatPushToken> _readPushToken() {
    return _pushTokenProvider?.call() ?? _pushService.initialize();
  }

  Future<String> _signSquareLoginPayload(
    SquareLoginContext context,
    Uint8List loginMessage, {
    _ChatAccount? expected,
  }) async {
    if (expected != null &&
        (context.cidNumber != expected.cidNumber ||
            context.bindingRevision != expected.bindingRevision ||
            context.accountId != expected.accountId)) {
      throw StateError('Cloudflare 会话与当前 Chat 用户不一致');
    }
    final signer = _loginSigner;
    if (signer != null) {
      return signer(
        cidNumber: context.cidNumber,
        accountId: context.accountId,
        loginMessage: loginMessage,
      );
    }
    // 会话握手 = 非用户动权 → P-256 硬件子钥静默签名 signing_message 摘要（不读 seed、不弹生物识别）。
    final raw = await _deviceSubkey.signRawHex(
      context.cidNumber,
      loginMessage,
    );
    return '0x$raw';
  }

  Future<void> _registerMissingDeviceSubkey(
    SquareLoginContext context,
  ) async {
    final binding = await _bindingForLoginContext(context);
    await _walletManager.registerDeviceSubkeyForBinding(binding);
    _currentUser.invalidate();
  }

  Future<_ChatAccount> _readAccount({String? expectedAccountId}) {
    return _runRuntimeOperation(
      () => _readAccountInternal(expectedAccountId: expectedAccountId),
    );
  }

  Future<_ChatAccount> _readAccountInternal({
    String? expectedAccountId,
  }) async {
    _ensureActive();
    // CID 是永久身份主键；默认账户只从本机钱包顺序读取。普通 Chat 禁止链读：
    // 本机绑定命中时直接使用；首次安装/导入没有缓存时才由 Cloudflare `users`
    // Cloudflare 持久用户的登录挑战恢复当前账户绑定。
    final defaultAccount = await DefaultAccountService(
      walletManager: _walletManager,
    ).getDefaultAccount();
    if (defaultAccount == null) {
      throw StateError('请先在「我的 → 我的钱包」添加账户');
    }
    if (expectedAccountId != null &&
        defaultAccount.accountId != expectedAccountId) {
      throw StateError('身份账户已切换，请重新进入聊天');
    }
    var binding = await _walletManager.readAccountDataBindingForAccountId(
      defaultAccount.accountId,
    );
    if (binding == null) {
      final session = await _squareApiClient.ensureSession(
        accountId: defaultAccount.accountId,
        signLoginPayload: _signSquareLoginPayload,
        onDeviceNotRegistered: _registerMissingDeviceSubkey,
      );
      binding = await _bindingForLoginContext(
        SquareLoginContext(
          cidNumber: session.cidNumber,
          bindingRevision: session.bindingRevision,
          accountId: session.accountId,
        ),
      );
      await _walletManager.activateAccountDataBinding(
        genesisHash: binding.genesisHash,
        cidNumber: binding.cidNumber,
        bindingRevision: binding.bindingRevision,
        accountId: binding.accountId,
      );
      _currentUser.invalidate();
    }
    if (binding.accountId != defaultAccount.accountId) {
      throw StateError('Cloudflare 用户投影与当前默认账户不一致');
    }
    return _ChatAccount(
      walletIndex: defaultAccount.walletIndex,
      genesisHash: binding.genesisHash,
      cidNumber: binding.cidNumber,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
      walletName: defaultAccount.accountName,
    );
  }

  static AccountDataBinding _bindingForAccount(_ChatAccount account) =>
      AccountDataBinding(
        genesisHash: account.genesisHash,
        cidNumber: account.cidNumber,
        bindingRevision: account.bindingRevision,
        accountId: account.accountId,
      );

  Future<AccountDataBinding> _bindingForLoginContext(
    SquareLoginContext context,
  ) async {
    final existing = await _walletManager.readAccountDataBindingForAccountId(
      context.accountId,
    );
    if (existing != null &&
        existing.cidNumber == context.cidNumber &&
        existing.bindingRevision == context.bindingRevision) {
      return existing;
    }
    final manifest = await _bootstrapApi.fetchManifest();
    return AccountDataBinding(
      genesisHash: manifest.chain.genesisHash,
      cidNumber: context.cidNumber,
      bindingRevision: context.bindingRevision,
      accountId: context.accountId,
    );
  }

  ChatFlow _messageFlow(
    _ChatAccountContext context, {
    bool scheduleDelivery = true,
  }) {
    return ChatFlow(
      crypto: context.crypto,
      store: _store,
      bindingToken: context.bindingToken,
      ownerCidNumber: context.account.cidNumber,
      currentAccountId: context.account.accountId,
      // 待加密行批量转换时先只完成本地正式队列，再由调用方统一扫描投递，
      // 避免同一 Envelope 被后台执行器和当前重试循环同时提交。
      deliveryScheduler: scheduleDelivery
          ? (conversationId, delivery) =>
              _scheduleOutboundDelivery(context, conversationId, delivery)
          : (conversationId, delivery) {},
      deliverer: (envelope, _, recipientCidNumber) {
        return ChatFlow.deliverWithTransport(
          transport: context.transport,
          envelope: envelope,
          recipientCidNumber: recipientCidNumber,
        );
      },
      beforeIncomingStore: (envelope, content) =>
          _cacheIncomingCloudAttachment(context, envelope, content),
    );
  }

  Future<void> _cacheIncomingCloudAttachment(
    _ChatAccountContext context,
    ChatEnvelope envelope,
    ChatContent content,
  ) async {
    if (!content.isMedia) return;
    final attachmentId = content.attachmentId ?? '';
    final cacheDirectory =
        await _attachmentDirectoryForToken(context.bindingToken);
    final cachePath = ChatFlow.attachmentCachePath(
      cacheDirectory: cacheDirectory,
      conversationId: envelope.conversationId,
      attachmentId: attachmentId,
      fileName: content.fileName ?? 'attachment.bin',
    );
    if (await AttachmentVault.hasCipher(cachePath)) {
      await context.transport.acknowledgeAttachment(attachmentId);
      return;
    }
    final encodedKey = content.cipherKey ?? '';
    final cipherKey = base64Url.decode(
      encodedKey.padRight((encodedKey.length + 3) ~/ 4 * 4, '='),
    );
    if (cipherKey.length != 32) {
      throw const FormatException('Chat 附件传输密钥不合法');
    }
    final tempDirectory = Directory('${cacheDirectory.path}/.tmp');
    final cipherFile =
        File('${tempDirectory.path}/${_safePath(attachmentId)}.download');
    final plainFile =
        File('${tempDirectory.path}/${_safePath(attachmentId)}.plain');
    try {
      await context.transport.downloadEncryptedAttachment(
        attachmentId: attachmentId,
        target: cipherFile,
        expectedByteSize: content.cipherByteSize ?? 0,
        expectedSha256: content.cipherSha256 ?? '',
      );
      final digest = await crypto_hash.sha256.bind(cipherFile.openRead()).first;
      if (digest.toString() != content.cipherSha256) {
        throw const FormatException('Chat 附件密文摘要不一致');
      }
      await AttachmentVault.openTransportCipher(
        cipherSource: cipherFile,
        plainTarget: plainFile,
        key: cipherKey,
      );
      if (await plainFile.length() != content.byteSize) {
        throw const FormatException('Chat 附件明文大小不一致');
      }
      await _saveReceivedAttachmentToCacheMutation(
        bindingToken: context.bindingToken,
        conversationId: envelope.conversationId,
        attachmentId: attachmentId,
        fileName: content.fileName ?? 'attachment.bin',
        contentType: content.mime ?? 'application/octet-stream',
        filePath: plainFile.path,
        byteSize: content.byteSize ?? 0,
      );
      await context.transport.acknowledgeAttachment(attachmentId);
    } finally {
      cipherKey.fillRange(0, cipherKey.length, 0);
      if (await cipherFile.exists()) await cipherFile.delete();
      if (await plainFile.exists()) await plainFile.delete();
    }
  }

  /// CitizenServe 邮箱的唯一入站 Envelope 边界；服务端路由身份与密文内身份必须一致。
  Future<List<String>> _processMailboxEnvelope(
    _ChatAccountContext context,
    String senderCidNumber,
    List<int> envelopeBytes,
  ) async {
    final envelope = ChatEnvelope.fromBuffer(envelopeBytes);
    if (envelope.senderCidNumber != senderCidNumber ||
        envelope.recipientCidNumber != context.account.cidNumber) {
      throw const FormatException('Chat 邮箱路由与 Envelope 身份不一致');
    }
    final isApplication = envelope.mlsMessageKind ==
        MlsWireMessageKind.MLS_WIRE_MESSAGE_KIND_APPLICATION;
    final alreadyStored = isApplication &&
        await _store.hasIncomingEnvelope(
          bindingToken: context.bindingToken,
          ownerCidNumber: context.account.cidNumber,
          envelopeId: envelope.envelopeId,
          senderCidNumber: senderCidNumber,
        );
    final accepted = <ChatEnvelope>[];
    if (alreadyStored) {
      // 邮箱按至少一次投递；重复应用 Envelope 不得再次推进 MLS。
      accepted.add(envelope);
    } else if (envelope.conversationId.startsWith('grp:')) {
      accepted.addAll(
        await _groupFlow(context).processIncomingGroupEnvelope(envelopeBytes),
      );
    } else {
      final result = await _messageFlow(context)
          .processIncomingEnvelopeBytes(envelopeBytes);
      accepted.addAll(result.acceptedEnvelopes);
    }
    final hub = _realtimeHubs[context.account.accountId];
    if (hub != null && !hub.closed) {
      await _notifyRealtimeHub(hub, disconnected: false);
    }
    return accepted
        .where((item) =>
            item.mlsMessageKind ==
            MlsWireMessageKind.MLS_WIRE_MESSAGE_KIND_APPLICATION)
        .map((item) => item.envelopeId)
        .toList(growable: false);
  }

  Future<MlsKeyPackage> _createDirectKeyPackage(
    _ChatAccountContext context,
  ) async {
    final keyPackage = await context.crypto.createKeyPackage(
      context.identity,
      lastResort: false,
    );
    if (keyPackage.cidNumber != context.account.cidNumber ||
        keyPackage.deviceId != context.deviceId ||
        keyPackage.devicePublicKey.toLowerCase() !=
            context.devicePublicKey.toLowerCase()) {
      throw const MlsNativeException(
        MlsNativeErrorCode.invalidResponse,
        'OpenMLS KeyPackage 与当前本机 CID 设备身份不一致',
      );
    }
    return keyPackage;
  }

  Future<MlsStateStore> _stateStore(
    AccountDataBinding binding,
    String deviceId,
  ) async {
    binding.validate();
    final factory = _stateStoreFactory;
    if (factory != null) {
      return factory(binding.cidNumber, deviceId);
    }
    final bindingDirectory = await _bindingDirectory(
      cidNumber: binding.cidNumber,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
    );
    final safeDevice = _safePath(deviceId);
    // MLS 状态（设备签名私钥 + 群 ratchet 秘密）落盘必须加密：已有 mls 用途钥从
    // 设备数据钥金库静默解封，真实缺钥时才鉴权一次生成。
    return MlsStateStore(
      Directory('${bindingDirectory.path}/mls/$safeDevice'),
      ownerCidNumber: binding.cidNumber,
      stateKey: (await _walletManager.readDataKeysForBinding(
        binding,
        const <({LocalKeyPurpose purpose, String? context})>[
          (purpose: LocalKeyPurpose.mls, context: null),
        ],
      ))
          .single,
    );
  }
}

class _ChatServiceContext {
  const _ChatServiceContext({
    required this.baseUri,
    required this.session,
    required this.transport,
  });

  final Uri baseUri;
  final SquareSession session;
  final ChatCloudTransport transport;
}

enum _ChatFileHandoverState {
  staged,
  committing;

  static _ChatFileHandoverState fromName(Object? value) {
    for (final state in values) {
      if (state.name == value) return state;
    }
    throw const FormatException('Chat 文件交接 receipt 状态损坏');
  }
}

@immutable
class _ChatFileHandoverInventoryItem {
  const _ChatFileHandoverInventoryItem({
    required this.relativePath,
    required this.byteSize,
    required this.sha256,
  });

  final String relativePath;
  final int byteSize;
  final String sha256;

  Map<String, Object> toJson() => <String, Object>{
        'relative_path': relativePath,
        'byte_size': byteSize,
        'sha256': sha256,
      };

  static _ChatFileHandoverInventoryItem fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value.keys.toSet().difference(<String>{
          'relative_path',
          'byte_size',
          'sha256',
        }).isNotEmpty) {
      throw const FormatException('Chat 文件交接文件清单结构损坏');
    }
    final relativePath = value['relative_path'];
    final byteSize = value['byte_size'];
    final sha256 = value['sha256'];
    if (relativePath is! String ||
        relativePath.isEmpty ||
        relativePath.startsWith('/') ||
        relativePath.split('/').any(
              (segment) => segment.isEmpty || segment == '..',
            ) ||
        byteSize is! int ||
        byteSize < 0 ||
        sha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const FormatException('Chat 文件交接文件清单内容损坏');
    }
    return _ChatFileHandoverInventoryItem(
      relativePath: relativePath,
      byteSize: byteSize,
      sha256: sha256,
    );
  }
}

@immutable
class _ChatFileHandoverReceipt {
  const _ChatFileHandoverReceipt({
    required this.state,
    required this.payloadJson,
    required this.mlsDevicePaths,
    required this.files,
  });

  final _ChatFileHandoverState state;
  final String payloadJson;
  final List<String> mlsDevicePaths;
  final List<_ChatFileHandoverInventoryItem> files;
}

bool _needsFirstKeyPackage(Object error) {
  return error.toString().contains('首次 MLS 会话必须提供');
}

String _newPendingMessageId(String conversationId, int millis) =>
    'pending:${_safePath(conversationId)}:$millis:${_newNonce()}';

String _newPendingAttachmentId(String conversationId, int millis) =>
    'attachment:${_safePath(conversationId)}:$millis:${_newNonce()}';

String _newNonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((item) => item.toRadixString(16).padLeft(2, '0')).join();
}

String _safePath(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
}

String _contextKey(
  _ChatAccount account,
  ChatDevice identity,
  ChatBindingFenceToken bindingToken,
) {
  return '${account.cidNumber}|${account.bindingRevision}|${account.accountId}|'
      '${bindingToken.genesisHash}|${bindingToken.generation}|'
      '${identity.deviceId}|'
      '${identity.devicePublicKey.toLowerCase()}';
}

String _pushRegistrationCacheKey(_ChatAccount account, ChatDevice identity) {
  return '${ChatRuntime._kPushRegistrationPrefix}.'
      '${_safePath(account.cidNumber)}.${account.bindingRevision}.'
      '${_safePath(account.accountId)}.${_safePath(identity.deviceId)}';
}
