import '../crypto/account_codec.dart';

/// 公民链启动清单校验错误。
final class BootstrapManifestException implements Exception {
  const BootstrapManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 只保留 CitizenSDK 轻节点所需字段的公民链启动清单。
///
/// SDK 只接受自己的 wire schema，不导入宿主产品的广场、聊天、媒体或交易中继配置。
final class BootstrapManifest {
  const BootstrapManifest({
    required this.generatedAt,
    required this.cacheTtlSeconds,
    required this.chain,
    required this.lightClient,
    required this.p2p,
    required this.security,
  });

  final int generatedAt;
  final int cacheTtlSeconds;
  final BootstrapChain chain;
  final BootstrapLightClient lightClient;
  final BootstrapP2p p2p;
  final BootstrapSecurity security;

  factory BootstrapManifest.fromJson(Map<String, dynamic> json) {
    if (_string(json, 'schema') != 'citizensdk.chain.bootstrap' ||
        json['ok'] != true) {
      throw const BootstrapManifestException('公民链启动清单 schema 或状态无效');
    }
    if (_containsForbiddenKey(json, const <String>{
      'rpc_url',
      'rpc_urls',
      'rpc_endpoint',
      'checkpoint',
      'checkpoint_url',
      'light_sync_state',
    })) {
      throw const BootstrapManifestException('启动清单不得下发 RPC 或 checkpoint');
    }
    final manifest = BootstrapManifest(
      generatedAt: _int(json, 'generated_at'),
      cacheTtlSeconds: _int(json, 'cache_ttl_seconds'),
      chain: BootstrapChain.fromJson(_map(json, 'chain')),
      lightClient: BootstrapLightClient.fromJson(_map(json, 'light_client')),
      p2p: BootstrapP2p.fromJson(_map(json, 'p2p')),
      security: BootstrapSecurity.fromJson(_map(json, 'security')),
    );
    if (!manifest.isSafe) {
      throw const BootstrapManifestException('启动清单违反公民链轻节点安全边界');
    }
    return manifest;
  }

  bool get isSafe =>
      chain.chainId == 'citizenchain' &&
      chain.ss58Format == citizenSs58Prefix &&
      lightClient.mode == 'smoldot' &&
      lightClient.truthSource == 'p2p_finalized_storage' &&
      !lightClient.apiIsTruth &&
      !security.exposesRpcUrl &&
      !security.rpcProxy &&
      !security.exposesPrivateKeyMaterial &&
      !security.validatorRpcPublic;
}

final class BootstrapChain {
  const BootstrapChain({
    required this.chainId,
    required this.protocolId,
    required this.genesisHash,
    required this.stateRoot,
    required this.ss58Format,
    required this.tokenSymbol,
    required this.tokenDecimals,
  });

  final String chainId;
  final String protocolId;
  final String genesisHash;
  final String stateRoot;
  final int ss58Format;
  final String tokenSymbol;
  final int tokenDecimals;

  factory BootstrapChain.fromJson(Map<String, dynamic> json) => BootstrapChain(
    chainId: _string(json, 'chain_id'),
    protocolId: _string(json, 'protocol_id'),
    genesisHash: _hex32(json, 'genesis_hash'),
    stateRoot: _hex32(json, 'state_root'),
    ss58Format: _int(json, 'ss58_format'),
    tokenSymbol: _string(json, 'token_symbol'),
    tokenDecimals: _int(json, 'token_decimals'),
  );
}

final class BootstrapLightClient {
  const BootstrapLightClient({
    required this.mode,
    required this.truthSource,
    required this.apiIsTruth,
    required this.bundledAssetsRequired,
  });

  final String mode;
  final String truthSource;
  final bool apiIsTruth;
  final List<String> bundledAssetsRequired;

  factory BootstrapLightClient.fromJson(Map<String, dynamic> json) {
    final assets = json['bundled_assets_required'];
    if (assets is! List ||
        assets.length != 2 ||
        assets[0] != 'assets/chainspec.json' ||
        assets[1] != 'assets/light_sync_state.json') {
      throw const BootstrapManifestException('启动清单的链资产声明无效');
    }
    return BootstrapLightClient(
      mode: _string(json, 'mode'),
      truthSource: _string(json, 'truth_source'),
      apiIsTruth: _bool(json, 'api_is_truth'),
      bundledAssetsRequired: List<String>.unmodifiable(assets.cast<String>()),
    );
  }
}

final class BootstrapP2p {
  const BootstrapP2p({required this.bootnodes, required this.minPeerCountHint});

  final List<String> bootnodes;
  final int minPeerCountHint;

  factory BootstrapP2p.fromJson(Map<String, dynamic> json) {
    final raw = json['bootnodes'];
    if (raw is! List) {
      throw const BootstrapManifestException('启动清单缺少 bootnodes');
    }
    final bootnodes = raw
        .whereType<String>()
        .where((value) => value.startsWith('/') && value.contains('/p2p/'))
        .toList(growable: false);
    return BootstrapP2p(
      bootnodes: List<String>.unmodifiable(bootnodes),
      minPeerCountHint: _int(json, 'min_peer_count_hint'),
    );
  }
}

final class BootstrapSecurity {
  const BootstrapSecurity({
    required this.exposesRpcUrl,
    required this.rpcProxy,
    required this.exposesPrivateKeyMaterial,
    required this.validatorRpcPublic,
  });

  final bool exposesRpcUrl;
  final bool rpcProxy;
  final bool exposesPrivateKeyMaterial;
  final bool validatorRpcPublic;

  factory BootstrapSecurity.fromJson(Map<String, dynamic> json) =>
      BootstrapSecurity(
        exposesRpcUrl: _bool(json, 'exposes_rpc_url'),
        rpcProxy: _bool(json, 'rpc_proxy'),
        exposesPrivateKeyMaterial: _bool(json, 'exposes_private_key_material'),
        validatorRpcPublic: _bool(json, 'validator_rpc_public'),
      );
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw BootstrapManifestException('$key 必须是 JSON 对象');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw BootstrapManifestException('$key 必须是非空字符串');
  }
  return value;
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw BootstrapManifestException('$key 必须是非负整数');
  }
  return value;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw BootstrapManifestException('$key 必须是布尔值');
  return value;
}

String _hex32(Map<String, dynamic> json, String key) {
  final value = _string(json, key).toLowerCase();
  if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(value)) {
    throw BootstrapManifestException('$key 必须是 32 字节 hex');
  }
  return value;
}

bool _containsForbiddenKey(Object? value, Set<String> forbidden) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (forbidden.contains('${entry.key}'.toLowerCase()) ||
          _containsForbiddenKey(entry.value, forbidden)) {
        return true;
      }
    }
  } else if (value is List) {
    return value.any((entry) => _containsForbiddenKey(entry, forbidden));
  }
  return false;
}
