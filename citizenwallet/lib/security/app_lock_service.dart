import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../isar/wallet_isar.dart';
import '../wallet/wallet_secure_keys.dart';
import 'secure_storage.dart';

class AppDataWipeException implements Exception {
  AppDataWipeException(List<String> failures)
      : failures = List<String>.unmodifiable(failures);

  final List<String> failures;

  @override
  String toString() => 'AppDataWipeException(${failures.join('; ')})';
}

enum AppPinVerificationResult {
  verified,
  duressMode,
  rejected,
  locked,
  dataWiped,
}

enum AppDataWipeStartupResult {
  ready,
  dataWiped,
  retryRequired,
  preflightBlocked,
}

/// 应用锁（6 位 PIN）服务。
///
/// 普通 PIN 以 10 万次、`duress_mode` PIN 以 1 万次
/// PBKDF2-HMAC-SHA256(pin, salt) 存储在 SecureStorage 中。
/// 连续 5 次验证错误锁定 24 小时，累计 3 次锁定则清空全部应用数据。
class AppLockService {
  /// 普通应用锁与公民统一使用 10 万次派生。
  static const int appLockPinHashIterations = 100000;

  /// 防共匪密码与公民统一使用 1 万次派生。
  static const int duressModePinHashIterations = 10000;
  // 单源加固实例(选项集中在 secure_storage.dart)。
  static const _secure = appSecureStorage;
  static const String _keyPinHash = 'pin_hash';
  static const String _keyPinSalt = 'pin_salt';
  static const String _keyFailCount = 'pin_fail_count';
  static const String _keyLockUntil = 'pin_lock_until';
  static const String _keyLockCount = 'pin_lock_count';
  static const String _keyDuressModePinHash = 'duress_mode_pin_hash';
  static const String _keyDuressModePinSalt = 'duress_mode_pin_salt';
  static const String _keyDuressModeEnabled = 'duress_mode_enabled';
  static const String _pendingWipeMarker = '.citizenwallet_data_wipe.pending';
  static const String _completeWipeMarker = '.citizenwallet_data_wipe.complete';

  static const int maxFailAttempts = 5;
  static const int maxLockCount = 3;
  static const Duration lockDuration = Duration(hours: 24);
  static const Duration _wipeStepTimeout = Duration(seconds: 6);
  static Future<AppPinVerificationResult> Function(String)?
      _debugVerifyPinForTest;
  static Future<bool> Function()? _debugIsLockedForTest;
  static Future<void> Function()? _debugWipeAllDataForTest;
  static Future<void> Function()? _debugLatchPersistentWipeForTest;
  static bool _walletHardwareSecretsDeletedInProcess = false;

  @visibleForTesting
  static void debugConfigureForTest({
    Future<AppPinVerificationResult> Function(String)? verifyPin,
    Future<bool> Function()? isLocked,
    Future<void> Function()? wipeAllData,
    Future<void> Function()? latchPersistentWipe,
  }) {
    _requireFlutterTest();
    _debugVerifyPinForTest = verifyPin;
    _debugIsLockedForTest = isLocked;
    _debugWipeAllDataForTest = wipeAllData;
    _debugLatchPersistentWipeForTest = latchPersistentWipe;
  }

  @visibleForTesting
  static void debugResetForTest() {
    _requireFlutterTest();
    _debugVerifyPinForTest = null;
    _debugIsLockedForTest = null;
    _debugWipeAllDataForTest = null;
    _debugLatchPersistentWipeForTest = null;
    _walletHardwareSecretsDeletedInProcess = false;
  }

  // PIN 管理
  static Future<void> setPin(String pin) async {
    _requireSixDigitPin(pin);
    final salt = _generateSalt();
    final hash = await _hash(
      pin,
      salt,
      iterations: appLockPinHashIterations,
    );
    await _secure.write(key: _keyPinSalt, value: salt);
    await _secure.write(key: _keyPinHash, value: hash);
    await _secure.write(key: _keyFailCount, value: '0');
    await _secure.delete(key: _keyLockUntil);
    await _secure.write(key: _keyLockCount, value: '0');
  }

  static Future<AppPinVerificationResult> verifyPin(String pin) async {
    final debugVerify = _debugVerifyPinForTest;
    if (debugVerify != null) {
      _requireFlutterTest();
      return debugVerify(pin);
    }
    if (await isLocked()) return AppPinVerificationResult.locked;

    final normalHash = await _secure.read(key: _keyPinHash);
    final normalSalt = await _secure.read(key: _keyPinSalt);
    if (normalHash == null || normalSalt == null) {
      return AppPinVerificationResult.rejected;
    }

    // 普通密码是高频路径，一次派生即可进入；未命中时才继续识别防共匪密码。
    final inputNormalHash = await _hash(
      pin,
      normalSalt,
      iterations: appLockPinHashIterations,
    );
    if (inputNormalHash == normalHash) {
      await _secure.write(key: _keyFailCount, value: '0');
      return AppPinVerificationResult.verified;
    }
    if (await _matchesDuressModePin(pin)) {
      return AppPinVerificationResult.duressMode;
    }
    return _recordRejectedPin();
  }

  /// 设置页关闭应用锁只验证普通密码，不识别防共匪密码。
  static Future<AppPinVerificationResult> verifyNormalPin(String pin) async {
    if (await isLocked()) return AppPinVerificationResult.locked;
    return _verifyNormalPin(pin);
  }

  static Future<AppPinVerificationResult> _verifyNormalPin(String pin) async {
    final storedHash = await _secure.read(key: _keyPinHash);
    final storedSalt = await _secure.read(key: _keyPinSalt);
    if (storedHash == null || storedSalt == null) {
      return AppPinVerificationResult.rejected;
    }

    final inputHash = await _hash(
      pin,
      storedSalt,
      iterations: appLockPinHashIterations,
    );
    if (inputHash == storedHash) {
      await _secure.write(key: _keyFailCount, value: '0');
      return AppPinVerificationResult.verified;
    }

    return _recordRejectedPin();
  }

  static Future<AppPinVerificationResult> _recordRejectedPin() async {
    final failCount = await _readInt(_keyFailCount) + 1;
    await _secure.write(key: _keyFailCount, value: failCount.toString());

    if (failCount >= maxFailAttempts) {
      final lockCount = await _readInt(_keyLockCount) + 1;
      await _secure.write(key: _keyLockCount, value: lockCount.toString());
      await _secure.write(key: _keyFailCount, value: '0');

      if (lockCount >= maxLockCount) {
        await wipeAllData();
        return AppPinVerificationResult.dataWiped;
      }

      final lockUntil = DateTime.now().add(lockDuration).millisecondsSinceEpoch;
      await _secure.write(key: _keyLockUntil, value: lockUntil.toString());
      return AppPinVerificationResult.locked;
    }

    return AppPinVerificationResult.rejected;
  }

  static Future<void> removePin() async {
    await _secure.delete(key: _keyPinHash);
    await _secure.delete(key: _keyPinSalt);
    await _secure.delete(key: _keyFailCount);
    await _secure.delete(key: _keyLockUntil);
    await _secure.delete(key: _keyLockCount);
    await removeDuressMode();
  }

  static Future<bool> setDuressModePin(String pin) async {
    _requireSixDigitPin(pin);
    final normalHash = await _secure.read(key: _keyPinHash);
    final normalSalt = await _secure.read(key: _keyPinSalt);
    if (normalHash == null || normalSalt == null) return false;
    if (await _hash(
          pin,
          normalSalt,
          iterations: appLockPinHashIterations,
        ) ==
        normalHash) {
      return false;
    }

    final salt = _generateSalt();
    await _secure.write(key: _keyDuressModePinSalt, value: salt);
    await _secure.write(
      key: _keyDuressModePinHash,
      value: await _hash(
        pin,
        salt,
        iterations: duressModePinHashIterations,
      ),
    );
    await _secure.write(key: _keyDuressModeEnabled, value: 'true');
    return isDuressModeEnabled();
  }

  static Future<bool> isDuressModeEnabled() async {
    if (!await isPinSet()) return false;
    final enabled = await _secure.read(key: _keyDuressModeEnabled);
    final hash = await _secure.read(key: _keyDuressModePinHash);
    final salt = await _secure.read(key: _keyDuressModePinSalt);
    return enabled == 'true' &&
        hash != null &&
        hash.isNotEmpty &&
        salt != null &&
        salt.isNotEmpty;
  }

  static Future<void> removeDuressMode() async {
    await _secure.delete(key: _keyDuressModePinHash);
    await _secure.delete(key: _keyDuressModePinSalt);
    await _secure.delete(key: _keyDuressModeEnabled);
  }

  static Future<bool> _matchesDuressModePin(String pin) async {
    final enabled = await _secure.read(key: _keyDuressModeEnabled);
    if (enabled != 'true') return false;
    final hash = await _secure.read(key: _keyDuressModePinHash);
    final salt = await _secure.read(key: _keyDuressModePinSalt);
    return hash != null &&
        salt != null &&
        await _hash(
              pin,
              salt,
              iterations: duressModePinHashIterations,
            ) ==
            hash;
  }

  static Future<bool> isPinSet() async {
    final hash = await _secure.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  // 锁定状态
  static Future<bool> isLocked() async {
    final debugIsLocked = _debugIsLockedForTest;
    if (debugIsLocked != null) {
      _requireFlutterTest();
      return debugIsLocked();
    }
    final lockUntilStr = await _secure.read(key: _keyLockUntil);
    if (lockUntilStr == null) return false;
    final lockUntil = int.tryParse(lockUntilStr);
    if (lockUntil == null) return false;
    return DateTime.now().millisecondsSinceEpoch < lockUntil;
  }

  static Future<int> getRemainingLockSeconds() async {
    final lockUntilStr = await _secure.read(key: _keyLockUntil);
    if (lockUntilStr == null) return 0;
    final lockUntil = int.tryParse(lockUntilStr);
    if (lockUntil == null) return 0;
    final remaining = lockUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining ~/ 1000 : 0;
  }

  static Future<int> getFailCount() async => _readInt(_keyFailCount);
  static Future<int> getLockCount() async => _readInt(_keyLockCount);

  /// 启动时只要发现 pending，就在任何钱包页面构造前继续擦除。
  static Future<AppDataWipeStartupResult> recoverPersistentWipeAtStartup({
    Future<Directory> Function()? debugDocumentsDirectoryProvider,
    Future<void> Function()? debugDeleteSecureStorage,
    Future<void> Function()? debugClearSharedPreferences,
  }) async {
    _requireDebugProvidersInFlutterTest(
      debugDocumentsDirectoryProvider,
      debugDeleteSecureStorage,
      debugClearSharedPreferences,
    );
    try {
      final files = await _wipeMarkerFiles(debugDocumentsDirectoryProvider);
      if (await files.complete.exists()) {
        await files.complete.delete();
        return AppDataWipeStartupResult.ready;
      }
      if (!await files.pending.exists()) return AppDataWipeStartupResult.ready;
      try {
        await wipeAllData(
          debugDocumentsDirectoryProvider: debugDocumentsDirectoryProvider,
          debugDeleteSecureStorage: debugDeleteSecureStorage,
          debugClearSharedPreferences: debugClearSharedPreferences,
        );
        return AppDataWipeStartupResult.dataWiped;
      } catch (_) {
        return AppDataWipeStartupResult.retryRequired;
      }
    } catch (_) {
      return AppDataWipeStartupResult.preflightBlocked;
    }
  }

  static Future<void> latchPersistentWipe({
    Future<Directory> Function()? debugDocumentsDirectoryProvider,
  }) async {
    final debugLatch = _debugLatchPersistentWipeForTest;
    if (debugLatch != null) {
      _requireFlutterTest();
      if (debugDocumentsDirectoryProvider != null) {
        throw StateError('禁止同时使用两组 AppLock 测试注入');
      }
      return debugLatch();
    }
    _requireDebugProvidersInFlutterTest(
      debugDocumentsDirectoryProvider,
      null,
      null,
    );
    final files = await _wipeMarkerFiles(debugDocumentsDirectoryProvider);
    if (await files.complete.exists()) await files.complete.delete();
    await files.pending.writeAsString('pending', flush: true);
    if (!await files.pending.exists()) throw StateError('持久擦除门闩未落盘');
  }

  // 数据清空
  static Future<void> wipeAllData({
    Future<Directory> Function()? debugDocumentsDirectoryProvider,
    Future<void> Function()? debugDeleteSecureStorage,
    Future<void> Function()? debugClearSharedPreferences,
  }) async {
    final debugWipe = _debugWipeAllDataForTest;
    if (debugWipe != null) {
      _requireFlutterTest();
      if (debugDocumentsDirectoryProvider != null ||
          debugDeleteSecureStorage != null ||
          debugClearSharedPreferences != null) {
        throw StateError('禁止同时使用两组 AppLock 测试注入');
      }
      return debugWipe();
    }
    _requireDebugProvidersInFlutterTest(
      debugDocumentsDirectoryProvider,
      debugDeleteSecureStorage,
      debugClearSharedPreferences,
    );
    final failures = <String>[];
    var markerReady = false;
    try {
      await latchPersistentWipe(
        debugDocumentsDirectoryProvider: debugDocumentsDirectoryProvider,
      ).timeout(_wipeStepTimeout);
      markerReady = true;
    } catch (error) {
      failures.add('持久擦除门闩：$error');
    }

    var walletSecretsDeleted = _walletHardwareSecretsDeletedInProcess;
    if (!walletSecretsDeleted) {
      walletSecretsDeleted = true;
      try {
        final isar = await WalletIsar.instance.db();
        final wallets =
            await isar.walletEntitys.where().sortByWalletIndex().findAll();
        final secretStore = WalletSecureKeys();
        for (final wallet in wallets) {
          try {
            await secretStore.deleteHardwareKey(wallet.masterId);
            if (await secretStore.containsHardwareKey(wallet.masterId)) {
              throw StateError('硬件密钥仍存在');
            }
          } catch (error) {
            walletSecretsDeleted = false;
            failures.add('钱包硬件密钥(${wallet.masterId})：$error');
          }
        }
      } catch (error) {
        walletSecretsDeleted = false;
        failures.add('钱包密钥索引：$error');
      }
      if (walletSecretsDeleted) {
        _walletHardwareSecretsDeletedInProcess = true;
      }
    }

    // 先确认硬件密钥删除并保留可重试索引，再清空平台安全存储，避免失败后丢失密钥清理依据。
    if (markerReady && walletSecretsDeleted) {
      await _attemptWipe(
        'SecureStorage',
        debugDeleteSecureStorage ?? _deleteAndVerifySecureStorage,
        failures,
      );
    } else if (!markerReady) {
      failures.add('SecureStorage：持久擦除门闩未就绪，已安全跳过');
    } else {
      failures.add('SecureStorage：硬件密钥未全部确认删除，已安全保留重试索引');
    }

    if (walletSecretsDeleted) {
      await _attemptWipe(
        'WalletIsar',
        WalletIsar.instance.closeAndDeleteFromDisk,
        failures,
      );
    } else {
      failures.add('WalletIsar：硬件密钥未全部确认删除，已安全保留重试索引');
    }

    if (markerReady && walletSecretsDeleted) {
      await _attemptWipe(
        'SharedPreferences',
        debugClearSharedPreferences ?? _clearAndVerifySharedPreferences,
        failures,
      );
    } else {
      failures.add('SharedPreferences：关键擦除前置条件未完成，已安全跳过');
    }

    if (failures.isEmpty) {
      try {
        final files = await _wipeMarkerFiles(debugDocumentsDirectoryProvider);
        await files.complete.writeAsString('complete', flush: true);
        if (await files.pending.exists()) await files.pending.delete();
      } catch (error) {
        failures.add('持久擦除完成态：$error');
      }
    }
    if (failures.isNotEmpty) throw AppDataWipeException(failures);
  }

  static Future<void> _deleteAndVerifySecureStorage() async {
    await _secure.deleteAll();
    if ((await _secure.readAll()).isNotEmpty) {
      throw StateError('安全存储仍有残留');
    }
  }

  static Future<void> _clearAndVerifySharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.clear() || prefs.getKeys().isNotEmpty) {
      throw StateError('偏好设置仍有残留');
    }
  }

  static Future<void> _attemptWipe(
    String dataDomain,
    Future<void> Function() operation,
    List<String> failures,
  ) async {
    try {
      await Future<void>.sync(operation).timeout(_wipeStepTimeout);
    } catch (error) {
      failures.add('$dataDomain：$error');
    }
  }

  static Future<({File pending, File complete})> _wipeMarkerFiles(
    Future<Directory> Function()? directoryProvider,
  ) async {
    final directory =
        await (directoryProvider ?? getApplicationDocumentsDirectory)();
    await directory.create(recursive: true);
    return (
      pending: File('${directory.path}/$_pendingWipeMarker'),
      complete: File('${directory.path}/$_completeWipeMarker'),
    );
  }

  static void _requireDebugProvidersInFlutterTest(
    Object? directoryProvider,
    Object? deleteSecureStorage,
    Object? clearSharedPreferences,
  ) {
    if ((directoryProvider != null ||
            deleteSecureStorage != null ||
            clearSharedPreferences != null) &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('AppLock 测试注入仅允许 flutter test 进程');
    }
  }

  static void _requireFlutterTest() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('AppLock 测试注入仅允许 flutter test 进程');
    }
  }

  // 内部工具
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    try {
      for (var index = 0; index < bytes.length; index++) {
        bytes[index] = random.nextInt(256);
      }
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } finally {
      _zeroBytes(bytes);
    }
  }

  /// 按密码用途执行固定次数的 PBKDF2-HMAC-SHA256，并在辅助 isolate 中派生。
  static Future<String> _hash(
    String pin,
    String salt, {
    required int iterations,
  }) {
    return Isolate.run(() {
      final pinBytes = Uint8List.fromList(utf8.encode(pin));
      final saltBytes = Uint8List.fromList(utf8.encode(salt));
      final output = Uint8List(32);
      try {
        final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
          ..init(Pbkdf2Parameters(saltBytes, iterations, output.length));
        derivator.deriveKey(pinBytes, 0, output, 0);
        return output
            .map((value) => value.toRadixString(16).padLeft(2, '0'))
            .join();
      } finally {
        _zeroBytes(pinBytes);
        _zeroBytes(saltBytes);
        _zeroBytes(output);
      }
    });
  }

  static void _zeroBytes(List<int> bytes) {
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = 0;
    }
  }

  static Future<int> _readInt(String key) async {
    final str = await _secure.read(key: key);
    if (str == null) return 0;
    return int.tryParse(str) ?? 0;
  }

  static void _requireSixDigitPin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', '必须是 6 位数字密码');
    }
  }
}
