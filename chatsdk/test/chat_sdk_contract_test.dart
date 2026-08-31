import 'package:flutter_test/flutter_test.dart';
import 'package:gmb_chat_sdk/chat_sdk.dart';

void main() {
  test('公开配置保留准确的 HTTPS 与 WSS 入口', () {
    final https = Uri.parse('https://chat.example.com');
    final wss = Uri.parse('wss://chat.example.com/chat/realtime');
    final config = ChatConfig(httpsEndpoint: https, wssEndpoint: wss);

    expect(config.httpsEndpoint, https);
    expect(config.wssEndpoint, wss);
  });

  test('启动和停止只改变同一个 ChatSDK 实例', () async {
    final identity = _Identity();
    final access = _Access();
    final chat = ChatSdk(config: _config(), identity: identity, access: access);

    await chat.start();
    await chat.start();
    expect(chat.isRunning, isTrue);
    expect(identity.accessTokenReads, 1);
    expect(access.reads, 1);

    await chat.stop();
    expect(chat.isRunning, isFalse);
  });

  test('并发启动只读取一次宿主身份', () async {
    final identity = _Identity(delay: const Duration(milliseconds: 10));
    final access = _Access();
    final chat = ChatSdk(config: _config(), identity: identity, access: access);

    await Future.wait<void>([chat.start(), chat.start(), chat.start()]);

    expect(identity.accessTokenReads, 1);
    expect(identity.userIdReads, 1);
    expect(identity.deviceIdReads, 1);
    expect(access.reads, 1);
  });

  test('权限快照按四类聊天能力查询', () {
    final capabilities = ChatCapabilities([
      ChatCapability.message,
      ChatCapability.call,
    ]);

    expect(capabilities.allows(ChatCapability.message), isTrue);
    expect(capabilities.allows(ChatCapability.attachment), isFalse);
    expect(capabilities.allows(ChatCapability.call), isTrue);
    expect(capabilities.allows(ChatCapability.extension), isFalse);
  });
}

ChatConfig _config() => ChatConfig(
  httpsEndpoint: Uri.parse('https://chat.example.com'),
  wssEndpoint: Uri.parse('wss://chat.example.com/chat/realtime'),
);

final class _Identity implements ChatIdentity {
  _Identity({this.delay = Duration.zero});

  final Duration delay;
  int accessTokenReads = 0;
  int userIdReads = 0;
  int deviceIdReads = 0;

  @override
  Future<String> accessToken() async {
    accessTokenReads += 1;
    await Future<void>.delayed(delay);
    return 'token';
  }

  @override
  Future<String> currentDeviceId() async {
    deviceIdReads += 1;
    await Future<void>.delayed(delay);
    return 'device';
  }

  @override
  Future<String> currentUserId() async {
    userIdReads += 1;
    await Future<void>.delayed(delay);
    return 'user';
  }
}

final class _Access implements ChatAccess {
  int reads = 0;

  @override
  Future<ChatCapabilities> capabilities() async {
    reads += 1;
    return ChatCapabilities(ChatCapability.values);
  }
}
