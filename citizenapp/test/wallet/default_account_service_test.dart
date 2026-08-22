import 'dart:typed_data';

import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/qr/qr_protocols.dart';
import 'package:citizenapp/signer/signing.dart';
import 'package:citizenapp/wallet/core/default_account_service.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../support/isar_test_env.dart';

const _account0 =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _account5 =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _coldAccount =
    '0x3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  useIsolatedIsar();

  tearDown(() {
    DefaultAccountService.debugBeforeOrderCommit = null;
  });

  Future<void> seedAccounts({List<String> storedOrder = const []}) async {
    await WalletIsar.instance.writeTxn((isar) async {
      await isar.walletProfileEntitys.put(
        WalletProfileEntity()
          ..walletIndex = 1
          ..walletName = '热钱包'
          ..walletIcon = 'wallet'
          ..balance = 0
          ..accountId = _account0
          ..masterId = _account0
          ..ss58Address = ss58FromAccountIdText(_account0)
          ..alg = 'sr25519'
          ..ss58 = 2027
          ..createdAtMillis = 1
          ..source = 'test'
          ..signMode = SignMode.hot.name,
      );
      for (final row in <({String accountId, int accountIndex})>[
        (accountId: _account0, accountIndex: 0),
        (accountId: _account5, accountIndex: 5),
      ]) {
        await isar.accountEntitys.put(
          AccountEntity()
            ..masterId = _account0
            ..accountIndex = row.accountIndex
            ..accountId = row.accountId
            ..ss58Address = ss58FromAccountIdText(row.accountId)
            ..accountName = '账户${row.accountIndex}'
            ..createdAtMillis = row.accountIndex,
        );
      }
      await isar.walletProfileEntitys.put(
        WalletProfileEntity()
          ..walletIndex = 2
          ..walletName = '冷钱包'
          ..walletIcon = 'wallet'
          ..balance = 0
          ..accountId = _coldAccount
          ..masterId = _coldAccount
          ..ss58Address = ss58FromAccountIdText(_coldAccount)
          ..alg = 'sr25519'
          ..ss58 = 2027
          ..createdAtMillis = 2
          ..source = 'test'
          ..signMode = SignMode.cold.name,
      );
      await isar.walletSettingsEntitys.put(
        WalletSettingsEntity()
          ..id = 0
          ..orderedAccountIds = storedOrder
          ..updatedAtMillis = 1,
      );
    });
  }

  test('冷热账户统一排序，第一项是唯一默认账户并清理无效顺序残留', () async {
    await seedAccounts(storedOrder: [
      _coldAccount,
      _coldAccount,
      '0x${'44' * 32}',
    ]);
    final service = DefaultAccountService();

    final accounts = await service.getAccounts();

    expect(
      accounts.map((account) => account.accountId),
      [_coldAccount, _account0, _account5],
    );
    expect(accounts.first.isColdAccount, isTrue);
    final stored = await WalletIsar.instance.read(
      (isar) => isar.walletSettingsEntitys.get(0),
    );
    expect(stored!.orderedAccountIds, [_coldAccount, _account0, _account5]);
  });

  test('第一项不变可直接持久化；第一项变化必须进入原默认账户签名流程', () async {
    await seedAccounts(storedOrder: [_account0, _account5, _coldAccount]);
    final service = DefaultAccountService();

    await service.persistOrderWithoutDefaultChange(
      [_account0, _coldAccount, _account5],
    );
    expect(
      (await service.getAccounts()).map((account) => account.accountId),
      [_account0, _coldAccount, _account5],
    );

    await expectLater(
      service.persistOrderWithoutDefaultChange(
        [_coldAccount, _account0, _account5],
      ),
      throwsA(isA<WalletAuthException>()),
    );
  });

  test('无签名重排在读后被新顺序抢先提交时 CAS 拒绝旧盲写', () async {
    await seedAccounts(storedOrder: [_account0, _account5, _coldAccount]);
    final service = DefaultAccountService();
    const competingOrder = <String>[_coldAccount, _account0, _account5];
    DefaultAccountService.debugBeforeOrderCommit = () async {
      DefaultAccountService.debugBeforeOrderCommit = null;
      await WalletIsar.instance.writeTxn((isar) async {
        final settings = (await isar.walletSettingsEntitys.get(0))!;
        settings.orderedAccountIds = competingOrder;
        settings.updatedAtMillis += 1;
        await isar.walletSettingsEntitys.put(settings);
      });
    };

    await expectLater(
      service.persistOrderWithoutDefaultChange(
        const <String>[_account0, _coldAccount, _account5],
      ),
      throwsA(isA<WalletAuthException>()),
    );

    final stored = await WalletIsar.instance.read(
      (isar) => isar.walletSettingsEntitys.get(0),
    );
    expect(stored!.orderedAccountIds, competingOrder);
  });

  test('0x21 授权覆盖原默认账户、完整目标顺序、期限和随机 nonce', () async {
    await seedAccounts(storedOrder: [_account0, _account5, _coldAccount]);
    final service = DefaultAccountService();
    final authorization = await service.prepareSwitch(
      genesisHash: Uint8List(32),
      orderedAccountIds: [_account5, _account0, _coldAccount],
      nowEpochSeconds: 100,
    );

    expect(authorization.currentDefaultAccount.accountId, _account0);
    expect(authorization.issuedAt, 100);
    expect(authorization.expiresAt, 190);
    expect(authorization.payload.length, 32 + 32 + 1 + 3 * 32 + 8 + 16);
    expect(authorization.payload.sublist(0, 32), everyElement(0));
    expect(authorization.payload[64], 3 << 2);
    expect(
      authorization.signingMessage,
      signingMessage(
        opTag: kOpSignSwitchDefaultAccount,
        scalePayload: authorization.payload,
      ),
    );
  });

  test('冷钱包作为原默认账户时生成 QR_V1 的 switch_default_account 请求', () async {
    await seedAccounts(storedOrder: [_coldAccount, _account0, _account5]);
    final service = DefaultAccountService();
    final authorization = await service.prepareSwitch(
      genesisHash: Uint8List.fromList(List<int>.filled(32, 7)),
      orderedAccountIds: [_account0, _coldAccount, _account5],
      nowEpochSeconds: 100,
    );

    final request = service.buildColdRequest(authorization);

    expect(request.body.action, QrActions.switchDefaultAccount);
    expect(request.body.signerPublicKeyHex, _coldAccount);
    expect(request.id, authorization.requestId);
    expect(request.expiresAt, authorization.expiresAt);
  });

  test('签名授权后顺序或账户事实换代时 CAS 不覆盖新代', () async {
    await seedAccounts(storedOrder: [_account0, _account5, _coldAccount]);
    final service = DefaultAccountService();
    final authorization = await service.prepareSwitch(
      genesisHash: Uint8List(32),
      orderedAccountIds: const <String>[
        _account5,
        _account0,
        _coldAccount,
      ],
    );
    const competingOrder = <String>[_coldAccount, _account5, _account0];
    DefaultAccountService.debugBeforeOrderCommit = () async {
      DefaultAccountService.debugBeforeOrderCommit = null;
      await WalletIsar.instance.writeTxn((isar) async {
        final settings = (await isar.walletSettingsEntitys.get(0))!;
        settings.orderedAccountIds = competingOrder;
        await isar.walletSettingsEntitys.put(settings);
        final account = await isar.accountEntitys
            .filter()
            .accountIdEqualTo(_account5)
            .findFirst();
        account!.accountName = '新代账户名';
        await isar.accountEntitys.put(account);
      });
    };

    await expectLater(
      service.debugCommitAuthorization(authorization),
      throwsA(isA<WalletAuthException>()),
    );

    final facts = await WalletIsar.instance.read((isar) async {
      final settings = await isar.walletSettingsEntitys.get(0);
      final account = await isar.accountEntitys
          .filter()
          .accountIdEqualTo(_account5)
          .findFirst();
      return (order: settings!.orderedAccountIds, name: account!.accountName);
    });
    expect(facts.order, competingOrder);
    expect(facts.name, '新代账户名');
  });
}
