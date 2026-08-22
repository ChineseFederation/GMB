import 'dart:convert';

import 'package:citizenapp/isar/wallet_isar.dart';

/// 提案详情本地持久化读库。
///
/// 这里保存的是详情页首屏展示快照，降低页面进入时对链上 storage
/// 的同步等待；投票、执行和提交前复核仍必须重新读取链上真值。
class ProposalDetailLocalStore {
  ProposalDetailLocalStore._();

  static final ProposalDetailLocalStore instance = ProposalDetailLocalStore._();

  static const Duration activeTtl = Duration(seconds: 60);
  Future<ProposalDetailSnapshot?> read(String typeKey, int proposalId) {
    return WalletIsar.instance.read((isar) async {
      final entity = await isar.walletProposalDetailEntitys
          .getByProposalKey(key(typeKey, proposalId));
      return ProposalDetailSnapshot.fromJsonString(entity?.payloadJson);
    });
  }

  Future<void> put(ProposalDetailSnapshot snapshot) async {
    await WalletIsar.instance.writeTxn((isar) async {
      final proposalKey = key(snapshot.typeKey, snapshot.proposalId);
      final entity = await isar.walletProposalDetailEntitys
              .getByProposalKey(proposalKey) ??
          (WalletProposalDetailEntity()..proposalKey = proposalKey);
      entity
        ..payloadJson = jsonEncode(snapshot.toJson())
        ..updatedAtMillis = snapshot.updatedAtMillis
        ..isFinal = snapshot.isFinal;
      await isar.walletProposalDetailEntitys.putByProposalKey(entity);
    });
  }

  Future<void> clearAllForTest() async {
    await WalletIsar.instance.writeTxn((isar) async {
      await isar.walletProposalDetailEntitys.clear();
    });
  }

  static String key(String typeKey, int proposalId) => '$typeKey:$proposalId';
}

class ProposalDetailSnapshot {
  const ProposalDetailSnapshot({
    required this.proposalId,
    required this.typeKey,
    required this.updatedAtMillis,
    this.status,
    this.yesCount = 0,
    this.noCount = 0,
    this.threshold,
    this.admins = const [],
    this.adminVotes = const {},
    this.pendingPublicKeys = const [],
    this.detail = const {},
    this.extra = const {},
  });

  final int proposalId;
  final String typeKey;
  final int updatedAtMillis;
  final int? status;
  final int yesCount;
  final int noCount;
  final int? threshold;
  final List<String> admins;
  final Map<String, bool?> adminVotes;
  final List<String> pendingPublicKeys;
  final Map<String, Object?> detail;
  final Map<String, Object?> extra;

  bool get isFinal => status != null && status != 0;

  bool isFresh(Duration ttl) {
    if (isFinal) return true;
    return DateTime.now().millisecondsSinceEpoch - updatedAtMillis <
        ttl.inMilliseconds;
  }

  Map<String, Object?> toJson() => {
        'proposal_id': proposalId,
        'type_key': typeKey,
        'updated_at_millis': updatedAtMillis,
        'status': status,
        'yes_count': yesCount,
        'no_count': noCount,
        'threshold': threshold,
        'admins': admins,
        'admin_votes': adminVotes.map(
          (key, value) => MapEntry(key, value),
        ),
        'pending_signer_public_keys': pendingPublicKeys,
        'detail': detail,
        'extra': extra,
      };

  static ProposalDetailSnapshot? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final proposalId = _toInt(decoded['proposal_id']);
      final typeKey = decoded['type_key']?.toString();
      final updatedAtMillis = _toInt(decoded['updated_at_millis']);
      if (proposalId == null ||
          typeKey == null ||
          typeKey.isEmpty ||
          updatedAtMillis == null) {
        return null;
      }
      return ProposalDetailSnapshot(
        proposalId: proposalId,
        typeKey: typeKey,
        updatedAtMillis: updatedAtMillis,
        status: _toInt(decoded['status']),
        yesCount: _toInt(decoded['yes_count']) ?? 0,
        noCount: _toInt(decoded['no_count']) ?? 0,
        threshold: _toInt(decoded['threshold']),
        admins: _stringList(decoded['admins']),
        adminVotes: _voteMap(decoded['admin_votes']),
        pendingPublicKeys: _stringList(decoded['pending_signer_public_keys']),
        detail: _objectMap(decoded['detail']),
        extra: _objectMap(decoded['extra']),
      );
    } catch (_) {
      return null;
    }
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, bool?> _voteMap(Object? value) {
    if (value is! Map) return const {};
    final result = <String, bool?>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.isEmpty) continue;
      final raw = entry.value;
      if (raw is bool) {
        result[key] = raw;
      } else if (raw == null) {
        result[key] = null;
      } else if (raw.toString() == 'true') {
        result[key] = true;
      } else if (raw.toString() == 'false') {
        result[key] = false;
      }
    }
    return result;
  }

  static Map<String, Object?> _objectMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
