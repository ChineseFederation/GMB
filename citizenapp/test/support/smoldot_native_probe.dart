import 'dart:ffi';
import 'dart:io';

String? _smoldotSkipReason;
bool _smoldotProbeCompleted = false;

/// Returns null when the independent smoldot host library can be loaded.
String? smoldotNativeSkipReason() {
  if (_smoldotProbeCompleted) return _smoldotSkipReason;
  _smoldotProbeCompleted = true;

  final cwd = Directory.current.path;
  final ci = Platform.environment['CI'] == 'true';
  // 本机只验本端 Cargo 产物；CI 保持既有 Runner 相对路径和系统装载行为。
  final target = ci
      ? '$cwd/smoldot/ffi/target'
      : Platform.environment['CARGO_TARGET_DIR'];
  if (target == null || (!ci && !target.startsWith('/'))) {
    _smoldotSkipReason = '本机原生测试缺少当前任务 CARGO_TARGET_DIR';
    return _smoldotSkipReason;
  }
  final candidates = switch (Platform.operatingSystem) {
    'macos' => <String>[
        '$target/release/libsmoldot.dylib',
        if (ci) 'libsmoldot.dylib',
      ],
    'linux' => <String>[
        '$target/release/libsmoldot.so',
        if (ci) 'libsmoldot.so',
      ],
    'windows' => <String>[
        '$target/release/smoldot.dll',
        if (ci) 'smoldot.dll',
      ],
    _ => const <String>[],
  };

  Object? lastError;
  for (final candidate in candidates) {
    if (!candidate.startsWith('lib') &&
        !candidate.endsWith('smoldot.dll') &&
        !File(candidate).existsSync()) {
      continue;
    }
    try {
      DynamicLibrary.open(candidate);
      return null;
    } catch (error) {
      lastError = error;
    }
  }

  _smoldotSkipReason =
      'libsmoldot native 库不可用；请先运行 scripts/build-smoldot-native.sh host：$lastError';
  return _smoldotSkipReason;
}
