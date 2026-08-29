import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;

/// Substrate key material accepted by the hardware vault envelope.
enum HardwareSecretType {
  accountMiniSecret('account_mini_secret'),
  masterMiniSecret('master_mini_secret'),
  mnemonic('mnemonic');

  const HardwareSecretType(this.storageName);

  final String storageName;
}

/// An unambiguous secret identity used as authenticated associated data.
final class HardwareSecretContext {
  HardwareSecretContext({
    required this.scope,
    required this.secretType,
    this.accountId,
  }) {
    if (!_scopePattern.hasMatch(scope)) {
      throw ArgumentError.value(scope, 'scope', '钱包作用域格式无效');
    }
    final value = accountId;
    if (value != null && !_accountIdPattern.hasMatch(value)) {
      throw ArgumentError.value(value, 'accountId', 'AccountId 格式无效');
    }
    if (secretType == HardwareSecretType.accountMiniSecret && value == null) {
      throw ArgumentError('账户 MiniSecretKey 必须绑定 AccountId');
    }
  }

  static final RegExp _scopePattern = RegExp(r'^[a-z0-9._:-]{1,80}$');
  static final RegExp _accountIdPattern = RegExp(r'^0x[0-9a-f]{64}$');

  final String scope;
  final String? accountId;
  final HardwareSecretType secretType;

  /// Hardware envelopes always belong to CitizenSDK, including when the SDK
  /// is embedded by another application. Hosts cannot override this identity.
  String get keyScope => '${HardwareBoundProduct.identifier}:$scope';

  /// Preserves the stable GMB vault AAD domain and field order byte-for-byte.
  Uint8List associatedData() => Uint8List.fromList(
    utf8.encode(
      'GMB\n${HardwareBoundProduct.identifier}\n$scope\n'
      '${accountId ?? ''}\n${secretType.storageName}',
    ),
  );
}

enum HardwareSecretVaultAvailability {
  available,
  noStrongBiometric,
  unsupported,
}

/// Byte-only Flutter bridge to the CitizenSDK hardware vault.
///
/// Mnemonics and mini-secrets never cross the channel as immutable strings.
final class HardwareSecretVault {
  HardwareSecretVault({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'citizen/sdk/hardware_secretvault';

  final MethodChannel _channel;

  Future<HardwareSecretVaultAvailability> availability() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'securityStatus',
      );
      if (result?['strongBiometricEnrolled'] != true) {
        return HardwareSecretVaultAvailability.noStrongBiometric;
      }
      return result?['supported'] == true
          ? HardwareSecretVaultAvailability.available
          : HardwareSecretVaultAvailability.unsupported;
    } on PlatformException {
      return HardwareSecretVaultAvailability.unsupported;
    } on MissingPluginException {
      return HardwareSecretVaultAvailability.unsupported;
    }
  }

  Future<Uint8List> encrypt(
    HardwareSecretContext context,
    Uint8List plaintext,
  ) async {
    if (plaintext.isEmpty) {
      throw ArgumentError.value(plaintext, 'plaintext', '机密不能为空');
    }
    final aad = context.associatedData();
    try {
      final result = await _channel.invokeMethod<Uint8List>('encrypt', {
        'scope': context.keyScope,
        'keyNamespace': HardwareBoundProduct.identifier,
        'associatedData': aad,
        'plaintext': plaintext,
      });
      if (result == null || result.isEmpty) {
        throw const HardwareSecretVaultException('encryptFailed', '硬件金库返回空密文');
      }
      return Uint8List.fromList(result);
    } on PlatformException catch (error) {
      throw HardwareSecretVaultException(
        error.code,
        error.message ?? error.code,
      );
    } on MissingPluginException catch (error) {
      throw HardwareSecretVaultException(
        'unavailable',
        error.message ?? 'CitizenSDK 硬件金库插件不可用',
      );
    } finally {
      clearBytes(aad);
    }
  }

  Future<Uint8List> decrypt(
    HardwareSecretContext context,
    Uint8List ciphertext,
  ) async {
    if (ciphertext.isEmpty) {
      throw ArgumentError.value(ciphertext, 'ciphertext', '密文不能为空');
    }
    final aad = context.associatedData();
    try {
      final borrowed = await _channel.invokeMethod<Uint8List>('decrypt', {
        'scope': context.keyScope,
        'keyNamespace': HardwareBoundProduct.identifier,
        'associatedData': aad,
        'ciphertext': ciphertext,
      });
      if (borrowed == null || borrowed.isEmpty) {
        throw const HardwareSecretVaultException('decryptFailed', '硬件金库返回空明文');
      }
      return Uint8List.fromList(borrowed);
    } on PlatformException catch (error) {
      throw HardwareSecretVaultException(
        error.code,
        error.message ?? error.code,
      );
    } on MissingPluginException catch (error) {
      throw HardwareSecretVaultException(
        'unavailable',
        error.message ?? 'CitizenSDK 硬件金库插件不可用',
      );
    } finally {
      clearBytes(aad);
    }
  }

  Future<void> deleteKey({required String scope}) async {
    final context = HardwareSecretContext(
      scope: scope,
      secretType: HardwareSecretType.masterMiniSecret,
    );
    try {
      await _channel.invokeMethod<void>('deleteKey', {
        'scope': context.keyScope,
        'keyNamespace': HardwareBoundProduct.identifier,
      });
    } on PlatformException catch (error) {
      throw HardwareSecretVaultException(
        error.code,
        error.message ?? error.code,
      );
    } on MissingPluginException catch (error) {
      throw HardwareSecretVaultException(
        'unavailable',
        error.message ?? 'CitizenSDK 硬件金库插件不可用',
      );
    }
  }

  Future<bool> containsKey({required String scope}) async {
    final context = HardwareSecretContext(
      scope: scope,
      secretType: HardwareSecretType.masterMiniSecret,
    );
    try {
      return await _channel.invokeMethod<bool>('containsKey', {
            'scope': context.keyScope,
            'keyNamespace': HardwareBoundProduct.identifier,
          }) ??
          false;
    } on PlatformException catch (error) {
      throw HardwareSecretVaultException(
        error.code,
        error.message ?? error.code,
      );
    } on MissingPluginException catch (error) {
      throw HardwareSecretVaultException(
        'unavailable',
        error.message ?? 'CitizenSDK 硬件金库插件不可用',
      );
    }
  }

  /// Clears an owned, writable byte buffer.
  static void clearBytes(List<int> bytes) {
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = 0;
    }
  }
}

/// The one fixed product identifier used by newly written hardware envelopes.
abstract final class HardwareBoundProduct {
  static const String identifier = 'citizensdk';
}

final class HardwareSecretVaultException implements Exception {
  const HardwareSecretVaultException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
