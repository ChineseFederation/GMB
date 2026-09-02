import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/citizen_capability.dart';
import '../models/citizen_chain_state.dart';
import '../models/citizen_transaction.dart';
import '../models/citizen_wallet.dart';
import '../platform/citizen_sdk_flutter_codec.dart';
import '../platform/citizen_sdk_flutter_sessions.dart';
import '../platform/citizen_sdk_platform.dart';
import '../platform/flutter_citizen_sdk_platform.dart';
import 'citizen_chain.dart';
import 'citizen_sdk_error.dart';
import 'citizen_sdk_events.dart';
import 'citizen_transactions.dart';
import 'citizen_wallet.dart';

/// CitizenSDK 的唯一 Dart/Flutter 公共门面。
final class CitizenSdkClient {
  CitizenSdkClient._(this._session, CitizenSdkFlutterCodec codec)
    : chain = _CitizenChain(_session, codec),
      wallet = _CitizenWallet(_session, codec),
      transactions = _CitizenTransactions(_session, codec);

  /// 打开当前受支持平台的 CitizenSDK session，但不隐式启动轻节点。
  ///
  /// Flutter 产品投影当前覆盖 Android、iOS 与 macOS（仅支持 ARM64 架构）；三个投影使用
  /// 完全相同的公开 API、22 个固定 tuple 方法和事件合同。
  static Future<CitizenSdkClient> open() async {
    final codec = const CitizenSdkFlutterCodec();
    final platform = CitizenSdkPlatform.instance ?? _defaultPlatform();
    final session = await CitizenSdkFlutterSession.open(
      platform: platform,
      codec: codec,
    );
    return CitizenSdkClient._(session, codec);
  }

  static final CitizenSdkPlatform _defaultFlutterPlatform =
      FlutterCitizenSdkPlatform();

  static CitizenSdkPlatform _defaultPlatform() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return _defaultFlutterPlatform;
    }
    throw const CitizenSdkException(
      code: CitizenSdkErrorCode.unsupported,
      message:
          'CitizenSDK Flutter binding 当前仅支持 Android、iOS 与 macOS（仅支持 ARM64 架构）',
    );
  }

  final CitizenSdkFlutterSession _session;
  final CitizenChain chain;
  final CitizenWallet wallet;
  final CitizenTransactions transactions;

  Stream<CitizenSdkEvent> get events => _session.events;
  CitizenSdkLifecycle get lifecycle => _session.lifecycle;

  Future<void> start() async {
    final value = await _session.invoke('start');
    final lifecycle = const CitizenSdkFlutterCodec().decodeLifecycle(value[0]);
    if (lifecycle != CitizenSdkLifecycle.running) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.decode,
        message: 'CitizenSDK start 未进入 running',
      );
    }
  }

  Future<void> stop() async {
    final value = await _session.invoke('stop');
    final lifecycle = const CitizenSdkFlutterCodec().decodeLifecycle(value[0]);
    if (lifecycle != CitizenSdkLifecycle.stopped) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.decode,
        message: 'CitizenSDK stop 未进入 stopped',
      );
    }
  }

  Future<CitizenCapabilitySnapshot> getCapabilities() =>
      chain.getCapabilities();

  /// 只有原生侧完成 checkpoint、stop、结果释放和 destroy 后 Future 才完成。
  Future<void> close() => _session.close();
}

final class _CitizenChain implements CitizenChain {
  const _CitizenChain(this._session, this._codec);

  final CitizenSdkFlutterSession _session;
  final CitizenSdkFlutterCodec _codec;

  @override
  Future<CitizenCapabilitySnapshot> getCapabilities() async {
    final value = await _session.invoke('getCapabilities');
    return _codec.decodeCapabilities(value[0]);
  }

  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    final value = await _session.invoke('getFinalizedHead');
    return _codec.decodeBlock(value[0]);
  }

  @override
  Future<CitizenAccountBalance> getAccountBalance(String accountId) async {
    final value = await _session.invoke(
      'getAccountBalance',
      fields: <Object?>[accountId],
    );
    final balance = _codec.decodeBalance(value[0]);
    if (balance.accountId != accountId) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.decode,
        message: '余额响应账户与请求账户不一致',
      );
    }
    return balance;
  }

  @override
  Future<CitizenAccountNonce> getAccountNonce(String accountId) async {
    final value = await _session.invoke(
      'getAccountNonce',
      fields: <Object?>[accountId],
    );
    final nonce = _codec.decodeNonce(value[0]);
    if (nonce.accountId != accountId) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.decode,
        message: 'nonce 响应账户与请求账户不一致',
      );
    }
    return nonce;
  }

  @override
  Future<CitizenFeeSnapshot> getFeeSnapshot() async {
    final value = await _session.invoke('getFeeSnapshot');
    return _codec.decodeFeeSnapshot(value[0]);
  }
}

final class _CitizenWallet implements CitizenWallet {
  const _CitizenWallet(this._session, this._codec);

  final CitizenSdkFlutterSession _session;
  final CitizenSdkFlutterCodec _codec;

  @override
  Future<CitizenWalletProfile?> getProfile() async {
    final value = await _session.invoke('getWalletProfile');
    return _codec.decodeWalletProfile(value[0]);
  }

  @override
  Future<CitizenWalletProfile> create({
    CitizenWalletWordCount wordCount = CitizenWalletWordCount.words12,
  }) async {
    final value = await _session.invoke(
      'createWallet',
      fields: <Object?>[wordCount.value],
    );
    return _requireProfile(value[0], '创建');
  }

  @override
  Future<CitizenWalletProfile> importWallet() async {
    final value = await _session.invoke('importWallet');
    return _requireProfile(value[0], '导入');
  }

  @override
  Future<CitizenWalletProfile> addAccounts(List<int> indices) async {
    _requireCount(
      indices.length,
      minimum: 1,
      maximum: CitizenSdkFlutterCodec.maximumAdditionalWalletAccounts,
      label: '追加账户 indices',
    );
    final value = await _session.invoke(
      'addWalletAccounts',
      fields: <Object?>[List<int>.unmodifiable(indices)],
    );
    return _requireProfile(value[0], '追加账户');
  }

  @override
  Future<CitizenWalletProfile> setActiveAccount(String accountId) async {
    final value = await _session.invoke(
      'setActiveWalletAccount',
      fields: <Object?>[accountId],
    );
    return _requireProfile(value[0], '切换账户');
  }

  @override
  Future<CitizenWalletProfile> renameAccount({
    required String accountId,
    required String name,
  }) async {
    if (name.length > 128) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.invalidArgument,
        message: '账户名称原始输入不能超过 128 个 UTF-16 code unit',
      );
    }
    final normalizedName = name.trim();
    final value = await _session.invoke(
      'renameWalletAccount',
      fields: <Object?>[accountId, normalizedName],
    );
    return _requireProfile(value[0], '重命名账户');
  }

  @override
  Future<CitizenWalletProfile?> deleteAccount(String accountId) async {
    final value = await _session.invoke(
      'deleteWalletAccount',
      fields: <Object?>[accountId],
    );
    return _codec.decodeWalletProfile(value[0]);
  }

  @override
  Future<void> delete() async {
    final value = await _session.invoke('deleteWallet');
    if (_codec.decodeWalletProfile(value[0]) != null) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.decode,
        message: 'deleteWallet 完成后仍返回钱包 profile',
      );
    }
  }

  @override
  Future<CitizenWalletProfile?> reconcileCleanup() async {
    final value = await _session.invoke('reconcileWalletCleanup');
    return _codec.decodeWalletProfile(value[0]);
  }

  @override
  Future<CitizenWalletSignature> sign({
    required String accountId,
    required Uint8List payload,
  }) async {
    if (payload.length > CitizenSdkFlutterCodec.maximumSigningPayloadBytes) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.invalidArgument,
        message: '签名 payload 不能超过 16 MiB',
      );
    }
    final transportCopy = Uint8List.fromList(payload);
    try {
      final value = await _session.invoke(
        'signWalletPayload',
        fields: <Object?>[accountId, transportCopy],
      );
      return _codec.decodeSignature(accountId: accountId, raw: value[0]);
    } finally {
      transportCopy.fillRange(0, transportCopy.length, 0);
    }
  }

  CitizenWalletProfile _requireProfile(Object? raw, String operation) {
    final profile = _codec.decodeWalletProfile(raw);
    if (profile == null) {
      throw CitizenSdkException(
        code: CitizenSdkErrorCode.decode,
        message: '$operation完成但没有公开钱包 profile',
      );
    }
    return profile;
  }
}

final class _CitizenTransactions implements CitizenTransactions {
  const _CitizenTransactions(this._session, this._codec);

  final CitizenSdkFlutterSession _session;
  final CitizenSdkFlutterCodec _codec;

  @override
  Future<CitizenWalletTransfer> transferWithRemark({
    required String sourceAccountId,
    required String destinationAccountId,
    required BigInt amountFen,
    String remark = '',
  }) async {
    if (amountFen <= BigInt.zero || amountFen > _maximumU128) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.invalidArgument,
        message: '转账金额必须在 1..u128::MAX 范围内',
      );
    }
    // Bound attacker-controlled text before UTF-8 encoding. The exact byte
    // check then preserves Core's 99-byte remark contract.
    if (remark.length > 99 || utf8.encode(remark).length > 99) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.invalidArgument,
        message: '转账备注不能超过 99 UTF-8 字节',
      );
    }
    final value = await _session.invoke(
      'transferWithRemark',
      fields: <Object?>[
        sourceAccountId,
        destinationAccountId,
        amountFen.toString(),
        remark,
      ],
    );
    return _codec.decodeTransfer(value[0]);
  }

  @override
  Future<CitizenTransactionHistory> initializeFinalizedHistory(
    List<String> accountIds,
  ) async {
    _requireHistoryAccounts(accountIds);
    final value = await _session.invoke(
      'initializeFinalizedHistory',
      fields: <Object?>[List<String>.unmodifiable(accountIds)],
    );
    return _codec.decodeHistory(value[0]);
  }

  @override
  Future<CitizenTransactionHistory> syncFinalizedHistory(
    List<String> accountIds,
  ) async {
    _requireHistoryAccounts(accountIds);
    final value = await _session.invoke(
      'syncFinalizedHistory',
      fields: <Object?>[List<String>.unmodifiable(accountIds)],
    );
    return _codec.decodeHistory(value[0]);
  }
}

final BigInt _maximumU128 = (BigInt.one << 128) - BigInt.one;

void _requireHistoryAccounts(List<String> accountIds) {
  _requireCount(
    accountIds.length,
    minimum: 1,
    maximum: CitizenSdkFlutterCodec.maximumHistoryAccounts,
    label: '历史 accountIds',
  );
  if (accountIds.toSet().length != accountIds.length) {
    throw const CitizenSdkException(
      code: CitizenSdkErrorCode.invalidArgument,
      message: '历史 accountIds 不能重复',
    );
  }
}

void _requireCount(
  int count, {
  required int minimum,
  required int maximum,
  required String label,
}) {
  if (count < minimum || count > maximum) {
    throw CitizenSdkException(
      code: CitizenSdkErrorCode.invalidArgument,
      message: '$label 必须包含 $minimum..$maximum 项',
    );
  }
}
