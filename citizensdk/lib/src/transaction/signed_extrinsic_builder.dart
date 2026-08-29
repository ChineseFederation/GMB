import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:polkadart/polkadart.dart'
    show ExtrinsicPayload, RuntimeVersion, SignatureType, SigningPayload;

import '../crypto/account_codec.dart';
import 'chain_rpc.dart';
import 'transaction_status.dart';

@immutable
final class SignedExtrinsicTrace {
  const SignedExtrinsicTrace({
    required this.callData,
    required this.payloadBytes,
    required this.signature,
    required this.encoded,
    required this.signerPublicKey,
    required this.genesisHash,
    required this.runtimeVersion,
    required this.nonce,
  });

  final Uint8List callData;
  final Uint8List payloadBytes;
  final Uint8List signature;
  final Uint8List encoded;
  final Uint8List signerPublicKey;
  final Uint8List genesisHash;
  final RuntimeVersion runtimeVersion;
  final int nonce;
}

/// 公民链 PoW 在线 extrinsic 统一构造器。
final class SignedExtrinsicBuilder {
  const SignedExtrinsicBuilder(this._rpc);

  final ChainRpc _rpc;

  static const int immortalEraPeriod = 0;
  static const int immortalBlockNumber = 0;

  Future<SubmittedTransaction> signAndSubmit({
    required Uint8List callData,
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required Future<Uint8List> Function(Uint8List payload) sign,
    void Function(SignedExtrinsicTrace trace)? onTrace,
    Future<void> Function(SignedExtrinsicTrace trace, String txHash)?
    beforeBroadcast,
    TransactionStatusCallback? onStatus,
    Duration watchTimeout = const Duration(minutes: 20),
    Duration executionLookupTimeout = const Duration(seconds: 30),
    Duration executionRetryInterval = const Duration(seconds: 1),
  }) async {
    final prepared = await _prepare(
      callData: callData,
      fromSs58Address: fromSs58Address,
      signerPublicKey: signerPublicKey,
      sign: sign,
    );
    onTrace?.call(prepared.trace);
    final txHash = await _rpc.submitExtrinsic(
      prepared.trace.encoded,
      beforeBroadcast: beforeBroadcast == null
          ? null
          : (txHash) => beforeBroadcast(prepared.trace, txHash),
      onStatus: onStatus,
      watchTimeout: watchTimeout,
      executionLookupTimeout: executionLookupTimeout,
      executionRetryInterval: executionRetryInterval,
    );
    return SubmittedTransaction(
      txHash: txHash,
      usedNonce: prepared.trace.nonce,
    );
  }

  Future<IncludedTransaction> signSubmitAndWait({
    required Uint8List callData,
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required Future<Uint8List> Function(Uint8List payload) sign,
    void Function(SignedExtrinsicTrace trace)? onTrace,
    Future<void> Function(SignedExtrinsicTrace trace, String txHash)?
    beforeBroadcast,
    TransactionStatusCallback? onStatus,
    bool waitForFinalized = false,
    Duration timeout = const Duration(minutes: 20),
    Duration executionLookupTimeout = const Duration(seconds: 30),
    Duration executionRetryInterval = const Duration(seconds: 1),
  }) async {
    final prepared = await _prepare(
      callData: callData,
      fromSs58Address: fromSs58Address,
      signerPublicKey: signerPublicKey,
      sign: sign,
    );
    onTrace?.call(prepared.trace);
    final result = await _rpc.submitAndWait(
      prepared.trace.encoded,
      beforeBroadcast: beforeBroadcast == null
          ? null
          : (txHash) => beforeBroadcast(prepared.trace, txHash),
      onStatus: onStatus,
      waitForFinalized: waitForFinalized,
      timeout: timeout,
      executionLookupTimeout: executionLookupTimeout,
      executionRetryInterval: executionRetryInterval,
    );
    return IncludedTransaction(
      txHash: result.txHash,
      usedNonce: prepared.trace.nonce,
      blockHash: result.included.blockHash!,
      finalized: result.included.kind == TransactionStatusKind.finalized,
      extrinsicIndex: result.extrinsicIndex,
      executionVerified: true,
    );
  }

  Future<({SignedExtrinsicTrace trace})> _prepare({
    required Uint8List callData,
    required String fromSs58Address,
    required Uint8List signerPublicKey,
    required Future<Uint8List> Function(Uint8List payload) sign,
  }) async {
    if (callData.isEmpty) throw ArgumentError('callData 不能为空');
    if (signerPublicKey.length != 32) {
      throw ArgumentError.value(
        signerPublicKey.length,
        'signerPublicKey.length',
      );
    }
    final addressPublicKey = citizenPublicKeyFromSs58(fromSs58Address);
    if (!_bytesEqual(addressPublicKey, signerPublicKey)) {
      throw ArgumentError('fromSs58Address 与 signerPublicKey 不属于同一账户');
    }
    // runtime version 与 metadata 必须来自同一当前 best 块。禁止分别读取后
    // 在升级边界拼出“前一代 registry + 新 specVersion/transactionVersion”。
    final runtimeContext = await _rpc.fetchRuntimeContext();
    final metadata = runtimeContext.metadata;
    final genesisHash = await _rpc.fetchGenesisHash();
    final runtimeVersion = runtimeContext.runtimeVersion;
    final nonce = await _rpc.fetchNonce(fromSs58Address);
    final registry = metadata.chainInfo.scaleCodec.registry;
    final signingPayload = buildImmortalSigningPayload(
      callData: callData,
      specVersion: runtimeVersion.specVersion,
      transactionVersion: runtimeVersion.transactionVersion,
      genesisHash: genesisHash,
      nonce: nonce,
    );
    final payloadBytes = signingPayload.encode(registry);
    final signature = await sign(payloadBytes);
    if (signature.length != 64) {
      throw StateError('sr25519 签名必须是 64 字节');
    }
    final extrinsic = buildImmortalExtrinsicPayload(
      callData: callData,
      signerPublicKey: signerPublicKey,
      signature: signature,
      nonce: nonce,
    );
    final encoded = extrinsic.encode(registry, SignatureType.sr25519);
    return (
      trace: SignedExtrinsicTrace(
        callData: Uint8List.fromList(callData),
        payloadBytes: Uint8List.fromList(payloadBytes),
        signature: Uint8List.fromList(signature),
        encoded: Uint8List.fromList(encoded),
        signerPublicKey: Uint8List.fromList(signerPublicKey),
        genesisHash: Uint8List.fromList(genesisHash),
        runtimeVersion: runtimeVersion,
        nonce: nonce,
      ),
    );
  }

  @visibleForTesting
  static SigningPayload buildImmortalSigningPayload({
    required Uint8List callData,
    required int specVersion,
    required int transactionVersion,
    required Uint8List genesisHash,
    required int nonce,
  }) {
    final hash = '0x${hexEncode(genesisHash)}';
    return SigningPayload(
      method: callData,
      specVersion: specVersion,
      transactionVersion: transactionVersion,
      genesisHash: hash,
      blockHash: hash,
      blockNumber: immortalBlockNumber,
      eraPeriod: immortalEraPeriod,
      nonce: nonce,
      tip: 0,
    );
  }

  @visibleForTesting
  static ExtrinsicPayload buildImmortalExtrinsicPayload({
    required Uint8List callData,
    required Uint8List signerPublicKey,
    required Uint8List signature,
    required int nonce,
  }) => ExtrinsicPayload(
    signer: signerPublicKey,
    method: callData,
    signature: signature,
    eraPeriod: immortalEraPeriod,
    blockNumber: immortalBlockNumber,
    nonce: nonce,
    tip: 0,
  );

  static String hexEncode(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
