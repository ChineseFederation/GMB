import 'dart:typed_data';

import 'package:citizen_sdk/src/transaction/signed_extrinsic_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('签名载荷的 era 与 additional signed hash 固定为 genesis', () {
    final genesis = Uint8List.fromList(
      List<int>.generate(32, (index) => index),
    );
    final payload = SignedExtrinsicBuilder.buildImmortalSigningPayload(
      callData: Uint8List.fromList(<int>[2, 3]),
      specVersion: 42,
      transactionVersion: 7,
      genesisHash: genesis,
      nonce: 9,
    );
    final encoded = payload.toEncodedMap(null);
    expect(encoded['era'], '00');
    expect(encoded['blockHash'], SignedExtrinsicBuilder.hexEncode(genesis));
    expect(encoded['genesisHash'], SignedExtrinsicBuilder.hexEncode(genesis));
  });

  test('extrinsic body 同样使用 immortal era', () {
    final payload = SignedExtrinsicBuilder.buildImmortalExtrinsicPayload(
      callData: Uint8List.fromList(<int>[4, 0]),
      signerPublicKey: Uint8List(32),
      signature: Uint8List(64),
      nonce: 3,
    );
    expect(payload.toEncodedMap(null)['era'], '00');
  });
}
