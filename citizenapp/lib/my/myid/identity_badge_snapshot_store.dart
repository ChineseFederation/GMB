import 'package:citizenapp/isar/user_isar.dart';

/// 单个永久 CID 的公开链上身份徽章快照。
///
/// 这里只保存 `visitor` / `voting` / `candidate` 展示信号，不保存护照详情、
/// 私钥或签名材料。快照用于非链页面展示，不得作为发布、投票或权限判断依据。
class IdentityBadgeSnapshot {
  const IdentityBadgeSnapshot({
    required this.cidNumber,
    required this.identityLevel,
    required this.updatedAtMillis,
  });

  final String cidNumber;
  final String identityLevel;
  final int updatedAtMillis;
}

/// 按永久 CID 隔离的身份徽章持久快照。
///
/// 钱包账户只负责取得最新链上快照；换绑后新账户继续读写同一个 CID 键。
class IdentityBadgeSnapshotStore {
  IdentityBadgeSnapshotStore({
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  static const _allowedLevels = {'visitor', 'voting', 'candidate'};

  final DateTime Function() _nowProvider;

  Future<IdentityBadgeSnapshot?> read(String cidNumber) async {
    final normalizedCidNumber = cidNumber.trim();
    if (normalizedCidNumber.isEmpty) return null;

    final row = await UserIsar.instance.read((isar) async => isar
        .userIdentityBadgeSnapshotEntitys
        .getByCidNumber(normalizedCidNumber));
    if (row == null) return null;
    if (row.cidNumber != normalizedCidNumber ||
        !_allowedLevels.contains(row.identityLevel) ||
        row.updatedAtMillis < 0) {
      // 展示缓存损坏时按无快照处理，但读取路径绝不删除事实。
      return null;
    }
    return IdentityBadgeSnapshot(
      cidNumber: normalizedCidNumber,
      identityLevel: row.identityLevel,
      updatedAtMillis: row.updatedAtMillis,
    );
  }

  Future<void> write({
    required String cidNumber,
    required String identityLevel,
  }) async {
    final normalizedCidNumber = cidNumber.trim();
    if (normalizedCidNumber.isEmpty) {
      throw ArgumentError.value(
        cidNumber,
        'cidNumber',
        'cid_number 不能为空',
      );
    }
    if (!_allowedLevels.contains(identityLevel)) {
      throw ArgumentError.value(
        identityLevel,
        'identityLevel',
        '身份档必须是 visitor、voting 或 candidate',
      );
    }

    await UserIsar.instance.writeTxn((isar) async {
      await isar.userIdentityBadgeSnapshotEntitys.putByCidNumber(
        UserIdentityBadgeSnapshotEntity()
          ..cidNumber = normalizedCidNumber
          ..identityLevel = identityLevel
          ..updatedAtMillis = _nowProvider().millisecondsSinceEpoch,
      );
    });
  }

  Future<void> remove(String cidNumber) async {
    final normalizedCidNumber = cidNumber.trim();
    if (normalizedCidNumber.isEmpty) return;
    await UserIsar.instance.writeTxn((isar) async {
      await isar.userIdentityBadgeSnapshotEntitys
          .deleteByCidNumber(normalizedCidNumber);
    });
  }
}
