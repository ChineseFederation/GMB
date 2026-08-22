import 'dart:io';

import 'package:citizenapp/chat/chat_push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 唤醒载荷按发件人身份主键 CID 号标识（Worker R5 口径）；下游 peer_ready / 补发
/// 一律按 CID 寻址，钱包账户 account_id 不进推送。
const _senderCidNumber = 'CN220-CTZN2-100000001-2026';
const _otherCidNumber = 'CN220-CTZN2-100000002-2026';

void main() {
  test('新应用标识使用各自登记的唯一 Firebase App ID', () {
    final source = File('lib/chat/chat_push_service.dart').readAsStringSync();
    final appIds = RegExp(
      r"'(1:124593150477:(?:android|ios):[0-9a-f]+)'",
    ).allMatches(source).map((match) => match.group(1)!).toSet();

    expect(
      source,
      contains("iosBundleId: Platform.isIOS ? 'ios.citizenapp' : null"),
    );
    expect(appIds, {
      '1:124593150477:android:436c372ca4779924ba1344',
      '1:124593150477:ios:dcff6e612fb28795ba1344',
    });
    expect(source, isNot(contains('String.fromEnvironment')));
  });

  test('Firebase 客户端 Key 按平台隔离且禁止共享回退', () {
    final source = File('lib/chat/chat_push_service.dart').readAsStringSync();
    final keys = RegExp(
      r"const _firebase(?:Android|Ios)ApiKey = '(AIza[^']+)'",
    ).allMatches(source).map((match) => match.group(1)!).toList();

    expect(keys, hasLength(2));
    expect(keys.toSet(), hasLength(2));
    expect(
      source,
      matches(
        RegExp(
          r'final\s+apiKey\s*=\s*Platform\.isIOS\s*\?\s*'
          r'_firebaseIosApiKey\s*:\s*_firebaseAndroidApiKey;',
        ),
      ),
    );
    expect(source, contains('if (apiKey.isEmpty ||'));
    expect(source, contains('apiKey: apiKey'));
  });

  test('只接受无内容聊天唤醒载荷', () {
    expect(
      ChatPushService.wakeSenderFromData(const {
        'kind': 'chat_wake',
        'sender_cid_number': _senderCidNumber,
      }),
      _senderCidNumber,
    );
    expect(
      ChatPushService.wakeSenderFromData(const {
        'kind': 'chat_wake',
        'sender_cid_number': _senderCidNumber,
        'message': '不得进入推送',
      }),
      isNull,
    );
    expect(
      ChatPushService.wakeSenderFromData(const {
        'kind': 'chat_message',
        'sender_cid_number': _senderCidNumber,
      }),
      isNull,
    );
  });

  test('APNs 环境只接受原生签名映射后的两个固定值', () {
    expect(requireApnsEnvironment('sandbox'), 'sandbox');
    expect(requireApnsEnvironment('production'), 'production');
    expect(() => requireApnsEnvironment('development'), throwsStateError);
    expect(() => requireApnsEnvironment(null), throwsStateError);
  });

  test('iOS APNs 环境以 provisioning profile 和 App Store 收据为真源', () {
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(entitlements, contains('<string>\$(APS_ENVIRONMENT)</string>'));
    expect(infoPlist, isNot(contains('\$(APS_ENVIRONMENT)')));
    expect(appDelegate, contains('embedded'));
    expect(appDelegate, contains('mobileprovision'));
    expect(appDelegate, contains('profile["Entitlements"]'));
    expect(appDelegate, contains('entitlements["aps-environment"]'));
    expect(appDelegate, contains('bundle.appStoreReceiptURL'));
  });

  test('iOS 正式包固定声明当前出口合规豁免结论', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    // 当前销售范围排除法国，App Store Connect 已判定标准加密无须上传文稿。
    expect(infoPlist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
    expect(
      infoPlist,
      contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>'),
    );
    expect(infoPlist, isNot(contains('ITSEncryptionExportComplianceCode')));
  });

  test('双端系统备份都排除设备侧聊天内容', () {
    final androidManifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final iosDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final chatIsar = File('lib/isar/chat_isar.dart').readAsStringSync();

    expect(androidManifest, contains('android:allowBackup="false"'));
    expect(iosDelegate, contains('isExcludedFromBackup = true'));
    expect(iosDelegate, contains('appendingPathComponent("chat"'));
    expect(iosDelegate, contains('hasPrefix("citizenapp_chat")'));
    expect(iosDelegate, contains('case "excludeChatDataFromBackup"'));
    expect(
        chatIsar, contains("invokeMethod<void>('excludeChatDataFromBackup')"));
  });

  test('推送端点缓存同时绑定服务类型、APNs 环境和 Token', () {
    const sandbox = ChatPushToken(
      provider: 'apns',
      token: 'same-token',
      apnsEnvironment: 'sandbox',
    );
    const production = ChatPushToken(
      provider: 'apns',
      token: 'same-token',
      apnsEnvironment: 'production',
    );
    const fcm = ChatPushToken(
      provider: 'fcm',
      token: 'same-token',
      apnsEnvironment: null,
    );
    expect(
      sandbox.registrationCacheValue,
      isNot(production.registrationCacheValue),
    );
    expect(fcm.registrationCacheValue, isNot(sandbox.registrationCacheValue));
  });

  test('后台连续唤醒会去重保存全部发送方', () async {
    SharedPreferences.setMockInitialValues({});
    await ChatPushService.storeWakeSender(_senderCidNumber);
    await ChatPushService.storeWakeSender(_otherCidNumber);
    await ChatPushService.storeWakeSender(_senderCidNumber);

    final service = ChatPushService();
    expect(await service.takePendingWakeSenders(), [
      _senderCidNumber,
      _otherCidNumber,
    ]);
    expect(await service.takePendingWakeSenders(), isEmpty);
    await service.dispose();
  });
}
