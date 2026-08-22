import 'package:flutter/services.dart';
import 'package:citizenapp/isar/user_isar.dart';

/// App 首次启动权限策略。
///
///
/// - 网络权限是 Android 普通权限，只能声明，不能也不需要运行时弹窗。
/// - 通知权限需要运行时申请，因此放在首启说明后的用户动作里。
/// - 相机与相册权限保持功能触发时申请，避免用户刚安装就被索取敏感权限。
class AppPermissionBootstrap {
  AppPermissionBootstrap._();

  static const MethodChannel _channel = MethodChannel('citizenapp/permissions');

  static Future<bool> shouldShowGuide() async {
    return UserIsar.instance.read((isar) async {
      final settings = await isar.userSettingsEntitys.get(0);
      return !(settings?.permissionGuideSeen ?? false);
    });
  }

  static Future<void> markGuideSeen() async {
    await UserIsar.instance.writeTxn((isar) async {
      final settings =
          await isar.userSettingsEntitys.get(0) ?? UserSettingsEntity();
      settings
        ..id = 0
        ..permissionGuideSeen = true
        ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      await isar.userSettingsEntitys.put(settings);
    });
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission');
      return granted ?? false;
    } on MissingPluginException {
      // 测试环境或不支持的平台没有原生通道时，不把权限申请失败当成启动失败。
      return false;
    } on PlatformException {
      return false;
    }
  }
}
