import 'dart:async';
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

  final WalletRepository _repository;
  final SecureSeedStore _seedStore;
  final DateTime Function() _clock;
  Future<void> _mutationTail = Future<void>.value();

  Future<WalletProfile?> get profile async {
    final state = await _repository.load();
    _validateState(state);
    return state.profile;
  }

  Future<WalletCreationResult> create({
    int wordCount = 12,
    String password = '',
  }) => _serialize(() async {
    if (wordCount != 12 && wordCount != 24) {
      throw ArgumentError.value(wordCount, 'wordCount', '只支持 12 或 24 个助记词');
    }
    await _requireSecureDevice();
    var state = await _reconcileCleanup();
    if (state.profile != null) throw const WalletAlreadyExists();
    final mnemonic = bip39.Mnemonic.generate(
      bip39.Language.english,
      length: wordCount == 24
          ? bip39.MnemonicLength.words24
          : bip39.MnemonicLength.words12,
    ).sentence;
    final derived = await _deriveAccount(mnemonic, password, 0);
    try {
      final profile = _profileFromAccount(
        derived.account,
        WalletOrigin.created,
      );
      try {
        await _seedStore.putAccountKey(
          walletIndex: walletIndex,
          accountId: derived.account.accountId,
          childMiniSecret: derived.child,
        );
        state = await _repository.commit(
          expectedRevision: state.revision,
          profile: profile,
          cleanup: null,
        );
      } on Object {
        await _rollbackCreatedKeys(<String>[derived.account.accountId]);
        rethrow;
      }
      return WalletCreationResult(profile: state.profile!, mnemonic: mnemonic);
    } finally {
      derived.dispose();
    }
  });

  Future<WalletProfile> importWallet(String mnemonic, {String password = ''}) =>
      _serialize(() async {
        await _requireSecureDevice();
        var state = await _reconcileCleanup();
        if (state.profile != null) throw const WalletAlreadyExists();
        final normalized = _validatedMnemonic(mnemonic);
        final derived = await _deriveAccount(normalized, password, 0);
        try {
          final profile = _profileFromAccount(
            derived.account,
            WalletOrigin.imported,
          );
          try {
            await _seedStore.putAccountKey(
              walletIndex: walletIndex,
              accountId: derived.account.accountId,
              childMiniSecret: derived.child,
            );
            state = await _repository.commit(
              expectedRevision: state.revision,
              profile: profile,
              cleanup: null,
            );
          } on Object {
            await _rollbackCreatedKeys(<String>[derived.account.accountId]);
            rethrow;
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
    var state = await _reconcileCleanup();
    final profile = state.profile;
    if (profile == null) throw const WalletNotFound();
    final normalized = _validatedMnemonic(mnemonic);
    final owner = await _deriveAccount(normalized, password, 0);
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
    final derived = <_DerivedAccount>[];
    final storedIds = <String>[];
    try {
      derived.addAll(await _deriveAccounts(normalized, password, sorted));
      try {
        for (final item in derived) {
          await _seedStore.putAccountKey(
            walletIndex: walletIndex,
            accountId: item.account.accountId,
            childMiniSecret: item.child,
          );
          storedIds.add(item.account.accountId);
        }
        final added = derived
            .map((entry) => entry.account)
            .toList(growable: false);
        state = await _repository.commit(
          expectedRevision: state.revision,
          profile: profile.copyWith(
            accounts: <WalletAccount>[...profile.accounts, ...added],
          ),
          cleanup: null,
        );
        return List<WalletAccount>.unmodifiable(added);
      } on Object {
        await _rollbackCreatedKeys(storedIds, deleteWalletKey: false);
        rethrow;
      }
    } finally {
      for (final item in derived) {
        item.dispose();
      }
    }
  });

  Future<void> setActiveAccount(String accountId) => _serialize(() async {
    final state = await _reconcileCleanup();
    final profile = state.profile;
    if (profile == null) throw const WalletNotFound();
    if (profile.accountById(accountId) == null) {
      throw const WalletNotFound('未找到指定账户');
    }
    await _repository.commit(
      expectedRevision: state.revision,
      profile: profile.copyWith(activeAccountId: accountId),
      cleanup: null,
    );
  });

  /// 用指定账户在本机签名任意协议载荷；TUYU v1 等上层协议可以复用此入口。
  Future<Uint8List> sign(String accountId, Uint8List payload) async {
    final state = await _repository.load();
    _validateState(state);
    final profile = state.profile;
    final account = profile?.accountById(accountId);
    if (profile == null || account == null) {
      throw const WalletNotFound('未找到指定账户');
    }
    final child = await _seedStore.readAccountKey(
      walletIndex: profile.walletIndex,
      accountId: accountId,
    );
    if (child == null) throw const WalletAuthenticationFailed('账户私钥不存在');
    try {
      final publicKey = NativeSr25519.publicKeyOf(child);
      if (citizenAccountIdFromBytes(publicKey) != accountId) {
        throw const WalletInvariantViolation('本地私钥与账户公钥不一致');
      }
      return NativeSr25519.sign(child, payload);
    } finally {
      WalletMiniSecret.clear(child);
    }
  }

  Future<void> deleteAccount(String accountId) => _serialize(() async {
    var state = await _reconcileCleanup();
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
      walletIndex: profile.walletIndex,
      accountIds: <String>[accountId],
      deleteWalletKey: false,
    );
    state = await _repository.commit(
      expectedRevision: state.revision,
      profile: profile.copyWith(
        activeAccountId: nextActive,
        accounts: remaining,
      ),
      cleanup: cleanup,
    );
    await _finishCleanup(state);
  });

  Future<void> deleteWallet() => _serialize(() async {
    final state = await _reconcileCleanup();
    final profile = state.profile;
    if (profile == null) throw const WalletNotFound();
    await _deleteWalletState(state, profile);
  });

  Future<void> reconcileCleanup() => _serialize(() async {
    await _reconcileCleanup();
  });

  Future<void> _deleteWalletState(
    WalletState state,
    WalletProfile profile,
  ) async {
    final cleanup = WalletCleanupPlan(
      walletIndex: profile.walletIndex,
      accountIds: profile.accounts
          .map((entry) => entry.accountId)
          .toList(growable: false),
      deleteWalletKey: true,
    );
    final committed = await _repository.commit(
      expectedRevision: state.revision,
      profile: null,
      cleanup: cleanup,
    );
    await _finishCleanup(committed);
  }

  Future<WalletState> _reconcileCleanup() async {
    final state = await _repository.load();
    _validateState(state);
    if (state.cleanup == null) return state;
    return _finishCleanup(state);
  }

  Future<WalletState> _finishCleanup(WalletState state) async {
    final cleanup = state.cleanup;
    if (cleanup == null) return state;
    for (final accountId in cleanup.accountIds) {
      await _seedStore.deleteAccountKey(
        walletIndex: cleanup.walletIndex,
        accountId: accountId,
      );
    }
    if (cleanup.deleteWalletKey) {
      await _seedStore.deleteWalletKey(walletIndex: cleanup.walletIndex);
    }
    final committed = await _repository.commit(
      expectedRevision: state.revision,
      profile: state.profile,
      cleanup: null,
    );
    _validateState(committed);
    return committed;
  }

  Future<void> _requireSecureDevice() async {
    switch (await _seedStore.authStatus()) {
      case SecureAuthStatus.available:
        return;
      case SecureAuthStatus.noDeviceLock:
        throw const NoDeviceCredential('设备未设置锁屏，禁止创建或导入钱包');
      case SecureAuthStatus.unsupported:
        throw const SecureStoreUnavailable('设备不支持 CitizenSDK 硬件金库');
    }
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
  ) async => (await _deriveAccounts(mnemonic, password, <int>[index])).single;

  Future<List<_DerivedAccount>> _deriveAccounts(
    String mnemonic,
    String password,
    List<int> indices,
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
  ) => WalletProfile(
    walletIndex: walletIndex,
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
    final cleanup = state.cleanup;
    if (cleanup != null && cleanup.walletIndex != walletIndex) {
      throw const WalletInvariantViolation('钱包清理计划的 walletIndex 无效');
    }
    final profile = state.profile;
    if (profile == null) return;
    if (profile.walletIndex != walletIndex || profile.accounts.isEmpty) {
      throw const WalletInvariantViolation('热钱包公开资料结构无效');
    }
    final accountIds = <String>{};
    final indices = <int>{};
    WalletAccount? anchor;
    for (final account in profile.accounts) {
      if (account.index < 0 ||
          account.index > maxAccountIndex ||
          !accountIds.add(account.accountId) ||
          !indices.add(account.index) ||
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

  Future<void> _rollbackCreatedKeys(
    List<String> accountIds, {
    bool deleteWalletKey = true,
  }) async {
    for (final accountId in accountIds) {
      await _seedStore.deleteAccountKey(
        walletIndex: walletIndex,
        accountId: accountId,
      );
    }
    if (deleteWalletKey) {
      await _seedStore.deleteWalletKey(walletIndex: walletIndex);
    }
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final class _DerivedAccount {
  _DerivedAccount({required this.child, required this.account});

  final Uint8List child;
  final WalletAccount account;

  void dispose() => WalletMiniSecret.clear(child);
}
