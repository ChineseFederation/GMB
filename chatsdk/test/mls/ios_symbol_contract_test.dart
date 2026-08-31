import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenMLS symbols belong only to the independent ChatSDK library', () {
    final chatSdkScript = File('scripts/build-native.sh').readAsStringSync();
    final chatSdkHeader = File('include/chat_sdk.h').readAsStringSync();
    final chatSdkPodspec = File('ios/chat_sdk.podspec').readAsStringSync();
    final package = File('pubspec.yaml').readAsStringSync();
    final loader = File('lib/src/mls/mls_native.dart').readAsStringSync();

    expect(chatSdkScript, contains('chat_sdk_mls_create_key_package_json'));
    expect(chatSdkScript, contains('chat_sdk_mls_group_create_message_json'));
    expect(chatSdkScript, contains('chat_sdk_mls_group_process_json'));
    expect(chatSdkScript, contains('ChatSDK.xcframework'));
    expect(chatSdkScript, contains('libchat_sdk.dylib'));
    expect(chatSdkScript, contains('-C strip=none'));
    expect(chatSdkScript, contains('string_offset % 8'));
    expect(chatSdkScript, contains('CHATSDK_PACKAGE_IOS_DIR'));
    expect(chatSdkScript, contains(r'ln -s "$xcframework" "$staged"'));
    expect(chatSdkScript, isNot(contains('install_name_tool')));
    expect(chatSdkScript, isNot(contains(r'$ROOT/ios/libchat_sdk.a')));
    expect(chatSdkHeader, contains('chat_sdk_mls_create_key_package_json'));
    expect(chatSdkHeader, contains('chat_sdk_mls_group_create_json'));
    expect(chatSdkHeader, contains('chat_sdk_mls_group_add_members_json'));
    expect(chatSdkHeader, contains('chat_sdk_mls_group_remove_members_json'));
    expect(chatSdkHeader, contains('chat_sdk_mls_group_create_message_json'));
    expect(chatSdkHeader, contains('chat_sdk_mls_group_process_json'));
    expect(chatSdkHeader, contains('chat_sdk_mls_group_state_json'));
    expect(chatSdkHeader, isNot(contains('chat_sdk_device_identity_json')));
    expect(chatSdkHeader, isNot(contains('chat_sdk_mls_encrypt_json')));
    expect(chatSdkHeader, isNot(contains('chat_sdk_mls_decrypt_json')));
    expect(chatSdkPodspec, contains("spec.name = 'chat_sdk'"));
    expect(
      chatSdkPodspec,
      contains("spec.vendored_frameworks = 'ChatSDK.xcframework'"),
    );
    expect(chatSdkPodspec, isNot(contains('vendored_libraries')));
    expect(chatSdkPodspec, isNot(contains('source_files')));
    expect(chatSdkPodspec, isNot(contains('framework_pattern')));
    expect(package, contains('ffiPlugin: true'));
    expect(loader, contains('ChatSDK 自己的 CocoaPods 目标'));
    expect(File('ios/chat_sdk_ffi.podspec').existsSync(), isFalse);
    expect(File('ios/placeholder.m').existsSync(), isFalse);
  });
}
