import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'types.dart';

/// Platform-specific library loading and path resolution
class SmoldotPlatform {
  /// Library name without extension
  static const String _libraryName = 'smoldot';

  /// Get the dynamic library for the current platform
  static DynamicLibrary loadLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return _loadLinux();
    } else if (Platform.isIOS || Platform.isMacOS) {
      return _loadDarwin();
    } else if (Platform.isWindows) {
      return _loadWindows();
    } else {
      throw SmoldotFfiException(
        'Unsupported platform: ${Platform.operatingSystem}',
        details: 'Only Android, iOS, macOS, Linux, and Windows are supported',
      );
    }
  }

  /// Load library on Linux/Android
  static DynamicLibrary _loadLinux() {
    try {
      // Try loading from system library path
      return DynamicLibrary.open('lib$_libraryName.so');
    } catch (e) {
      // Try loading from package directory
      final libraryPath = _getPackageLibraryPath('lib$_libraryName.so');
      if (libraryPath != null) {
        return DynamicLibrary.open(libraryPath);
      }
      throw SmoldotFfiException(
        'Failed to load $_libraryName library on ${Platform.operatingSystem}',
        details: e.toString(),
      );
    }
  }

  /// Load library on macOS/iOS
  static DynamicLibrary _loadDarwin() {
    if (Platform.isIOS) {
      // iOS 上静态库 libsmoldot.a 经本地 pod(ios/smoldot)-force_load 链进
      // Runner 主二进制,符号直接从当前进程取;沙盒里也不存在独立 .dylib
      // 可 open,所以不做任何文件路径尝试(那只会白抛两层异常)。
      return DynamicLibrary.process();
    }

    // flutter_tester 不会链接 iOS CocoaPods 的静态库；macOS 宿主测试只能
    // dlopen 中央工作目录生成并注入隔离快照的 dylib。禁止退回当前进程句柄，
    // 否则“宿主库不存在”会被伪装成某一个 FFI 符号 lookup 失败。
    final libraryPath = _getPackageLibraryPath('lib$_libraryName.dylib');
    Object? packageError;
    if (libraryPath != null && File(libraryPath).existsSync()) {
      try {
        return DynamicLibrary.open(libraryPath);
      } on Object catch (error) {
        packageError = error;
      }
    }

    try {
      return DynamicLibrary.open('lib$_libraryName.dylib');
    } on Object catch (systemError) {
      throw SmoldotFfiException(
        'Failed to load $_libraryName library on ${Platform.operatingSystem}',
        details:
            'Library path: $libraryPath\n'
            'Package error: ${packageError ?? 'library not found'}\n'
            'System error: $systemError\n'
            'Run ./scripts/build-smoldot-native.sh host before flutter test.',
      );
    }
  }

  /// Load library on Windows
  static DynamicLibrary _loadWindows() {
    try {
      // Try loading from system library path
      return DynamicLibrary.open('$_libraryName.dll');
    } catch (e) {
      // Try loading from package directory
      final libraryPath = _getPackageLibraryPath('$_libraryName.dll');
      if (libraryPath != null) {
        return DynamicLibrary.open(libraryPath);
      }
      throw SmoldotFfiException(
        'Failed to load $_libraryName library on ${Platform.operatingSystem}',
        details: e.toString(),
      );
    }
  }

  /// Get the package library path for the given library name
  static String? _getPackageLibraryPath(String libraryName) {
    // 中文注释：源码树禁止出现任何编译产物。宿主测试只允许把中央工作目录
    // 生成的动态库注入隔离构建根目录，因此这里只检查当前工作目录；移动正式版
    // 仍分别走 Android 系统库搜索与 iOS 当前进程符号。
    final libraryPath = path.join(Directory.current.path, libraryName);
    return File(libraryPath).existsSync() ? libraryPath : null;
  }

  /// Get the current platform name
  static String get platformName => Platform.operatingSystem;

  /// Check if the platform is supported
  static bool get isSupported {
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isWindows;
  }

  /// Get platform-specific library extension
  static String get libraryExtension {
    if (Platform.isAndroid || Platform.isLinux) {
      return '.so';
    } else if (Platform.isIOS || Platform.isMacOS) {
      return '.dylib';
    } else if (Platform.isWindows) {
      return '.dll';
    }
    return '';
  }

  /// Get the full library name with extension
  static String get fullLibraryName {
    final prefix = Platform.isWindows ? '' : 'lib';
    return '$prefix$_libraryName$libraryExtension';
  }
}
