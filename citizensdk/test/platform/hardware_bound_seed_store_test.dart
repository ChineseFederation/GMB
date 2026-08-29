import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';

const _generationA = '10101010101010101010101010101010';
const _generationB = '20202020202020202020202020202020';
const _ownerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('citizen/sdk/test/hardware_bound_seed_store');
  late _MemoryBlobStore blobs;
  late HardwareBoundSeedStore store;
  late List<String> vaultMethods;
  late Set<String> vaultKeyScopes;
  late bool throwAfterDeleteKey;
  late bool keepDeletedVaultKey;
  late bool strongBiometricEnrolled;
  late bool authenticateAssociatedData;

  setUp(() {
    blobs = _MemoryBlobStore();
    vaultMethods = <String>[];
    vaultKeyScopes = <String>{_vaultScope(_generationA)};
    throwAfterDeleteKey = false;
    keepDeletedVaultKey = false;
    strongBiometricEnrolled = true;
    authenticateAssociatedData = false;
    store = HardwareBoundSeedStore(
      hardwareVault: HardwareSecretVault(channel: channel),
      blobStore: blobs,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          vaultMethods.add(call.method);
          final arguments = call.arguments as Map<Object?, Object?>?;
          final scope = arguments?['scope'] as String?;
          switch (call.method) {
            case 'securityStatus':
              return <String, Object>{
                'supported': true,
                'strongBiometricEnrolled': strongBiometricEnrolled,
              };
            case 'encrypt':
              vaultKeyScopes.add(scope!);
              if (authenticateAssociatedData) {
                return _cipherForAssociatedData(
                  arguments!['associatedData']! as Uint8List,
                );
              }
              return Uint8List.fromList(<int>[1, 2, 3]);
            case 'decrypt':
              if (authenticateAssociatedData) {
                final expected = _cipherForAssociatedData(
                  arguments!['associatedData']! as Uint8List,
                );
                final ciphertext = arguments['ciphertext']! as Uint8List;
                if (!_sameBytes(expected, ciphertext)) {
                  throw PlatformException(
                    code: 'authenticationFailed',
                    message: 'associated data mismatch',
                  );
                }
              }
              return Uint8List.fromList(List<int>.generate(32, (i) => i));
            case 'containsKey':
              return vaultKeyScopes.contains(scope);
            case 'deleteKey':
              if (!keepDeletedVaultKey) vaultKeyScopes.remove(scope);
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

  test('未登记强生物识别时返回准确状态而不误报未设置锁屏', () async {
    strongBiometricEnrolled = false;

    expect(await store.authStatus(), SecureAuthStatus.noStrongBiometric);
  });

  test(
    'stores ciphertext under citizensdk key and restores 32 bytes',
    () async {
      final accountId = '0x${'04' * 32}';
      await store.putAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
        childMiniSecret: Uint8List(32),
      );
      expect(blobs.values.keys.single, startsWith('citizensdk.wallet.secret.'));
      expect(
        await store.hasAccountKey(
          walletIndex: 0,
          walletGeneration: _generationA,
          secretOwner: _ownerA,
          accountId: accountId,
        ),
        isTrue,
      );
      expect(
        await store.readAccountKey(
          walletIndex: 0,
          walletGeneration: _generationA,
          secretOwner: _ownerA,
          accountId: accountId,
        ),
        hasLength(32),
      );
    },
  );

  test('rejects non-32-byte account secret', () async {
    expect(
      store.putAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
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
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );

    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
      ),
      isTrue,
    );
  });

  test('blob 写调用正常返回但静默丢写时拒绝确认', () async {
    final accountId = '0x${'0a' * 32}';
    blobs.dropNextWrite = true;

    await expectLater(
      store.putAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
        childMiniSecret: Uint8List(32),
      ),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
      ),
      isFalse,
    );
  });

  test('删除账户只删密文 blob，回读为空且不删共享 KEK', () async {
    final accountId = '0x${'06' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );

    await store.deleteAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
    );

    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
      ),
      isFalse,
    );
    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationA),
      isTrue,
    );
    expect(vaultMethods, isNot(contains('deleteKey')));
  });

  test('删除钱包只删共享 KEK，账户 blob 由清理计划逐项删除', () async {
    final accountId = '0x${'07' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );

    await store.deleteWalletKey(walletIndex: 0, walletGeneration: _generationA);

    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationA),
      isFalse,
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
      ),
      isTrue,
    );
    expect(vaultMethods.where((method) => method == 'deleteKey'), hasLength(1));
  });

  test('blob 删除写后抛错仍可通过回读确认事实', () async {
    final accountId = '0x${'08' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );
    blobs.throwAfterNextDelete = true;

    await store.deleteAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
    );

    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
      ),
      isFalse,
    );
  });

  test('blob 删除正常返回但密文仍存在时拒绝确认', () async {
    final accountId = '0x${'0b' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );
    blobs.keepNextDelete = true;

    await expectLater(
      store.deleteAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
      ),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: accountId,
      ),
      isTrue,
    );
  });

  test('KEK 删除写后抛错仍可通过回读确认事实', () async {
    throwAfterDeleteKey = true;

    await store.deleteWalletKey(walletIndex: 0, walletGeneration: _generationA);

    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationA),
      isFalse,
    );
  });

  test('KEK 删除正常返回但硬件密钥仍存在时拒绝确认', () async {
    keepDeletedVaultKey = true;

    await expectLater(
      store.deleteWalletKey(walletIndex: 0, walletGeneration: _generationA),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationA),
      isTrue,
    );
  });

  test('相同 AccountId 的两代硬件密文与 KEK 精确隔离', () async {
    final accountId = '0x${'0c' * 32}';
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationB,
      secretOwner: _ownerB,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );

    expect(blobs.values, hasLength(2));
    await store.deleteAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
    );
    await store.deleteWalletKey(walletIndex: 0, walletGeneration: _generationA);

    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationB,
        secretOwner: _ownerB,
        accountId: accountId,
      ),
      isTrue,
    );
    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationB),
      isTrue,
    );
  });

  test('同一钱包和 AccountId 的两代 owner 密文不能交换', () async {
    authenticateAssociatedData = true;
    final accountId = '0x${'0d' * 32}';
    final oldKey = CitizenSdkSecretBlobKeys.account(
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
    );
    final newKey = CitizenSdkSecretBlobKeys.account(
      walletGeneration: _generationA,
      secretOwner: _ownerB,
      accountId: accountId,
    );
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerB,
      accountId: accountId,
      childMiniSecret: Uint8List(32),
    );
    blobs.values[newKey] = blobs.values[oldKey]!;

    await expectLater(
      store.readAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerB,
        accountId: accountId,
      ),
      throwsA(isA<SecureStoreUnavailable>()),
    );
  });
}

String _vaultScope(String generation) => 'citizensdk:0:$generation';

Uint8List _cipherForAssociatedData(Uint8List associatedData) {
  final result = Uint8List(32);
  for (var index = 0; index < associatedData.length; index++) {
    final position = index % result.length;
    result[position] =
        (result[position] ^ associatedData[index] ^ (index & 0xff)) & 0xff;
  }
  return result;
}

bool _sameBytes(Uint8List first, Uint8List second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
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
