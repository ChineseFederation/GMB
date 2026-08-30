import 'dart:ffi';
import 'dart:io';

String? _smoldotSkipReason;
bool _smoldotProbeCompleted = false;

/// Returns null when the independent smoldot host library can be loaded.
String? smoldotNativeSkipReason() {
  if (_smoldotProbeCompleted) return _smoldotSkipReason;
  _smoldotProbeCompleted = true;

  final cwd = Directory.current.path;
  final candidates = switch (Platform.operatingSystem) {
    'macos' => <String>[
        '$cwd/smoldot/ffi/target/release/libsmoldot.dylib',
        'libsmoldot.dylib',
      ],
    'linux' => <String>[
        '$cwd/smoldot/ffi/target/release/libsmoldot.so',
        'libsmoldot.so',
      ],
    'windows' => <String>[
        '$cwd/smoldot/ffi/target/release/smoldot.dll',
        'smoldot.dll',
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
