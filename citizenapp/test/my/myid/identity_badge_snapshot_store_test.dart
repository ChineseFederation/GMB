import 'package:citizenapp/my/myid/identity_badge_snapshot_store.dart';
import 'package:citizenapp/isar/user_isar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/isar_test_env.dart';

void main() {
  const cidA = 'GD-CTZN1-000000001-2026';
  const cidB = 'GD-CTZN1-000000002-2026';

  useIsolatedIsar();

  test('身份徽章快照按永久 CID 隔离', () async {
    final store = IdentityBadgeSnapshotStore(
      nowProvider: () => DateTime.fromMillisecondsSinceEpoch(1234),
    );

    await store.write(
      cidNumber: cidA,
      identityLevel: 'voting',
    );
    await store.write(
      cidNumber: cidB,
      identityLevel: 'candidate',
    );

    final citizenA = await store.read(cidA);
    final citizenB = await store.read(cidB);
    expect(citizenA?.identityLevel, 'voting');
    expect(citizenA?.updatedAtMillis, 1234);
    expect(citizenB?.identityLevel, 'candidate');
  });

  test('损坏快照按无展示处理且读取路径不删除事实', () async {
    final store = IdentityBadgeSnapshotStore();
    await UserIsar.instance.writeTxn((isar) async {
      await isar.userIdentityBadgeSnapshotEntitys.putByCidNumber(
        UserIdentityBadgeSnapshotEntity()
          ..cidNumber = cidA
          ..identityLevel = 'broken'
          ..updatedAtMillis = -1,
      );
    });
    expect(await store.read(cidA), isNull);
    final retained = await UserIsar.instance.read((isar) async =>
        isar.userIdentityBadgeSnapshotEntitys.getByCidNumber(cidA));
    expect(retained, isNotNull);
    expect(retained?.identityLevel, 'broken');
  });

  test('不接受非正式身份档', () async {
    final store = IdentityBadgeSnapshotStore();

    await expectLater(
      store.write(cidNumber: cidA, identityLevel: 'admin'),
      throwsArgumentError,
    );
    expect(await store.read(cidA), isNull);
  });
}
