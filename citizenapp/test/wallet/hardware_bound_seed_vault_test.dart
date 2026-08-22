import 'dart:convert';

import 'package:citizenapp/wallet/core/fake_hardware_bound_seed_vault.dart';
import 'package:citizenapp/wallet/core/hardware_bound_seed_vault.dart';
import 'package:citizenapp/wallet/core/secure_seed_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmb_hardware_secretvault/hardware_secretvault.dart';

const String _accountA =
    '0x2afba9278e30ccf6a6ceb3a8b6e336b70068f045c666f2e7f4f9cc5f47db8972';
const String _accountB =
    '0xb606fc73f57f03cdb4c932d475ab426043e429cecc2ffff0d2672b0df8398c48';

Uint8List _secret(int value) => Uint8List.fromList(List<int>.filled(32, value));

/// 内存 blob store；测试只观察硬件信封密文，不接触系统安全存储通道。
class _MemBlobStore implements VaultBlobStore {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<void> delete(String key) async => store.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeHardwareBoundSeedVault', () {
    late FakeHardwareBoundSeedVault vault;

    setUp(() => vault = FakeHardwareBoundSeedVault());

    test('account key put/read/delete round-trip', () async {
      final secret = _secret(0x11);
      await vault.putAccountKey(
        walletIndex: 1,
        accountId: _accountA,
        childMiniSecret: secret,
      );
      expect(
        await vault.readAccountKey(walletIndex: 1, accountId: _accountA),
        orderedEquals(secret),
      );
      expect(await vault.hasAccountKey(_accountA), isTrue);
      await vault.deleteAccountKey(walletIndex: 1, accountId: _accountA);
      expect(await vault.hasAccountKey(_accountA), isFalse);
    });

    test('injected readAccountKey error thrown once then cleared', () async {
      final secret = _secret(0x22);
      await vault.putAccountKey(
        walletIndex: 1,
        accountId: _accountA,
        childMiniSecret: secret,
      );
      vault.nextReadError = const SeedKeyInvalidated('changed');
      await expectLater(
        () => vault.readAccountKey(walletIndex: 1, accountId: _accountA),
        throwsA(isA<SeedKeyInvalidated>()),
      );
      expect(
        await vault.readAccountKey(walletIndex: 1, accountId: _accountA),
        orderedEquals(secret),
      );
    });
  });

  group('HardwareBoundSeedVault', () {
    const channel = MethodChannel('gmb/hardware_secretvault');
    late _MemBlobStore blobs;
    late HardwareBoundSeedVault vault;
    late Map<String, Uint8List> ciphertextToPlaintext;
    late Set<String> hardwareScopes;
    late List<MethodCall> calls;
    String? decryptErrorCode;
    bool encryptReturnsNull = false;
    bool biometricEnrolled = true;
    int counter = 1;

    setUp(() {
      blobs = _MemBlobStore();
      ciphertextToPlaintext = <String, Uint8List>{};
      hardwareScopes = <String>{};
      calls = <MethodCall>[];
      decryptErrorCode = null;
      encryptReturnsNull = false;
      biometricEnrolled = true;
      counter = 1;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        final arguments =
            (call.arguments as Map<Object?, Object?>?) ?? <Object?, Object?>{};
        switch (call.method) {
          case 'securityStatus':
            return <String, Object?>{
              'supported': true,
              'strongBiometricEnrolled': biometricEnrolled,
            };
          case 'encrypt':
            if (encryptReturnsNull) return null;
            final scope = arguments['scope']! as String;
            final plaintext = arguments['plaintext']! as Uint8List;
            final ciphertext = Uint8List.fromList(<int>[counter++, 0xa5]);
            hardwareScopes.add(scope);
            ciphertextToPlaintext[base64Encode(ciphertext)] =
                Uint8List.fromList(plaintext);
            return ciphertext;
          case 'decrypt':
            if (decryptErrorCode != null) {
              throw PlatformException(code: decryptErrorCode!);
            }
            final ciphertext = arguments['ciphertext']! as Uint8List;
            final plaintext = ciphertextToPlaintext[base64Encode(ciphertext)];
            // 模拟 Android/iOS 平台通道返回的只读 TypedData；共享包必须复制后再交给
            // 公民的调用方清零，不能直接写入引擎借用缓冲区。
            return plaintext == null
                ? null
                : Uint8List.fromList(plaintext).asUnmodifiableView();
          case 'containsKey':
            return hardwareScopes.contains(arguments['scope']);
          case 'deleteKey':
            hardwareScopes.remove(arguments['scope']);
            return null;
        }
        return null;
      });
      vault = HardwareBoundSeedVault(
        hardwareVault: HardwareSecretvault(channel: channel),
        blobStore: blobs,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('写入使用统一字节通道并绑定产品、钱包作用域和 AccountId', () async {
      final secret = _secret(0x31);
      await vault.putAccountKey(
        walletIndex: 3,
        accountId: _accountA,
        childMiniSecret: secret,
      );
      final encrypt = calls.firstWhere((call) => call.method == 'encrypt');
      final arguments = encrypt.arguments! as Map<Object?, Object?>;
      expect(arguments['scope'], 'citizenapp:3');
      expect(arguments['plaintext'], isA<Uint8List>());
      expect(arguments['associatedData'], isA<Uint8List>());
      expect(
        blobs.store['wallet.secret.$_accountA.account_mini_secret'],
        isNotNull,
      );
    });

    test('同钱包账户共用硬件作用域但密文相互独立', () async {
      await vault.putAccountKey(
        walletIndex: 3,
        accountId: _accountA,
        childMiniSecret: _secret(0x41),
      );
      await vault.putAccountKey(
        walletIndex: 3,
        accountId: _accountB,
        childMiniSecret: _secret(0x42),
      );
      expect(hardwareScopes, <String>{'citizenapp:3'});
      expect(
        blobs.store['wallet.secret.$_accountA.account_mini_secret'],
        isNot(blobs.store['wallet.secret.$_accountB.account_mini_secret']),
      );
    });

    test('账户 MiniSecretKey 经硬件信封往返仍是 32 字节', () async {
      final secret = _secret(0x51);
      await vault.putAccountKey(
        walletIndex: 3,
        accountId: _accountA,
        childMiniSecret: secret,
      );
      final restored =
          await vault.readAccountKey(walletIndex: 3, accountId: _accountA);
      expect(restored, orderedEquals(secret));
      HardwareSecretvault.clearBytes(restored!);
      expect(restored, orderedEquals(Uint8List(32)));
    });

    test('存在性只检查密文，不触发生物解密', () async {
      expect(await vault.hasAccountKey(_accountA), isFalse);
      await vault.putAccountKey(
        walletIndex: 3,
        accountId: _accountA,
        childMiniSecret: _secret(0x61),
      );
      expect(await vault.hasAccountKey(_accountA), isTrue);
      expect(calls.where((call) => call.method == 'decrypt'), isEmpty);
    });

    test('删除账户只删密文，删除钱包才删硬件作用域', () async {
      await vault.putAccountKey(
        walletIndex: 3,
        accountId: _accountA,
        childMiniSecret: _secret(0x71),
      );
      await vault.deleteAccountKey(walletIndex: 3, accountId: _accountA);
      expect(await vault.hasAccountKey(_accountA), isFalse);
      expect(await vault.hasWalletKey(walletIndex: 3), isTrue);
      await vault.deleteWalletKey(walletIndex: 3);
      expect(await vault.hasWalletKey(walletIndex: 3), isFalse);
    });

    test('错误长度、空原生结果均 fail-closed', () async {
      await expectLater(
        () => vault.putAccountKey(
          walletIndex: 1,
          accountId: _accountA,
          childMiniSecret: Uint8List(31),
        ),
        throwsA(isA<SecureStoreUnavailable>()),
      );
      encryptReturnsNull = true;
      await expectLater(
        () => vault.putAccountKey(
          walletIndex: 1,
          accountId: _accountA,
          childMiniSecret: _secret(0x01),
        ),
        throwsA(isA<SecureStoreUnavailable>()),
      );
    });

    final mappings = <(String, Matcher)>[
      ('keyPermanentlyInvalidated', isA<SeedKeyInvalidated>()),
      ('userCancelled', isA<AuthCancelled>()),
      ('lockout', isA<AuthCancelled>()),
      ('notEnrolled', isA<NoDeviceCredential>()),
      ('hardwareUnavailable', isA<SecureStoreUnavailable>()),
    ];
    for (final mapping in mappings) {
      test('解密统一映射 ${mapping.$1}', () async {
        await vault.putAccountKey(
          walletIndex: 3,
          accountId: _accountA,
          childMiniSecret: _secret(0x21),
        );
        decryptErrorCode = mapping.$1;
        await expectLater(
          () => vault.readAccountKey(walletIndex: 3, accountId: _accountA),
          throwsA(mapping.$2),
        );
      });
    }

    test('设备能力状态统一映射', () async {
      expect(await vault.authStatus(), SecureAuthStatus.available);
      biometricEnrolled = false;
      expect(await vault.authStatus(), SecureAuthStatus.noDeviceLock);
    });
  });
}
