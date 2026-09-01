import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

/// CitizenSDK 随包链资产的类型化信任清单。
///
/// 清单只绑定 CitizenChain 静态资产，不接收远端覆盖。解析器使用精确字段闭集，避免未来新增
/// 字段被旧 SDK 静默忽略后改变信任语义。
final class CitizenChainAssetManifest {
  const CitizenChainAssetManifest._({
    required this.formatVersion,
    required this.productId,
    required this.chainId,
    required this.protocolId,
    required this.genesisHash,
    required this.chainSpecSha256,
    required this.lightSyncStateSha256,
    required this.sdkMinVersion,
  });

  static const supportedFormatVersion = 1;
  static const expectedProductId = 'citizensdk';
  static const expectedChainId = 'citizenchain';
  static const expectedProtocolId = 'citizenchain';
  static const supportedSdkMinVersion = '1.0.0';

  static const _keys = <String>{
    'format_version',
    'product_id',
    'chain_id',
    'protocol_id',
    'genesis_hash',
    'chainspec_sha256',
    'light_sync_state_sha256',
    'sdk_min_version',
  };
  static final _hex32 = RegExp(r'^0x[0-9a-f]{64}$');
  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  final int formatVersion;
  final String productId;
  final String chainId;
  final String protocolId;
  final String genesisHash;
  final String chainSpecSha256;
  final String lightSyncStateSha256;
  final String sdkMinVersion;

  factory CitizenChainAssetManifest.parse(String raw) {
    if (raw.trim().isEmpty) {
      throw const FormatException('CitizenChain 资产 manifest 为空');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('CitizenChain 资产 manifest 必须是 JSON 对象');
    }
    final actualKeys = decoded.keys.toSet();
    if (actualKeys.length != _keys.length || !actualKeys.containsAll(_keys)) {
      throw const FormatException('CitizenChain 资产 manifest 字段集合不正确');
    }

    final formatVersion = decoded['format_version'];
    final productId = decoded['product_id'];
    final chainId = decoded['chain_id'];
    final protocolId = decoded['protocol_id'];
    final genesisHash = decoded['genesis_hash'];
    final chainSpecSha256 = decoded['chainspec_sha256'];
    final lightSyncStateSha256 = decoded['light_sync_state_sha256'];
    final sdkMinVersion = decoded['sdk_min_version'];

    if (formatVersion is! int || formatVersion != supportedFormatVersion) {
      throw const FormatException(
        'CitizenChain 资产 manifest format_version 不受支持',
      );
    }
    if (productId is! String || productId != expectedProductId) {
      throw const FormatException('CitizenChain 资产 manifest product_id 不正确');
    }
    if (chainId is! String || chainId != expectedChainId) {
      throw const FormatException('CitizenChain 资产 manifest chain_id 不正确');
    }
    if (protocolId is! String || protocolId != expectedProtocolId) {
      throw const FormatException('CitizenChain 资产 manifest protocol_id 不正确');
    }
    if (genesisHash is! String || !_hex32.hasMatch(genesisHash)) {
      throw const FormatException('CitizenChain 资产 manifest genesis_hash 无效');
    }
    if (chainSpecSha256 is! String || !_sha256.hasMatch(chainSpecSha256)) {
      throw const FormatException(
        'CitizenChain 资产 manifest chainspec_sha256 无效',
      );
    }
    if (lightSyncStateSha256 is! String ||
        !_sha256.hasMatch(lightSyncStateSha256)) {
      throw const FormatException(
        'CitizenChain 资产 manifest light_sync_state_sha256 无效',
      );
    }
    if (sdkMinVersion is! String || sdkMinVersion != supportedSdkMinVersion) {
      throw const FormatException(
        'CitizenChain 资产 manifest sdk_min_version 不受支持',
      );
    }

    return CitizenChainAssetManifest._(
      formatVersion: formatVersion,
      productId: productId,
      chainId: chainId,
      protocolId: protocolId,
      genesisHash: genesisHash,
      chainSpecSha256: chainSpecSha256,
      lightSyncStateSha256: lightSyncStateSha256,
      sdkMinVersion: sdkMinVersion,
    );
  }

  /// 对原始 UTF-8 JSON 文本执行逐字节摘要核验。
  void verifyDigests({
    required String chainSpecJson,
    required String lightSyncStateJson,
  }) {
    if (sha256Utf8(chainSpecJson) != chainSpecSha256) {
      throw const FormatException('CitizenChain chainspec SHA-256 不匹配');
    }
    if (sha256Utf8(lightSyncStateJson) != lightSyncStateSha256) {
      throw const FormatException('CitizenChain light sync state SHA-256 不匹配');
    }
  }

  /// 在摘要通过后核对 chainspec、checkpoint 与 manifest 的同一链身份。
  void verifyIdentity({
    required String actualChainId,
    required String actualProtocolId,
    required String actualGenesisHash,
  }) {
    if (actualChainId != chainId) {
      throw const FormatException('CitizenChain chainspec id 与 manifest 不匹配');
    }
    if (actualProtocolId != protocolId) {
      throw const FormatException(
        'CitizenChain chainspec protocolId 与 manifest 不匹配',
      );
    }
    if (actualGenesisHash.toLowerCase() != genesisHash) {
      throw const FormatException('CitizenChain genesis hash 与 manifest 不匹配');
    }
  }

  /// 测试和 Release 合同共用的 UTF-8 文本摘要算法。
  static String sha256Utf8(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
