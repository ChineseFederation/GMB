import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/8964/services/square_api_client.dart'
    show SquareMembershipState, SquareSession;
import 'package:citizenapp/my/creator/creator_api.dart';
import 'package:citizenapp/my/creator/models/creator_overview.dart';
import 'package:citizenapp/my/creator/models/creator_plan.dart';
import 'package:citizenapp/my/membership/subscription_service.dart';
import 'package:citizenapp/my/myid/finalized_identity_resolver.dart';
import 'package:citizenapp/qr/pages/qr_sign_session_page.dart';
import 'package:citizenapp/qr/qr_protocols.dart';
import 'package:citizenapp/rpc/pallet_registry.dart';
import 'package:citizenapp/rpc/subscription_rpc.dart';
import 'package:citizenapp/wallet/core/default_account_service.dart';
import 'package:citizenapp/wallet/core/device_subkey.dart' show hexToBytes;
import 'package:citizenapp/wallet/core/secure_seed_store.dart'
    show SecureSeedException;
import 'package:citizenapp/wallet/core/seed_sign_error.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/isar/wallet_isar.dart';

/// 创作者页展示态：无可用钱包账户会话 / 已开通（含计划与概览）。

class CreatorPageData {
  const CreatorPageData._({required this.gated, this.plan, this.overview});

  /// true = 无会话或没有当前有效的平台会员权益。
  final bool gated;
  final CreatorPlan? plan;
  final CreatorOverview? overview;

  factory CreatorPageData.gated() => const CreatorPageData._(gated: true);

  factory CreatorPageData.active({
    required CreatorPlan plan,
    required CreatorOverview overview,
  }) =>
      CreatorPageData._(gated: false, plan: plan, overview: overview);
}

/// 创作者页本地展示快照。
///
/// 快照只决定首帧展示，不授予会员权益，也不允许绕过保存动作中的 finalized 校验。
/// CID 是快照唯一归属主键；会员态与创作者数据分别记录成功读取时间，便于页面只在
/// 数据过期时后台刷新，而不是每次进页面都等待网络和链。
class CreatorDisplaySnapshot {
  const CreatorDisplaySnapshot({
    required this.cidNumber,
    required this.data,
    required this.membershipFetchedAtMs,
    required this.creatorFetchedAtMs,
  });

  final String cidNumber;
  final CreatorPageData data;
  final int membershipFetchedAtMs;
  final int creatorFetchedAtMs;

  bool isFresh(
    int nowMs, {
    Duration membershipTtl = const Duration(minutes: 5),
    Duration creatorTtl = const Duration(minutes: 1),
  }) {
    bool fresh(int timestamp, Duration ttl) =>
        timestamp > 0 &&
        nowMs >= timestamp &&
        nowMs - timestamp <= ttl.inMilliseconds;
    return fresh(membershipFetchedAtMs, membershipTtl) &&
        (data.gated || fresh(creatorFetchedAtMs, creatorTtl));
  }
}

class CreatorException implements Exception {
  const CreatorException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 创作者管理编排：当前有效的平台会员可创建档位、读取概览并收取订阅款。
///
/// - 保存档位只签一次 `set_creator_plans` 链上交易；名称与价格均由 finalized 链状态确认。
class CreatorService {
  CreatorService({
    CreatorApi? api,
    SubscriptionRpc? subscriptionRpc,
    WalletManager? walletManager,
    DefaultAccountReader? defaultAccountReader,
    SquareSessionProvider? sessionProvider,
    SubscriptionService? subscriptionService,
  })  : _api = api ?? CreatorApiHttp(),
        _subscriptionRpc = subscriptionRpc ?? SubscriptionRpc(),
        _wallet = walletManager ?? WalletManager(),
        _defaultAccountReader = defaultAccountReader ??
            DefaultAccountService(walletManager: walletManager),
        _session = sessionProvider ?? SquareSessionProvider.instance,
        _subscriptionService = subscriptionService ?? SubscriptionService() {
    _walletAccountSigner = WalletAccountSigner(walletManager: _wallet);
  }

  final CreatorApi _api;
  final SubscriptionRpc _subscriptionRpc;
  final WalletManager _wallet;
  final DefaultAccountReader _defaultAccountReader;
  final SquareSessionProvider _session;
  final SubscriptionService _subscriptionService;
  late final WalletAccountSigner _walletAccountSigner;

  String _displaySnapshotKey(String cidNumber) =>
      'creator_display_snapshot_by_cid:$cidNumber';

  /// 读取上一次成功同步的页面快照；损坏快照不参与展示，读取路径绝不删除数据。
  Future<CreatorDisplaySnapshot?> readDisplaySnapshot(String cidNumber) async {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty) return null;
    final raw = await _readCreatorState(_displaySnapshotKey(normalized));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['cid_number'] != normalized ||
          decoded['gated'] is! bool) {
        return null;
      }
      final gated = decoded['gated'] as bool;
      final membershipFetchedAtMs = decoded['membership_fetched_at_ms'];
      final creatorFetchedAtMs = decoded['creator_fetched_at_ms'];
      if (membershipFetchedAtMs is! int || creatorFetchedAtMs is! int) {
        return null;
      }
      if (gated) {
        return CreatorDisplaySnapshot(
          cidNumber: normalized,
          data: CreatorPageData.gated(),
          membershipFetchedAtMs: membershipFetchedAtMs,
          creatorFetchedAtMs: creatorFetchedAtMs,
        );
      }
      final planRaw = decoded['plan'];
      final overviewRaw = decoded['overview'];
      if (planRaw is! Map<String, dynamic> ||
          overviewRaw is! Map<String, dynamic>) {
        return null;
      }
      final plan = CreatorPlan.fromJson(planRaw);
      if (plan.creatorCidNumber != normalized) return null;
      return CreatorDisplaySnapshot(
        cidNumber: normalized,
        data: CreatorPageData.active(
          plan: plan,
          overview: CreatorOverview.fromJson(overviewRaw),
        ),
        membershipFetchedAtMs: membershipFetchedAtMs,
        creatorFetchedAtMs: creatorFetchedAtMs,
      );
    } on FormatException {
      return null;
    }
  }

  /// 保存已经可展示的创作者页数据；只更新本地读模型，不改变授权状态。
  Future<void> rememberDisplayData({
    required String cidNumber,
    required CreatorPageData data,
    required int membershipFetchedAtMs,
    required int creatorFetchedAtMs,
  }) async {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty) return;
    final plan = data.plan;
    final overview = data.overview;
    await _writeCreatorState(
      _displaySnapshotKey(normalized),
      jsonEncode({
        'cid_number': normalized,
        'gated': data.gated,
        'membership_fetched_at_ms': membershipFetchedAtMs,
        'creator_fetched_at_ms': creatorFetchedAtMs,
        if (plan != null)
          'plan': {
            'creator_cid_number': plan.creatorCidNumber,
            'tiers': plan.tiersJson(),
            'updated_at': plan.updatedAt,
          },
        if (overview != null)
          'overview': {
            'subscriber_count': overview.subscriberCount,
            'month_income_fen': overview.monthIncomeFen,
            'tier_count': overview.tierCount,
          },
      }),
    );
  }

  /// 后台刷新：按 finalized 平台订阅真态门禁，并在同一区块读取创作者档位。
  ///
  /// 页面首帧不等待本方法；[expectedCidNumber] 防止旧会话结果写入新身份页面。
  Future<CreatorPageData> load({String? expectedCidNumber}) async {
    final session = await _session.ensureSession();
    if (session == null) {
      throw const CreatorException('会话不可用，请稍后重试');
    }
    final expected = expectedCidNumber?.trim() ?? '';
    if (expected.isNotEmpty && session.cidNumber != expected) {
      throw const CreatorException('当前会话与创作者身份不一致，请稍后重试');
    }

    final membership = await _subscriptionRpc.fetchSubscriptionSnapshot(
      subscriberCidNumber: session.cidNumber,
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final membershipActive =
        membership.state?.isEffectiveAt(membership.chainNowMs) == true;
    await _rememberMembershipSnapshot(
      cidNumber: session.cidNumber,
      membership: membership,
      fetchedAtMs: nowMs,
    );
    if (!membershipActive) {
      final data = CreatorPageData.gated();
      await rememberDisplayData(
        cidNumber: session.cidNumber,
        data: data,
        membershipFetchedAtMs: nowMs,
        creatorFetchedAtMs: 0,
      );
      return data;
    }

    // 上一次链上已 finalized、但 Cloudflare 瞬时失败时只重试 finalized 投影确认，不再签名。
    unawaited(_retryPendingProjection(session));

    final displayPlanFuture = () async {
      try {
        return await _api.fetchMyPlan(session);
      } on Exception {
        return null;
      }
    }();
    final overviewFuture = () async {
      try {
        return await _api.fetchOverview(session);
      } on Exception {
        return null;
      }
    }();
    final results = await Future.wait([
      // Cloudflare 只补投影时间与统计；瞬时不可用时仍允许按链上真态进入页面。
      displayPlanFuture,
      overviewFuture,
      _subscriptionRpc.fetchCreatorPlansAtBlock(
        session.cidNumber,
        membership.blockHashHex,
      ),
    ]);
    final displayPlan = results[0] as CreatorPlan?;
    final cached = await readDisplaySnapshot(session.cidNumber);
    final overview = results[1] as CreatorOverview? ??
        cached?.data.overview ??
        CreatorOverview.zero;
    final chainTiers = results[2] as List<ChainCreatorTier>;
    final data = CreatorPageData.active(
      plan: mergeCreatorPlanWithChain(
        creatorCidNumber: session.cidNumber,
        displayPlan: displayPlan,
        chainTiers: chainTiers,
      ),
      overview: overview,
    );
    await rememberDisplayData(
      cidNumber: session.cidNumber,
      data: data,
      membershipFetchedAtMs: nowMs,
      creatorFetchedAtMs: nowMs,
    );
    return data;
  }

  Future<void> _rememberMembershipSnapshot({
    required String cidNumber,
    required FinalizedSubscriptionSnapshot membership,
    required int fetchedAtMs,
  }) async {
    final previous = await _subscriptionService.readDisplaySnapshot(cidNumber);
    final state = membership.state;
    final active = state?.isEffectiveAt(membership.chainNowMs) == true;
    await _subscriptionService.writeDisplaySnapshot(
      cidNumber,
      MembershipDisplaySnapshot(
        state: SquareMembershipState(
          active: active,
          paidUntil: state?.paidUntil ?? 0,
          membershipLevel: state?.plan.membershipLevel,
          subscriptionStatus: state?.status,
          subscriptionActive: active,
          lastChargedAt: state?.lastChargedAt ?? 0,
        ),
        prices: previous?.prices ?? const <String, int>{},
        subscriptionFetchedAtMs: fetchedAtMs,
        pricesFetchedAtMs: previous?.pricesFetchedAtMs ?? 0,
      ),
    );
  }

  /// 覆盖式保存档位：一次链上签名原子写入名称与价格，再确认 finalized 投影。
  Future<CreatorPlan> saveTiers(
    List<CreatorTier> tiers, {
    BuildContext? context,
  }) async {
    if (tiers.length > CreatorPlan.maxTiers) {
      throw const CreatorException('最多 ${CreatorPlan.maxTiers} 个会员档');
    }
    final identity = await _requireIdentity();
    final account = await _requireSigningAccount(identity.accountId);
    final session = await _session.ensureSession();
    if (session == null) {
      throw const CreatorException('会话不可用，请稍后重试');
    }
    if (session.accountId != identity.accountId) {
      throw const CreatorException('当前会话与默认钱包账户不一致，请重新登录');
    }
    try {
      final membership = await _subscriptionRpc.fetchSubscriptionSnapshot(
        subscriberCidNumber: session.cidNumber,
      );
      if (membership.state?.isEffectiveAt(membership.chainNowMs) != true) {
        throw const CreatorException('需要当前有效的平台会员才能设置创作者会员档');
      }
      final result = await _subscriptionRpc.setCreatorPlans(
        fromSs58Address: identity.ss58Address,
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        tiers: tiers
            .map(
              (tier) => CreatorTierInput(
                tierId: tier.tierId,
                tierName: tier.tierName,
                pricesFen: tier.pricesFen.entries
                    .map(
                      (entry) => CreatorPeriodPriceInput(
                        billingPeriod: entry.key.key,
                        priceFen: BigInt.from(entry.value),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        sign: (payload) => _walletAccountSigner.sign(
          context: context,
          accountId: identity.accountId,
          signMode: account.signMode,
          payload: payload,
          action: QrActions.chain(
            PalletRegistry.squarePostPallet,
            PalletRegistry.setCreatorPlansCall,
          ),
          requestPrefix: 'creator-plans-',
        ),
      );
      return _completeFinalizedSave(
        session: session,
        accountId: identity.accountId,
        creatorCidNumber: session.cidNumber,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
        signedExtrinsicHex: result.signedExtrinsicHex,
        tiers: tiers,
      );
    } on SecureSeedException catch (e) {
      // 生物识别取消 / 无锁屏等：单源文案，杜绝静默失败。
      throw CreatorException(seedSignErrorMessage(e));
    } on WalletAuthException catch (e) {
      throw CreatorException(e.message);
    } on CreatorApiException catch (e) {
      throw CreatorException(e.message);
    } on Exception catch (e) {
      throw CreatorException('保存失败：$e');
    }
  }

  /// 只改现有档位名称：当前 CID 控制账户签名，价格、授权、续费与扣款完全不变。
  Future<CreatorPlan> updateTierName({
    BuildContext? context,
    required List<CreatorTier> currentTiers,
    required String tierId,
    required String tierName,
  }) async {
    final identity = await _requireIdentity();
    final account = await _requireSigningAccount(identity.accountId);
    final session = await _session.ensureSession();
    if (session == null || session.accountId != identity.accountId) {
      throw const CreatorException('当前会话与默认钱包账户不一致，请重新登录');
    }
    final index = currentTiers.indexWhere((tier) => tier.tierId == tierId);
    if (index < 0) throw const CreatorException('要改名的会员档不存在');
    try {
      final result = await _subscriptionRpc.updateCreatorTierName(
        fromSs58Address: identity.ss58Address,
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        tierId: tierId,
        tierName: tierName,
        sign: (payload) => _walletAccountSigner.sign(
          context: context,
          accountId: identity.accountId,
          signMode: account.signMode,
          payload: payload,
          action: QrActions.chain(
            PalletRegistry.squarePostPallet,
            PalletRegistry.updateCreatorTierNameCall,
          ),
          requestPrefix: 'creator-tier-name-',
        ),
      );
      try {
        await _appendLocalTransaction(
          creatorCidNumber: session.cidNumber,
          accountId: identity.accountId,
          action: 'update_creator_tier_name',
          txHash: result.txHash,
          blockHashHex: result.blockHashHex,
          signedExtrinsicHex: result.signedExtrinsicHex,
        );
      } on Exception {
        // 链上已经 finalized；本地审计缓存失败不得诱导用户再次签名。
      }
      final localTiers = List<CreatorTier>.from(currentTiers);
      localTiers[index] = localTiers[index].copyWith(tierName: tierName);
      final localPlan = CreatorPlan(
        creatorCidNumber: session.cidNumber,
        tiers: List.unmodifiable(localTiers),
        updatedAt: 0,
      );
      try {
        final chainTiers =
            await _subscriptionRpc.fetchCreatorPlans(session.cidNumber);
        return mergeCreatorPlanWithChain(
          creatorCidNumber: session.cidNumber,
          displayPlan: null,
          chainTiers: chainTiers,
        );
      } on Exception {
        return localPlan;
      }
    } on SecureSeedException catch (e) {
      throw CreatorException(seedSignErrorMessage(e));
    } on WalletAuthException catch (e) {
      throw CreatorException(e.message);
    } on Exception catch (e) {
      throw CreatorException('改名失败：$e');
    }
  }

  /// 当前默认账户经 finalized 闭环验证后，才可签名 `set_creator_plans` 链上
  /// 交易的唯一签名者。档位与待提交证明归属永久 CID，账户只记录签名事实。
  Future<FinalizedIdentity> _requireIdentity() async {
    final identity = await FinalizedIdentityResolver.instance.resolve();
    if (identity == null || !identity.isRegistered) {
      throw const CreatorException('请先注册并绑定公民 CID');
    }
    return identity;
  }

  Future<DefaultAccount> _requireSigningAccount(String accountId) async {
    final account = await _defaultAccountReader.getDefaultAccount();
    if (account == null || account.accountId != accountId) {
      throw const CreatorException('当前身份与默认钱包账户不一致，已拒绝签名');
    }
    return account;
  }

  String _pendingProjectionKey(String creatorCidNumber) =>
      'creator_plan_projection_pending_by_cid:$creatorCidNumber';

  Future<void> _writePendingProjection({
    required String creatorCidNumber,
    required String signerAccountId,
    required String txHash,
    required String blockHashHex,
    required String signedExtrinsicHex,
    required List<CreatorTier> tiers,
  }) async {
    await _writeCreatorState(
      _pendingProjectionKey(creatorCidNumber),
      jsonEncode({
        'tx_hash': txHash,
        'block_hash': blockHashHex,
        'signed_extrinsic_hex': signedExtrinsicHex,
        'signer_account_id': signerAccountId,
        'tiers': tiers.map((tier) => tier.toJson()).toList(growable: false),
      }),
    );
  }

  Future<void> _clearPendingProjection(String creatorCidNumber) async {
    await _deleteCreatorState(_pendingProjectionKey(creatorCidNumber));
  }

  Future<void> _retryPendingProjection(SquareSession session) async {
    try {
      final raw =
          await _readCreatorState(_pendingProjectionKey(session.cidNumber));
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final txHash = decoded['tx_hash'];
      final blockHashHex = decoded['block_hash'];
      final signedExtrinsicHex = decoded['signed_extrinsic_hex'];
      final rawTiers = decoded['tiers'];
      if (txHash is! String ||
          blockHashHex is! String ||
          signedExtrinsicHex is! String ||
          rawTiers is! List) {
        return;
      }
      final tiers = rawTiers
          .whereType<Map<String, dynamic>>()
          .map(CreatorTier.fromJson)
          .toList(growable: false);
      await _api.saveMyPlan(
        session: session,
        txHash: txHash,
        blockHashHex: blockHashHex,
        signedExtrinsicHex: signedExtrinsicHex,
        tiers: tiers,
      );
      await _deleteCreatorState(_pendingProjectionKey(session.cidNumber));
    } on Exception {
      // 保留待同步记录；页面仍以 finalized 链上名称与价格为真源，不阻断创作者功能。
    }
  }

  /// 进入本方法时链上业务已经 finalized；之后任何边缘或本地缓存失败都不得要求用户重签。
  Future<CreatorPlan> _completeFinalizedSave({
    required SquareSession session,
    required String accountId,
    required String creatorCidNumber,
    required String txHash,
    required String blockHashHex,
    required String signedExtrinsicHex,
    required List<CreatorTier> tiers,
  }) async {
    final localPlan = CreatorPlan(
      creatorCidNumber: creatorCidNumber,
      tiers: tiers,
      updatedAt: 0,
    );
    try {
      await _appendLocalTransaction(
        creatorCidNumber: creatorCidNumber,
        accountId: accountId,
        action: 'set_creator_plans',
        txHash: txHash,
        blockHashHex: blockHashHex,
        signedExtrinsicHex: signedExtrinsicHex,
      );
      await _writePendingProjection(
        creatorCidNumber: creatorCidNumber,
        signerAccountId: accountId,
        txHash: txHash,
        blockHashHex: blockHashHex,
        signedExtrinsicHex: signedExtrinsicHex,
        tiers: tiers,
      );
    } on Exception {
      // 继续立即提交 Cloudflare；链上已成功，禁止把本地缓存异常变成第二次签名。
    }

    var displayPlan = localPlan;
    try {
      displayPlan = await _api.saveMyPlan(
        session: session,
        txHash: txHash,
        blockHashHex: blockHashHex,
        signedExtrinsicHex: signedExtrinsicHex,
        tiers: tiers,
      );
      await _clearPendingProjection(creatorCidNumber);
    } on Exception {
      // 保留待同步记录；下次进入创作者页只重试 HTTP。
    }

    try {
      final chainTiers = await _subscriptionRpc.fetchCreatorPlans(
        creatorCidNumber,
      );
      return mergeCreatorPlanWithChain(
        creatorCidNumber: creatorCidNumber,
        displayPlan: displayPlan,
        chainTiers: chainTiers,
      );
    } on Exception {
      return localPlan;
    }
  }

  /// 本地按永久 CID 保留有限条 finalized 交易证明；签名账户留在证明内部作为
  /// 不可变交易事实，Cloudflare 成功后也不删除链上交易记录。
  Future<void> _appendLocalTransaction({
    required String creatorCidNumber,
    required String accountId,
    required String action,
    required String txHash,
    required String blockHashHex,
    required String signedExtrinsicHex,
  }) async {
    final key = 'subscription_tx_history_by_cid:$creatorCidNumber';
    final raw = await _readMembershipState(key);
    final history = <Map<String, dynamic>>[];
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        history.addAll(decoded.whereType<Map<String, dynamic>>());
      }
    }
    history.removeWhere((item) => item['tx_hash'] == txHash);
    history.add({
      'action': action,
      'tx_hash': txHash,
      'block_hash': blockHashHex,
      'signed_extrinsic_hex': signedExtrinsicHex,
      'signer_account_id': accountId,
    });
    if (history.length > 50) history.removeRange(0, history.length - 50);
    await _writeMembershipState(key, jsonEncode(history));
  }

  Future<String?> _readCreatorState(String key) => WalletIsar.instance.read(
        (isar) async =>
            (await isar.walletCreatorStateEntitys.getByStateKey(key))
                ?.payloadJson,
      );

  Future<void> _writeCreatorState(String key, String payloadJson) =>
      WalletIsar.instance.writeTxn((isar) async {
        final row = await isar.walletCreatorStateEntitys.getByStateKey(key) ??
            WalletCreatorStateEntity();
        row
          ..stateKey = key
          ..payloadJson = payloadJson;
        await isar.walletCreatorStateEntitys.put(row);
      });

  Future<void> _deleteCreatorState(String key) =>
      WalletIsar.instance.writeTxn((isar) async {
        await isar.walletCreatorStateEntitys.deleteByStateKey(key);
      });

  Future<String?> _readMembershipState(String key) => WalletIsar.instance.read(
        (isar) async =>
            (await isar.walletMembershipStateEntitys.getByStateKey(key))
                ?.payloadJson,
      );

  Future<void> _writeMembershipState(String key, String payloadJson) =>
      WalletIsar.instance.writeTxn((isar) async {
        final row =
            await isar.walletMembershipStateEntitys.getByStateKey(key) ??
                WalletMembershipStateEntity();
        row
          ..stateKey = key
          ..payloadJson = payloadJson;
        await isar.walletMembershipStateEntitys.put(row);
      });
}
