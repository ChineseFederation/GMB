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
      keyGeneration: '10' * 16,
      secretOwner: '11' * 16,
      accountId: '0x${'01' * 32}',
      secretType: HardwareSecretType.accountMiniSecret,
    );
    expect(
      utf8.decode(context.associatedData()),
      'GMB\ncitizensdk\n0\n${'10' * 16}\n${'11' * 16}\n'
      '0x${'01' * 32}\naccount_mini_secret',
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
      keyGeneration: '20' * 16,
      secretOwner: '21' * 16,
      accountId: '0x${'02' * 32}',
      secretType: HardwareSecretType.accountMiniSecret,
    );

    expect(await vault.encrypt(context, Uint8List(32)), <int>[7, 8, 9]);
    expect(captured?.method, 'encrypt');
    expect(
      (captured?.arguments as Map<Object?, Object?>)['scope'],
      'citizensdk:0:${'20' * 16}',
    );
    expect(
      (captured?.arguments as Map<Object?, Object?>)['keyNamespace'],
      'citizensdk',
    );
  });

  test('decryption is fixed to citizensdk native namespace', () async {
    final borrowed = Uint8List.fromList(List<int>.filled(32, 4));
    final borrowingChannel = _BorrowingMethodChannel(borrowed);
    final vault = HardwareSecretVault(channel: borrowingChannel);
    final context = HardwareSecretContext(
      scope: '0',
      keyGeneration: '30' * 16,
      secretOwner: '31' * 16,
      accountId: '0x${'03' * 32}',
      secretType: HardwareSecretType.accountMiniSecret,
    );
    final owned = await vault.decrypt(context, Uint8List.fromList(<int>[1]));
    expect(owned, List<int>.filled(32, 4));
    expect(identical(owned, borrowed), isFalse);
    expect(borrowed, List<int>.filled(32, 0));
    expect(borrowingChannel.captured?.method, 'decrypt');
    expect(
      (borrowingChannel.captured?.arguments as Map<Object?, Object?>)['scope'],
      'citizensdk:0:${'30' * 16}',
    );
    expect(
      (borrowingChannel.captured?.arguments
          as Map<Object?, Object?>)['keyNamespace'],
      'citizensdk',
    );
  });

  test('解密结果校验抛错时仍清零平台借用缓冲', () async {
    final borrowed = Uint8List.fromList(<int>[9, 8, 7]);
    final vault = HardwareSecretVault(
      channel: _BorrowingMethodChannel(borrowed),
    );
    final context = HardwareSecretContext(
      scope: '0',
      keyGeneration: '40' * 16,
      secretOwner: '41' * 16,
      accountId: '0x${'04' * 32}',
      secretType: HardwareSecretType.accountMiniSecret,
    );

    await expectLater(
      vault.decrypt(context, Uint8List.fromList(<int>[1])),
      throwsA(isA<HardwareSecretVaultException>()),
    );
    expect(borrowed, <int>[0, 0, 0]);
  });
}

/// Bypasses StandardMethodCodec's defensive copy so the contract can observe
/// the exact borrowed platform buffer received by [HardwareSecretVault].
final class _BorrowingMethodChannel extends MethodChannel {
  _BorrowingMethodChannel(this.borrowed)
    : super('citizen/sdk/test/borrowed_hardware_secret_vault');

  final Uint8List borrowed;
  MethodCall? captured;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    captured = MethodCall(method, arguments);
    return borrowed as T;
  }
}
