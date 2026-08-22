import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/qr/qr_protocols.dart';
import 'package:citizenapp/signer/qr_signer.dart';
import 'package:citizenapp/signer/signing.dart';
import 'package:citizenapp/wallet/core/native_sr25519.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';

/// “我的钱包”中一个可成为默认账户的统一公开视图。
///
/// 热钱包账户来自 [AccountEntity]，冷钱包账户来自 [WalletProfileEntity]；两者以
/// `account_id` 合并到同一个顺序。默认账户只由列表第一项决定，不另存影子字段。
class DefaultAccount {
  const DefaultAccount({
    required this.accountId,
    required this.ss58Address,
    required this.accountName,
    required this.signMode,
    required this.walletIndex,
    this.masterId,
    this.accountIndex,
  });

  final String accountId;
  final String ss58Address;
  final String accountName;
  final SignMode signMode;
  final int walletIndex;
  final String? masterId;
  final int? accountIndex;

  bool get isHotAccount => signMode == SignMode.hot;
  bool get isColdAccount => signMode == SignMode.cold;
}

/// 一次默认账户切换的不可变授权快照。
///
/// [beforeAccountIds] 用于提交前防并发覆盖；[orderedAccountIds] 是签名覆盖的完整目标
/// 顺序。两者都只含本机账户，不含 CID 或 binding revision。
class DefaultAccountSwitchAuthorization {
  const DefaultAccountSwitchAuthorization({
    required this.currentDefaultAccount,
    required this.beforeAccounts,
    required this.beforeAccountIds,
    required this.orderedAccountIds,
    required this.payload,
    required this.signingMessage,
    required this.requestId,
    required this.issuedAt,
    required this.expiresAt,
  });

  final DefaultAccount currentDefaultAccount;
  final List<DefaultAccount> beforeAccounts;
  final List<String> beforeAccountIds;
  final List<String> orderedAccountIds;
  final Uint8List payload;
  final Uint8List signingMessage;
  final String requestId;
  final int issuedAt;
  final int expiresAt;
}

/// 默认账户唯一服务。
///
/// 这里只管理本机账户顺序和原默认账户控制证明。它不读取 CID、不调用 Worker、不提交
/// Extrinsic，也不得调用任何占号或换绑入口。
abstract interface class DefaultAccountReader {
  Future<DefaultAccount?> getDefaultAccount();
}

class DefaultAccountService implements DefaultAccountReader {
  DefaultAccountService({WalletManager? walletManager})
      : _walletManager = walletManager ?? WalletManager();

  static const int authorizationTtlSeconds = 90;
  static const int maxOrderedAccounts = 256;

  final WalletManager _walletManager;

  /// 仅供真实 Isar 并发回归把竞争写精确停在读取与 CAS 之间。
  @visibleForTesting
  static Future<void> Function()? debugBeforeOrderCommit;

  /// 返回完整热、冷账户顺序；缺失的新账户稳定追加到末尾，失效账户从顺序中清除。
  ///
  /// 该收敛只修复本机顺序索引，不删除钱包、账户、密钥或任何 CID 用户数据。
  Future<List<DefaultAccount>> getAccounts() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final facts = await _loadFacts();
      final byId = <String, DefaultAccount>{
        for (final account in facts.accounts) account.accountId: account,
      };
      final orderedIds = _canonicalOrder(
        stored: facts.storedOrder,
        deterministic: facts.accounts.map((account) => account.accountId),
      );
      if (!_sameOrder(orderedIds, facts.storedOrder)) {
        try {
          await WalletManager.runWalletFactsMutation(
            () => _repairCanonicalOrderCas(
              beforeAccounts: facts.accounts,
              beforeStoredOrder: facts.storedOrder,
              targetOrder: orderedIds,
            ),
          );
        } on WalletAuthException {
          continue;
        }
      }
      return orderedIds.map((id) => byId[id]!).toList(growable: false);
    }
    throw const WalletAuthException('账户列表持续变化，请重试');
  }

  @override
  Future<DefaultAccount?> getDefaultAccount() async {
    final accounts = await getAccounts();
    return accounts.isEmpty ? null : accounts.first;
  }

  /// 第一项不变的普通排序直接持久化；第一项变化必须走签名授权入口。
  Future<void> persistOrderWithoutDefaultChange(
    List<String> orderedAccountIds,
  ) async {
    final current = await getAccounts();
    final currentIds = current.map((account) => account.accountId).toList();
    _validatePermutation(currentIds, orderedAccountIds);
    if (currentIds.isNotEmpty && currentIds.first != orderedAccountIds.first) {
      throw const WalletAuthException('默认账户变化必须由原默认账户签名');
    }
    await debugBeforeOrderCommit?.call();
    await WalletManager.runWalletFactsMutation(
      () => _commitOrderCas(
        beforeAccounts: current,
        beforeAccountIds: currentIds,
        orderedAccountIds: orderedAccountIds,
        requireSameDefault: true,
      ),
    );
    WalletManager.notifyDefaultAccountChanged();
  }

  /// 构造第一项变化的完整签名授权。签名者固定为变化前的原默认账户。
  Future<DefaultAccountSwitchAuthorization> prepareSwitch({
    required Uint8List genesisHash,
    required List<String> orderedAccountIds,
    int? nowEpochSeconds,
  }) async {
    if (genesisHash.length != 32) {
      throw ArgumentError('genesis_hash 必须为 32 字节');
    }
    final current = await getAccounts();
    final before = current.map((account) => account.accountId).toList();
    _validatePermutation(before, orderedAccountIds);
    if (before.isEmpty || before.first == orderedAccountIds.first) {
      throw const WalletAuthException('默认账户没有发生变化');
    }
    final issuedAt = nowEpochSeconds ??
        DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final expiresAt = issuedAt + authorizationTtlSeconds;
    final nonce = _secureRandomBytes(16);
    final payload = encodeSwitchPayload(
      genesisHash: genesisHash,
      currentDefaultAccountId: before.first,
      orderedAccountIds: orderedAccountIds,
      expiresAt: expiresAt,
      nonce: nonce,
    );
    nonce.fillRange(0, nonce.length, 0);
    return DefaultAccountSwitchAuthorization(
      currentDefaultAccount: current.first,
      beforeAccounts: List<DefaultAccount>.unmodifiable(current),
      beforeAccountIds: List<String>.unmodifiable(before),
      orderedAccountIds: List<String>.unmodifiable(orderedAccountIds),
      payload: payload,
      signingMessage: signingMessage(
        opTag: kOpSignSwitchDefaultAccount,
        scalePayload: payload,
      ),
      requestId: QrSigner.generateRequestId(prefix: 'da_'),
      issuedAt: issuedAt,
      expiresAt: expiresAt,
    );
  }

  /// 原默认账户是热账户时，在本机强生物识别解锁后签名、立即验签并原子提交。
  Future<void> authorizeHotAndPersist(
    DefaultAccountSwitchAuthorization authorization,
  ) async {
    final current = authorization.currentDefaultAccount;
    if (!current.isHotAccount) {
      throw const WalletAuthException('原默认账户是冷钱包，请使用公民钱包扫码签名');
    }
    final signature = await _walletManager.signForAccountId(
      current.accountId,
      authorization.signingMessage,
    );
    try {
      if (!NativeSr25519.verify(
        _accountIdBytes(current.accountId),
        signature,
        authorization.signingMessage,
      )) {
        throw const WalletAuthException('默认账户切换签名验证失败');
      }
      await _commit(authorization);
    } finally {
      signature.fillRange(0, signature.length, 0);
    }
  }

  /// 原默认账户是冷账户时构造唯一 QR_V1 签名请求。
  SignRequestEnvelope buildColdRequest(
    DefaultAccountSwitchAuthorization authorization,
  ) {
    final current = authorization.currentDefaultAccount;
    if (!current.isColdAccount) {
      throw const WalletAuthException('原默认账户不是冷钱包');
    }
    return QrSigner().buildRequest(
      requestId: authorization.requestId,
      signerPublicKey: current.accountId,
      payloadHex: _lowerHex(authorization.payload),
      action: QrActions.switchDefaultAccount,
      nowEpochSeconds: authorization.issuedAt,
      ttlSeconds: authorization.expiresAt - authorization.issuedAt,
    );
  }

  /// 接收已经与本地 session 匹配的冷签响应，再独立验一次签名后提交。
  Future<void> authorizeColdAndPersist(
    DefaultAccountSwitchAuthorization authorization,
    SignResponseEnvelope response,
  ) async {
    final current = authorization.currentDefaultAccount;
    if (!current.isColdAccount ||
        response.id != authorization.requestId ||
        response.body.signerPublicKeyHex != current.accountId ||
        !QrSigner.verifySr25519Signature(
          signerPublicKeyHex: current.accountId,
          signatureHex: response.body.signatureHex,
          message: authorization.signingMessage,
        )) {
      throw const WalletAuthException('冷钱包默认账户切换签名无效');
    }
    await _commit(authorization);
  }

  /// 只供真实 Isar 竞态测试跳过密码学输入；生产调用者必须走上述热/冷签名入口。
  @visibleForTesting
  Future<void> debugCommitAuthorization(
    DefaultAccountSwitchAuthorization authorization,
  ) =>
      _commit(authorization);

  Future<void> _commit(
    DefaultAccountSwitchAuthorization authorization,
  ) async {
    final now =
        DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    if (now >= authorization.expiresAt) {
      throw const WalletAuthException('默认账户切换授权已过期');
    }
    await debugBeforeOrderCommit?.call();
    await WalletManager.runWalletFactsMutation(
      () => _commitOrderCas(
        beforeAccounts: authorization.beforeAccounts,
        beforeAccountIds: authorization.beforeAccountIds,
        orderedAccountIds: authorization.orderedAccountIds,
        requireSameDefault: false,
      ),
    );
    WalletManager.notifyDefaultAccountChanged();
  }

  Future<({List<DefaultAccount> accounts, List<String> storedOrder})>
      _loadFacts() async {
    return WalletIsar.instance.read(_loadFactsInTxn);
  }

  Future<({List<DefaultAccount> accounts, List<String> storedOrder})>
      _loadFactsInTxn(Isar isar) async {
    final profiles =
        await isar.walletProfileEntitys.where().sortByWalletIndex().findAll();
    final accountRows = await isar.accountEntitys.where().findAll();
    final settings = await isar.walletSettingsEntitys.get(0);
    final rowsByMaster = <String, List<AccountEntity>>{};
    for (final row in accountRows) {
      rowsByMaster.putIfAbsent(row.masterId, () => <AccountEntity>[]).add(row);
    }
    final accounts = <DefaultAccount>[];
    final seen = <String>{};
    for (final profile in profiles) {
      if (SignMode.tryParse(profile.signMode) == SignMode.hot) {
        final rows = rowsByMaster[profile.masterId] ?? const <AccountEntity>[];
        rows.sort(
          (left, right) => left.accountIndex.compareTo(right.accountIndex),
        );
        for (final row in rows) {
          if (!_isValidAccount(row.accountId, row.ss58Address) ||
              !seen.add(row.accountId)) {
            continue;
          }
          accounts.add(
            DefaultAccount(
              accountId: row.accountId,
              ss58Address: row.ss58Address,
              accountName: row.accountName,
              signMode: SignMode.hot,
              walletIndex: profile.walletIndex,
              masterId: row.masterId,
              accountIndex: row.accountIndex,
            ),
          );
        }
      } else if (SignMode.tryParse(profile.signMode) == SignMode.cold &&
          _isValidAccount(profile.accountId, profile.ss58Address) &&
          seen.add(profile.accountId)) {
        accounts.add(
          DefaultAccount(
            accountId: profile.accountId,
            ss58Address: profile.ss58Address,
            accountName: profile.walletName,
            signMode: SignMode.cold,
            walletIndex: profile.walletIndex,
          ),
        );
      }
    }
    return (
      accounts: List<DefaultAccount>.unmodifiable(accounts),
      storedOrder: List<String>.unmodifiable(
        settings?.orderedAccountIds ?? const <String>[],
      ),
    );
  }

  Future<void> _repairCanonicalOrderCas({
    required List<DefaultAccount> beforeAccounts,
    required List<String> beforeStoredOrder,
    required List<String> targetOrder,
  }) async {
    await WalletIsar.instance.writeTxn((isar) async {
      final current = await _loadFactsInTxn(isar);
      if (!_sameAccounts(current.accounts, beforeAccounts) ||
          !_sameOrder(current.storedOrder, beforeStoredOrder)) {
        throw const WalletAuthException('账户列表已变化，请重试');
      }
      await _writeOrderInTxn(isar, targetOrder);
    });
  }

  Future<void> _commitOrderCas({
    required List<DefaultAccount> beforeAccounts,
    required List<String> beforeAccountIds,
    required List<String> orderedAccountIds,
    required bool requireSameDefault,
  }) async {
    await WalletIsar.instance.writeTxn((isar) async {
      final current = await _loadFactsInTxn(isar);
      final currentIds = _canonicalOrder(
        stored: current.storedOrder,
        deterministic: current.accounts.map((account) => account.accountId),
      );
      if (!_sameAccounts(current.accounts, beforeAccounts) ||
          !_sameOrder(currentIds, beforeAccountIds) ||
          !_sameOrder(current.storedOrder, beforeAccountIds)) {
        throw const WalletAuthException('账户列表已变化，请重新拖动并签名');
      }
      _validatePermutation(currentIds, orderedAccountIds);
      if (requireSameDefault &&
          currentIds.isNotEmpty &&
          currentIds.first != orderedAccountIds.first) {
        throw const WalletAuthException('默认账户变化必须由原默认账户签名');
      }
      await _writeOrderInTxn(isar, orderedAccountIds);
    });
  }

  Future<void> _writeOrderInTxn(
    Isar isar,
    Iterable<String> orderedAccountIds,
  ) async {
    final order = List<String>.unmodifiable(orderedAccountIds);
    final settings = await isar.walletSettingsEntitys.get(0) ??
        (WalletSettingsEntity()..id = 0);
    settings.orderedAccountIds = order;
    settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    await isar.walletSettingsEntitys.put(settings);
  }

  static List<String> _canonicalOrder({
    required Iterable<String> stored,
    required Iterable<String> deterministic,
  }) {
    final allowed = deterministic.toSet();
    final seen = <String>{};
    final result = <String>[];
    for (final id in stored) {
      if (allowed.contains(id) && seen.add(id)) result.add(id);
    }
    for (final id in deterministic) {
      if (seen.add(id)) result.add(id);
    }
    return result;
  }

  static void _validatePermutation(
    List<String> current,
    List<String> target,
  ) {
    if (current.isEmpty ||
        current.length != target.length ||
        target.length > maxOrderedAccounts ||
        target.toSet().length != target.length ||
        !current.toSet().containsAll(target)) {
      throw const WalletAuthException('目标账户顺序必须是当前全部账户的完整无重复排列');
    }
  }

  static bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static bool _sameAccounts(
    List<DefaultAccount> left,
    List<DefaultAccount> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.accountId != b.accountId ||
          a.ss58Address != b.ss58Address ||
          a.accountName != b.accountName ||
          a.signMode != b.signMode ||
          a.walletIndex != b.walletIndex ||
          a.masterId != b.masterId ||
          a.accountIndex != b.accountIndex) {
        return false;
      }
    }
    return true;
  }

  static bool _isValidAccount(String accountId, String ss58Address) {
    return isAccountIdText(accountId) &&
        ss58Address == ss58FromAccountIdText(accountId);
  }

  /// SCALE：`genesis_hash || current_default_account_id || Vec<AccountId>
  /// || expires_at(u64 LE) || nonce(16B)`。
  static Uint8List encodeSwitchPayload({
    required Uint8List genesisHash,
    required String currentDefaultAccountId,
    required List<String> orderedAccountIds,
    required int expiresAt,
    required Uint8List nonce,
  }) {
    if (genesisHash.length != 32 || nonce.length != 16) {
      throw ArgumentError('genesis_hash/nonce 长度无效');
    }
    if (orderedAccountIds.isEmpty ||
        orderedAccountIds.length > maxOrderedAccounts ||
        orderedAccountIds.toSet().length != orderedAccountIds.length ||
        orderedAccountIds.first == currentDefaultAccountId) {
      throw ArgumentError('默认账户切换顺序无效');
    }
    final bytes = <int>[
      ...genesisHash,
      ..._accountIdBytes(currentDefaultAccountId),
      ..._scaleCompact(orderedAccountIds.length),
      for (final accountId in orderedAccountIds) ..._accountIdBytes(accountId),
      for (var shift = 0; shift < 64; shift += 8) (expiresAt >> shift) & 0xff,
      ...nonce,
    ];
    return Uint8List.fromList(bytes);
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _accountIdBytes(String accountId) {
    if (!isAccountIdText(accountId)) {
      throw ArgumentError.value(accountId, 'accountId', 'AccountId 格式无效');
    }
    return Uint8List.fromList(List<int>.generate(
      32,
      (index) => int.parse(
        accountId.substring(2 + index * 2, 4 + index * 2),
        radix: 16,
      ),
    ));
  }

  static List<int> _scaleCompact(int value) {
    if (value < 1 << 6) return <int>[value << 2];
    if (value < 1 << 14) {
      final encoded = (value << 2) | 1;
      return <int>[encoded & 0xff, (encoded >> 8) & 0xff];
    }
    throw ArgumentError.value(value, 'value', '账户数量超出 SCALE compact 范围');
  }

  static String _lowerHex(List<int> bytes) {
    final buffer = StringBuffer('0x');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
