import 'dart:convert';

/// smoldot finalized database 的公开数据存储接口。
///
/// 数据库正文只包含已验证链状态和已知 peer，不得与钱包金库共用命名空间。
abstract interface class ChainDatabaseStore {
  Future<String?> read();

  Future<void> write(String envelope);

  Future<void> delete();
}

/// CitizenSDK 本机 finalized database 的版本化信封。
final class ChainDatabaseEnvelope {
  ChainDatabaseEnvelope({
    required String genesisHash,
    required this.finalizedBlockNumber,
    required String finalizedBlockHash,
    required this.databaseContent,
  }) : genesisHash = genesisHash.toLowerCase(),
       finalizedBlockHash = finalizedBlockHash.toLowerCase();

  static const schema = 'citizen_sdk.smoldot.database.v1';
  static const maxDatabaseBytes = 256 * 1024;
  static final RegExp _hex32 = RegExp(r'^0x[0-9a-f]{64}$');

  final String genesisHash;
  final int finalizedBlockNumber;
  final String finalizedBlockHash;
  final String databaseContent;

  factory ChainDatabaseEnvelope.parse(
    String raw, {
    required String expectedGenesisHash,
  }) {
    final decoded = jsonDecode(raw);
    const requiredKeys = <String>{
      'schema',
      'genesis_hash',
      'finalized_block_number',
      'finalized_block_hash',
      'database_content',
    };
    if (decoded is! Map<String, dynamic> ||
        decoded.length != requiredKeys.length ||
        !requiredKeys.every(decoded.containsKey) ||
        decoded['schema'] != schema) {
      throw const FormatException('同步数据库信封 schema 或字段无效');
    }
    final genesisHash = decoded['genesis_hash'];
    final finalizedBlockNumber = decoded['finalized_block_number'];
    final finalizedBlockHash = decoded['finalized_block_hash'];
    final databaseContent = decoded['database_content'];
    if (genesisHash is! String ||
        finalizedBlockNumber is! int ||
        finalizedBlockHash is! String ||
        databaseContent is! String) {
      throw const FormatException('同步数据库信封字段类型无效');
    }
    final envelope = ChainDatabaseEnvelope(
      genesisHash: genesisHash,
      finalizedBlockNumber: finalizedBlockNumber,
      finalizedBlockHash: finalizedBlockHash,
      databaseContent: databaseContent,
    );
    envelope.validate();
    if (envelope.genesisHash != expectedGenesisHash.toLowerCase()) {
      throw const FormatException('同步数据库不属于当前公民链 genesis');
    }
    return envelope;
  }

  void validate() {
    if (!_hex32.hasMatch(genesisHash) ||
        !_hex32.hasMatch(finalizedBlockHash) ||
        finalizedBlockNumber < 0) {
      throw const FormatException('同步数据库 finalized 锚点无效');
    }
    final length = utf8.encode(databaseContent).length;
    if (length == 0 || length > maxDatabaseBytes) {
      throw const FormatException('同步数据库正文大小无效');
    }
  }

  String encode() {
    validate();
    return jsonEncode(<String, Object>{
      'schema': schema,
      'genesis_hash': genesisHash,
      'finalized_block_number': finalizedBlockNumber,
      'finalized_block_hash': finalizedBlockHash,
      'database_content': databaseContent,
    });
  }
}
