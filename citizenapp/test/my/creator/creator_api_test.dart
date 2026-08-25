import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenapp/8964/services/square_api_client.dart'
    show SquareSession;
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/my/creator/creator_api.dart';
import 'package:citizenapp/my/creator/creator_service.dart';
import 'package:citizenapp/my/creator/models/creator_overview.dart';
import 'package:citizenapp/my/creator/models/creator_plan.dart';
import 'package:citizenapp/my/myid/finalized_identity_resolver.dart';
import 'package:citizenapp/my/myid/citizen_identity_chain_reader.dart';
import 'package:citizenapp/rpc/chain_rpc.dart' show TxPoolWatchCallback;
import 'package:citizenapp/rpc/subscription_rpc.dart';
import 'package:citizenapp/wallet/core/default_account_service.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/isar_test_env.dart';

void main() {
  useIsolatedIsar();
  // saveTiers 现按身份账户签名，会命中单例 FinalizedIdentityResolver.instance。
  // 注入 fake（身份=账户0，与 _FakeWalletManager/_FakeSessionProvider 同账户），
  // 避免真链读/真 Isar 导致 flaky。
  setUp(() {
    FinalizedIdentityResolver.debugInstance = _FakeIdentityCache();
  });
  tearDown(FinalizedIdentityResolver.resetDebugInstance);

  const session = SquareSession(
    sessionToken: 't',
    cidNumber: "CN220-CTZN2-198805200-2026",
    bindingRevision: 1,
    accountId:
        '0x7777777777777777777777777777777777777777777777777777777777777777',
    expiresAt: 9999999999999,
  );

  const tier = CreatorTier(
    tierId: 't1',
    tierName: '铁杆粉丝',
    pricesFen: {BillingPeriod.monthly: 990},
  );

  test('FakeCreatorApi 只接收已 finalized 交易哈希，不再触发第二次业务签名', () async {
    final api = FakeCreatorApi();

    final plan = await api.saveMyPlan(
      session: session,
      txHash: '0x${List.filled(64, 'a').join()}',
      blockHashHex: '0x${List.filled(64, 'b').join()}',
    );

    expect(api.lastSaveTxHash, '0x${List.filled(64, 'a').join()}');
    expect(plan.creatorCidNumber, session.cidNumber);
    expect(plan.tiers, isEmpty);
    expect(await api.fetchMyPlan(session), isNotNull);
  });

  test('CreatorApiHttp 保存只调用一次 plan 接口且携带链上交易哈希', () async {
    final paths = <String>[];
    var deviceSignCount = 0;
    final txHash = '0x${List.filled(64, 'b').join()}';
    final blockHash = '0x${List.filled(64, 'c').join()}';
    final api = CreatorApiHttp(
      baseUrl: 'https://creator.test',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['tx_hash'], txHash);
        expect(body['block_hash'], blockHash);
        expect(body, isNot(contains('signed_extrinsic_hex')));
        expect(body, isNot(contains('tiers')));
        expect(body, isNot(contains('challenge_id')));
        expect(body, isNot(contains('signature')));
        expect(request.headers['authorization'], 'Bearer t');
        expect(request.headers, isNot(contains('x-device-signature')));
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'plan': {
              'creator_cid_number': 'CN220-CTZN2-198805200-2026',
              'tiers': [tier.toJson()],
              'updated_at': 1,
            },
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final signedSession = SquareSession(
      sessionToken: 't',
      cidNumber: "CN220-CTZN2-198805200-2026",
      bindingRevision: 1,
      accountId:
          '0x7777777777777777777777777777777777777777777777777777777777777777',
      expiresAt: 9999999999999,
      signRequest: (_) async {
        deviceSignCount++;
        return 'device-signature';
      },
    );

    await api.saveMyPlan(
      session: signedSession,
      txHash: txHash,
      blockHashHex: blockHash,
    );

    expect(paths, ['/square/creator/plan']);
    expect(deviceSignCount, 0, reason: 'finalized 后的 Cloudflare 投影不得产生第二次签名');
  });

  test('创作者订阅投影确认只传 finalized 交易定位', () async {
    final api = CreatorApiHttp(
      baseUrl: 'https://creator.test',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, unorderedEquals(['tx_hash', 'block_hash']));
        expect(body, isNot(contains('creator_cid_number')));
        expect(body, isNot(contains('action')));
        expect(body, isNot(contains('tier_id')));
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await api.confirmCreatorSubscription(
      session: session,
      txHash: '0x${List.filled(64, 'a').join()}',
      blockHashHex: '0x${List.filled(64, 'b').join()}',
    );
  });

  test('FakeCreatorApi 概览默认按档位数', () async {
    final api = FakeCreatorApi(
      initialPlan: const CreatorPlan(
        creatorCidNumber: 'CN220-CTZN2-198805200-2026',
        tiers: [tier],
        updatedAt: 0,
      ),
    );
    final overview = await api.fetchOverview(session);
    expect(overview.tierCount, 1);
    expect(overview.subscriberCount, 0);
  });

  test('创作者展示快照按 CID 持久化并完整往返', () async {
    final service = CreatorService(
      api: FakeCreatorApi(),
      subscriptionRpc: _FakeSubscriptionRpc(),
      walletManager: _FakeWalletManager(),
      sessionProvider: _FakeSessionProvider(),
    );
    final display = CreatorPageData.active(
      plan: const CreatorPlan(
        creatorCidNumber: _creatorCidNumber,
        tiers: [tier],
        updatedAt: 123,
      ),
      overview: const CreatorOverview(
        subscriberCount: 7,
        monthIncomeFen: 8800,
        tierCount: 1,
      ),
    );
    await service.rememberDisplayData(
      cidNumber: _creatorCidNumber,
      data: display,
      membershipFetchedAtMs: 1000,
      creatorFetchedAtMs: 2000,
    );

    final snapshot = await service.readDisplaySnapshot(_creatorCidNumber);
    expect(snapshot, isNotNull);
    expect(snapshot!.cidNumber, _creatorCidNumber);
    expect(snapshot.data.gated, isFalse);
    expect(snapshot.data.plan!.tiers.single.tierName, '铁杆粉丝');
    expect(snapshot.data.overview!.subscriberCount, 7);
    expect(snapshot.membershipFetchedAtMs, 1000);
    expect(snapshot.creatorFetchedAtMs, 2000);
  });

  test('链上 finalized 后 Cloudflare 失败只重试投影确认，不产生第二次链上签名', () async {
    final api = _FlakyCreatorApi()..failSave = true;
    final rpc = _FakeSubscriptionRpc();
    final sessionProvider = _FakeSessionProvider();
    final service = CreatorService(
      api: api,
      subscriptionRpc: rpc,
      walletManager: _FakeWalletManager(),
      defaultAccountReader: _FakeDefaultAccountReader(),
      sessionProvider: sessionProvider,
    );

    final saved = await service.saveTiers(const [tier]);
    expect(saved.tiers.single.tierName, '铁杆粉丝');
    expect(rpc.setPlansCount, 1);
    expect(rpc.signCount, 1);
    expect(api.saveCount, 1);

    // 同一 CID 已换绑到新钱包账户；待提交证明仍必须由新会话接续处理。
    sessionProvider.accountId = _reboundAccountId;
    api.failSave = false;
    await service.load();
    expect(api.saveCount, 2, reason: '再次进入页面只重试 Cloudflare 查询投影');
    expect(rpc.setPlansCount, 1, reason: '同一业务不得再次提交链上交易');
    expect(rpc.signCount, 1, reason: '同一业务不得再次账户签名');
  });

  test('创作者刷新复用会员快照的 finalized 区块读取档位', () async {
    final rpc = _FakeSubscriptionRpc();
    final service = CreatorService(
      api: FakeCreatorApi(),
      subscriptionRpc: rpc,
      walletManager: _FakeWalletManager(),
      sessionProvider: _FakeSessionProvider(),
    );

    final data = await service.load(expectedCidNumber: _creatorCidNumber);

    expect(data.gated, isFalse);
    expect(
      rpc.lastPlansBlockHash,
      '0x${List.filled(64, '0').join()}',
      reason: '会员资格与创作者档位必须来自同一个 finalized 区块',
    );
  });

  test('仅改档位名只提交 call_index 6，不重写价格计划', () async {
    final rpc = _FakeSubscriptionRpc();
    final api = FakeCreatorApi();
    final service = CreatorService(
      api: api,
      subscriptionRpc: rpc,
      walletManager: _FakeWalletManager(),
      defaultAccountReader: _FakeDefaultAccountReader(),
      sessionProvider: _FakeSessionProvider(),
    );

    final plan = await service.updateTierName(
      currentTiers: const [tier],
      tierId: 't1',
      tierName: '核心支持者',
    );

    expect(rpc.renameCount, 1);
    expect(rpc.setPlansCount, 0);
    expect(rpc.signCount, 1);
    expect(api.lastSaveTxHash, '0x${List.filled(64, 'e').join()}');
    expect(plan.tiers.single.tierName, '核心支持者');
    expect(plan.tiers.single.priceFenOf(BillingPeriod.monthly), 990);
  });
}

const _signerSs58Address = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
const _accountId =
    '0x0000000000000000000000000000000000000000000000000000000000000000';
const _reboundAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _creatorCidNumber = 'CN220-CTZN2-198805200-2026';

class _FakeSessionProvider extends SquareSessionProvider {
  String accountId = _accountId;

  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
        sessionToken: 'creator-session',
        cidNumber: _creatorCidNumber,
        bindingRevision: 1,
        accountId: accountId,
        expiresAt: 9999999999999,
      );
}

/// 身份账户单源 fake：身份=账户0（与钱包/会话同账户），offline、不链读。
class _FakeIdentityCache extends FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
        accountId: _accountId,
        ss58Address: _signerSs58Address,
        snapshot: CitizenIdentityChainSnapshot(
          cidNumber: _creatorCidNumber,
          accountId: Uint8List(32),
          bindingRevision: 1,
          votingIdentity: null,
        ),
      );
}

class _FakeWalletManager extends WalletManager {
  @override
  Future<WalletProfile?> getDefaultWallet() async => const WalletProfile(
        walletIndex: 1,
        walletName: 'creator',
        walletIcon: '',
        balance: 0,
        ss58Address: _signerSs58Address,
        accountId: _accountId,
        alg: 'sr25519',
        ss58: 2027,
        createdAtMillis: 0,
        source: 'test',
        signMode: SignMode.hot,
      );

  @override
  Future<Uint8List> signForAccountId(
          String accountId, Uint8List payload) async =>
      Uint8List(64);
}

class _FakeDefaultAccountReader implements DefaultAccountReader {
  @override
  Future<DefaultAccount?> getDefaultAccount() async => const DefaultAccount(
        accountId: _accountId,
        ss58Address: _signerSs58Address,
        accountName: 'creator',
        signMode: SignMode.hot,
        walletIndex: 1,
      );
}

class _FakeSubscriptionRpc extends SubscriptionRpc {
  int setPlansCount = 0;
  int renameCount = 0;
  int signCount = 0;
  String currentTierName = '铁杆粉丝';
  String? lastPlansBlockHash;

  @override
  Future<FinalizedSubscriptionSnapshot> fetchSubscriptionSnapshot({
    required String subscriberCidNumber,
    String? creatorCidNumber,
  }) async =>
      FinalizedSubscriptionSnapshot(
        state: ChainSubscriptionState(
          plan: const ChainSubscriptionPlan.platform('freedom'),
          startedAt: 1000,
          lastChargedAt: 1000,
          lastChargedPriceFen: BigInt.one,
          paidUntil: 3000,
          status: 'active',
          authorizedPriceFen: BigInt.one,
          suspendReason: null,
        ),
        chainNowMs: 2000,
        blockHashHex: '0x${List.filled(64, '0').join()}',
      );

  @override
  Future<FinalizedSubscriptionTransaction> setCreatorPlans({
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required List<CreatorTierInput> tiers,
    required Future<Uint8List> Function(Uint8List payload) sign,
    TxPoolWatchCallback? onWatchEvent,
  }) async {
    setPlansCount++;
    await sign(Uint8List.fromList([1]));
    signCount++;
    return (
      txHash: '0x${List.filled(64, 'c').join()}',
      usedNonce: 1,
      blockHashHex: '0x${List.filled(64, 'd').join()}',
    );
  }

  @override
  Future<FinalizedSubscriptionTransaction> updateCreatorTierName({
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required String tierId,
    required String tierName,
    required Future<Uint8List> Function(Uint8List payload) sign,
    TxPoolWatchCallback? onWatchEvent,
  }) async {
    renameCount++;
    await sign(Uint8List.fromList([2]));
    signCount++;
    currentTierName = tierName;
    return (
      txHash: '0x${List.filled(64, 'e').join()}',
      usedNonce: 2,
      blockHashHex: '0x${List.filled(64, 'f').join()}',
    );
  }

  @override
  Future<List<ChainCreatorTier>> fetchCreatorPlans(
          String creatorCidNumber) async =>
      [
        ChainCreatorTier(
          tierId: 't1',
          tierName: currentTierName,
          pricesFen: {'monthly': BigInt.from(990)},
        ),
      ];

  @override
  Future<List<ChainCreatorTier>> fetchCreatorPlansAtBlock(
    String creatorCidNumber,
    String blockHashHex,
  ) {
    lastPlansBlockHash = blockHashHex;
    return fetchCreatorPlans(creatorCidNumber);
  }
}

class _FlakyCreatorApi extends FakeCreatorApi {
  bool failSave = false;
  int saveCount = 0;

  @override
  Future<CreatorPlan> saveMyPlan({
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  }) async {
    saveCount++;
    if (failSave) throw const CreatorApiException('temporary');
    return super.saveMyPlan(
      session: session,
      txHash: txHash,
      blockHashHex: blockHashHex,
    );
  }
}
