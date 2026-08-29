import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

import '../crypto/account_codec.dart';
import '../crypto/native_sr25519.dart';
import '../crypto/wallet_mini_secret.dart';
import '../crypto/wallet_password.dart';
import 'models.dart';
import 'secure_seed_store.dart';
import 'wallet_error.dart';
import 'wallet_repository.dart';

/// 产品无关的公民链无根热钱包服务。
final class WalletService {
  WalletService({
    required WalletRepository repository,
    required SecureSeedStore seedStore,
    DateTime Function()? clock,
  }) : _repository = repository,
       _seedStore = seedStore,
       _clock = clock ?? DateTime.now;

  static const int walletIndex = 0;
  static const int maxAccountIndex = 1989;
  static const int maxCleanupQueueLength = 64;

  final WalletRepository _repository;
  final SecureSeedStore _seedStore;
  final DateTime Function() _clock;
  static Future<void> _exclusiveOperationTail = Future<void>.value();
  static final RegExp _ownerPattern = RegExp(r'^[0-9a-f]{32}$');

  Future<WalletProfile?> get profile async {
    final state = await _repository.load();
    _validateState(state);
    return state.provisioning?.previousProfile ?? state.profile;
  }

  /// 返回经本机硬件金库完整核验的可用钱包；钱包不存在或任一秘密事实
  /// 缺失、错配时返回 `null`。
  ///
  /// 本检查在全实例串行队列内执行：先验证公开 profile 与账户0 锚点，
  /// 再确认钱包 KEK 存在，并逐个读取 profile 中每个 child mini-secret、
  /// 由 sr25519 公钥反证其 AccountId。读取会触发生物识别，所有返回的
  /// 明文字节都在 `finally` 中清零。硬件金库或仓储异常原样上抛，绝不
  /// 伪装成“钱包不可用”。
  Future<WalletProfile?> get usableProfile =>
      _serialize(_usableProfileWithinQueue);

  /// 是否存在经 [usableProfile] 同等完整核验的本机热钱包。
  ///
  /// 本 getter 会独立执行一次完整硬件金库读取，不缓存先前结果。
  Future<bool> get isUsable =>
      _serialize(() async => await _usableProfileWithinQueue() != null);

  Future<WalletCreationResult> create({
    int wordCount = 12,
    String password = '',
  }) => _serialize(() async {
    if (wordCount != 12 && wordCount != 24) {
      throw ArgumentError.value(wordCount, 'wordCount', '只支持 12 或 24 个助记词');
    }
    await _requireSecureDevice();
    var state = await _reconcilePendingOperations();
    if (state.profile != null) throw const WalletAlreadyExists();
    final mnemonic = bip39.Mnemonic.generate(
      bip39.Language.english,
      length: wordCount == 24
          ? bip39.MnemonicLength.words24
          : bip39.MnemonicLength.words12,
    ).sentence;
    final walletGeneration = _mintOwner();
    final accountOwner = _mintOwner(forbidden: <String>{walletGeneration});
    final operationId = _mintOwner(
      forbidden: <String>{walletGeneration, accountOwner},
    );
    final derived = await _deriveAccount(mnemonic, password, 0, accountOwner);
    try {
      final profile = _profileFromAccount(
        derived.account,
        WalletOrigin.created,
        walletGeneration,
      );
      final provisioning = _newProvisioning(
        operationId: operationId,
        targetProfile: profile,
        previousProfile: null,
        accounts: <WalletAccount>[derived.account],
        deleteWalletKeyOnRollback: true,
      );
      state = await _commitFacts(
        expectedRevision: state.revision,
        profile: profile,
        provisioning: provisioning,
        cleanup: null,
        cleanupQueue: state.cleanupQueue,
      );
      try {
        await _seedStore.putAccountKey(
          walletIndex: walletIndex,
          walletGeneration: walletGeneration,
          secretOwner: derived.account.secretOwner,
          accountId: derived.account.accountId,
          childMiniSecret: derived.child,
        );
        await _verifyProvisionedFactsAndSecrets(state);
        state = await _completeProvisioning(state);
      } on Object catch (error, stackTrace) {
        await _rollbackProvisioning(committedState: state);
        Error.throwWithStackTrace(error, stackTrace);
      }
      return WalletCreationResult(profile: state.profile!, mnemonic: mnemonic);
    } finally {
      derived.dispose();
    }
  });

  Future<WalletProfile> importWallet(String mnemonic, {String password = ''}) =>
      _serialize(() async {
        await _requireSecureDevice();
        var state = await _reconcilePendingOperations();
        if (state.profile != null) throw const WalletAlreadyExists();
        final normalized = _validatedMnemonic(mnemonic);
        final walletGeneration = _mintOwner();
        final accountOwner = _mintOwner(forbidden: <String>{walletGeneration});
        final operationId = _mintOwner(
          forbidden: <String>{walletGeneration, accountOwner},
        );
        final derived = await _deriveAccount(
          normalized,
          password,
          0,
          accountOwner,
        );
        try {
          final profile = _profileFromAccount(
            derived.account,
            WalletOrigin.imported,
            walletGeneration,
          );
          final provisioning = _newProvisioning(
            operationId: operationId,
            targetProfile: profile,
            previousProfile: null,
            accounts: <WalletAccount>[derived.account],
            deleteWalletKeyOnRollback: true,
          );
          state = await _commitFacts(
            expectedRevision: state.revision,
            profile: profile,
            provisioning: provisioning,
            cleanup: null,
            cleanupQueue: state.cleanupQueue,
          );
          try {
            await _seedStore.putAccountKey(
              walletIndex: walletIndex,
              walletGeneration: walletGeneration,
              secretOwner: derived.account.secretOwner,
              accountId: derived.account.accountId,
              childMiniSecret: derived.child,
            );
            await _verifyProvisionedFactsAndSecrets(state);
            state = await _completeProvisioning(state);
          } on Object catch (error, stackTrace) {
            await _rollbackProvisioning(committedState: state);
            Error.throwWithStackTrace(error, stackTrace);
          }
          return state.profile!;
        } finally {
          derived.dispose();
        }
      });

  Future<List<WalletAccount>> addAccounts({
    required String mnemonic,
    required List<int> indices,
    String password = '',
  }) => _serialize(() async {
    if (indices.isEmpty) throw ArgumentError('indices 不能为空');
    await _requireSecureDevice();
    var state = await _reconcilePendingOperations();
    final profile = state.profile;
    if (profile == null) throw const WalletNotFound();
    final normalized = _validatedMnemonic(mnemonic);
    final owner = await _deriveAccount(
      normalized,
      password,
      0,
      profile.accounts.first.secretOwner,
    );
    try {
      if (owner.account.accountId != profile.masterAccountId) {
        throw const WalletAuthenticationFailed('助记词或 password 与该钱包不符');
      }
    } finally {
      owner.dispose();
    }
    final existingIndices = profile.accounts
        .map((entry) => entry.index)
        .toSet();
    final seen = <int>{};
    for (final index in indices) {
      if (index < 1 || index > maxAccountIndex) {
        throw RangeError.range(index, 1, maxAccountIndex, 'index');
      }
      if (!seen.add(index)) throw ArgumentError('账户序号重复：$index');
      if (existingIndices.contains(index)) {
        throw ArgumentError('账户序号已存在：$index');
      }
    }
    final sorted = seen.toList()..sort();
    await _requireExistingProfileSecrets(profile);
    await _requireUsableAnchor(profile);
    final derived = <_DerivedAccount>[];
    try {
      final forbiddenOwners = <String>{
        profile.walletGeneration,
        ...profile.accounts.map((account) => account.secretOwner),
      };
      final owners = <int, String>{};
      for (final index in sorted) {
        final secretOwner = _mintOwner(forbidden: forbiddenOwners);
        forbiddenOwners.add(secretOwner);
        owners[index] = secretOwner;
      }
      final operationId = _mintOwner(forbidden: forbiddenOwners);
      derived.addAll(
        await _deriveAccounts(normalized, password, sorted, owners),
      );
      final added = derived
          .map((entry) => entry.account)
          .toList(growable: false);
      final expandedProfile = profile.copyWith(
        accounts: <WalletAccount>[...profile.accounts, ...added],
      );
      final provisioning = _newProvisioning(
        operationId: operationId,
        targetProfile: expandedProfile,
        previousProfile: profile,
        accounts: added,
        deleteWalletKeyOnRollback: false,
      );
      state = await _commitFacts(
        expectedRevision: state.revision,
        profile: expandedProfile,
        provisioning: provisioning,
        cleanup: null,
        cleanupQueue: state.cleanupQueue,
      );
      try {
        for (final item in derived) {
          await _seedStore.putAccountKey(
            walletIndex: walletIndex,
            walletGeneration: profile.walletGeneration,
            secretOwner: item.account.secretOwner,
            accountId: item.account.accountId,
            childMiniSecret: item.child,
          );
        }
        await _verifyProvisionedFactsAndSecrets(state);
        state = await _completeProvisioning(state);
        return List<WalletAccount>.unmodifiable(added);
      } on Object catch (error, stackTrace) {
        await _rollbackProvisioning(committedState: state);
        Error.throwWithStackTrace(error, stackTrace);
      }
    } finally {
      for (final item in derived) {
        item.dispose();
      }
    }
  });

  Future<void> setActiveAccount(String accountId) => _serialize(() async {
    final state = await _reconcilePendingOperations();
    final profile = state.profile;
    if (profile == null) throw const WalletNotFound();
    if (profile.accountById(accountId) == null) {
      throw const WalletNotFound('未找到指定账户');
    }
    await _commitFacts(
      expectedRevision: state.revision,
      profile: profile.copyWith(activeAccountId: accountId),
      provisioning: null,
      cleanup: null,
      cleanupQueue: state.cleanupQueue,
    );
  });

  /// 重命名单个 `//index` 账户；名称只属于本机公开资料，不触碰任何
  /// child mini-secret、KEK、链上身份或产品用户昵称。
  Future<void> renameAccount(String accountId, String newName) =>
      _serialize(() async {
        final name = newName.trim();
        if (name.isEmpty) {
          throw ArgumentError.value(newName, 'newName', '账户名称不能为空');
        }
        if (name.runes.length > 30) {
          throw ArgumentError.value(newName, 'newName', '账户名称不能超过 30 个字符');
        }
        final state = await _repository.load();
        _validateState(state);
        if (state.provisioning != null ||
            state.cleanup != null ||
            state.cleanupQueue.isNotEmpty) {
          throw const WalletInvariantViolation('钱包仍有未完成的本机操作计划');
        }
        final profile = state.profile;
        if (profile == null || profile.accountById(accountId) == null) {
          throw const WalletNotFound('未找到指定账户');
        }
        final accounts = <WalletAccount>[
          for (final account in profile.accounts)
            if (account.accountId == accountId)
              WalletAccount(
                index: account.index,
                accountId: account.accountId,
                secretOwner: account.secretOwner,
                ss58Address: account.ss58Address,
                name: name,
                createdAtMillis: account.createdAtMillis,
              )
            else
              account,
        ];
        await _commitFacts(
          expectedRevision: state.revision,
          profile: profile.copyWith(accounts: accounts),
          provisioning: null,
          cleanup: null,
          cleanupQueue: state.cleanupQueue,
        );
      });

  /// 用指定账户在本机签名任意协议载荷；TUYU v1 等上层协议可以
  /// 复用此入口。
  Future<Uint8List> sign(String accountId, Uint8List payload) =>
      _serialize(() async {
        final profile = await _requireCurrentAccount(accountId);
        final account = profile.accountById(accountId)!;
        final child = await _seedStore.readAccountKey(
          walletIndex: profile.walletIndex,
          walletGeneration: profile.walletGeneration,
          secretOwner: account.secretOwner,
          accountId: accountId,
        );
        if (child == null) {
          throw const WalletAuthenticationFailed('账户私钥不存在');
        }
        try {
          // 生物识别和金库解密可能长时间阻塞。签名前再从
          // 持久事实确认账户仍存在；同 isolate 的删除同时
          // 被全实例队列阻塞，不得越过本次签名。
          await _requireCurrentAccount(
            accountId,
            expectedWalletGeneration: profile.walletGeneration,
            expectedSecretOwner: account.secretOwner,
          );
          final publicKey = NativeSr25519.publicKeyOf(child);
          if (citizenAccountIdFromBytes(publicKey) != accountId) {
            throw const WalletInvariantViolation('本地私钥与账户公钥不一致');
          }
          return NativeSr25519.sign(child, payload);
        } finally {
          WalletMiniSecret.clear(child);
        }
      });

  /// 由用户主动导出指定账户的 child mini-secret。
  ///
  /// 读取硬件金库会触发设备生物识别；导出结果固定为 `0x` 加 64 位
  /// 小写十六进制。此入口只导出指定子账户的 mini-secret，不导出钱包
  /// 母种子或助记词，也不会把秘密上传到任何服务。
  ///
  /// 返回值是不可擦除的 Dart [String]。产品只能在用户明确确认风险后，
  /// 于防截屏的界面即时展示，并应尽快丢弃引用，禁止持久化、记录或上传。
  Future<String> getAccountPrivateKey(String accountId) => _serialize(() async {
    final profile = await _requireCurrentAccount(accountId);
    final account = profile.accountById(accountId)!;
    final child = await _seedStore.readAccountKey(
      walletIndex: profile.walletIndex,
      walletGeneration: profile.walletGeneration,
      secretOwner: account.secretOwner,
      accountId: accountId,
    );
    if (child == null) {
      throw const WalletAuthenticationFailed('账户私钥不存在');
    }
    try {
      // 生物识别和金库解密可能长时间阻塞。导出前必须再次确认
      // 账户仍是当前公开事实；全实例队列同时禁止删除越过导出。
      await _requireCurrentAccount(
        accountId,
        expectedWalletGeneration: profile.walletGeneration,
        expectedSecretOwner: account.secretOwner,
      );
      final publicKey = NativeSr25519.publicKeyOf(child);
      if (citizenAccountIdFromBytes(publicKey) != accountId) {
        throw const WalletInvariantViolation('本地私钥与账户公钥不一致');
      }
      return '0x${_toHex(child)}';
    } finally {
      WalletMiniSecret.clear(child);
    }
  });

  Future<void> deleteAccount(String accountId) => _serialize(() async {
    var state = await _reconcilePendingOperations();
    final profile = state.profile;
    if (profile == null) throw const WalletNotFound();
    final account = profile.accountById(accountId);
    if (account == null) throw const WalletNotFound('未找到指定账户');
    if (account.index == 0) {
      if (profile.accounts.length > 1) {
        throw const WalletInvariantViolation('账户0 是钱包锚点，存在其它账户时不能单独删除');
      }
      await _deleteWalletState(state, profile);
      return;
    }
    final remaining = profile.accounts
        .where((entry) => entry.accountId != accountId)
        .toList(growable: false);
    final nextActive = profile.activeAccountId == accountId
        ? profile.masterAccountId
        : profile.activeAccountId;
    final cleanup = WalletCleanupPlan(
      operationId: _mintOwner(forbidden: _profileOwners(profile)),
      walletIndex: profile.walletIndex,
      walletGeneration: profile.walletGeneration,
      secretRefs: <WalletSecretRef>[_secretRef(profile, account)],
      deleteWalletKey: false,
    );
    state = await _commitFacts(
      expectedRevision: state.revision,
      profile: profile.copyWith(
        activeAccountId: nextActive,
        accounts: remaining,
      ),
      provisioning: null,
      cleanup: cleanup,
      cleanupQueue: state.cleanupQueue,
    );
    await _finishCleanup(state);
  });

  Future<void> deleteWallet() => _serialize(() async {
    final state = await _reconcilePendingOperations();
    final profile = state.profile;
    if (profile == null) throw const WalletNotFound();
    await _deleteWalletState(state, profile);
  });

  Future<void> reconcileCleanup() => _serialize(() async {
    await _reconcilePendingOperations();
  });

  static String _toHex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  Future<void> _deleteWalletState(
    WalletState state,
    WalletProfile profile,
  ) async {
    final cleanup = WalletCleanupPlan(
      operationId: _mintOwner(forbidden: _profileOwners(profile)),
      walletIndex: profile.walletIndex,
      walletGeneration: profile.walletGeneration,
      secretRefs: profile.accounts
          .map((account) => _secretRef(profile, account))
          .toList(growable: false),
      deleteWalletKey: true,
    );
    final committed = await _commitFacts(
      expectedRevision: state.revision,
      profile: null,
      provisioning: null,
      cleanup: cleanup,
      cleanupQueue: state.cleanupQueue,
    );
    await _finishCleanup(committed);
  }

  Future<WalletState> _reconcilePendingOperations() async {
    var state = await _repository.load();
    _validateState(state);
    state = await _drainCleanupQueue(state);
    if (state.cleanup != null) state = await _finishCleanup(state);
    if (state.provisioning == null) return state;
    final cleanupState = await _transitionProvisioningToCleanup(state);
    return _finishCleanup(cleanupState);
  }

  Future<WalletState> _finishCleanup(WalletState state) async {
    final expected = state.cleanup;
    if (expected == null) throw const WalletRepositoryConflict();
    for (var attempt = 0; attempt < 32; attempt++) {
      final latest = await _repository.load();
      _validateState(latest);
      final cleanup = latest.cleanup;
      if (cleanup == null) {
        if (_containsCleanup(latest.cleanupQueue, expected)) {
          return _finishQueuedCleanup(expected);
        }
        if (await _cleanupTargetsAbsent(expected)) return latest;
        throw const WalletRepositoryConflict();
      }
      if (!_sameCleanup(cleanup, expected)) {
        throw const WalletRepositoryConflict();
      }

      final failures = await _cleanupSecrets(
        secretRefs: cleanup.secretRefs,
        walletGeneration: cleanup.walletGeneration,
        deleteWalletKey: cleanup.deleteWalletKey,
      );
      if (failures.isNotEmpty) {
        // 删除后的公开事实与 cleanup plan 保持原样，供新实例幂等重放。
        throw WalletLocalCleanupException(failures);
      }

      try {
        return await _commitFacts(
          expectedRevision: latest.revision,
          profile: latest.profile,
          provisioning: latest.provisioning,
          cleanup: null,
          cleanupQueue: latest.cleanupQueue,
        );
      } on WalletRepositoryConflict {
        // 其它执行者只要保留本计划，就以最新 revision 再次精确收敛。
      }
    }
    throw const WalletRepositoryConflict();
  }

  Future<WalletState> _drainCleanupQueue(WalletState state) async {
    var latest = state;
    while (latest.cleanupQueue.isNotEmpty) {
      latest = await _finishQueuedCleanup(latest.cleanupQueue.first);
    }
    return latest;
  }

  Future<WalletState> _finishQueuedCleanup(WalletCleanupPlan expected) async {
    for (var attempt = 0; attempt < 32; attempt++) {
      final latest = await _repository.load();
      _validateState(latest);
      final index = latest.cleanupQueue.indexWhere(
        (entry) => _sameCleanup(entry, expected),
      );
      if (index < 0) {
        if (await _cleanupTargetsAbsent(expected)) return latest;
        throw const WalletRepositoryConflict();
      }

      final failures = await _cleanupSecrets(
        secretRefs: expected.secretRefs,
        walletGeneration: expected.walletGeneration,
        deleteWalletKey: expected.deleteWalletKey,
      );
      if (failures.isNotEmpty) {
        throw WalletLocalCleanupException(failures);
      }

      final remaining = <WalletCleanupPlan>[
        ...latest.cleanupQueue.take(index),
        ...latest.cleanupQueue.skip(index + 1),
      ];
      try {
        return await _commitFacts(
          expectedRevision: latest.revision,
          profile: latest.profile,
          provisioning: latest.provisioning,
          cleanup: latest.cleanup,
          cleanupQueue: remaining,
        );
      } on WalletRepositoryConflict {
        // 当前 profile 或另一计划前进时，保留 exact plan 并以新 revision 重试。
      }
    }
    throw const WalletRepositoryConflict();
  }

  Future<bool> _cleanupTargetsAbsent(WalletCleanupPlan cleanup) async {
    for (final ref in cleanup.secretRefs) {
      if (await _seedStore.hasAccountKey(
        walletIndex: cleanup.walletIndex,
        walletGeneration: ref.walletGeneration,
        secretOwner: ref.secretOwner,
        accountId: ref.accountId,
      )) {
        return false;
      }
    }
    return !cleanup.deleteWalletKey ||
        !await _seedStore.hasWalletKey(
          walletIndex: cleanup.walletIndex,
          walletGeneration: cleanup.walletGeneration,
        );
  }

  Future<void> _requireSecureDevice() async {
    switch (await _seedStore.authStatus()) {
      case SecureAuthStatus.available:
        return;
      case SecureAuthStatus.noStrongBiometric:
        throw const NoStrongBiometric('设备未登记强生物识别，禁止创建、导入或追加账户');
      case SecureAuthStatus.unsupported:
        throw const SecureStoreUnavailable('设备不支持 CitizenSDK 硬件金库');
    }
  }

  Future<WalletProfile?> _usableProfileWithinQueue() async {
    final state = await _repository.load();
    _validateState(state);
    final profile = state.provisioning?.previousProfile ?? state.profile;
    if (profile == null || state.cleanup != null) return null;
    if (!await _seedStore.hasWalletKey(
      walletIndex: profile.walletIndex,
      walletGeneration: profile.walletGeneration,
    )) {
      return null;
    }
    for (final account in profile.accounts) {
      final child = await _seedStore.readAccountKey(
        walletIndex: profile.walletIndex,
        walletGeneration: profile.walletGeneration,
        secretOwner: account.secretOwner,
        accountId: account.accountId,
      );
      if (child == null) return null;
      try {
        final publicKey = NativeSr25519.publicKeyOf(child);
        if (citizenAccountIdFromBytes(publicKey) != account.accountId) {
          return null;
        }
      } finally {
        WalletMiniSecret.clear(child);
      }
    }

    // 多次生物识别期间可能有队列外的仓储实现发生变化；不得返回
    // 已过期 profile。SDK 自身的其它实例已由同一队列排除在外。
    final observed = await _repository.load();
    _validateState(observed);
    if (!_sameProfile(observed.profile, state.profile) ||
        !_sameProvisioning(observed.provisioning, state.provisioning) ||
        !_sameCleanup(observed.cleanup, state.cleanup)) {
      throw const WalletRepositoryConflict();
    }
    return profile;
  }

  Future<void> _requireExistingProfileSecrets(WalletProfile profile) async {
    if (!await _seedStore.hasWalletKey(
      walletIndex: profile.walletIndex,
      walletGeneration: profile.walletGeneration,
    )) {
      throw const WalletAuthenticationFailed('钱包硬件密钥不存在');
    }
    for (final account in profile.accounts) {
      if (!await _seedStore.hasAccountKey(
        walletIndex: profile.walletIndex,
        walletGeneration: profile.walletGeneration,
        secretOwner: account.secretOwner,
        accountId: account.accountId,
      )) {
        throw WalletInvariantViolation('现有账户私钥不存在：${account.accountId}');
      }
    }
  }

  Future<void> _requireUsableAnchor(WalletProfile profile) async {
    final anchor = profile.accountById(profile.masterAccountId)!;
    final child = await _seedStore.readAccountKey(
      walletIndex: profile.walletIndex,
      walletGeneration: profile.walletGeneration,
      secretOwner: anchor.secretOwner,
      accountId: profile.masterAccountId,
    );
    if (child == null) {
      throw const WalletAuthenticationFailed('钱包锚点私钥不存在');
    }
    try {
      final publicKey = NativeSr25519.publicKeyOf(child);
      if (citizenAccountIdFromBytes(publicKey) != profile.masterAccountId) {
        throw const WalletInvariantViolation('钱包锚点私钥与账户公钥不一致');
      }
    } finally {
      WalletMiniSecret.clear(child);
    }
  }

  Future<WalletProfile> _requireCurrentAccount(
    String accountId, {
    String? expectedWalletGeneration,
    String? expectedSecretOwner,
  }) async {
    final state = await _repository.load();
    _validateState(state);
    final profile = state.provisioning?.previousProfile ?? state.profile;
    final account = profile?.accountById(accountId);
    if (profile == null || account == null) {
      throw const WalletNotFound('未找到指定账户');
    }
    if ((expectedWalletGeneration != null &&
            profile.walletGeneration != expectedWalletGeneration) ||
        (expectedSecretOwner != null &&
            account.secretOwner != expectedSecretOwner)) {
      throw const WalletRepositoryConflict();
    }
    return profile;
  }

  String _validatedMnemonic(String mnemonic) {
    final normalized = mnemonic.trim();
    try {
      bip39.Mnemonic.fromSentence(normalized, bip39.Language.english);
    } on bip39.MnemonicException {
      throw const WalletAuthenticationFailed('助记词无效');
    }
    return normalized;
  }

  Future<_DerivedAccount> _deriveAccount(
    String mnemonic,
    String password,
    int index,
    String secretOwner,
  ) async => (await _deriveAccounts(
    mnemonic,
    password,
    <int>[index],
    <int, String>{index: secretOwner},
  )).single;

  Future<List<_DerivedAccount>> _deriveAccounts(
    String mnemonic,
    String password,
    List<int> indices,
    Map<int, String> secretOwners,
  ) async {
    final normalizedPassword = WalletPassword.parse(password);
    final seed = await WalletMiniSecret.fromMnemonic(
      mnemonic,
      password: normalizedPassword.value,
    );
    try {
      final createdAtMillis = _clock().millisecondsSinceEpoch;
      final result = <_DerivedAccount>[];
      try {
        for (final index in indices) {
          final chainCode = WalletMiniSecret.hardJunctionChainCode(index);
          try {
            final child = NativeSr25519.deriveHard(seed, chainCode);
            try {
              final publicKey = NativeSr25519.publicKeyOf(child);
              final accountId = citizenAccountIdFromBytes(publicKey);
              result.add(
                _DerivedAccount(
                  child: child,
                  account: WalletAccount(
                    index: index,
                    accountId: accountId,
                    secretOwner: secretOwners[index]!,
                    ss58Address: citizenSs58FromAccountId(accountId),
                    name: '账户$index',
                    createdAtMillis: createdAtMillis,
                  ),
                ),
              );
            } on Object {
              WalletMiniSecret.clear(child);
              rethrow;
            }
          } finally {
            WalletMiniSecret.clear(chainCode);
          }
        }
        return result;
      } on Object {
        for (final item in result) {
          item.dispose();
        }
        rethrow;
      }
    } finally {
      WalletMiniSecret.clear(seed);
    }
  }

  WalletProfile _profileFromAccount(
    WalletAccount account,
    WalletOrigin origin,
    String walletGeneration,
  ) => WalletProfile(
    walletIndex: walletIndex,
    walletGeneration: walletGeneration,
    masterAccountId: account.accountId,
    origin: origin,
    createdAtMillis: account.createdAtMillis,
    activeAccountId: account.accountId,
    accounts: List<WalletAccount>.unmodifiable(<WalletAccount>[account]),
  );

  void _validateState(WalletState state) {
    if (state.revision < 0) {
      throw const WalletInvariantViolation('钱包仓储 revision 不能为负数');
    }
    if (state.provisioning != null && state.cleanup != null) {
      throw const WalletInvariantViolation('钱包不能同时存在 provision 与 cleanup 计划');
    }

    final profile = state.profile;
    if (profile != null) _validateProfile(profile);

    final provisioning = state.provisioning;
    if (provisioning != null) {
      if (profile == null ||
          provisioning.walletIndex != walletIndex ||
          provisioning.walletGeneration != profile.walletGeneration ||
          !_ownerPattern.hasMatch(provisioning.operationId) ||
          provisioning.secretRefs.isEmpty) {
        throw const WalletInvariantViolation('钱包 provision 计划结构无效');
      }
      _validateSecretRefs(
        provisioning.secretRefs,
        provisioning.walletGeneration,
      );
      final previous = provisioning.previousProfile;
      if (previous == null) {
        if (!provisioning.deleteWalletKeyOnRollback ||
            !_sameRefSets(
              provisioning.secretRefs,
              profile.accounts.map((account) => _secretRef(profile, account)),
            )) {
          throw const WalletInvariantViolation('新钱包 provision 计划不完整');
        }
      } else {
        _validateProfile(previous);
        if (provisioning.deleteWalletKeyOnRollback ||
            previous.walletIndex != profile.walletIndex ||
            previous.walletGeneration != profile.walletGeneration ||
            !_profileIsExactSubset(previous, profile)) {
          throw const WalletInvariantViolation('追加账户 provision 前态无效');
        }
        final previousOwners = previous.accounts
            .map((account) => account.secretOwner)
            .toSet();
        final addedRefs = profile.accounts
            .where((account) => !previousOwners.contains(account.secretOwner))
            .map((account) => _secretRef(profile, account));
        if (!_sameRefSets(provisioning.secretRefs, addedRefs)) {
          throw const WalletInvariantViolation('追加账户 provision 秘密集合无效');
        }
      }
    }

    final cleanup = state.cleanup;
    if (cleanup != null) {
      _validateCleanupPlan(cleanup);
      if (profile == null) {
        if (!cleanup.deleteWalletKey) {
          throw const WalletInvariantViolation('整钱包删除计划必须清理钱包硬件密钥');
        }
      } else if (!_cleanupCanCoexistWithProfile(cleanup, profile)) {
        throw const WalletInvariantViolation('钱包清理计划仍指向现存公开账户');
      }
    }

    if (state.cleanupQueue.length > maxCleanupQueueLength) {
      throw const WalletInvariantViolation('钱包 cleanup queue 超过上限');
    }
    final operationIds = <String>{};
    if (provisioning != null) operationIds.add(provisioning.operationId);
    if (cleanup != null && !operationIds.add(cleanup.operationId)) {
      throw const WalletInvariantViolation('钱包操作所有权标识重复');
    }
    final accepted = <WalletCleanupPlan>[];
    if (cleanup != null) accepted.add(cleanup);
    for (final queued in state.cleanupQueue) {
      _validateCleanupPlan(queued);
      if (!operationIds.add(queued.operationId)) {
        throw const WalletInvariantViolation('钱包操作所有权标识重复');
      }
      if (!_cleanupCanCoexistWithProfile(queued, profile)) {
        throw const WalletInvariantViolation('钱包 cleanup queue 仍指向现存公开事实');
      }
      if (accepted.any((entry) => _cleanupPlansOverlap(entry, queued))) {
        throw const WalletInvariantViolation('钱包 cleanup 计划包含重复的精确清理目标');
      }
      accepted.add(queued);
    }
  }

  void _validateCleanupPlan(WalletCleanupPlan cleanup) {
    if (cleanup.walletIndex != walletIndex ||
        !_ownerPattern.hasMatch(cleanup.operationId) ||
        cleanup.secretRefs.isEmpty) {
      throw const WalletInvariantViolation('钱包 cleanup 计划结构无效');
    }
    _validateSecretRefs(cleanup.secretRefs, cleanup.walletGeneration);
  }

  bool _cleanupCanCoexistWithProfile(
    WalletCleanupPlan cleanup,
    WalletProfile? profile,
  ) {
    if (profile == null) return true;
    if (cleanup.deleteWalletKey &&
        cleanup.walletGeneration == profile.walletGeneration) {
      return false;
    }
    return cleanup.secretRefs.every(
      (ref) => !profile.accounts.any(
        (account) =>
            ref.walletGeneration == profile.walletGeneration &&
            ref.secretOwner == account.secretOwner &&
            ref.accountId == account.accountId,
      ),
    );
  }

  bool _cleanupCanJoinState(WalletCleanupPlan cleanup, WalletState state) {
    if (state.cleanupQueue.length >= maxCleanupQueueLength ||
        !_cleanupCanCoexistWithProfile(cleanup, state.profile) ||
        state.provisioning?.operationId == cleanup.operationId ||
        state.cleanup?.operationId == cleanup.operationId ||
        state.cleanupQueue.any(
          (entry) =>
              entry.operationId == cleanup.operationId ||
              _cleanupPlansOverlap(entry, cleanup),
        )) {
      return false;
    }
    final active = state.cleanup;
    return active == null || !_cleanupPlansOverlap(active, cleanup);
  }

  bool _cleanupPlansOverlap(WalletCleanupPlan left, WalletCleanupPlan right) {
    if (_sameCleanup(left, right) || left.operationId == right.operationId) {
      return true;
    }
    if (left.deleteWalletKey &&
        right.deleteWalletKey &&
        left.walletGeneration == right.walletGeneration) {
      return true;
    }
    final leftRefs = left.secretRefs.map(_refKey).toSet();
    return right.secretRefs.any((ref) => leftRefs.contains(_refKey(ref)));
  }

  void _validateProfile(WalletProfile profile) {
    if (profile.walletIndex != walletIndex ||
        !_ownerPattern.hasMatch(profile.walletGeneration) ||
        profile.accounts.isEmpty) {
      throw const WalletInvariantViolation('热钱包公开资料结构无效');
    }
    final accountIds = <String>{};
    final indices = <int>{};
    final secretOwners = <String>{};
    WalletAccount? anchor;
    for (final account in profile.accounts) {
      if (account.index < 0 ||
          account.index > maxAccountIndex ||
          !accountIds.add(account.accountId) ||
          !indices.add(account.index) ||
          !_ownerPattern.hasMatch(account.secretOwner) ||
          account.secretOwner == profile.walletGeneration ||
          !secretOwners.add(account.secretOwner) ||
          !isCitizenAccountId(account.accountId) ||
          citizenSs58FromAccountId(account.accountId) != account.ss58Address) {
        throw const WalletInvariantViolation('钱包账户公开资料无效或重复');
      }
      if (account.index == 0) anchor = account;
    }
    if (anchor == null || anchor.accountId != profile.masterAccountId) {
      throw const WalletInvariantViolation('钱包缺少正确的账户0锚点');
    }
    if (!accountIds.contains(profile.activeAccountId)) {
      throw const WalletInvariantViolation('钱包 activeAccountId 不存在');
    }
  }

  void _validateSecretRefs(
    Iterable<WalletSecretRef> refs,
    String walletGeneration,
  ) {
    if (!_ownerPattern.hasMatch(walletGeneration)) {
      throw const WalletInvariantViolation('钱包秘密 generation 无效');
    }
    final keys = <String>{};
    for (final ref in refs) {
      if (ref.walletGeneration != walletGeneration ||
          !_ownerPattern.hasMatch(ref.secretOwner) ||
          !isCitizenAccountId(ref.accountId) ||
          !keys.add(_refKey(ref))) {
        throw const WalletInvariantViolation('钱包秘密引用无效或重复');
      }
    }
  }

  Future<void> _verifyProvisionedFactsAndSecrets(WalletState expected) async {
    final persisted = await _repository.load();
    _validateState(persisted);
    if (!_sameProfile(persisted.profile, expected.profile) ||
        !_sameProvisioning(persisted.provisioning, expected.provisioning) ||
        !_sameCleanup(persisted.cleanup, expected.cleanup)) {
      throw const WalletRepositoryConflict();
    }
    final provisioning = persisted.provisioning!;
    for (final ref in provisioning.secretRefs) {
      if (!await _seedStore.hasAccountKey(
        walletIndex: walletIndex,
        walletGeneration: ref.walletGeneration,
        secretOwner: ref.secretOwner,
        accountId: ref.accountId,
      )) {
        throw WalletInvariantViolation('账户私钥写入后复核失败：${ref.accountId}');
      }
    }
    if (!await _seedStore.hasWalletKey(
      walletIndex: walletIndex,
      walletGeneration: provisioning.walletGeneration,
    )) {
      throw const WalletInvariantViolation('钱包硬件密钥写入后复核失败');
    }
  }

  Future<WalletState> _completeProvisioning(WalletState expected) async {
    final latest = await _repository.load();
    _validateState(latest);
    if (!_sameProfile(latest.profile, expected.profile) ||
        !_sameProvisioning(latest.provisioning, expected.provisioning) ||
        latest.cleanup != null) {
      throw const WalletRepositoryConflict();
    }
    return _commitFacts(
      expectedRevision: latest.revision,
      profile: latest.profile,
      provisioning: null,
      cleanup: null,
      cleanupQueue: latest.cleanupQueue,
    );
  }

  Future<void> _rollbackProvisioning({
    required WalletState committedState,
  }) async {
    final expectedPlan = committedState.provisioning;
    if (expectedPlan == null) throw const WalletRepositoryConflict();
    final expectedCleanup = _cleanupFromProvisioning(expectedPlan);
    final owned = await _acquireProvisioningCleanup(
      provisioning: expectedPlan,
      cleanup: expectedCleanup,
    );
    if (_sameCleanup(owned.cleanup, expectedCleanup)) {
      await _finishCleanup(owned);
    } else {
      await _finishQueuedCleanup(expectedCleanup);
    }
  }

  Future<WalletState> _acquireProvisioningCleanup({
    required WalletProvisioningPlan provisioning,
    required WalletCleanupPlan cleanup,
  }) async {
    for (var attempt = 0; attempt < 32; attempt++) {
      final latest = await _repository.load();
      _validateState(latest);
      if (_sameCleanup(latest.cleanup, cleanup) ||
          _containsCleanup(latest.cleanupQueue, cleanup)) {
        return latest;
      }
      if (_sameProvisioning(latest.provisioning, provisioning) &&
          latest.cleanup == null) {
        try {
          return await _transitionProvisioningToCleanup(latest);
        } on WalletRepositoryConflict {
          continue;
        }
      }
      if (!_cleanupCanJoinState(cleanup, latest)) {
        throw const WalletRepositoryConflict();
      }
      try {
        return await _commitFacts(
          expectedRevision: latest.revision,
          profile: latest.profile,
          provisioning: latest.provisioning,
          cleanup: latest.cleanup,
          cleanupQueue: <WalletCleanupPlan>[...latest.cleanupQueue, cleanup],
        );
      } on WalletRepositoryConflict {
        // 持久状态前进后重新判断是否已取得 exact cleanup 所有权。
      }
    }
    throw const WalletRepositoryConflict();
  }

  Future<WalletState> _transitionProvisioningToCleanup(
    WalletState state,
  ) async {
    final provisioning = state.provisioning;
    if (provisioning == null || state.cleanup != null) {
      throw const WalletRepositoryConflict();
    }
    return _commitFacts(
      expectedRevision: state.revision,
      profile: provisioning.previousProfile,
      provisioning: null,
      cleanup: _cleanupFromProvisioning(provisioning),
      cleanupQueue: state.cleanupQueue,
    );
  }

  WalletCleanupPlan _cleanupFromProvisioning(
    WalletProvisioningPlan provisioning,
  ) => WalletCleanupPlan(
    operationId: provisioning.operationId,
    walletIndex: provisioning.walletIndex,
    walletGeneration: provisioning.walletGeneration,
    secretRefs: List<WalletSecretRef>.unmodifiable(provisioning.secretRefs),
    deleteWalletKey: provisioning.deleteWalletKeyOnRollback,
  );

  Future<List<String>> _cleanupSecrets({
    required Iterable<WalletSecretRef> secretRefs,
    required String walletGeneration,
    required bool deleteWalletKey,
  }) async {
    final failures = <String>[];
    for (final ref in secretRefs) {
      await _attemptCleanup(
        failures,
        '账户私钥(${ref.accountId}/${ref.secretOwner})',
        () => _seedStore.deleteAccountKey(
          walletIndex: walletIndex,
          walletGeneration: ref.walletGeneration,
          secretOwner: ref.secretOwner,
          accountId: ref.accountId,
        ),
      );
      await _attemptCleanup(
        failures,
        '账户私钥删除复核(${ref.accountId}/${ref.secretOwner})',
        () async {
          if (await _seedStore.hasAccountKey(
            walletIndex: walletIndex,
            walletGeneration: ref.walletGeneration,
            secretOwner: ref.secretOwner,
            accountId: ref.accountId,
          )) {
            throw StateError('密文仍存在');
          }
        },
      );
    }
    if (deleteWalletKey) {
      await _attemptCleanup(
        failures,
        '钱包硬件密钥($walletIndex/$walletGeneration)',
        () => _seedStore.deleteWalletKey(
          walletIndex: walletIndex,
          walletGeneration: walletGeneration,
        ),
      );
      await _attemptCleanup(
        failures,
        '钱包硬件密钥删除复核($walletIndex/$walletGeneration)',
        () async {
          if (await _seedStore.hasWalletKey(
            walletIndex: walletIndex,
            walletGeneration: walletGeneration,
          )) {
            throw StateError('硬件密钥仍存在');
          }
        },
      );
    }
    return failures;
  }

  Future<void> _attemptCleanup(
    List<String> failures,
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error) {
      failures.add('$label：$error');
    }
  }

  Future<WalletState> _commitFacts({
    required int expectedRevision,
    required WalletProfile? profile,
    required WalletProvisioningPlan? provisioning,
    required WalletCleanupPlan? cleanup,
    required List<WalletCleanupPlan> cleanupQueue,
  }) async {
    Object? commitError;
    StackTrace? commitStackTrace;
    try {
      await _repository.commit(
        expectedRevision: expectedRevision,
        profile: profile,
        provisioning: provisioning,
        cleanup: cleanup,
        cleanupQueue: cleanupQueue,
      );
    } on Object catch (error, stackTrace) {
      commitError = error;
      commitStackTrace = stackTrace;
    }

    Object? readError;
    StackTrace? readStackTrace;
    WalletState? observed;
    try {
      observed = await _repository.load();
      _validateState(observed);
    } on Object catch (error, stackTrace) {
      readError = error;
      readStackTrace = stackTrace;
    }
    if (observed != null &&
        observed.revision == expectedRevision + 1 &&
        _sameProfile(observed.profile, profile) &&
        _sameProvisioning(observed.provisioning, provisioning) &&
        _sameCleanup(observed.cleanup, cleanup) &&
        _sameCleanupQueue(observed.cleanupQueue, cleanupQueue)) {
      // commit 正常返回与“真实写入后抛错”都只能由持久事实
      // 精确回读确认。
      return observed;
    }

    if (commitError != null) {
      Error.throwWithStackTrace(commitError, commitStackTrace!);
    }
    if (readError != null) {
      Error.throwWithStackTrace(readError, readStackTrace!);
    }
    throw const WalletInvariantViolation('钱包公开事实写入后复核失败');
  }

  bool _sameCleanup(WalletCleanupPlan? left, WalletCleanupPlan? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    if (left.operationId != right.operationId ||
        left.walletIndex != right.walletIndex ||
        left.walletGeneration != right.walletGeneration ||
        left.deleteWalletKey != right.deleteWalletKey ||
        left.secretRefs.length != right.secretRefs.length) {
      return false;
    }
    for (var index = 0; index < left.secretRefs.length; index++) {
      if (!_sameSecretRef(left.secretRefs[index], right.secretRefs[index])) {
        return false;
      }
    }
    return true;
  }

  bool _sameCleanupQueue(
    List<WalletCleanupPlan> left,
    List<WalletCleanupPlan> right,
  ) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_sameCleanup(left[index], right[index])) return false;
    }
    return true;
  }

  bool _containsCleanup(
    Iterable<WalletCleanupPlan> plans,
    WalletCleanupPlan expected,
  ) => plans.any((plan) => _sameCleanup(plan, expected));

  bool _sameProvisioning(
    WalletProvisioningPlan? left,
    WalletProvisioningPlan? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    if (left.operationId != right.operationId ||
        left.walletIndex != right.walletIndex ||
        left.walletGeneration != right.walletGeneration ||
        left.deleteWalletKeyOnRollback != right.deleteWalletKeyOnRollback ||
        !_sameProfile(left.previousProfile, right.previousProfile) ||
        left.secretRefs.length != right.secretRefs.length) {
      return false;
    }
    for (var index = 0; index < left.secretRefs.length; index++) {
      if (!_sameSecretRef(left.secretRefs[index], right.secretRefs[index])) {
        return false;
      }
    }
    return true;
  }

  bool _sameProfile(WalletProfile? left, WalletProfile? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    if (left.walletIndex != right.walletIndex ||
        left.walletGeneration != right.walletGeneration ||
        left.masterAccountId != right.masterAccountId ||
        left.origin != right.origin ||
        left.createdAtMillis != right.createdAtMillis ||
        left.activeAccountId != right.activeAccountId ||
        left.accounts.length != right.accounts.length) {
      return false;
    }
    for (var index = 0; index < left.accounts.length; index++) {
      final leftAccount = left.accounts[index];
      final rightAccount = right.accounts[index];
      if (leftAccount.index != rightAccount.index ||
          leftAccount.accountId != rightAccount.accountId ||
          leftAccount.secretOwner != rightAccount.secretOwner ||
          leftAccount.ss58Address != rightAccount.ss58Address ||
          leftAccount.name != rightAccount.name ||
          leftAccount.createdAtMillis != rightAccount.createdAtMillis) {
        return false;
      }
    }
    return true;
  }

  bool _sameSecretRef(WalletSecretRef left, WalletSecretRef right) =>
      left.walletGeneration == right.walletGeneration &&
      left.secretOwner == right.secretOwner &&
      left.accountId == right.accountId;

  bool _sameRefSets(
    Iterable<WalletSecretRef> left,
    Iterable<WalletSecretRef> right,
  ) {
    final leftKeys = left.map(_refKey).toSet();
    final rightKeys = right.map(_refKey).toSet();
    return leftKeys.length == rightKeys.length &&
        leftKeys.containsAll(rightKeys);
  }

  String _refKey(WalletSecretRef ref) =>
      '${ref.walletGeneration}:${ref.secretOwner}:${ref.accountId}';

  WalletSecretRef _secretRef(WalletProfile profile, WalletAccount account) =>
      WalletSecretRef(
        walletGeneration: profile.walletGeneration,
        secretOwner: account.secretOwner,
        accountId: account.accountId,
      );

  WalletProvisioningPlan _newProvisioning({
    required String operationId,
    required WalletProfile targetProfile,
    required WalletProfile? previousProfile,
    required Iterable<WalletAccount> accounts,
    required bool deleteWalletKeyOnRollback,
  }) => WalletProvisioningPlan(
    operationId: operationId,
    walletIndex: targetProfile.walletIndex,
    walletGeneration: targetProfile.walletGeneration,
    previousProfile: previousProfile,
    secretRefs: List<WalletSecretRef>.unmodifiable(
      accounts.map((account) => _secretRef(targetProfile, account)),
    ),
    deleteWalletKeyOnRollback: deleteWalletKeyOnRollback,
  );

  Set<String> _profileOwners(WalletProfile profile) => <String>{
    profile.walletGeneration,
    ...profile.accounts.map((account) => account.secretOwner),
  };

  bool _profileIsExactSubset(WalletProfile previous, WalletProfile target) {
    if (previous.walletIndex != target.walletIndex ||
        previous.walletGeneration != target.walletGeneration ||
        previous.masterAccountId != target.masterAccountId ||
        previous.origin != target.origin ||
        previous.createdAtMillis != target.createdAtMillis ||
        previous.activeAccountId != target.activeAccountId ||
        previous.accounts.length >= target.accounts.length) {
      return false;
    }
    for (var index = 0; index < previous.accounts.length; index++) {
      final left = previous.accounts[index];
      final right = target.accounts[index];
      if (left.index != right.index ||
          left.accountId != right.accountId ||
          left.secretOwner != right.secretOwner ||
          left.ss58Address != right.ss58Address ||
          left.name != right.name ||
          left.createdAtMillis != right.createdAtMillis) {
        return false;
      }
    }
    return true;
  }

  String _mintOwner({Set<String> forbidden = const <String>{}}) {
    for (var attempt = 0; attempt < 64; attempt++) {
      final candidate = _newSecureOwnerId();
      if (_ownerPattern.hasMatch(candidate) && !forbidden.contains(candidate)) {
        return candidate;
      }
    }
    throw const WalletInvariantViolation('无法生成不可复用的钱包所有权标识');
  }

  static String _newSecureOwnerId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _exclusiveOperationTail;
    _exclusiveOperationTail = () async {
      try {
        await previous;
      } on Object {
        // 先前失败不能永久污染全实例签名与变更队列。
      }
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }
}

final class _DerivedAccount {
  _DerivedAccount({required this.child, required this.account});

  final Uint8List child;
  final WalletAccount account;

  void dispose() => WalletMiniSecret.clear(child);
}
