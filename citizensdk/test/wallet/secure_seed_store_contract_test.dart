import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('测试金库按 accountId 隔离并复制输入缓冲', () async {
    final store = _Store();
    final source = Uint8List.fromList(List<int>.filled(32, 7));
    await store.putAccountKey(
      walletIndex: 0,
      accountId: 'account-a',
      childMiniSecret: source,
    );
    source.fillRange(0, source.length, 0);
    expect(
      await store.readAccountKey(walletIndex: 0, accountId: 'account-a'),
      orderedEquals(List<int>.filled(32, 7)),
    );
    expect(await store.hasAccountKey('account-b'), isFalse);
  });

  test('删除钱包 KEK 会清理该钱包全部 child', () async {
    final store = _Store();
    await store.putAccountKey(
      walletIndex: 0,
      accountId: 'a',
      childMiniSecret: Uint8List(32),
    );
    await store.deleteWalletKey(walletIndex: 0);
    expect(await store.hasAccountKey('a'), isFalse);
  });
}

final class _Store implements SecureSeedStore {
  final Map<String, Uint8List> values = <String, Uint8List>{};

  @override
  Future<SecureAuthStatus> authStatus() async => SecureAuthStatus.available;

  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {
    values['$walletIndex:$accountId'] = Uint8List.fromList(childMiniSecret);
  }

  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    final value = values['$walletIndex:$accountId'];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<bool> hasAccountKey(String accountId) async =>
      values.keys.any((key) => key.endsWith(':$accountId'));

  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    values.remove('$walletIndex:$accountId');
  }

  @override
  Future<void> deleteWalletKey({required int walletIndex}) async {
    values.removeWhere((key, _) => key.startsWith('$walletIndex:'));
  }

  @override
  Future<bool> hasWalletKey({required int walletIndex}) async =>
      values.keys.any((key) => key.startsWith('$walletIndex:'));
}
