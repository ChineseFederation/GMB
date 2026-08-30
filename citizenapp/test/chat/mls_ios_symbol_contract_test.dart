import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenMLS symbols belong only to the independent ChatSDK library', () {
    final smoldotScript =
        File('scripts/build-smoldot-native.sh').readAsStringSync();
    final chatSdkScript =
        File('../chatsdk/scripts/build-native.sh').readAsStringSync();
    final chatSdkHeader =
        File('../chatsdk/include/chat_sdk.h').readAsStringSync();
    final chatSdkPodspec =
        File('../chatsdk/ios/chat_sdk_ffi.podspec').readAsStringSync();

    expect(smoldotScript, isNot(contains('citizen_chat_mls_')));
    expect(smoldotScript, isNot(contains('citizen_chat_device_identity_json')));
    expect(chatSdkScript, contains('chat_sdk_mls_'));
    expect(chatSdkScript, contains('libchat_sdk.a'));
    expect(chatSdkHeader, contains('chat_sdk_device_identity_json'));
    expect(chatSdkHeader, contains('chat_sdk_mls_'));
    expect(chatSdkPodspec, contains("vendored_libraries = 'libchat_sdk.a'"));
  });
}
