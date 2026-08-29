import 'dart:async';

import '../smoldot/chain.dart';
import '../smoldot/client.dart';
import '../smoldot/types.dart';
import 'bootstrap_client.dart';
import 'bootstrap_manifest.dart';
import 'chain_assets.dart';
import 'chain_database_store.dart';
import 'chain_health.dart';
import 'sdk_log.dart';

/// 公民链内嵌 smoldot 轻节点。
///
/// 实例拥有自己的生命周期，不使用 CitizenApp 单例。宿主通常在进程内只创建一个实例，
/// 并在退出时调用 [dispose]。查询和提交均直接经过本机轻节点 P2P。
final class CitizenLightClient {
  CitizenLightClient({
    CitizenChainAssets assets = const CitizenChainAssets(),
    BootstrapClient? bootstrapClient,
    ChainDatabaseStore? databaseStore,
    CitizenSdkLogger logger = discardCitizenSdkLog,
    int maxLogLevel = 1,
  }) : _assets = assets,
       _bootstrapClient = bootstrapClient ?? BootstrapClient(),
       _databaseStore = databaseStore,
       _logger = logger,
       _maxLogLevel = maxLogLevel;

  final CitizenChainAssets _assets;
  final BootstrapClient _bootstrapClient;
  final ChainDatabaseStore? _databaseStore;
  final CitizenSdkLogger _logger;
  final int _maxLogLevel;

  final StreamController<ChainHealthSnapshot> _healthController =
      StreamController<ChainHealthSnapshot>.broadcast(sync: true);
  ChainHealthSnapshot _health = const ChainHealthSnapshot.uninitialized();
  SmoldotClient? _client;
  Chain? _chain;
  String? _genesisHash;
  Future<void>? _startFuture;
  Future<void>? _disposeFuture;
  int _generation = 0;
  bool _disposed = false;

  ChainHealthSnapshot get health => _health;
  Stream<ChainHealthSnapshot> get healthChanges => _healthController.stream;
  bool get isReady => !_disposed && _client != null && _chain != null;
  String? get genesisHash => _genesisHash;

  Future<void> ensureStarted() {
    if (_disposed) throw StateError('CitizenLightClient 已销毁');
    if (isReady) return Future<void>.value();
    final current = _startFuture;
    if (current != null) return current;
    final generation = _generation;
    late final Future<void> task;
    task = _start(generation).whenComplete(() {
      if (identical(_startFuture, task)) _startFuture = null;
    });
    _startFuture = task;
    return task;
  }

  Future<void> _start(int generation) async {
    _setHealth(ChainHealthStatus.starting);
    BootstrapManifest? bootstrap;
    try {
      bootstrap = await _bootstrapClient.fetch();
    } on Object catch (error) {
      _log(
        CitizenSdkLogLevel.warning,
        '远端 bootnode 清单不可用，继续使用随包 chainspec',
        error,
      );
    }
    final bundle = await _assets.load(bootstrap: bootstrap);
    _ensureCurrent(generation);
    _genesisHash = bundle.genesisHash;

    String? databaseContent;
    final store = _databaseStore;
    if (store != null) {
      try {
        final raw = await store.read();
        if (raw != null) {
          databaseContent = ChainDatabaseEnvelope.parse(
            raw,
            expectedGenesisHash: bundle.genesisHash,
          ).databaseContent;
        }
      } on Object catch (error) {
        await store.delete();
        _log(CitizenSdkLogLevel.warning, '已丢弃无效轻节点同步缓存', error);
      }
    }
    _ensureCurrent(generation);

    final client = SmoldotClient(
      config: SmoldotConfig(maxLogLevel: _maxLogLevel),
    );
    try {
      await client.initialize();
      _ensureCurrent(generation);
      Chain? chain;
      try {
        chain = await client.addChain(
          AddChainConfig(
            chainSpec: bundle.chainSpec,
            databaseContent: databaseContent,
          ),
        );
      } on Object catch (cacheError) {
        if (databaseContent == null) rethrow;
        await store?.delete();
        _log(CitizenSdkLogLevel.warning, '同步缓存恢复失败，改从随包创世锚启动', cacheError);
        chain = await client.addChain(
          AddChainConfig(chainSpec: bundle.chainSpec),
        );
      }
      _ensureCurrent(generation);
      _client = client;
      _chain = chain;
      _setHealth(ChainHealthStatus.syncing);
    } on Object {
      if (!identical(_client, client)) await client.dispose();
      rethrow;
    }
  }

  Future<void> waitUntilSynced({
    Duration timeout = const Duration(minutes: 3),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    await ensureStarted();
    try {
      await _requireChain().waitUntilSynced(
        timeout: timeout,
        pollInterval: pollInterval,
      );
      await refreshHealth();
    } on Object catch (error) {
      _setHealth(ChainHealthStatus.degraded, error: error);
      rethrow;
    }
  }

  Future<ChainHealthSnapshot> refreshHealth() async {
    await ensureStarted();
    try {
      final snapshot = await _requireChain().getStatusSnapshot();
      final health = ChainHealthSnapshot(
        status: snapshot.isUsable
            ? ChainHealthStatus.operational
            : ChainHealthStatus.syncing,
        peerCount: snapshot.peerCount,
        isUsable: snapshot.isUsable,
        currentVerifiedFinalizedBlockNumber:
            snapshot.currentVerifiedFinalizedBlockNumber,
        currentVerifiedFinalizedBlockHash:
            snapshot.currentVerifiedFinalizedBlockHash,
        bestBlockNumber: snapshot.bestBlockNumber,
        bestBlockHash: snapshot.bestBlockHash,
      );
      _health = health;
      _healthController.add(health);
      return health;
    } on Object catch (error) {
      _setHealth(ChainHealthStatus.degraded, error: error);
      rethrow;
    }
  }

  Future<Object?> request(
    String method, [
    List<Object?> params = const [],
  ]) async {
    await ensureStarted();
    final response = await _requireChain().request(method, params);
    if (response.isError) {
      throw StateError('$method 失败：${response.error}');
    }
    return response.result;
  }

  Stream<Object?> subscribe(String method, [List<Object?> params = const []]) {
    if (!isReady) throw StateError('轻节点尚未启动');
    return _requireChain().subscribe(method, params).map<Object?>((response) {
      if (response.isError) throw StateError('$method 订阅失败：${response.error}');
      return response.result;
    });
  }

  Future<Map<String, dynamic>> runtimeVersion() async {
    await ensureStarted();
    return _requireChain().getRuntimeVersionJson();
  }

  Future<String> metadataHex() async {
    await ensureStarted();
    return _requireChain().getMetadataHex();
  }

  Future<int> accountNextIndex(String accountIdHex) async {
    await ensureStarted();
    return _requireChain().getAccountNextIndex(accountIdHex);
  }

  Future<String> blockHash(int blockNumber) async {
    await ensureStarted();
    return _requireChain().getBlockHash(blockNumber);
  }

  Future<String?> finalizedStorage(String storageKeyHex) async {
    await ensureStarted();
    return _requireChain().getFinalizedStorageValueHex(storageKeyHex);
  }

  Future<String> submitExtrinsic(String extrinsicHex) async {
    await ensureStarted();
    return _requireChain().submitExtrinsicHex(extrinsicHex);
  }

  Future<void> persistDatabase() async {
    final store = _databaseStore;
    final genesis = _genesisHash;
    if (store == null || genesis == null || !isReady) return;
    final chain = _requireChain();
    final before = await chain.getStatusSnapshot();
    if (!before.isUsable) return;
    final response = await chain.request(
      'chainHead_unstable_finalizedDatabase',
      const <Object?>[ChainDatabaseEnvelope.maxDatabaseBytes],
    );
    if (response.isError || response.result is! String) {
      throw StateError('导出轻节点同步数据库失败：${response.error}');
    }
    final after = await chain.getStatusSnapshot();
    if (!after.isUsable ||
        before.currentVerifiedFinalizedBlockNumber !=
            after.currentVerifiedFinalizedBlockNumber ||
        before.currentVerifiedFinalizedBlockHash.toLowerCase() !=
            after.currentVerifiedFinalizedBlockHash.toLowerCase()) {
      return;
    }
    final envelope = ChainDatabaseEnvelope(
      genesisHash: genesis,
      finalizedBlockNumber: after.currentVerifiedFinalizedBlockNumber,
      finalizedBlockHash: after.currentVerifiedFinalizedBlockHash,
      databaseContent: response.result! as String,
    );
    await store.write(envelope.encode());
  }

  Future<void> dispose() {
    final current = _disposeFuture;
    if (current != null) return current;
    late final Future<void> task;
    task = _dispose().whenComplete(() {
      if (identical(_disposeFuture, task)) _disposeFuture = null;
    });
    _disposeFuture = task;
    return task;
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    _generation++;
    try {
      await persistDatabase();
    } on Object catch (error) {
      _log(CitizenSdkLogLevel.warning, '退出前保存同步数据库失败', error);
    }
    final client = _client;
    _chain = null;
    _client = null;
    if (client != null) await client.dispose();
    _disposed = true;
    _setHealth(ChainHealthStatus.disposed);
    await _healthController.close();
    _bootstrapClient.close();
  }

  Chain _requireChain() {
    final chain = _chain;
    if (chain == null) throw StateError('公民链轻节点尚未启动');
    return chain;
  }

  void _ensureCurrent(int generation) {
    if (_disposed || generation != _generation) {
      throw StateError('轻节点初始化已被新的生命周期取消');
    }
  }

  void _setHealth(ChainHealthStatus status, {Object? error}) {
    final current = _health;
    final next = ChainHealthSnapshot(
      status: status,
      peerCount: current.peerCount,
      isUsable: status == ChainHealthStatus.operational && current.isUsable,
      currentVerifiedFinalizedBlockNumber:
          current.currentVerifiedFinalizedBlockNumber,
      currentVerifiedFinalizedBlockHash:
          current.currentVerifiedFinalizedBlockHash,
      bestBlockNumber: current.bestBlockNumber,
      bestBlockHash: current.bestBlockHash,
      lastError: error?.toString(),
    );
    _health = next;
    if (!_healthController.isClosed) _healthController.add(next);
  }

  void _log(CitizenSdkLogLevel level, String message, [Object? error]) {
    _logger(
      CitizenSdkLogEvent(
        level: level,
        scope: 'light_client',
        message: message,
        error: error,
      ),
    );
  }
}
