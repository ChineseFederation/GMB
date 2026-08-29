import 'dart:typed_data';

import 'package:citizen_sdk/src/transaction/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transfer_with_remark call 保持 pallet/call 与 u128 分单位', () {
    final call = TransferService.buildTransferWithRemarkCall(
      destinationPublicKey: Uint8List.fromList(
        List<int>.generate(32, (i) => i),
      ),
      amountFen: BigInt.from(100),
      remark: 'hi',
    );
    expect(call[0], 4);
    expect(call[1], 0);
    expect(
      call.sublist(2, 34),
      orderedEquals(List<int>.generate(32, (i) => i)),
    );
    expect(call[34], 100);
    expect(call[35], 0);
    expect(call[50], 8); // Compact(2) = 2 << 2
    expect(call.sublist(51), orderedEquals(<int>[0x68, 0x69]));
  });

  test('备注超 99 字节与非正金额必须拒绝', () {
    expect(
      () => TransferService.buildTransferWithRemarkCall(
        destinationPublicKey: Uint8List(32),
        amountFen: BigInt.one,
        remark: List<String>.filled(100, 'a').join(),
      ),
      throwsArgumentError,
    );
    expect(
      () => TransferService.buildTransferWithRemarkCall(
        destinationPublicKey: Uint8List(32),
        amountFen: BigInt.zero,
        remark: '',
      ),
      throwsArgumentError,
    );
  });
}
