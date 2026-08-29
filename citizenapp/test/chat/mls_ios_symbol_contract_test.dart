import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('设备身份 FFI 符号进入静态清单与最终包精确门禁', () {
    final script = File('scripts/build-smoldot-native.sh').readAsStringSync();

    expect(
      script,
      contains(
        r"grep -E '^_(smoldot_|citizen_sr25519_|citizen_chat_device_|citizen_chat_mls_|account_crypto_)'",
      ),
    );
    expect(
      script,
      contains(r"grep -c '^_citizen_chat_device_identity_json$'"),
    );
    expect(
      RegExp('citizen_chat_device_identity_json').allMatches(script).length,
      greaterThanOrEqualTo(10),
    );
    expect(
      script,
      contains('Android 包内必须准确导出 citizen_chat_device_identity_json'),
    );
    expect(
      script,
      contains('iOS Runner 必须准确导出 citizen_chat_device_identity_json'),
    );
  });
}
