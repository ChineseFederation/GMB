import 'package:flutter/services.dart';

/// 防共匪擦除期间的原生生命周期桥。
///
/// Android 会把任务移到后台但保留 Flutter 引擎；iOS 只申请系统允许的有限后台
/// 执行时间。平台桥只是提高本进程完成概率，真正的不可逆保证仍由持久门闩提供。
final class EmergencyWipePlatform {
  EmergencyWipePlatform._();

  static const MethodChannel _channel = MethodChannel('citizenapp/security');

  static Future<void> beginProtectedExecution() =>
      _bestEffort('beginEmergencyWipe');

  static Future<void> finishProtectedExecution() =>
      _bestEffort('finishEmergencyWipe');

  static Future<void> _bestEffort(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // 测试、桌面端或旧原生壳没有桥时仍必须在当前 isolate 完成擦除。
    } on PlatformException {
      // 门闩已经落盘；平台生命周期加固失败不能取消不可逆擦除。
    }
  }
}
