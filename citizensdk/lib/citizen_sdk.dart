// ignore: unnecessary_library_name -- 保留已发布入口的稳定库标识。
library citizen_sdk;

import 'src/crypto/citizen_signer.dart';
import 'src/node/bootstrap_client.dart';
import 'src/node/chain_assets.dart';
import 'src/node/chain_database_store.dart';
import 'src/node/chain_event_subscription.dart';
import 'src/node/light_client.dart';
import 'src/node/sdk_log.dart';
import 'src/platform/mobile_citizen_sdk.dart';
import 'src/transaction/chain_rpc.dart';
import 'src/transaction/finalized_transaction_repository.dart';
import 'src/transaction/finalized_transaction_scanner.dart';
import 'src/transaction/transfer_service.dart';
import 'src/wallet/secure_seed_store.dart';
import 'src/wallet/wallet_repository.dart';
import 'src/wallet/wallet_service.dart';

export 'src/crypto/account_codec.dart';
export 'src/crypto/citizen_signer.dart';
export 'src/node/bootstrap_client.dart';
export 'src/node/bootstrap_manifest.dart';
export 'src/node/chain_assets.dart';
export 'src/node/chain_database_store.dart';
export 'src/node/chain_event_subscription.dart';
export 'src/node/chain_health.dart';
export 'src/node/light_client.dart';
export 'src/node/sdk_log.dart';
export 'src/platform/hardware_bound_seed_store.dart';
export 'src/platform/hardware_secret_vault.dart';
export 'src/platform/mobile_citizen_sdk.dart';
export 'src/platform/preferences_chain_database_store.dart';
export 'src/platform/preferences_data_store.dart';
export 'src/platform/preferences_finalized_transaction_repository.dart';
export 'src/platform/preferences_wallet_repository.dart';
export 'src/platform/secure_blob_store.dart';
export 'src/transaction/chain_rpc.dart';
export 'src/transaction/chain_transfer_event_decoder.dart';
export 'src/transaction/finalized_transaction_models.dart';
export 'src/transaction/finalized_transaction_repository.dart';
export 'src/transaction/finalized_transaction_scanner.dart';
export 'src/transaction/signed_extrinsic_builder.dart';
export 'src/transaction/transaction_status.dart';
export 'src/transaction/transfer_service.dart';
export 'src/wallet/models.dart';
export 'src/wallet/secure_seed_store.dart';
export 'src/wallet/wallet_error.dart';
export 'src/wallet/wallet_repository.dart';
export 'src/wallet/wallet_service.dart';

/// CitizenSDK 单产品公共门面。
///
/// [chain] 是公民链轻节点，[wallet] 是本地无根热钱包，[transfers] 构造并提交公民链
/// 转账，[signer] 提供公钥验签。TUYU 等上层协议通过 [wallet] 的任意载荷签名入口复用
/// 同一账户私钥，但协议编码不进入 SDK。
final class CitizenSdk {
  CitizenSdk({
    required WalletRepository walletRepository,
    required SecureSeedStore secureSeedStore,
    CitizenLightClient? lightClient,
    CitizenChainAssets chainAssets = const CitizenChainAssets(),
    BootstrapClient? bootstrapClient,
    ChainDatabaseStore? chainDatabaseStore,
    FinalizedTransactionRepository? transactionRepository,
    FinalizedBlockHeadSource? transactionHeadSource,
    CitizenSdkLogger logger = discardCitizenSdkLog,
    int nativeLogLevel = 1,
  }) {
    chain =
        lightClient ??
        CitizenLightClient(
          assets: chainAssets,
          bootstrapClient: bootstrapClient,
          databaseStore: chainDatabaseStore,
          logger: logger,
          maxLogLevel: nativeLogLevel,
        );
    rpc = ChainRpc(chain);
    wallet = WalletService(
      repository: walletRepository,
      seedStore: secureSeedStore,
    );
    if (transactionRepository != null) {
      transactionHistory = FinalizedTransactionHistory(
        repository: transactionRepository,
      );
      transactionScanner = FinalizedTransactionScanner(
        rpc: rpc,
        history: transactionHistory!,
        headSource:
            transactionHeadSource ??
            ChainEventFinalizedBlockHeadSource(
              ChainEventSubscription(lightClient: chain, logger: logger),
            ),
        logger: logger,
      );
    } else {
      transactionHistory = null;
      transactionScanner = null;
    }
    transfers = TransferService(rpc, transactionHistory: transactionHistory);
  }

  /// Creates the standard Android/iOS SDK assembly.
  ///
  /// Native hardware-vault support is intentionally not claimed for desktop
  /// platforms in this release. Pass [components] to replace persistence in a
  /// test or a future independently reviewed platform port.
  factory CitizenSdk.mobile({
    MobileCitizenSdkComponents? components,
    CitizenLightClient? lightClient,
    CitizenChainAssets chainAssets = const CitizenChainAssets(),
    BootstrapClient? bootstrapClient,
    CitizenSdkLogger logger = discardCitizenSdkLog,
    int nativeLogLevel = 1,
  }) {
    final mobile = components ?? MobileCitizenSdkComponents.standard();
    return CitizenSdk(
      walletRepository: mobile.walletRepository,
      secureSeedStore: mobile.secureSeedStore,
      lightClient: lightClient,
      chainAssets: chainAssets,
      bootstrapClient: bootstrapClient,
      chainDatabaseStore: mobile.chainDatabaseStore,
      transactionRepository: mobile.transactionRepository,
      logger: logger,
      nativeLogLevel: nativeLogLevel,
    );
  }

  late final CitizenLightClient chain;
  late final ChainRpc rpc;
  late final WalletService wallet;
  late final TransferService transfers;
  late final FinalizedTransactionHistory? transactionHistory;
  late final FinalizedTransactionScanner? transactionScanner;
  final CitizenSigner signer = const CitizenSigner();

  Future<void> start({bool waitUntilSynced = false}) async {
    await chain.ensureStarted();
    if (waitUntilSynced) await chain.waitUntilSynced();
  }

  /// 以当前钱包完整账户快照启动 finalized 交易流水扫描。
  ///
  /// 钱包创建、导入、增删账户后再次调用即可原子替换监控集合；新账户从调用时的
  /// finalized 高度开始，已有账户从持久游标补缺口。未装配 transaction repository
  /// 的自定义 SDK 返回 false。
  Future<bool> syncWalletTransactionHistory() async {
    final scanner = transactionScanner;
    if (scanner == null) return false;
    final profile = await wallet.profile;
    await scanner.replaceWatchedAccounts(
      profile?.accounts.map((account) => account.accountId) ?? const <String>[],
    );
    if (profile == null || profile.accounts.isEmpty) return true;
    await scanner.start();
    return true;
  }

  Future<void> dispose() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await transactionScanner?.stop();
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await chain.dispose();
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
