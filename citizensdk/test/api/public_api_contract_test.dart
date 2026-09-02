import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/src/platform/citizen_sdk_flutter_codec.dart';
import 'package:citizen_sdk/src/platform/citizen_sdk_platform.dart';
import 'package:citizen_sdk/src/platform/flutter_citizen_sdk_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Hosted Package根入口公开稳定API与公开模型', () {
    expect(CitizenSdkClient.open, isA<Function>());
    expect(isA<CitizenChain>(), isNotNull);
    expect(isA<CitizenWallet>(), isNotNull);
    expect(isA<CitizenTransactions>(), isNotNull);
    expect(CitizenSdkErrorCode.values, hasLength(22));
    expect(CitizenCapabilityName.values, hasLength(10));
    expect(
      CitizenWalletSignature(accountId: _account(1), bytes: Uint8List(64)),
      isA<CitizenWalletSignature>(),
    );
  });

  test('Flutter三平台channel名称、22方法及无任意RPC/裸extrinsic闭集固定', () {
    expect(FlutterCitizenSdkPlatform.methodChannelName, 'citizen/sdk/core/v1');
    expect(FlutterCitizenSdkPlatform.eventChannelName, 'citizen/sdk/events/v1');
    expect(CitizenSdkFlutterCodec.methods, hasLength(22));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('rpc')));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('submitExtrinsic')));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('watchExtrinsic')));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('exportPrivateKey')));
  });

  test('Android、iOS与macOS默认选择同一Flutter transport', () async {
    CitizenSdkPlatform.instance = null;
    const core = MethodChannel(FlutterCitizenSdkPlatform.methodChannelName);
    const events = MethodChannel(FlutterCitizenSdkPlatform.eventChannelName);
    var nextSession = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(events, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(core, (call) async {
          final arguments = call.arguments! as List<Object?>;
          if (call.method == 'open') {
            expect(arguments, const <Object?>[1]);
            return <Object?>[
              1,
              'session-${++nextSession}',
              0,
              <Object?>['created', 1],
            ];
          }
          if (call.method == 'close') {
            return <Object?>[
              1,
              arguments[1],
              arguments[2],
              <Object?>['disposed'],
            ];
          }
          throw StateError('未预期 method：${call.method}');
        });
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      CitizenSdkPlatform.instance = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(core, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(events, null);
    });

    for (final target in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = target;
      final client = await CitizenSdkClient.open();
      expect(client.lifecycle, CitizenSdkLifecycle.created);
      await client.close();
    }
    expect(nextSession, 3);
  });

  test('未交付平台不会误走Flutter channel', () async {
    CitizenSdkPlatform.instance = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      CitizenSdkPlatform.instance = null;
    });

    await expectLater(
      CitizenSdkClient.open(),
      throwsA(
        isA<CitizenSdkException>().having(
          (error) => error.code,
          'code',
          CitizenSdkErrorCode.unsupported,
        ),
      ),
    );
  });
}

String _account(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';
