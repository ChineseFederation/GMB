import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/crypto/citizen_signer.dart';
import 'package:citizen_sdk/src/wallet/models.dart';
import 'package:citizen_sdk/src/wallet/secure_seed_store.dart';
import 'package:citizen_sdk/src/wallet/wallet_error.dart';
import 'package:citizen_sdk/src/wallet/wallet_repository.dart';
import 'package:citizen_sdk/src/wallet/wallet_service.dart';
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

  test('usableProfile 与 isUsable 完整核验多账户且逐个清零 child', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_exportGoldenMnemonic);
    await service.addAccounts(
      mnemonic: _exportGoldenMnemonic,
      indices: const <int>[1, 2],
    );
    final buffersBefore = store.readBuffers.length;

    final usable = await service.usableProfile;

    expect(usable, isNotNull);
    expect(usable!.masterAccountId, profile.masterAccountId);
    expect(usable.accounts, hasLength(3));
    expect(store.readBuffers.length - buffersBefore, 3);
    expect(
      store.readBuffers.skip(buffersBefore),
      everyElement(everyElement(0)),
    );

    final buffersBeforePredicate = store.readBuffers.length;
    expect(await service.isUsable, isTrue);
    expect(store.readBuffers.length - buffersBeforePredicate, 3);
    expect(
      store.readBuffers.skip(buffersBeforePredicate),
      everyElement(everyElement(0)),
    );
  });

  test('钱包不存在时 usableProfile 返回 null 且 isUsable 返回 false', () async {
    final store = _SeedStore();
    final service = WalletService(
      repository: _Repository(const WalletState.empty()),
      seedStore: store,
    );

    expect(await service.usableProfile, isNull);
    expect(await service.isUsable, isFalse);
    expect(store.hasWalletAttempts, 0);
    expect(store.readCount, 0);
  });

  test('KEK、child 缺失或 child 与账户错配时钱包不可用', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    final original = store.copyAccountSecret(profile.masterAccountId);

    store.walletKeyExists = false;
    expect(await service.usableProfile, isNull);

    store.walletKeyExists = true;
    store.removeAccountSecret(profile.masterAccountId);
    expect(await service.isUsable, isFalse);

    store.replaceAccountSecret(
      profile.masterAccountId,
      Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );
    expect(await service.usableProfile, isNull);
    expect(store.lastReadBuffer, everyElement(0));

    store.replaceAccountSecret(profile.masterAccountId, original);
    expect(await service.isUsable, isTrue);
  });

  test('usableProfile 不把 KEK 或 child 后端异常伪装成 false', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    store.beforeNextHasWallet = () async {
      throw const SecureStoreUnavailable('KEK 后端不可用');
    };

    await expectLater(
      service.usableProfile,
      throwsA(isA<SecureStoreUnavailable>()),
    );

    store.beforeNextRead = () async {
      throw const SeedKeyInvalidated('生物识别集合已变化');
    };
    await expectLater(service.isUsable, throwsA(isA<SeedKeyInvalidated>()));
  });

  test('usableProfile 在读取金库前拒绝公开账户0锚点损坏', () async {
    final base = _stateWithAccount();
    final broken = WalletState(
      revision: base.revision,
      profile: WalletProfile(
        walletIndex: base.profile!.walletIndex,
        walletGeneration: base.profile!.walletGeneration,
        masterAccountId: '0x${List<String>.filled(64, '2').join()}',
        origin: base.profile!.origin,
        createdAtMillis: base.profile!.createdAtMillis,
        activeAccountId: base.profile!.activeAccountId,
        accounts: base.profile!.accounts,
      ),
      provisioning: null,
      cleanup: null,
      cleanupQueue: const <WalletCleanupPlan>[],
    );
    final store = _SeedStore();
    final service = WalletService(
      repository: _Repository(broken),
      seedStore: store,
    );

    await expectLater(
      service.usableProfile,
      throwsA(isA<WalletInvariantViolation>()),
    );
    expect(store.hasWalletAttempts, 0);
    expect(store.readCount, 0);
  });

  test('未登记强生物识别时使用准确错误并禁止创建钱包', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore()
      ..authStatusValue = SecureAuthStatus.noStrongBiometric;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(
        isA<NoStrongBiometric>().having(
          (error) => error.message,
          'message',
          contains('强生物识别'),
        ),
      ),
    );
    expect(repository.state.profile, isNull);
    expect(store.putCount, 0);
  });

  test('强生物识别被移除后追加账户在派生和写入前 fail-closed', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    final revision = repository.state.revision;
    final putCount = store.putCount;
    final accountIds = Set<String>.of(store.accountIds);
    store.authStatusValue = SecureAuthStatus.noStrongBiometric;

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[1]),
      throwsA(isA<NoStrongBiometric>()),
    );

    expect(repository.state.revision, revision);
    expect(repository.state.profile!.accounts, hasLength(1));
    expect(store.putCount, putCount);
    expect(store.accountIds, accountIds);
  });

  test('生物集合变化使原 KEK 失效时追加账户不写新事实或秘密', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    final revision = repository.state.revision;
    final putCount = store.putCount;
    final accountIds = Set<String>.of(store.accountIds);
    store.beforeNextRead = () async {
      throw const SeedKeyInvalidated('生物识别集合已变化');
    };

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[1]),
      throwsA(isA<SeedKeyInvalidated>()),
    );

    expect(repository.state.revision, revision);
    expect(repository.state.profile!.accounts, hasLength(1));
    expect(store.putCount, putCount);
    expect(store.accountIds, accountIds);
  });

  test('账户0锚点私钥错配时追加账户回滚前即失败并清零明文', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    store.replaceAccountSecret(
      profile.masterAccountId,
      Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );
    final revision = repository.state.revision;
    final putCount = store.putCount;
    final accountIds = Set<String>.of(store.accountIds);

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[1]),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(repository.state.revision, revision);
    expect(repository.state.profile!.accounts, hasLength(1));
    expect(store.putCount, putCount);
    expect(store.accountIds, accountIds);
    expect(store.lastReadBuffer, isNotNull);
    expect(store.lastReadBuffer, everyElement(0));
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

  test('签名成功且可由账户公钥验证', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    final payload = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final signature = await service.sign(profile.masterAccountId, payload);

    expect(signature, hasLength(64));
    expect(
      const CitizenSigner().verify(
        publicKey: citizenAccountIdBytes(profile.masterAccountId),
        signature: signature,
        message: payload,
      ),
      isTrue,
    );
  });

  test('本地 child 公钥与公开账户不匹配时拒绝签名', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    store.replaceAccountSecret(
      profile.masterAccountId,
      Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );

    await expectLater(
      service.sign(profile.masterAccountId, Uint8List(0)),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(store.lastReadBuffer, everyElement(0));
  });

  test('签名完成后清零金库返回的 child 缓冲', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);

    await service.sign(profile.masterAccountId, Uint8List.fromList(<int>[7]));

    expect(store.lastReadBuffer, isNotNull);
    expect(store.lastReadBuffer, everyElement(0));
  });

  test('主动导出多账户 child 与公民冷热钱包共享金标逐字节一致', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_exportGoldenMnemonic);
    final added = await service.addAccounts(
      mnemonic: _exportGoldenMnemonic,
      indices: const <int>[1, 2],
    );
    final accounts = <WalletAccount>[profile.accounts.single, ...added];

    for (var index = 0; index < accounts.length; index++) {
      final account = accounts[index];
      expect(account.accountId, _exportGoldenAccounts[index].$1);
      expect(
        await service.getAccountPrivateKey(account.accountId),
        _exportGoldenAccounts[index].$2,
        reason: '//$index 必须导出该账户自己的 child mini-secret',
      );
      expect(store.lastReadBuffer, everyElement(0));
    }
  });

  test('未知、缺失或硬件失效的导出密钥均 fail-closed', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    final unknown = '0x${List.filled(64, '2').join()}';
    final readsBeforeUnknown = store.readCount;

    await expectLater(
      service.getAccountPrivateKey(unknown),
      throwsA(isA<WalletNotFound>()),
    );
    expect(store.readCount, readsBeforeUnknown);

    final originalSecret = store.copyAccountSecret(profile.masterAccountId);
    store.removeAccountSecret(profile.masterAccountId);
    await expectLater(
      service.getAccountPrivateKey(profile.masterAccountId),
      throwsA(isA<WalletAuthenticationFailed>()),
    );

    store.replaceAccountSecret(profile.masterAccountId, originalSecret);
    store.beforeNextRead = () async {
      throw const SeedKeyInvalidated('生物识别集合已变化');
    };
    await expectLater(
      service.getAccountPrivateKey(profile.masterAccountId),
      throwsA(isA<SeedKeyInvalidated>()),
    );
    expect(store.accountIds, contains(profile.masterAccountId));
  });

  test('导出 child 与公开账户错配时拒绝并清零金库明文', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    store.replaceAccountSecret(
      profile.masterAccountId,
      Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );

    await expectLater(
      service.getAccountPrivateKey(profile.masterAccountId),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(store.lastReadBuffer, isNotNull);
    expect(store.lastReadBuffer, everyElement(0));
  });

  test('跨实例删除子账户不得越过阻塞中的主动导出', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final exportingService = WalletService(
      repository: repository,
      seedStore: store,
    );
    final deletingService = WalletService(
      repository: repository,
      seedStore: store,
    );
    await exportingService.importWallet(_exportGoldenMnemonic);
    final child = (await exportingService.addAccounts(
      mnemonic: _exportGoldenMnemonic,
      indices: const <int>[1],
    )).single;
    final readStarted = Completer<void>();
    final continueRead = Completer<void>();
    store.beforeNextRead = () async {
      readStarted.complete();
      await continueRead.future;
    };

    final exporting = exportingService.getAccountPrivateKey(child.accountId);
    await readStarted.future;
    final deleting = deletingService.deleteAccount(child.accountId);
    await Future<void>.delayed(Duration.zero);

    expect(repository.state.profile!.accountById(child.accountId), isNotNull);
    expect(store.deleteAttempts, isEmpty);

    continueRead.complete();
    expect(await exporting, _exportGoldenAccounts[1].$2);
    expect(store.lastReadBuffer, everyElement(0));
    await deleting;
    expect(repository.state.profile!.accountById(child.accountId), isNull);
    expect(store.accountIds, isNot(contains(child.accountId)));
  });

  test('跨实例删除不得越过阻塞中的签名', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final signingService = WalletService(
      repository: repository,
      seedStore: store,
    );
    final deletingService = WalletService(
      repository: repository,
      seedStore: store,
    );
    final profile = await signingService.importWallet(_mnemonic);
    final readStarted = Completer<void>();
    final continueRead = Completer<void>();
    store.beforeNextRead = () async {
      readStarted.complete();
      await continueRead.future;
    };

    final signing = signingService.sign(
      profile.masterAccountId,
      Uint8List.fromList(<int>[9]),
    );
    await readStarted.future;
    final deleting = deletingService.deleteWallet();
    await Future<void>.delayed(Duration.zero);

    expect(repository.state.profile, isNotNull);
    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);

    continueRead.complete();
    final signature = await signing;
    expect(signature, hasLength(64));
    await deleting;
    expect(repository.state.profile, isNull);
    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
  });

  test('renameAccount 只提交修剪后的本地名称且绝不触碰金库', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    final child = (await service.addAccounts(
      mnemonic: _mnemonic,
      indices: const <int>[1],
    )).single;
    await service.setActiveAccount(child.accountId);
    final revision = repository.state.revision;
    final storeFacts = (
      store.readCount,
      store.putCount,
      store.deleteAttempts.length,
      store.deleteWalletAttempts,
      store.hasAccountAttempts.length,
      store.hasWalletAttempts,
    );
    final accountIds = Set<String>.of(store.accountIds);

    await service.renameAccount(child.accountId, '  日常账户  ');

    final renamed = repository.state.profile!.accountById(child.accountId)!;
    expect(renamed.name, '日常账户');
    expect(repository.state.profile!.accounts.first.name, '账户0');
    expect(repository.state.profile!.activeAccountId, child.accountId);
    expect(repository.state.revision, revision + 1);
    expect((
      store.readCount,
      store.putCount,
      store.deleteAttempts.length,
      store.deleteWalletAttempts,
      store.hasAccountAttempts.length,
      store.hasWalletAttempts,
    ), storeFacts);
    expect(store.accountIds, accountIds);
  });

  test('renameAccount 对未知账户、空名称和超长名称失败关闭', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    final revision = repository.state.revision;
    final puts = store.putCount;

    await expectLater(
      service.renameAccount(profile.masterAccountId, ' \n '),
      throwsArgumentError,
    );
    await expectLater(
      service.renameAccount(
        profile.masterAccountId,
        List<String>.filled(31, '名').join(),
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.renameAccount('0x${List<String>.filled(64, '2').join()}', '未知'),
      throwsA(isA<WalletNotFound>()),
    );

    expect(repository.state.revision, revision);
    expect(repository.state.profile!.accounts.single.name, '账户0');
    expect(store.putCount, puts);
    expect(store.deleteAttempts, isEmpty);
  });

  test('renameAccount 遇到遗留清理计划只失败关闭且不代为触碰密文', () async {
    final base = _stateWithAccount();
    final staleAccountId = '0x${List<String>.filled(64, '2').join()}';
    final repository = _Repository(
      WalletState(
        revision: base.revision,
        profile: base.profile,
        provisioning: null,
        cleanup: WalletCleanupPlan(
          operationId: _operationId,
          walletIndex: 0,
          walletGeneration: _walletGeneration,
          secretRefs: <WalletSecretRef>[
            WalletSecretRef(
              walletGeneration: _walletGeneration,
              secretOwner: _staleSecretOwner,
              accountId: staleAccountId,
            ),
          ],
          deleteWalletKey: false,
        ),
        cleanupQueue: const <WalletCleanupPlan>[],
      ),
    );
    final store = _SeedStore()
      ..accountIds.addAll(<String>{
        base.profile!.masterAccountId,
        staleAccountId,
      })
      ..walletKeyExists = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.renameAccount(base.profile!.masterAccountId, '新名称'),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(repository.state.revision, base.revision);
    expect(repository.state.cleanup, isNotNull);
    expect(store.readCount, 0);
    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
    expect(
      store.accountIds,
      containsAll(<String>[base.profile!.masterAccountId, staleAccountId]),
    );
  });

  test('跨实例删除先行时 renameAccount 不得复活已删除账户', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final deletingService = WalletService(
      repository: repository,
      seedStore: store,
    );
    final renamingService = WalletService(
      repository: repository,
      seedStore: store,
    );
    await deletingService.importWallet(_mnemonic);
    final child = (await deletingService.addAccounts(
      mnemonic: _mnemonic,
      indices: const <int>[1],
    )).single;
    final deleteStarted = Completer<void>();
    final continueDelete = Completer<void>();
    store.beforeNextDeleteAccount = () async {
      deleteStarted.complete();
      await continueDelete.future;
    };

    final deleting = deletingService.deleteAccount(child.accountId);
    await deleteStarted.future;
    final renaming = expectLater(
      renamingService.renameAccount(child.accountId, '不得复活'),
      throwsA(isA<WalletNotFound>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.state.profile!.accountById(child.accountId), isNull);
    continueDelete.complete();
    await deleting;
    await renaming;
    expect(repository.state.profile!.accountById(child.accountId), isNull);
    expect(store.accountIds, isNot(contains(child.accountId)));
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

  test('跨 WalletService 实例并发 create/import 只有一个胜出且失败方零删除', () async {
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
    expect(store.accountIds.single, repository.state.profile!.masterAccountId);
    expect(store.walletKeyExists, isTrue);
    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
  });

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
      expect(repository.state.provisioning, isNotNull);
      expect(repository.state.provisioning!.previousProfile, isNull);
      expect(repository.state.provisioning!.secretRefs, hasLength(1));
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

    await expectLater(service.create(), throwsA(isA<SecureStoreUnavailable>()));

    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
    expect(store.deleteAttempts, hasLength(1));
    expect(store.deleteWalletAttempts, 1);
    expect(repository.state.profile, isNull);
  });

  test('导入回滚清理失败时保留精确 cleanup，新实例可恢复', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore()
      ..throwAfterNextPut = true
      ..throwBeforeNextDeleteAccount = true;
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(isA<WalletLocalCleanupException>()),
    );

    expect(repository.state.profile, isNull);
    expect(repository.state.provisioning, isNull);
    expect(repository.state.cleanup, isNotNull);
    expect(repository.state.cleanup!.secretRefs, hasLength(1));
    expect(store.accountIds, hasLength(1));

    final retry = WalletService(repository: repository, seedStore: store);
    await retry.reconcileCleanup();
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
    expect(repository.state.provisioning, isNull);
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

  test('addAccounts 多账户批次当前写入落地后抛错仍精确清理完整计划', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    var batchPutOrdinal = 0;
    late Future<void> Function(String, String, String, Uint8List) putHook;
    late (String, String, String) failedCurrentRef;
    putHook = (walletGeneration, secretOwner, accountId, _) async {
      batchPutOrdinal++;
      if (batchPutOrdinal == 1) {
        store.beforeNextPutWithIdentity = putHook;
        return;
      }
      failedCurrentRef = (walletGeneration, secretOwner, accountId);
      store.throwAfterNextPut = true;
    };
    store.beforeNextPutWithIdentity = putHook;

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[1, 2, 3]),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    expect(batchPutOrdinal, 2);
    expect(store.accountIds, <String>{profile.masterAccountId});
    expect(store.deletedAccountIds.toSet(), hasLength(3));
    expect(
      store.deletedSecretSlots,
      contains(
        _SeedStore._slotKey(
          failedCurrentRef.$1,
          failedCurrentRef.$2,
          failedCurrentRef.$3,
        ),
      ),
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: failedCurrentRef.$1,
        secretOwner: failedCurrentRef.$2,
        accountId: failedCurrentRef.$3,
      ),
      isFalse,
    );
    expect(store.walletKeyExists, isTrue);
    expect(store.deleteWalletAttempts, 0);
    expect(repository.state.profile!.accounts, hasLength(1));
    expect(repository.state.provisioning, isNull);
    expect(repository.state.cleanup, isNull);
    expect(repository.state.cleanupQueue, isEmpty);
  });

  test('addAccounts 在 KEK 缺失时不写新事实或新秘密', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    store.walletKeyExists = false;
    final revision = repository.state.revision;
    final putCount = store.putCount;
    final accountIds = Set<String>.of(store.accountIds);

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[1]),
      throwsA(
        isA<WalletAuthenticationFailed>().having(
          (error) => error.message,
          'message',
          '钱包硬件密钥不存在',
        ),
      ),
    );

    expect(repository.state.revision, revision);
    expect(repository.state.profile!.accounts, hasLength(1));
    expect(store.putCount, putCount);
    expect(store.accountIds, accountIds);
    expect(store.deleteAttempts, isEmpty);
  });

  test('addAccounts 在任一既有 child 缺失时不写新事实或新秘密', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    final existing = await service.addAccounts(
      mnemonic: _mnemonic,
      indices: const <int>[1],
    );
    store.removeAccountSecret(existing.single.accountId);
    final revision = repository.state.revision;
    final putCount = store.putCount;
    final accountIds = Set<String>.of(store.accountIds);

    await expectLater(
      service.addAccounts(mnemonic: _mnemonic, indices: const <int>[2]),
      throwsA(
        isA<WalletInvariantViolation>().having(
          (error) => error.message,
          'message',
          '现有账户私钥不存在：${existing.single.accountId}',
        ),
      ),
    );

    expect(repository.state.revision, revision);
    expect(repository.state.profile!.accounts, hasLength(2));
    expect(store.putCount, putCount);
    expect(store.accountIds, accountIds);
    expect(store.deleteAttempts, isEmpty);
  });

  test('provision 回滚清理失败时恢复前态并保留精确 cleanup', () async {
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

    expect(repository.state.profile!.accounts, hasLength(1));
    expect(store.accountIds, hasLength(2));
    expect(store.deleteAttempts, hasLength(1));
    expect(repository.state.provisioning, isNull);
    expect(repository.state.cleanup, isNotNull);
    expect(repository.state.cleanup!.secretRefs, hasLength(1));

    final retry = WalletService(repository: repository, seedStore: store);
    await retry.reconcileCleanup();
    expect(store.accountIds, hasLength(1));
    expect(store.walletKeyExists, isTrue);
    expect(repository.state.profile!.accounts, hasLength(1));
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
      provisioning: null,
      cleanup: null,
      cleanupQueue: const <WalletCleanupPlan>[],
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
      provisioning: null,
      cleanup: null,
      cleanupQueue: const <WalletCleanupPlan>[],
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
        provisioning: null,
        cleanup: WalletCleanupPlan(
          operationId: _operationId,
          walletIndex: 0,
          walletGeneration: _walletGeneration,
          secretRefs: <WalletSecretRef>[
            WalletSecretRef(
              walletGeneration: _walletGeneration,
              secretOwner: initial.profile!.accounts.single.secretOwner,
              accountId: accountId,
            ),
          ],
          deleteWalletKey: false,
        ),
        cleanupQueue: const <WalletCleanupPlan>[],
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

  test('cleanup queue 结构损坏时在触碰秘密前拒绝', () async {
    final accountId = '0x${List<String>.filled(64, '3').join()}';
    final repository = _Repository(
      WalletState(
        revision: 1,
        profile: null,
        provisioning: null,
        cleanup: null,
        cleanupQueue: <WalletCleanupPlan>[
          WalletCleanupPlan(
            operationId: 'bad',
            walletIndex: 0,
            walletGeneration: _walletGeneration,
            secretRefs: <WalletSecretRef>[
              WalletSecretRef(
                walletGeneration: _walletGeneration,
                secretOwner: _staleSecretOwner,
                accountId: accountId,
              ),
            ],
            deleteWalletKey: true,
          ),
        ],
      ),
    );
    final store = _SeedStore();

    await expectLater(
      WalletService(
        repository: repository,
        seedStore: store,
      ).reconcileCleanup(),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
  });

  test('active cleanup 与 queue 重复目标时在删除前拒绝', () async {
    final accountId = '0x${List<String>.filled(64, '3').join()}';
    final plan = WalletCleanupPlan(
      operationId: _operationId,
      walletIndex: 0,
      walletGeneration: _walletGeneration,
      secretRefs: <WalletSecretRef>[
        WalletSecretRef(
          walletGeneration: _walletGeneration,
          secretOwner: _staleSecretOwner,
          accountId: accountId,
        ),
      ],
      deleteWalletKey: true,
    );
    final repository = _Repository(
      WalletState(
        revision: 1,
        profile: null,
        provisioning: null,
        cleanup: plan,
        cleanupQueue: <WalletCleanupPlan>[plan],
      ),
    );
    final store = _SeedStore();

    await expectLater(
      WalletService(
        repository: repository,
        seedStore: store,
      ).reconcileCleanup(),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
  });

  test('cleanup queue 指向现存账户时在删除前拒绝', () async {
    final initial = _stateWithAccount();
    final account = initial.profile!.accounts.single;
    final repository = _Repository(
      WalletState(
        revision: initial.revision,
        profile: initial.profile,
        provisioning: null,
        cleanup: null,
        cleanupQueue: <WalletCleanupPlan>[
          WalletCleanupPlan(
            operationId: _operationId,
            walletIndex: 0,
            walletGeneration: initial.profile!.walletGeneration,
            secretRefs: <WalletSecretRef>[
              WalletSecretRef(
                walletGeneration: initial.profile!.walletGeneration,
                secretOwner: account.secretOwner,
                accountId: account.accountId,
              ),
            ],
            deleteWalletKey: false,
          ),
        ],
      ),
    );
    final store = _SeedStore();

    await expectLater(
      WalletService(
        repository: repository,
        seedStore: store,
      ).reconcileCleanup(),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
  });

  test('cleanup queue 超过上限时在删除前拒绝', () async {
    final accountId = '0x${List<String>.filled(64, '3').join()}';
    final plan = WalletCleanupPlan(
      operationId: _operationId,
      walletIndex: 0,
      walletGeneration: _walletGeneration,
      secretRefs: <WalletSecretRef>[
        WalletSecretRef(
          walletGeneration: _walletGeneration,
          secretOwner: _staleSecretOwner,
          accountId: accountId,
        ),
      ],
      deleteWalletKey: true,
    );
    final repository = _Repository(
      WalletState(
        revision: 1,
        profile: null,
        provisioning: null,
        cleanup: null,
        cleanupQueue: List<WalletCleanupPlan>.filled(65, plan),
      ),
    );
    final store = _SeedStore();

    await expectLater(
      WalletService(
        repository: repository,
        seedStore: store,
      ).reconcileCleanup(),
      throwsA(isA<WalletInvariantViolation>()),
    );

    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
  });

  test('遗留清理计划失败后可重放，且服务修改队列恢复', () async {
    final accountId = '0x${List.filled(64, '3').join()}';
    final repository = _Repository(
      WalletState(
        revision: 7,
        profile: null,
        provisioning: null,
        cleanup: WalletCleanupPlan(
          operationId: _operationId,
          walletIndex: 0,
          walletGeneration: _walletGeneration,
          secretRefs: <WalletSecretRef>[
            WalletSecretRef(
              walletGeneration: _walletGeneration,
              secretOwner: _staleSecretOwner,
              accountId: accountId,
            ),
          ],
          deleteWalletKey: true,
        ),
        cleanupQueue: const <WalletCleanupPlan>[],
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

  test('完成 provision 的 commit 写后抛错由持久事实收敛且零删除', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    store.afterNextPut = () async {
      repository.throwAfterNextCommit = true;
    };
    final service = WalletService(repository: repository, seedStore: store);

    final profile = await service.importWallet(_mnemonic);

    expect(repository.state.profile?.masterAccountId, profile.masterAccountId);
    expect(repository.state.provisioning, isNull);
    expect(repository.state.cleanup, isNull);
    expect(repository.state.cleanupQueue, isEmpty);
    expect(store.deleteAttempts, isEmpty);
    expect(store.deleteWalletAttempts, 0);
  });

  test('失败 provision 精确补偿清理不得删除另一执行者成功钱包', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    late String successfulGeneration;
    late String successfulOwner;
    store.afterNextPut = () async {
      final pending = repository.state;
      final plan = pending.provisioning!;
      final target = pending.profile!;
      final ref = plan.secretRefs.single;
      final cleanup = WalletCleanupPlan(
        operationId: plan.operationId,
        walletIndex: plan.walletIndex,
        walletGeneration: plan.walletGeneration,
        secretRefs: plan.secretRefs,
        deleteWalletKey: true,
      );
      await repository.commit(
        expectedRevision: pending.revision,
        profile: null,
        provisioning: null,
        cleanup: cleanup,
        cleanupQueue: pending.cleanupQueue,
      );
      await store.deleteAccountKey(
        walletIndex: 0,
        walletGeneration: ref.walletGeneration,
        secretOwner: ref.secretOwner,
        accountId: ref.accountId,
      );
      await store.deleteWalletKey(
        walletIndex: 0,
        walletGeneration: plan.walletGeneration,
      );
      await repository.commit(
        expectedRevision: repository.state.revision,
        profile: null,
        provisioning: null,
        cleanup: null,
        cleanupQueue: repository.state.cleanupQueue,
      );

      successfulGeneration = plan.walletGeneration == _replacementGeneration
          ? _secondReplacementGeneration
          : _replacementGeneration;
      successfulOwner = ref.secretOwner == _replacementSecretOwner
          ? _secondReplacementSecretOwner
          : _replacementSecretOwner;
      final successfulAccount = WalletAccount(
        index: target.accounts.single.index,
        accountId: target.accounts.single.accountId,
        secretOwner: successfulOwner,
        ss58Address: target.accounts.single.ss58Address,
        name: target.accounts.single.name,
        createdAtMillis: target.accounts.single.createdAtMillis,
      );
      final successfulProfile = WalletProfile(
        walletIndex: 0,
        walletGeneration: successfulGeneration,
        masterAccountId: successfulAccount.accountId,
        origin: target.origin,
        createdAtMillis: target.createdAtMillis,
        activeAccountId: successfulAccount.accountId,
        accounts: <WalletAccount>[successfulAccount],
      );
      await repository.commit(
        expectedRevision: repository.state.revision,
        profile: successfulProfile,
        provisioning: null,
        cleanup: null,
        cleanupQueue: repository.state.cleanupQueue,
      );
      await store.putAccountKey(
        walletIndex: 0,
        walletGeneration: successfulGeneration,
        secretOwner: successfulOwner,
        accountId: successfulAccount.accountId,
        childMiniSecret: Uint8List.fromList(List<int>.filled(32, 9)),
      );
      store.throwAfterNextPut = true;
    };
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(isA<SecureStoreUnavailable>()),
    );

    final successfulProfile = repository.state.profile!;
    final successfulAccount = successfulProfile.accounts.single;
    expect(successfulProfile.walletGeneration, successfulGeneration);
    expect(successfulAccount.secretOwner, successfulOwner);
    expect(
      await store.hasWalletKey(
        walletIndex: 0,
        walletGeneration: successfulGeneration,
      ),
      isTrue,
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: successfulGeneration,
        secretOwner: successfulOwner,
        accountId: successfulAccount.accountId,
      ),
      isTrue,
    );
    expect(
      store.deletedWalletGenerations,
      isNot(contains(successfulGeneration)),
    );
  });

  test('cleanup 先完成而 secret 后落地时重新 CAS 精确清理且保全胜者', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    late String lateGeneration;
    late String lateOwner;
    store.beforeNextPutWithIdentity =
        (walletGeneration, secretOwner, accountId, childMiniSecret) async {
          lateGeneration = walletGeneration;
          lateOwner = secretOwner;
          final pending = repository.state;
          final plan = pending.provisioning!;
          final target = pending.profile!;
          final cleanup = WalletCleanupPlan(
            operationId: plan.operationId,
            walletIndex: plan.walletIndex,
            walletGeneration: plan.walletGeneration,
            secretRefs: plan.secretRefs,
            deleteWalletKey: true,
          );
          await repository.commit(
            expectedRevision: pending.revision,
            profile: null,
            provisioning: null,
            cleanup: cleanup,
            cleanupQueue: pending.cleanupQueue,
          );
          await store.deleteAccountKey(
            walletIndex: 0,
            walletGeneration: walletGeneration,
            secretOwner: secretOwner,
            accountId: accountId,
          );
          await store.deleteWalletKey(
            walletIndex: 0,
            walletGeneration: walletGeneration,
          );
          await repository.commit(
            expectedRevision: repository.state.revision,
            profile: null,
            provisioning: null,
            cleanup: null,
            cleanupQueue: repository.state.cleanupQueue,
          );

          final winnerAccount = WalletAccount(
            index: target.accounts.single.index,
            accountId: accountId,
            secretOwner: _replacementSecretOwner,
            ss58Address: target.accounts.single.ss58Address,
            name: target.accounts.single.name,
            createdAtMillis: target.accounts.single.createdAtMillis,
          );
          final winnerProfile = WalletProfile(
            walletIndex: 0,
            walletGeneration: _replacementGeneration,
            masterAccountId: accountId,
            origin: target.origin,
            createdAtMillis: target.createdAtMillis,
            activeAccountId: accountId,
            accounts: <WalletAccount>[winnerAccount],
          );
          await repository.commit(
            expectedRevision: repository.state.revision,
            profile: winnerProfile,
            provisioning: null,
            cleanup: null,
            cleanupQueue: repository.state.cleanupQueue,
          );
          await store.putAccountKey(
            walletIndex: 0,
            walletGeneration: winnerProfile.walletGeneration,
            secretOwner: winnerAccount.secretOwner,
            accountId: accountId,
            childMiniSecret: childMiniSecret,
          );
        };
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(isA<WalletRepositoryConflict>()),
    );

    final winner = repository.state.profile!;
    final winnerAccount = winner.accounts.single;
    expect(winner.walletGeneration, _replacementGeneration);
    expect(winnerAccount.secretOwner, _replacementSecretOwner);
    expect(repository.state.provisioning, isNull);
    expect(repository.state.cleanup, isNull);
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: lateGeneration,
        secretOwner: lateOwner,
        accountId: winnerAccount.accountId,
      ),
      isFalse,
    );
    expect(
      await store.hasWalletKey(
        walletIndex: 0,
        walletGeneration: lateGeneration,
      ),
      isFalse,
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: winner.walletGeneration,
        secretOwner: winnerAccount.secretOwner,
        accountId: winnerAccount.accountId,
      ),
      isTrue,
    );
    expect(
      await store.hasWalletKey(
        walletIndex: 0,
        walletGeneration: winner.walletGeneration,
      ),
      isTrue,
    );
    expect(repository.state.cleanupQueue, isEmpty);
  });

  test('B 仍在 provision 时 A 迟到写入经 queue 精确清理且 B 可完成', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    late String lateGeneration;
    late String lateOwner;
    late WalletProfile winnerProfile;
    late WalletProvisioningPlan winnerProvisioning;
    store.beforeNextPutWithIdentity =
        (walletGeneration, secretOwner, accountId, childMiniSecret) async {
          lateGeneration = walletGeneration;
          lateOwner = secretOwner;
          final pending = repository.state;
          final plan = pending.provisioning!;
          final target = pending.profile!;
          final cleanup = WalletCleanupPlan(
            operationId: plan.operationId,
            walletIndex: plan.walletIndex,
            walletGeneration: plan.walletGeneration,
            secretRefs: plan.secretRefs,
            deleteWalletKey: true,
          );
          await repository.commit(
            expectedRevision: pending.revision,
            profile: null,
            provisioning: null,
            cleanup: cleanup,
            cleanupQueue: pending.cleanupQueue,
          );
          await store.deleteAccountKey(
            walletIndex: 0,
            walletGeneration: walletGeneration,
            secretOwner: secretOwner,
            accountId: accountId,
          );
          await store.deleteWalletKey(
            walletIndex: 0,
            walletGeneration: walletGeneration,
          );
          await repository.commit(
            expectedRevision: repository.state.revision,
            profile: null,
            provisioning: null,
            cleanup: null,
            cleanupQueue: repository.state.cleanupQueue,
          );

          final winnerAccount = WalletAccount(
            index: target.accounts.single.index,
            accountId: accountId,
            secretOwner: _replacementSecretOwner,
            ss58Address: target.accounts.single.ss58Address,
            name: target.accounts.single.name,
            createdAtMillis: target.accounts.single.createdAtMillis,
          );
          winnerProfile = WalletProfile(
            walletIndex: 0,
            walletGeneration: _replacementGeneration,
            masterAccountId: accountId,
            origin: target.origin,
            createdAtMillis: target.createdAtMillis,
            activeAccountId: accountId,
            accounts: <WalletAccount>[winnerAccount],
          );
          winnerProvisioning = WalletProvisioningPlan(
            operationId: _operationId,
            walletIndex: 0,
            walletGeneration: winnerProfile.walletGeneration,
            previousProfile: null,
            secretRefs: <WalletSecretRef>[
              WalletSecretRef(
                walletGeneration: winnerProfile.walletGeneration,
                secretOwner: winnerAccount.secretOwner,
                accountId: accountId,
              ),
            ],
            deleteWalletKeyOnRollback: true,
          );
          await repository.commit(
            expectedRevision: repository.state.revision,
            profile: winnerProfile,
            provisioning: winnerProvisioning,
            cleanup: null,
            cleanupQueue: repository.state.cleanupQueue,
          );
          await store.putAccountKey(
            walletIndex: 0,
            walletGeneration: winnerProfile.walletGeneration,
            secretOwner: winnerAccount.secretOwner,
            accountId: accountId,
            childMiniSecret: childMiniSecret,
          );
        };
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(isA<WalletRepositoryConflict>()),
    );

    expect(repository.state.profile, same(winnerProfile));
    expect(repository.state.provisioning, same(winnerProvisioning));
    expect(repository.state.cleanup, isNull);
    expect(repository.state.cleanupQueue, isEmpty);
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: lateGeneration,
        secretOwner: lateOwner,
        accountId: winnerProfile.masterAccountId,
      ),
      isFalse,
    );
    expect(
      await store.hasWalletKey(
        walletIndex: 0,
        walletGeneration: lateGeneration,
      ),
      isFalse,
    );
    final winnerAccount = winnerProfile.accounts.single;
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: winnerProfile.walletGeneration,
        secretOwner: winnerAccount.secretOwner,
        accountId: winnerAccount.accountId,
      ),
      isTrue,
    );
    expect(
      await store.hasWalletKey(
        walletIndex: 0,
        walletGeneration: winnerProfile.walletGeneration,
      ),
      isTrue,
    );

    await repository.commit(
      expectedRevision: repository.state.revision,
      profile: winnerProfile,
      provisioning: null,
      cleanup: null,
      cleanupQueue: repository.state.cleanupQueue,
    );
    expect(repository.state.profile, same(winnerProfile));
    expect(repository.state.provisioning, isNull);
    expect(repository.state.cleanupQueue, isEmpty);
  });

  test('迟到 secret 的精确补偿失败时保留赢家旁 cleanup 并可重放', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    late String lateGeneration;
    late String lateOwner;
    store.beforeNextPutWithIdentity =
        (walletGeneration, secretOwner, accountId, childMiniSecret) async {
          lateGeneration = walletGeneration;
          lateOwner = secretOwner;
          final pending = repository.state;
          final plan = pending.provisioning!;
          final target = pending.profile!;
          await repository.commit(
            expectedRevision: pending.revision,
            profile: null,
            provisioning: null,
            cleanup: WalletCleanupPlan(
              operationId: plan.operationId,
              walletIndex: plan.walletIndex,
              walletGeneration: plan.walletGeneration,
              secretRefs: plan.secretRefs,
              deleteWalletKey: true,
            ),
            cleanupQueue: pending.cleanupQueue,
          );
          await store.deleteAccountKey(
            walletIndex: 0,
            walletGeneration: walletGeneration,
            secretOwner: secretOwner,
            accountId: accountId,
          );
          await store.deleteWalletKey(
            walletIndex: 0,
            walletGeneration: walletGeneration,
          );
          await repository.commit(
            expectedRevision: repository.state.revision,
            profile: null,
            provisioning: null,
            cleanup: null,
            cleanupQueue: repository.state.cleanupQueue,
          );

          final winnerAccount = WalletAccount(
            index: target.accounts.single.index,
            accountId: accountId,
            secretOwner: _replacementSecretOwner,
            ss58Address: target.accounts.single.ss58Address,
            name: target.accounts.single.name,
            createdAtMillis: target.accounts.single.createdAtMillis,
          );
          final winnerProfile = WalletProfile(
            walletIndex: 0,
            walletGeneration: _replacementGeneration,
            masterAccountId: accountId,
            origin: target.origin,
            createdAtMillis: target.createdAtMillis,
            activeAccountId: accountId,
            accounts: <WalletAccount>[winnerAccount],
          );
          await repository.commit(
            expectedRevision: repository.state.revision,
            profile: winnerProfile,
            provisioning: null,
            cleanup: null,
            cleanupQueue: repository.state.cleanupQueue,
          );
          await store.putAccountKey(
            walletIndex: 0,
            walletGeneration: winnerProfile.walletGeneration,
            secretOwner: winnerAccount.secretOwner,
            accountId: accountId,
            childMiniSecret: childMiniSecret,
          );
          store.throwBeforeNextDeleteAccount = true;
        };
    final service = WalletService(repository: repository, seedStore: store);

    await expectLater(
      service.importWallet(_mnemonic),
      throwsA(isA<WalletLocalCleanupException>()),
    );

    final winner = repository.state.profile!;
    final winnerAccount = winner.accounts.single;
    expect(winner.walletGeneration, _replacementGeneration);
    expect(repository.state.cleanup, isNull);
    expect(
      repository.state.cleanupQueue.single.walletGeneration,
      lateGeneration,
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: lateGeneration,
        secretOwner: lateOwner,
        accountId: winnerAccount.accountId,
      ),
      isTrue,
    );

    await WalletService(
      repository: repository,
      seedStore: store,
    ).reconcileCleanup();

    expect(repository.state.cleanup, isNull);
    expect(repository.state.cleanupQueue, isEmpty);
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: lateGeneration,
        secretOwner: lateOwner,
        accountId: winnerAccount.accountId,
      ),
      isFalse,
    );
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: winner.walletGeneration,
        secretOwner: winnerAccount.secretOwner,
        accountId: winnerAccount.accountId,
      ),
      isTrue,
    );
    expect(
      await store.hasWalletKey(
        walletIndex: 0,
        walletGeneration: winner.walletGeneration,
      ),
      isTrue,
    );
  });

  test('迟到的账户 cleanup 不能删除同 AccountId 的新 secret owner', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    await service.importWallet(_mnemonic);
    final removed = (await service.addAccounts(
      mnemonic: _mnemonic,
      indices: const <int>[1],
    )).single;
    final deleteStarted = Completer<void>();
    store.beforeNextDeleteAccount = () async {
      final deleting = repository.state;
      final cleanup = deleting.cleanup!;
      final oldRef = cleanup.secretRefs.single;
      await store.deleteAccountKey(
        walletIndex: 0,
        walletGeneration: oldRef.walletGeneration,
        secretOwner: oldRef.secretOwner,
        accountId: oldRef.accountId,
      );
      await repository.commit(
        expectedRevision: deleting.revision,
        profile: deleting.profile,
        provisioning: null,
        cleanup: null,
        cleanupQueue: deleting.cleanupQueue,
      );
      final retained = repository.state.profile!;
      final newOwner = oldRef.secretOwner == _replacementSecretOwner
          ? _secondReplacementSecretOwner
          : _replacementSecretOwner;
      final replacement = WalletAccount(
        index: removed.index,
        accountId: removed.accountId,
        secretOwner: newOwner,
        ss58Address: removed.ss58Address,
        name: removed.name,
        createdAtMillis: removed.createdAtMillis,
      );
      await repository.commit(
        expectedRevision: repository.state.revision,
        profile: retained.copyWith(
          accounts: <WalletAccount>[...retained.accounts, replacement],
        ),
        provisioning: null,
        cleanup: null,
        cleanupQueue: repository.state.cleanupQueue,
      );
      await store.putAccountKey(
        walletIndex: 0,
        walletGeneration: retained.walletGeneration,
        secretOwner: newOwner,
        accountId: replacement.accountId,
        childMiniSecret: Uint8List.fromList(List<int>.filled(32, 8)),
      );
      deleteStarted.complete();
    };

    await service.deleteAccount(removed.accountId);
    await deleteStarted.future;

    final current = repository.state.profile!;
    final replacement = current.accountById(removed.accountId)!;
    expect(replacement.secretOwner, isNot(removed.secretOwner));
    expect(repository.state.cleanup, isNull);
    expect(repository.state.cleanupQueue, isEmpty);
    expect(
      await store.hasAccountKey(
        walletIndex: 0,
        walletGeneration: current.walletGeneration,
        secretOwner: replacement.secretOwner,
        accountId: replacement.accountId,
      ),
      isTrue,
    );
  });

  test('进程中断留下的 provision 可由新实例 CAS 转 cleanup 并恢复', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final profile = await service.importWallet(_mnemonic);
    final account = profile.accounts.single;
    await repository.commit(
      expectedRevision: repository.state.revision,
      profile: profile,
      provisioning: WalletProvisioningPlan(
        operationId: _operationId,
        walletIndex: 0,
        walletGeneration: profile.walletGeneration,
        previousProfile: null,
        secretRefs: <WalletSecretRef>[
          WalletSecretRef(
            walletGeneration: profile.walletGeneration,
            secretOwner: account.secretOwner,
            accountId: account.accountId,
          ),
        ],
        deleteWalletKeyOnRollback: true,
      ),
      cleanup: null,
      cleanupQueue: repository.state.cleanupQueue,
    );

    final recovery = WalletService(repository: repository, seedStore: store);
    await recovery.reconcileCleanup();

    expect(repository.state.profile, isNull);
    expect(repository.state.provisioning, isNull);
    expect(repository.state.cleanup, isNull);
    expect(store.accountIds, isEmpty);
    expect(store.walletKeyExists, isFalse);
  });

  test('删除后用同助记词重建钱包及重加账户均获得全新 owner', () async {
    final repository = _Repository(const WalletState.empty());
    final store = _SeedStore();
    final service = WalletService(repository: repository, seedStore: store);
    final first = await service.importWallet(_mnemonic);
    final firstChild = (await service.addAccounts(
      mnemonic: _mnemonic,
      indices: const <int>[1],
    )).single;
    await service.deleteAccount(firstChild.accountId);
    final secondChild = (await service.addAccounts(
      mnemonic: _mnemonic,
      indices: const <int>[1],
    )).single;

    expect(secondChild.accountId, firstChild.accountId);
    expect(secondChild.secretOwner, isNot(firstChild.secretOwner));

    await service.deleteWallet();
    final second = await service.importWallet(_mnemonic);
    expect(second.masterAccountId, first.masterAccountId);
    expect(second.walletGeneration, isNot(first.walletGeneration));
    expect(
      second.accounts.single.secretOwner,
      isNot(first.accounts.single.secretOwner),
    );
  });
}

const String _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon about';

/// Substrate 开发助记词；全网公开，只允许用于测试。
const String _exportGoldenMnemonic =
    'bottom drive obey lake curtain smoke basket hold race lonely fit walk';

const String _walletGeneration = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _operationId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _staleSecretOwner = 'cccccccccccccccccccccccccccccccc';
const String _replacementGeneration = 'dddddddddddddddddddddddddddddddd';
const String _secondReplacementGeneration = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const String _replacementSecretOwner = '11111111111111111111111111111111';
const String _secondReplacementSecretOwner = '22222222222222222222222222222222';

/// CitizenApp/CitizenWallet 已共同验证的 `//0`、`//1`、`//2`
/// (AccountId, child mini-secret) 金标。
const List<(String, String)> _exportGoldenAccounts = <(String, String)>[
  (
    '0x2afba9278e30ccf6a6ceb3a8b6e336b70068f045c666f2e7f4f9cc5f47db8972',
    '0x914dded06277afbe5b0e8a30bce539ec8a9552a784d08e530dc7c2915c478393',
  ),
  (
    '0xb606fc73f57f03cdb4c932d475ab426043e429cecc2ffff0d2672b0df8398c48',
    '0x4433c3ada0cf37c3050d5435321872f4f84ef53d8b5f1f1560689d500b882245',
  ),
  (
    '0x46f136b564e1fad55031404dd84e5cd3fa76bfe7cc7599b39d38fd06663bbc0a',
    '0x5418179cea7224f2d9d2ab437773c2fdb266e52ef7fa52c0d9c15c6ca6068748',
  ),
];

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
      secretOwner: List<String>.filled(
        32,
        (index + 1).toRadixString(16),
      ).join(),
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
      walletGeneration: _walletGeneration,
      masterAccountId: accountId,
      origin: WalletOrigin.imported,
      createdAtMillis: 1,
      activeAccountId: accountId,
      accounts: accounts,
    ),
    provisioning: null,
    cleanup: null,
    cleanupQueue: const <WalletCleanupPlan>[],
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
    required WalletProvisioningPlan? provisioning,
    required WalletCleanupPlan? cleanup,
    required List<WalletCleanupPlan> cleanupQueue,
  }) async {
    if (state.revision != expectedRevision) {
      throw const WalletRepositoryConflict();
    }
    state = WalletState(
      revision: state.revision + 1,
      profile: profile,
      provisioning: provisioning,
      cleanup: cleanup,
      cleanupQueue: cleanupQueue,
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
  final Map<String, Uint8List> _accountSecrets = <String, Uint8List>{};
  final Map<String, String> _knownSlotByAccountId = <String, String>{};
  final Set<String> _walletGenerations = <String>{};
  final List<String> deletedSecretSlots = <String>[];
  final List<String> deletedWalletGenerations = <String>[];
  int readCount = 0;
  int putCount = 0;
  int deleteWalletAttempts = 0;
  int hasWalletAttempts = 0;
  bool walletKeyExists = false;
  bool throwAfterNextPut = false;
  Future<void> Function()? beforeNextPut;
  Future<void> Function(String, String, String, Uint8List)?
  beforeNextPutWithIdentity;
  Future<void> Function()? afterNextPut;
  Future<void> Function()? beforeNextRead;
  Future<void> Function()? beforeNextHasWallet;
  Future<void> Function()? beforeNextDeleteAccount;
  Uint8List? lastReadBuffer;
  final List<Uint8List> readBuffers = <Uint8List>[];
  bool throwBeforeNextDeleteAccount = false;
  String? throwBeforeDeleteAccountOnce;
  String? throwAfterDeleteAccountOnce;
  bool throwAfterDeleteWalletOnce = false;
  bool keepNextDeletedAccount = false;
  bool keepNextDeletedWalletKey = false;
  SecureAuthStatus authStatusValue = SecureAuthStatus.available;

  @override
  Future<SecureAuthStatus> authStatus() async => authStatusValue;
  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async {
    events?.add('seed:delete:$accountId');
    deleteAttempts.add(accountId);
    final beforeDelete = beforeNextDeleteAccount;
    beforeNextDeleteAccount = null;
    if (beforeDelete != null) await beforeDelete();
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
    final slot = _slotKey(walletGeneration, secretOwner, accountId);
    _accountSecrets.remove(slot);
    deletedSecretSlots.add(slot);
    if (!_hasManagedAccount(accountId)) accountIds.remove(accountId);
    deletedAccountIds.add(accountId);
    if (throwAfterDeleteAccountOnce == accountId) {
      throwAfterDeleteAccountOnce = null;
      throw const SecureStoreUnavailable('delete failed after mutation');
    }
  }

  @override
  Future<void> deleteWalletKey({
    required int walletIndex,
    required String walletGeneration,
  }) async {
    events?.add('seed:delete-wallet');
    deleteWalletAttempts++;
    if (keepNextDeletedWalletKey) {
      keepNextDeletedWalletKey = false;
      return;
    }
    _walletGenerations.remove(walletGeneration);
    deletedWalletGenerations.add(walletGeneration);
    walletKeyExists = _walletGenerations.isNotEmpty;
    if (throwAfterDeleteWalletOnce) {
      throwAfterDeleteWalletOnce = false;
      throw const SecureStoreUnavailable('delete KEK failed after mutation');
    }
  }

  @override
  Future<bool> hasAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async {
    events?.add('seed:has:$accountId');
    hasAccountAttempts.add(accountId);
    final hasManaged = _hasManagedAccount(accountId);
    return hasManaged
        ? _accountSecrets.containsKey(
            _slotKey(walletGeneration, secretOwner, accountId),
          )
        : accountIds.contains(accountId);
  }

  @override
  Future<bool> hasWalletKey({
    required int walletIndex,
    required String walletGeneration,
  }) async {
    events?.add('seed:has-wallet');
    hasWalletAttempts++;
    final beforeHasWallet = beforeNextHasWallet;
    beforeNextHasWallet = null;
    if (beforeHasWallet != null) await beforeHasWallet();
    return walletKeyExists &&
        (_walletGenerations.isEmpty ||
            _walletGenerations.contains(walletGeneration));
  }

  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {
    putCount++;
    final beforePut = beforeNextPut;
    beforeNextPut = null;
    if (beforePut != null) await beforePut();
    final beforePutWithIdentity = beforeNextPutWithIdentity;
    beforeNextPutWithIdentity = null;
    if (beforePutWithIdentity != null) {
      await beforePutWithIdentity(
        walletGeneration,
        secretOwner,
        accountId,
        childMiniSecret,
      );
    }
    accountIds.add(accountId);
    final slot = _slotKey(walletGeneration, secretOwner, accountId);
    _accountSecrets[slot] = Uint8List.fromList(childMiniSecret);
    _knownSlotByAccountId[accountId] = slot;
    _walletGenerations.add(walletGeneration);
    walletKeyExists = true;
    final afterPut = afterNextPut;
    afterNextPut = null;
    if (afterPut != null) await afterPut();
    if (throwAfterNextPut) {
      throwAfterNextPut = false;
      throw const SecureStoreUnavailable('put failed after mutation');
    }
  }

  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async {
    readCount++;
    final beforeRead = beforeNextRead;
    beforeNextRead = null;
    if (beforeRead != null) await beforeRead();
    if (!accountIds.contains(accountId)) return null;
    final stored =
        _accountSecrets[_slotKey(walletGeneration, secretOwner, accountId)];
    if (stored == null) return null;
    final result = Uint8List.fromList(stored);
    lastReadBuffer = result;
    readBuffers.add(result);
    return result;
  }

  void removeAccountSecret(String accountId) {
    accountIds.remove(accountId);
    _accountSecrets.removeWhere((key, _) => key.endsWith(':$accountId'));
  }

  void replaceAccountSecret(String accountId, Uint8List childMiniSecret) {
    accountIds.add(accountId);
    final key = _knownSlotByAccountId[accountId];
    if (key == null) throw StateError('unknown test secret slot');
    _accountSecrets[key] = Uint8List.fromList(childMiniSecret);
  }

  Uint8List copyAccountSecret(String accountId) {
    final key = _knownSlotByAccountId[accountId];
    if (key == null) throw StateError('unknown test secret slot');
    return Uint8List.fromList(_accountSecrets[key]!);
  }

  bool _hasManagedAccount(String accountId) =>
      _accountSecrets.keys.any((key) => key.endsWith(':$accountId'));

  static String _slotKey(
    String walletGeneration,
    String secretOwner,
    String accountId,
  ) => '$walletGeneration:$secretOwner:$accountId';
}
