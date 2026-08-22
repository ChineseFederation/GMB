import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../support/isar_test_env.dart';

void main() {
  useIsolatedIsar();

  test('数据库重开只初始化钱包设置，不扫描或改写 Wallet typed 状态', () async {
    final isar = await WalletIsar.instance.db();
    await isar.writeTxn(() async {
      await isar.walletMembershipStateEntitys.putByStateKey(
        WalletMembershipStateEntity()
          ..stateKey = 'membership-a'
          ..payloadJson = 'keep-a',
      );
      await isar.walletCreatorStateEntitys.putByStateKey(
        WalletCreatorStateEntity()
          ..stateKey = 'creator-b'
          ..payloadJson = 'keep-b',
      );
    });

    await isar.close();
    final reopened = await WalletIsar.instance.db();
    expect(
      (await reopened.walletMembershipStateEntitys
              .getByStateKey('membership-a'))
          ?.payloadJson,
      'keep-a',
    );
    expect(
      (await reopened.walletCreatorStateEntitys.getByStateKey('creator-b'))
          ?.payloadJson,
      'keep-b',
    );
    expect(await reopened.walletSettingsEntitys.get(0), isNotNull);
  });

  test('钱包改名只更新本机钱包标签且不创建公开昵称同步状态', () async {
    final isar = await WalletIsar.instance.db();
    await isar.writeTxn(() async {
      await isar.walletProfileEntitys.put(
        WalletProfileEntity()
          ..walletIndex = 1
          ..walletName = '钱包1'
          ..walletIcon = 'wallet'
          ..balance = 0
          ..accountId =
              '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          ..masterId =
              '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          ..ss58Address = 'citizen_test_wallet'
          ..alg = 'sr25519'
          ..ss58 = 2027
          ..createdAtMillis = 1
          ..source = 'test'
          ..signMode = SignMode.hot.name,
      );
    });

    await WalletManager().renameWallet(1, '仅本机标签');

    final wallet = await isar.walletProfileEntitys
        .filter()
        .walletIndexEqualTo(1)
        .findFirst();
    expect(wallet?.walletName, '仅本机标签');
    expect(await isar.walletMembershipStateEntitys.count(), 0);
    expect(await isar.walletCreatorStateEntitys.count(), 0);
  });
}
