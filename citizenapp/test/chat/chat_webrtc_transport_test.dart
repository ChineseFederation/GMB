import 'dart:convert';

import 'package:citizenapp/chat/crypto/mls_boundary.dart';
import 'package:citizenapp/chat/transport/chat_webrtc_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const keyPackage = MlsKeyPackage(
    cidNumber: 'CN220-CTZN2-199001010-2026',
    deviceId: 'device-bob',
    devicePublicKey: 'public-key',
    keyPackageId: 'kp-1',
    keyPackageBytes: <int>[1, 2, 3, 4],
    cipherSuite: 'MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519',
    notBeforeMillis: 1,
    notAfterMillis: 2,
    lastResort: false,
  );

  test('WebRTC 控制帧只接受 KeyPackage 请求', () {
    final frame = ChatWebrtcControlFrame.keyPackageRequest('request-1');
    expect(
      ChatWebrtcControlFrame.decode(jsonEncode(frame)),
      <String, dynamic>{
        'kind': 'key_package_request',
        'request_id': 'request-1',
      },
    );
  });

  test('KeyPackage 响应严格往返且保持 CID', () {
    final frame = ChatWebrtcControlFrame.keyPackageResponse(
      'request-2',
      keyPackage,
    );
    final decoded = ChatWebrtcControlFrame.decode(jsonEncode(frame));
    final restored = ChatWebrtcControlFrame.keyPackage(decoded);

    expect(restored.cidNumber, keyPackage.cidNumber);
    expect(restored.deviceId, keyPackage.deviceId);
    expect(restored.keyPackageId, keyPackage.keyPackageId);
    expect(restored.keyPackageBytes, keyPackage.keyPackageBytes);
  });

  test('普通附件帧禁止进入 WebRTC 控制通道', () {
    expect(
      () => ChatWebrtcControlFrame.decode(jsonEncode(<String, Object?>{
        'kind': 'attachment_start',
        'attachment_id': 'att-1',
      })),
      throwsFormatException,
    );
  });

  test('KeyPackage 控制帧拒绝多余字段', () {
    expect(
      () => ChatWebrtcControlFrame.decode(jsonEncode(<String, Object?>{
        'kind': 'key_package_request',
        'request_id': 'request-3',
        'attachment_id': 'forbidden',
      })),
      throwsFormatException,
    );
  });
}
