import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:citizen_sdk/src/node/bootstrap_client.dart';
import 'package:citizen_sdk/src/node/chain_assets.dart';
import 'package:citizen_sdk/src/node/chain_database_store.dart';
import 'package:citizen_sdk/src/node/chain_event_subscription.dart';
import 'package:citizen_sdk/src/node/chain_health.dart';
import 'package:citizen_sdk/src/node/light_client.dart';
import 'package:citizen_sdk/src/smoldot/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

late _MemoryChainDatabaseStore _store;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _store = _MemoryChainDatabaseStore();
  });

  test('损坏链资产在创建或初始化原生 smoldot 客户端前失败', () async {
    late CitizenLightClient manager;
    final reads = <String>[];
    final bundle = _FailingAssetBundle((key) {
      reads.add(key);
      expect(manager.nativeClientCreatedForTesting, isFalse);
    });
    manager = CitizenLightClient(
      assets: CitizenChainAssets(bundle: bundle),
      bootstrapClient: BootstrapClient(
        httpClient: MockClient((_) async => http.Response('{}', 503)),
      ),
      databaseStore: _store,
    );

    await expectLater(manager.ensureStarted(), throwsFormatException);
    expect(reads, <String>[CitizenChainAssets.manifestAsset]);
    expect(manager.nativeClientCreatedForTesting, isFalse);
    await manager.dispose();
  });

  test('并发启动复用同一个 Future 且只执行一次初始化', () async {
    final releaseStart = Completer<void>();
    var startCount = 0;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () {
        startCount += 1;
        return releaseStart.future;
      },
    );

    final first = manager.ensureStarted();
    final second = manager.initialize();

    expect(identical(first, second), isTrue);
    expect(startCount, 1);
    releaseStart.complete();
    await Future.wait([first, second]);

    expect(manager.initializedForTesting, isTrue);
    await manager.dispose();
  });

  test('初始化失败会清空在途状态并允许下一次重试', () async {
    var startCount = 0;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {
        startCount += 1;
        if (startCount == 1) {
          throw StateError('first start failed');
        }
      },
    );

    await expectLater(manager.ensureStarted(), throwsStateError);
    expect(manager.initializedForTesting, isFalse);

    await manager.ensureStarted();
    expect(startCount, 2);
    expect(manager.initializedForTesting, isTrue);
    await manager.dispose();
  });

  test('初始化成功后 dispose 可以释放并再次启动', () async {
    var startCount = 0;
    var disposeCount = 0;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async => startCount += 1,
      dispose: () async => disposeCount += 1,
    );

    await manager.ensureStarted();
    await manager.dispose();
    expect(manager.initializedForTesting, isFalse);

    await manager.ensureStarted();
    expect(startCount, 2);
    expect(disposeCount, 1);
    expect(manager.initializedForTesting, isTrue);
    await manager.dispose();
  });

  test('dispose 会让先前的在途初始化失效且不会覆盖新生命周期', () async {
    final firstStart = Completer<void>();
    var startCount = 0;
    var disposeCount = 0;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () {
        startCount += 1;
        return startCount == 1 ? firstStart.future : Future<void>.value();
      },
      dispose: () async => disposeCount += 1,
    );

    final staleStart = manager.ensureStarted();
    final staleStartExpectation = expectLater(
      staleStart,
      throwsA(isA<Exception>()),
    );
    final disposing = manager.dispose();
    firstStart.complete();

    await staleStartExpectation;
    await disposing;
    expect(manager.initializedForTesting, isFalse);

    await manager.ensureStarted();
    expect(startCount, 2);
    expect(disposeCount, 1);
    expect(manager.initializedForTesting, isTrue);
    await manager.dispose();
  });

  test('dispose 进行中发起的启动会等待释放完成并进入新生命周期', () async {
    final releaseDispose = Completer<void>();
    var startCount = 0;
    var disposeFinished = false;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {
        expect(disposeFinished || startCount == 0, isTrue);
        startCount += 1;
      },
      dispose: () async {
        await releaseDispose.future;
        disposeFinished = true;
      },
    );

    await manager.ensureStarted();
    final disposing = manager.dispose();
    final restarting = manager.ensureStarted();

    expect(manager.initializedForTesting, isTrue);
    expect(startCount, 1);
    releaseDispose.complete();
    await Future.wait([disposing, restarting]);

    expect(startCount, 2);
    expect(manager.initializedForTesting, isTrue);
    await manager.dispose();
  });

  test('链订阅会等待启动结果且初始化失败时返回 false', () async {
    var startCount = 0;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {
        startCount += 1;
        throw StateError('start failed');
      },
    );
    final subscription = ChainEventSubscription(lightClient: manager);

    expect(await subscription.connect(), isFalse);
    expect(startCount, 1);

    subscription.disconnect();
    await manager.dispose();
  });

  test('同步成功不是粘性状态，原生重新进入 warp 后必须再次过门禁', () async {
    final statuses = Queue<LightClientStatusSnapshot>.from(
      <LightClientStatusSnapshot>[
        _snapshot(10),
        _snapshot(11, syncPhase: LightClientSyncPhase.warpDownloadingFragments),
        _snapshot(11),
      ],
    );
    var synchronizeCount = 0;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {},
      synchronize: (_) async => synchronizeCount += 1,
      syncStatus: () async => statuses.removeFirst(),
    );

    await manager.ensureSynced();
    await manager.ensureSynced();

    expect(synchronizeCount, 2);
    expect(manager.healthStatus, ChainHealthStatus.operational);
    await manager.dispose();
  });

  test('同步超时后由单一后台重试恢复 operational', () async {
    final retryStarted = Completer<void>();
    final releaseRetry = Completer<void>();
    var synchronizeCount = 0;
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {},
      synchronize: (_) async {
        synchronizeCount += 1;
        if (synchronizeCount == 1) throw TimeoutException('first timeout');
        retryStarted.complete();
        await releaseRetry.future;
      },
      syncStatus: () async => _snapshot(12),
      retrySyncDelay: Duration.zero,
      retrySyncAttempts: 1,
    );

    await expectLater(manager.ensureSynced(), throwsA(isA<TimeoutException>()));
    await retryStarted.future;
    releaseRetry.complete();
    while (manager.healthStatus != ChainHealthStatus.operational) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(synchronizeCount, 2);
    await manager.dispose();
  });

  test('degraded 后基础读取恢复只能回到 syncing 而不能伪报 operational', () async {
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {},
      synchronize: (_) async {},
      syncStatus: () async => _snapshot(13),
    );
    await manager.ensureSynced();
    expect(manager.health.status, ChainHealthStatus.operational);
    expect(manager.health.isUsable, isTrue);

    await expectLater(
      manager.readWithRetryForTesting<void>(
        'forced read failure',
        () async => throw StateError('fatal read failure'),
      ),
      throwsStateError,
    );
    expect(manager.health.status, ChainHealthStatus.degraded);
    expect(manager.health.isUsable, isFalse);

    expect(
      await manager.readWithRetryForTesting<String>(
        'base rpc recovery',
        () async => 'ok',
      ),
      'ok',
    );
    expect(manager.health.status, ChainHealthStatus.syncing);
    expect(manager.health.isUsable, isFalse);
    expect(manager.health.lastError, isNull);
    await manager.dispose();
  });

  test('事件订阅解析块高并在意外断开时发出 dropped', () async {
    final newHeads = StreamController<Object?>();
    final finalizedHeads = StreamController<Object?>();
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {},
      synchronize: (_) async {},
      syncStatus: () async => _snapshot(20),
      subscribe: (method, _) => switch (method) {
        'chain_subscribeNewHeads' => newHeads.stream,
        'chain_subscribeFinalizedHeads' => finalizedHeads.stream,
        _ => const Stream<Object?>.empty(),
      },
    );
    final subscription = ChainEventSubscription(lightClient: manager);

    expect(await subscription.connect(), isTrue);
    final eventExpectation = expectLater(
      subscription.events,
      emits(
        isA<ChainEvent>()
            .having((event) => event.type, 'type', ChainEventType.newBlock)
            .having((event) => event.blockNumber, 'blockNumber', 42),
      ),
    );
    newHeads.add(<String, Object?>{'number': '0x2a'});
    await eventExpectation;

    final droppedExpectation = expectLater(subscription.dropped, emits(isNull));
    await newHeads.close();
    await droppedExpectation;

    subscription.disconnect();
    await finalizedHeads.close();
    await manager.dispose();
  });

  test('事件订阅主动断开消费两条 cancel Future 的异步失败', () async {
    final newHeads = StreamController<Object?>(
      onCancel: () => Future<void>.error(StateError('new heads cancel failed')),
    );
    final finalizedHeads = StreamController<Object?>(
      onCancel: () =>
          Future<void>.error(StateError('finalized heads cancel failed')),
    );
    final manager = CitizenLightClient.forTesting(
      databaseStore: _store,
      initialize: () async {},
      synchronize: (_) async {},
      syncStatus: () async => _snapshot(21),
      subscribe: (method, _) => switch (method) {
        'chain_subscribeNewHeads' => newHeads.stream,
        'chain_subscribeFinalizedHeads' => finalizedHeads.stream,
        _ => const Stream<Object?>.empty(),
      },
    );
    final subscription = ChainEventSubscription(lightClient: manager);
    final zoneErrors = <Object>[];

    final body = runZonedGuarded<Future<void>>(() async {
      expect(await subscription.connect(), isTrue);
      subscription.disconnect();
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => zoneErrors.add(error));
    expect(body, isNotNull);
    await body!;

    expect(zoneErrors, isEmpty);
    expect(newHeads.hasListener, isFalse);
    expect(finalizedHeads.hasListener, isFalse);
    // 这两个故障注入 controller 的 onCancel Future 刻意失败；其 close Future
    // 会等待同一失败清理，不属于被测 SDK。订阅已取消且 controller 无 listener，
    // 测试结束后即可由 GC 回收。
    await manager.dispose();
  });

  group('smoldot finalized database 缓存', () {
    // 缓存行为只需要稳定的链身份夹具，禁止复制任何真实创世哈希
    // 形成第二真源。
    const genesisHash =
        '0x1111111111111111111111111111111111111111111111111111111111111111';

    test('从内置 #0 checkpoint 推导合法 genesis hash', () async {
      final checkpointRaw = await File(
        'assets/citizenchain/light_sync_state.json',
      ).readAsString();
      final checkpoint = jsonDecode(checkpointRaw) as Map<String, dynamic>;

      expect(
        CitizenLightClient.genesisHashFromCheckpointForTesting(
          checkpoint['finalizedBlockHeader'] as String,
        ),
        matches(RegExp(r'^0x[0-9a-f]{64}$')),
      );
      expect(
        () => CitizenLightClient.genesisHashFromCheckpointForTesting(
          '0x${'00' * 32}80',
        ),
        throwsFormatException,
      );
    });

    test('无有效 database 时真实启动锚点只能是安装包固定 #0', () {
      final bundledStart = _snapshot(0, startupFinalizedBlockHash: genesisHash);
      expect(
        CitizenLightClient.bundledCheckpointStartMatchesForTesting(
          expectedGenesisHash: genesisHash,
          snapshot: bundledStart,
        ),
        isTrue,
      );
      expect(
        CitizenLightClient.bundledCheckpointStartMatchesForTesting(
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(
            0,
            startupFinalizedSource:
                LightClientStartupFinalizedSource.localDatabase,
            startupFinalizedBlockHash: genesisHash,
          ),
        ),
        isFalse,
      );
      expect(
        CitizenLightClient.bundledCheckpointStartMatchesForTesting(
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(
            1,
            startupFinalizedBlockNumber: 1,
            startupFinalizedBlockHash: _hashForHeight(1),
          ),
        ),
        isFalse,
      );
      expect(
        CitizenLightClient.bundledCheckpointStartMatchesForTesting(
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(0),
        ),
        isFalse,
      );
    });

    test('无信封格式、未知字段和跨链信封会被删除', () async {
      final manager = CitizenLightClient.forTesting(
        databaseStore: _store,
        initialize: () async {},
      );
      await _store.write('unversioned-database');
      expect(await manager.loadCachedDatabaseForTesting(genesisHash), isNull);
      expect(await _store.read(), isNull);

      await _store.write(
        _cacheEnvelopeRaw(
          genesisHash: genesisHash,
          finalizedBlockNumber: 10,
          databaseContent: 'db-10',
          extra: const {'unknown_field': true},
        ),
      );
      expect(await manager.loadCachedDatabaseForTesting(genesisHash), isNull);
      expect(await _store.read(), isNull);

      await _store.write(
        _cacheEnvelopeRaw(
          genesisHash: _hashForHeight(999),
          finalizedBlockNumber: 10,
          databaseContent: 'db-10',
        ),
      );
      expect(await manager.loadCachedDatabaseForTesting(genesisHash), isNull);
      expect(await _store.read(), isNull);

      await _store.write(
        _cacheEnvelopeRaw(
          genesisHash: genesisHash,
          finalizedBlockNumber: 10,
          databaseContent: 'db-10',
        ),
      );
      expect(await manager.loadCachedDatabaseForTesting(genesisHash), 'db-10');
    });

    test('缓存恢复必须真实采用信封声明的 database anchor', () {
      final raw = _cacheEnvelopeRaw(
        genesisHash: genesisHash,
        finalizedBlockNumber: 10,
        databaseContent: 'db-10',
      );

      expect(
        CitizenLightClient.restoredDatabaseCacheReachedForTesting(
          rawEnvelope: raw,
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(10),
        ),
        isFalse,
      );
      expect(
        CitizenLightClient.restoredDatabaseCacheReachedForTesting(
          rawEnvelope: raw,
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(
            10,
            startupFinalizedSource:
                LightClientStartupFinalizedSource.localDatabase,
            startupFinalizedBlockNumber: 9,
            startupFinalizedBlockHash: _hashForHeight(9),
          ),
        ),
        isFalse,
      );
      expect(
        CitizenLightClient.restoredDatabaseCacheReachedForTesting(
          rawEnvelope: raw,
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(
            10,
            startupFinalizedSource:
                LightClientStartupFinalizedSource.localDatabase,
            startupFinalizedBlockNumber: 10,
            startupFinalizedBlockHash: _hashForHeight(10),
          ),
        ),
        isTrue,
      );
      expect(
        CitizenLightClient.restoredDatabaseCacheReachedForTesting(
          rawEnvelope: raw,
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(
            11,
            startupFinalizedSource:
                LightClientStartupFinalizedSource.localDatabase,
            startupFinalizedBlockNumber: 10,
            startupFinalizedBlockHash: _hashForHeight(10),
          ),
        ),
        isTrue,
      );
      expect(
        CitizenLightClient.restoredDatabaseCacheReachedForTesting(
          rawEnvelope: raw,
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(
            11,
            startupFinalizedSource:
                LightClientStartupFinalizedSource.localDatabase,
            startupFinalizedBlockNumber: 10,
            startupFinalizedBlockHash: _hashForHeight(11),
          ),
        ),
        isFalse,
      );
    });

    test('导出严格串行且低 finalized 不得覆盖高缓存', () async {
      final statusQueue = Queue<LightClientStatusSnapshot>.from([
        _snapshot(10),
        _snapshot(10),
        _snapshot(20),
        _snapshot(20),
        _snapshot(19),
        _snapshot(19),
      ]);
      final releaseFirstExport = Completer<void>();
      final firstExportStarted = Completer<void>();
      var exportCount = 0;
      final manager = CitizenLightClient.forTesting(
        databaseStore: _store,
        initialize: () async {},
        cacheStatus: () async => statusQueue.removeFirst(),
        exportDatabase: () async {
          exportCount += 1;
          if (exportCount == 1) {
            firstExportStarted.complete();
            await releaseFirstExport.future;
          }
          return switch (exportCount) {
            1 => 'db-10',
            2 => 'db-20',
            _ => 'db-19',
          };
        },
        expectedGenesisHash: genesisHash,
      );
      await manager.ensureStarted();

      final first = manager.saveDatabaseCacheForTesting();
      await firstExportStarted.future;
      final second = manager.saveDatabaseCacheForTesting();
      await Future<void>.delayed(Duration.zero);
      expect(exportCount, 1, reason: '第二次导出必须等待第一次完成');

      releaseFirstExport.complete();
      await Future.wait([first, second]);
      await manager.saveDatabaseCacheForTesting();

      final saved = await _savedEnvelope();
      expect(saved['finalized_block_number'], 20);
      expect(saved['database_content'], 'db-20');
      await manager.dispose();
    });

    test('finalized 在导出期间推进时丢弃不稳定正文并重试', () async {
      final statusQueue = Queue<LightClientStatusSnapshot>.from([
        _snapshot(10),
        _snapshot(11),
        _snapshot(11),
        _snapshot(11),
      ]);
      final databaseQueue = Queue<String>.from(['moving-db', 'stable-db']);
      final manager = CitizenLightClient.forTesting(
        databaseStore: _store,
        initialize: () async {},
        cacheStatus: () async => statusQueue.removeFirst(),
        exportDatabase: () async => databaseQueue.removeFirst(),
        expectedGenesisHash: genesisHash,
      );
      await manager.ensureStarted();

      await manager.saveDatabaseCacheForTesting();

      final saved = await _savedEnvelope();
      expect(saved['finalized_block_number'], 11);
      expect(saved['database_content'], 'stable-db');
      await manager.dispose();
    });

    test('表面 finalized 已到 F 但完整验证仍为 H 时禁止落缓存', () async {
      final statusQueue = Queue<LightClientStatusSnapshot>.from([
        _snapshot(
          33,
          isSyncing: false,
          syncPhase: LightClientSyncPhase.warpDownloadingFragments,
        ),
        _snapshot(31),
        _snapshot(31),
        _snapshot(31),
        _snapshot(33),
        _snapshot(33),
        _snapshot(33),
      ]);
      var exportCount = 0;
      final manager = CitizenLightClient.forTesting(
        databaseStore: _store,
        initialize: () async {},
        cacheStatus: () async => statusQueue.removeFirst(),
        exportDatabase: () async => 'db-${++exportCount}',
        expectedGenesisHash: genesisHash,
      );
      await manager.ensureStarted();

      await manager.saveDatabaseCacheForTesting();
      expect(exportCount, 0, reason: 'warp 尚未 regular 时禁止导出');

      await manager.saveDatabaseCacheForTesting();
      expect((await _savedEnvelope())['finalized_block_number'], 31);
      expect(exportCount, 1);

      await manager.refreshDatabaseCacheIfAdvancedForTesting();
      expect(exportCount, 1, reason: 'finalized 未推进时不得重复导出');

      await manager.refreshDatabaseCacheIfAdvancedForTesting();
      final saved = await _savedEnvelope();
      expect(saved['finalized_block_number'], 33);
      expect(saved['database_content'], 'db-2');
      expect(exportCount, 2);
      await manager.dispose();
    });

    test('完整验证 F 落盘后下一次启动必须把同一个 F 作为 H', () async {
      final statusQueue = Queue<LightClientStatusSnapshot>.from([
        _snapshot(100),
        _snapshot(100),
      ]);
      final manager = CitizenLightClient.forTesting(
        databaseStore: _store,
        initialize: () async {},
        cacheStatus: () async => statusQueue.removeFirst(),
        exportDatabase: () async => 'db-f',
        expectedGenesisHash: genesisHash,
      );
      await manager.ensureStarted();
      await manager.saveDatabaseCacheForTesting();

      final rawEnvelope = (await _store.read())!;
      expect(
        CitizenLightClient.restoredDatabaseCacheReachedForTesting(
          rawEnvelope: rawEnvelope,
          expectedGenesisHash: genesisHash,
          snapshot: _snapshot(
            100,
            startupFinalizedSource:
                LightClientStartupFinalizedSource.localDatabase,
            startupFinalizedBlockNumber: 100,
            startupFinalizedBlockHash: _hashForHeight(100),
          ),
        ),
        isTrue,
      );
      await manager.dispose();
    });

    test('同高度同 hash 不重写，同高度不同 hash 清理后写入当前候选', () async {
      final hashA = _hashForHeight(20);
      final hashB = _hashForHeight(21);
      final statusQueue = Queue<LightClientStatusSnapshot>.from([
        _snapshot(20, hash: hashA),
        _snapshot(20, hash: hashA),
        _snapshot(20, hash: hashA),
        _snapshot(20, hash: hashA),
        _snapshot(20, hash: hashB),
        _snapshot(20, hash: hashB),
      ]);
      final databaseQueue = Queue<String>.from(['db-a', 'db-b', 'db-c']);
      final manager = CitizenLightClient.forTesting(
        databaseStore: _store,
        initialize: () async {},
        cacheStatus: () async => statusQueue.removeFirst(),
        exportDatabase: () async => databaseQueue.removeFirst(),
        expectedGenesisHash: genesisHash,
      );
      await manager.ensureStarted();

      await manager.saveDatabaseCacheForTesting();
      await manager.saveDatabaseCacheForTesting();
      expect((await _savedEnvelope())['database_content'], 'db-a');

      await manager.saveDatabaseCacheForTesting();
      final saved = await _savedEnvelope();
      expect(saved['finalized_block_hash'], hashB);
      expect(saved['database_content'], 'db-c');
      await manager.dispose();
    });

    test('dispose 使先前导出失效且新生命周期可以保存更高缓存', () async {
      final statusQueue = Queue<LightClientStatusSnapshot>.from([
        _snapshot(10),
        _snapshot(20),
        _snapshot(20),
      ]);
      final oldExportStarted = Completer<void>();
      final releaseOldExport = Completer<void>();
      var exportCount = 0;
      final manager = CitizenLightClient.forTesting(
        databaseStore: _store,
        initialize: () async {},
        cacheStatus: () async => statusQueue.removeFirst(),
        exportDatabase: () async {
          exportCount += 1;
          if (exportCount == 1) {
            oldExportStarted.complete();
            await releaseOldExport.future;
            return 'stale-db-10';
          }
          return 'db-20';
        },
        expectedGenesisHash: genesisHash,
      );
      await manager.ensureStarted();

      final staleSave = manager.saveDatabaseCacheForTesting();
      await oldExportStarted.future;
      final disposing = manager.dispose();
      releaseOldExport.complete();
      await Future.wait([staleSave, disposing]);
      expect(await _store.read(), isNull);

      await manager.ensureStarted();
      await manager.saveDatabaseCacheForTesting();
      final saved = await _savedEnvelope();
      expect(saved['finalized_block_number'], 20);
      expect(saved['database_content'], 'db-20');
      await manager.dispose();
    });
  });
}

LightClientStatusSnapshot _snapshot(
  int height, {
  String? hash,
  bool isSyncing = false,
  LightClientSyncPhase syncPhase = LightClientSyncPhase.regular,
  LightClientStartupFinalizedSource startupFinalizedSource =
      LightClientStartupFinalizedSource.bundledCheckpoint,
  int startupFinalizedBlockNumber = 0,
  String? startupFinalizedBlockHash,
}) {
  final isUsable = !isSyncing && syncPhase == LightClientSyncPhase.regular;
  final currentVerifiedHeight = isUsable ? height : startupFinalizedBlockNumber;
  final currentVerifiedHash = isUsable
      ? (hash ?? _hashForHeight(height))
      : (startupFinalizedBlockHash ??
            _hashForHeight(startupFinalizedBlockNumber));
  return LightClientStatusSnapshot(
    peerCount: 1,
    isSyncing: isSyncing,
    isUsable: isUsable,
    syncPhase: syncPhase,
    bestBlockNumber: height,
    bestBlockHash: hash ?? _hashForHeight(height),
    finalizedBlockNumber: height,
    finalizedBlockHash: hash ?? _hashForHeight(height),
    startupFinalizedSource: startupFinalizedSource,
    startupFinalizedBlockNumber: startupFinalizedBlockNumber,
    startupFinalizedBlockHash:
        startupFinalizedBlockHash ??
        _hashForHeight(startupFinalizedBlockNumber),
    highestPeerFinalizedBlockNumber: height,
    currentVerifiedFinalizedBlockNumber: currentVerifiedHeight,
    currentVerifiedFinalizedBlockHash: currentVerifiedHash,
    warpTargetFinalizedBlockNumber: isUsable ? null : height,
    warpTargetFinalizedBlockHash: isUsable
        ? null
        : (hash ?? _hashForHeight(height)),
    warpRequestCount: 0,
    activeWarpFragmentRequestCount: 0,
    activeWarpStorageRequestCount: 0,
    activeWarpCallProofRequestCount: 0,
    warpReceivedFragmentCount: 0,
    warpVerifiedFragmentCount: 0,
    warpRejectedFragmentCount: 0,
  );
}

String _hashForHeight(int height) =>
    '0x${height.toRadixString(16).padLeft(64, '0')}';

String _cacheEnvelopeRaw({
  required String genesisHash,
  required int finalizedBlockNumber,
  required String databaseContent,
  Map<String, dynamic> extra = const {},
}) {
  return jsonEncode({
    'schema': 'citizen_sdk.smoldot.database.v1',
    'genesis_hash': genesisHash,
    'finalized_block_number': finalizedBlockNumber,
    'finalized_block_hash': _hashForHeight(finalizedBlockNumber),
    'database_content': databaseContent,
    ...extra,
  });
}

Future<Map<String, dynamic>> _savedEnvelope() async =>
    jsonDecode((await _store.read())!) as Map<String, dynamic>;

final class _MemoryChainDatabaseStore implements ChainDatabaseStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String envelope) async {
    value = envelope;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

/// 生产启动顺序回归夹具：读取第一项资产时检查原生客户端尚未创建，随后
/// 以确定性格式错误终止，避免测试依赖本机动态库或网络。
final class _FailingAssetBundle extends AssetBundle {
  _FailingAssetBundle(this.onLoad);

  final void Function(String key) onLoad;

  @override
  Future<ByteData> load(String key) async {
    onLoad(key);
    throw FormatException('测试链资产损坏：$key');
  }
}
