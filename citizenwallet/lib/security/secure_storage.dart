import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 全 App 单源的加固 SecureStorage 实例。
///
/// 这里只保存硬件金库信封密文、PIN 派生材料和锁设置；master
/// [MiniSecretKey]、助记词与硬件 KEK 均不会以明文进入本存储。硬化选项集中一处，
/// 避免各文件各自 `FlutterSecureStorage()` 时选项漂移。
///
/// - Android:使用插件 10.x 默认 RSA-OAEP + AES-GCM，并允许安全迁移旧算法。
///   需 minSdk ≥ 24(同时满足 local_auth 3.x)。
/// - iOS:钥匙串可访问性设为 first_unlock_this_device —— 不随 iCloud 备份/
///   迁移外泄,仅本机首次解锁后可读,契合冷钱包只在前台解锁态使用的场景。
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    migrateOnAlgorithmChange: true,
    migrateWithBackup: true,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
