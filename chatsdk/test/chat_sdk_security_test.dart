import 'package:chat_sdk/chat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('拒绝明文 HTTP 入口', () {
    expect(
      () => ChatConfig(
        httpsEndpoint: Uri.parse('http://chat.example.com'),
        wssEndpoint: Uri.parse('wss://chat.example.com/chat/realtime'),
      ),
      throwsArgumentError,
    );
  });

  test('拒绝明文 WebSocket 入口', () {
    expect(
      () => ChatConfig(
        httpsEndpoint: Uri.parse('https://chat.example.com'),
        wssEndpoint: Uri.parse('ws://chat.example.com/chat/realtime'),
      ),
      throwsArgumentError,
    );
  });

  test('拒绝空主机和相对地址', () {
    for (final invalid in [Uri.parse('https:///chat'), Uri.parse('/chat')]) {
      expect(
        () => ChatConfig(
          httpsEndpoint: invalid,
          wssEndpoint: Uri.parse('wss://chat.example.com/chat/realtime'),
        ),
        throwsArgumentError,
      );
    }
  });

  test('拒绝地址中的账户信息、查询参数和片段', () {
    for (final invalid in [
      Uri.parse('https://user:password@chat.example.com'),
      Uri.parse('https://chat.example.com?token=value'),
      Uri.parse('https://chat.example.com/#secret'),
    ]) {
      expect(
        () => ChatConfig(
          httpsEndpoint: invalid,
          wssEndpoint: Uri.parse('wss://chat.example.com/chat/realtime'),
        ),
        throwsArgumentError,
      );
    }
  });

  test('身份字段为空时拒绝启动', () async {
    final chat = ChatSdk(
      config: ChatConfig(
        httpsEndpoint: Uri.parse('https://chat.example.com'),
        wssEndpoint: Uri.parse('wss://chat.example.com/chat/realtime'),
      ),
      identity: _EmptyIdentity(),
      access: _Access(),
    );

    await expectLater(chat.start(), throwsStateError);
    expect(chat.isRunning, isFalse);
  });
}

final class _EmptyIdentity implements ChatIdentity {
  @override
  Future<String> accessToken() async => '';

  @override
  Future<String> currentDeviceId() async => 'device';

  @override
  Future<String> currentUserId() async => 'user';
}

final class _Access implements ChatAccess {
  @override
  Future<ChatCapabilities> capabilities() async =>
      ChatCapabilities(ChatCapability.values);
}
