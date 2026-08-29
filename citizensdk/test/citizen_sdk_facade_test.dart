import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('公共门面组合轻节点、钱包、转账、验签和可选 finalized 流水能力', () {
    final sdk = CitizenSdk(
      walletRepository: _MemoryWalletRepository(),
      secureSeedStore: _MemorySeedStore(),
      transactionRepository: _MemoryTransactionRepository(),
    );
    expect(sdk.chain, isA<CitizenLightClient>());
    expect(sdk.wallet, isA<WalletService>());
    expect(sdk.transfers, isA<TransferService>());
    expect(sdk.signer, isA<CitizenSigner>());
    expect(sdk.transactionHistory, isA<FinalizedTransactionHistory>());
    expect(sdk.transactionScanner, isA<FinalizedTransactionScanner>());
  });

  test('自定义装配可显式关闭流水仓储，移动标准装配默认提供它', () {
    final custom = CitizenSdk(
      walletRepository: _MemoryWalletRepository(),
      secureSeedStore: _MemorySeedStore(),
    );
    expect(custom.transactionHistory, isNull);
    expect(custom.transactionScanner, isNull);

    final mobile = MobileCitizenSdkComponents.standard(
      preferencesStore: _MemoryPreferences(),
    );
    expect(
      mobile.transactionRepository,
      isA<PreferencesFinalizedTransactionRepository>(),
    );
  });

  test('dispose 在 scanner 清理失败时仍释放轻节点并返回首个错误', () async {
    var chainDisposeCount = 0;
    final headSource = _FacadeHeadSource();
    addTearDown(headSource.close);
    final chain = CitizenLightClient.forTesting(
      initialize: () async {},
      dispose: () async {
        chainDisposeCount += 1;
      },
      request: (method, params) async => switch (method) {
        'chain_getFinalizedHead' => _blockHash(5),
        'chain_getHeader' => const <String, Object?>{'number': '0x5'},
        _ => throw StateError('未预期 RPC：$method'),
      },
    );
    final sdk = CitizenSdk(
      walletRepository: _MemoryWalletRepository(),
      secureSeedStore: _MemorySeedStore(),
      lightClient: chain,
      transactionRepository: _MemoryTransactionRepository(),
      transactionHeadSource: headSource,
    );
    await sdk.transactionScanner!.replaceWatchedAccounts(<String>[
      _blockHash(0xaa),
    ]);
    await sdk.transactionScanner!.start();
    headSource.disconnectError = StateError('scanner cleanup failed');

    await expectLater(sdk.dispose(), throwsStateError);

    expect(headSource.disconnectCount, 1);
    expect(chainDisposeCount, 1);
  });
}

final class _FacadeHeadSource implements FinalizedBlockHeadSource {
  final StreamController<int> _heads = StreamController<int>.broadcast();
  final StreamController<void> _dropped = StreamController<void>.broadcast();
  int disconnectCount = 0;
  Object? disconnectError;

  @override
  Stream<int> get finalizedBlockNumbers => _heads.stream;

  @override
  Stream<void> get dropped => _dropped.stream;

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    final error = disconnectError;
    if (error != null) throw error;
  }

  Future<void> close() async {
    await _heads.close();
    await _dropped.close();
  }
}

final class _MemoryPreferences implements PreferencesDataStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

final class _MemoryWalletRepository implements WalletRepository {
  WalletState state = const WalletState.empty();

  @override
  Future<WalletState> load() async => state;

  @override
  Future<WalletState> commit({
    required int expectedRevision,
    required WalletProfile? profile,
    required WalletProvisioningPlan? provisioning,
    required WalletCleanupPlan? cleanup,
    required List<WalletCleanupPlan> cleanupQueue,
  }) async {
    if (state.revision != expectedRevision) {
      throw const WalletRepositoryConflict();
    }
    return state = WalletState(
      revision: state.revision + 1,
      profile: profile,
      provisioning: provisioning,
      cleanup: cleanup,
      cleanupQueue: cleanupQueue,
    );
  }
}

final class _MemorySeedStore implements SecureSeedStore {
  @override
  Future<SecureAuthStatus> authStatus() async => SecureAuthStatus.available;

  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async {}

  @override
  Future<void> deleteWalletKey({
    required int walletIndex,
    required String walletGeneration,
  }) async {}

  @override
  Future<bool> hasAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async => false;

  @override
  Future<bool> hasWalletKey({
    required int walletIndex,
    required String walletGeneration,
  }) async => false;

  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {}

  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String walletGeneration,
    required String secretOwner,
    required String accountId,
  }) async => null;
}

final class _MemoryTransactionRepository
    implements FinalizedTransactionRepository {
  FinalizedTransactionState state = const FinalizedTransactionState.empty();

  @override
  Future<FinalizedTransactionState> load() async => state;

  @override
  Future<FinalizedTransactionState> commit({
    required int expectedRevision,
    required Map<String, TransactionSyncCursor> cursors,
    required Map<String, FinalizedAccountTransfer> transfers,
    required Map<String, PendingSubmittedTransaction> submissions,
  }) async {
    if (state.revision != expectedRevision) {
      throw const FinalizedTransactionRepositoryConflict();
    }
    return state = FinalizedTransactionState(
      revision: state.revision + 1,
      cursors: cursors,
      transfers: transfers,
      submissions: submissions,
    );
  }
}

String _blockHash(int value) => '0x${value.toRadixString(16).padLeft(64, '0')}';
