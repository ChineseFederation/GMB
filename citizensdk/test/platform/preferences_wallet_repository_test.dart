import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/platform/preferences_wallet_repository.dart';
import 'package:citizen_sdk/src/wallet/models.dart';
import 'package:citizen_sdk/src/wallet/wallet_error.dart';
import 'package:flutter_test/flutter_test.dart';

const _walletGeneration = '10101010101010101010101010101010';
const _secretOwner = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _operationId = 'cccccccccccccccccccccccccccccccc';

void main() {
  test('round-trips public wallet state and increments revision', () async {
    final preferences = _MemoryPreferences();
    final repository = PreferencesWalletRepository(preferences: preferences);
    final profile = _profile();

    final committed = await repository.commit(
      expectedRevision: 0,
      profile: profile,
      provisioning: null,
      cleanup: null,
      cleanupQueue: const <WalletCleanupPlan>[],
    );
    final restored = await repository.load();

    expect(committed.revision, 1);
    expect(restored.profile?.masterAccountId, profile.masterAccountId);
    expect(
      restored.profile?.accounts.single.ss58Address,
      citizenSs58FromAccountId(profile.masterAccountId),
    );
    expect(preferences.values.values.single, isNot(contains('mnemonic')));
    expect(preferences.values.values.single, isNot(contains('mini_secret')));
  });

  test('round-trips a service-valid wallet deletion cleanup plan', () async {
    final preferences = _MemoryPreferences();
    final repository = PreferencesWalletRepository(preferences: preferences);
    final accountId = '0x${'0d' * 32}';

    final committed = await repository.commit(
      expectedRevision: 0,
      profile: null,
      provisioning: null,
      cleanup: WalletCleanupPlan(
        operationId: _operationId,
        walletIndex: 0,
        walletGeneration: _walletGeneration,
        secretRefs: <WalletSecretRef>[
          WalletSecretRef(
            walletGeneration: _walletGeneration,
            secretOwner: _secretOwner,
            accountId: accountId,
          ),
        ],
        deleteWalletKey: true,
      ),
      cleanupQueue: const <WalletCleanupPlan>[],
    );
    final restored = await repository.load();

    expect(committed.revision, 1);
    expect(restored.profile, isNull);
    expect(restored.cleanup?.operationId, _operationId);
    expect(restored.cleanup?.walletGeneration, _walletGeneration);
    expect(restored.cleanup?.secretRefs.single.accountId, accountId);
    expect(restored.cleanup?.secretRefs.single.secretOwner, _secretOwner);
    expect(restored.cleanup?.deleteWalletKey, isTrue);
  });

  test('round-trips the exact sidecar cleanup queue', () async {
    final preferences = _MemoryPreferences();
    final repository = PreferencesWalletRepository(preferences: preferences);
    final accountId = '0x${'0d' * 32}';
    final queued = WalletCleanupPlan(
      operationId: _operationId,
      walletIndex: 0,
      walletGeneration: _walletGeneration,
      secretRefs: <WalletSecretRef>[
        WalletSecretRef(
          walletGeneration: _walletGeneration,
          secretOwner: _secretOwner,
          accountId: accountId,
        ),
      ],
      deleteWalletKey: true,
    );

    final committed = await repository.commit(
      expectedRevision: 0,
      profile: null,
      provisioning: null,
      cleanup: null,
      cleanupQueue: <WalletCleanupPlan>[queued],
    );
    final restored = await repository.load();

    expect(committed.cleanupQueue.single.operationId, _operationId);
    expect(restored.cleanupQueue.single.walletGeneration, _walletGeneration);
    expect(restored.cleanupQueue.single.secretRefs.single.accountId, accountId);
    expect(restored.cleanupQueue.single.deleteWalletKey, isTrue);
  });

  test(
    'round-trips the exact provisioning owner and previous profile',
    () async {
      final preferences = _MemoryPreferences();
      final repository = PreferencesWalletRepository(preferences: preferences);
      final previousProfile = _profile(accountByte: '0e');
      final accountId = '0x${'0f' * 32}';

      final committed = await repository.commit(
        expectedRevision: 0,
        profile: previousProfile,
        provisioning: WalletProvisioningPlan(
          operationId: _operationId,
          walletIndex: 0,
          walletGeneration: _walletGeneration,
          previousProfile: previousProfile,
          secretRefs: <WalletSecretRef>[
            WalletSecretRef(
              walletGeneration: _walletGeneration,
              secretOwner: _secretOwner,
              accountId: accountId,
            ),
          ],
          deleteWalletKeyOnRollback: false,
        ),
        cleanup: null,
        cleanupQueue: const <WalletCleanupPlan>[],
      );
      final restored = await repository.load();

      expect(committed.revision, 1);
      expect(restored.provisioning?.operationId, _operationId);
      expect(
        restored.provisioning?.previousProfile?.masterAccountId,
        previousProfile.masterAccountId,
      );
      expect(restored.provisioning?.secretRefs.single.accountId, accountId);
      expect(restored.provisioning?.deleteWalletKeyOnRollback, isFalse);
    },
  );

  test('rejects stale compare-and-swap revision', () async {
    final repository = PreferencesWalletRepository(
      preferences: _MemoryPreferences(),
    );
    await repository.commit(
      expectedRevision: 0,
      profile: _profile(),
      provisioning: null,
      cleanup: null,
      cleanupQueue: const <WalletCleanupPlan>[],
    );
    await expectLater(
      repository.commit(
        expectedRevision: 0,
        profile: _profile(),
        provisioning: null,
        cleanup: null,
        cleanupQueue: const <WalletCleanupPlan>[],
      ),
      throwsA(isA<WalletRepositoryConflict>()),
    );
  });

  test('共享底层存储的两个仓储并发 commit 只有一个胜出', () async {
    final preferences = _MemoryPreferences();
    final first = PreferencesWalletRepository(preferences: preferences);
    final second = PreferencesWalletRepository(preferences: preferences);

    final outcomes = await Future.wait<Object>(<Future<Object>>[
      _capture(
        first.commit(
          expectedRevision: 0,
          profile: _profile(accountByte: '07'),
          provisioning: null,
          cleanup: null,
          cleanupQueue: const <WalletCleanupPlan>[],
        ),
      ),
      _capture(
        second.commit(
          expectedRevision: 0,
          profile: _profile(accountByte: '08'),
          provisioning: null,
          cleanup: null,
          cleanupQueue: const <WalletCleanupPlan>[],
        ),
      ),
    ]);

    expect(outcomes.whereType<WalletState>(), hasLength(1));
    expect(outcomes.whereType<WalletRepositoryConflict>(), hasLength(1));
    final restored = await first.load();
    expect(restored.revision, 1);
    expect(
      restored.profile!.masterAccountId,
      outcomes.whereType<WalletState>().single.profile!.masterAccountId,
    );
  });

  test('底层写入后抛错时回读已持久化事实并视为提交成功', () async {
    final preferences = _MemoryPreferences()..throwAfterNextWrite = true;
    final repository = PreferencesWalletRepository(preferences: preferences);
    final profile = _profile(accountByte: '09');

    final committed = await repository.commit(
      expectedRevision: 0,
      profile: profile,
      provisioning: null,
      cleanup: null,
      cleanupQueue: const <WalletCleanupPlan>[],
    );

    expect(committed.revision, 1);
    expect(committed.profile?.masterAccountId, profile.masterAccountId);
    expect((await repository.load()).revision, 1);
  });

  test('底层 setString 静默丢写时回读不一致并拒绝提交', () async {
    final preferences = _MemoryPreferences()..dropNextWrite = true;
    final repository = PreferencesWalletRepository(preferences: preferences);

    await expectLater(
      repository.commit(
        expectedRevision: 0,
        profile: _profile(accountByte: '0c'),
        provisioning: null,
        cleanup: null,
        cleanupQueue: const <WalletCleanupPlan>[],
      ),
      throwsA(isA<WalletRepositoryConflict>()),
    );

    expect((await repository.load()).revision, 0);
  });

  test('写入前失败不改变事实，后续 commit 可恢复队列', () async {
    final preferences = _MemoryPreferences()..throwBeforeNextWrite = true;
    final repository = PreferencesWalletRepository(preferences: preferences);

    await expectLater(
      repository.commit(
        expectedRevision: 0,
        profile: _profile(accountByte: '0a'),
        provisioning: null,
        cleanup: null,
        cleanupQueue: const <WalletCleanupPlan>[],
      ),
      throwsA(isA<StateError>()),
    );
    expect((await repository.load()).revision, 0);

    final committed = await repository.commit(
      expectedRevision: 0,
      profile: _profile(accountByte: '0b'),
      provisioning: null,
      cleanup: null,
      cleanupQueue: const <WalletCleanupPlan>[],
    );
    expect(committed.revision, 1);
    expect(committed.profile?.masterAccountId, '0x${'0b' * 32}');
  });
}

Future<Object> _capture(Future<WalletState> operation) async {
  try {
    return await operation;
  } on Object catch (error) {
    return error;
  }
}

WalletProfile _profile({String accountByte = '06'}) {
  final accountId = '0x${accountByte * 32}';
  return WalletProfile(
    walletIndex: 0,
    walletGeneration: _walletGeneration,
    masterAccountId: accountId,
    origin: WalletOrigin.created,
    createdAtMillis: 1,
    activeAccountId: accountId,
    accounts: <WalletAccount>[
      WalletAccount(
        index: 0,
        accountId: accountId,
        secretOwner: _secretOwner,
        ss58Address: citizenSs58FromAccountId(accountId),
        name: '账户 1',
        createdAtMillis: 1,
      ),
    ],
  );
}

final class _MemoryPreferences implements PreferencesDataStore {
  final Map<String, String> values = <String, String>{};
  bool throwBeforeNextWrite = false;
  bool throwAfterNextWrite = false;
  bool dropNextWrite = false;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    if (throwBeforeNextWrite) {
      throwBeforeNextWrite = false;
      throw StateError('write failed before mutation');
    }
    if (dropNextWrite) {
      dropNextWrite = false;
      return;
    }
    values[key] = value;
    if (throwAfterNextWrite) {
      throwAfterNextWrite = false;
      throw StateError('write failed after mutation');
    }
  }
}
