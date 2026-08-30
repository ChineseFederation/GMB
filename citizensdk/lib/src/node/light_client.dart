import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart' show visibleForTesting;

import '../smoldot/smoldot.dart';
import 'bootstrap_client.dart';
import 'bootstrap_manifest.dart';
import 'chain_assets.dart';
import 'chain_database_store.dart';
import 'chain_health.dart';
import 'sdk_log.dart';

/// CitizenSDK 实例拥有的 citizenchain 轻节点客户端管理器。
///
/// 基于 smoldot 轻客户端，仅在宿主明确访问链能力时初始化，加载
/// chainspec 后
/// 加入 citizenchain P2P 网络；非链业务不得隐式启动本客户端。
///
/// 所有链上读操作内置瞬断重试（最多 4 次，间隔 2 秒），
/// 并维护 [healthStatus] 供 UI 层展示链状态。
final class CitizenLightClient {
  factory CitizenLightClient({
    CitizenChainAssets assets = const CitizenChainAssets(),
    BootstrapClient? bootstrapClient,
    ChainDatabaseStore? databaseStore,
    CitizenSdkLogger logger = discardCitizenSdkLog,
    int maxLogLevel = 1,
    Duration databaseCacheRefreshInterval = const Duration(minutes: 1),
  }) {
    return CitizenLightClient._(
      assets: assets,
      bootstrapClient: bootstrapClient ?? BootstrapClient(),
      databaseStore: databaseStore,
      logger: logger,
      maxLogLevel: maxLogLevel,
      databaseCacheRefreshInterval: databaseCacheRefreshInterval,
    );
  }

  CitizenLightClient._({
    CitizenChainAssets assets = const CitizenChainAssets(),
    BootstrapClient? bootstrapClient,
    ChainDatabaseStore? databaseStore,
    CitizenSdkLogger logger = discardCitizenSdkLog,
    int maxLogLevel = 1,
    Future<void> Function()? initializeOverride,
    Future<void> Function()? disposeOverride,
    Future<LightClientStatusSnapshot> Function()? cacheStatusOverride,
    Future<String> Function()? databaseExportOverride,
    Future<void> Function(Duration timeout)? synchronizeOverride,
    Future<LightClientStatusSnapshot> Function()? syncStatusOverride,
    Stream<Object?> Function(String method, List<Object?> params)?
    subscribeOverride,
    Future<Object?> Function(String method, List<Object?> params)?
    requestOverride,
    String? expectedGenesisHashOverride,
    Duration databaseCacheRefreshInterval = const Duration(minutes: 1),
    Duration retrySyncDelay = const Duration(seconds: 60),
    int retrySyncAttempts = 5,
  }) : _assets = assets,
       _bootstrapClient = bootstrapClient,
       _databaseStore = databaseStore,
       _logger = logger,
       _maxLogLevel = maxLogLevel,
       _initializeOverride = initializeOverride,
       _disposeOverride = disposeOverride,
       _cacheStatusOverride = cacheStatusOverride,
       _databaseExportOverride = databaseExportOverride,
       _synchronizeOverride = synchronizeOverride,
       _syncStatusOverride = syncStatusOverride,
       _subscribeOverride = subscribeOverride,
       _requestOverride = requestOverride,
       _expectedGenesisHashOverride = expectedGenesisHashOverride,
       _databaseCacheRefreshInterval = databaseCacheRefreshInterval,
       _retrySyncDelay = retrySyncDelay,
       _retrySyncAttempts = retrySyncAttempts;

  /// 生命周期单测专用实例，不加载 Flutter asset 或原生 smoldot。
  @visibleForTesting
  factory CitizenLightClient.forTesting({
    required Future<void> Function() initialize,
    Future<void> Function()? dispose,
    Future<LightClientStatusSnapshot> Function()? cacheStatus,
    Future<String> Function()? exportDatabase,
    Future<void> Function(Duration timeout)? synchronize,
    Future<LightClientStatusSnapshot> Function()? syncStatus,
    Stream<Object?> Function(String method, List<Object?> params)? subscribe,
    Future<Object?> Function(String method, List<Object?> params)? request,
    String? expectedGenesisHash,
    ChainDatabaseStore? databaseStore,
    CitizenSdkLogger logger = discardCitizenSdkLog,
    Duration databaseCacheRefreshInterval = const Duration(minutes: 1),
    Duration retrySyncDelay = const Duration(seconds: 60),
    int retrySyncAttempts = 5,
  }) {
    return CitizenLightClient._(
      initializeOverride: initialize,
      disposeOverride: dispose,
      cacheStatusOverride: cacheStatus,
      databaseExportOverride: exportDatabase,
      synchronizeOverride: synchronize,
      syncStatusOverride: syncStatus,
      subscribeOverride: subscribe,
      requestOverride: request,
      expectedGenesisHashOverride: expectedGenesisHash,
      databaseStore: databaseStore,
      logger: logger,
      databaseCacheRefreshInterval: databaseCacheRefreshInterval,
      retrySyncDelay: retrySyncDelay,
      retrySyncAttempts: retrySyncAttempts,
    );
  }

  final CitizenChainAssets _assets;
  final BootstrapClient? _bootstrapClient;
  final ChainDatabaseStore? _databaseStore;
  final CitizenSdkLogger _logger;
  final int _maxLogLevel;

  final Future<void> Function()? _initializeOverride;
  final Future<void> Function()? _disposeOverride;
  final Future<LightClientStatusSnapshot> Function()? _cacheStatusOverride;
  final Future<String> Function()? _databaseExportOverride;
  final Future<void> Function(Duration timeout)? _synchronizeOverride;
  final Future<LightClientStatusSnapshot> Function()? _syncStatusOverride;
  final Stream<Object?> Function(String method, List<Object?> params)?
  _subscribeOverride;
  final Future<Object?> Function(String method, List<Object?> params)?
  _requestOverride;
  final String? _expectedGenesisHashOverride;
  final Duration _databaseCacheRefreshInterval;
  final Duration _retrySyncDelay;
  final int _retrySyncAttempts;

  SmoldotClient? _client;
  Chain? _chain;
  bool _initialized = false;
  Future<void>? _initFuture;
  int? _initGeneration;
  Future<void>? _disposeFuture;

  /// 每次开始销毁时递增。先前生命周期中的异步初始化不得提交到新状态。
  int _lifecycleGeneration = 0;
  bool _synced = false;
  Future<void>? _syncFuture;
  Future<void>? _retrySyncFuture;

  /// 当前本地链资产推导出的 genesis hash；只用于验证本机同步缓存归属。
  String? _expectedGenesisHash;

  /// 所有 database 导出和持久化写入共用同一队尾。
  ///
  /// 中文注释：队尾跨 lifecycle 保留，先前任务完成后先检查代际再退出，
  /// 新任务最多等待一个已经在执行的导出，不会与先前任务并发覆盖同一个
  /// 缓存键。
  static Future<void> _databaseCacheWriteTail = Future<void>.value();
  Timer? _databaseCacheRefreshTimer;
  Future<void>? _databaseCacheRefreshFuture;
  int? _lastPersistedFinalizedBlockNumber;

  final StreamController<ChainHealthSnapshot> _healthController =
      StreamController<ChainHealthSnapshot>.broadcast(sync: true);
  ChainHealthSnapshot _health = const ChainHealthSnapshot.uninitialized();

  /// 当前链健康状态。
  ChainHealthStatus _healthStatus = ChainHealthStatus.uninitialized;
  ChainHealthStatus get healthStatus => _healthStatus;
  ChainHealthSnapshot get health => _health;
  Stream<ChainHealthSnapshot> get healthChanges => _healthController.stream;
  String? get genesisHash => _expectedGenesisHash;

  /// 最近一次链操作错误信息（仅 degraded 时有值）。
  String? _lastError;
  String? get lastError => _lastError;

  BootstrapManifest? _lastBootstrapManifest;
  BootstrapManifest? get lastBootstrapManifest => _lastBootstrapManifest;

  String? _lastBootstrapError;
  String? get lastBootstrapError => _lastBootstrapError;

  static const _readMaxRetries = 4;
  static const _readRetryDelay = Duration(seconds: 2);
  static const _defaultSyncTimeout = Duration(minutes: 3);

  /// 通用读操作包装：瞬断重试 + 健康状态更新。
  ///
  /// 所有链上读操作（余额、nonce、metadata、storage 等）统一走此方法，
  /// 避免每个调用点各自重复重试逻辑。
  Future<T> _withRetry<T>(
    String debugLabel,
    Future<T> Function() action,
  ) async {
    for (var attempt = 1; attempt <= _readMaxRetries; attempt++) {
      try {
        final result = await action();
        // 基础 RPC 恢复只证明链连接可读；失败路径已经撤销 `_synced`，此时
        // 必须回到 syncing，不能发布 status=operational/isUsable=false 的矛盾快照。
        // 只有仍持有完整同步事实时才可恢复 operational。
        if (_healthStatus == ChainHealthStatus.degraded) {
          _lastError = null;
          _setHealthStatus(
            _synced ? ChainHealthStatus.operational : ChainHealthStatus.syncing,
          );
          _debug(
            _synced ? '[Smoldot] 链操作恢复正常' : '[Smoldot] 基础链读取恢复，等待重新完成同步门禁',
          );
        }
        return result;
      } catch (e) {
        final msg = e.toString().toLowerCase();

        // 轻节点固有的"老区块体不可得"是预期边界情况，
        // 不属于"瞬断"也不应降级健康状态；上层钱包流水已改为读
        // 区块事件，不再逐块拉加入前区块 body 搜索交易。
        final isLightClientBlockMiss = msg.contains(
          'failed to download block body',
        );
        if (isLightClientBlockMiss) {
          rethrow;
        }

        final isTransient =
            msg.contains('timeout') ||
            msg.contains('proof') ||
            msg.contains('channel closed') ||
            msg.contains('no node') ||
            msg.contains('peers') ||
            msg.contains('inaccessible');
        if (!isTransient || attempt == _readMaxRetries) {
          _synced = false;
          _syncFuture = null;
          _lastError = '$debugLabel 失败: $e';
          _setHealthStatus(ChainHealthStatus.degraded);
          _debug('[Smoldot] $_lastError (attempt $attempt/$_readMaxRetries)');
          rethrow;
        }
        _debug(
          '[Smoldot] $debugLabel 瞬断，${_readRetryDelay.inSeconds}s 后重试 '
          '($attempt/$_readMaxRetries): $e',
        );
        await Future<void>.delayed(_readRetryDelay);
      }
    }
    // 不应到达
    throw StateError('$debugLabel 重试次数已用尽');
  }

  /// 轻节点是否已初始化并加入链。
  bool get isReady => _initialized && _chain != null;

  /// 打印当前轻节点诊断信息到 debugPrint，用于排查连接/同步/读取问题。
  Future<void> printDiagnostics() async {
    await ensureStarted();
    _debug('╔══════ Smoldot 诊断 ══════');
    _debug('║ initialized: $_initialized');
    _debug('║ chain: ${_chain != null ? "已加入" : "null"}');
    _debug('║ synced: $_synced');
    _debug('║ healthStatus: $_healthStatus');
    _debug('║ lastError: $_lastError');
    if (_chain != null) {
      try {
        final snapshot = await getStatusSnapshotRaw();
        _debug('║ peerCount: ${snapshot.peerCount}');
        _debug('║ isSyncing: ${snapshot.isSyncing}');
        _debug(
          '║ bestBlock: #${snapshot.bestBlockNumber} ${snapshot.bestBlockHash}',
        );
        _debug(
          '║ surfaceFinalized: #${snapshot.finalizedBlockNumber} ${snapshot.finalizedBlockHash}',
        );
        _debug(
          '║ verifiedFinalized: '
          '#${snapshot.currentVerifiedFinalizedBlockNumber} '
          '${snapshot.currentVerifiedFinalizedBlockHash}',
        );
      } catch (e) {
        _debug('║ getStatusSnapshot 失败: $e');
      }
      try {
        final nonce = await _chain!.getAccountNextIndex(
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        );
        _debug('║ accountNextIndex(zero): $nonce');
      } catch (e) {
        _debug('║ accountNextIndex 失败: $e');
      }
    }
    _debug('╚══════════════════════════');
  }

  static const _dbExportStableAttempts = 2;

  /// 将内部诊断状态转换为用户可理解的链路错误提示。
  ///
  /// 原始错误细节仍保留在日志与 [lastError] 中，UI 层只展示统一文案，
  /// 避免把底层 FFI / JSON-RPC 细节直接暴露给最终用户。
  String buildUserFacingError([Object? error]) {
    final raw = '${error ?? ''} ${_lastError ?? ''}'.toLowerCase();
    if (!_initialized ||
        raw.contains('未初始化') ||
        raw.contains('failed to initialize smoldot client') ||
        raw.contains('failed to add chain')) {
      return '轻节点初始化失败，请检查网络后重试';
    }
    if (_healthStatus == ChainHealthStatus.offline ||
        raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused')) {
      return '设备网络不可用，请检查网络后重试';
    }
    if ((_healthStatus == ChainHealthStatus.degraded &&
            (raw.contains('waituntilsynced') ||
                raw.contains('timeout') ||
                raw.contains('timed out') ||
                raw.contains('同步失败'))) ||
        raw.contains('轻节点同步失败')) {
      return '轻节点同步超时，请检查网络后重试';
    }
    if (_healthStatus == ChainHealthStatus.syncing ||
        raw.contains('waituntilsynced') ||
        raw.contains('timeout') ||
        raw.contains('timed out')) {
      return '轻节点正在同步链状态，请稍后再试';
    }
    if (_healthStatus == ChainHealthStatus.degraded ||
        raw.contains('proof') ||
        raw.contains('channel closed') ||
        raw.contains('peers') ||
        raw.contains('inaccessible')) {
      return '区块链暂不可用，请检查网络连接后重试';
    }
    return '区块链读取失败，请稍后再试';
  }

  /// 初始化 smoldot 轻客户端并加入 citizenchain。
  ///
  /// 从 assets/chainspec.json 加载链规格文件。
  /// 如果上次运行有缓存的同步数据库，会通过 `databaseContent` 恢复，
  /// 大幅缩短区块头同步时间。
  /// 如果已初始化或已有初始化正在执行，则复用同一个 Future。
  Future<void> initialize() => ensureStarted();

  /// 轻节点唯一启动闸口：成功幂等、进行中合并、失败后允许重试。
  Future<void> ensureStarted() {
    final generation = _lifecycleGeneration;
    final current = _initFuture;
    if (current != null && _initGeneration == generation) return current;

    final pendingDispose = _disposeFuture;
    if (pendingDispose == null && _initialized) return Future<void>.value();

    // 捕获调用时已存在的销毁任务，避免 start/dispose 互相等待形成环。
    late final Future<void> task;
    task = _startAfterDispose(pendingDispose).whenComplete(() {
      if (identical(_initFuture, task)) {
        _initFuture = null;
        _initGeneration = null;
      }
    });
    _initFuture = task;
    _initGeneration = generation;
    return task;
  }

  Future<void> _startAfterDispose(Future<void>? pendingDispose) async {
    if (pendingDispose != null) {
      await pendingDispose;
    }
    if (_initialized) return;

    final generation = _lifecycleGeneration;
    final initializeOverride = _initializeOverride;
    if (initializeOverride != null) {
      await initializeOverride();
      _ensureLifecycleCurrent(generation);
      _initialized = true;
      _setHealthStatus(ChainHealthStatus.syncing);
      return;
    }
    await _doInitialize(generation);
  }

  Future<void> _doInitialize(int generation) async {
    _ensureLifecycleCurrent(generation);

    _lastError = null;
    _lastBootstrapError = null;
    _setHealthStatus(ChainHealthStatus.syncing);

    try {
      final bootstrap = await _fetchBootstrapManifest();
      _ensureLifecycleCurrent(generation);

      // 1. 创建 smoldot 客户端
      _client = SmoldotClient(config: SmoldotConfig(maxLogLevel: _maxLogLevel));
      await _client!.initialize();
      _ensureLifecycleCurrent(generation);

      // 2. 通过 SDK 资产适配器加载 chainspec，并注入安装包固定的 #0 信任锚。
      // 远端清单只可补充与本地链参数匹配的 bootnode，不能替代随包锚点。
      final bundle = await _assets.load(bootstrap: bootstrap);
      final chainSpec = bundle.chainSpec;
      _expectedGenesisHash = bundle.genesisHash;
      _ensureLifecycleCurrent(generation);

      // 3. 优先恢复上次导出的 finalized database，避免每次冷启动都从零同步
      final cachedEnvelope = await _loadCachedDatabaseEnvelope(
        expectedGenesisHash: bundle.genesisHash,
      );
      _ensureLifecycleCurrent(generation);
      if (cachedEnvelope != null) {
        try {
          _chain = await _addChain(
            chainSpec,
            databaseContent: cachedEnvelope.databaseContent,
          );
          _ensureLifecycleCurrent(generation);
          await _verifyRestoredDatabaseCache(
            cachedEnvelope,
            _chain!,
            generation,
          );
          _ensureLifecycleCurrent(generation);
          _debug(
            '[Smoldot] 已从同步缓存恢复轻节点 '
            '(${cachedEnvelope.databaseContent.length} bytes)',
          );
        } catch (e) {
          _ensureLifecycleCurrent(generation);
          // 缓存无法用于当前链状态时，清掉缓存并回退到无缓存重连，
          // 避免一次坏缓存把后续所有启动都卡死。
          _debug('[Smoldot] 同步缓存失效，清理后重试: $e');
          final rejectedChain = _chain;
          _chain = null;
          try {
            await rejectedChain?.dispose();
          } catch (disposeError) {
            _debug('[Smoldot] 释放失效缓存链实例失败: $disposeError');
          }
          await _clearCachedDatabase();
          _ensureLifecycleCurrent(generation);
          _chain = await _addChainFromBundledCheckpoint(
            chainSpec,
            expectedGenesisHash: bundle.genesisHash,
            lifecycleGeneration: generation,
          );
          _ensureLifecycleCurrent(generation);
        }
      } else {
        _chain = await _addChainFromBundledCheckpoint(
          chainSpec,
          expectedGenesisHash: bundle.genesisHash,
          lifecycleGeneration: generation,
        );
        _ensureLifecycleCurrent(generation);
      }

      _initialized = true;
      _synced = false;
      _syncFuture = null;
      _setHealthStatus(ChainHealthStatus.syncing);
      _debug('[Smoldot] 轻节点已启动，正在验证或同步链状态...');

      // 主动链入口加入网络后立刻预热同步，后续读链复用同一个 Future。
      unawaited(
        ensureSynced(timeout: _defaultSyncTimeout).catchError((Object e) {
          _debug('[Smoldot] 后台同步失败: $e');
        }),
      );
    } catch (e) {
      final lifecycleInvalidated = e is _SmoldotLifecycleInvalidated;
      if (!lifecycleInvalidated) {
        _lastError = '轻节点初始化失败: $e';
        _setHealthStatus(
          _looksOffline(e)
              ? ChainHealthStatus.offline
              : ChainHealthStatus.degraded,
        );
        _debug('[Smoldot] $_lastError');
      }
      await _releaseNativeResources();
      _initialized = false;
      _synced = false;
      _syncFuture = null;
      _expectedGenesisHash = null;
      rethrow;
    }
  }

  void _ensureLifecycleCurrent(int generation) {
    if (generation != _lifecycleGeneration) {
      throw const _SmoldotLifecycleInvalidated();
    }
  }

  @visibleForTesting
  bool get initializedForTesting => _initialized;

  /// 只供生命周期合同测试驱动与生产读取相同的重试/健康状态机。
  @visibleForTesting
  Future<T> readWithRetryForTesting<T>(
    String debugLabel,
    Future<T> Function() action,
  ) => _withRetry(debugLabel, action);

  /// 缓存单调性测试专用：按当前生命周期进入与生产一致的串行保存
  /// 路径。
  @visibleForTesting
  Future<void> saveDatabaseCacheForTesting() =>
      _saveDatabaseCache(lifecycleGeneration: _lifecycleGeneration);

  /// finalized 推进刷新测试入口；生产由单实例低频定时器调用同一路径。
  @visibleForTesting
  Future<void> refreshDatabaseCacheIfAdvancedForTesting() =>
      _refreshDatabaseCacheIfAdvanced(
        lifecycleGeneration: _lifecycleGeneration,
      );

  /// 缓存格式测试专用：返回通过严格信封校验后的 database 正文。
  @visibleForTesting
  Future<String?> loadCachedDatabaseForTesting(String expectedGenesisHash) =>
      _loadCachedDatabaseEnvelope(
        expectedGenesisHash: expectedGenesisHash,
      ).then((envelope) => envelope?.databaseContent);

  /// 缓存恢复测试专用：判断异步恢复是否已经到达信封声明的 finalized。
  @visibleForTesting
  static bool restoredDatabaseCacheReachedForTesting({
    required String rawEnvelope,
    required String expectedGenesisHash,
    required LightClientStatusSnapshot snapshot,
  }) {
    final envelope = ChainDatabaseEnvelope.parse(
      rawEnvelope,
      expectedGenesisHash: expectedGenesisHash,
    );
    return _restoredDatabaseCacheReached(envelope, snapshot);
  }

  /// 无有效本机 database 时，验证真实启动锚点必须是安装包固定 #0。
  @visibleForTesting
  static bool bundledCheckpointStartMatchesForTesting({
    required String expectedGenesisHash,
    required LightClientStatusSnapshot snapshot,
  }) => _bundledCheckpointStartMatches(expectedGenesisHash, snapshot);

  Future<BootstrapManifest?> _fetchBootstrapManifest() async {
    final api = _bootstrapClient;
    if (api == null) return null;
    try {
      final manifest = await api.fetch();
      _lastBootstrapManifest = manifest;
      _lastBootstrapError = null;
      _debug('[Smoldot] 已读取链启动清单: bootnodes=${manifest.p2p.bootnodes.length}');
      return manifest;
    } catch (e) {
      _lastBootstrapManifest = null;
      _lastBootstrapError = '链启动清单不可用，继续使用本地链规格: $e';
      _debug('[Smoldot] $_lastBootstrapError');
      return null;
    }
  }

  Future<Chain> _addChain(String chainSpec, {String? databaseContent}) {
    return _client!.addChain(
      AddChainConfig(chainSpec: chainSpec, databaseContent: databaseContent),
    );
  }

  /// 无有效本机 database 时唯一允许的启动路径。
  ///
  /// addChain 成功不代表 smoldot 真实采用了安装包锚点；必须读取第一份
  /// 原生快照，精确核对来源、高度和 hash。核对失败时立即释放 chain，
  /// 禁止带着未知 H 继续联网。
  Future<Chain> _addChainFromBundledCheckpoint(
    String chainSpec, {
    required String expectedGenesisHash,
    required int lifecycleGeneration,
  }) async {
    final chain = await _addChain(chainSpec);
    try {
      _ensureLifecycleCurrent(lifecycleGeneration);
      final snapshot = await chain.getStatusSnapshot();
      _ensureLifecycleCurrent(lifecycleGeneration);
      if (!_bundledCheckpointStartMatches(expectedGenesisHash, snapshot)) {
        throw FormatException(
          '轻节点没有采用安装包固定创世锚点: '
          '来源 ${snapshot.startupFinalizedSource?.wireValue}, '
          '启动 #${snapshot.startupFinalizedBlockNumber} '
          '${snapshot.startupFinalizedBlockHash}',
        );
      }
      return chain;
    } catch (_) {
      try {
        await chain.dispose();
      } catch (disposeError) {
        _debug('[Smoldot] 释放错误启动锚点链实例失败: $disposeError');
      }
      rethrow;
    }
  }

  static bool _bundledCheckpointStartMatches(
    String expectedGenesisHash,
    LightClientStatusSnapshot snapshot,
  ) {
    return snapshot.startupFinalizedSource ==
            LightClientStartupFinalizedSource.bundledCheckpoint &&
        snapshot.startupFinalizedBlockNumber == 0 &&
        snapshot.startupFinalizedBlockHash?.toLowerCase() ==
            expectedGenesisHash.toLowerCase();
  }

  /// 固定 `#0` checkpoint 的 genesis hash 推导测试入口。
  @visibleForTesting
  static String genesisHashFromCheckpointForTesting(String headerHex) =>
      CitizenChainAssets.genesisHashFromCheckpoint(headerHex);

  /// 从宿主注入的公开数据库存储加载并严格验证缓存信封。
  ///
  /// 无信封 database、损坏 JSON、未知 schema 和跨链缓存一律删除；只接受
  /// 当前严格信封，避免无法证明链身份的数据进入 addChain。
  Future<ChainDatabaseEnvelope?> _loadCachedDatabaseEnvelope({
    required String expectedGenesisHash,
  }) async {
    final store = _databaseStore;
    if (store == null) return null;
    try {
      final raw = await store.read();
      if (raw == null) {
        _lastPersistedFinalizedBlockNumber = null;
        return null;
      }
      try {
        final envelope = ChainDatabaseEnvelope.parse(
          raw,
          expectedGenesisHash: expectedGenesisHash,
        );
        _debug(
          '[Smoldot] 已验证同步缓存信封 '
          '(finalized #${envelope.finalizedBlockNumber})',
        );
        _lastPersistedFinalizedBlockNumber = envelope.finalizedBlockNumber;
        return envelope;
      } catch (e) {
        await store.delete();
        _lastPersistedFinalizedBlockNumber = null;
        _debug('[Smoldot] 同步缓存信封无效，已清理: $e');
        return null;
      }
    } catch (e) {
      _debug('[Smoldot] 加载同步缓存失败: $e');
      return null;
    }
  }

  /// 验证 smoldot 是否真实采用 database chain information 作为启动 anchor。
  ///
  /// 不能再用网络实时 finalized 已经追到信封高度冒充“缓存恢复成功”；
  /// 启动来源、高度和 hash 必须与信封完全一致，否则立即释放该 chain、
  /// 删除缓存并回退 #0。
  Future<void> _verifyRestoredDatabaseCache(
    ChainDatabaseEnvelope envelope,
    Chain chain,
    int lifecycleGeneration,
  ) async {
    _ensureLifecycleCurrent(lifecycleGeneration);
    final snapshot = await chain.getStatusSnapshot();
    if (_restoredDatabaseCacheReached(envelope, snapshot)) return;
    throw FormatException(
      '同步缓存信封与真实恢复锚点不一致: '
      '声明 #${envelope.finalizedBlockNumber} ${envelope.finalizedBlockHash}, '
      '启动来源 ${snapshot.startupFinalizedSource?.wireValue}, '
      '启动 #${snapshot.startupFinalizedBlockNumber} '
      '${snapshot.startupFinalizedBlockHash}',
    );
  }

  static bool _restoredDatabaseCacheReached(
    ChainDatabaseEnvelope envelope,
    LightClientStatusSnapshot snapshot,
  ) {
    return snapshot.startupFinalizedSource ==
            LightClientStartupFinalizedSource.localDatabase &&
        snapshot.startupFinalizedBlockNumber == envelope.finalizedBlockNumber &&
        snapshot.startupFinalizedBlockHash?.toLowerCase() ==
            envelope.finalizedBlockHash &&
        snapshot.currentVerifiedFinalizedBlockNumber >=
            envelope.finalizedBlockNumber;
  }

  Future<void> _clearCachedDatabase() async {
    final store = _databaseStore;
    if (store == null) return;
    try {
      await store.delete();
      _lastPersistedFinalizedBlockNumber = null;
      _debug('[Smoldot] 已清除失效同步缓存');
    } catch (e) {
      _debug('[Smoldot] 清除同步缓存失败: $e');
    }
  }

  /// 将一次 database 导出排入全局串行队列。
  ///
  /// 所有调用点都可以继续 `unawaited` 触发；这里保证实际导出和落盘
  /// 不会并发。
  /// 单个任务失败只记录日志，不得让队尾进入永久失败状态。
  Future<void> _saveDatabaseCache({required int lifecycleGeneration}) {
    final previous = _databaseCacheWriteTail;
    late final Future<void> task;
    task = previous.catchError((Object _) {}).then((_) async {
      try {
        await _saveDatabaseCacheSerial(lifecycleGeneration);
      } catch (e) {
        _debug('[Smoldot] 保存同步缓存失败: $e');
      }
    });
    _databaseCacheWriteTail = task;
    return task;
  }

  Future<void> _saveDatabaseCacheSerial(int lifecycleGeneration) async {
    final chain = _chain;
    final hasTestingSource =
        _cacheStatusOverride != null && _databaseExportOverride != null;
    if (!hasTestingSource && (!isReady || chain == null)) return;
    if (!_isCacheSourceCurrent(lifecycleGeneration, chain)) return;

    final expectedGenesisHash =
        _expectedGenesisHashOverride ?? _expectedGenesisHash;
    if (expectedGenesisHash == null) {
      _debug('[Smoldot] 缺少本地 genesis hash，跳过同步缓存导出');
      return;
    }

    final candidate = await _captureStableDatabaseCache(
      lifecycleGeneration: lifecycleGeneration,
      chain: chain,
      expectedGenesisHash: expectedGenesisHash,
    );
    if (candidate == null ||
        !_isCacheSourceCurrent(lifecycleGeneration, chain)) {
      return;
    }
    await _persistDatabaseCacheCandidate(candidate);
  }

  /// 在同一个完整验证 finalized 锚点前后夹住 database 导出。
  ///
  /// smoldot 导出期间仍可能推进 currentVerifiedFinalized；前后高度或哈希
  /// 变化时，无法证明正文与信封锚点一致，本次结果必须丢弃并有限
  /// 重试，
  /// 不能给较新正文贴过期高度标签。
  Future<ChainDatabaseEnvelope?> _captureStableDatabaseCache({
    required int lifecycleGeneration,
    required Chain? chain,
    required String expectedGenesisHash,
  }) async {
    for (var attempt = 1; attempt <= _dbExportStableAttempts; attempt++) {
      if (!_isCacheSourceCurrent(lifecycleGeneration, chain)) return null;
      final before = await _readDatabaseCacheStatus(chain);
      if (!_isCacheSourceCurrent(lifecycleGeneration, chain)) return null;
      if (!before.isUsable) {
        _debug(
          '[Smoldot] 链状态尚未 regular/可用，跳过同步缓存导出 '
          '(phase=${before.syncPhase.wireValue}, syncing=${before.isSyncing})',
        );
        return null;
      }

      final databaseContent = await _exportFinalizedDatabase(chain);
      if (!_isCacheSourceCurrent(lifecycleGeneration, chain)) return null;
      if (databaseContent.isEmpty) return null;

      final after = await _readDatabaseCacheStatus(chain);
      if (!_isCacheSourceCurrent(lifecycleGeneration, chain)) return null;
      if (!after.isUsable) {
        _debug('[Smoldot] 导出后链状态不再可用，本轮同步缓存不落盘');
        return null;
      }

      final beforeNumber = before.currentVerifiedFinalizedBlockNumber;
      final beforeHash = before.currentVerifiedFinalizedBlockHash.toLowerCase();
      final afterNumber = after.currentVerifiedFinalizedBlockNumber;
      final afterHash = after.currentVerifiedFinalizedBlockHash.toLowerCase();
      if (beforeNumber == afterNumber && beforeHash == afterHash) {
        return ChainDatabaseEnvelope(
          genesisHash: expectedGenesisHash,
          finalizedBlockNumber: afterNumber,
          finalizedBlockHash: afterHash,
          databaseContent: databaseContent,
        )..validate();
      }
      _debug(
        '[Smoldot] 导出期间 finalized 已推进 '
        '(#$beforeNumber → #$afterNumber)，重试 $attempt/$_dbExportStableAttempts',
      );
    }
    _debug('[Smoldot] finalized 持续推进，本轮同步缓存不落盘');
    return null;
  }

  Future<LightClientStatusSnapshot> _readDatabaseCacheStatus(
    Chain? chain,
  ) async {
    final override = _cacheStatusOverride;
    if (override != null) return override();
    return chain!.getStatusSnapshot();
  }

  Future<String> _exportFinalizedDatabase(Chain? chain) async {
    final override = _databaseExportOverride;
    if (override != null) return override();
    final result = await chain!.request(
      'chainHead_unstable_finalizedDatabase',
      <Object?>[ChainDatabaseEnvelope.maxDatabaseBytes],
    );
    if (result.isError || result.result is! String) {
      throw StateError('导出同步数据库失败: ${result.error}');
    }
    return result.result as String;
  }

  bool _isCacheSourceCurrent(int lifecycleGeneration, Chain? chain) {
    if (lifecycleGeneration != _lifecycleGeneration) return false;
    if (_cacheStatusOverride != null && _databaseExportOverride != null) {
      return _initialized;
    }
    return isReady && identical(_chain, chain);
  }

  void _startDatabaseCacheRefresh(int lifecycleGeneration) {
    _databaseCacheRefreshTimer?.cancel();
    _databaseCacheRefreshTimer = Timer.periodic(
      _databaseCacheRefreshInterval,
      (_) => unawaited(_runDatabaseCacheRefresh(lifecycleGeneration)),
    );
  }

  Future<void> _runDatabaseCacheRefresh(int lifecycleGeneration) {
    final current = _databaseCacheRefreshFuture;
    if (current != null) return current;

    late final Future<void> task;
    task =
        () async {
          try {
            await _refreshDatabaseCacheIfAdvanced(
              lifecycleGeneration: lifecycleGeneration,
            );
          } catch (e) {
            // 定时刷新只维护下次冷启动进度；瞬时读链失败不得污染
            // 业务链状态，
            // 下一周期继续复用同一门禁重试即可。
            _debug('[Smoldot] 刷新同步缓存失败，等待下次重试: $e');
          }
        }().whenComplete(() {
          if (identical(_databaseCacheRefreshFuture, task)) {
            _databaseCacheRefreshFuture = null;
          }
        });
    _databaseCacheRefreshFuture = task;
    return task;
  }

  /// 只在 currentVerifiedFinalized 严格推进且原生状态可用时触发昂贵导出。
  Future<void> _refreshDatabaseCacheIfAdvanced({
    required int lifecycleGeneration,
  }) async {
    final chain = _chain;
    final hasTestingSource = _cacheStatusOverride != null;
    if (!hasTestingSource && (!isReady || chain == null)) return;
    if (!_isCacheSourceCurrent(lifecycleGeneration, chain)) return;

    final snapshot = await _readDatabaseCacheStatus(chain);
    if (!_isCacheSourceCurrent(lifecycleGeneration, chain) ||
        !snapshot.isUsable) {
      return;
    }
    final finalized = snapshot.currentVerifiedFinalizedBlockNumber;
    if (finalized <= (_lastPersistedFinalizedBlockNumber ?? -1)) {
      return;
    }
    await _saveDatabaseCache(lifecycleGeneration: lifecycleGeneration);
  }

  /// 只允许同一 genesis 的更高 finalized 覆盖现有缓存。
  Future<void> _persistDatabaseCacheCandidate(
    ChainDatabaseEnvelope candidate,
  ) async {
    final store = _databaseStore;
    if (store == null) return;
    final persistedRaw = await store.read();
    if (persistedRaw != null) {
      try {
        final persisted = ChainDatabaseEnvelope.parse(
          persistedRaw,
          expectedGenesisHash: candidate.genesisHash,
        );
        _lastPersistedFinalizedBlockNumber = persisted.finalizedBlockNumber;
        if (candidate.finalizedBlockNumber < persisted.finalizedBlockNumber) {
          _debug(
            '[Smoldot] 丢弃倒退同步缓存 '
            '(#${candidate.finalizedBlockNumber} < #${persisted.finalizedBlockNumber})',
          );
          return;
        }
        if (candidate.finalizedBlockNumber == persisted.finalizedBlockNumber) {
          if (candidate.finalizedBlockHash == persisted.finalizedBlockHash) {
            return;
          }
          // 同 genesis、同 finalized 高度不应出现不同哈希。先前值已无法信任，
          // 先删除，再写入当前轻节点刚验证并稳定导出的候选。
          await store.delete();
          _debug('[Smoldot] 同步缓存 finalized hash 冲突，已清除先前值');
        }
      } catch (e) {
        await store.delete();
        _lastPersistedFinalizedBlockNumber = null;
        _debug('[Smoldot] 已清除无法验证的先前同步缓存: $e');
      }
    }

    final encoded = candidate.encode();
    await store.write(encoded);
    if (await store.read() != encoded) {
      throw StateError('同步缓存写入后回读不一致');
    }
    _lastPersistedFinalizedBlockNumber = candidate.finalizedBlockNumber;
    _debug(
      '[Smoldot] 同步缓存已保存 '
      '(finalized #${candidate.finalizedBlockNumber}, '
      '${utf8.encode(candidate.databaseContent).length} bytes)',
    );
  }

  static const _peerWaitInterval = Duration(milliseconds: 500);
  static const _peerWaitMaxAttempts = 12; // 最多等 6 秒

  /// 发送 JSON-RPC 请求，返回 result 字段。
  ///
  /// 如果当前 peers=0，先等待 peer 重连后再发请求（最多 6 秒），
  /// 避免在短暂断连期间直接报错。
  Future<Object?> request(
    String method, [
    List<Object?> params = const <Object?>[],
  ]) async {
    // 仅 `forTesting` 可注入；生产构造器没有该入口，始终走下方真实轻节点门禁。
    final requestOverride = _requestOverride;
    if (requestOverride != null) return requestOverride(method, params);
    await ensureSynced();
    _ensureReady();

    // 等待至少有 1 个 peer 连接
    await _waitForPeer();

    return _withRetry(method, () async {
      final response = await _chain!.request(method, params);
      if (response.isError) {
        throw Exception('smoldot RPC 请求失败: $method, error=${response.error}');
      }
      return response.result;
    });
  }

  /// 按 finalized 块哈希钉死的 `state_getKeysPaged` 反向索引扫描入口。
  ///
  /// (ADR-017 全端 finalized 单一口径)：
  /// - keysPaged 未携带 hash 参数时，smoldot 在请求入队那一刻钉死
  ///   current_best_block——轻节点启动后追块窗口内这是先前区块，会返回
  ///   先前状态的空列表且不报任何错误，禁止裸调；
  /// - 链端投票规则放开(出块即固化)后 finalized 与 best 仅差秒级，业务读取
  ///   一律钉 finalized，与余额/提案/事件同口径；
  /// - 快照必须在 ensureSynced 之后取，否则追块窗口内拿到过期哈希；
  /// - 哈希缺失直接抛错，绝不用假空列表冒充"暂无数据"。
  Future<List<String>> getKeysPagedFinalized(
    String prefixHex, {
    int count = 1000,
    String? startKey,
  }) async {
    await ensureSynced();
    _ensureReady();
    final snapshot = await getStatusSnapshotRaw();
    final finalizedHash = snapshot.currentVerifiedFinalizedBlockHash;
    if (finalizedHash.isEmpty) {
      throw Exception('轻节点未提供 finalized 块哈希，无法执行索引扫描');
    }
    final raw =
        await request('state_getKeysPaged', [
              prefixHex,
              count,
              startKey,
              finalizedHash,
            ])
            as List<dynamic>?;
    if (raw == null) return const [];
    return raw.whereType<String>().toList(growable: false);
  }

  /// 等待至少有 1 个 peer 连接。如果当前 peers=0，轮询等待。
  Future<void> _waitForPeer() async {
    for (var i = 0; i < _peerWaitMaxAttempts; i++) {
      final peers = await getPeerCount();
      if (peers > 0) return;
      if (i == 0) {
        _debug('[Smoldot] peers=0，等待 P2P 重连...');
      }
      await Future<void>.delayed(_peerWaitInterval);
    }
    // 超时后仍然发请求（让 smoldot 返回具体错误，由上层重试处理）
  }

  /// 创建轻节点订阅，返回事件流。
  ///
  /// 当前用于接收 `chain_subscribeNewHeads` 等链事件。
  Stream<Object?> subscribe(
    String method, [
    List<Object?> params = const <Object?>[],
  ]) async* {
    // 订阅驱动后续业务状态，必须从已追上 finalized 的生命周期开始。
    await ensureSynced();
    _ensureReady();
    final override = _subscribeOverride;
    if (override != null) {
      yield* override(method, params);
      return;
    }
    yield* _chain!.subscribe(method, params).map<Object?>((response) {
      if (response.isError) {
        throw StateError('$method 订阅失败：${response.error}');
      }
      return response.result;
    });
  }

  /// 等待轻节点同步到最新区块。
  Future<void> waitUntilSynced({Duration timeout = _defaultSyncTimeout}) async {
    await ensureSynced(timeout: timeout);
  }

  /// 在首次链上读写前等待轻节点同步完成，避免把未同步状态误判为
  /// 链上空数据。
  ///
  /// 如果后台重试已在运行，改为短等 30 秒检查一次是否
  /// 已追上，避免每次读操作都重新发起 3 分钟的阻塞等待。
  Future<void> ensureSynced({Duration timeout = _defaultSyncTimeout}) async {
    await ensureStarted();
    _ensureReady();
    final generation = _lifecycleGeneration;

    // `_synced` 只代表上一次检查已经完成，不能永久缓存为链真相。
    // 运行期间 peer 的 F 继续推进时，原生会重新进入 warp；每次业务入口
    // 都必须重新确认唯一 isUsable。
    if (_synced) {
      final snapshot = await _readSyncStatus();
      _ensureLifecycleCurrent(generation);
      if (snapshot.isUsable) return;
      _synced = false;
      _databaseCacheRefreshTimer?.cancel();
      _databaseCacheRefreshTimer = null;
      _lastError = null;
      _setHealthStatus(ChainHealthStatus.syncing);
      _debug(
        '[Smoldot] peer finalized 已推进，重新等待完整验证: '
        'phase=${snapshot.syncPhase.wireValue}, '
        'H=#${snapshot.currentVerifiedFinalizedBlockNumber}, '
        'F=#${snapshot.highestPeerFinalizedBlockNumber}',
      );
    }

    // 后台重试正在运行时，短等即可——后台会设置 _synced=true
    if (_retrySyncFuture != null) {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        _ensureLifecycleCurrent(generation);
        // 后台只写入候选状态；回到统一入口再向原生确认，禁止绕过
        // 非黏性门禁。
        if (_synced) return ensureSynced(timeout: timeout);
      }
      throw Exception('轻节点同步中，请稍后再试');
    }

    final current = _syncFuture;
    if (current != null) {
      await current;
      return;
    }

    final future = _waitForSync(timeout, generation);
    _syncFuture = future;
    try {
      await future;
    } finally {
      // 完成态 Future 不能跨下一次原生状态检查继续占用槽位：peer 的 F
      // 推进后 `_synced` 会失效，此时必须创建新的同步任务，不能 await
      // 上一轮已经完成的 Future 后误返回。
      if (identical(_syncFuture, future)) {
        _syncFuture = null;
      }
    }
  }

  Future<void> _waitForSync(Duration timeout, int generation) async {
    _debug('[Smoldot] 等待轻节点同步完成...');
    try {
      final synchronize = _synchronizeOverride;
      if (synchronize != null) {
        await synchronize(timeout);
      } else {
        await _chain!.waitUntilSynced(timeout: timeout);
      }
      _ensureLifecycleCurrent(generation);
      final snapshot = await _readSyncStatus();
      _ensureLifecycleCurrent(generation);
      _acceptSynchronizedSnapshot(snapshot, generation: generation);

      // 同步完成后异步保存数据库缓存，下次启动可快速恢复
      unawaited(_saveDatabaseCache(lifecycleGeneration: generation));
    } catch (e) {
      if (generation != _lifecycleGeneration) {
        rethrow;
      }
      // 同步超时不等于链不可用——smoldot 后台仍在追赶区块头。
      // 保持 syncing 并启动后台重试；warp 未完成时禁止导出或保存
      // 部分 database。
      _synced = false;
      _syncFuture = null;
      _lastError = '轻节点同步中，尚未追上最新区块: $e';
      _setHealthStatus(ChainHealthStatus.syncing);
      _debug('[Smoldot] $_lastError');
      // 后台定时重试同步检查，追上后自动恢复 operational
      unawaited(_scheduleRetrySync(generation));
      rethrow;
    }
  }

  /// 后台定时重试同步检查（生产默认 5 次、间隔 60 秒，单实例守卫）。
  ///
  /// smoldot 链实例在后台验证 warp 或同步尾部区块，此方法定期检查
  /// 是否已追上最新块。
  /// 追上后自动将状态从 syncing 切换到 operational，并保存 database 缓存。
  /// Future 身份守卫保证同一时刻只有一组重试，先前生命周期也不能
  /// 清掉新重试。
  Future<void> _scheduleRetrySync(int generation) {
    final current = _retrySyncFuture;
    if (current != null) return current;

    late final Future<void> task;
    task = _runRetrySync(generation).whenComplete(() {
      if (identical(_retrySyncFuture, task)) {
        _retrySyncFuture = null;
      }
    });
    _retrySyncFuture = task;
    return task;
  }

  Future<void> _runRetrySync(int generation) async {
    for (var i = 0; i < _retrySyncAttempts; i++) {
      await Future<void>.delayed(_retrySyncDelay);
      if (generation != _lifecycleGeneration || _synced || !_hasSyncSource) {
        return;
      }
      try {
        final synchronize = _synchronizeOverride;
        if (synchronize != null) {
          await synchronize(const Duration(seconds: 30));
        } else {
          await _chain!.waitUntilSynced(timeout: const Duration(seconds: 30));
        }
        _ensureLifecycleCurrent(generation);
        final snapshot = await _readSyncStatus();
        _ensureLifecycleCurrent(generation);
        _acceptSynchronizedSnapshot(snapshot, generation: generation);
        _syncFuture = null;
        _debug('[Smoldot] 后台重试同步成功 (第 ${i + 1} 次)');
        unawaited(_saveDatabaseCache(lifecycleGeneration: generation));
        return;
      } catch (e) {
        if (generation != _lifecycleGeneration) return;
        _debug(
          '[Smoldot] 后台重试同步未完成 '
          '(第 ${i + 1}/$_retrySyncAttempts 次): $e',
        );
      }
    }
    // 所有后台尝试都未成功时标记 degraded。
    if (!_synced && generation == _lifecycleGeneration) {
      _lastError = '轻节点长时间未能同步到最新区块';
      _setHealthStatus(ChainHealthStatus.degraded);
      _debug('[Smoldot] $_lastError');
    }
  }

  /// 同步完成的最终提交点；只接受完整可用的 regular 快照。
  void _acceptSynchronizedSnapshot(
    LightClientStatusSnapshot snapshot, {
    required int generation,
  }) {
    if (!snapshot.isUsable) {
      throw StateError(
        '轻节点完成条件不一致: '
        'phase=${snapshot.syncPhase.wireValue}, '
        'syncing=${snapshot.isSyncing}, peers=${snapshot.peerCount}',
      );
    }
    _synced = true;
    _lastError = null;
    _publishSnapshot(snapshot, status: ChainHealthStatus.operational);
    _startDatabaseCacheRefresh(generation);
    _debug(
      '[Smoldot] 链状态同步完成: '
      'phase=${snapshot.syncPhase.wireValue}, '
      'source=${snapshot.startupFinalizedSource?.wireValue}, '
      'startup=#${snapshot.startupFinalizedBlockNumber}, '
      'peer_finalized=#${snapshot.highestPeerFinalizedBlockNumber}, '
      'verified=#${snapshot.currentVerifiedFinalizedBlockNumber}, '
      'warp_target=#${snapshot.warpTargetFinalizedBlockNumber}, '
      'requests=${snapshot.warpRequestCount}, '
      'active_fragments=${snapshot.activeWarpFragmentRequestCount}, '
      'active_storage=${snapshot.activeWarpStorageRequestCount}, '
      'active_call_proof=${snapshot.activeWarpCallProofRequestCount}, '
      'received=${snapshot.warpReceivedFragmentCount}, '
      'verified=${snapshot.warpVerifiedFragmentCount}, '
      'rejected=${snapshot.warpRejectedFragmentCount}, '
      'last_failure=${snapshot.warpLastFailure?.wireValue}, '
      'best=#${snapshot.bestBlockNumber}, '
      'surface_finalized=#${snapshot.finalizedBlockNumber}',
    );
  }

  bool _looksOffline(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused');
  }

  /// 获取当前连接的 P2P 节点数。
  Future<int> getPeerCount() async {
    if (!isReady) return 0;
    return await _chain!.getPeerCount();
  }

  // ──── 基础读取（不要求完整同步，同步中即可使用） ────
  //
  // runtime version、metadata、genesis hash 等信息在 smoldot 加入链后立即可用，
  // 不需要等待区块头完整同步。这些接口只等 peer 连接，不卡
  // ensureSynced()，
  // 让业务层在同步期间就能完成初始化（编码 extrinsic、展示链信息等）。

  /// 获取轻节点状态快照（同步中也可读）。
  ///
  /// 用于展示 peer / best / finalized / syncing 等诊断信息。
  /// 这里不要先等待 peer，因为 peerCount=0 本身就是需要暴露的状态。
  Future<LightClientStatusSnapshot> getStatusSnapshotRaw() async {
    await ensureStarted();
    _ensureReady();
    final snapshot = await _withRetry(
      'getStatusSnapshotRaw',
      () => _chain!.getStatusSnapshot(),
    );
    _publishSnapshot(
      snapshot,
      status: snapshot.isUsable
          ? ChainHealthStatus.operational
          : ChainHealthStatus.syncing,
    );
    return snapshot;
  }

  /// 刷新并返回面向宿主的健康快照；读取本身不会等待完整同步。
  Future<ChainHealthSnapshot> refreshHealth() async {
    await getStatusSnapshotRaw();
    return _health;
  }

  /// 原生读取运行时版本 JSON（不要求完整同步）。
  Future<Map<String, dynamic>?> getRuntimeVersionJson() async {
    await ensureStarted();
    _ensureReady();
    await _waitForPeer();
    return _withRetry(
      'getRuntimeVersion',
      () => _chain!.getRuntimeVersionJson(),
    );
  }

  /// 原生读取 metadata hex（不要求完整同步）。
  Future<String?> getMetadataHex() async {
    await ensureStarted();
    _ensureReady();
    await _waitForPeer();
    return _withRetry('getMetadata', () => _chain!.getMetadataHex());
  }

  /// 原生读取指定块高的 block hash（不要求完整同步）。
  ///
  /// genesis hash (blockNumber=0) 永远可用；已知高度的 block hash
  /// 只要 smoldot 已同步过该高度即可返回。
  Future<String?> getBlockHash(int blockNumber) async {
    await ensureStarted();
    _ensureReady();
    await _waitForPeer();
    return _withRetry('getBlockHash', () => _chain!.getBlockHash(blockNumber));
  }

  // ──── 最新状态读取（必须完整同步后才能使用） ────
  //
  // 余额、nonce、storage、交易提交等操作依赖最新链状态，
  // 未同步完成时查询结果是过时的或直接失败。

  /// 获取轻节点状态快照（必须完整同步）。
  Future<LightClientStatusSnapshot> getStatusSnapshot() async {
    await ensureSynced();
    _ensureReady();
    await _waitForPeer();
    return _withRetry('getStatusSnapshot', () => _chain!.getStatusSnapshot());
  }

  /// 原生读取账户下一个可用 nonce（必须完整同步）。
  Future<int?> getAccountNextIndex(String accountId) async {
    await ensureSynced();
    _ensureReady();
    await _waitForPeer();
    return _withRetry(
      'getAccountNextIndex',
      () => _chain!.getAccountNextIndex(accountId),
    );
  }

  /// 为本机刚提交、已进入 inBlock 或 finalized 的单笔交易读取一次区块 extrinsics。
  ///
  /// 仅用于按 txHash 定位 extrinsic index，再核对同 index 的
  /// `System.ExtrinsicSuccess/ExtrinsicFailed`。严禁把本入口用于逐块扫描；同一块 body
  /// 的重复请求
  /// 会触发 Substrate 反滥用限制，因此这里不走 `_withRetry`。
  Future<List<String>> getFinalizedBlockExtrinsicsOnce(
    String blockHashHex,
  ) async {
    await ensureSynced();
    _ensureReady();
    await _waitForPeer();
    return _chain!.getBlockExtrinsics(blockHashHex);
  }

  /// 原生提交已编码 extrinsic（必须完整同步）。
  Future<String?> submitExtrinsicHex(String extrinsicHex) async {
    await ensureSynced();
    _ensureReady();
    await _waitForPeer();
    return _withRetry(
      'submitExtrinsic',
      () => _chain!.submitExtrinsicHex(extrinsicHex),
    );
  }

  /// 原生读取 `System.Account` 快照（必须完整同步）。
  Future<SystemAccountSnapshot?> getSystemAccountSnapshot(
    String accountId,
  ) async {
    await ensureSynced();
    _ensureReady();
    return _withRetry(
      'getSystemAccount',
      () => _chain!.getSystemAccount(accountId),
    );
  }

  /// 原生读取 finalized 块上的 `System.Account` 快照（必须完整同步）。
  Future<SystemAccountSnapshot?> getFinalizedSystemAccountSnapshot(
    String accountId,
  ) async {
    await ensureSynced();
    _ensureReady();
    // 金额展示统一走 finalized storage proof，避免 best 头余额先行变动。
    return _withRetry(
      'getFinalizedSystemAccount',
      () => _chain!.getFinalizedSystemAccount(accountId),
    );
  }

  /// 原生读取单个 storage value hex（必须完整同步）。
  Future<String?> getStorageValueHex(String storageKeyHex) async {
    await ensureSynced();
    _ensureReady();
    return _withRetry(
      'getStorageValue',
      () => _chain!.getStorageValueHex(storageKeyHex),
    );
  }

  /// 原生读取 finalized 块上的单个 storage value hex（必须完整同步）。
  Future<String?> getFinalizedStorageValueHex(String storageKeyHex) async {
    await ensureSynced();
    _ensureReady();
    return _withRetry(
      'getFinalizedStorageValue',
      () => _chain!.getFinalizedStorageValueHex(storageKeyHex),
    );
  }

  /// 原生批量读取多个 storage value hex（必须完整同步）。
  Future<Map<String, String?>> getStorageValuesHex(
    List<String> storageKeyHexList,
  ) async {
    if (storageKeyHexList.isEmpty) {
      return const {};
    }
    await ensureSynced();
    _ensureReady();
    return _withRetry(
      'getStorageValues',
      () => _chain!.getStorageValuesHex(storageKeyHexList),
    );
  }

  /// 原生批量读取 finalized 块上的多个 storage value hex（必须完整同步）。
  Future<Map<String, String?>> getFinalizedStorageValuesHex(
    List<String> storageKeyHexList,
  ) async {
    if (storageKeyHexList.isEmpty) {
      return const {};
    }
    await ensureSynced();
    _ensureReady();
    return _withRetry(
      'getFinalizedStorageValues',
      () => _chain!.getFinalizedStorageValuesHex(storageKeyHexList),
    );
  }

  /// CitizenSDK 稳定门面的运行时版本读取。
  Future<Map<String, dynamic>> runtimeVersion() async =>
      (await getRuntimeVersionJson()) ??
      (throw StateError('轻节点未返回 runtime version'));

  /// CitizenSDK 稳定门面的 metadata 读取。
  Future<String> metadataHex() async =>
      (await getMetadataHex()) ?? (throw StateError('轻节点未返回 metadata'));

  /// CitizenSDK 稳定门面的账户 nonce 读取。
  Future<int> accountNextIndex(String accountIdHex) async =>
      (await getAccountNextIndex(accountIdHex)) ??
      (throw StateError('轻节点未返回账户 nonce'));

  /// CitizenSDK 稳定门面的块哈希读取。
  Future<String> blockHash(int blockNumber) async =>
      (await getBlockHash(blockNumber)) ?? (throw StateError('轻节点未返回块哈希'));

  /// CitizenSDK 稳定门面的 finalized storage 读取。
  Future<String?> finalizedStorage(String storageKeyHex) =>
      getFinalizedStorageValueHex(storageKeyHex);

  /// CitizenSDK 稳定门面的 extrinsic 提交。
  Future<String> submitExtrinsic(String extrinsicHex) async =>
      (await submitExtrinsicHex(extrinsicHex)) ??
      (throw StateError('轻节点未返回交易哈希'));

  /// 立即进入与周期刷新相同的串行、稳定、单调缓存导出路径。
  Future<void> persistDatabase() =>
      _saveDatabaseCache(lifecycleGeneration: _lifecycleGeneration);

  /// 释放资源。App 退出或重启轻节点时必须等待完成。
  ///
  /// 销毁会使当前生命周期代际失效；调用时已经在途的初始化和缓存导出
  /// 先自行收口，随后统一释放原生 chain/client，避免先前 Future 向新的
  /// 生命周期写回状态。
  Future<void> dispose() {
    final current = _disposeFuture;
    if (current != null) return current;

    _databaseCacheRefreshTimer?.cancel();
    _databaseCacheRefreshTimer = null;
    final pendingCacheRefresh = _databaseCacheRefreshFuture;
    _lifecycleGeneration += 1;
    final pendingStart = _initFuture;
    late final Future<void> task;
    task = _disposeAfterStart(pendingStart, pendingCacheRefresh).whenComplete(
      () {
        if (identical(_disposeFuture, task)) {
          _disposeFuture = null;
        }
      },
    );
    _disposeFuture = task;
    return task;
  }

  Future<void> _disposeAfterStart(
    Future<void>? pendingStart,
    Future<void>? pendingCacheRefresh,
  ) async {
    if (pendingStart != null) {
      try {
        await pendingStart;
      } catch (_) {
        // 初始化失败或被本次代际切换取消，仍继续收口已经分配的
        // 原生资源。
      }
    }

    if (pendingCacheRefresh != null) {
      try {
        await pendingCacheRefresh;
      } catch (_) {
        // 刷新路径自行记录错误；销毁继续等待统一写队列收口。
      }
    }

    // dispose 已先递增 lifecycleGeneration，排队但尚未运行的先前缓存
    // 任务会直接退出；
    // 已进入宿主持久化写入的任务必须在新 client 启动前完成收口。
    try {
      await _databaseCacheWriteTail;
    } catch (_) {
      // 保存路径自行记录错误；销毁不得因非关键缓存失败而中断。
    }

    try {
      final disposeOverride = _disposeOverride;
      if (disposeOverride != null) {
        await disposeOverride();
      } else {
        await _releaseNativeResources();
      }
    } finally {
      _resetLifecycleState();
    }
  }

  Future<void> _releaseNativeResources() async {
    final chain = _chain;
    final client = _client;
    _chain = null;
    _client = null;

    try {
      await chain?.dispose();
    } catch (e) {
      _debug('[Smoldot] 释放 chain 失败: $e');
    }
    try {
      await client?.dispose();
    } catch (e) {
      _debug('[Smoldot] 释放 client 失败: $e');
    }
  }

  void _resetLifecycleState() {
    _initialized = false;
    _synced = false;
    _syncFuture = null;
    _retrySyncFuture = null;
    _databaseCacheRefreshTimer?.cancel();
    _databaseCacheRefreshTimer = null;
    _databaseCacheRefreshFuture = null;
    _lastPersistedFinalizedBlockNumber = null;
    _lastError = null;
    _setHealthStatus(ChainHealthStatus.uninitialized);
    _lastBootstrapManifest = null;
    _lastBootstrapError = null;
    _expectedGenesisHash = null;
    _debug('[Smoldot] 轻节点已关闭');
  }

  void _ensureReady() {
    if (!_hasSyncSource) {
      throw StateError('smoldot 轻节点未初始化，请先调用 ensureStarted()');
    }
  }

  bool get _hasSyncSource =>
      isReady ||
      (_initialized &&
          _synchronizeOverride != null &&
          _syncStatusOverride != null);

  Future<LightClientStatusSnapshot> _readSyncStatus() {
    final override = _syncStatusOverride;
    if (override != null) return override();
    return _chain!.getStatusSnapshot();
  }

  void _setHealthStatus(ChainHealthStatus status) {
    _healthStatus = status;
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
      lastError: _lastError,
    );
    _health = next;
    if (!_healthController.isClosed) _healthController.add(next);
  }

  void _publishSnapshot(
    LightClientStatusSnapshot snapshot, {
    required ChainHealthStatus status,
  }) {
    _healthStatus = status;
    final next = ChainHealthSnapshot(
      status: status,
      peerCount: snapshot.peerCount,
      isUsable: snapshot.isUsable,
      currentVerifiedFinalizedBlockNumber:
          snapshot.currentVerifiedFinalizedBlockNumber,
      currentVerifiedFinalizedBlockHash:
          snapshot.currentVerifiedFinalizedBlockHash,
      bestBlockNumber: snapshot.bestBlockNumber,
      bestBlockHash: snapshot.bestBlockHash,
      lastError: _lastError,
    );
    _health = next;
    if (!_healthController.isClosed) _healthController.add(next);
  }

  void _debug(String message) {
    _logger(
      CitizenSdkLogEvent(
        level: CitizenSdkLogLevel.debug,
        scope: 'light_client',
        message: message,
      ),
    );
  }
}

/// 初始化所属生命周期已被 dispose 失效。
class _SmoldotLifecycleInvalidated implements Exception {
  const _SmoldotLifecycleInvalidated();

  @override
  String toString() => 'smoldot 初始化已被新的生命周期取代';
}
