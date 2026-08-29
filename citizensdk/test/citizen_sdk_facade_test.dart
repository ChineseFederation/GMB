import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('公共门面只组合轻节点、钱包、转账和验签能力', () {
    final sdk = CitizenSdk(
      walletRepository: _MemoryWalletRepository(),
      secureSeedStore: _MemorySeedStore(),
    );
    expect(sdk.chain, isA<CitizenLightClient>());
    expect(sdk.wallet, isA<WalletService>());
    expect(sdk.transfers, isA<TransferService>());
    expect(sdk.signer, isA<CitizenSigner>());
  });
}

final class _MemoryWalletRepository implements WalletRepository {
  WalletState state = const WalletState.empty();

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

final class _MemorySeedStore implements SecureSeedStore {
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
  }) async => null;
}
