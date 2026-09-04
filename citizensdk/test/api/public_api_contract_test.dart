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
    expect(CitizenSdk.open, isA<Function>());
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

  test('Flutter五种平台注册共用channel、22方法及无任意RPC/裸extrinsic闭集', () {
    expect(FlutterCitizenSdkPlatform.methodChannelName, 'citizen/sdk/core/v1');
    expect(FlutterCitizenSdkPlatform.eventChannelName, 'citizen/sdk/events/v1');
    expect(CitizenSdkFlutterCodec.methods, hasLength(22));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('rpc')));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('submitExtrinsic')));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('watchExtrinsic')));
    expect(CitizenSdkFlutterCodec.methods, isNot(contains('exportPrivateKey')));
  });

  test('Android、iOS、macOS、Linux与Windows默认选择同一Flutter transport', () async {
    CitizenSdkPlatform.instance = null;
    const core = MethodChannel(FlutterCitizenSdkPlatform.methodChannelName);
    const events = MethodChannel(FlutterCitizenSdkPlatform.eventChannelName);
    var nextSession = 0;
    var closes = 0;
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
            closes++;
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
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      debugDefaultTargetPlatformOverride = target;
      final sdk = await CitizenSdk.open();
      expect(sdk.lifecycle, CitizenSdkLifecycle.created);
      await sdk.close();
      expect(sdk.lifecycle, CitizenSdkLifecycle.disposed);
      await sdk.close();
    }
    expect(nextSession, 5);
    expect(closes, 5);
  });

  test('Fuchsia未支持平台在进入任何channel前拒绝', () async {
    CitizenSdkPlatform.instance = null;
    const core = MethodChannel(FlutterCitizenSdkPlatform.methodChannelName);
    const events = MethodChannel(FlutterCitizenSdkPlatform.eventChannelName);
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(core, (_) async {
          calls++;
          throw StateError('未支持平台不应进入原生通道');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(events, (_) async {
          calls++;
          throw StateError('未支持平台不应订阅原生事件');
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      CitizenSdkPlatform.instance = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(core, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(events, null);
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    await expectLater(
      CitizenSdk.open(),
      throwsA(
        isA<CitizenSdkException>().having(
          (error) => error.code,
          'code',
          CitizenSdkErrorCode.unsupported,
        ),
      ),
    );
    expect(calls, 0);
  });

  test('五种默认平台缺少原生插件时失败关闭且不替换transport', () async {
    CitizenSdkPlatform.instance = null;
    const core = MethodChannel(FlutterCitizenSdkPlatform.methodChannelName);
    const events = MethodChannel(FlutterCitizenSdkPlatform.eventChannelName);
    var opens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(events, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(core, (call) async {
          expect(call.method, 'open');
          expect(call.arguments, const <Object?>[1]);
          opens++;
          // 所有已开放平台都走官方通道；缺少插件时不得伪造原生 session。
          throw MissingPluginException('CitizenSDK plugin missing');
        });
    addTearDown(() {
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
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      debugDefaultTargetPlatformOverride = target;
      await expectLater(
        CitizenSdk.open(),
        throwsA(
          isA<CitizenSdkException>().having(
            (error) => error.code,
            'code',
            CitizenSdkErrorCode.unsupported,
          ),
        ),
      );
    }
    expect(opens, 5);
    expect(CitizenSdkPlatform.instance, isNull);
  });
}

String _account(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';
