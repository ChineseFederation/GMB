import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('citizen/sdk/test/hardware_secret_vault');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('AAD keeps the stable GMB domain with citizensdk product', () {
    final context = HardwareSecretContext(
      scope: '0',
      accountId: '0x${'01' * 32}',
      secretType: HardwareSecretType.accountMiniSecret,
    );
    expect(
      utf8.decode(context.associatedData()),
      'GMB\ncitizensdk\n0\n0x${'01' * 32}\naccount_mini_secret',
    );
  });

  test('new encryption is fixed to citizensdk native namespace', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return Uint8List.fromList(<int>[7, 8, 9]);
        });
    final vault = HardwareSecretVault(channel: channel);
    final context = HardwareSecretContext(
      scope: '0',
      accountId: '0x${'02' * 32}',
      secretType: HardwareSecretType.accountMiniSecret,
    );

    expect(await vault.encrypt(context, Uint8List(32)), <int>[7, 8, 9]);
    expect(captured?.method, 'encrypt');
    expect(
      (captured?.arguments as Map<Object?, Object?>)['keyNamespace'],
      'citizensdk',
    );
  });

  test('decryption is fixed to citizensdk native namespace', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return Uint8List.fromList(List<int>.filled(32, 4));
        });
    final vault = HardwareSecretVault(channel: channel);
    final context = HardwareSecretContext(
      scope: '0',
      accountId: '0x${'03' * 32}',
      secretType: HardwareSecretType.accountMiniSecret,
    );
    expect(
      await vault.decrypt(context, Uint8List.fromList(<int>[1])),
      hasLength(32),
    );
    expect(captured?.method, 'decrypt');
    expect(
      (captured?.arguments as Map<Object?, Object?>)['keyNamespace'],
      'citizensdk',
    );
  });
}
