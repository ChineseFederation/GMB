import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CitizenApp stages and cleans the independent iOS ChatSDK package', () {
    final runner = File('scripts/citizenapp-run.sh').readAsStringSync();
    final testRunner = File('scripts/citizenapp-test.sh').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final lockfile = File('ios/Podfile.lock').readAsStringSync();

    expect(runner, contains('CHATSDK_PACKAGE_IOS_DIR='));
    expect(
      runner,
      contains(r'rm -f "$REPO_ROOT/chatsdk/ios/ChatSDK.xcframework"'),
    );
    expect(runner, contains(r'verify-ios-package "$IOS_APP"'));
    expect(pubspec, contains('gmb_chat_sdk:\n    path: ../chatsdk'));
    expect(runner, contains('dependency_overrides:'));
    expect(runner, contains('gmb_chat_sdk:'));
    expect(runner, contains(r'rm -f "$CHATSDK_OVERRIDE_PATH"'));
    expect(testRunner, contains('dependency_overrides:'));
    expect(testRunner, contains('gmb_chat_sdk:'));
    expect(podfile, contains('ChatSDK 通过自身 Flutter FFI plugin'));
    expect(lockfile, contains('- chat_sdk (1.0.0)'));
  });
}
