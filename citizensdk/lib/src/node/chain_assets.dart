import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:polkadart/polkadart.dart' show Hasher;

import 'bootstrap_manifest.dart';
import 'chain_asset_manifest.dart';

/// 注入固定创世 checkpoint 后的公民链规格。
final class CitizenChainBundle {
  const CitizenChainBundle({
    required this.chainSpec,
    required this.genesisHash,
  });

  final String chainSpec;
  final String genesisHash;
}

/// CitizenSDK 随包链资产加载器。
final class CitizenChainAssets {
  const CitizenChainAssets({AssetBundle? bundle}) : _bundle = bundle;

  static const _assetRoot = 'packages/citizen_sdk/assets/citizenchain';
  static const manifestAsset = '$_assetRoot/manifest.json';
  static const chainSpecAsset = '$_assetRoot/chainspec.json';
  static const lightSyncStateAsset = '$_assetRoot/light_sync_state.json';

  final AssetBundle? _bundle;

  Future<CitizenChainBundle> load({BootstrapManifest? bootstrap}) async {
    final bundle = _bundle ?? rootBundle;
    final rawManifest = await bundle.loadString(manifestAsset);
    final rawChainSpec = await bundle.loadString(chainSpecAsset);
    final rawLightSyncState = await bundle.loadString(lightSyncStateAsset);
    return combine(
      assetManifestJson: rawManifest,
      chainSpecJson: rawChainSpec,
      lightSyncStateJson: rawLightSyncState,
      bootstrap: bootstrap,
    );
  }

  static CitizenChainBundle combine({
    required String assetManifestJson,
    required String chainSpecJson,
    required String lightSyncStateJson,
    BootstrapManifest? bootstrap,
  }) {
    final assetManifest = CitizenChainAssetManifest.parse(assetManifestJson);
    // 摘要必须先于任何链内容消费通过；损坏或被替换的 JSON 不能进入 smoldot。
    assetManifest.verifyDigests(
      chainSpecJson: chainSpecJson,
      lightSyncStateJson: lightSyncStateJson,
    );
    final chainSpec = _jsonObject(chainSpecJson, 'chainspec.json');
    final lightSyncState = _jsonObject(
      lightSyncStateJson,
      'light_sync_state.json',
    );
    final headerHex = lightSyncState['finalizedBlockHeader'];
    final authoritySetHex = lightSyncState['grandpaAuthoritySet'];
    if (headerHex is! String || authoritySetHex is! String) {
      throw const FormatException('light_sync_state.json 缺少必要 checkpoint 字段');
    }
    _decodeHex(authoritySetHex, 'grandpaAuthoritySet');
    final checkpointBytes = _decodeGenesisCheckpoint(headerHex);
    final genesisHash = _genesisHash(checkpointBytes);
    final chainId = chainSpec['id'];
    final protocolId = chainSpec['protocolId'];
    if (chainId is! String || protocolId is! String) {
      throw const FormatException('chainspec 缺少字符串 id 或 protocolId');
    }
    final genesis = chainSpec['genesis'];
    final stateRoot = genesis is Map ? genesis['stateRootHash'] : null;
    final checkpointStateRoot = '0x${_hex(checkpointBytes.sublist(33, 65))}';
    if (stateRoot is! String ||
        stateRoot.toLowerCase() != checkpointStateRoot) {
      throw const FormatException(
        'chainspec stateRootHash 与 #0 checkpoint 不匹配',
      );
    }
    assetManifest.verifyIdentity(
      actualChainId: chainId,
      actualProtocolId: protocolId,
      actualGenesisHash: genesisHash,
    );
    // 远端清单只是非权威 bootnode 建议。任何链参数或 genesis 不匹配都必须
    // 忽略清单并继续使用随包 chainspec，不能让远端配置阻断本地可信
    // 启动路径。
    if (bootstrap != null &&
        bootstrap.chain.genesisHash == genesisHash &&
        _matchesLocalSpec(chainSpec, bootstrap)) {
      final existing =
          (chainSpec['bootNodes'] as List?)?.cast<Object?>() ?? <Object?>[];
      for (final bootnode in bootstrap.p2p.bootnodes.reversed) {
        existing.removeWhere((entry) => entry == bootnode);
        existing.insert(0, bootnode);
      }
      chainSpec['bootNodes'] = existing;
    }
    chainSpec['lightSyncState'] = lightSyncState;
    return CitizenChainBundle(
      chainSpec: jsonEncode(chainSpec),
      genesisHash: genesisHash,
    );
  }

  static String genesisHashFromCheckpoint(String headerHex) {
    return _genesisHash(_decodeGenesisCheckpoint(headerHex));
  }

  static Uint8List _decodeGenesisCheckpoint(String headerHex) {
    final header = _decodeHex(headerHex, 'finalizedBlockHeader');
    // Substrate header 前 32 字节是 parent hash，第 33 字节是 compact 编码的块高。
    // #0 必须编码为单字节 0；随后至少要包含 32 字节 state root。
    if (header.length < 65 || header[32] != 0) {
      throw const FormatException('内置 lightSyncState 必须固定为完整创世块 #0 header');
    }
    return header;
  }

  static String _genesisHash(Uint8List header) {
    final hash = Hasher.blake2b256.hash(header);
    return '0x${_hex(hash)}';
  }

  static bool _matchesLocalSpec(
    Map<String, dynamic> spec,
    BootstrapManifest manifest,
  ) {
    final genesis = spec['genesis'];
    final properties = spec['properties'];
    final stateRoot = genesis is Map ? genesis['stateRootHash'] : null;
    final ss58 = properties is Map ? properties['ss58Format'] : null;
    return spec['id'] == manifest.chain.chainId &&
        spec['protocolId'] == manifest.chain.protocolId &&
        stateRoot is String &&
        stateRoot.toLowerCase() == manifest.chain.stateRoot &&
        ss58 == manifest.chain.ss58Format;
  }

  static Map<String, dynamic> _jsonObject(String raw, String name) {
    if (raw.trim().isEmpty) throw FormatException('$name 为空');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$name 必须是 JSON 对象');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Uint8List _decodeHex(String value, String fieldName) {
    final clean = value.startsWith('0x') ? value.substring(2) : value;
    if (clean.isEmpty ||
        clean.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw FormatException('$fieldName 不是有效 hex');
    }
    return Uint8List.fromList(<int>[
      for (var offset = 0; offset < clean.length; offset += 2)
        int.parse(clean.substring(offset, offset + 2), radix: 16),
    ]);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
