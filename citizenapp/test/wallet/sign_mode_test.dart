import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignMode', () {
    test('持久化协议只接受 hot 与 cold 两个闭集值', () {
      expect(SignMode.tryParse('hot'), SignMode.hot);
      expect(SignMode.tryParse('cold'), SignMode.cold);
      expect(SignMode.tryParse('Hot'), isNull);
      expect(SignMode.tryParse('Cold'), isNull);
      expect(SignMode.tryParse(''), isNull);
      expect(SignMode.tryParse('unknown'), isNull);
    });

    test('Hot 只进入热签，Cold 只进入冷签', () {
      expect(_profile(SignMode.hot).requiresHotSign, isTrue);
      expect(_profile(SignMode.cold).requiresHotSign, isFalse);
    });

    test('非法模式不能被布尔分支误当成 Cold', () {
      final profile = _profile(null);

      expect(
        () => profile.requiredSignMode,
        throwsA(isA<WalletAuthException>()),
      );
      expect(
        () => profile.requiresHotSign,
        throwsA(isA<WalletAuthException>()),
      );
    });
  });
}

WalletProfile _profile(SignMode? signMode) => WalletProfile(
      walletIndex: 1,
      walletName: '测试钱包',
      walletIcon: 'wallet',
      balance: 0,
      accountId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      ss58Address: 'test-address',
      alg: 'sr25519',
      ss58: 2027,
      createdAtMillis: 1,
      source: 'test',
      signMode: signMode,
    );
