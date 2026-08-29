import 'package:citizen_sdk/src/crypto/wallet_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('空 password 保持兼容', () {
    expect(WalletPassword.parse('').value, isEmpty);
  });

  test('允许 ASCII 与汉字并执行长度边界', () {
    for (final value in <String>[
      'ABCDEF',
      'abcdef',
      '123456',
      r'!@#$%^',
      '中华民族复兴',
      'Aa1!中华',
    ]) {
      expect(WalletPassword.parse(value).value, value);
    }
  });

  test('空白、emoji 和过短 password fail-closed', () {
    for (final value in <String>['abcde', 'abcde ', 'abc de', 'abcde😀']) {
      expect(
        () => WalletPassword.parse(value),
        throwsA(isA<WalletPasswordException>()),
      );
    }
  });
}
