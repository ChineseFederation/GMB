import 'dart:async';
import 'dart:typed_data';

import 'package:polkadart/polkadart.dart'
    show Hasher, RuntimeMetadata, RuntimeVersion;
import 'package:polkadart/scale_codec.dart' show ByteInput;

import '../crypto/account_codec.dart';
import '../node/light_client.dart';
import 'transaction_status.dart';

/// 只通过 CitizenSDK 内嵌轻节点访问公民链的 RPC 边界。
final class ChainRpc {
  ChainRpc(this.lightClient);

  final CitizenLightClient lightClient;
  Uint8List? _genesisHash;
  RuntimeMetadata? _metadata;
  Future<RuntimeMetadata>? _metadataInflight;

  Future<int> fetchNonce(String ss58Address) {
    final accountId = citizenAccountIdFromBytes(
      citizenPublicKeyFromSs58(ss58Address),
    );
    return lightClient.accountNextIndex(accountId);
  }

  Future<RuntimeVersion> fetchRuntimeVersion() async =>
      RuntimeVersion.fromJson(await lightClient.runtimeVersion());

  Future<Uint8List> fetchGenesisHash() async {
    final cached = _genesisHash;
    if (cached != null) return Uint8List.fromList(cached);
    final value = await lightClient.blockHash(0);
    final decoded = _hexDecode(value);
    if (decoded.length != 32) throw StateError('公民链 genesis hash 不是 32 字节');
    _genesisHash = decoded;
    return Uint8List.fromList(decoded);
  }

  Future<RuntimeMetadata> fetchMetadata() async {
    final cached = _metadata;
    if (cached != null) return cached;
    final current = _metadataInflight;
    if (current != null) return current;
    final task = lightClient.metadataHex().then(RuntimeMetadata.fromHex);
    _metadataInflight = task;
    try {
      final metadata = await task;
      _metadata = metadata;
      return metadata;
    } finally {
      _metadataInflight = null;
    }
  }

  void invalidateRuntimeMetadata() {
    _metadata = null;
    _metadataInflight = null;
  }

  Future<Object?> fetchPalletConstant(String pallet, String name) async {
    final metadata = await fetchMetadata();
    final constant = metadata.chainInfo.constants[pallet]?[name];
    if (constant == null) throw StateError('链上未下发常量 $pallet.$name');
    return constant.type.decode(ByteInput(constant.bytes));
  }

  Future<BigInt> fetchPalletConstantU128(String pallet, String name) async {
    final value = await fetchPalletConstant(pallet, name);
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    throw StateError('链上常量 $pallet.$name 不是整数');
  }

  Future<BigInt> fetchMinimumSelfPayBalanceFen() async {
    final values = await Future.wait<BigInt>(<Future<BigInt>>[
      fetchPalletConstantU128('OnchainTransaction', 'OnchainMinFee'),
      fetchPalletConstantU128('Balances', 'ExistentialDeposit'),
    ]);
    return values[0] + values[1];
  }

  Future<Uint8List?> fetchFinalizedStorage(String storageKeyHex) async {
    final value = await lightClient.finalizedStorage(storageKeyHex);
    return value == null ? null : _hexDecode(value);
  }

  /// 返回 finalized System.Account.free，单位为公民链整数分。
  Future<BigInt> fetchFinalizedBalanceFen(String accountId) async {
    final publicKey = citizenAccountIdBytes(accountId);
    final blake2 = Hasher.blake2b128.hash(publicKey);
    final key =
        Uint8List(
            _systemAccountPrefix.length + blake2.length + publicKey.length,
          )
          ..setAll(0, _systemAccountPrefix)
          ..setAll(_systemAccountPrefix.length, blake2)
          ..setAll(_systemAccountPrefix.length + blake2.length, publicKey);
    final data = await fetchFinalizedStorage('0x${_hex(key)}');
    if (data == null || data.length < 32) return BigInt.zero;
    return _readU128(data, 16);
  }

  Future<String> submitExtrinsic(
    Uint8List encoded, {
    TransactionStatusCallback? onStatus,
  }) async {
    final extrinsicHex = '0x${_hex(encoded)}';
    final txHash = _normalizeHash(
      await lightClient.submitExtrinsic(extrinsicHex),
    );
    if (onStatus != null) {
      unawaited(_watchInBackground(extrinsicHex, onStatus));
    }
    return txHash;
  }

  Future<({String txHash, TransactionStatus included})> submitAndWait(
    Uint8List encoded, {
    TransactionStatusCallback? onStatus,
    bool waitForFinalized = false,
    Duration timeout = const Duration(minutes: 20),
  }) async {
    final extrinsicHex = '0x${_hex(encoded)}';
    final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    final done = Completer<TransactionStatus>();
    StreamSubscription<Object?>? subscription;
    final timer = Timer(timeout, () {
      if (!done.isCompleted) {
        done.completeError(TimeoutException('交易等待入块超时', timeout));
      }
    });
    try {
      subscription = lightClient
          .subscribe('author_submitAndWatchExtrinsic', <Object?>[extrinsicHex])
          .listen(
            (raw) {
              final status = TransactionStatus.fromRpc(raw);
              onStatus?.call(status);
              if (status.isDefinitiveFailure && !done.isCompleted) {
                done.completeError(StateError(status.description));
              }
              final reached = waitForFinalized
                  ? status.kind == TransactionStatusKind.finalized
                  : status.isIncluded;
              if (reached && !done.isCompleted) {
                if (status.blockHash == null) {
                  done.completeError(StateError('交易状态未携带区块哈希'));
                } else {
                  done.complete(status);
                }
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!done.isCompleted) done.completeError(error, stackTrace);
            },
            onDone: () {
              if (!done.isCompleted) {
                done.completeError(StateError('交易池订阅结束但交易尚未入块'));
              }
            },
          );
      return (txHash: txHash, included: await done.future);
    } finally {
      timer.cancel();
      if (subscription != null) unawaited(subscription.cancel());
    }
  }

  Future<void> _watchInBackground(
    String extrinsicHex,
    TransactionStatusCallback onStatus,
  ) async {
    StreamSubscription<Object?>? subscription;
    final done = Completer<void>();
    final timer = Timer(const Duration(minutes: 20), () {
      if (!done.isCompleted) done.complete();
    });
    try {
      subscription = lightClient
          .subscribe('author_submitAndWatchExtrinsic', <Object?>[extrinsicHex])
          .listen(
            (raw) {
              final status = TransactionStatus.fromRpc(raw);
              onStatus(status);
              if ((status.isDefinitiveFailure ||
                      status.kind == TransactionStatusKind.finalized) &&
                  !done.isCompleted) {
                done.complete();
              }
            },
            onError: (Object error) {
              onStatus(
                TransactionStatus(
                  kind: TransactionStatusKind.error,
                  description: '$error',
                  raw: '$error',
                ),
              );
              if (!done.isCompleted) done.complete();
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
          );
      await done.future;
    } finally {
      timer.cancel();
      if (subscription != null) unawaited(subscription.cancel());
    }
  }

  static final Uint8List _systemAccountPrefix = _hexDecode(
    '26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9',
  );

  static BigInt _readU128(Uint8List data, int offset) {
    var value = BigInt.zero;
    for (var index = 0; index < 16; index++) {
      value += BigInt.from(data[offset + index]) << (index * 8);
    }
    return value;
  }

  static Uint8List _hexDecode(String input) {
    final hex = input.startsWith('0x') ? input.substring(2) : input;
    if (hex.isEmpty ||
        hex.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      throw const FormatException('不是有效 hex');
    }
    return Uint8List.fromList(<int>[
      for (var offset = 0; offset < hex.length; offset += 2)
        int.parse(hex.substring(offset, offset + 2), radix: 16),
    ]);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static String _normalizeHash(String value) {
    final normalized = value.startsWith('0x') ? value : '0x$value';
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(normalized)) {
      throw StateError('轻节点返回的交易哈希无效');
    }
    return normalized.toLowerCase();
  }
}
