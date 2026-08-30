import 'package:citizenapp/chat/chat_sdk_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_sdk/chat_sdk.dart';

import '../support/chat_sdk_native_probe.dart';

void main() {
  // 官方 CI 先构建宿主库；开发者在无 libchat_sdk 的临时环境直跑时才跳过。
  final skip = chatSdkNativeSkipReason();

  test('native OpenMLS creates a real KeyPackage', () async {
    final crypto = NativeMlsCrypto();
    final keyPackage = await crypto.createKeyPackage(
      const ChatDevice(
        userId: 'CN220-CTZN2-100000001-2026',
        deviceId: 'alice-phone',
        devicePublicKey: 'aabbcc',
      ),
    );

    expect(keyPackage.cidNumber, 'CN220-CTZN2-100000001-2026');
    expect(keyPackage.deviceId, 'alice-phone');
    expect(keyPackage.devicePublicKey, isNotEmpty);
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(keyPackage.devicePublicKey), isTrue);
    expect(keyPackage.keyPackageBytes.length, greaterThan(100));
    expect(keyPackage.cipherSuite, contains('MLS_128'));
    expect(keyPackage.lastResort, isFalse);
    // OpenMLS 0.8.1 默认 84 天，并向过去保留 1 小时时钟偏差窗口。
    expect(
      keyPackage.notAfterMillis - keyPackage.notBeforeMillis,
      (84 * 24 + 1) * 60 * 60 * 1000,
    );
  }, skip: skip);

  test('native OpenMLS creates a standards-marked last-resort KeyPackage',
      () async {
    final crypto = NativeMlsCrypto();
    final keyPackage = await crypto.createKeyPackage(
      const ChatDevice(
        userId: 'CN220-CTZN2-100000001-2026',
        deviceId: 'alice-phone',
        devicePublicKey: 'aabbcc',
      ),
      lastResort: true,
    );

    expect(keyPackage.lastResort, isTrue);
    expect(keyPackage.notAfterMillis, greaterThan(keyPackage.notBeforeMillis));
  }, skip: skip);

  test('native OpenMLS two-party smoke decrypts original plaintext', () async {
    final crypto = NativeMlsCrypto();
    final result = await crypto.runTwoPartySmoke(
      plaintext: 'hello from 公民 Chat',
    );

    expect(result.roundTripOk, isTrue);
    expect(result.decryptedPlaintext, 'hello from 公民 Chat');
    expect(result.aliceWireMessageHex.length, greaterThan(100));
    expect(result.bobKeyPackageHex.length, greaterThan(100));
    expect(result.welcomeHex.length, greaterThan(100));
  }, skip: skip);
}
