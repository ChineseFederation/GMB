import 'dart:convert';
import 'dart:io';

import 'package:citizen_sdk/src/node/bootstrap_manifest.dart';
import 'package:citizen_sdk/src/node/chain_assets.dart';
import 'package:flutter_test/flutter_test.dart';

const _bootnodeA =
    '/dns4/nrcgch.crcfrcn.com/tcp/30333/wss/p2p/'
    '12D3KooWHepcMGD3h9VC1XNWmrac3pXo63RimV5jhTU2nC2TLAyS';
const _bootnodeB =
    '/dns4/prczss.crcfrcn.com/tcp/30333/wss/p2p/'
    '12D3KooWPjWNXvCzPv6PPuiGnF3J5uToW3ySfaB7rKkwUrN2CALv';
const _bootnodeGzs =
    '/dns4/prcgzs.crcfrcn.com/tcp/30333/wss/p2p/'
    '12D3KooWC7t4V1Z2aQWS9HikBdXQgXEaTqeZ5YD78cnxtYBDn31M';
const _bootnodeHes =
    '/dns4/prches.crcfrcn.com/tcp/30333/wss/p2p/'
    '12D3KooWSkKBEJ2KZXckFhzLvrqqbhpq4PVKeFuWsxdTF7hfzoGc';
const _bootnodeHbs =
    '/dns4/prchbs.crcfrcn.com/tcp/30333/wss/p2p/'
    '12D3KooWMXQoZ9F6nxMuoC2ZnzxEKAn4z2qPKAugP2CZFEcXDqkT';

void main() {
  test('安装包 chainspec 只登记当前五个已部署 bootnode', () async {
    final spec =
        jsonDecode(await File('assets/chainspec.json').readAsString())
            as Map<String, dynamic>;
    expect(spec['bootNodes'], <String>[
      _bootnodeA,
      _bootnodeB,
      _bootnodeGzs,
      _bootnodeHes,
      _bootnodeHbs,
    ]);
  });

  test('随包 chainspec 注入固定 #0 lightSyncState', () async {
    final bundle = CitizenChainAssets.combine(
      chainSpecJson: await File('assets/chainspec.json').readAsString(),
      lightSyncStateJson: await File(
        'assets/light_sync_state.json',
      ).readAsString(),
    );
    expect(bundle.chainSpec, contains('lightSyncState'));
    expect(bundle.genesisHash, matches(RegExp(r'^0x[0-9a-f]{64}$')));
  });

  test('非 #0 checkpoint 必须拒绝', () {
    final header = '0x${List<String>.filled(32, '00').join()}04';
    expect(
      () => CitizenChainAssets.genesisHashFromCheckpoint(header),
      throwsFormatException,
    );
  });

  test('启动清单只接受 citizensdk schema 且不需要宿主服务字段', () {
    final manifest = BootstrapManifest.fromJson(<String, dynamic>{
      'ok': true,
      'schema': 'citizensdk.chain.bootstrap',
      'generated_at': 1,
      'cache_ttl_seconds': 300,
      'chain': <String, dynamic>{
        'chain_id': 'citizenchain',
        'protocol_id': 'citizenchain',
        'genesis_hash': '0x${List<String>.filled(32, '11').join()}',
        'state_root': '0x${List<String>.filled(32, '22').join()}',
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
        'bootnodes': <String>[],
        'min_peer_count_hint': 1,
      },
      'security': <String, dynamic>{
        'exposes_rpc_url': false,
        'rpc_proxy': false,
        'exposes_private_key_material': false,
        'validator_rpc_public': false,
      },
    });

    expect(manifest.isSafe, isTrue);
    expect(
      () => BootstrapManifest.fromJson(<String, dynamic>{
        'ok': true,
        'schema': 'otherproduct.chain.bootstrap',
      }),
      throwsA(isA<BootstrapManifestException>()),
    );
  });
}
