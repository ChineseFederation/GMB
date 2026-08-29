import 'package:meta/meta.dart';

enum WalletOrigin { created, imported }

/// 一只热钱包下的公开账户资料，不包含任何私钥材料。
@immutable
final class WalletAccount {
  const WalletAccount({
    required this.index,
    required this.accountId,
    required this.secretOwner,
    required this.ss58Address,
    required this.name,
    required this.createdAtMillis,
  });

  final int index;
  final String accountId;

  /// 账户秘密槽的不可复用 128 位所有权标识。
  final String secretOwner;
  final String ss58Address;
  final String name;
  final int createdAtMillis;

  String get derivationPath => '//$index';
}

/// CitizenSDK 单热钱包、多账户公开视图。
@immutable
final class WalletProfile {
  WalletProfile({
    required this.walletIndex,
    required this.walletGeneration,
    required this.masterAccountId,
    required this.origin,
    required this.createdAtMillis,
    required this.activeAccountId,
    required List<WalletAccount> accounts,
  }) : accounts = List<WalletAccount>.unmodifiable(accounts);

  final int walletIndex;

  /// 本次钱包生命周期独占的 128 位硬件 KEK generation。
  final String walletGeneration;
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
    walletGeneration: walletGeneration,
    masterAccountId: masterAccountId,
    origin: origin,
    createdAtMillis: createdAtMillis,
    activeAccountId: activeAccountId ?? this.activeAccountId,
    accounts: List<WalletAccount>.unmodifiable(accounts ?? this.accounts),
  );
}

/// 硬件金库中一个账户秘密的精确、不可复用身份。
@immutable
final class WalletSecretRef {
  const WalletSecretRef({
    required this.walletGeneration,
    required this.secretOwner,
    required this.accountId,
  });

  final String walletGeneration;
  final String secretOwner;
  final String accountId;
}

/// 在任何秘密写入前持久化的钱包 provision 所有权。
///
/// [previousProfile] 是失败或崩溃恢复时唯一允许恢复的公开事实；
/// [secretRefs] 是本操作可能写入的完整、精确秘密集合。另一个执行者只有先
/// 通过仓储 CAS 把本计划转换成同 owner 的 [WalletCleanupPlan]，才允许删除。
@immutable
final class WalletProvisioningPlan {
  WalletProvisioningPlan({
    required this.operationId,
    required this.walletIndex,
    required this.walletGeneration,
    required this.previousProfile,
    required List<WalletSecretRef> secretRefs,
    required this.deleteWalletKeyOnRollback,
  }) : secretRefs = List<WalletSecretRef>.unmodifiable(secretRefs);

  final String operationId;
  final int walletIndex;
  final String walletGeneration;
  final WalletProfile? previousProfile;
  final List<WalletSecretRef> secretRefs;
  final bool deleteWalletKeyOnRollback;
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
  WalletCleanupPlan({
    required this.operationId,
    required this.walletIndex,
    required this.walletGeneration,
    required List<WalletSecretRef> secretRefs,
    required this.deleteWalletKey,
  }) : secretRefs = List<WalletSecretRef>.unmodifiable(secretRefs);

  final String operationId;
  final int walletIndex;
  final String walletGeneration;
  final List<WalletSecretRef> secretRefs;
  final bool deleteWalletKey;
}

/// 钱包公开事实的原子仓储状态。
///
/// [cleanup] 是当前串行清理计划；[cleanupQueue] 保留与当前
/// profile/provisioning 物理目标不相交的精确补偿计划。
@immutable
final class WalletState {
  WalletState({
    required this.revision,
    required this.profile,
    required this.provisioning,
    required this.cleanup,
    required List<WalletCleanupPlan> cleanupQueue,
  }) : cleanupQueue = List<WalletCleanupPlan>.unmodifiable(cleanupQueue);

  const WalletState.empty()
    : revision = 0,
      profile = null,
      provisioning = null,
      cleanup = null,
      cleanupQueue = const <WalletCleanupPlan>[];

  final int revision;
  final WalletProfile? profile;
  final WalletProvisioningPlan? provisioning;
  final WalletCleanupPlan? cleanup;
  final List<WalletCleanupPlan> cleanupQueue;
}
