import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('citizen/sdk/test/hardware_bound_seed_store');
  late _MemoryBlobStore blobs;
  late HardwareBoundSeedStore store;
  late List<String> vaultMethods;
  late bool vaultKeyExists;
  late bool throwAfterDeleteKey;
  late bool keepDeletedVaultKey;

  setUp(() {
    blobs = _MemoryBlobStore();
    vaultMethods = <String>[];
    vaultKeyExists = true;
    throwAfterDeleteKey = false;
    keepDeletedVaultKey = false;
    store = HardwareBoundSeedStore(
      hardwareVault: HardwareSecretVault(channel: channel),
      blobStore: blobs,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          vaultMethods.add(call.method);
          switch (call.method) {
            case 'securityStatus':
              return <String, Object>{
                'supported': true,
                'strongBiometricEnrolled': true,
              };
            case 'encrypt':
              vaultKeyExists = true;
              return Uint8List.fromList(<int>[1, 2, 3]);
            case 'decrypt':
              return Uint8List.fromList(List<int>.generate(32, (i) => i));
            case 'containsKey':
              return vaultKeyExists;
            case 'deleteKey':
              if (!keepDeletedVaultKey) vaultKeyExists = false;
              keepDeletedVaultKey = false;
              if (throwAfterDeleteKey) {
                throwAfterDeleteKey = false;
                throw PlatformException(
                  code: 'deleteFailed',
                  message: 'delete reported failure after mutation',
                );
              }
              return null;
          }
          throw MissingPluginException(call.method);
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'stores ciphertext under citizensdk key and restores 32 bytes',
    () async {
      final accountId = '0x${'04' * 32}';
      await store.putAccountKey(
        walletIndex: 0,
        accountId: accountId,
        childMiniSecret: Uint8List(32),
      );
      expect(blobs.values.keys.single, startsWith('citizensdk.wallet.secret.'));
      expect(await store.hasAccountKey(accountId), isTrue);
      expect(
        await store.readAccountKey(walletIndex: 0, accountId: accountId),
        hasLength(32),
      );
    },
  );

  test('rejects non-32-byte account secret', () async {
    expect(
      store.putAccountKey(
        walletIndex: 0,
        accountId: '0x${'05' * 32}',
        childMiniSecret: Uint8List(31),
      ),
      throwsA(isA<SecureStoreUnavailable>()),
    );
  });

  test('blob 写入后抛错但完整回读一致时收敛为成功', () async {
    final accountId = '0x${'09' * 32}';
    blobs.throwAfterNextWrite = true;

    await store.putAccountKey(
      walletIndex: 0,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );

    expect(await store.hasAccountKey(accountId), isTrue);
  });

  test('blob 写调用正常返回但静默丢写时拒绝确认', () async {
    final accountId = '0x${'0a' * 32}';
    blobs.dropNextWrite = true;

    await expectLater(
      store.putAccountKey(
        walletIndex: 0,
        accountId: accountId,
        childMiniSecret: Uint8List(32),
      ),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(await store.hasAccountKey(accountId), isFalse);
  });

  test('删除账户只删密文 blob，回读为空且不删共享 KEK', () async {
    final accountId = '0x${'06' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );

    await store.deleteAccountKey(walletIndex: 0, accountId: accountId);

    expect(await store.hasAccountKey(accountId), isFalse);
    expect(await store.hasWalletKey(walletIndex: 0), isTrue);
    expect(vaultMethods, isNot(contains('deleteKey')));
  });

  test('删除钱包只删共享 KEK，账户 blob 由清理计划逐项删除', () async {
    final accountId = '0x${'07' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );

    await store.deleteWalletKey(walletIndex: 0);

    expect(await store.hasWalletKey(walletIndex: 0), isFalse);
    expect(await store.hasAccountKey(accountId), isTrue);
    expect(vaultMethods.where((method) => method == 'deleteKey'), hasLength(1));
  });

  test('blob 删除写后抛错仍可通过回读确认事实', () async {
    final accountId = '0x${'08' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );
    blobs.throwAfterNextDelete = true;

    await store.deleteAccountKey(walletIndex: 0, accountId: accountId);

    expect(await store.hasAccountKey(accountId), isFalse);
  });

  test('blob 删除正常返回但密文仍存在时拒绝确认', () async {
    final accountId = '0x${'0b' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );
    blobs.keepNextDelete = true;

    await expectLater(
      store.deleteAccountKey(walletIndex: 0, accountId: accountId),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(await store.hasAccountKey(accountId), isTrue);
  });

  test('KEK 删除写后抛错仍可通过回读确认事实', () async {
    throwAfterDeleteKey = true;

    await store.deleteWalletKey(walletIndex: 0);

    expect(await store.hasWalletKey(walletIndex: 0), isFalse);
  });

  test('KEK 删除正常返回但硬件密钥仍存在时拒绝确认', () async {
    keepDeletedVaultKey = true;

    await expectLater(
      store.deleteWalletKey(walletIndex: 0),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(await store.hasWalletKey(walletIndex: 0), isTrue);
  });
}

final class _MemoryBlobStore implements SecureBlobStore {
  final Map<String, String> values = <String, String>{};
  bool throwAfterNextDelete = false;
  bool throwAfterNextWrite = false;
  bool dropNextWrite = false;
  bool keepNextDelete = false;

  @override
  Future<void> delete(String key) async {
    if (keepNextDelete) {
      keepNextDelete = false;
      return;
    }
    values.remove(key);
    if (throwAfterNextDelete) {
      throwAfterNextDelete = false;
      throw PlatformException(
        code: 'deleteFailed',
        message: 'delete reported failure after mutation',
      );
    }
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (dropNextWrite) {
      dropNextWrite = false;
      return;
    }
    values[key] = value;
    if (throwAfterNextWrite) {
      throwAfterNextWrite = false;
      throw PlatformException(
        code: 'writeFailed',
        message: 'write reported failure after mutation',
      );
    }
  }
}
