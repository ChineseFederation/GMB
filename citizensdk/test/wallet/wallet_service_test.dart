import 'dart:async';
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

  test('并发钱包修改串行执行且不丢失最后一次事实', () async {
    final repository = _Repository(_stateWithAccounts(3));
    final service = WalletService(
      repository: repository,
      seedStore: _SeedStore(),
    );
    final account1 = repository.state.profile!.accounts[1].accountId;
    final account2 = repository.state.profile!.accounts[2].accountId;

    await Future.wait(<Future<void>>[
      service.setActiveAccount(account1),
      service.setActiveAccount(account2),
    ]);

    expect(repository.state.revision, 3);
    expect(repository.state.profile!.activeAccountId, account2);
  });

  test(
    '跨 WalletService 实例并发 create/import 只有一个胜出且失败方零删除',
    () async {
      final repository = _Repository(const WalletState.empty());
      final store = _SeedStore();
      final first = WalletService(repository: repository, seedStore: store);
      final second = WalletService(repository: repository, seedStore: store);

      final outcomes = await Future.wait<Object>(<Future<Object>>[
        _captureOutcome(first.create()),
        _captureOutcome(second.importWallet(_mnemonic)),
      ]);

      expect(
        outcomes.where(
          (outcome) =>
              outcome is WalletCreationResult || outcome is WalletProfile,
        ),
        hasLength(1),
      );
      expect(outcomes.whereType<WalletAlreadyExists>(), hasLength(1));
      expect(store.accountIds, hasLength(1));
      expect(
        store.accountIds.single,
        repository.state.profile!.masterAccountId,
      );
      expect(store.walletKeyExists, isTrue);
      expect(store.deleteAttempts, isEmpty);
      expect(store.deleteWalletAttempts, 0);
    },
  );

  test('导入在写 secret 前已经持久化完整公开事实', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final putStarted = Completer<void>();
    final continuePut = Completer<void>();
    store.beforeNextPut = () async {
      putStarted.complete();
      await continuePut.future;
    };
    final service = WalletService(repository: repository, seedStore: store);

    final importing = service.importWallet(_mnemonic);
    await putStarted.future;

    try {
      expect(repository.state.revision, 1);
      expect(repository.state.profile, isNotNull);
      expect(repository.state.cleanup, isNull);
      expect(store.accountIds, isEmpty);
    } finally {
      if (!continuePut.isCompleted) continuePut.complete();
    }
    final profile = await importing;
    expect(store.accountIds, <String>{profile.masterAccountId});
  });

  test('导入写 secret 后抛错会清除当前 child 与 KEK 后撤回 profile', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore()..throwAfterNextPut = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
    expect(store.deleteAttempts, hasLength(1));
    expect(store.hasAccountAttempts, hasLength(1));
    expect(store.deleteWalletAttempts, 1);
    expect(store.hasWalletAttempts, 1);
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNull);
  });

  test('创建写 secret 后抛错同样清除当前 child 与 KEK', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore()..throwAfterNextPut = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.create(),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
    expect(store.deleteAttempts, hasLength(1));
    expect(store.deleteWalletAttempts, 1);
    expect(repository.state.profile, isNull);
  });

  test('导入回滚清理失败时保留 profile，后续新实例可完成删除', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore()
      ..throwAfterNextPut = true
      ..throwBeforeNextDeleteAccount = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(isA<WalletLocalCleanupException>()),
    );

    expect(repository.state.profile, isNotNull);
    expect(repository.state.profile!.accounts, hasLength(1));
    expect(
      store.accountIds,
      contains(repository.state.profile!.masterAccountId),
    );
    expect(repository.state.cleanup, isNull);

    final retry = WalletService(repository: repository, seedStore: store);
    await retry.deleteWallet();
    expect(store.accountIds, isEmpty);
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNull);
  });

  test('公开事实已写入后 commit 抛错不得回滚已公开的私钥', () async {
    final repository = _Repository(const WalletState.empty())
      ..throwAfterNextCommit = true;
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);

    final profile = await service.importWallet(_mnemonic);

    expect(repository.state.profile?.masterAccountId, profile.masterAccountId);
    expect(store.accountIds, contains(profile.masterAccountId));
    expect(store.deletedAccountIds, isEmpty);
    expect(store.deleteWalletAttempts, 0);
  });

  test('addAccounts 在金库写后抛错时回滚 attempted 账户', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    store.throwAfterNextPut = true;

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[1]),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(store.accountIds, <String>{profile.masterAccountId});
    expect(store.deletedAccountIds, hasLength(1));
    expect(store.deletedAccountIds.single, isNot(profile.masterAccountId));
    expect(store.walletKeyExists, isTrue);
    expect(store.deleteWalletAttempts, 0);
    expect(repository.state.profile!.accounts, hasLength(1));
  });

  test('provision 回滚清理失败时保留已提交的精确公开事实', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    store
      ..throwAfterNextPut = true
      ..throwBeforeNextDeleteAccount = true;

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[1]),
      throwsA(isA<WalletLocalCleanupException>()),
    );

    expect(repository.state.profile!.accounts, hasLength(2));
    expect(store.accountIds, hasLength(2));
    expect(store.deleteAttempts, hasLength(1));
    expect(repository.state.cleanup, isNull);

    final retry = WalletService(repository: repository, seedStore: store);
    await retry.deleteWallet();
    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNull);
  });

  test('整钱包删除先提交公开事实和计划，再清理并回读金库', () async {
    final events = <String>[];
    final initial = _stateWithAccounts(2);
    final repository = _Repository(initial, events: events);
    final store = _SeedStore(events: events)
      ..accountIds.addAll(
        initial.profile!.accounts.map((account) => account.accountId),
      )
      ..walletKeyExists = true;
    final service = WalletService(repository: repository, seedStore: store);

    await service.deleteWallet();

    expect(events.first, 'repository:cleanup');
    expect(events.last, 'repository:clear');
    for (final account in initial.profile!.accounts) {
      final deletion = events.indexOf('seed:delete:${account.accountId}');
      final readBack = events.indexOf('seed:has:${account.accountId}');
      expect(deletion, greaterThan(0));
      expect(readBack, greaterThan(deletion));
    }
    expect(
      events.indexOf('seed:has-wallet'),
      greaterThan(events.indexOf('seed:delete-wallet')),
    );
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNull);
  });

  test('删除 active 子账户先提交计划、回到账户0且不删除 KEK', () async {
    final events = <String>[];
    final base = _stateWithAccounts(3);
    final child = base.profile!.accounts[1];
    final initial = WalletState(
      revision: base.revision,
      profile: base.profile!.copyWith(activeAccountId: child.accountId),
      cleanup: null,
    );
    final repository = _Repository(initial, events: events);
    final store = _SeedStore(events: events)
      ..accountIds.addAll(
        initial.profile!.accounts.map((account) => account.accountId),
      )
      ..walletKeyExists = true;
    final service = WalletService(repository: repository, seedStore: store);

    await service.deleteAccount(child.accountId);

    expect(events.first, 'repository:cleanup');
    expect(events.last, 'repository:clear');
    expect(store.accountIds, isNot(contains(child.accountId)));
    final retainedAccountIds = initial.profile!.accounts
        .where((account) => account.accountId != child.accountId)
        .map((account) => account.accountId);
    expect(store.accountIds, containsAll(retainedAccountIds));
    expect(store.walletKeyExists, isTrue);
    expect(store.deleteWalletAttempts, 0);
    expect(
      repository.state.profile!.activeAccountId,
      initial.profile!.masterAccountId,
    );
    expect(repository.state.profile!.accounts, hasLength(2));
    expect(repository.state.cleanup, isNull);
  });

  test('子账户删除回读仍存在时保留计划并由新实例重放', () async {
    final base = _stateWithAccounts(2);
    final child = base.profile!.accounts[1];
    final initial = WalletState(
      revision: base.revision,
      profile: base.profile!.copyWith(activeAccountId: child.accountId),
      cleanup: null,
    );
    final repository = _Repository(initial);
    final store = _SeedStore()
      ..accountIds.addAll(
        initial.profile!.accounts.map((account) => account.accountId),
      )
      ..walletKeyExists = true
      ..keepNextDeletedAccount = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.deleteAccount(child.accountId),
      throwsA(isA<WalletLocalCleanupException>()),
    );

    expect(repository.state.profile!.accountById(child.accountId), isNull);
    expect(
      repository.state.profile!.activeAccountId,
      initial.profile!.masterAccountId,
    );
    expect(repository.state.cleanup, isNotNull);
    expect(store.walletKeyExists, isTrue);
    expect(store.deleteWalletAttempts, 0);

    final retry = WalletService(repository: repository, seedStore: store);
    await retry.reconcileCleanup();
    expect(store.accountIds, isNot(contains(child.accountId)));
    expect(repository.state.cleanup, isNull);
  });

  test('存在兄弟账户时拒绝删除账户0且不触碰金库', () async {
    final initial = _stateWithAccounts(2);
    final repository = _Repository(initial);
    final store = _SeedStore()
      ..accountIds.addAll(
        initial.profile!.accounts.map((account) => account.accountId),
      )
      ..walletKeyExists = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.deleteAccount(initial.profile!.masterAccountId),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(repository.state.revision, initial.revision);
    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
    expect(store.accountIds, hasLength(2));
    expect(store.walletKeyExists, isTrue);
  });

  test('账户0是最后一个账户时按整钱包合同删除', () async {
    final initial = _stateWithAccount();
    final accountId = initial.profile!.masterAccountId;
    final repository = _Repository(initial);
    final store = _SeedStore()
      ..accountIds.add(accountId)
      ..walletKeyExists = true;
    final service = WalletService(repository: repository, seedStore: store);

    await service.deleteAccount(accountId);

    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
    expect(store.deleteWalletAttempts, 1);
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNull);
  });

  test('单个删除失败仍尝试其余条目和 KEK，事实未清除则保留计划', () async {
    final initial = _stateWithAccounts(2);
    final firstId = initial.profile!.accounts.first.accountId;
    final secondId = initial.profile!.accounts.last.accountId;
    final repository = _Repository(initial);
    final store = _SeedStore()
      ..accountIds.addAll(<String>{firstId, secondId})
      ..walletKeyExists = true
      ..throwBeforeDeleteAccountOnce = firstId;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.deleteWallet(),
      throwsA(
        isA<WalletLocalCleanupException>().having(
          (error) => error.failures,
          'failures',
          isNotEmpty,
        ),
      ),
    );

    expect(store.deleteAttempts, containsAll(<String>[firstId, secondId]));
    expect(store.deleteWalletAttempts, 1);
    expect(store.hasAccountAttempts, containsAll(<String>[firstId, secondId]));
    expect(store.hasWalletAttempts, 1);
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNotNull);
  });

  test('裸删除错误即使回读已不存在也由服务保留清理计划', () async {
    final initial = _stateWithAccount();
    final accountId = initial.profile!.masterAccountId;
    final repository = _Repository(initial);
    final store = _SeedStore()
      ..accountIds.add(accountId)
      ..walletKeyExists = true
      ..throwAfterDeleteAccountOnce = accountId
      ..throwAfterDeleteWalletOnce = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.deleteWallet(),
      throwsA(isA<WalletLocalCleanupException>()),
    );

    expect(store.hasAccountAttempts, contains(accountId));
    expect(store.hasWalletAttempts, 1);
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNotNull);
  });

  test('删除正常返回但账户或 KEK 仍存在时保留计划并可重放', () async {
    final initial = _stateWithAccount();
    final accountId = initial.profile!.masterAccountId;
    final repository = _Repository(initial);
    final store = _SeedStore()
      ..accountIds.add(accountId)
      ..walletKeyExists = true
      ..keepNextDeletedAccount = true
      ..keepNextDeletedWalletKey = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.deleteWallet(),
      throwsA(isA<WalletLocalCleanupException>()),
    );

    expect(store.accountIds, contains(accountId));
    expect(store.walletKeyExists, isTrue);
    expect(repository.state.profile, isNull);
    expect(repository.state.cleanup, isNotNull);

    final retry = WalletService(repository: repository, seedStore: store);
    await retry.reconcileCleanup();
    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
    expect(repository.state.cleanup, isNull);
  });

  test('清理计划仍指向现存公开账户时拒绝触碰本机秘密', () async {
    final initial = _stateWithAccount();
    final accountId = initial.profile!.masterAccountId;
    final repository = _Repository(
      WalletState(
        revision: initial.revision,
        profile: initial.profile,
        cleanup: WalletCleanupPlan(
          walletIndex: 0,
          accountIds: <String>[accountId],
          deleteWalletKey: false,
        ),
      ),
    );
    final store = _SeedStore()
      ..accountIds.add(accountId)
      ..walletKeyExists = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.reconcileCleanup(),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
    expect(store.accountIds, contains(accountId));
    expect(store.walletKeyExists, isTrue);
  });

  test('遗留清理计划失败后可重放，且服务修改队列恢复', () async {
    final accountId = '0x${List.filled(64, '3').join()}';
    final repository = _Repository(
      WalletState(
        revision: 7,
        profile: null,
        cleanup: WalletCleanupPlan(
          walletIndex: 0,
          accountIds: <String>[accountId],
          deleteWalletKey: true,
        ),
      ),
    );
    final store = _SeedStore()
      ..accountIds.add(accountId)
      ..walletKeyExists = true
      ..throwBeforeDeleteAccountOnce = accountId;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.reconcileCleanup(),
      throwsA(
        isA<WalletLocalCleanupException>().having(
          (error) => error.failures,
          'failures',
          isNotEmpty,
        ),
      ),
    );
    expect(repository.state.cleanup, isNotNull);

    final retry = WalletService(repository: repository, seedStore: store);
    await retry.reconcileCleanup();

    expect(store.deleteAttempts.where((id) => id == accountId), hasLength(2));
    expect(repository.state.revision, 8);
    expect(repository.state.cleanup, isNull);
  });
}

const String _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon about';

Future<Object> _captureOutcome<T extends Object>(Future<T> operation) async {
  try {
    return await operation;
  } on Object catch (error) {
    return error;
  }
}

WalletState _stateWithAccount() {
  return _stateWithAccounts(1);
}

WalletState _stateWithAccounts(int count) {
  final accounts = List<WalletAccount>.generate(count, (index) {
    final digit = '${index + 1}';
    final accountId = '0x${List.filled(64, digit).join()}';
    return WalletAccount(
      index: index,
      accountId: accountId,
      ss58Address: citizenSs58FromAccountId(accountId),
      name: '账户$index',
      createdAtMillis: 1,
    );
  });
  final accountId = accounts.first.accountId;
  return WalletState(
    revision: 1,
    profile: WalletProfile(
      walletIndex: 0,
      masterAccountId: accountId,
      origin: WalletOrigin.imported,
      createdAtMillis: 1,
      activeAccountId: accountId,
      accounts: accounts,
    ),
    cleanup: null,
  );
}

final class _Repository implements WalletRepository {
  _Repository(this.state, {this.events});

  WalletState state;
  final List<String>? events;
  bool throwAfterNextCommit = false;

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
    state = WalletState(
      revision: state.revision + 1,
      profile: profile,
      cleanup: cleanup,
    );
    events?.add(cleanup == null ? 'repository:clear' : 'repository:cleanup');
    if (throwAfterNextCommit) {
      throwAfterNextCommit = false;
      throw StateError('commit wrote state, then reported failure');
    }
    return state;
  }
}

final class _SeedStore implements SecureSeedStore {
  _SeedStore({this.events});

  final List<String>? events;
  final Set<String> accountIds = <String>{};
  final List<String> deletedAccountIds = <String>[];
  final List<String> deleteAttempts = <String>[];
  final List<String> hasAccountAttempts = <String>[];
  int readCount = 0;
  int deleteWalletAttempts = 0;
  int hasWalletAttempts = 0;
  bool walletKeyExists = false;
  bool throwAfterNextPut = false;
  Future<void> Function()? beforeNextPut;
  bool throwBeforeNextDeleteAccount = false;
  String? throwBeforeDeleteAccountOnce;
  String? throwAfterDeleteAccountOnce;
  bool throwAfterDeleteWalletOnce = false;
  bool keepNextDeletedAccount = false;
  bool keepNextDeletedWalletKey = false;

  @override
  Future<SecureAuthStatus> authStatus() async => SecureAuthStatus.available;
  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    events?.add('seed:delete:$accountId');
    deleteAttempts.add(accountId);
    if (throwBeforeNextDeleteAccount) {
      throwBeforeNextDeleteAccount = false;
      throw const SecureStoreUnavailable('delete failed before mutation');
    }
    if (throwBeforeDeleteAccountOnce == accountId) {
      throwBeforeDeleteAccountOnce = null;
      throw const SecureStoreUnavailable('delete failed before mutation');
    }
    if (keepNextDeletedAccount) {
      keepNextDeletedAccount = false;
      return;
    }
    accountIds.remove(accountId);
    deletedAccountIds.add(accountId);
    if (throwAfterDeleteAccountOnce == accountId) {
      throwAfterDeleteAccountOnce = null;
      throw const SecureStoreUnavailable('delete failed after mutation');
    }
  }
  @override
  Future<void> deleteWalletKey({required int walletIndex}) async {
    events?.add('seed:delete-wallet');
    deleteWalletAttempts++;
    if (keepNextDeletedWalletKey) {
      keepNextDeletedWalletKey = false;
      return;
    }
    walletKeyExists = false;
    if (throwAfterDeleteWalletOnce) {
      throwAfterDeleteWalletOnce = false;
      throw const SecureStoreUnavailable('delete KEK failed after mutation');
    }
  }
  @override
  Future<bool> hasAccountKey(String accountId) async {
    events?.add('seed:has:$accountId');
    hasAccountAttempts.add(accountId);
    return accountIds.contains(accountId);
  }
  @override
  Future<bool> hasWalletKey({required int walletIndex}) async {
    events?.add('seed:has-wallet');
    hasWalletAttempts++;
    return walletKeyExists;
  }
  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {
    final beforePut = beforeNextPut;
    beforeNextPut = null;
    if (beforePut != null) await beforePut();
    accountIds.add(accountId);
    walletKeyExists = true;
    if (throwAfterNextPut) {
      throwAfterNextPut = false;
      throw const SecureStoreUnavailable('put failed after mutation');
    }
  }
  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    readCount++;
    return null;
  }
}
