import '../models/citizen_transaction.dart';

/// CitizenSDK 高层公民链转账与 finalized 历史接口。
///
/// 交易构造、sr25519 签名、pending-before-broadcast、提交、监听和 Runtime 终态核验全部由
/// Rust Core 完成；Dart 不接收已签名 extrinsic。
abstract interface class CitizenTransactions {
  Future<CitizenWalletTransfer> transferWithRemark({
    required String sourceAccountId,
    required String destinationAccountId,
    required BigInt amountFen,
    String remark = '',
  });

  Future<CitizenTransactionHistory> initializeFinalizedHistory(
    List<String> accountIds,
  );

  Future<CitizenTransactionHistory> syncFinalizedHistory(
    List<String> accountIds,
  );
}
