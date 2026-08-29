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

/// CitizenSDK hardware ciphertext keys with exact wallet/account ownership.
abstract final class CitizenSdkSecretBlobKeys {
  static final RegExp _accountIdPattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp _ownerPattern = RegExp(r'^[0-9a-f]{32}$');

  static String account({
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) {
    _validateOwner(walletGeneration, 'walletGeneration');
    _validateOwner(secretOwner, 'secretOwner');
    _validateAccountId(accountId);
    return 'citizensdk.wallet.secret.$walletGeneration.$secretOwner.'
        '$accountId.account_mini_secret';
  }

  static void _validateAccountId(String accountId) {
    if (!_accountIdPattern.hasMatch(accountId)) {
      throw ArgumentError.value(accountId, 'accountId', 'AccountId 格式无效');
    }
  }

  static void _validateOwner(String value, String name) {
    if (!_ownerPattern.hasMatch(value)) {
      throw ArgumentError.value(value, name, '钱包所有权标识格式无效');
    }
  }
}
