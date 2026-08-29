import 'dart:convert';
import 'dart:io';

import 'package:citizen_sdk/src/node/bootstrap_client.dart';
import 'package:citizen_sdk/src/node/bootstrap_manifest.dart';
import 'package:citizen_sdk/src/node/chain_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _bootnodeA =
    '/dns4/a.example/tcp/30333/wss/p2p/12D3KooW1111111111111111111111111111111111111111';
const _bootnodeB =
    '/dns4/b.example/tcp/30333/wss/p2p/12D3KooW2222222222222222222222222222222222222222';
const _stateRoot =
    '0x4444444444444444444444444444444444444444444444444444444444444444';

void main() {
  test('BootstrapClient 使用 SDK 独立 endpoint 并解析安全清单', () async {
    final wireFixture =
        jsonDecode(
              File(
                'test/node/citizensdk_bootstrap_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final client = BootstrapClient(
      baseUrl: 'http://127.0.0.1:8787',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/chain/citizensdk/bootstrap');
        return http.Response(jsonEncode(wireFixture), 200);
      }),
    );

    final manifest = await client.fetch();

    expect(manifest.chain.chainId, 'citizenchain');
    expect(manifest.chain.ss58Format, 2027);
    expect(manifest.lightClient.apiIsTruth, isFalse);
    expect(
      manifest.p2p.bootnodes,
      ((wireFixture['p2p'] as Map<String, dynamic>)['bootnodes'] as List)
          .cast<String>(),
    );
    client.close();
  });

  test('清单拒绝 API 真源、RPC proxy、RPC URL 与远端 checkpoint', () {
    final apiTruth = _manifest();
    (apiTruth['light_client'] as Map<String, dynamic>)['api_is_truth'] = true;
    expect(
      () => BootstrapManifest.fromJson(apiTruth),
      throwsA(isA<BootstrapManifestException>()),
    );

    final rpcProxy = _manifest();
    (rpcProxy['security'] as Map<String, dynamic>)['rpc_proxy'] = true;
    expect(
      () => BootstrapManifest.fromJson(rpcProxy),
      throwsA(isA<BootstrapManifestException>()),
    );

    for (final forbidden in <String>[
      'rpc_url',
      'validator_rpc_url',
      'archive_rpc_url',
      'chain_rpc_url',
      'light_sync_state_url',
      'light_sync_state_sha256',
    ]) {
      final data = _manifest()..[forbidden] = 'https://example.invalid/value';
      expect(
        () => BootstrapManifest.fromJson(data),
        throwsA(isA<BootstrapManifestException>()),
        reason: forbidden,
      );
    }
  });

  test('清单逐层拒绝聊天、广场、TUYU 与其他未知业务字段', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (json) => json['chat'] = <String, dynamic>{},
      (json) => json['square'] = <String, dynamic>{},
      (json) => json['tuyu'] = <String, dynamic>{},
      (json) => (json['chain'] as Map<String, dynamic>)['business'] = true,
      (json) =>
          (json['light_client'] as Map<String, dynamic>)['product'] = 'host',
      (json) => (json['p2p'] as Map<String, dynamic>)['service'] = 'chat',
      (json) => (json['security'] as Map<String, dynamic>)['login'] = true,
    ];

    for (final mutate in mutations) {
      final data = _manifest();
      mutate(data);
      expect(
        () => BootstrapManifest.fromJson(data),
        throwsA(isA<BootstrapManifestException>()),
      );
    }
  });

  test('BootstrapClient 只允许 HTTPS 或本机 HTTP', () {
    expect(
      BootstrapClient(baseUrl: 'https://api.example/').baseUrl,
      'https://api.example',
    );
    expect(
      BootstrapClient(baseUrl: 'http://127.0.0.1:8787/').baseUrl,
      'http://127.0.0.1:8787',
    );
    expect(
      () => BootstrapClient(baseUrl: 'http://api.example'),
      throwsArgumentError,
    );
  });

  test('推荐 bootnode 只在链参数与本地 chainspec 完全匹配时注入', () {
    final manifest = BootstrapManifest.fromJson(_manifest());
    final injected = CitizenChainAssets.combine(
      chainSpecJson: jsonEncode(_chainSpec()),
      lightSyncStateJson: jsonEncode(_lightSyncState()),
      bootstrap: manifest,
    );
    final spec = jsonDecode(injected.chainSpec) as Map<String, dynamic>;
    expect(spec['bootNodes'], <String>[
      _bootnodeA,
      _bootnodeB,
      '/dns4/old.example/p2p/old',
    ]);

    final mismatch = _manifest();
    (mismatch['chain'] as Map<String, dynamic>)['state_root'] =
        '0x${'11' * 32}';
    final unchanged = CitizenChainAssets.combine(
      chainSpecJson: jsonEncode(_chainSpec()),
      lightSyncStateJson: jsonEncode(_lightSyncState()),
      bootstrap: BootstrapManifest.fromJson(mismatch),
    );
    expect(
      (jsonDecode(unchanged.chainSpec) as Map<String, dynamic>)['bootNodes'],
      <String>['/dns4/old.example/p2p/old'],
    );

    final wrongGenesis = _manifest();
    (wrongGenesis['chain'] as Map<String, dynamic>)['genesis_hash'] =
        '0x${'33' * 32}';
    final genesisMismatch = CitizenChainAssets.combine(
      chainSpecJson: jsonEncode(_chainSpec()),
      lightSyncStateJson: jsonEncode(_lightSyncState()),
      bootstrap: BootstrapManifest.fromJson(wrongGenesis),
    );
    expect(
      (jsonDecode(genesisMismatch.chainSpec)
          as Map<String, dynamic>)['bootNodes'],
      <String>['/dns4/old.example/p2p/old'],
      reason: '远端非权威清单不得阻断或改写随包可信启动路径',
    );
  });
}

Map<String, dynamic> _manifest() => <String, dynamic>{
  'ok': true,
  'schema': 'citizensdk.chain.bootstrap',
  'generated_at': 1800000000000,
  'cache_ttl_seconds': 300,
  'chain': <String, dynamic>{
    'chain_id': 'citizenchain',
    'protocol_id': 'citizenchain',
    'genesis_hash': CitizenChainAssets.genesisHashFromCheckpoint(
      _lightSyncState()['finalizedBlockHeader']! as String,
    ),
    'state_root': _stateRoot,
    'ss58_format': 2027,
    'token_symbol': 'GMB',
    'token_decimals': 2,
  },
  'light_client': <String, dynamic>{
    'mode': 'smoldot',
    'truth_source': 'p2p_finalized_storage',
    'api_is_truth': false,
    'bundled_assets_required': <String>[
      'assets/chainspec.json',
      'assets/light_sync_state.json',
    ],
  },
  'p2p': <String, dynamic>{
    'bootnodes': <String>[_bootnodeA, _bootnodeB],
    'min_peer_count_hint': 1,
  },
  'security': <String, dynamic>{
    'exposes_rpc_url': false,
    'rpc_proxy': false,
    'exposes_private_key_material': false,
    'validator_rpc_public': false,
  },
};

Map<String, dynamic> _chainSpec() => <String, dynamic>{
  'id': 'citizenchain',
  'protocolId': 'citizenchain',
  'properties': <String, dynamic>{'ss58Format': 2027},
  'genesis': <String, dynamic>{'stateRootHash': _stateRoot},
  'bootNodes': <String>['/dns4/old.example/p2p/old'],
};

Map<String, dynamic> _lightSyncState() => <String, dynamic>{
  'finalizedBlockHeader': '0x${'00' * 32}00${'00' * 64}',
  'grandpaAuthoritySet': '0x00',
};
