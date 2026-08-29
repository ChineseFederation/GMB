import 'package:characters/characters.dart';
import 'package:citizen_sdk/src/crypto/wallet_mini_secret.dart';
import 'package:citizen_sdk/src/crypto/wallet_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('空 password 表示沿用无 password 钱包', () {
    expect(WalletPassword.parse('').value, isEmpty);
  });

  test('五类字符及 6/30 用户可见字符边界均接受', () {
    for (final value in <String>[
      'ABCDEF',
      'abcdef',
      '123456',
      r'!@#$%^',
      '中华民族复兴',
      'Aa1!中华',
      List<String>.filled(30, '中').join(),
    ]) {
      final parsed = WalletPassword.parse(value);
      expect(parsed.value.characters.length, value.characters.length);
    }
  });

  test('NFKD 由唯一真源执行且汉字归一后仍可恢复', () {
    // U+F900 在 NFKD 中映射为 U+8C48。
    expect(WalletPassword.parse('AAAAA豈').value, 'AAAAA豈');
  });

  test('非空 password 的长度严格限制为 6–30 位', () {
    for (final value in <String>[
      'a',
      'abcde',
      List<String>.filled(31, 'a').join(),
      List<String>.filled(31, '中').join(),
    ]) {
      expect(
        () => WalletPassword.parse(value),
        throwsA(isA<WalletPasswordException>()),
      );
    }
  });

  test('空白、换行、emoji、全角及其它文字体系全部拒绝', () {
    for (final value in <String>[
      'abcde ',
      'abc de',
      'abcde\n',
      'abcde\r',
      'abcde\t',
      'abcde😀',
      'Ａbcdef',
      '가나다라마바',
      'абвгде',
    ]) {
      expect(
        () => WalletPassword.parse(value),
        throwsA(isA<WalletPasswordException>()),
      );
    }
  });

  test('相同 password 派生稳定，password 改变必须得到不同 master', () async {
    final first = await WalletMiniSecret.fromMnemonic(
      mnemonic,
      password: '安全密码A1!',
    );
    final second = await WalletMiniSecret.fromMnemonic(
      mnemonic,
      password: '安全密码A1!',
    );
    final different = await WalletMiniSecret.fromMnemonic(
      mnemonic,
      password: '安全密码A2!',
    );
    try {
      expect(first, hasLength(32));
      expect(second, orderedEquals(first));
      expect(different, isNot(orderedEquals(first)));
    } finally {
      WalletMiniSecret.clear(first);
      WalletMiniSecret.clear(second);
      WalletMiniSecret.clear(different);
    }
  });

  test('非法 password 在派生真源再次 fail-closed', () async {
    await expectLater(
      WalletMiniSecret.fromMnemonic(mnemonic, password: 'A1!'),
      throwsA(isA<WalletPasswordException>()),
    );
  });
}
