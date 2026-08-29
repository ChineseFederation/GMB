import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage for Base64 hardware ciphertext only; plaintext is never accepted.
abstract interface class SecureBlobStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecureBlobStore implements SecureBlobStore {
  FlutterSecureBlobStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stable key names for CitizenSDK hardware ciphertext blobs.
abstract final class CitizenSdkSecretBlobKeys {
  static final RegExp _accountIdPattern = RegExp(r'^0x[0-9a-f]{64}$');

  static String account(String accountId) {
    _validate(accountId);
    return 'citizensdk.wallet.secret.$accountId.account_mini_secret';
  }

  static void _validate(String accountId) {
    if (!_accountIdPattern.hasMatch(accountId)) {
      throw ArgumentError.value(accountId, 'accountId', 'AccountId 格式无效');
    }
  }
}
