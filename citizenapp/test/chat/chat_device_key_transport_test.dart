import 'dart:convert';

import 'package:citizenapp/chat/transport/chat_cloud_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const cid = 'CN220-CTZN2-198805200-2026';
  const peer = 'CN220-CTZN2-199001010-2026';
  const publicKey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('幂等登记当前设备HPKE公开钥且只使用HTTPS接口', () async {
    late Map<String, dynamic> body;
    final transport = ChatCloudTransport(
      accountId: 'account',
      localCidNumber: cid,
      localDeviceId: 'alice-phone',
      serviceBaseUrl: Uri.parse('https://worker.example/api'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/chat/device-key');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(<String, Object?>{'ok': true}), 200);
      }),
    );

    await transport.publishDeviceKey(publicKey);
    expect(body, <String, Object?>{
      'device_id': 'alice-phone',
      'device_public_key_hex': publicKey,
    });
  });

  test('首次私信只读取稳定设备公开钥且不建立WebRTC', () async {
    final transport = ChatCloudTransport(
      accountId: 'account',
      localCidNumber: cid,
      localDeviceId: 'alice-phone',
      serviceBaseUrl: Uri.parse('https://worker.example/api'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/chat/device-key/resolve');
        expect(jsonDecode(request.body), <String, Object?>{
          'recipient_cid_number': peer,
        });
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'cid_number': peer,
            'device_id': 'bob-phone',
            'device_public_key_hex': publicKey,
          }),
          200,
        );
      }),
    );

    expect(await transport.resolveDeviceKey(peer), publicKey);
  });
}
