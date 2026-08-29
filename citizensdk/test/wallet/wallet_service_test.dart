import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('公开 profile 只来自仓储且不读取硬件金库', () async {
    final repository = _Repository(_stateWithAccount());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    expect(
      (await service.profile)?.masterAccountId,
      '0x${List.filled(64, '1').join()}',
    );
    expect(store.readCount, 0);
  });

  test('未知账户签名在读取私钥前 fail-closed', () async {
    final store = _SeedStore();
    final service = WalletService(
      repository: _Repository(_stateWithAccount()),
      seedStore: store,
    );
    await expectLater(
      service.sign('0x${List.filled(64, '2').join()}', Uint8List(0)),
      throwsA(isA<WalletNotFound>()),
    );
    expect(store.readCount, 0);
  });
}

WalletState _stateWithAccount() {
  final accountId = '0x${List.filled(64, '1').join()}';
  final account = WalletAccount(
    index: 0,
    accountId: accountId,
    ss58Address: citizenSs58FromAccountId(accountId),
    name: '账户0',
    createdAtMillis: 1,
  );
  return WalletState(
    revision: 1,
    profile: WalletProfile(
      walletIndex: 0,
      masterAccountId: accountId,
      origin: WalletOrigin.imported,
      createdAtMillis: 1,
      activeAccountId: accountId,
      accounts: <WalletAccount>[account],
    ),
    cleanup: null,
  );
}

final class _Repository implements WalletRepository {
  _Repository(this.state);
  WalletState state;

  @override
  Future<WalletState> load() async => state;

  @override
  Future<WalletState> commit({
    required int expectedRevision,
    required WalletProfile? profile,
    required WalletCleanupPlan? cleanup,
  }) async {
    if (state.revision != expectedRevision) {
      throw const WalletRepositoryConflict();
    }
    return state = WalletState(
      revision: state.revision + 1,
      profile: profile,
      cleanup: cleanup,
    );
  }
}

final class _SeedStore implements SecureSeedStore {
  int readCount = 0;

  @override
  Future<SecureAuthStatus> authStatus() async => SecureAuthStatus.available;
  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {}
  @override
  Future<void> deleteWalletKey({required int walletIndex}) async {}
  @override
  Future<bool> hasAccountKey(String accountId) async => false;
  @override
  Future<bool> hasWalletKey({required int walletIndex}) async => false;
  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {}
  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    readCount++;
    return null;
  }
}
