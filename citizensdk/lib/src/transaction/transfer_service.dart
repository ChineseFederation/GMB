import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:polkadart/scale_codec.dart' show ByteOutput, CompactBigIntCodec;

import '../crypto/account_codec.dart';
import 'chain_rpc.dart';
import 'finalized_transaction_repository.dart';
import 'pallet_registry.dart';
import 'signed_extrinsic_builder.dart';
import 'transaction_status.dart';

/// 公民链 OnchainTransaction::transfer_with_remark 服务。
final class TransferService {
  const TransferService(
    this._rpc, {
    FinalizedTransactionHistory? transactionHistory,
  }) : _transactionHistory = transactionHistory;

  final ChainRpc _rpc;
  final FinalizedTransactionHistory? _transactionHistory;

  static const int maxTransferRemarkBytes = 99;

  /// 从当前公民链 runtime metadata 读取费率和最低费后估算转账手续费。
  ///
  /// 输入与返回值均为整数分；不接受 `double`，也不保存本地费率副本。
  Future<BigInt> estimateTransferFeeFen(BigInt amountFen) =>
      _rpc.estimateOnchainTransactionFeeFen(amountFen);

  Future<SubmittedTransaction> transferWithRemark({
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required String toSs58Address,
    required BigInt amountFen,
    required String remark,
    required Future<Uint8List> Function(Uint8List payload) sign,
    TransactionStatusCallback? onStatus,
    Duration watchTimeout = const Duration(minutes: 20),
    Duration executionLookupTimeout = const Duration(seconds: 30),
    Duration executionRetryInterval = const Duration(seconds: 1),
  }) async {
    final fromAccountId = citizenAccountIdFromBytes(
      citizenPublicKeyFromSs58(fromSs58Address),
    );
    final toAccountId = citizenAccountIdFromBytes(
      citizenPublicKeyFromSs58(toSs58Address),
    );
    final callData = buildTransferWithRemarkCall(
      destinationPublicKey: citizenAccountIdBytes(toAccountId),
      amountFen: amountFen,
      remark: remark,
    );
    String? persistedTxHash;
    return SignedExtrinsicBuilder(_rpc).signAndSubmit(
      callData: callData,
      fromSs58Address: fromSs58Address,
      signerPublicKey: signerPublicKey,
      sign: sign,
      beforeBroadcast: _transactionHistory == null
          ? null
          : (trace, txHash) async {
              persistedTxHash = txHash;
              await _transactionHistory.recordPendingSubmission(
                accountId: fromAccountId,
                txHash: txHash,
                usedNonce: trace.nonce,
                toAccountId: toAccountId,
                amountFen: amountFen,
                remark: remark,
              );
            },
      onStatus: _statusObserver(
        accountId: fromAccountId,
        txHash: () => persistedTxHash,
        callback: onStatus,
      ),
      watchTimeout: watchTimeout,
      executionLookupTimeout: executionLookupTimeout,
      executionRetryInterval: executionRetryInterval,
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
    Duration timeout = const Duration(minutes: 20),
    Duration executionLookupTimeout = const Duration(seconds: 30),
    Duration executionRetryInterval = const Duration(seconds: 1),
  }) async {
    final fromAccountId = citizenAccountIdFromBytes(
      citizenPublicKeyFromSs58(fromSs58Address),
    );
    final toAccountId = citizenAccountIdFromBytes(
      citizenPublicKeyFromSs58(toSs58Address),
    );
    final callData = buildTransferWithRemarkCall(
      destinationPublicKey: citizenAccountIdBytes(toAccountId),
      amountFen: amountFen,
      remark: remark,
    );
    String? persistedTxHash;
    return SignedExtrinsicBuilder(_rpc).signSubmitAndWait(
      callData: callData,
      fromSs58Address: fromSs58Address,
      signerPublicKey: signerPublicKey,
      sign: sign,
      beforeBroadcast: _transactionHistory == null
          ? null
          : (trace, txHash) async {
              persistedTxHash = txHash;
              await _transactionHistory.recordPendingSubmission(
                accountId: fromAccountId,
                txHash: txHash,
                usedNonce: trace.nonce,
                toAccountId: toAccountId,
                amountFen: amountFen,
                remark: remark,
              );
            },
      onStatus: _statusObserver(
        accountId: fromAccountId,
        txHash: () => persistedTxHash,
        callback: onStatus,
      ),
      waitForFinalized: waitForFinalized,
      timeout: timeout,
      executionLookupTimeout: executionLookupTimeout,
      executionRetryInterval: executionRetryInterval,
    );
  }

  TransactionStatusCallback? _statusObserver({
    required String accountId,
    required String? Function() txHash,
    required TransactionStatusCallback? callback,
  }) {
    final history = _transactionHistory;
    if (history == null) return callback;
    return (status) {
      final currentTxHash = txHash();
      if (currentTxHash != null) {
        Future<void>? mutation;
        if ((status.kind == TransactionStatusKind.inBlock ||
                status.kind == TransactionStatusKind.finalized) &&
            status.blockHash != null) {
          // finalized 只保存块锚，不能直接冒充 runtime 执行成功。
          mutation = history.markSubmissionInBlock(
            accountId: accountId,
            txHash: currentTxHash,
            blockHash: status.blockHash!,
          );
        } else if (status.kind == TransactionStatusKind.invalid ||
            status.kind == TransactionStatusKind.usurped) {
          mutation = history.markPoolRejected(
            accountId: accountId,
            txHash: currentTxHash,
            reason: status.description,
          );
        }
        if (mutation != null) {
          // 状态观察回调不能阻塞交易状态机；持久仓储自身执行 CAS、写后回读和
          // 同实例队列，失败不会被当作链上终态。scanner 仍可凭 txHash 补收敛。
          unawaited(
            mutation.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
          );
        }
      }
      callback?.call(status);
    };
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
