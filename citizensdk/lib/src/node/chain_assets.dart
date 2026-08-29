import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:polkadart/polkadart.dart' show Hasher;

import 'bootstrap_manifest.dart';

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

  static const chainSpecAsset = 'packages/citizen_sdk/assets/chainspec.json';
  static const lightSyncStateAsset =
      'packages/citizen_sdk/assets/light_sync_state.json';

  final AssetBundle? _bundle;

  Future<CitizenChainBundle> load({BootstrapManifest? bootstrap}) async {
    final bundle = _bundle ?? rootBundle;
    final rawChainSpec = await bundle.loadString(chainSpecAsset);
    final rawLightSyncState = await bundle.loadString(lightSyncStateAsset);
    return combine(
      chainSpecJson: rawChainSpec,
      lightSyncStateJson: rawLightSyncState,
      bootstrap: bootstrap,
    );
  }

  static CitizenChainBundle combine({
    required String chainSpecJson,
    required String lightSyncStateJson,
    BootstrapManifest? bootstrap,
  }) {
    final chainSpec = _jsonObject(chainSpecJson, 'chainspec.json');
    if (bootstrap != null && _matchesLocalSpec(chainSpec, bootstrap)) {
      final existing =
          (chainSpec['bootNodes'] as List?)?.cast<Object?>() ?? <Object?>[];
      for (final bootnode in bootstrap.p2p.bootnodes.reversed) {
        existing.removeWhere((entry) => entry == bootnode);
        existing.insert(0, bootnode);
      }
      chainSpec['bootNodes'] = existing;
    }

    final lightSyncState = _jsonObject(
      lightSyncStateJson,
      'light_sync_state.json',
    );
    final headerHex = lightSyncState['finalizedBlockHeader'];
    if (headerHex is! String ||
        lightSyncState['grandpaAuthoritySet'] is! String) {
      throw const FormatException('light_sync_state.json 缺少必要 checkpoint 字段');
    }
    final genesisHash = genesisHashFromCheckpoint(headerHex);
    if (bootstrap != null && bootstrap.chain.genesisHash != genesisHash) {
      throw const FormatException('远端启动清单与随包 genesis 不一致');
    }
    chainSpec['lightSyncState'] = lightSyncState;
    return CitizenChainBundle(
      chainSpec: jsonEncode(chainSpec),
      genesisHash: genesisHash,
    );
  }

  static String genesisHashFromCheckpoint(String headerHex) {
    final header = _decodeHex(headerHex, 'finalizedBlockHeader');
    if (header.length <= 32 || header[32] != 0) {
      throw const FormatException('内置 lightSyncState 必须固定为创世块 #0');
    }
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
