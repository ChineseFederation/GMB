import 'dart:convert';

import 'package:citizenapp/chat/crypto/mls_boundary.dart';
import 'package:citizenapp/chat/transport/chat_cloud_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const cid = 'CN220-CTZN2-198805200-2026';
  const peer = 'CN220-CTZN2-199001010-2026';
  final now = DateTime.now().millisecondsSinceEpoch;

  // 统一构造当前设备和对端设备的公开 KeyPackage，测试只改变持有者与备用标记。
  MlsKeyPackage package(String owner, bool lastResort) => MlsKeyPackage(
        cidNumber: owner,
        deviceId: owner == cid ? 'alice-phone' : 'bob-phone',
        devicePublicKey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        keyPackageId: lastResort ? 'package-last-resort' : 'package-normal',
        keyPackageBytes: const <int>[1, 2, 3, 4],
        cipherSuite: 'MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519',
        notBeforeMillis: now - 1000,
        notAfterMillis: now + 60000,
        lastResort: lastResort,
      );

  // 发布合同必须一次提交普通包和备用包，并保持 HTTPS 服务端路径唯一。
  test('发布严格的一次性包和last-resort包且不经过WebRTC', () async {
    late Map<String, dynamic> body;
    final transport = ChatCloudTransport(
      accountId: 'account',
      localCidNumber: cid,
      localDeviceId: 'alice-phone',
      serviceBaseUrl: Uri.parse('https://worker.example/api'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/chat/key-packages');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(<String, Object?>{'ok': true}), 200);
      }),
    );

    await transport.publishKeyPackages(
      normal: package(cid, false),
      lastResort: package(cid, true),
    );
    expect((body['normal'] as Map<String, dynamic>)['last_resort'], isFalse);
    expect((body['last_resort'] as Map<String, dynamic>)['last_resort'], isTrue);
  });

  // 首次建会话只领取对端公开包，不把私钥材料或本机会话状态送入云端。
  test('首次会话经HTTPS领取公开KeyPackage', () async {
    final claimed = package(peer, false);
    final transport = ChatCloudTransport(
      accountId: 'account',
      localCidNumber: cid,
      localDeviceId: 'alice-phone',
      serviceBaseUrl: Uri.parse('https://worker.example/api'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/chat/key-packages/claim');
        return http.Response(jsonEncode(<String, Object?>{
          'ok': true,
          'key_package': <String, Object?>{
            'cid_number': claimed.cidNumber,
            'device_id': claimed.deviceId,
            'device_public_key_hex': claimed.devicePublicKey,
            'key_package_id': claimed.keyPackageId,
            'key_package': base64Url.encode(claimed.keyPackageBytes).replaceAll('=', ''),
            'cipher_suite': claimed.cipherSuite,
            'not_before': claimed.notBeforeMillis,
            'not_after': claimed.notAfterMillis,
            'last_resort': claimed.lastResort,
          },
        }), 200);
      }),
    );

    final result = await transport.claimKeyPackage(peer);
    expect(result.cidNumber, peer);
    expect(result.keyPackageBytes, claimed.keyPackageBytes);
  });
}
