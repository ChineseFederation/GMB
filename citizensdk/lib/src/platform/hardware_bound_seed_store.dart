import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;

import '../wallet/secure_seed_store.dart';
import 'hardware_secret_vault.dart';
import 'secure_blob_store.dart';

/// 无根热钱包机密合同的移动端实现。
///
/// 只持久化每账户 32 字节 child mini-secret。产品标识固定为
/// `citizensdk`，宿主产品不得覆盖。
final class HardwareBoundSeedStore implements SecureSeedStore {
  HardwareBoundSeedStore({
    HardwareSecretVault? hardwareVault,
    SecureBlobStore? blobStore,
  }) : _hardwareVault = hardwareVault ?? HardwareSecretVault(),
       _blobStore = blobStore ?? FlutterSecureBlobStore();

  final HardwareSecretVault _hardwareVault;
  final SecureBlobStore _blobStore;

  @override
  Future<SecureAuthStatus> authStatus() async {
    try {
      switch (await _hardwareVault.availability()) {
        case HardwareSecretVaultAvailability.available:
          return SecureAuthStatus.available;
        case HardwareSecretVaultAvailability.noStrongBiometric:
          return SecureAuthStatus.noDeviceLock;
        case HardwareSecretVaultAvailability.unsupported:
          return SecureAuthStatus.unsupported;
      }
    } on Object catch (error) {
      _throwMapped(error);
    }
  }

  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {
    if (childMiniSecret.length != 32) {
      throw const SecureStoreUnavailable('账户 MiniSecretKey 必须为 32 字节');
    }
    final key = CitizenSdkSecretBlobKeys.account(accountId);
    final context = _context(walletIndex, accountId);
    Uint8List? encrypted;
    try {
      encrypted = await _hardwareVault.encrypt(
        context,
        childMiniSecret,
      );
      await _writeBlobAndConfirm(
        key: key,
        value: base64Encode(encrypted),
      );
    } on SecureSeedException {
      rethrow;
    } on HardwareSecretVaultException catch (error) {
      _mapAndThrow(error);
    } on PlatformException catch (error) {
      throw SecureStoreUnavailable(error.message ?? error.code);
    } on MissingPluginException catch (error) {
      throw SecureStoreUnavailable(
        error.message ?? 'CitizenSDK 移动存储插件不可用',
      );
    } on Object catch (error) {
      _throwMapped(error);
    } finally {
      if (encrypted != null) HardwareSecretVault.clearBytes(encrypted);
    }
  }

  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    final key = CitizenSdkSecretBlobKeys.account(accountId);
    final stored = await _readBlob(key);
    if (stored == null) return null;
    final context = _context(walletIndex, accountId);

    Uint8List? encrypted;
    try {
      encrypted = Uint8List.fromList(base64Decode(stored));
      final plaintext = await _hardwareVault.decrypt(
        context,
        encrypted,
      );
      if (plaintext.length != 32) {
        HardwareSecretVault.clearBytes(plaintext);
        throw const SecureStoreUnavailable('账户 MiniSecretKey 长度异常');
      }
      return plaintext;
    } on SecureSeedException {
      rethrow;
    } on FormatException {
      throw const SecureStoreUnavailable('账户硬件密文格式异常');
    } on HardwareSecretVaultException catch (error) {
      _mapAndThrow(error);
    } on PlatformException catch (error) {
      throw SecureStoreUnavailable(error.message ?? error.code);
    } on MissingPluginException catch (error) {
      throw SecureStoreUnavailable(
        error.message ?? 'CitizenSDK 移动存储插件不可用',
      );
    } on Object catch (error) {
      _throwMapped(error);
    } finally {
      if (encrypted != null) HardwareSecretVault.clearBytes(encrypted);
    }
  }

  @override
  Future<bool> hasAccountKey(String accountId) async =>
      await _readBlob(CitizenSdkSecretBlobKeys.account(accountId)) != null;

  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String accountId,
  }) => _deleteBlobAndConfirmAbsent(
    CitizenSdkSecretBlobKeys.account(accountId),
  );

  @override
  Future<void> deleteWalletKey({required int walletIndex}) =>
      _deleteWalletKeyAndConfirmAbsent(walletIndex);

  @override
  Future<bool> hasWalletKey({required int walletIndex}) =>
      _containsWalletKey(walletIndex);

  static HardwareSecretContext _context(int walletIndex, String accountId) =>
      HardwareSecretContext(
        scope: walletIndex.toString(),
        accountId: accountId,
        secretType: HardwareSecretType.accountMiniSecret,
      );

  Future<String?> _readBlob(String key) async {
    try {
      return await _blobStore.read(key);
    } on Object catch (error) {
      _throwMapped(error);
    }
  }

  Future<void> _writeBlob(String key, String value) async {
    try {
      await _blobStore.write(key, value);
    } on Object catch (error) {
      _throwMapped(error);
    }
  }

  Future<void> _deleteBlob(String key) async {
    try {
      await _blobStore.delete(key);
    } on Object catch (error) {
      _throwMapped(error);
    }
  }

  Future<void> _writeBlobAndConfirm({
    required String key,
    required String value,
  }) async {
    Object? writeError;
    StackTrace? writeStackTrace;
    try {
      await _writeBlob(key, value);
    } on Object catch (error, stackTrace) {
      writeError = error;
      writeStackTrace = stackTrace;
    }

    String? persisted;
    try {
      persisted = await _readBlob(key);
    } on Object catch (readError, readStackTrace) {
      if (writeError != null) {
        Error.throwWithStackTrace(writeError, writeStackTrace!);
      }
      Error.throwWithStackTrace(readError, readStackTrace);
    }
    if (persisted == value) return;
    if (writeError != null) {
      Error.throwWithStackTrace(writeError, writeStackTrace!);
    }
    throw const SecureStoreUnavailable('账户硬件密文写后回读不一致');
  }

  Future<void> _deleteBlobAndConfirmAbsent(String key) async {
    Object? deleteError;
    StackTrace? deleteStackTrace;
    try {
      await _deleteBlob(key);
    } on Object catch (error, stackTrace) {
      deleteError = error;
      deleteStackTrace = stackTrace;
    }

    String? persisted;
    try {
      persisted = await _readBlob(key);
    } on Object catch (readError, readStackTrace) {
      if (deleteError != null) {
        Error.throwWithStackTrace(deleteError, deleteStackTrace!);
      }
      Error.throwWithStackTrace(readError, readStackTrace);
    }
    if (persisted == null) return;
    if (deleteError != null) {
      Error.throwWithStackTrace(deleteError, deleteStackTrace!);
    }
    throw const SecureStoreUnavailable('账户硬件密文删除后仍存在');
  }

  Future<void> _deleteWalletKeyAndConfirmAbsent(int walletIndex) async {
    Object? deleteError;
    StackTrace? deleteStackTrace;
    try {
      await _deleteWalletKey(walletIndex);
    } on Object catch (error, stackTrace) {
      deleteError = error;
      deleteStackTrace = stackTrace;
    }

    bool exists;
    try {
      exists = await _containsWalletKey(walletIndex);
    } on Object catch (readError, readStackTrace) {
      if (deleteError != null) {
        Error.throwWithStackTrace(deleteError, deleteStackTrace!);
      }
      Error.throwWithStackTrace(readError, readStackTrace);
    }
    if (!exists) return;
    if (deleteError != null) {
      Error.throwWithStackTrace(deleteError, deleteStackTrace!);
    }
    throw const SecureStoreUnavailable('钱包硬件 KEK 删除后仍存在');
  }

  Future<void> _deleteWalletKey(int walletIndex) async {
    try {
      await _hardwareVault.deleteKey(scope: walletIndex.toString());
    } on Object catch (error) {
      _throwMapped(error);
    }
  }

  Future<bool> _containsWalletKey(int walletIndex) async {
    try {
      return await _hardwareVault.containsKey(scope: walletIndex.toString());
    } on Object catch (error) {
      _throwMapped(error);
    }
  }

  Never _mapAndThrow(HardwareSecretVaultException error) {
    switch (error.code) {
      case 'keyPermanentlyInvalidated':
        throw SeedKeyInvalidated(error.message);
      case 'userCancelled':
      case 'lockout':
        throw AuthCancelled(error.message);
      case 'notEnrolled':
        throw NoDeviceCredential(error.message);
      default:
        throw SecureStoreUnavailable(error.message);
    }
  }

  Never _throwMapped(Object error) {
    if (error is SecureSeedException) throw error;
    if (error is HardwareSecretVaultException) _mapAndThrow(error);
    if (error is PlatformException) {
      throw SecureStoreUnavailable(error.message ?? error.code);
    }
    if (error is MissingPluginException) {
      throw SecureStoreUnavailable(
        error.message ?? 'CitizenSDK 移动存储插件不可用',
      );
    }
    throw SecureStoreUnavailable(error.toString());
  }
}
