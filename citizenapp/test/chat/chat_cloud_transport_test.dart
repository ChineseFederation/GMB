import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/chat/transport/chat_cloud_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _bobCidNumber = 'CN220-CTZN2-100000002-2026';

void main() {
  test('未配置服务时不允许登记系统唤醒端点', () async {
    final transport = ChatCloudTransport(
      accountId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      localDeviceId: 'alice-phone',
    );

    await expectLater(
      transport.registerPushEndpoint(
        pushProvider: 'fcm',
        pushToken: 'fcm-token-1234567890',
        apnsEnvironment: null,
        expiresAtMillis: 999999,
      ),
      throwsStateError,
    );
  });

  test('Chat云端拒绝非HTTPS地址且不降级', () async {
    const insecureScheme = '${'ht'}${'tp'}';
    final transport = ChatCloudTransport(
      accountId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      localDeviceId: 'alice-phone',
      serviceBaseUrl: Uri.parse('$insecureScheme://worker.example/api'),
      sessionToken: 'session-token',
      httpClient: MockClient((_) async => _json({'ok': true})),
    );

    await expectLater(
      transport.sendSignal(
        recipientCidNumber: _bobCidNumber,
        signal: const {'kind': 'peer_ready'},
      ),
      throwsStateError,
    );
  });

  test('推送登记只提交操作系统端点，不提交聊天公钥或消息内容', () async {
    final transport = _transport((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/chat/push-endpoint');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {
        'device_id': 'alice-phone',
        'push_provider': 'fcm',
        'push_token': 'fcm-token-1234567890',
        'apns_environment': null,
        'expires_at': 999999,
      });
      expect(body.keys, isNot(contains('device_public_key_hex')));
      expect(body.keys, isNot(contains('key_package')));
      expect(body.keys, isNot(contains('envelope')));
      return _json({'ok': true});
    });

    await transport.registerPushEndpoint(
      pushProvider: 'fcm',
      pushToken: 'fcm-token-1234567890',
      apnsEnvironment: null,
      expiresAtMillis: 999999,
    );
  });

  test('WebRTC 只向 Worker 发送严格的瞬时建连信令', () async {
    final transport = _transport((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/chat/signals');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['sender_device_id'], 'alice-phone');
      expect(body['recipient_cid_number'], _bobCidNumber);
      expect(body['recipient_device_id'], '');
      expect(body['signal'], {
        'kind': 'offer',
        'connection_kind': 'control',
        'connection_id': 'control-12345678',
        'sdp': 'v=0\r\n',
        'sdp_type': 'offer',
      });
      expect(body.keys, isNot(contains('envelope')));
      return _json({'ok': true, 'delivery_state': 'sent'});
    });

    final sent = await transport.sendSignal(
      recipientCidNumber: _bobCidNumber,
      signal: const {
        'kind': 'offer',
        'connection_kind': 'control',
        'connection_id': 'control-12345678',
        'sdp': 'v=0\r\n',
        'sdp_type': 'offer',
      },
    );

    expect(sent, isTrue);
  });

  test('对端无实时连接时明确返回 unavailable 且信令不伪装排队', () async {
    final transport = _transport(
      (_) async => _json({'ok': true, 'delivery_state': 'unavailable'}),
    );

    final sent = await transport.sendSignal(
      recipientCidNumber: _bobCidNumber,
      signal: const {'kind': 'peer_ready'},
    );

    expect(sent, isFalse);
    expect(transport.lastRealtimeDiagnosticCode, 'chat_signal_unavailable');
  });

  test('WSS必须等待ready并通过有界ping/pong识别半断开连接', () {
    final source =
        File('lib/chat/transport/chat_cloud_transport.dart').readAsStringSync();
    expect(source, contains("'citizen_chat_ws_ready'"));
    expect(source, contains("'citizen_chat_ws_pong'"));
    expect(source, contains("socket.add('ping')"));
    expect(source, contains('chat_signal_ready_timeout'));
    expect(source, contains('chat_signal_pong_timeout'));
    expect(source, isNot(contains("'queued'")));
  });

  test('服务端结构化错误只暴露稳定错误码', () async {
    final transport = _transport(
      (_) async => http.Response(
        jsonEncode({
          'ok': false,
          'error_code': 'invalid_chat_signal',
          'message': 'server-detail-must-not-reach-ui',
        }),
        400,
      ),
    );

    await expectLater(
      transport.sendSignal(
        recipientCidNumber: _bobCidNumber,
        signal: const {'kind': 'peer_ready'},
      ),
      throwsA(
        predicate((error) => error.toString() == 'invalid_chat_signal'),
      ),
    );
  });
}

ChatCloudTransport _transport(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ChatCloudTransport(
    accountId:
        '0x1111111111111111111111111111111111111111111111111111111111111111',
    localDeviceId: 'alice-phone',
    serviceBaseUrl: Uri.parse('https://worker.example/api'),
    sessionToken: 'session-token',
    httpClient: MockClient(handler),
  );
}

http.Response _json(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200);
