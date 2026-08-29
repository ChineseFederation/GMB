import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('citizen/sdk/test/hardware_bound_seed_store');
  late _MemoryBlobStore blobs;
  late HardwareBoundSeedStore store;

  setUp(() {
    blobs = _MemoryBlobStore();
    store = HardwareBoundSeedStore(
      hardwareVault: HardwareSecretVault(channel: channel),
      blobStore: blobs,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'securityStatus':
              return <String, Object>{
                'supported': true,
                'strongBiometricEnrolled': true,
              };
            case 'encrypt':
              return Uint8List.fromList(<int>[1, 2, 3]);
            case 'decrypt':
              return Uint8List.fromList(List<int>.generate(32, (i) => i));
            case 'containsKey':
              return true;
            case 'deleteKey':
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
}

final class _MemoryBlobStore implements SecureBlobStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
