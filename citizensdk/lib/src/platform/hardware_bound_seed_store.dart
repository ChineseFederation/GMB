import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;

import '../wallet/secure_seed_store.dart';
import 'hardware_secret_vault.dart';
import 'secure_blob_store.dart';

/// Mobile implementation of the rootless hot-wallet secret contract.
///
/// Only 32-byte per-account child mini-secrets are persisted. The fixed product
/// identifier is `citizensdk`; no host product may override it.
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
    switch (await _hardwareVault.availability()) {
      case HardwareSecretVaultAvailability.available:
        return SecureAuthStatus.available;
      case HardwareSecretVaultAvailability.noStrongBiometric:
        return SecureAuthStatus.noDeviceLock;
      case HardwareSecretVaultAvailability.unsupported:
        return SecureAuthStatus.unsupported;
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
    Uint8List? encrypted;
    try {
      encrypted = await _hardwareVault.encrypt(
        _context(walletIndex, accountId),
        childMiniSecret,
      );
      await _writeBlob(
        CitizenSdkSecretBlobKeys.account(accountId),
        base64Encode(encrypted),
      );
    } on HardwareSecretVaultException catch (error) {
      _mapAndThrow(error);
    } on PlatformException catch (error) {
      throw SecureStoreUnavailable(error.message ?? error.code);
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

    Uint8List? encrypted;
    try {
      encrypted = Uint8List.fromList(base64Decode(stored));
      final plaintext = await _hardwareVault.decrypt(
        _context(walletIndex, accountId),
        encrypted,
      );
      if (plaintext.length != 32) {
        HardwareSecretVault.clearBytes(plaintext);
        throw const SecureStoreUnavailable('账户 MiniSecretKey 长度异常');
      }
      return plaintext;
    } on FormatException {
      throw const SecureStoreUnavailable('账户硬件密文格式异常');
    } on HardwareSecretVaultException catch (error) {
      _mapAndThrow(error);
    } on PlatformException catch (error) {
      throw SecureStoreUnavailable(error.message ?? error.code);
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
  }) => _deleteBlob(CitizenSdkSecretBlobKeys.account(accountId));

  @override
  Future<void> deleteWalletKey({required int walletIndex}) =>
      _hardwareVault.deleteKey(scope: walletIndex.toString());

  @override
  Future<bool> hasWalletKey({required int walletIndex}) =>
      _hardwareVault.containsKey(scope: walletIndex.toString());

  static HardwareSecretContext _context(int walletIndex, String accountId) =>
      HardwareSecretContext(
        scope: walletIndex.toString(),
        accountId: accountId,
        secretType: HardwareSecretType.accountMiniSecret,
      );

  Future<String?> _readBlob(String key) async {
    try {
      return await _blobStore.read(key);
    } on PlatformException catch (error) {
      throw SecureStoreUnavailable(error.message ?? error.code);
    } on MissingPluginException catch (error) {
      throw SecureStoreUnavailable(error.message ?? 'CitizenSDK 移动存储插件不可用');
    }
  }

  Future<void> _writeBlob(String key, String value) async {
    try {
      await _blobStore.write(key, value);
    } on PlatformException catch (error) {
      throw SecureStoreUnavailable(error.message ?? error.code);
    } on MissingPluginException catch (error) {
      throw SecureStoreUnavailable(error.message ?? 'CitizenSDK 移动存储插件不可用');
    }
  }

  Future<void> _deleteBlob(String key) async {
    try {
      await _blobStore.delete(key);
    } on PlatformException catch (error) {
      throw SecureStoreUnavailable(error.message ?? error.code);
    } on MissingPluginException catch (error) {
      throw SecureStoreUnavailable(error.message ?? 'CitizenSDK 移动存储插件不可用');
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
}
