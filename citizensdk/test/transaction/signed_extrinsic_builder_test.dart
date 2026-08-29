import 'dart:typed_data';

import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/node/light_client.dart';
import 'package:citizen_sdk/src/transaction/chain_rpc.dart';
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

  test('签名前拒绝空 call data 和非 32 字节公钥', () async {
    final builder = SignedExtrinsicBuilder(ChainRpc(CitizenLightClient()));
    final publicKey = Uint8List(32);
    final address = citizenSs58FromAccountId(
      citizenAccountIdFromBytes(publicKey),
    );

    await expectLater(
      builder.signAndSubmit(
        callData: Uint8List(0),
        fromSs58Address: address,
        signerPublicKey: publicKey,
        sign: (_) async => Uint8List(64),
      ),
      throwsArgumentError,
    );
    await expectLater(
      builder.signAndSubmit(
        callData: Uint8List.fromList(<int>[4, 0]),
        fromSs58Address: address,
        signerPublicKey: Uint8List(31),
        sign: (_) async => Uint8List(64),
      ),
      throwsArgumentError,
    );
  });

  test('签名前常量时间比对 SS58 地址与签名公钥', () async {
    final builder = SignedExtrinsicBuilder(ChainRpc(CitizenLightClient()));
    final addressPublicKey = Uint8List(32);
    final address = citizenSs58FromAccountId(
      citizenAccountIdFromBytes(addressPublicKey),
    );
    final otherPublicKey = Uint8List.fromList(<int>[
      1,
      ...List<int>.filled(31, 0),
    ]);

    await expectLater(
      builder.signAndSubmit(
        callData: Uint8List.fromList(<int>[4, 0]),
        fromSs58Address: address,
        signerPublicKey: otherPublicKey,
        sign: (_) async => Uint8List(64),
      ),
      throwsArgumentError,
    );
  });
}
