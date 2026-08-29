import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:polkadart/scale_codec.dart' show ByteOutput, CompactBigIntCodec;

import '../crypto/account_codec.dart';
import 'chain_rpc.dart';
import 'pallet_registry.dart';
import 'signed_extrinsic_builder.dart';
import 'transaction_status.dart';

/// 公民链 OnchainTransaction::transfer_with_remark 服务。
final class TransferService {
  const TransferService(this._rpc);

  final ChainRpc _rpc;

  static const int maxTransferRemarkBytes = 99;

  Future<SubmittedTransaction> transferWithRemark({
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required String toSs58Address,
    required BigInt amountFen,
    required String remark,
    required Future<Uint8List> Function(Uint8List payload) sign,
    TransactionStatusCallback? onStatus,
  }) {
    final callData = buildTransferWithRemarkCall(
      destinationPublicKey: citizenPublicKeyFromSs58(toSs58Address),
      amountFen: amountFen,
      remark: remark,
    );
    return SignedExtrinsicBuilder(_rpc).signAndSubmit(
      callData: callData,
      fromSs58Address: fromSs58Address,
      signerPublicKey: signerPublicKey,
      sign: sign,
      onStatus: onStatus,
    );
  }

  Future<IncludedTransaction> transferWithRemarkAndWait({
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required String toSs58Address,
    required BigInt amountFen,
    required String remark,
    required Future<Uint8List> Function(Uint8List payload) sign,
    TransactionStatusCallback? onStatus,
    bool waitForFinalized = false,
  }) {
    final callData = buildTransferWithRemarkCall(
      destinationPublicKey: citizenPublicKeyFromSs58(toSs58Address),
      amountFen: amountFen,
      remark: remark,
    );
    return SignedExtrinsicBuilder(_rpc).signSubmitAndWait(
      callData: callData,
      fromSs58Address: fromSs58Address,
      signerPublicKey: signerPublicKey,
      sign: sign,
      onStatus: onStatus,
      waitForFinalized: waitForFinalized,
    );
  }

  @visibleForTesting
  static Uint8List buildTransferWithRemarkCall({
    required Uint8List destinationPublicKey,
    required BigInt amountFen,
    required String remark,
  }) {
    if (destinationPublicKey.length != 32) {
      throw ArgumentError('收款公钥必须是 32 字节');
    }
    if (amountFen <= BigInt.zero) throw ArgumentError('转账金额必须大于 0 分');
    final remarkBytes = Uint8List.fromList(utf8.encode(remark));
    if (remarkBytes.length > maxTransferRemarkBytes) {
      throw ArgumentError('转账备注不能超过 $maxTransferRemarkBytes 字节');
    }
    final output = ByteOutput()
      ..pushByte(PalletRegistry.onchainTransactionPallet)
      ..pushByte(PalletRegistry.transferWithRemarkCall)
      ..write(destinationPublicKey)
      ..write(_u128LittleEndian(amountFen))
      ..write(CompactBigIntCodec.codec.encode(BigInt.from(remarkBytes.length)))
      ..write(remarkBytes);
    return output.toBytes();
  }

  static Uint8List _u128LittleEndian(BigInt value) {
    final result = Uint8List(16);
    var remaining = value;
    for (var index = 0; index < result.length; index++) {
      result[index] = (remaining & BigInt.from(0xff)).toInt();
      remaining >>= 8;
    }
    if (remaining != BigInt.zero) throw ArgumentError('金额超出 u128 范围');
    return result;
  }
}
