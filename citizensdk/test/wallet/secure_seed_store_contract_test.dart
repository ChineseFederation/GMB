import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

const _generationA = '10101010101010101010101010101010';
const _generationB = '20202020202020202020202020202020';
const _ownerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test('测试金库按 accountId 隔离并复制输入缓冲', () async {
    final store = _Store();
    final source = Uint8List.fromList(List<int>.filled(32, 7));
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'account-a',
      childMiniSecret: source,
    );
    source.fillRange(0, source.length, 0);
    expect(
      await store.readAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: 'account-a',
      ),
      orderedEquals(List<int>.filled(32, 7)),
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerB,
        accountId: 'account-b',
      ),
      isFalse,
    );
  });

  test('读取返回独立缓冲，调用方清零不污染存储值', () async {
    final store = _Store();
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'a',
      childMiniSecret: Uint8List.fromList(List<int>.filled(32, 9)),
    );

    final first = await store.readAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'a',
    );
    first!.fillRange(0, first.length, 0);

    expect(
      await store.readAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: 'a',
      ),
      orderedEquals(List<int>.filled(32, 9)),
    );
  });

  test('账户删除幂等且不影响其余账户或共享 KEK', () async {
    final store = _Store();
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'a',
      childMiniSecret: Uint8List(32),
    );
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerB,
      accountId: 'b',
      childMiniSecret: Uint8List(32),
    );

    await store.deleteAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'a',
    );
    await store.deleteAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'a',
    );

    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: 'a',
      ),
      isFalse,
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerB,
        accountId: 'b',
      ),
      isTrue,
    );
    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationA),
      isTrue,
    );
  });

  test('删除钱包 KEK 幂等，不冒充逐账户密文清理', () async {
    final store = _Store();
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'a',
      childMiniSecret: Uint8List(32),
    );

    await store.deleteWalletKey(walletIndex: 0, walletGeneration: _generationA);
    await store.deleteWalletKey(walletIndex: 0, walletGeneration: _generationA);

    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationA),
      isFalse,
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: _generationA,
        secretOwner: _ownerA,
        accountId: 'a',
      ),
      isTrue,
    );
  });

  test('相同 AccountId 的不同 generation 与 owner 精确隔离', () async {
    final store = _Store();
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'same',
      childMiniSecret: Uint8List.fromList(List<int>.filled(32, 1)),
    );
    await store.putAccountKey(
      walletIndex: 0,
      walletGeneration: _generationB,
      secretOwner: _ownerB,
      accountId: 'same',
      childMiniSecret: Uint8List.fromList(List<int>.filled(32, 2)),
    );

    await store.deleteAccountKey(
      walletIndex: 0,
      walletGeneration: _generationA,
      secretOwner: _ownerA,
      accountId: 'same',
    );
    await store.deleteWalletKey(walletIndex: 0, walletGeneration: _generationA);

    expect(
      await store.readAccountKey(
        walletIndex: 0,
        walletGeneration: _generationB,
        secretOwner: _ownerB,
        accountId: 'same',
      ),
      orderedEquals(List<int>.filled(32, 2)),
    );
    expect(
      await store.hasWalletKey(walletIndex: 0, walletGeneration: _generationB),
      isTrue,
    );
  });
}

final class _Store implements SecureSeedStore {
  final Map<String, Uint8List> values = <String, Uint8List>{};
  final Set<String> walletKeys = <String>{};

  @override
  Future<SecureAuthStatus> authStatus() async => SecureAuthStatus.available;

  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {
    values[_accountKey(walletIndex, walletGeneration, secretOwner, accountId)] =
        Uint8List.fromList(childMiniSecret);
    walletKeys.add(_walletKey(walletIndex, walletGeneration));
  }

  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async {
    final value =
        values[_accountKey(
          walletIndex,
          walletGeneration,
          secretOwner,
          accountId,
        )];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<bool> hasAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async => values.containsKey(
    _accountKey(walletIndex, walletGeneration, secretOwner, accountId),
  );

  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async {
    values.remove(
      _accountKey(walletIndex, walletGeneration, secretOwner, accountId),
    );
  }

  @override
  Future<void> deleteWalletKey({
    required int walletIndex,
    required String walletGeneration,
  }) async {
    walletKeys.remove(_walletKey(walletIndex, walletGeneration));
  }

  @override
  Future<bool> hasWalletKey({
    required int walletIndex,
    required String walletGeneration,
  }) async => walletKeys.contains(_walletKey(walletIndex, walletGeneration));

  static String _walletKey(int walletIndex, String walletGeneration) =>
      '$walletIndex:$walletGeneration';

  static String _accountKey(
    int walletIndex,
    String walletGeneration,
    String secretOwner,
    String accountId,
  ) => '$walletIndex:$walletGeneration:$secretOwner:$accountId';
}
