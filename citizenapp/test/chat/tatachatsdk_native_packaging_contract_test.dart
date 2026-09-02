import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CitizenApp stages and cleans the independent iOS TataChatSDK package', () {
    final runner = File('scripts/citizenapp-run.sh').readAsStringSync();
    final testRunner = File('scripts/citizenapp-test.sh').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final lockfile = File('ios/Podfile.lock').readAsStringSync();

    expect(runner, contains('TATACHATSDK_PACKAGE_IOS_DIR='));
    expect(
      runner,
      contains(r'rm -f "$TATACHATSDK_ROOT/ios/TataChatSDK.xcframework"'),
    );
    expect(runner, contains(r'verify-ios-package "$IOS_APP"'));
    expect(pubspec, contains('tatachat_sdk:\n    path: ../../TATA/tatachatsdk'));
    expect(runner, contains('dependency_overrides:'));
    expect(runner, contains('tatachat_sdk:'));
    expect(runner, contains(r'rm -f "$TATACHATSDK_OVERRIDE_PATH"'));
    expect(testRunner, contains('dependency_overrides:'));
    expect(testRunner, contains('tatachat_sdk:'));
    expect(podfile, contains('TataChatSDK 通过自身 Flutter FFI plugin'));
    expect(lockfile, contains('- tatachat_sdk (1.0.0)'));
  });
}
