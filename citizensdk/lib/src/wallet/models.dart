import 'package:meta/meta.dart';

enum WalletOrigin { created, imported }

/// 一只热钱包下的公开账户资料，不包含任何私钥材料。
@immutable
final class WalletAccount {
  const WalletAccount({
    required this.index,
    required this.accountId,
    required this.ss58Address,
    required this.name,
    required this.createdAtMillis,
  });

  final int index;
  final String accountId;
  final String ss58Address;
  final String name;
  final int createdAtMillis;

  String get derivationPath => '//$index';
}

/// CitizenSDK 单热钱包、多账户公开视图。
@immutable
final class WalletProfile {
  const WalletProfile({
    required this.walletIndex,
    required this.masterAccountId,
    required this.origin,
    required this.createdAtMillis,
    required this.activeAccountId,
    required this.accounts,
  });

  final int walletIndex;
  final String masterAccountId;
  final WalletOrigin origin;
  final int createdAtMillis;
  final String activeAccountId;
  final List<WalletAccount> accounts;

  WalletAccount? accountById(String accountId) {
    for (final account in accounts) {
      if (account.accountId == accountId) return account;
    }
    return null;
  }

  WalletProfile copyWith({
    String? activeAccountId,
    List<WalletAccount>? accounts,
  }) => WalletProfile(
    walletIndex: walletIndex,
    masterAccountId: masterAccountId,
    origin: origin,
    createdAtMillis: createdAtMillis,
    activeAccountId: activeAccountId ?? this.activeAccountId,
    accounts: List<WalletAccount>.unmodifiable(accounts ?? this.accounts),
  );
}

/// 创建钱包时一次性返回的助记词；SDK 不持久化该字符串。
@immutable
final class WalletCreationResult {
  const WalletCreationResult({required this.profile, required this.mnemonic});

  final WalletProfile profile;
  final String mnemonic;
}

/// 公开事实提交后仍需在硬件金库执行的可恢复清理计划。
@immutable
final class WalletCleanupPlan {
  const WalletCleanupPlan({
    required this.walletIndex,
    required this.accountIds,
    required this.deleteWalletKey,
  });

  final int walletIndex;
  final List<String> accountIds;
  final bool deleteWalletKey;
}

/// 钱包公开事实的原子仓储状态。
@immutable
final class WalletState {
  const WalletState({
    required this.revision,
    required this.profile,
    required this.cleanup,
  });

  const WalletState.empty() : revision = 0, profile = null, cleanup = null;

  final int revision;
  final WalletProfile? profile;
  final WalletCleanupPlan? cleanup;
}
