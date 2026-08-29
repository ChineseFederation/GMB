import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:polkadart/polkadart.dart'
    show Events, Hasher, RuntimeMetadata, RuntimeVersion;
import 'package:polkadart/scale_codec.dart' show ByteInput;

import '../crypto/account_codec.dart';
import '../node/light_client.dart';
import 'transaction_status.dart';

/// CitizenSDK 交易层使用的轻节点能力边界。
///
/// 生产环境由 [CitizenLightClientChainRpcTransport] 直接连接本机
/// smoldot。该边界也让交易状态机能使用确定性 fake 覆盖断线、超时、
/// 入块和 runtime dispatch error，不需要伪造真实 P2P 网络。
abstract interface class ChainRpcTransport {
  Future<void> ensureStarted();

  Future<int> accountNextIndex(String accountIdHex);

  Future<Map<String, dynamic>> runtimeVersion();

  Future<String> blockHash(int blockNumber);

  Future<String> metadataHex();

  Future<String?> finalizedStorage(String storageKeyHex);

  Future<Map<String, String?>> finalizedStorageValues(
    List<String> storageKeyHexList,
  );

  Future<String> submitExtrinsic(String extrinsicHex);

  Future<List<String>> blockExtrinsicsOnce(String blockHashHex);

  Future<Object?> request(String method, List<Object?> params);

  Stream<Object?> subscribe(String method, List<Object?> params);
}

/// [ChainRpcTransport] 的 CitizenSDK 内嵌轻节点实现。
final class CitizenLightClientChainRpcTransport implements ChainRpcTransport {
  const CitizenLightClientChainRpcTransport(this.lightClient);

  final CitizenLightClient lightClient;

  @override
  Future<void> ensureStarted() => lightClient.ensureStarted();

  @override
  Future<int> accountNextIndex(String accountIdHex) =>
      lightClient.accountNextIndex(accountIdHex);

  @override
  Future<Map<String, dynamic>> runtimeVersion() => lightClient.runtimeVersion();

  @override
  Future<String> blockHash(int blockNumber) =>
      lightClient.blockHash(blockNumber);

  @override
  Future<String> metadataHex() => lightClient.metadataHex();

  @override
  Future<String?> finalizedStorage(String storageKeyHex) =>
      lightClient.finalizedStorage(storageKeyHex);

  @override
  Future<Map<String, String?>> finalizedStorageValues(
    List<String> storageKeyHexList,
  ) => lightClient.getFinalizedStorageValuesHex(storageKeyHexList);

  @override
  Future<String> submitExtrinsic(String extrinsicHex) =>
      lightClient.submitExtrinsic(extrinsicHex);

  @override
  Future<List<String>> blockExtrinsicsOnce(String blockHashHex) =>
      lightClient.getFinalizedBlockExtrinsicsOnce(blockHashHex);

  @override
  Future<Object?> request(String method, List<Object?> params) =>
      lightClient.request(method, params);

  @override
  Stream<Object?> subscribe(String method, List<Object?> params) =>
      lightClient.subscribe(method, params);
}

/// 一次 finalized `System.Account` 读取解码出的账户余额，单位均为分。
///
/// [requestedAccount] 原样保留调用方传入的 AccountId 或 SS58 键；
/// [accountId] 是严格校验后归一化的公民链 AccountId。批量读取因此可以按
/// 输入位置保留重复键，同时不混淆调用方键与链上存储键身份。
@immutable
final class FinalizedAccountBalance {
  const FinalizedAccountBalance({
    required this.requestedAccount,
    required this.accountId,
    required this.freeFen,
    required this.reservedFen,
  });

  final String requestedAccount;
  final String accountId;
  final BigInt freeFen;
  final BigInt reservedFen;

  BigInt get totalFen => freeFen + reservedFen;
}

/// 同一块上原子读取的 runtime 版本与 metadata。
///
/// [blockHash] 同时传给 `state_getRuntimeVersion` 和 `state_getMetadata`，因此
/// [runtimeVersion] 的 `specVersion`、签名所用 `transactionVersion` 与
/// [metadata] registry 不会跨 runtime 升级拼接。
@immutable
final class ChainRuntimeContext {
  const ChainRuntimeContext({
    required this.blockHash,
    required this.runtimeVersion,
    required this.metadata,
  });

  final String blockHash;
  final RuntimeVersion runtimeVersion;
  final RuntimeMetadata metadata;
}

/// 由 `chain_getFinalizedHead` 与同哈希 header 共同确认的 finalized 块锚。
@immutable
final class FinalizedBlockRef {
  const FinalizedBlockRef({required this.blockHash, required this.blockNumber});

  final String blockHash;
  final int blockNumber;
}

/// 只通过 CitizenSDK 内嵌轻节点访问公民链的 RPC 边界。
///
/// 交易确认分为三个不可混同的事实：
///
/// 1. `author_submitExtrinsic` 返回 txHash，只代表本机轻节点接收提交；
/// 2. `inBlock/finalized` 只代表 extrinsic 被包含在区块中；
/// 3. 只有按 txHash 定位到同一 extrinsic index，再读到该 index 的
///    `System.ExtrinsicSuccess`，才能返回“执行成功”。
///
/// 本类不包含远程签名、远程 RPC 代理或已签名交易中继；广播始终由
/// 宿主设备上的 smoldot P2P 轻节点执行。
final class ChainRpc {
  ChainRpc(CitizenLightClient lightClient)
    : _transport = CitizenLightClientChainRpcTransport(lightClient);

  @visibleForTesting
  ChainRpc.withTransport(ChainRpcTransport transport) : _transport = transport;

  final ChainRpcTransport _transport;
  Uint8List? _genesisHash;
  _RuntimeMetadataCache? _metadataCache;
  _RuntimeMetadataInflight? _metadataInflight;
  static final BigInt _u32Max = (BigInt.one << 32) - BigInt.one;
  static final BigInt _u128Max = (BigInt.one << 128) - BigInt.one;
  static final BigInt _perbillDenominator = BigInt.from(1000000000);

  /// 状态回调只承担界面与业务观察，不拥有交易状态机的控制流。
  ///
  /// 同步抛错和回调内部异步任务的未处理错误都在独立错误 Zone 中收口，
  /// 不能阻断 Completer、定时器、订阅清理，也不能把一个链上终态改写成
  /// 第二个错误终态。
  static void _notifyStatus(
    TransactionStatusCallback? onStatus,
    TransactionStatus status,
  ) {
    final callback = onStatus;
    if (callback == null) return;
    runZonedGuarded<void>(() => callback(status), (Object _, StackTrace _) {
      // best-effort 通知：观察者故障不得反向影响交易真源状态机。
    });
  }

  Future<int> fetchNonce(String ss58Address) {
    final accountId = citizenAccountIdFromBytes(
      citizenPublicKeyFromSs58(ss58Address),
    );
    return _transport.accountNextIndex(accountId);
  }

  /// 读取当前 best 块的 runtime version。
  ///
  /// 该独立入口保持 CitizenApp 已验证语义：只依赖 runtime-version RPC，
  /// metadata 暂时不可用时仍可用于版本诊断。交易构造、费用和事件解码必须改用
  /// [fetchRuntimeContext]，由同一块同时绑定 version 与 metadata。
  Future<RuntimeVersion> fetchRuntimeVersion() async =>
      _fetchRuntimeVersionAt(await _fetchBestHead());

  /// 读取当前 finalized 块，并以同一个哈希解析块号。
  Future<FinalizedBlockRef> fetchFinalizedBlock() async {
    final rawHash = await _transport.request(
      'chain_getFinalizedHead',
      const <Object?>[],
    );
    if (rawHash is! String) {
      throw StateError('chain_getFinalizedHead 未返回区块哈希');
    }
    final blockHash = _normalizeHash(rawHash);
    final blockNumber = await fetchBlockNumberByHash(blockHash);
    if (blockNumber == null) {
      throw StateError('finalized 块头没有有效块号');
    }
    return FinalizedBlockRef(blockHash: blockHash, blockNumber: blockNumber);
  }

  /// 读取指定高度的规范链块哈希。
  Future<String> fetchBlockHash(int blockNumber) async {
    if (blockNumber < 0) throw ArgumentError('blockNumber 不能为负数');
    return _normalizeHash(await _transport.blockHash(blockNumber));
  }

  /// 按块哈希读取 header.number；不存在时返回 null。
  Future<int?> fetchBlockNumberByHash(String blockHashHex) async {
    final blockHash = _normalizeHash(blockHashHex);
    final raw = await _transport.request('chain_getHeader', <Object?>[
      blockHash,
    ]);
    if (raw == null) return null;
    if (raw is! Map) throw StateError('chain_getHeader 未返回对象');
    final number = raw['number'];
    if (number is! String || number.isEmpty) {
      throw StateError('chain_getHeader.number 无效');
    }
    final hex = number.startsWith('0x') ? number.substring(2) : number;
    if (hex.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      throw StateError('chain_getHeader.number 不是 hex');
    }
    return int.parse(hex, radix: 16);
  }

  Future<Uint8List> fetchGenesisHash() async {
    final cached = _genesisHash;
    if (cached != null) return Uint8List.fromList(cached);
    final value = await _transport.blockHash(0);
    final decoded = _hexDecode(value);
    if (decoded.length != 32) {
      throw StateError('公民链 genesis hash 不是 32 字节');
    }
    _genesisHash = decoded;
    return Uint8List.fromList(decoded);
  }

  /// 在同一块读取 runtime version 与 metadata，并按 `specVersion` 自动换代。
  ///
  /// 未指定 [blockHashHex] 时先读取当前 best head；交易构造必须跟随当前
  /// runtime，不能在升级刚进入 best 链时继续使用落后一段的 finalized runtime。
  /// 执行结果核对则传入交易
  /// 所在块，避免 runtime 升级后用当前 registry 解码先前区块事件。同一
  /// `specVersion` 复用 registry；不同版本的在途请求互不复用，且前一代请求迟到
  /// 完成时不能覆盖较新的缓存身份。
  Future<ChainRuntimeContext> fetchRuntimeContext({
    String? blockHashHex,
  }) async {
    final blockHash = blockHashHex == null
        ? await _fetchBestHead()
        : _normalizeHash(blockHashHex);
    final runtimeVersion = await _fetchRuntimeVersionAt(blockHash);
    final metadata = await _fetchMetadataForRuntime(
      blockHash: blockHash,
      specVersion: runtimeVersion.specVersion,
    );
    return ChainRuntimeContext(
      blockHash: blockHash,
      runtimeVersion: runtimeVersion,
      metadata: metadata,
    );
  }

  Future<RuntimeVersion> _fetchRuntimeVersionAt(String blockHash) async {
    final rawVersion = await _transport.request(
      'state_getRuntimeVersion',
      <Object?>[blockHash],
    );
    if (rawVersion is! Map) {
      throw StateError('state_getRuntimeVersion 未返回对象');
    }
    return RuntimeVersion.fromJson(Map<String, dynamic>.from(rawVersion));
  }

  Future<String> _fetchBestHead() async {
    final raw = await _transport.request(
      'chain_getBlockHash',
      const <Object?>[],
    );
    if (raw is! String) {
      throw StateError('chain_getBlockHash 未返回当前 best 区块哈希');
    }
    return _normalizeHash(raw);
  }

  Future<RuntimeMetadata> _fetchMetadataForRuntime({
    required String blockHash,
    required int specVersion,
  }) async {
    final cached = _metadataCache;
    if (cached != null && cached.specVersion == specVersion) {
      return cached.metadata;
    }
    final current = _metadataInflight;
    if (current != null && current.specVersion == specVersion) {
      return current.future;
    }

    late final Future<RuntimeMetadata> task;
    task = _transport.request('state_getMetadata', <Object?>[blockHash]).then((
      raw,
    ) {
      if (raw is! String || raw.isEmpty) {
        throw StateError('state_getMetadata 未返回 metadata hex');
      }
      return RuntimeMetadata.fromHex(raw);
    });
    final inflight = _RuntimeMetadataInflight(
      specVersion: specVersion,
      future: task,
    );
    _metadataInflight = inflight;
    try {
      final metadata = await task;
      // 不同 specVersion 的新请求或显式失效会替换 identity。前一代 Future
      // 即使随后成功，也只能返回给原调用方，不得倒灌当前缓存。
      if (identical(_metadataInflight, inflight)) {
        _metadataCache = _RuntimeMetadataCache(
          specVersion: specVersion,
          metadata: metadata,
        );
      }
      return metadata;
    } finally {
      if (identical(_metadataInflight, inflight)) _metadataInflight = null;
    }
  }

  Future<RuntimeMetadata> fetchMetadata() async =>
      (await fetchRuntimeContext()).metadata;

  void invalidateRuntimeMetadata() {
    _metadataCache = null;
    _metadataInflight = null;
  }

  Future<Object?> fetchPalletConstant(String pallet, String name) async {
    final context = await fetchRuntimeContext();
    return _decodePalletConstant(context.metadata, pallet, name);
  }

  static Object? _decodePalletConstant(
    RuntimeMetadata metadata,
    String pallet,
    String name,
  ) {
    final constant = metadata.chainInfo.constants[pallet]?[name];
    if (constant == null) throw StateError('链上未下发常量 $pallet.$name');
    return constant.type.decode(ByteInput(constant.bytes));
  }

  Future<BigInt> fetchPalletConstantU128(String pallet, String name) async {
    final value = await _fetchPalletConstantInteger(pallet, name);
    if (value < BigInt.zero || value > _u128Max) {
      throw StateError('链上常量 $pallet.$name 超出 u128 范围');
    }
    return value;
  }

  /// 读取 metadata 中严格位于 u32 范围的整数常量。
  Future<int> fetchPalletConstantU32(String pallet, String name) async {
    final value = await _fetchPalletConstantInteger(pallet, name);
    if (value < BigInt.zero || value > _u32Max) {
      throw StateError('链上常量 $pallet.$name 超出 u32 范围');
    }
    return value.toInt();
  }

  Future<BigInt> _fetchPalletConstantInteger(String pallet, String name) async {
    return _requireIntegerConstant(
      await fetchPalletConstant(pallet, name),
      pallet,
      name,
    );
  }

  static BigInt _requireIntegerConstant(
    Object? value,
    String pallet,
    String name,
  ) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    throw StateError('链上常量 $pallet.$name 不是整数');
  }

  static void _requireU128(BigInt value, String pallet, String name) {
    if (value < BigInt.zero || value > _u128Max) {
      throw StateError('链上常量 $pallet.$name 超出 u128 范围');
    }
  }

  Future<BigInt> fetchMinimumSelfPayBalanceFen() async {
    final metadata = (await fetchRuntimeContext()).metadata;
    final minimumFee = _requireIntegerConstant(
      _decodePalletConstant(metadata, 'OnchainTransaction', 'OnchainMinFee'),
      'OnchainTransaction',
      'OnchainMinFee',
    );
    final existentialDeposit = _requireIntegerConstant(
      _decodePalletConstant(metadata, 'Balances', 'ExistentialDeposit'),
      'Balances',
      'ExistentialDeposit',
    );
    _requireU128(minimumFee, 'OnchainTransaction', 'OnchainMinFee');
    _requireU128(existentialDeposit, 'Balances', 'ExistentialDeposit');
    return minimumFee + existentialDeposit;
  }

  /// 按当前 runtime metadata 预估一笔链上资金交易的手续费，单位为分。
  ///
  /// `OnchainFeeRate` 是 Perbill 的 u32 parts，`OnchainMinFee` 是 u128；
  /// 两项都只从链上 metadata 读取。缺失、类型错误或越过 runtime 约束时
  /// 直接失败，不使用本地费率或最低费兜底。
  Future<BigInt> estimateOnchainTransactionFeeFen(BigInt amountFen) async {
    if (amountFen < BigInt.zero || amountFen > _u128Max) {
      throw ArgumentError.value(amountFen, 'amountFen', '金额必须位于 u128 范围');
    }
    final metadata = (await fetchRuntimeContext()).metadata;
    final feeRateValue = _requireIntegerConstant(
      _decodePalletConstant(metadata, 'OnchainTransaction', 'OnchainFeeRate'),
      'OnchainTransaction',
      'OnchainFeeRate',
    );
    if (feeRateValue < BigInt.zero || feeRateValue > _u32Max) {
      throw StateError('链上常量 OnchainTransaction.OnchainFeeRate 超出 u32 范围');
    }
    final feeRateParts = feeRateValue.toInt();
    final minimumFeeFen = _requireIntegerConstant(
      _decodePalletConstant(metadata, 'OnchainTransaction', 'OnchainMinFee'),
      'OnchainTransaction',
      'OnchainMinFee',
    );
    _requireU128(minimumFeeFen, 'OnchainTransaction', 'OnchainMinFee');
    final parts = BigInt.from(feeRateParts);
    if (parts <= BigInt.zero || parts > _perbillDenominator) {
      throw StateError('链上常量 OnchainTransaction.OnchainFeeRate 不是有效的正 Perbill');
    }
    if (minimumFeeFen <= BigInt.zero) {
      throw StateError('链上常量 OnchainTransaction.OnchainMinFee 必须大于 0');
    }

    // 与 runtime `mul_perbill_round` 逐项一致：先拆整量与余量，所有 u128
    // 加乘都饱和，余量加半个 Perbill 分母后做 half-up 整数舍入。
    final whole = amountFen ~/ _perbillDenominator;
    final remainder = amountFen % _perbillDenominator;
    final wholeComponent = _saturatingU128Multiply(whole, parts);
    final roundedRemainder =
        _saturatingU128Add(
          _saturatingU128Multiply(remainder, parts),
          _perbillDenominator ~/ BigInt.from(2),
        ) ~/
        _perbillDenominator;
    final byRate = _saturatingU128Add(wholeComponent, roundedRemainder);
    return byRate > minimumFeeFen ? byRate : minimumFeeFen;
  }

  static BigInt _saturatingU128Multiply(BigInt left, BigInt right) {
    if (left == BigInt.zero || right == BigInt.zero) return BigInt.zero;
    if (left > _u128Max ~/ right) return _u128Max;
    return left * right;
  }

  static BigInt _saturatingU128Add(BigInt left, BigInt right) {
    if (left > _u128Max - right) return _u128Max;
    return left + right;
  }

  Future<Uint8List?> fetchFinalizedStorage(String storageKeyHex) async {
    final value = await _transport.finalizedStorage(storageKeyHex);
    return value == null ? null : _hexDecode(value);
  }

  /// 一次读取并解码 finalized `System.Account` 的 free 与 reserved。
  ///
  /// [account] 必须是规范的小写 AccountId 或公民链 SS58；不存在或短于
  /// 当前 AccountInfo 中 `reserved` 末尾的存储值按零余额处理。
  Future<FinalizedAccountBalance> fetchFinalizedAccountBalance(
    String account,
  ) async {
    final entry = _finalizedAccountRequest(account);
    return _decodeFinalizedAccountBalance(
      entry,
      await _transport.finalizedStorage(entry.storageKeyHex),
    );
  }

  static _FinalizedAccountRequest _finalizedAccountRequest(String account) {
    final publicKey = account.startsWith('0x')
        ? citizenAccountIdBytes(account)
        : citizenPublicKeyFromSs58(account);
    final accountId = citizenAccountIdFromBytes(publicKey);
    final blake2 = Hasher.blake2b128.hash(publicKey);
    final key =
        Uint8List(
            _systemAccountPrefix.length + blake2.length + publicKey.length,
          )
          ..setAll(0, _systemAccountPrefix)
          ..setAll(_systemAccountPrefix.length, blake2)
          ..setAll(_systemAccountPrefix.length + blake2.length, publicKey);
    return _FinalizedAccountRequest(
      requestedAccount: account,
      accountId: accountId,
      storageKeyHex: '0x${_hex(key)}',
    );
  }

  static FinalizedAccountBalance _decodeFinalizedAccountBalance(
    _FinalizedAccountRequest entry,
    String? raw,
  ) {
    final data = raw == null ? null : _hexDecode(raw);
    if (data == null || data.length < 48) {
      return FinalizedAccountBalance(
        requestedAccount: entry.requestedAccount,
        accountId: entry.accountId,
        freeFen: BigInt.zero,
        reservedFen: BigInt.zero,
      );
    }
    return FinalizedAccountBalance(
      requestedAccount: entry.requestedAccount,
      accountId: entry.accountId,
      freeFen: _readU128(data, 16),
      reservedFen: _readU128(data, 32),
    );
  }

  /// 返回 finalized `System.Account.free`，单位为公民链整数分。
  Future<BigInt> fetchFinalizedBalanceFen(String account) async =>
      (await fetchFinalizedAccountBalance(account)).freeFen;

  /// 返回 finalized `free + reserved`，单位为公民链整数分。
  Future<BigInt> fetchFinalizedTotalBalanceFen(String account) async =>
      (await fetchFinalizedAccountBalance(account)).totalFen;

  /// 按输入顺序逐项读取 finalized `System.Account`。
  ///
  /// 所有输入先规范化为 storage key 并去重，再通过轻节点的一次原生 batch
  /// 调用读取；返回列表仍与原输入逐项对齐，重复账户复用同一个链上值但不会被
  /// Map 合并。每项同时携带 free、reserved 与 total，避免为不同余额重复取证。
  Future<List<FinalizedAccountBalance>> fetchFinalizedAccountBalances(
    Iterable<String> accounts,
  ) async {
    final requested = List<String>.of(accounts);
    if (requested.isEmpty) return const <FinalizedAccountBalance>[];
    final entries = <_FinalizedAccountRequest>[];
    final uniqueStorageKeys = <String>[];
    final seenStorageKeys = <String>{};
    for (final account in requested) {
      final entry = _finalizedAccountRequest(account);
      entries.add(entry);
      if (seenStorageKeys.add(entry.storageKeyHex)) {
        uniqueStorageKeys.add(entry.storageKeyHex);
      }
    }
    final rawValues = await _transport.finalizedStorageValues(
      List<String>.unmodifiable(uniqueStorageKeys),
    );
    return List<FinalizedAccountBalance>.unmodifiable(
      entries.map(
        (entry) => _decodeFinalizedAccountBalance(
          entry,
          rawValues[entry.storageKeyHex],
        ),
      ),
    );
  }

  /// 批量返回 finalized free；结果按输入位置对齐并保留重复项。
  Future<List<BigInt>> fetchFinalizedBalancesFen(
    Iterable<String> accounts,
  ) async {
    final balances = await fetchFinalizedAccountBalances(accounts);
    return List<BigInt>.unmodifiable(
      balances.map((balance) => balance.freeFen),
    );
  }

  /// 批量返回 finalized `free + reserved`；结果按输入位置对齐并保留重复项。
  Future<List<BigInt>> fetchFinalizedTotalBalancesFen(
    Iterable<String> accounts,
  ) async {
    final balances = await fetchFinalizedAccountBalances(accounts);
    return List<BigInt>.unmodifiable(
      balances.map((balance) => balance.totalFen),
    );
  }

  /// 提交已签名 extrinsic，拿到 txHash 立即返回。
  ///
  /// 与 CitizenApp 已验证管线一致，主提交通过
  /// `author_submitExtrinsic`，然后在本机轻节点上启动后台
  /// `author_submitAndWatchExtrinsic`。后台只在 finalized 锚上核对 runtime
  /// 执行结果；不把 txHash、广播或入块单独当成执行成功。
  Future<String> submitExtrinsic(
    Uint8List encoded, {
    Future<void> Function(String txHash)? beforeBroadcast,
    TransactionStatusCallback? onStatus,
    Duration watchTimeout = const Duration(minutes: 20),
    Duration executionLookupTimeout = const Duration(seconds: 30),
    Duration executionRetryInterval = const Duration(seconds: 1),
  }) async {
    if (encoded.isEmpty) throw ArgumentError('encoded 不能为空');
    _validateDuration(watchTimeout, 'watchTimeout');
    _validateDuration(executionLookupTimeout, 'executionLookupTimeout');
    _validateDuration(executionRetryInterval, 'executionRetryInterval');
    await _transport.ensureStarted();
    final extrinsicHex = '0x${_hex(encoded)}';
    final localTxHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    await beforeBroadcast?.call(localTxHash);
    final returnedTxHash = _normalizeHash(
      await _transport.submitExtrinsic(extrinsicHex),
    );
    if (returnedTxHash != localTxHash) {
      throw StateError('轻节点返回的 txHash 与已签名 extrinsic 本地哈希不一致');
    }
    unawaited(
      _watchInBackground(
        extrinsicHex,
        returnedTxHash,
        onStatus,
        watchTimeout: watchTimeout,
        executionLookupTimeout: executionLookupTimeout,
        executionRetryInterval: executionRetryInterval,
      ),
    );
    return returnedTxHash;
  }

  /// 提交并等待区块包含，随后核对 runtime 执行结果。
  ///
  /// [waitForFinalized] 为假时，结果已核对执行成功但区块仍可回退；
  /// 为真时只接受 finalized 锚。`future/dropped/retracted/finalityTimeout`
  /// 均不是确定失败，会继续等待；只有 `invalid/usurped` 立即失败。
  Future<({String txHash, TransactionStatus included, int extrinsicIndex})>
  submitAndWait(
    Uint8List encoded, {
    Future<void> Function(String txHash)? beforeBroadcast,
    TransactionStatusCallback? onStatus,
    bool waitForFinalized = false,
    Duration timeout = const Duration(minutes: 20),
    Duration executionLookupTimeout = const Duration(seconds: 30),
    Duration executionRetryInterval = const Duration(seconds: 1),
  }) async {
    if (encoded.isEmpty) throw ArgumentError('encoded 不能为空');
    _validateDuration(timeout, 'timeout');
    _validateDuration(executionLookupTimeout, 'executionLookupTimeout');
    _validateDuration(executionRetryInterval, 'executionRetryInterval');
    await _transport.ensureStarted();
    final extrinsicHex = '0x${_hex(encoded)}';
    final txHash = '0x${_hex(Hasher.blake2b256.hash(encoded))}';
    await beforeBroadcast?.call(txHash);
    final done = Completer<TransactionStatus>();
    StreamSubscription<Object?>? subscription;
    final timer = Timer(timeout, () {
      if (!done.isCompleted) {
        done.completeError(
          TimeoutException('交易 $txHash 在等待窗口内未达到目标区块状态', timeout),
        );
      }
    });
    try {
      subscription = _transport
          .subscribe('author_submitAndWatchExtrinsic', <Object?>[extrinsicHex])
          .listen(
            (raw) {
              // 目标区块状态一旦交给执行核对，done 会永久完成；此后交易池
              // 的迟到状态不能再通过回调制造与 runtime 结果冲突的终态。
              if (done.isCompleted) return;
              try {
                final status = TransactionStatus.fromRpc(raw);
                _notifyStatus(onStatus, status);
                if (status.isDefinitiveFailure && !done.isCompleted) {
                  done.completeError(StateError(status.description));
                  return;
                }
                final reached = waitForFinalized
                    ? status.kind == TransactionStatusKind.finalized
                    : status.kind == TransactionStatusKind.inBlock ||
                          status.kind == TransactionStatusKind.finalized;
                if (reached && !done.isCompleted) {
                  final blockHash = status.blockHash;
                  if (blockHash == null) {
                    done.completeError(StateError('交易状态未携带区块哈希'));
                  } else {
                    done.complete(status);
                  }
                }
              } on Object catch (error, stackTrace) {
                if (!done.isCompleted) {
                  done.completeError(error, stackTrace);
                }
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (done.isCompleted) return;
              _notifyStatus(
                onStatus,
                TransactionStatus(
                  kind: TransactionStatusKind.error,
                  description: '交易池订阅异常：$error',
                  raw: '$error',
                ),
              );
              if (!done.isCompleted) done.completeError(error, stackTrace);
            },
            onDone: () {
              if (!done.isCompleted) {
                done.completeError(StateError('交易池订阅结束但交易尚未入块'));
              }
            },
          );
      final included = await done.future;
      final blockHash = included.blockHash!;
      try {
        final extrinsicIndex = await _waitForExecutionResult(
          txHash: txHash,
          blockHash: blockHash,
          timeout: executionLookupTimeout,
          retryInterval: executionRetryInterval,
        );
        _notifyStatus(
          onStatus,
          TransactionStatus(
            kind: TransactionStatusKind.executionSuccess,
            description: '已核对 System.ExtrinsicSuccess',
            raw: 'System.ExtrinsicSuccess',
            blockHash: blockHash,
            extrinsicIndex: extrinsicIndex,
          ),
        );
        return (
          txHash: txHash,
          included: included,
          extrinsicIndex: extrinsicIndex,
        );
      } on TransactionDispatchException catch (error) {
        _notifyStatus(
          onStatus,
          TransactionStatus(
            kind: TransactionStatusKind.executionFailed,
            description: error.failure.description,
            raw: 'System.ExtrinsicFailed',
            blockHash: blockHash,
            extrinsicIndex: error.extrinsicIndex,
            dispatchFailure: error.failure,
          ),
        );
        rethrow;
      } on Object catch (error) {
        _notifyStatus(
          onStatus,
          TransactionStatus(
            kind: TransactionStatusKind.error,
            description: '链上执行结果未能核实：$error',
            raw: '$error',
            blockHash: blockHash,
          ),
        );
        rethrow;
      }
    } finally {
      timer.cancel();
      _cancelSubscriptionBestEffort(subscription);
    }
  }

  Future<void> _watchInBackground(
    String extrinsicHex,
    String txHash,
    TransactionStatusCallback? onStatus, {
    required Duration watchTimeout,
    required Duration executionLookupTimeout,
    required Duration executionRetryInterval,
  }) async {
    StreamSubscription<Object?>? subscription;
    final done = Completer<void>();
    var sawAnyStatus = false;
    var executionCheckStarted = false;
    Timer? timer;
    try {
      await _transport.ensureStarted();
      timer = Timer(watchTimeout, () {
        if (done.isCompleted) return;
        _notifyStatus(
          onStatus,
          TransactionStatus(
            kind: TransactionStatusKind.timeout,
            description: sawAnyStatus
                ? '在 ${watchTimeout.inSeconds} 秒观察窗口内未达到 finalized，交易成功性未确定'
                : '在 ${watchTimeout.inSeconds} 秒观察窗口内未收到交易池状态，交易成功性未确定',
            raw: 'timeout',
          ),
        );
        done.complete();
      });
      subscription = _transport
          .subscribe('author_submitAndWatchExtrinsic', <Object?>[extrinsicHex])
          .listen(
            (raw) {
              // finalized 已把终态所有权交给 System.Events 核对；此后交易池
              // 订阅里的迟到状态、畸形消息或错误都不能再制造第二个终态。
              if (executionCheckStarted || done.isCompleted) return;
              try {
                sawAnyStatus = true;
                final status = TransactionStatus.fromRpc(raw);
                _notifyStatus(onStatus, status);
                if (status.isDefinitiveFailure && !done.isCompleted) {
                  done.complete();
                  return;
                }
                if (status.kind != TransactionStatusKind.finalized ||
                    executionCheckStarted ||
                    done.isCompleted) {
                  return;
                }
                final blockHash = status.blockHash;
                if (blockHash == null) {
                  _notifyStatus(
                    onStatus,
                    const TransactionStatus(
                      kind: TransactionStatusKind.error,
                      description: 'finalized 状态未携带有效区块哈希，链上执行结果未核实',
                      raw: 'finalized-without-block-hash',
                    ),
                  );
                  done.complete();
                  return;
                }
                executionCheckStarted = true;
                // watchTimeout 只约束看到 finalized 的窗口；进入执行核对后由
                // executionLookupTimeout 独立约束，不能让先前定时器提前静默结束。
                timer?.cancel();
                unawaited(
                  _finishBackgroundExecutionCheck(
                    txHash: txHash,
                    blockHash: blockHash,
                    timeout: executionLookupTimeout,
                    retryInterval: executionRetryInterval,
                    onStatus: onStatus,
                    done: done,
                  ),
                );
              } on Object catch (error) {
                _notifyStatus(
                  onStatus,
                  TransactionStatus(
                    kind: TransactionStatusKind.error,
                    description: '交易状态解析异常：$error',
                    raw: '$error',
                  ),
                );
                if (!done.isCompleted) done.complete();
              }
            },
            onError: (Object error) {
              if (executionCheckStarted || done.isCompleted) return;
              _notifyStatus(
                onStatus,
                TransactionStatus(
                  kind: TransactionStatusKind.error,
                  description: '交易池订阅异常：$error',
                  raw: '$error',
                ),
              );
              if (!done.isCompleted) done.complete();
            },
            onDone: () {
              if (!done.isCompleted && !executionCheckStarted) {
                _notifyStatus(
                  onStatus,
                  const TransactionStatus(
                    kind: TransactionStatusKind.error,
                    description: '交易池订阅提前结束，尚未达到 finalized，交易成功性未确定',
                    raw: 'subscription-closed-before-finalized',
                  ),
                );
                done.complete();
              }
            },
          );
      await done.future;
    } on Object catch (error) {
      _notifyStatus(
        onStatus,
        TransactionStatus(
          kind: TransactionStatusKind.error,
          description: '交易后台观察异常：$error',
          raw: '$error',
        ),
      );
    } finally {
      timer?.cancel();
      _cancelSubscriptionBestEffort(subscription);
    }
  }

  Future<void> _finishBackgroundExecutionCheck({
    required String txHash,
    required String blockHash,
    required Duration timeout,
    required Duration retryInterval,
    required TransactionStatusCallback? onStatus,
    required Completer<void> done,
  }) async {
    try {
      final extrinsicIndex = await _waitForExecutionResult(
        txHash: txHash,
        blockHash: blockHash,
        timeout: timeout,
        retryInterval: retryInterval,
      );
      _notifyStatus(
        onStatus,
        TransactionStatus(
          kind: TransactionStatusKind.executionSuccess,
          description: '已核对 System.ExtrinsicSuccess',
          raw: 'System.ExtrinsicSuccess',
          blockHash: blockHash,
          extrinsicIndex: extrinsicIndex,
        ),
      );
    } on TransactionDispatchException catch (error) {
      _notifyStatus(
        onStatus,
        TransactionStatus(
          kind: TransactionStatusKind.executionFailed,
          description: error.failure.description,
          raw: 'System.ExtrinsicFailed',
          blockHash: blockHash,
          extrinsicIndex: error.extrinsicIndex,
          dispatchFailure: error.failure,
        ),
      );
    } on Object catch (error) {
      _notifyStatus(
        onStatus,
        TransactionStatus(
          kind: TransactionStatusKind.error,
          description: '链上执行结果未能核实：$error',
          raw: '$error',
          blockHash: blockHash,
        ),
      );
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }

  Future<int> _waitForExecutionResult({
    required String txHash,
    required String blockHash,
    required Duration timeout,
    required Duration retryInterval,
  }) async {
    _validateDuration(timeout, 'timeout');
    _validateDuration(retryInterval, 'retryInterval');
    // executionLookupTimeout 是从目标块出现后到 runtime 结果核实结束的总预算，
    // 不能只在一次 RPC 返回后检查。传输层 Future 可能永不完成，因此块体和每次
    // System.Events 读取都必须绑定到同一单调 deadline；Duration.zero 不等待任何
    // 未完成 Future，并立即以“未核实”结束。
    final stopwatch = Stopwatch()..start();
    Duration remainingBudget() {
      final remaining = timeout - stopwatch.elapsed;
      return remaining > Duration.zero ? remaining : Duration.zero;
    }

    final int extrinsicIndex;
    try {
      // CitizenApp 的已验证约束：同一块 body 只取一次，禁止因结果
      // 核对而重复拉取，避免触发 Substrate peer 反滥用限制。
      final extrinsics = await fetchBlockExtrinsics(
        blockHash,
      ).timeout(remainingBudget());
      final matched = await findExtrinsicIndexInHexList(
        extrinsics,
        txHashHex: txHash,
      ).timeout(remainingBudget());
      if (matched == null) {
        throw StateError('目标区块中未找到该 txHash');
      }
      extrinsicIndex = matched;
    } on Object catch (error) {
      throw TransactionExecutionUnverifiedException(
        txHash: txHash,
        blockHash: blockHash,
        description: '交易已入块，但无法定位目标 extrinsic',
        cause: error,
      );
    }
    Object? lastError;
    do {
      try {
        final events = await fetchSystemEventsAtBlock(
          blockHash,
        ).timeout(remainingBudget());
        if (events == null || events.isEmpty) {
          throw StateError('目标区块没有可核对的 System.Events');
        }
        final ChainExtrinsicOutcome? outcome;
        try {
          outcome = await _findExtrinsicOutcome(
            events,
            extrinsicIndex: extrinsicIndex,
            blockHash: blockHash,
          ).timeout(remainingBudget());
        } on TimeoutException {
          // 传输层 metadata Future 可能永不完成；清除本次缓存身份，使之后的
          // 独立交易可以重新请求，而迟到的前一代 Future 由 fetchMetadata 的 identity
          // 守卫禁止污染新缓存。
          invalidateRuntimeMetadata();
          rethrow;
        }
        if (outcome == null) {
          throw StateError('未找到同一 extrinsic 的 Success/Failed 事件');
        }
        if (!outcome.isSuccess) {
          throw TransactionDispatchException(
            txHash: txHash,
            blockHash: blockHash,
            extrinsicIndex: extrinsicIndex,
            failure: outcome.failure!,
          );
        }
        return extrinsicIndex;
      } on TransactionDispatchException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
      }
      if (stopwatch.elapsed >= timeout) break;
      if (retryInterval > Duration.zero) {
        final remaining = timeout - stopwatch.elapsed;
        if (remaining <= Duration.zero) break;
        await Future<void>.delayed(
          retryInterval < remaining ? retryInterval : remaining,
        );
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    } while (stopwatch.elapsed < timeout);
    throw TransactionExecutionUnverifiedException(
      txHash: txHash,
      blockHash: blockHash,
      description: '交易已入块，但未能核实 runtime 执行结果',
      cause: lastError,
    );
  }

  /// 读取指定区块的 extrinsic hex 列表。
  ///
  /// 该入口只用于核对本机刚提交的单笔交易，不得用于历史窗口扫块。
  Future<List<String>> fetchBlockExtrinsics(String blockHashHex) async {
    final blockHash = _normalizeHash(blockHashHex);
    final extrinsics = await _transport
        .blockExtrinsicsOnce(blockHash)
        .timeout(const Duration(seconds: 8));
    return <String>[for (final value in extrinsics) _normalizeHexBytes(value)];
  }

  /// 查询指定区块的 `System.Events` 原始 SCALE 数据。
  Future<Uint8List?> fetchSystemEventsAtBlock(String blockHashHex) async {
    final blockHash = _normalizeHash(blockHashHex);
    final value = await _transport.request('state_getStorage', <Object?>[
      '0x${_hex(_systemEventsKey)}',
      blockHash,
    ]);
    if (value == null) return null;
    if (value is! String) throw StateError('System.Events 不是 hex');
    return _hexDecode(value);
  }

  /// 在目标区块中按 txHash 定位 extrinsic index。
  Future<int?> findSubmittedExtrinsicIndexAtBlock({
    required String blockHashHex,
    required String txHashHex,
  }) async {
    final extrinsics = await fetchBlockExtrinsics(blockHashHex);
    return findExtrinsicIndexInHexList(extrinsics, txHashHex: txHashHex);
  }

  /// 用目标块自己的 runtime metadata 核对指定 extrinsic 的明确执行终态。
  ///
  /// 只在读到同 index 的 `System.ExtrinsicSuccess/Failed` 时返回结果；metadata
  /// 解码失败、事件缺失或 index 不存在均返回 null，调用方不得把 null 当成功。
  Future<ChainExtrinsicOutcome?> findExtrinsicOutcomeAtBlock({
    required Uint8List eventsBytes,
    required int extrinsicIndex,
    required String blockHashHex,
  }) => _findExtrinsicOutcome(
    eventsBytes,
    extrinsicIndex: extrinsicIndex,
    blockHash: _normalizeHash(blockHashHex),
  );

  /// 在一批 extrinsic hex 中按 blake2b256 txHash 定位。
  ///
  /// 与 CitizenApp 一致，逐条哈希放到 isolate，避免阻塞 Flutter UI
  /// isolate。只查单个已知区块，不扫描历史区块。
  static Future<int?> findExtrinsicIndexInHexList(
    List<String> extrinsics, {
    required String txHashHex,
  }) {
    return Isolate.run(
      () => findExtrinsicIndexInHexListSync(extrinsics, txHashHex: txHashHex),
    );
  }

  @visibleForTesting
  static int? findExtrinsicIndexInHexListSync(
    List<String> extrinsics, {
    required String txHashHex,
  }) {
    final normalizedTxHash = _normalizeHash(txHashHex);
    for (var index = 0; index < extrinsics.length; index++) {
      final encoded = _hexDecode(extrinsics[index]);
      final hash = Hasher.blake2b256.hash(encoded);
      final hashHex = '0x${_hex(hash)}';
      if (hashHex == normalizedTxHash) return index;
    }
    return null;
  }

  Future<ChainExtrinsicOutcome?> _findExtrinsicOutcome(
    Uint8List data, {
    required int extrinsicIndex,
    required String blockHash,
  }) async {
    try {
      final metadata = (await fetchRuntimeContext(
        blockHashHex: blockHash,
      )).metadata;
      final events = Events.fromJson(<String, dynamic>{
        'changes': <Object?>[
          <Object?>['0x${_hex(_systemEventsKey)}', '0x${_hex(data)}'],
        ],
      }, metadata.chainInfo);
      for (final record in events.eventRecord) {
        if (_decodedExtrinsicIndex(record.phase) != extrinsicIndex) continue;
        final system = record.event['System'] ?? record.event['system'];
        if (system is! Map) continue;
        if (system.containsKey('ExtrinsicFailed') ||
            system.containsKey('extrinsicFailed')) {
          final raw = system['ExtrinsicFailed'] ?? system['extrinsicFailed'];
          return ChainExtrinsicOutcome.failed(_decodeStructuredFailure(raw));
        }
        if (system.containsKey('ExtrinsicSuccess') ||
            system.containsKey('extrinsicSuccess')) {
          return const ChainExtrinsicOutcome.success();
        }
      }
      return null;
    } on Object {
      // EventRecord 的 payload 长度只能由对应 runtime metadata 确定。禁止在
      // 任意事件 payload 中滑窗寻找看似 ApplyExtrinsic/System 的字节模式；
      // metadata 解码失败必须 fail closed，由上层重试后报告“执行未核实”。
      return null;
    }
  }

  static int? _decodedExtrinsicIndex(Map<String, dynamic> phase) {
    final value = phase['ApplyExtrinsic'] ?? phase['applyExtrinsic'];
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static ChainExtrinsicFailure _decodeStructuredFailure(Object? raw) {
    final dispatch = _findDispatchError(raw);
    if (dispatch is Map) {
      final module = dispatch['Module'] ?? dispatch['module'];
      if (module is Map) {
        final moduleIndex = _asInt(module['index'] ?? module['0']);
        final errorIndex = _firstErrorByte(module['error'] ?? module['1']);
        if (moduleIndex != null && errorIndex != null) {
          return ChainExtrinsicFailure(
            dispatchErrorVariant: 3,
            moduleIndex: moduleIndex,
            errorIndex: errorIndex,
            description: _describeRuntimeModuleError(moduleIndex, errorIndex),
          );
        }
      }
      for (final entry in dispatch.entries) {
        final name = '${entry.key}';
        final variant = _dispatchVariantByName(name);
        if (variant != null) {
          return ChainExtrinsicFailure(
            dispatchErrorVariant: variant,
            description: '链上执行失败：${_dispatchErrorName(variant)}',
          );
        }
      }
    }
    return const ChainExtrinsicFailure(
      dispatchErrorVariant: 255,
      description: '链上执行失败：DispatchError 无法解码',
    );
  }

  static Object? _findDispatchError(Object? raw) {
    if (raw is List) return raw.isEmpty ? null : raw.first;
    if (raw is! Map) return raw;
    if (raw.containsKey('Module') || raw.containsKey('module')) return raw;
    for (final key in const <String>[
      'DispatchError',
      'dispatch_error',
      'dispatchError',
      'error',
      '0',
    ]) {
      if (raw.containsKey(key)) return raw[key];
    }
    if (raw.length == 1) return raw.values.first;
    for (final value in raw.values) {
      if (value is Map &&
          (value.containsKey('Module') || value.containsKey('module'))) {
        return value;
      }
    }
    return raw;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _firstErrorByte(Object? value) {
    final direct = _asInt(value);
    if (direct != null) return direct;
    if (value is List && value.isNotEmpty) return _asInt(value.first);
    if (value is Map && value.isNotEmpty) return _asInt(value.values.first);
    return null;
  }

  static String _describeRuntimeModuleError(int moduleIndex, int errorIndex) {
    if (moduleIndex == 4) {
      final name = switch (errorIndex) {
        0 => 'ZeroAmount',
        1 => 'SelfTransferNotAllowed',
        2 => 'TransferFailed',
        _ => 'error_$errorIndex',
      };
      final hint = switch (errorIndex) {
        0 => '转账金额不能为零',
        1 => '不能向当前账户转账',
        2 => '余额模块拒绝转账，请核对余额和最小存活余额',
        _ => null,
      };
      final code = 'OnchainTransaction.$name';
      return hint == null ? '链上执行失败：$code' : '链上执行失败：$code，$hint';
    }
    return '链上执行失败：Module($moduleIndex).error_$errorIndex';
  }

  static String _dispatchErrorName(int variant) => switch (variant) {
    0 => 'Other',
    1 => 'CannotLookup',
    2 => 'BadOrigin',
    3 => 'Module',
    4 => 'ConsumerRemaining',
    5 => 'NoProviders',
    6 => 'TooManyConsumers',
    7 => 'Token',
    8 => 'Arithmetic',
    9 => 'Transactional',
    10 => 'Exhausted',
    11 => 'Corruption',
    12 => 'Unavailable',
    13 => 'RootNotAllowed',
    _ => 'DispatchError($variant)',
  };

  static int? _dispatchVariantByName(String value) => switch (value) {
    'Other' || 'other' => 0,
    'CannotLookup' || 'cannotLookup' || 'cannot_lookup' => 1,
    'BadOrigin' || 'badOrigin' || 'bad_origin' => 2,
    'Module' || 'module' => 3,
    'ConsumerRemaining' || 'consumerRemaining' || 'consumer_remaining' => 4,
    'NoProviders' || 'noProviders' || 'no_providers' => 5,
    'TooManyConsumers' || 'tooManyConsumers' || 'too_many_consumers' => 6,
    'Token' || 'token' => 7,
    'Arithmetic' || 'arithmetic' => 8,
    'Transactional' || 'transactional' => 9,
    'Exhausted' || 'exhausted' => 10,
    'Corruption' || 'corruption' => 11,
    'Unavailable' || 'unavailable' => 12,
    'RootNotAllowed' || 'rootNotAllowed' || 'root_not_allowed' => 13,
    _ => null,
  };

  static final Uint8List _systemAccountPrefix = _hexDecode(
    '26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9',
  );

  static final Uint8List _systemEventsKey = _buildStorageValueKey(
    'System',
    'Events',
  );

  static Uint8List _buildStorageValueKey(String pallet, String storage) {
    final palletHash = Hasher.twoxx128.hashString(pallet);
    final storageHash = Hasher.twoxx128.hashString(storage);
    return Uint8List(palletHash.length + storageHash.length)
      ..setAll(0, palletHash)
      ..setAll(palletHash.length, storageHash);
  }

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
      throw StateError('区块或交易哈希无效');
    }
    return normalized.toLowerCase();
  }

  static String _normalizeHexBytes(String value) {
    final normalized = value.startsWith('0x') ? value : '0x$value';
    final hex = normalized.substring(2);
    if (hex.isEmpty ||
        hex.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      throw StateError('extrinsic hex 无效');
    }
    return normalized.toLowerCase();
  }

  static void _validateDuration(Duration value, String name) {
    if (value.isNegative) throw ArgumentError.value(value, name);
  }

  /// 交易终态已经由状态机拥有，订阅取消只能做非阻塞资源收口。
  ///
  /// `cancel()` 的 Future 允许异步失败；若只交给 [unawaited]，错误仍会泄漏到
  /// 宿主 Zone。这里同时消费同步抛错与异步失败，但不等待一个可能永不完成的
  /// 第三方清理 Future，避免覆盖或卡住已经确定的交易结果。
  static void _cancelSubscriptionBestEffort(
    StreamSubscription<Object?>? subscription,
  ) {
    if (subscription == null) return;
    try {
      final cancellation = subscription.cancel();
      unawaited(
        cancellation.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
    } on Object {
      // best-effort：同步取消异常同样不能反向改写交易终态。
    }
  }
}

final class _RuntimeMetadataCache {
  const _RuntimeMetadataCache({
    required this.specVersion,
    required this.metadata,
  });

  final int specVersion;
  final RuntimeMetadata metadata;
}

final class _RuntimeMetadataInflight {
  const _RuntimeMetadataInflight({
    required this.specVersion,
    required this.future,
  });

  final int specVersion;
  final Future<RuntimeMetadata> future;
}

final class _FinalizedAccountRequest {
  const _FinalizedAccountRequest({
    required this.requestedAccount,
    required this.accountId,
    required this.storageKeyHex,
  });

  final String requestedAccount;
  final String accountId;
  final String storageKeyHex;
}
