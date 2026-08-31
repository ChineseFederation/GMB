import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gmb_chat_sdk/chat_sdk.dart';

final class _WrongProtocolSocket implements ChatServerSocket {
  final StreamController<Object?> _events = StreamController<Object?>();

  @override
  String? get protocol => null;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  void add(List<int> bytes) {}

  @override
  Future<void> close() async {
    unawaited(_events.close());
  }
}

void main() {
  test('access contract rejects paths, credentials in URL and cleartext', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final value in <String>[
      'http://chat.example.test',
      'https://user@chat.example.test',
      'https://chat.example.test/v1',
    ]) {
      expect(
        () => ChatServerAccess(
          chatServerUrl: Uri.parse(value),
          chatServerToken: 'token',
          expiresAtMillis: now + 300000,
        ).validate(now),
        throwsStateError,
      );
    }
  });

  test('missing chatserver subprotocol fails closed', () async {
    final transport = ChatServerTransport(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatServerAccess(
        chatServerUrl: Uri.parse('https://chat.example.test'),
        chatServerToken: 'token',
        expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
      ),
      socketConnector: (uri, token) async => _WrongProtocolSocket(),
    );
    await expectLater(
      transport.connect(),
      throwsA(isA<ChatServerTransportException>()),
    );
    await transport.dispose();
  });
}
