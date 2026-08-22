import 'package:flutter/services.dart';

/// 截屏保护工具（进程级全局资源，引用计数管理）。
///
/// - Android: 通过 FLAG_SECURE 阻止截屏和屏幕录制。
/// - iOS: 进入后台时添加模糊遮罩，检测截屏事件。
///
/// 敏感页面可能嵌套打开；每个页面各持有一次引用，只有最后一个页面退出时才关闭
/// 原生保护，避免子页面退出后误把父页面仍需的保护一并关闭。
class ScreenshotGuard {
  const ScreenshotGuard._();

  static const MethodChannel _channel = MethodChannel('citizenapp/security');

  static int _refCount = 0;

  /// 启用截屏保护。每次调用持有一个引用，首次持有时才切换原生开关。
  static Future<void> enable() async {
    _refCount++;
    if (_refCount != 1) return;
    try {
      await _channel.invokeMethod('enableScreenshotProtection');
    } on PlatformException {
      // 平台不支持，忽略。
    } on MissingPluginException {
      // 非移动端测试环境没有原生实现，忽略。
    }
  }

  /// 释放一次截屏保护引用；引用归零时才关闭原生开关。
  static Future<void> disable() async {
    if (_refCount == 0) return;
    _refCount--;
    if (_refCount != 0) return;
    try {
      await _channel.invokeMethod('disableScreenshotProtection');
    } on PlatformException {
      // 平台不支持，忽略。
    } on MissingPluginException {
      // 非移动端测试环境没有原生实现，忽略。
    }
  }

  /// 检测设备是否已 root（Android）或越狱（iOS）。
  static Future<bool> isDeviceRooted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceRooted');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
