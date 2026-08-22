import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/my/membership/membership_revision.dart';
import 'package:citizenapp/my/myid/finalized_identity_resolver.dart';
import 'package:citizenapp/qr/pages/qr_sign_session_page.dart';
import 'package:citizenapp/qr/qr_protocols.dart';
import 'package:citizenapp/rpc/chain_rpc.dart' show TxPoolWatchCallback;
import 'package:citizenapp/rpc/pallet_registry.dart';
import 'package:citizenapp/rpc/subscription_rpc.dart';
import 'package:citizenapp/wallet/core/default_account_service.dart';
import 'package:citizenapp/wallet/core/device_subkey.dart' show hexToBytes;
import 'package:citizenapp/wallet/core/secure_seed_store.dart'
    show SecureSeedException;
import 'package:citizenapp/wallet/core/seed_sign_error.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/isar/wallet_isar.dart';

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 会员页持久化展示快照：只缓存低频变化的 finalized 订阅态与三档链上价格。
///
/// 套餐名称和权益不进入缓存，始终使用 App 内置静态定义；订阅或支付动作仍在提交前
/// 使用链上真值校验，展示缓存不构成授权真源。
class MembershipDisplaySnapshot {
  const MembershipDisplaySnapshot({
    required this.state,
    required this.prices,
    required this.subscriptionFetchedAtMs,
    required this.pricesFetchedAtMs,
    this.membershipConfirmed = true,
  });

  final SquareMembershipState state;
  final Map<String, int> prices;
  final int subscriptionFetchedAtMs;
  final int pricesFetchedAtMs;

  /// true 表示有效/无效已经由 finalized 链读取或 verify_on_deny 收敛；旧缓存没有
  /// 本字段时按 unknown 处理，普通 D1 否定不得伪装成“确认无会员”。
  final bool membershipConfirmed;

  MembershipDisplayDecision get decision {
    if (!membershipConfirmed) return MembershipDisplayDecision.unknown;
    return state.active
        ? MembershipDisplayDecision.activeConfirmed
        : MembershipDisplayDecision.inactiveConfirmed;
  }

  bool subscriptionIsFresh(int nowMs, Duration ttl) =>
      subscriptionFetchedAtMs > 0 &&
      nowMs >= subscriptionFetchedAtMs &&
      nowMs - subscriptionFetchedAtMs <= ttl.inMilliseconds;

  bool pricesAreFresh(int nowMs, Duration ttl) =>
      pricesFetchedAtMs > 0 &&
      nowMs >= pricesFetchedAtMs &&
      nowMs - pricesFetchedAtMs <= ttl.inMilliseconds;
}

/// 平台会员订阅编排：在「我的 → 会员」页订阅 / 取消平台会员（自由/民主/薪火）。
///
/// 用户签名订阅、取消和换档；首次扣款、真实公历到期时间与后续自动扣款由 runtime
/// 根据共识时间戳完成。CitizenApp 不提交续费或周期确认。
class SubscriptionService {
  SubscriptionService({
    SubscriptionRpc? rpc,
    WalletManager? walletManager,
    DefaultAccountReader? defaultAccountReader,
    SquareSessionProvider? sessionProvider,
    SquareApiClient? api,
  })  : _rpc = rpc ?? SubscriptionRpc(),
        _wallet = walletManager ?? WalletManager(),
        _defaultAccountReader = defaultAccountReader ??
            DefaultAccountService(walletManager: walletManager),
        _session = sessionProvider ?? SquareSessionProvider.instance,
        _api = api ?? SquareApiClient() {
    _walletAccountSigner = WalletAccountSigner(walletManager: _wallet);
  }

  final SubscriptionRpc _rpc;
  final WalletManager _wallet;
  final DefaultAccountReader _defaultAccountReader;
  final SquareSessionProvider _session;
  final SquareApiClient _api;
  late final WalletAccountSigner _walletAccountSigner;

  bool _mirrorSyncPending = false;

  /// 最近一次平台订阅动作已经 finalized，但 Worker 镜像仍等待确认。
  ///
  /// 该状态只供会员页显示同步提示；会员资格仍以 Worker 或 finalized 链读取为准。
  bool get mirrorSyncPending => _mirrorSyncPending;

  /// 会员页只以 finalized 链状态和同区块共识时间戳决定当前档位与权益。
  Future<FinalizedSubscriptionSnapshot> fetchFinalizedState(
      String cidNumber) async {
    // Cloudflare 只是 finalized 回执镜像；历史回执重试不得阻塞会员页链上真态读取。
    unawaited(_retryPendingMirrorsForCurrentSession());
    return _rpc.fetchSubscriptionSnapshot(subscriberCidNumber: cidNumber);
  }

  String _displaySnapshotKey(String cidNumber) =>
      'platform_membership_display_snapshot:$cidNumber';

  /// 读取当前账户上一次成功同步的展示快照；损坏缓存只忽略展示，读取路径不删除事实。
  Future<MembershipDisplaySnapshot?> readDisplaySnapshot(
      String cidNumber) async {
    final key = _displaySnapshotKey(cidNumber);
    final raw = await _readState(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final pricesRaw = decoded['prices'];
      final prices = <String, int>{};
      if (pricesRaw is Map<String, dynamic>) {
        for (final level in const ['freedom', 'democracy', 'spark']) {
          final value = pricesRaw[level];
          if (value is int && value >= 0) prices[level] = value;
        }
      }
      final membershipLevel = decoded['membership_level'];
      final subscriptionStatus = decoded['subscription_status'];
      return MembershipDisplaySnapshot(
        state: SquareMembershipState(
          active: decoded['active'] == true,
          paidUntil:
              decoded['paid_until'] is int ? decoded['paid_until'] as int : 0,
          membershipLevel: membershipLevel is String ? membershipLevel : null,
          subscriptionStatus:
              subscriptionStatus is String ? subscriptionStatus : null,
          subscriptionActive: decoded['subscription_active'] == true,
          lastChargedAt: decoded['last_charged_at'] is int
              ? decoded['last_charged_at'] as int
              : 0,
        ),
        prices: prices,
        subscriptionFetchedAtMs: decoded['subscription_fetched_at_ms'] is int
            ? decoded['subscription_fetched_at_ms'] as int
            : 0,
        pricesFetchedAtMs: decoded['prices_fetched_at_ms'] is int
            ? decoded['prices_fetched_at_ms'] as int
            : 0,
        membershipConfirmed: decoded['membership_confirmed'] == true,
      );
    } on FormatException {
      // 损坏展示快照不参与授权；读取路径保留事实供显式诊断。
      return null;
    }
  }

  /// 原子覆盖当前账户展示快照；调用方只在对应链读成功后推进该部分时间戳。
  Future<void> writeDisplaySnapshot(
    String cidNumber,
    MembershipDisplaySnapshot snapshot,
  ) async {
    await _writeState(
      _displaySnapshotKey(cidNumber),
      jsonEncode({
        'active': snapshot.state.active,
        'paid_until': snapshot.state.paidUntil,
        'membership_level': snapshot.state.membershipLevel,
        'subscription_status': snapshot.state.subscriptionStatus,
        'subscription_active': snapshot.state.subscriptionActive,
        'last_charged_at': snapshot.state.lastChargedAt,
        'prices': snapshot.prices,
        'subscription_fetched_at_ms': snapshot.subscriptionFetchedAtMs,
        'prices_fetched_at_ms': snapshot.pricesFetchedAtMs,
        'membership_confirmed': snapshot.membershipConfirmed,
      }),
    );
  }

  /// 订阅平台会员某档（level=freedom/democracy/spark）。
  Future<void> subscribe(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
    TxPoolWatchCallback? onWatchEvent,
  }) async {
    final identity = await _requireIdentity();
    final account = await _requireSigningAccount(identity.accountId);
    final cidNumber = identity.snapshot!.cidNumber;
    try {
      final result = await _rpc.subscribePlatform(
        fromSs58Address: identity.ss58Address,
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        level: level,
        expectedPriceFen: BigInt.from(expectedPriceFen),
        sign: (payload) => _walletAccountSigner.sign(
          context: context,
          accountId: identity.accountId,
          signMode: account.signMode,
          payload: payload,
          action: QrActions.chain(
            PalletRegistry.squarePostPallet,
            PalletRegistry.subscribeCall,
          ),
          requestPrefix: 'subscribe-',
        ),
        onWatchEvent: onWatchEvent,
      );
      await _confirm(
        subscriberCidNumber: cidNumber,
        signerAccountId: identity.accountId,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
        signedExtrinsicHex: result.signedExtrinsicHex,
        action: 'subscribe',
        membershipLevel: level,
      );
    } on SecureSeedException catch (e) {
      throw SubscriptionException(seedSignErrorMessage(e));
    } on WalletAuthException catch (e) {
      throw SubscriptionException(e.message);
    } on Exception catch (e) {
      throw SubscriptionException('订阅失败：$e');
    }
  }

  /// 取消平台会员（撤销按月扣款授权）。
  Future<void> cancel({
    BuildContext? context,
    TxPoolWatchCallback? onWatchEvent,
  }) async {
    final identity = await _requireIdentity();
    final account = await _requireSigningAccount(identity.accountId);
    final cidNumber = identity.snapshot!.cidNumber;
    try {
      final result = await _rpc.cancelPlatform(
        fromSs58Address: identity.ss58Address,
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        sign: (payload) => _walletAccountSigner.sign(
          context: context,
          accountId: identity.accountId,
          signMode: account.signMode,
          payload: payload,
          action: QrActions.chain(
            PalletRegistry.squarePostPallet,
            PalletRegistry.cancelSubscriptionCall,
          ),
          requestPrefix: 'cancel-sub-',
        ),
        onWatchEvent: onWatchEvent,
      );
      await _confirm(
        subscriberCidNumber: cidNumber,
        signerAccountId: identity.accountId,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
        signedExtrinsicHex: result.signedExtrinsicHex,
        action: 'cancel',
      );
    } on SecureSeedException catch (e) {
      throw SubscriptionException(seedSignErrorMessage(e));
    } on WalletAuthException catch (e) {
      throw SubscriptionException(e.message);
    } on Exception catch (e) {
      throw SubscriptionException('取消失败：$e');
    }
  }

  /// 更换平台会员档。当前已付周期内仅登记待切换档位，具体生效时间由 runtime 决定。
  Future<void> changePlan(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
    TxPoolWatchCallback? onWatchEvent,
  }) async {
    final identity = await _requireIdentity();
    final account = await _requireSigningAccount(identity.accountId);
    final cidNumber = identity.snapshot!.cidNumber;
    try {
      final result = await _rpc.changePlatformPlan(
        fromSs58Address: identity.ss58Address,
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        level: level,
        expectedPriceFen: BigInt.from(expectedPriceFen),
        sign: (payload) => _walletAccountSigner.sign(
          context: context,
          accountId: identity.accountId,
          signMode: account.signMode,
          payload: payload,
          action: QrActions.chain(
            PalletRegistry.squarePostPallet,
            PalletRegistry.changeSubscriptionPlanCall,
          ),
          requestPrefix: 'change-sub-',
        ),
        onWatchEvent: onWatchEvent,
      );
      await _confirm(
        subscriberCidNumber: cidNumber,
        signerAccountId: identity.accountId,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
        signedExtrinsicHex: result.signedExtrinsicHex,
        action: 'change',
        membershipLevel: level,
      );
    } on SecureSeedException catch (e) {
      throw SubscriptionException(seedSignErrorMessage(e));
    } on WalletAuthException catch (e) {
      throw SubscriptionException(e.message);
    } on Exception catch (e) {
      throw SubscriptionException('更换订阅失败：$e');
    }
  }

  Future<DefaultAccount> _requireSigningAccount(String accountId) async {
    final account = await _defaultAccountReader.getDefaultAccount();
    if (account == null || account.accountId != accountId) {
      throw const SubscriptionException('当前身份与默认钱包账户不一致，已拒绝签名');
    }
    return account;
  }

  /// 当前默认账户经 finalized 闭环验证后，才可成为链上订阅交易签名者。
  /// 本地待提交证明归属永久 CID；账户只记录当时的签名与付款事实。
  Future<FinalizedIdentity> _requireIdentity() async {
    final identity = await FinalizedIdentityResolver.instance.resolve();
    if (identity == null || !identity.isRegistered) {
      throw const SubscriptionException('请先注册并绑定公民 CID');
    }
    return identity;
  }

  String _pendingKey(String subscriberCidNumber) =>
      'platform_subscription_mirror_pending_by_cid:$subscriberCidNumber';

  /// finalized 回执按永久 CID 落本地，再提交 Cloudflare；当时的签名账户只作为
  /// 交易事实写入证明。HTTP 失败只重试证明，不再签名。
  Future<void> _confirm({
    required String subscriberCidNumber,
    required String signerAccountId,
    required String txHash,
    required String blockHashHex,
    required String signedExtrinsicHex,
    required String action,
    String? membershipLevel,
  }) async {
    final proof = <String, dynamic>{
      'tx_hash': txHash,
      'block_hash': blockHashHex,
      'signed_extrinsic_hex': signedExtrinsicHex,
      'action': action,
      'signer_account_id': signerAccountId,
      if (membershipLevel != null) 'membership_level': membershipLevel,
    };
    try {
      await _storeLocalProof(subscriberCidNumber, proof);
    } on Exception {
      // 链上已 finalized；本地缓存异常不能让用户重新签名。
    }
    _mirrorSyncPending = !await _syncProof(
      subscriberCidNumber: subscriberCidNumber,
      proof: proof,
    );
  }

  Future<void> _retryPendingMirrorsForCurrentSession() async {
    try {
      final session = await _session.ensureSession();
      if (session == null) return;
      final subscriberCidNumber = session.cidNumber;
      final pending = await _readList(_pendingKey(subscriberCidNumber));
      for (final proof in List<Map<String, dynamic>>.from(pending)) {
        await _syncProof(
          subscriberCidNumber: subscriberCidNumber,
          proof: proof,
        );
      }
      _mirrorSyncPending =
          (await _readList(_pendingKey(subscriberCidNumber))).isNotEmpty;
    } on Exception {
      // 保留未完成证明；链上订阅与自动续费不依赖 Cloudflare。
    }
  }

  /// 用已 finalized 的交易证明推进 Worker 镜像。确认接口失败时只追加一次授权点查：
  /// Worker 可按当前 Session CID 从 finalized 链重建漏写镜像，不产生第二次签名。
  Future<bool> _syncProof({
    required String subscriberCidNumber,
    required Map<String, dynamic> proof,
  }) async {
    final txHash = proof['tx_hash'];
    final blockHashHex = proof['block_hash'];
    final signedExtrinsicHex = proof['signed_extrinsic_hex'];
    final action = proof['action'];
    final membershipLevel = proof['membership_level'];
    if (txHash is! String ||
        blockHashHex is! String ||
        signedExtrinsicHex is! String ||
        action is! String ||
        (membershipLevel != null && membershipLevel is! String)) {
      return false;
    }

    final SquareSession? session;
    try {
      session = await _session.ensureSession();
    } on Exception {
      return false;
    }
    if (session == null ||
        session.cidNumber.trim() != subscriberCidNumber.trim()) {
      return false;
    }

    var confirmed = false;
    try {
      await _api.confirmPlatformSubscription(
        session: session,
        txHash: txHash,
        blockHashHex: blockHashHex,
        signedExtrinsicHex: signedExtrinsicHex,
        action: action,
        membershipLevel: membershipLevel as String?,
      );
      confirmed = true;
    } on Exception {
      try {
        final state = await _api.fetchMembership(
          session,
          verifyOnDeny: true,
        );
        confirmed = _proofMatchesMembership(
          action: action,
          membershipLevel: membershipLevel as String?,
          state: state,
        );
      } on Exception {
        confirmed = false;
      }
    }
    if (!confirmed) return false;

    try {
      await _removePendingProof(subscriberCidNumber, txHash);
    } on Exception {
      // Worker 镜像已经确认；本地删除失败只会导致后续幂等重试，不能撤销成功事实。
    }
    MembershipRevision.instance.notifyConfirmed(subscriberCidNumber);
    return true;
  }

  bool _proofMatchesMembership({
    required String action,
    required String? membershipLevel,
    required SquareMembershipState state,
  }) {
    if (action == 'cancel') return state.subscriptionStatus == 'cancelled';
    return state.active &&
        membershipLevel != null &&
        state.membershipLevel == membershipLevel;
  }

  Future<void> _storeLocalProof(
      String subscriberCidNumber, Map<String, dynamic> proof) async {
    final pending = await _readList(_pendingKey(subscriberCidNumber));
    pending.removeWhere((item) => item['tx_hash'] == proof['tx_hash']);
    pending.add(proof);
    await _writeState(_pendingKey(subscriberCidNumber), jsonEncode(pending));

    final historyKey = 'subscription_tx_history_by_cid:$subscriberCidNumber';
    final history = await _readList(historyKey);
    history.removeWhere((item) => item['tx_hash'] == proof['tx_hash']);
    history.add(proof);
    if (history.length > 50) history.removeRange(0, history.length - 50);
    await _writeState(historyKey, jsonEncode(history));
  }

  Future<void> _removePendingProof(
    String subscriberCidNumber,
    String txHash,
  ) async {
    final pending = await _readList(_pendingKey(subscriberCidNumber));
    pending.removeWhere((item) => item['tx_hash'] == txHash);
    if (pending.isEmpty) {
      await _deleteState(_pendingKey(subscriberCidNumber));
    } else {
      await _writeState(
        _pendingKey(subscriberCidNumber),
        jsonEncode(pending),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final raw = await _readState(key);
    if (raw == null) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    return decoded is List
        ? decoded.whereType<Map<String, dynamic>>().toList(growable: true)
        : <Map<String, dynamic>>[];
  }

  Future<String?> _readState(String key) => WalletIsar.instance.read(
        (isar) async =>
            (await isar.walletMembershipStateEntitys.getByStateKey(key))
                ?.payloadJson,
      );

  Future<void> _writeState(String key, String payloadJson) =>
      WalletIsar.instance.writeTxn((isar) async {
        final row =
            await isar.walletMembershipStateEntitys.getByStateKey(key) ??
                WalletMembershipStateEntity();
        row
          ..stateKey = key
          ..payloadJson = payloadJson;
        await isar.walletMembershipStateEntitys.put(row);
      });

  Future<void> _deleteState(String key) =>
      WalletIsar.instance.writeTxn((isar) async {
        await isar.walletMembershipStateEntitys.deleteByStateKey(key);
      });
}

enum MembershipDisplayDecision {
  activeConfirmed,
  inactiveConfirmed,
  unknown,
}
