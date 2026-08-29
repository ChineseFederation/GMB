import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips public wallet state and increments revision', () async {
    final preferences = _MemoryPreferences();
    final repository = PreferencesWalletRepository(preferences: preferences);
    final profile = _profile();

    final committed = await repository.commit(
      expectedRevision: 0,
      profile: profile,
      cleanup: const WalletCleanupPlan(
        walletIndex: 0,
        accountIds: <String>[],
        deleteWalletKey: false,
      ),
    );
    final restored = await repository.load();

    expect(committed.revision, 1);
    expect(restored.profile?.masterAccountId, profile.masterAccountId);
    expect(restored.profile?.accounts.single.ss58Address, 'address');
    expect(preferences.values.values.single, isNot(contains('mnemonic')));
    expect(preferences.values.values.single, isNot(contains('mini_secret')));
  });

  test('rejects stale compare-and-swap revision', () async {
    final repository = PreferencesWalletRepository(
      preferences: _MemoryPreferences(),
    );
    await repository.commit(
      expectedRevision: 0,
      profile: _profile(),
      cleanup: null,
    );
    expect(
      () => repository.commit(
        expectedRevision: 0,
        profile: _profile(),
        cleanup: null,
      ),
      throwsA(isA<WalletRepositoryConflict>()),
    );
  });
}

WalletProfile _profile() {
  final accountId = '0x${'06' * 32}';
  return WalletProfile(
    walletIndex: 0,
    masterAccountId: accountId,
    origin: WalletOrigin.created,
    createdAtMillis: 1,
    activeAccountId: accountId,
    accounts: <WalletAccount>[
      WalletAccount(
        index: 0,
        accountId: accountId,
        ss58Address: 'address',
        name: '账户 1',
        createdAtMillis: 1,
      ),
    ],
  );
}

final class _MemoryPreferences implements PreferencesDataStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
