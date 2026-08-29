import 'package:citizen_sdk/src/crypto/wallet_mini_secret.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('Substrate BIP-39 master mini-secret 保持公开金标', () async {
    final secret = await WalletMiniSecret.fromMnemonic(mnemonic);
    try {
      expect(
        secret,
        orderedEquals(<int>[
          0x4e,
          0xd8,
          0xd4,
          0xb1,
          0x76,
          0x98,
          0xdd,
          0xea,
          0xa1,
          0xf1,
          0x55,
          0x9f,
          0x15,
          0x2f,
          0x87,
          0xb5,
          0xd4,
          0x72,
          0xf7,
          0x25,
          0xca,
          0x86,
          0xd3,
          0x41,
          0xbd,
          0x02,
          0x76,
          0xf1,
          0xb6,
          0x11,
          0x97,
          0xe2,
        ]),
      );
    } finally {
      WalletMiniSecret.clear(secret);
    }
  });

  test('数字硬派生 junction 固定为 32 字节且序号敏感', () {
    final zero = WalletMiniSecret.hardJunctionChainCode(0);
    final one = WalletMiniSecret.hardJunctionChainCode(1);
    expect(zero, hasLength(32));
    expect(one, hasLength(32));
    expect(one, isNot(orderedEquals(zero)));
  });
}
