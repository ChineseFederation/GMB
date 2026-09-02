import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('钱包公开模型复制列表与签名字节', () {
    final accounts = <CitizenAccount>[
      CitizenAccount(
        index: 0,
        accountId: _account(1),
        ss58Address: 'CitizenAddress',
        name: '主账户',
        createdAtMillis: BigInt.one,
        isActive: true,
      ),
    ];
    final profile = CitizenWalletProfile(
      walletIndex: 0,
      masterAccountId: _account(1),
      origin: CitizenWalletOrigin.created,
      createdAtMillis: BigInt.one,
      activeAccountId: _account(1),
      accounts: accounts,
    );
    accounts.clear();
    expect(profile.accounts, hasLength(1));

    final source = Uint8List.fromList(List<int>.filled(64, 7));
    final signature = CitizenWalletSignature(
      accountId: _account(1),
      bytes: source,
    );
    source.fillRange(0, source.length, 0);
    expect(signature.bytes, everyElement(7));
  });

  test('交易历史复制三个集合和公开remark bytes', () {
    final transfer = CitizenFinalizedTransfer(
      trackedAccountId: _account(1),
      fromAccountId: _account(1),
      toAccountId: _account(2),
      amountFen: BigInt.from(100),
      block: CitizenBlockRef(
        hash: _account(3),
        number: BigInt.one,
        finality: CitizenBlockFinality.finalized,
      ),
      eventRecordIndex: 0,
      extrinsicIndex: 1,
      direction: CitizenTransferDirection.outgoing,
      sourcePallet: 'OnchainTransaction',
      remarkDisplay: '公开备注',
      remarkBytes: Uint8List.fromList(<int>[1, 2]),
    );
    final transfers = <CitizenFinalizedTransfer>[transfer];
    final history = CitizenTransactionHistory(
      revision: BigInt.one,
      cursors: const <CitizenHistoryCursor>[],
      records: const <CitizenHistoryRecord>[],
      transfers: transfers,
    );
    transfers.clear();
    expect(history.transfers.single.remarkDisplay, '公开备注');
  });
}

String _account(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';
