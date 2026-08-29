import 'dart:convert';

import 'package:citizen_sdk/src/platform/preferences_data_store.dart';
import 'package:citizen_sdk/src/platform/preferences_finalized_transaction_repository.dart';
import 'package:citizen_sdk/src/transaction/finalized_transaction_models.dart';
import 'package:citizen_sdk/src/transaction/finalized_transaction_repository.dart';
import 'package:citizen_sdk/src/transaction/transaction_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final accountA = _account(0xaa);
  final accountB = _account(0xbb);
  final txHash = _hash(0x11);
  const runtimeFailure = ChainExtrinsicFailure(
    dispatchErrorVariant: 3,
    moduleIndex: 4,
    errorIndex: 0,
    description: 'ZeroAmount',
  );

  DecodedFinalizedTransfer decodedTransfer({
    int blockNumber = 8,
    String? blockHash,
    int? extrinsicIndex = 0,
    String sourcePallet = 'OnchainTransaction',
    String? remark = 'fixture',
  }) => DecodedFinalizedTransfer(
    fromAccountId: accountA,
    toAccountId: accountB,
    amountFen: BigInt.one,
    blockNumber: blockNumber,
    blockHash: blockHash ?? _hash(8),
    eventRecordIndex: 2,
    extrinsicIndex: extrinsicIndex,
    sourcePallet: sourcePallet,
    remark: remark,
  );

  FinalizedAccountTransfer accountTransfer({
    int blockNumber = 8,
    String? blockHash,
    int? extrinsicIndex = 0,
    String sourcePallet = 'OnchainTransaction',
    String? remark = 'fixture',
  }) {
    final resolvedBlockHash = blockHash ?? _hash(8);
    return FinalizedAccountTransfer(
      recordKey: FinalizedAccountTransfer.eventRecordKey(
        accountA,
        resolvedBlockHash,
        2,
      ),
      accountId: accountA,
      direction: FinalizedTransferDirection.outgoing,
      fromAccountId: accountA,
      toAccountId: accountB,
      amountFen: BigInt.one,
      blockNumber: blockNumber,
      blockHash: resolvedBlockHash,
      eventRecordIndex: 2,
      extrinsicIndex: extrinsicIndex,
      sourcePallet: sourcePallet,
      remark: remark,
    );
  }

  PendingSubmittedTransaction submission({
    PendingSubmittedTransactionStatus status =
        PendingSubmittedTransactionStatus.pending,
    String? transactionHash,
    String? anchorBlockHash,
    int? blockNumber,
    int? extrinsicIndex,
    ChainExtrinsicFailure? failure,
    String? failureReason,
  }) => PendingSubmittedTransaction(
    recordKey: PendingSubmittedTransaction.submitRecordKey(accountA, txHash),
    accountId: accountA,
    txHash: transactionHash ?? txHash,
    usedNonce: 3,
    fromAccountId: accountA,
    toAccountId: accountB,
    amountFen: BigInt.one,
    remark: 'fixture',
    status: status,
    createdAtMillis: 100,
    updatedAtMillis: 101,
    anchorBlockHash: anchorBlockHash,
    blockNumber: blockNumber,
    extrinsicIndex: extrinsicIndex,
    failure: failure,
    failureReason: failureReason,
  );

  test('公开模型只接受规范哈希、非负 index 与白名单转账来源', () {
    final canonicalHash = _hash(8);
    final invalidHashes = <String>[
      canonicalHash.substring(2),
      canonicalHash.toUpperCase(),
      '0x${canonicalHash.substring(2, 65)}g',
    ];
    for (final invalidHash in invalidHashes) {
      expect(
        () => normalizeCitizenChainHash(invalidHash),
        throwsFormatException,
      );
      expect(
        () => decodedTransfer(blockHash: invalidHash),
        throwsFormatException,
      );
      expect(
        () => submission(transactionHash: invalidHash),
        throwsFormatException,
      );
    }
    expect(normalizeCitizenChainHash(canonicalHash), canonicalHash);

    expect(() => decodedTransfer(extrinsicIndex: -1), throwsFormatException);
    expect(() => accountTransfer(extrinsicIndex: -1), throwsFormatException);
    expect(
      () => submission(
        status: PendingSubmittedTransactionStatus.finalized,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        extrinsicIndex: -1,
      ),
      throwsFormatException,
    );

    for (final unsupported in <String>['System', 'balances', '']) {
      expect(
        () => decodedTransfer(sourcePallet: unsupported),
        throwsFormatException,
      );
      expect(
        () => accountTransfer(sourcePallet: unsupported),
        throwsFormatException,
      );
    }
    expect(
      () => decodedTransfer(sourcePallet: 'Balances', remark: ''),
      throwsFormatException,
    );
    expect(
      () => accountTransfer(sourcePallet: 'Balances', remark: 'fixture'),
      throwsFormatException,
    );
    expect(
      decodedTransfer(sourcePallet: 'Balances', remark: null).sourcePallet,
      'Balances',
    );
  });

  test('pending 状态机公开模型严格执行每个状态的字段闭集', () {
    expect(submission().status, PendingSubmittedTransactionStatus.pending);
    expect(
      submission(
        status: PendingSubmittedTransactionStatus.inBlock,
        anchorBlockHash: _hash(8),
      ).status,
      PendingSubmittedTransactionStatus.inBlock,
    );
    expect(
      submission(
        status: PendingSubmittedTransactionStatus.poolRejected,
        failureReason: 'pool rejected',
      ).status,
      PendingSubmittedTransactionStatus.poolRejected,
    );
    expect(
      submission(
        status: PendingSubmittedTransactionStatus.finalized,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        extrinsicIndex: 0,
      ).status,
      PendingSubmittedTransactionStatus.finalized,
    );
    expect(
      submission(
        status: PendingSubmittedTransactionStatus.failed,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        extrinsicIndex: 0,
        failure: runtimeFailure,
      ).status,
      PendingSubmittedTransactionStatus.failed,
    );

    final rejected = <PendingSubmittedTransaction Function()>[
      () => submission(anchorBlockHash: _hash(8)),
      () => submission(blockNumber: 8),
      () => submission(extrinsicIndex: 0),
      () => submission(failure: runtimeFailure),
      () => submission(failureReason: 'unexpected'),
      () => submission(status: PendingSubmittedTransactionStatus.inBlock),
      () => submission(
        status: PendingSubmittedTransactionStatus.inBlock,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.inBlock,
        anchorBlockHash: _hash(8),
        extrinsicIndex: 0,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.inBlock,
        anchorBlockHash: _hash(8),
        failure: runtimeFailure,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.inBlock,
        anchorBlockHash: _hash(8),
        failureReason: 'unexpected',
      ),
      () => submission(status: PendingSubmittedTransactionStatus.poolRejected),
      () => submission(
        status: PendingSubmittedTransactionStatus.poolRejected,
        failureReason: '   ',
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.poolRejected,
        failureReason: 'rejected',
        anchorBlockHash: _hash(8),
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.poolRejected,
        failureReason: 'rejected',
        blockNumber: 8,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.poolRejected,
        failureReason: 'rejected',
        extrinsicIndex: 0,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.poolRejected,
        failureReason: 'rejected',
        failure: runtimeFailure,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.finalized,
        blockNumber: 8,
        extrinsicIndex: 0,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.finalized,
        anchorBlockHash: _hash(8),
        extrinsicIndex: 0,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.finalized,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.finalized,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        extrinsicIndex: 0,
        failure: runtimeFailure,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.finalized,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        extrinsicIndex: 0,
        failureReason: 'unexpected',
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.failed,
        blockNumber: 8,
        extrinsicIndex: 0,
        failure: runtimeFailure,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.failed,
        anchorBlockHash: _hash(8),
        extrinsicIndex: 0,
        failure: runtimeFailure,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.failed,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        failure: runtimeFailure,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.failed,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        extrinsicIndex: 0,
      ),
      () => submission(
        status: PendingSubmittedTransactionStatus.failed,
        anchorBlockHash: _hash(8),
        blockNumber: 8,
        extrinsicIndex: 0,
        failure: runtimeFailure,
        failureReason: 'unexpected',
      ),
    ];
    for (final create in rejected) {
      expect(create, throwsFormatException);
    }
  });

  test('pending、明确 outcome、转账和 cursor 在一个 CAS 状态中提交', () async {
    final preferences = _MemoryPreferences();
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: preferences,
    );
    final history = FinalizedTransactionHistory(
      repository: repository,
      clock: () => DateTime.fromMillisecondsSinceEpoch(100),
    );
    await history.ensureCursors(accountIds: <String>[accountA], startBlock: 7);
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 3,
      toAccountId: accountB,
      amountFen: BigInt.from(55),
      remark: 'fixture',
    );
    final transfer = FinalizedAccountTransfer(
      recordKey: FinalizedAccountTransfer.eventRecordKey(accountB, _hash(8), 2),
      accountId: accountB,
      direction: FinalizedTransferDirection.incoming,
      fromAccountId: accountA,
      toAccountId: accountB,
      amountFen: BigInt.from(55),
      blockNumber: 8,
      blockHash: _hash(8),
      eventRecordIndex: 2,
      extrinsicIndex: 0,
      sourcePallet: 'OnchainTransaction',
      remark: 'fixture',
    );
    final submissionKey = PendingSubmittedTransaction.submitRecordKey(
      accountA,
      txHash,
    );

    await history.commitFinalizedBlock(
      blockNumber: 8,
      blockHash: _hash(8),
      transfers: <FinalizedAccountTransfer>[transfer],
      outcomes: <String, ChainExtrinsicOutcome>{
        submissionKey: const ChainExtrinsicOutcome.success(),
      },
      extrinsicIndexBySubmissionKey: <String, int>{submissionKey: 0},
      advanceCursorAccountIds: <String>[accountA],
    );

    final state = await repository.load();
    expect(state.cursors[accountA]!.lastSyncedBlock, 8);
    expect(state.transfers[transfer.recordKey], isNotNull);
    expect(
      state.submissions[submissionKey]!.status,
      PendingSubmittedTransactionStatus.finalized,
    );
    expect(state.submissions[submissionKey]!.extrinsicIndex, 0);
    expect(state.revision, 3);
  });

  test('poolRejected 与 runtime failed 是不同持久终态', () async {
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: _MemoryPreferences(),
    );
    final history = FinalizedTransactionHistory(repository: repository);
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 1,
      toAccountId: accountB,
      amountFen: BigInt.one,
      remark: '',
    );
    await history.markSubmissionInBlock(
      accountId: accountA,
      txHash: txHash,
      blockHash: _hash(8),
    );
    await history.markPoolRejected(
      accountId: accountA,
      txHash: txHash,
      reason: '交易被同 nonce 的另一笔交易替代',
    );

    final rejected = (await history.load()).submissions.values.single;
    expect(rejected.status, PendingSubmittedTransactionStatus.poolRejected);
    expect(rejected.failureReason, contains('nonce'));
    expect(rejected.anchorBlockHash, isNull);
    expect(rejected.blockNumber, isNull);
    expect(rejected.extrinsicIndex, isNull);
    expect(rejected.failure, isNull);

    final failedTx = _hash(0x12);
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: failedTx,
      usedNonce: 2,
      toAccountId: accountB,
      amountFen: BigInt.two,
      remark: '',
    );
    final failedKey = PendingSubmittedTransaction.submitRecordKey(
      accountA,
      failedTx,
    );
    await history.commitFinalizedBlock(
      blockNumber: 9,
      blockHash: _hash(9),
      transfers: const <FinalizedAccountTransfer>[],
      outcomes: <String, ChainExtrinsicOutcome>{
        failedKey: const ChainExtrinsicOutcome.failed(
          ChainExtrinsicFailure(
            dispatchErrorVariant: 3,
            moduleIndex: 4,
            errorIndex: 0,
            description: 'ZeroAmount',
          ),
        ),
      },
      extrinsicIndexBySubmissionKey: <String, int>{failedKey: 1},
      advanceCursorAccountIds: const <String>[],
    );
    final failed = (await history.load()).submissions[failedKey]!;
    expect(failed.status, PendingSubmittedTransactionStatus.failed);
    expect(failed.failure!.moduleIndex, 4);
    expect(failed.failureReason, isNull);
    expect(failed.blockNumber, 9);
  });

  test('finalized 链上 outcome 可覆盖 poolRejected，且成功和失败都保留精确事实', () async {
    Future<PendingSubmittedTransaction> settleRejected({
      required String settledTxHash,
      required ChainExtrinsicOutcome outcome,
      required int extrinsicIndex,
    }) async {
      final repository = PreferencesFinalizedTransactionRepository(
        preferences: _MemoryPreferences(),
      );
      final history = FinalizedTransactionHistory(repository: repository);
      await history.recordPendingSubmission(
        accountId: accountA,
        txHash: settledTxHash,
        usedNonce: extrinsicIndex,
        toAccountId: accountB,
        amountFen: BigInt.one,
        remark: '',
      );
      await history.markPoolRejected(
        accountId: accountA,
        txHash: settledTxHash,
        reason: '本地交易池拒绝',
      );
      final key = PendingSubmittedTransaction.submitRecordKey(
        accountA,
        settledTxHash,
      );
      await history.commitFinalizedBlock(
        blockNumber: 10,
        blockHash: _hash(10),
        transfers: const <FinalizedAccountTransfer>[],
        outcomes: <String, ChainExtrinsicOutcome>{key: outcome},
        extrinsicIndexBySubmissionKey: <String, int>{key: extrinsicIndex},
        advanceCursorAccountIds: const <String>[],
      );
      return (await history.load()).submissions[key]!;
    }

    final finalized = await settleRejected(
      settledTxHash: _hash(0x21),
      outcome: const ChainExtrinsicOutcome.success(),
      extrinsicIndex: 2,
    );
    expect(finalized.status, PendingSubmittedTransactionStatus.finalized);
    expect(finalized.anchorBlockHash, _hash(10));
    expect(finalized.blockNumber, 10);
    expect(finalized.extrinsicIndex, 2);
    expect(finalized.failure, isNull);
    expect(finalized.failureReason, isNull);

    final failed = await settleRejected(
      settledTxHash: _hash(0x22),
      outcome: const ChainExtrinsicOutcome.failed(runtimeFailure),
      extrinsicIndex: 3,
    );
    expect(failed.status, PendingSubmittedTransactionStatus.failed);
    expect(failed.anchorBlockHash, _hash(10));
    expect(failed.blockNumber, 10);
    expect(failed.extrinsicIndex, 3);
    expect(failed.failure!.description, 'ZeroAmount');
    expect(failed.failureReason, isNull);
  });

  test('commitFinalizedBlock 非法闭集输入不会推进 revision 或 cursor', () async {
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: _MemoryPreferences(),
    );
    final history = FinalizedTransactionHistory(repository: repository);
    await history.ensureCursors(accountIds: <String>[accountA], startBlock: 7);
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 3,
      toAccountId: accountB,
      amountFen: BigInt.one,
      remark: 'fixture',
    );
    final submissionKey = PendingSubmittedTransaction.submitRecordKey(
      accountA,
      txHash,
    );
    final unknownKey = PendingSubmittedTransaction.submitRecordKey(
      accountB,
      _hash(0x77),
    );

    Future<void> expectRejectedWithoutMutation({
      required int committedBlockNumber,
      required String committedBlockHash,
      required Iterable<FinalizedAccountTransfer> transfers,
      required Map<String, ChainExtrinsicOutcome> outcomes,
      required Map<String, int> indexes,
    }) async {
      final before = await history.load();
      await expectLater(
        history.commitFinalizedBlock(
          blockNumber: committedBlockNumber,
          blockHash: committedBlockHash,
          transfers: transfers,
          outcomes: outcomes,
          extrinsicIndexBySubmissionKey: indexes,
          advanceCursorAccountIds: <String>[accountA],
        ),
        throwsStateError,
      );
      final after = await history.load();
      expect(after.revision, before.revision);
      expect(
        after.cursors[accountA]!.lastSyncedBlock,
        before.cursors[accountA]!.lastSyncedBlock,
      );
      expect(after.transfers, hasLength(before.transfers.length));
      expect(
        after.submissions[submissionKey]!.status,
        before.submissions[submissionKey]!.status,
      );
    }

    await expectRejectedWithoutMutation(
      committedBlockNumber: 8,
      committedBlockHash: _hash(8),
      transfers: <FinalizedAccountTransfer>[accountTransfer(blockNumber: 9)],
      outcomes: const <String, ChainExtrinsicOutcome>{},
      indexes: const <String, int>{},
    );
    await expectRejectedWithoutMutation(
      committedBlockNumber: 8,
      committedBlockHash: _hash(8),
      transfers: <FinalizedAccountTransfer>[
        accountTransfer(blockHash: _hash(9)),
      ],
      outcomes: const <String, ChainExtrinsicOutcome>{},
      indexes: const <String, int>{},
    );
    await expectRejectedWithoutMutation(
      committedBlockNumber: 8,
      committedBlockHash: _hash(8),
      transfers: const <FinalizedAccountTransfer>[],
      outcomes: <String, ChainExtrinsicOutcome>{
        submissionKey: const ChainExtrinsicOutcome.success(),
      },
      indexes: const <String, int>{},
    );
    await expectRejectedWithoutMutation(
      committedBlockNumber: 8,
      committedBlockHash: _hash(8),
      transfers: const <FinalizedAccountTransfer>[],
      outcomes: <String, ChainExtrinsicOutcome>{
        submissionKey: const ChainExtrinsicOutcome.success(),
      },
      indexes: <String, int>{submissionKey: 0, unknownKey: 1},
    );
    await expectRejectedWithoutMutation(
      committedBlockNumber: 8,
      committedBlockHash: _hash(8),
      transfers: const <FinalizedAccountTransfer>[],
      outcomes: <String, ChainExtrinsicOutcome>{
        submissionKey: const ChainExtrinsicOutcome.success(),
      },
      indexes: <String, int>{submissionKey: -1},
    );
    await expectRejectedWithoutMutation(
      committedBlockNumber: 8,
      committedBlockHash: _hash(8),
      transfers: const <FinalizedAccountTransfer>[],
      outcomes: <String, ChainExtrinsicOutcome>{
        submissionKey: const ChainExtrinsicOutcome.failed(null),
      },
      indexes: <String, int>{submissionKey: 0},
    );
    await expectRejectedWithoutMutation(
      committedBlockNumber: 8,
      committedBlockHash: _hash(8),
      transfers: const <FinalizedAccountTransfer>[],
      outcomes: <String, ChainExtrinsicOutcome>{
        unknownKey: const ChainExtrinsicOutcome.success(),
      },
      indexes: <String, int>{unknownKey: 0},
    );

    final unchanged = await history.load();
    expect(unchanged.revision, 2);
    expect(unchanged.cursors[accountA]!.lastSyncedBlock, 7);
    expect(
      unchanged.submissions[submissionKey]!.status,
      PendingSubmittedTransactionStatus.pending,
    );
  });

  test('相同 finalized 终态幂等，不同块、index 或执行结果 fail closed', () async {
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: _MemoryPreferences(),
    );
    final history = FinalizedTransactionHistory(repository: repository);
    await history.ensureCursors(accountIds: <String>[accountA], startBlock: 7);
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 3,
      toAccountId: accountB,
      amountFen: BigInt.one,
      remark: '',
    );
    final key = PendingSubmittedTransaction.submitRecordKey(accountA, txHash);

    Future<void> settle({
      int blockNumber = 8,
      int index = 0,
      ChainExtrinsicOutcome outcome = const ChainExtrinsicOutcome.success(),
    }) => history.commitFinalizedBlock(
      blockNumber: blockNumber,
      blockHash: _hash(blockNumber),
      transfers: const <FinalizedAccountTransfer>[],
      outcomes: <String, ChainExtrinsicOutcome>{key: outcome},
      extrinsicIndexBySubmissionKey: <String, int>{key: index},
      advanceCursorAccountIds: <String>[accountA],
    );

    await settle();
    final committed = await history.load();
    await settle();
    expect((await history.load()).revision, committed.revision);

    await expectLater(settle(index: 1), throwsStateError);
    await expectLater(settle(blockNumber: 9), throwsStateError);
    await expectLater(
      settle(outcome: const ChainExtrinsicOutcome.failed(runtimeFailure)),
      throwsStateError,
    );
    final unchanged = await history.load();
    expect(unchanged.revision, committed.revision);
    expect(unchanged.cursors[accountA]!.lastSyncedBlock, 8);
    expect(
      unchanged.submissions[key]!.status,
      PendingSubmittedTransactionStatus.finalized,
    );
  });

  test('写入后抛错但完整事实已落盘时按成功回读收敛', () async {
    final preferences = _MemoryPreferences()..throwAfterWrite = true;
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: preferences,
    );

    final committed = await repository.commit(
      expectedRevision: 0,
      cursors: <String, TransactionSyncCursor>{
        accountA: TransactionSyncCursor(
          accountId: accountA,
          trackingStartBlock: 4,
          lastSyncedBlock: 4,
        ),
      },
      transfers: const <String, FinalizedAccountTransfer>{},
      submissions: const <String, PendingSubmittedTransaction>{},
    );

    expect(committed.revision, 1);
    expect((await repository.load()).cursors, contains(accountA));
  });

  test('真实未写入错误阻止广播前 pending 被确认', () async {
    final preferences = _MemoryPreferences()..throwWithoutWrite = true;
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: preferences,
    );
    final history = FinalizedTransactionHistory(repository: repository);

    await expectLater(
      history.recordPendingSubmission(
        accountId: accountA,
        txHash: txHash,
        usedNonce: 1,
        toAccountId: accountB,
        amountFen: BigInt.one,
        remark: '',
      ),
      throwsStateError,
    );
    expect((await repository.load()).submissions, isEmpty);
  });

  test('revision 冲突与畸形 schema 均 fail closed', () async {
    final preferences = _MemoryPreferences();
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: preferences,
    );
    await repository.commit(
      expectedRevision: 0,
      cursors: const <String, TransactionSyncCursor>{},
      transfers: const <String, FinalizedAccountTransfer>{},
      submissions: const <String, PendingSubmittedTransaction>{},
    );
    await expectLater(
      repository.commit(
        expectedRevision: 0,
        cursors: const <String, TransactionSyncCursor>{},
        transfers: const <String, FinalizedAccountTransfer>{},
        submissions: const <String, PendingSubmittedTransaction>{},
      ),
      throwsA(isA<FinalizedTransactionRepositoryConflict>()),
    );

    final decoded =
        jsonDecode(
              preferences.values[PreferencesFinalizedTransactionRepository
                  .storageKey]!,
            )
            as Map<String, dynamic>;
    decoded['unexpected'] = true;
    preferences.values[PreferencesFinalizedTransactionRepository.storageKey] =
        jsonEncode(decoded);
    await expectLater(repository.load(), throwsFormatException);
  });

  test('持久 JSON 对哈希、来源、index 和 pending 字段闭集 fail closed', () async {
    final preferences = _MemoryPreferences();
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: preferences,
    );
    final history = FinalizedTransactionHistory(repository: repository);
    await history.ensureCursors(accountIds: <String>[accountA], startBlock: 7);
    await history.recordPendingSubmission(
      accountId: accountA,
      txHash: txHash,
      usedNonce: 3,
      toAccountId: accountB,
      amountFen: BigInt.one,
      remark: 'fixture',
    );
    await history.commitFinalizedBlock(
      blockNumber: 8,
      blockHash: _hash(8),
      transfers: <FinalizedAccountTransfer>[accountTransfer()],
      outcomes: const <String, ChainExtrinsicOutcome>{},
      extrinsicIndexBySubmissionKey: const <String, int>{},
      advanceCursorAccountIds: <String>[accountA],
    );
    final baseline = preferences
        .values[PreferencesFinalizedTransactionRepository.storageKey]!;

    Map<String, dynamic> firstTransfer(Map<String, dynamic> root) =>
        (root['transfers']! as List<dynamic>).single as Map<String, dynamic>;
    Map<String, dynamic> firstSubmission(Map<String, dynamic> root) =>
        (root['submissions']! as List<dynamic>).single as Map<String, dynamic>;

    final corruptions = <(String, void Function(Map<String, dynamic>))>[
      (
        'block hash 缺少 0x',
        (root) {
          final transfer = firstTransfer(root);
          transfer['block_hash'] = (transfer['block_hash']! as String)
              .substring(2);
        },
      ),
      (
        'tx hash 含大写',
        (root) {
          final pending = firstSubmission(root);
          pending['tx_hash'] = (pending['tx_hash']! as String).toUpperCase();
        },
      ),
      (
        '未知 source pallet',
        (root) => firstTransfer(root)['source_pallet'] = 'System',
      ),
      (
        'Balances 带 remark',
        (root) => firstTransfer(root)['source_pallet'] = 'Balances',
      ),
      (
        '负 extrinsic index',
        (root) => firstTransfer(root)['extrinsic_index'] = -1,
      ),
      (
        '已删除的先前 pending 状态',
        (root) => firstSubmission(root)['status'] = 'nonceConsumedUnverified',
      ),
      (
        'pending 携带块锚',
        (root) => firstSubmission(root)['anchor_block_hash'] = _hash(8),
      ),
      (
        'inBlock 携带 finalized 区块号',
        (root) {
          final pending = firstSubmission(root);
          pending['status'] = 'inBlock';
          pending['anchor_block_hash'] = _hash(8);
          pending['block_number'] = 8;
        },
      ),
      (
        'poolRejected 残留块锚',
        (root) {
          final pending = firstSubmission(root);
          pending['status'] = 'poolRejected';
          pending['failure_reason'] = 'rejected';
          pending['anchor_block_hash'] = _hash(8);
        },
      ),
      (
        'finalized 缺少块锚/index',
        (root) => firstSubmission(root)['status'] = 'finalized',
      ),
      (
        'failed 缺少 runtime failure',
        (root) {
          final pending = firstSubmission(root);
          pending['status'] = 'failed';
          pending['anchor_block_hash'] = _hash(8);
          pending['block_number'] = 8;
          pending['extrinsic_index'] = 0;
        },
      ),
    ];

    for (final corruption in corruptions) {
      final decoded = jsonDecode(baseline) as Map<String, dynamic>;
      corruption.$2(decoded);
      preferences.values[PreferencesFinalizedTransactionRepository.storageKey] =
          jsonEncode(decoded);
      await expectLater(
        repository.load(),
        throwsFormatException,
        reason: corruption.$1,
      );
    }
  });

  test('重复 finalized event 幂等，不同事实复用同 key 必须拒绝', () async {
    final repository = PreferencesFinalizedTransactionRepository(
      preferences: _MemoryPreferences(),
    );
    final history = FinalizedTransactionHistory(repository: repository);
    await history.ensureCursors(accountIds: <String>[accountA], startBlock: 1);
    final key = FinalizedAccountTransfer.eventRecordKey(accountA, _hash(2), 0);
    FinalizedAccountTransfer transfer(BigInt amount) =>
        FinalizedAccountTransfer(
          recordKey: key,
          accountId: accountA,
          direction: FinalizedTransferDirection.outgoing,
          fromAccountId: accountA,
          toAccountId: accountB,
          amountFen: amount,
          blockNumber: 2,
          blockHash: _hash(2),
          eventRecordIndex: 0,
          extrinsicIndex: 0,
          sourcePallet: 'Balances',
        );
    Future<void> commit(FinalizedAccountTransfer value) =>
        history.commitFinalizedBlock(
          blockNumber: 2,
          blockHash: _hash(2),
          transfers: <FinalizedAccountTransfer>[value],
          outcomes: const <String, ChainExtrinsicOutcome>{},
          extrinsicIndexBySubmissionKey: const <String, int>{},
          advanceCursorAccountIds: <String>[accountA],
        );

    await commit(transfer(BigInt.one));
    await commit(transfer(BigInt.one));
    expect((await history.load()).transfers, hasLength(1));
    await expectLater(commit(transfer(BigInt.two)), throwsStateError);
  });
}

final class _MemoryPreferences implements PreferencesDataStore {
  final Map<String, String> values = <String, String>{};
  bool throwAfterWrite = false;
  bool throwWithoutWrite = false;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (throwWithoutWrite) throw StateError('write rejected');
    values[key] = value;
    if (throwAfterWrite) throw StateError('late platform error');
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

String _account(int byte) => _hash(byte);

String _hash(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';
