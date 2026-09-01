import 'dart:convert';
import 'dart:io';

import 'package:citizen_sdk/src/node/chain_asset_manifest.dart';
import 'package:citizen_sdk/src/node/chain_assets.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetRoot = 'assets/citizenchain';

void main() {
  test('正式 manifest 逐项绑定 CitizenChain 三项链身份和两个资产摘要', () async {
    final manifestJson = await File('$_assetRoot/manifest.json').readAsString();
    final chainSpecJson = await File(
      '$_assetRoot/chainspec.json',
    ).readAsString();
    final lightSyncStateJson = await File(
      '$_assetRoot/light_sync_state.json',
    ).readAsString();
    final manifest = CitizenChainAssetManifest.parse(manifestJson);
    final chainSpec = jsonDecode(chainSpecJson) as Map<String, dynamic>;
    final lightSyncState =
        jsonDecode(lightSyncStateJson) as Map<String, dynamic>;
    final genesisHash = CitizenChainAssets.genesisHashFromCheckpoint(
      lightSyncState['finalizedBlockHeader'] as String,
    );

    manifest.verifyDigests(
      chainSpecJson: chainSpecJson,
      lightSyncStateJson: lightSyncStateJson,
    );
    manifest.verifyIdentity(
      actualChainId: chainSpec['id'] as String,
      actualProtocolId: chainSpec['protocolId'] as String,
      actualGenesisHash: genesisHash,
    );

    expect(manifest.productId, 'citizensdk');
    expect(manifest.chainId, 'citizenchain');
    expect(manifest.protocolId, 'citizenchain');
    expect(
      manifest.genesisHash,
      '0x18847a5dfd263272f2e7727836fe6582f8c4463ff48609df7b96d5e4d9dd24dd',
    );
  });

  test('manifest 精确拒绝未知字段、第二套链名和错误格式版本', () async {
    final source =
        jsonDecode(await File('$_assetRoot/manifest.json').readAsString())
            as Map<String, dynamic>;
    final mutations = <Map<String, dynamic> Function()>[
      () => Map<String, dynamic>.from(source)..['unexpected'] = true,
      () => Map<String, dynamic>.from(source)..remove('chain_id'),
      () =>
          Map<String, dynamic>.from(source)
            ..['chain_id'] = 'citizenchain-mainnet',
      () =>
          Map<String, dynamic>.from(source)
            ..['protocol_id'] = 'citizenchain-mainnet',
      () => Map<String, dynamic>.from(source)..['format_version'] = 2,
      () => Map<String, dynamic>.from(source)..['sdk_min_version'] = '1.0.1',
    ];

    for (final mutate in mutations) {
      expect(
        () => CitizenChainAssetManifest.parse(jsonEncode(mutate())),
        throwsFormatException,
      );
    }
  });

  test('manifest 拒绝任一资产或 genesis hash 漂移', () async {
    final manifest = CitizenChainAssetManifest.parse(
      await File('$_assetRoot/manifest.json').readAsString(),
    );
    final chainSpecJson = await File(
      '$_assetRoot/chainspec.json',
    ).readAsString();
    final lightSyncStateJson = await File(
      '$_assetRoot/light_sync_state.json',
    ).readAsString();

    expect(
      () => manifest.verifyDigests(
        chainSpecJson: '$chainSpecJson\n',
        lightSyncStateJson: lightSyncStateJson,
      ),
      throwsFormatException,
    );
    expect(
      () => manifest.verifyDigests(
        chainSpecJson: chainSpecJson,
        lightSyncStateJson: '$lightSyncStateJson\n',
      ),
      throwsFormatException,
    );
    expect(
      () => manifest.verifyIdentity(
        actualChainId: 'citizenchain',
        actualProtocolId: 'citizenchain',
        actualGenesisHash: '0x${'00' * 32}',
      ),
      throwsFormatException,
    );
    expect(
      () => manifest.verifyIdentity(
        actualChainId: 'citizenchain-mainnet',
        actualProtocolId: 'citizenchain',
        actualGenesisHash: manifest.genesisHash,
      ),
      throwsFormatException,
    );
    expect(
      () => manifest.verifyIdentity(
        actualChainId: 'citizenchain',
        actualProtocolId: 'citizenchain-mainnet',
        actualGenesisHash: manifest.genesisHash,
      ),
      throwsFormatException,
    );
  });

  test('资产摘要漂移必须先于损坏 JSON 内容解析而失败', () async {
    final manifestJson = await File('$_assetRoot/manifest.json').readAsString();
    final lightSyncStateJson = await File(
      '$_assetRoot/light_sync_state.json',
    ).readAsString();

    expect(
      () => CitizenChainAssets.combine(
        assetManifestJson: manifestJson,
        chainSpecJson: '{不是有效 JSON',
        lightSyncStateJson: lightSyncStateJson,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'CitizenChain chainspec SHA-256 不匹配',
        ),
      ),
    );
  });
}
