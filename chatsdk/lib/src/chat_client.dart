import 'chat_access.dart';
import 'chat_config.dart';
import 'chat_identity.dart';

/// ChatSDK 的唯一生命周期入口。
final class ChatSdk {
  ChatSdk({required this.config, required this.identity, required this.access});

  final ChatConfig config;
  final ChatIdentity identity;
  final ChatAccess access;

  Future<void>? _starting;
  bool _running = false;

  bool get isRunning => _running;

  /// 验证宿主身份后启动唯一实例；并发调用只执行一次身份读取。
  Future<void> start() async {
    if (_running) return;
    final active = _starting;
    if (active != null) return active;

    final pending = _validateAndStart();
    _starting = pending;
    try {
      await pending;
    } finally {
      if (identical(_starting, pending)) _starting = null;
    }
  }

  Future<void> _validateAndStart() async {
    final values = await Future.wait<String>([
      identity.accessToken(),
      identity.currentUserId(),
      identity.currentDeviceId(),
    ]);
    if (values.any((value) => value.trim().isEmpty)) {
      throw StateError('ChatSDK 身份信息不完整');
    }
    await access.capabilities();
    _running = true;
  }

  /// 停止当前实例；尚未启动时调用不会创建任何运行资源。
  Future<void> stop() async {
    final active = _starting;
    if (active != null) await active;
    _running = false;
  }
}
