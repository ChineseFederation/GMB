import 'dart:async';

import 'light_client.dart';
import 'sdk_log.dart';

/// 只通过 CitizenSDK 内嵌 smoldot 轻节点监听新区块头。
///
/// 该对象不拥有 [CitizenLightClient]，主动断开只取消本对象创建的订阅。
final class ChainEventSubscription {
  ChainEventSubscription({
    required CitizenLightClient lightClient,
    CitizenSdkLogger logger = discardCitizenSdkLog,
  }) : _lightClient = lightClient,
       _logger = logger;

  final CitizenLightClient _lightClient;
  final CitizenSdkLogger _logger;
  final StreamController<ChainEvent> _eventController =
      StreamController<ChainEvent>.broadcast();
  final StreamController<void> _droppedController =
      StreamController<void>.broadcast();

  StreamSubscription<Object?>? _newHeadsSub;
  StreamSubscription<Object?>? _finalizedHeadsSub;
  int _lifecycleGeneration = 0;

  Stream<ChainEvent> get events => _eventController.stream;

  /// 底层订阅意外断开的信号；主动 [disconnect] 不发送。
  Stream<void> get dropped => _droppedController.stream;

  /// 等待轻节点完整同步后同时建立 new-head 与 finalized-head 订阅。
  Future<bool> connect() async {
    final generation = _lifecycleGeneration;
    try {
      await _lightClient.ensureSynced();
    } on Object catch (error) {
      _debug('轻节点尚未就绪，订阅连接失败: $error');
      return false;
    }
    if (generation != _lifecycleGeneration) return false;

    final newHeadsOk = _connect(
      method: 'chain_subscribeNewHeads',
      type: ChainEventType.newBlock,
      logLabel: 'newHeads',
      generation: generation,
    );
    final finalizedOk = _connect(
      method: 'chain_subscribeFinalizedHeads',
      type: ChainEventType.newFinalizedBlock,
      logLabel: 'finalizedHeads',
      generation: generation,
    );
    return newHeadsOk && finalizedOk;
  }

  bool _connect({
    required String method,
    required ChainEventType type,
    required String logLabel,
    required int generation,
  }) {
    if (type == ChainEventType.newBlock && _newHeadsSub != null) return true;
    if (type == ChainEventType.newFinalizedBlock &&
        _finalizedHeadsSub != null) {
      return true;
    }

    _debug('使用 smoldot 轻节点订阅 $logLabel');
    try {
      final subscription = _lightClient
          .subscribe(method)
          .listen(
            (data) {
              int? blockNumber;
              if (data is Map) {
                final numberHex = data['number'];
                if (numberHex is String) {
                  blockNumber = int.tryParse(
                    numberHex.startsWith('0x')
                        ? numberHex.substring(2)
                        : numberHex,
                    radix: 16,
                  );
                }
              }
              _eventController.add(
                ChainEvent(type: type, blockNumber: blockNumber),
              );
            },
            onError: (Object error) {
              _debug('$logLabel 订阅错误: $error');
            },
            onDone: () {
              _debug('$logLabel 订阅结束');
              if (type == ChainEventType.newBlock) {
                _newHeadsSub = null;
              } else {
                _finalizedHeadsSub = null;
              }
              // cancel 不触发 onDone；代际检查防止停止过程中的迟到
              // 完成唤醒上层。
              if (generation != _lifecycleGeneration ||
                  _droppedController.isClosed) {
                return;
              }
              _droppedController.add(null);
            },
          );
      if (type == ChainEventType.newBlock) {
        _newHeadsSub = subscription;
      } else {
        _finalizedHeadsSub = subscription;
      }
      return true;
    } on Object catch (error) {
      _debug('$logLabel 订阅启动失败: $error');
      return false;
    }
  }

  /// 主动取消两条订阅，不产生 dropped 事件。
  void disconnect() {
    _lifecycleGeneration += 1;
    _cancelBestEffort(_newHeadsSub);
    _cancelBestEffort(_finalizedHeadsSub);
    _newHeadsSub = null;
    _finalizedHeadsSub = null;
  }

  /// 主动断开已经同步废止当前代际，取消 Future 只能非阻塞地释放资源。
  ///
  /// 第三方 Stream 可以在 `cancel()` 同步抛错或让其 Future 异步失败；两者都
  /// 不得泄漏到宿主 Zone，也不能让一个可能永不完成的取消阻塞重新连接。
  static void _cancelBestEffort(StreamSubscription<Object?>? subscription) {
    if (subscription == null) return;
    try {
      final cancellation = subscription.cancel();
      unawaited(
        cancellation.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
    } on Object {
      // best-effort：代际已失效，清理异常不能恢复先前订阅身份。
    }
  }

  void _debug(String message) {
    _logger(
      CitizenSdkLogEvent(
        level: CitizenSdkLogLevel.debug,
        scope: 'chain_event_subscription',
        message: message,
      ),
    );
  }
}

enum ChainEventType { newBlock, newFinalizedBlock }

final class ChainEvent {
  const ChainEvent({required this.type, this.blockNumber});

  final ChainEventType type;
  final int? blockNumber;
}
