import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/chat/crypto/mls_boundary.dart';
import 'package:citizenapp/chat/transport/chat_cloud_transport.dart';
import 'package:citizenapp/chat/transport/chat_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// 中文注释：本组用例固定验证云端只承载加密邮箱、ICE 配置与唯一 WSS 信令，
// 禁止恢复 HTTP 信令、明文 Envelope 或不安全协议降级。
const _aliceCidNumber = 'CN220-CTZN2-100000001-2026';
const _bobCidNumber = 'CN220-CTZN2-100000002-2026';
const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  test('未配置服务时不允许登记系统唤醒端点', () async {
    final transport = ChatCloudTransport(
      accountId: _accountId,
      localCidNumber: _aliceCidNumber,
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
      accountId: _accountId,
      localCidNumber: _aliceCidNumber,
      localDeviceId: 'alice-phone',
      serviceBaseUrl: Uri.parse('$insecureScheme://worker.example/api'),
      sessionToken: 'session-token',
      httpClient: MockClient((_) async => _json({'ok': true})),
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

  test('推送登记只提交操作系统端点，不提交聊天密文或密钥', () async {
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

  test('OpenMLS Envelope 只以端到端密文写入有界邮箱', () async {
    final envelope = _envelope();
    final bytes = envelope.writeToBuffer();
    final transport = _transport((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/chat/messages');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'envelope_id',
        'recipient_cid_number',
        'conversation_id',
        'envelope',
        'created_at_millis',
        'ttl_millis',
      });
      expect(body['envelope_id'], envelope.envelopeId);
      expect(body['recipient_cid_number'], _bobCidNumber);
      expect(body['conversation_id'], envelope.conversationId);
      expect(base64Url.decode(body['envelope'] as String), bytes);
      expect(body.keys, isNot(contains('sender_cid_number')));
      return _json({'ok': true});
    });

    final result = await transport.sendEncryptedEnvelope(
      envelopeId: envelope.envelopeId,
      envelopeBytes: bytes,
      recipientCidNumber: _bobCidNumber,
    );

    expect(result.transportType, ChatTransportType.mailbox);
    expect(result.state.name, 'sent');
  });

  test('邮箱补拉严格解析密文并以原 envelope_id 数组确认', () async {
    final envelope = _envelope();
    final encoded = base64Url.encode(envelope.writeToBuffer());
    var calls = 0;
    final transport = _transport((request) async {
      calls += 1;
      if (request.method == 'GET') {
        expect(request.url.path, '/api/chat/messages');
        return _json([
          {
            'envelope_id': envelope.envelopeId,
            'sender_cid_number': _bobCidNumber,
            'recipient_cid_number': _aliceCidNumber,
            'conversation_id': envelope.conversationId,
            'envelope': encoded,
            'created_at_millis': 1000,
            'ttl_millis': 60000,
          }
        ]);
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/api/chat/messages/ack');
      expect(jsonDecode(request.body), [envelope.envelopeId]);
      return _json({'ok': true});
    });

    final items = await transport.fetchMailbox();
    expect(items, hasLength(1));
    expect(items.single.senderCidNumber, _bobCidNumber);
    await transport.acknowledgeMailbox([items.single.envelopeId]);
    expect(calls, 2);
  });

  test('ICE配置只允许STUN且在55分钟窗口内复用', () async {
    var calls = 0;
    final transport = _transport((request) async {
      calls += 1;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/chat/ice');
      expect(jsonDecode(request.body), <String, dynamic>{});
      return _json({
        'stun_urls': ['stun:stun.cloudflare.com:3478'],
      });
    });

    final first = await transport.fetchIceConfiguration();
    final second = await transport.fetchIceConfiguration();
    expect(first.iceServers, hasLength(1));
    expect(first.iceServers.single.keys, <String>['urls']);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
  });

  test('WSS承担双向扁平信令且旧HTTP信令彻底删除', () {
    final source =
        File('lib/chat/transport/chat_cloud_transport.dart').readAsStringSync();
    expect(source, contains("'citizen_chat_ws_ready'"));
    expect(source, contains("'citizen_chat_ws_pong'"));
    expect(source, contains("'citizen_chat_signal_result'"));
    expect(source, contains("'signal_kind'"));
    expect(source, contains('socket.add(jsonEncode(frame))'));
    expect(source, contains("socket.add('ping')"));
    expect(source, contains('chat_signal_pong_timeout'));
    expect(source, isNot(contains("_postMap('/chat/signals'")));
    expect(source, isNot(contains("'connection_kind'")));
    expect(source, isNot(contains("'transfer_id'")));
  });

  test('服务端结构化错误只暴露稳定错误码', () async {
    final transport = _transport(
      (_) async => http.Response(
        jsonEncode({
          'ok': false,
          'error_code': 'invalid_chat_request',
          'message': 'server-detail-must-not-reach-ui',
        }),
        400,
      ),
    );

    await expectLater(
      transport.registerPushEndpoint(
        pushProvider: 'fcm',
        pushToken: 'fcm-token-1234567890',
        apnsEnvironment: null,
        expiresAtMillis: 999999,
      ),
      throwsA(predicate((error) => error.toString() == 'invalid_chat_request')),
    );
  });

  test('真机聊天诊断覆盖WSS和信封全链路且不记录敏感正文', () {
    final cloudSource =
        File('lib/chat/transport/chat_cloud_transport.dart').readAsStringSync();
    final flowSource = File('lib/chat/chat_flow.dart').readAsStringSync();
    final logSource = File('lib/log/app_log.dart').readAsStringSync();

    expect(cloudSource, contains("'[ChatTrace] realtime="));
    expect(cloudSource, contains('_webSocketFailureDiagnostic(error)'));
    expect(cloudSource, contains("'chat_signal_http_\$status'"));
    expect(cloudSource, contains('_diagnoseRealtimePreflight(uri)'));
    expect(cloudSource, contains("wsUri.replace(scheme: 'https')"));
    expect(cloudSource, contains("'[ChatTrace] realtime_preflight status="));
    expect(flowSource, contains("'[ChatTrace] envelope.queued"));
    expect(flowSource, contains("'[ChatTrace] envelope.delivery"));
    expect(flowSource, contains("'[ChatTrace] envelope.incoming"));
    expect(flowSource, contains("'[ChatTrace] envelope.received"));
    expect(cloudSource, isNot(contains('[ChatTrace] token=')));
    expect(cloudSource, isNot(contains('[ChatTrace] signature=')));
    expect(flowSource, isNot(contains('[ChatTrace] plaintext=')));
    expect(flowSource, contains('_safeTraceError(error)'));
    expect(logSource, contains("'CITIZENAPP_DIAGNOSTICS'"));
    expect(logSource, contains('!kReleaseMode || _explicitDiagnostics'));
  });
}

ChatCloudTransport _transport(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ChatCloudTransport(
    accountId: _accountId,
    localCidNumber: _aliceCidNumber,
    localDeviceId: 'alice-phone',
    serviceBaseUrl: Uri.parse('https://worker.example/api'),
    sessionToken: 'session-token',
    httpClient: MockClient(handler),
  );
}

dynamic _envelope() => const MlsWireMessage(
      wireBytes: [1, 2, 3],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-mailbox',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-mailbox-1',
      senderCidNumber: _aliceCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 1000,
      ttlMillis: 60000,
    );

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);
