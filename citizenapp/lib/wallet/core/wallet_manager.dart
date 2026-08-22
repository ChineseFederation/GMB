import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:isar_community/isar.dart';
// 仅用于 SS58 地址编解码(base58 + 校验和，非密码学)，与全 app 其它调用点一致；
// sr25519 派生/签名/验签一律走原生 [NativeSr25519]，本文件零纯 Dart 密码学。
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:gmb_wallet_password/wallet_mini_secret.dart';
import 'package:gmb_wallet_password/wallet_password.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/log/app_log.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/signer/signing.dart';
import 'package:citizenapp/wallet/core/device_data_key_vault.dart';
import 'package:citizenapp/wallet/core/native_sr25519.dart';
import 'package:citizenapp/wallet/core/device_subkey.dart';
import 'package:citizenapp/wallet/core/hardware_bound_seed_vault.dart';
import 'package:citizenapp/wallet/core/secure_seed_store.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';

class WalletProfile {
  const WalletProfile({
    required this.walletIndex,
    required this.walletName,
    required this.walletIcon,
    required this.balance,
    required this.accountId,
    required this.ss58Address,
    required this.alg,
    required this.ss58,
    required this.createdAtMillis,
    required this.source,
    required this.signMode,
  });

  final int walletIndex;
  final String walletName;
  final String walletIcon;
  final double balance;
  final String accountId;
  final String ss58Address;
  final String alg;
  final int ss58;
  final int createdAtMillis;
  final String source;

  /// 钱包账户签名模式；`null` 只表示持久化值非法，任何签名入口都必须拒绝。
  final SignMode? signMode;

  bool get isHotWallet => signMode == SignMode.hot;
  bool get isColdWallet => signMode == SignMode.cold;

  /// 返回两种合法模式之一；持久化值缺失或非法时立即拒绝，禁止被调用方的 `else`
  /// 分支误当成冷钱包。
  SignMode get requiredSignMode {
    final mode = signMode;
    if (mode == null) {
      throw const WalletAuthException('钱包账户签名模式无效');
    }
    return mode;
  }

  /// 钱包账户签名分流的布尔门禁。返回 `false` 只可能代表 [SignMode.cold]；非法
  /// 模式会先抛错，调用方后续的冷签分支不能接收第三种状态。
  bool get requiresHotSign => switch (requiredSignMode) {
        SignMode.hot => true,
        SignMode.cold => false,
      };
}

/// 一只钱包(masterId)下的一个账户(`//index`,含账户0 = `//0`)。
///
/// 无根多账户模型的公开视图:只含身份字段,不含任何私钥材料。签名 / 导私钥须回
/// [WalletManager.signForAccountId] / [WalletManager.getAccountPrivateKey],经硬件金库
/// 按 accountId 读回该账户的 child(触发生物识别)。
class Account {
  const Account({
    required this.masterId,
    required this.accountIndex,
    required this.accountId,
    required this.ss58Address,
    required this.accountName,
  });

  final String masterId;
  final int accountIndex;
  final String accountId;
  final String ss58Address;
  final String accountName;

  /// 展示用派生路径:`//index`(账户0 = `//0`)。
  String get derivationPath => '//$accountIndex';
}

class WalletCreationResult {
  const WalletCreationResult({required this.profile, required this.mnemonic});

  final WalletProfile profile;

  /// 助记词仅在创建时一次性展示，不会持久化。
  final String mnemonic;
}

/// 删除事实提交后仍需完成的本机清理计划。
///
/// 计划与钱包/账户删除事实在同一个 Isar 事务内持久化。即使进程在安全存储或清算行
/// 缓存清理前退出，新 [WalletManager] 仍能按精确 walletIndex、账户集合和清理能力
/// 继续执行。冷钱包没有 child/钱包硬件钥，两项能力都必须为 false，不能虚构热钱包
/// 清理动作。
class WalletCleanupPlan {
  WalletCleanupPlan({
    required this.planId,
    required this.walletIndex,
    required Set<String> accountIds,
    required this.deleteAccountKeys,
    required this.deleteWalletWideKeys,
  }) : accountIds = Set<String>.unmodifiable(accountIds);

  final String planId;

  /// 钱包事实内的稳定索引。只有修复损坏事实时无法定位归属才允许为 null；此时两类
  /// walletIndex 作用域清理能力必须同时关闭。
  final int? walletIndex;
  final Set<String> accountIds;
  final bool deleteAccountKeys;
  final bool deleteWalletWideKeys;

  Map<String, Object?> _toJson() => <String, Object?>{
        'plan_id': planId,
        'wallet_index': walletIndex,
        'account_ids': accountIds.toList(growable: false)..sort(),
        'delete_account_keys': deleteAccountKeys,
        'delete_wallet_wide_keys': deleteWalletWideKeys,
      };

  bool _sameFacts(WalletCleanupPlan other) {
    return planId == other.planId &&
        walletIndex == other.walletIndex &&
        deleteAccountKeys == other.deleteAccountKeys &&
        deleteWalletWideKeys == other.deleteWalletWideKeys &&
        setEquals(accountIds, other.accountIds);
  }
}

/// 钱包/账户删除事务的确定结果。
///
/// [cleanupPlans] 只来自删除写事务内的真实事实，并与删除本身同一事务提交；页面不得
/// 再用删除前快照或一次可能失败的 reload 推算清理目标。
class WalletDeletionResult {
  WalletDeletionResult({
    required this.factCommitted,
    required List<WalletCleanupPlan> cleanupPlans,
  }) : cleanupPlans = List<WalletCleanupPlan>.unmodifiable(cleanupPlans);

  final bool factCommitted;
  final List<WalletCleanupPlan> cleanupPlans;

  Set<String> get deletedAccountIds => Set<String>.unmodifiable(
        cleanupPlans.expand((plan) => plan.accountIds),
      );
}

class WalletAuthException implements Exception {
  const WalletAuthException(this.message);
  final String message;

  @override
  String toString() => 'WalletAuthException: $message';
}

/// AccountId 与本机现有钱包事实冲突的分类。
enum WalletAccountConflictKind {
  existingHotAccount,
  existingColdWallet,
  pendingLocalCleanup,
  corruptWalletData,
}

/// 冷热钱包唯一性冲突；[toString] 只返回可直接展示的中文文案，不泄露数据库细节。
class WalletAccountConflictException implements Exception {
  const WalletAccountConflictException(this.kind, this.message);

  final WalletAccountConflictKind kind;
  final String message;

  @override
  String toString() => message;
}

/// 钱包事实数据已经删除，但一个或多个本机安全存储条目清理失败。
///
/// 删除流程不会因首个 Keystore / Secure Enclave / Keychain 错误而停止；全部密钥都尝试
/// 删除后统一报告，避免某个账户 child 清理失败导致钱包 KEK 或 P-256 设备子钥被跳过。
class WalletLocalCleanupException implements Exception {
  const WalletLocalCleanupException(
    this.failures, {
    this.deletionResult,
  });

  final List<String> failures;
  final WalletDeletionResult? deletionResult;

  @override
  String toString() => '钱包已删除，但本机安全存储清理未完成：${failures.join('；')}';
}

/// 通讯录专用密钥材料。
///
/// 日常读取优先来自已有设备数据钥金库；实际解密发现缺钥时可鉴权一次生成；正式 CID
/// 换绑交接才允许从旧、新绑定账户 child 派生。业务层不能借此签名、恢复钱包或
/// 推导其他用途的子钥。
class ContactKeyMaterial {
  const ContactKeyMaterial({
    required this.encryptionKey,
    required this.indexKey,
  });

  final Uint8List encryptionKey;
  final Uint8List indexKey;

  /// 通讯录操作结束后立即清零两把用途子钥，避免等待 GC 才释放当前账户材料。
  void dispose() {
    encryptionKey.fillRange(0, encryptionKey.length, 0);
    indexKey.fillRange(0, indexKey.length, 0);
  }
}

/// 注册 P-256 设备子钥的钩子：给定当前 CID 绑定三元组与一个对绑定消息做当前账户
/// sr25519 签名的闭包（返回 `0x` hex）。由 app 启动注入实现，避免 wallet/core
/// 反向依赖 8964 层。只允许由实际会话收到 Worker 的 `device_not_registered`
/// 后调用；CID finalized、页面门禁与后台预热禁止调用。
typedef WalletSubkeyRegistrar = Future<void> Function({
  required String cidNumber,
  required int bindingRevision,
  required String accountId,
  required Future<String> Function({
    required Uint8List payload,
    required Uint8List signingMessage,
    required String devicePublicKey,
    required int issuedAtMillis,
  }) signBinding,
});

/// 冷账户在 CitizenWallet 上签署设备绑定 0x1C 摘要的前台回调。
typedef WalletColdDeviceBindingSigner = Future<String> Function({
  required AccountDataBinding binding,
  required Uint8List payload,
  required Uint8List signingMessage,
  required String devicePublicKey,
  required int issuedAtMillis,
});

/// 冷账户通过 CitizenWallet 为当前 CID 绑定版本提供指定用途钥的前台回调。
/// 返回顺序必须与 [requests] 完全一致；WalletManager 会逐把封入本机硬件金库。
typedef WalletColdAccountDataKeyProvider = Future<List<Uint8List>> Function({
  required AccountDataBinding binding,
  required List<({LocalKeyPurpose purpose, String? context})> requests,
});

/// 账户用途钥派生函数签名。生产始终使用 [AccountDataKeyDeriver.derive]；测试只注入
/// 可控失败点，以验证批量派生的已返回明文在后续用途失败时会被立即清零。
typedef WalletAccountDataKeyDeriver = Future<Uint8List> Function({
  required List<int> accountSecret,
  required AccountDataBinding binding,
  required LocalKeyPurpose purpose,
  String? context,
});

class WalletManager {
  /// 账户派生序号上界(`//index` 的 index 最大值)。账户0 为锚点主账户,
  /// 追加账户序号取 `1.._maxAccountIndex`。与 citizenwallet 冷端同源。
  static const int _maxAccountIndex = 1989;

  /// [_maxAccountIndex] 的公开只读别名，供 UI 展示 / 校验「指定序号」范围时单源引用，
  /// 避免把上界魔法数抄进界面层。
  static const int maxAccountIndex = _maxAccountIndex;

  /// 钱包身份数据版本号：钱包增删、默认账户排序、改名，以及 **CID 占号 / 换绑改变
  /// 「身份账户」绑定**后自增。
  ///
  /// 身份主键 = CID 号,其落点(CID 绑定的钱包账户)是链上派生而非本地存储字段,
  /// 占号/换绑写完没有任何本地广播。常驻页面（我的 tab、广场首页、Chat 会话列表、
  /// 身份页）监听此版本号,在身份账户变化后立即重读身份,避免「UI 显示旧身份、
  /// 动作以新身份执行」的分叉。余额刷新是高频操作且不影响身份,不计入此版本号。
  static final ValueNotifier<int> walletsRevision = ValueNotifier<int>(0);

  /// 正在进行的钱包事实变更层数。创建、导入和追加账户都包含“Isar 事实 + 硬件
  /// 存储 + 失败回滚”多个异步阶段；只看一次提交后的 revision 会把中间态误当成
  /// 稳定快照。深度计数允许内部流程安全嵌套，最外层和内层都不会提前解除门禁。
  static int _walletFactsMutationDepth = 0;
  static Completer<void>? _walletFactsMutationSettled;

  /// 页面一致快照只允许在该门禁关闭时提交。
  static bool get walletFactsMutationActive => _walletFactsMutationDepth > 0;

  /// 测试只读暴露嵌套深度，用来证明失败回滚后不会遗留永久门禁。
  @visibleForTesting
  static int get walletFactsMutationDepth => _walletFactsMutationDepth;

  /// 当前事实变更全部退出后完成；无变更时立即完成。
  ///
  /// 页面不能在 gate active 时同步烧完重试次数并永久停在旧快照；等待本信号后再按
  /// revision 有界连读。新 mutation 若紧接着开始，调用方下一轮仍会再次等待。
  static Future<void> waitForWalletFactsMutationToSettle() {
    if (_walletFactsMutationDepth == 0) return Future<void>.value();
    return _walletFactsMutationSettled!.future;
  }

  static void _bumpWalletsRevision() {
    walletsRevision.value++;
  }

  /// 覆盖一整段钱包事实变更。begin/end 都推进 revision：即使 Isar 已写而硬件钥
  /// 仍在等待，读者也会看到版本变化；无论成功、失败还是回滚异常，finally 都会
  /// 解除本层门禁并再次广播最终事实。
  static Future<T> runWalletFactsMutation<T>(
    Future<T> Function() action,
  ) async {
    if (_walletFactsMutationDepth == 0) {
      _walletFactsMutationSettled = Completer<void>();
    }
    _walletFactsMutationDepth += 1;
    try {
      _bumpWalletsRevision();
      return await action();
    } finally {
      _walletFactsMutationDepth -= 1;
      _bumpWalletsRevision();
      if (_walletFactsMutationDepth == 0) {
        final settled = _walletFactsMutationSettled;
        _walletFactsMutationSettled = null;
        if (settled != null && !settled.isCompleted) settled.complete();
      }
    }
  }

  Future<T> _runWalletFactsMutation<T>(Future<T> Function() action) =>
      WalletManager.runWalletFactsMutation(action);

  /// CID 占号 / 换绑改变了「身份账户」绑定(钱包列表没变,但身份主键的落点变了)。
  /// 复用同一身份版本号广播,避免第二套通知机制;常驻页据此重读身份。
  static void notifyIdentityBindingChanged() => _bumpWalletsRevision();

  /// 默认账户顺序已经原子提交。常驻页面必须据此重读当前用户；该通知只表示本机
  /// 用户切换，不修改 CID 绑定，也不得触发换绑交接。
  static void notifyDefaultAccountChanged() => _bumpWalletsRevision();

  /// 账户 child mini-secret 的硬件级安全存储后端（[HardwareBoundSeedVault]：
  /// Keystore/SE auth-bound KEK 信封加密，**读 child 时由硬件 + 生物识别原子
  /// 解锁**，写入静默）；测试经 [debugSeedStore] 注入内存 fake。无根模型只存
  /// child，绝不存母种子 / 助记词。
  static SecureSeedStore _store = HardwareBoundSeedVault();

  /// 当前 CID 绑定公开元数据与设备硬件钥封装后的用途钥密文。
  /// 这里只保存不可脱离本机硬件解封的 blob，绝不保存明文用途钥或账户 child。
  static VaultBlobStore _contactKeyStore = SecureStorageBlobStore();

  /// 每个 CID 共享一把 P-256 硬件设备子钥，物理键由 cid_number 隔离。
  static DeviceSubkey _deviceSubkey = DeviceSubkey();

  /// 每只热钱包独立的设备数据钥封装边界；日常静默使用，不读取钱包账户 child。
  static DeviceDataKeyVault _deviceDataKeyVault = DeviceDataKeyVault();

  static WalletAccountDataKeyDeriver _accountDataKeyDeriver =
      AccountDataKeyDeriver.derive;

  @visibleForTesting
  static Future<void> Function(WalletProfile profile)?
      debugWalletPersistedVerifier;

  /// 本地设备数据钥生成的进程级 single-flight。同一 CID 钱包账户只共享一次钱包
  /// 解锁；不得与 P-256 设备登记共用状态或失败回滚。
  static final Map<String, Future<void>> _deviceDataKeyInitializationFlights =
      <String, Future<void>>{};

  /// P-256 设备登记的进程级 single-flight。只有 Worker 明确报告未登记后才进入；
  /// 不生成、不删除本地设备数据钥。
  static final Map<String, Future<void>> _deviceSubkeyRegistrationFlights =
      <String, Future<void>>{};

  @visibleForTesting
  static set debugSeedStore(SecureSeedStore store) => _store = store;

  @visibleForTesting
  static set debugContactKeyStore(VaultBlobStore store) =>
      _contactKeyStore = store;

  @visibleForTesting
  static set debugDeviceSubkey(DeviceSubkey deviceSubkey) =>
      _deviceSubkey = deviceSubkey;

  @visibleForTesting
  static set debugDeviceDataKeyVault(DeviceDataKeyVault vault) =>
      _deviceDataKeyVault = vault;

  @visibleForTesting
  static set debugAccountDataKeyDeriver(WalletAccountDataKeyDeriver? deriver) {
    _accountDataKeyDeriver = deriver ?? AccountDataKeyDeriver.derive;
  }

  /// 纯 Dart 测试入口：在真实写事务中执行与创建、导入、追加账户相同的唯一性检查。
  /// 只检查不写数据，生产页面不得调用。
  @visibleForTesting
  Future<void> debugEnsureAccountIdAvailable(
    String accountId, {
    required SignMode requestedSignMode,
  }) {
    return WalletIsar.instance.writeTxn((isar) {
      return _ensureAccountIdAvailableInTxn(
        isar,
        accountId,
        requestedSignMode: requestedSignMode,
      );
    });
  }

  /// 当前 CID 钱包绑定元数据；只保存公开字段，私有数据子钥不落盘。
  static AccountDataBindingStore get _accountDataBindingStore =>
      AccountDataBindingStore(_LocalKeyBlobStoreAdapter(_contactKeyStore));

  /// 设备子钥登记钩子（app 启动注入）。只由
  /// [registerDeviceSubkeyForBinding] 在 Worker 明确报告未登记后调用；未注入时
  /// fail-closed；远端登记状态是唯一真源。
  /// 「每次动钱动权都验证」现由硬件金库读 child 时的原子生物识别实现,
  /// 不再需要操作层 local_auth 软门禁。
  static WalletSubkeyRegistrar? _subkeyRegistrar;
  static WalletColdDeviceBindingSigner? _coldDeviceBindingSigner;
  static WalletColdAccountDataKeyProvider? _coldAccountDataKeyProvider;

  static set subkeyRegistrar(WalletSubkeyRegistrar? registrar) =>
      _subkeyRegistrar = registrar;

  static set coldDeviceBindingSigner(WalletColdDeviceBindingSigner? signer) =>
      _coldDeviceBindingSigner = signer;

  static set coldAccountDataKeyProvider(
    WalletColdAccountDataKeyProvider? provider,
  ) =>
      _coldAccountDataKeyProvider = provider;

  // 查询
  /// 钱包档案列表查询入口。钱包档案只按本机稳定 walletIndex 排序；当前默认用户
  /// 必须读取账户级 `orderedAccountIds`，不得再把钱包档案顺序当作身份顺序。
  Future<List<WalletProfile>> getWallets() async {
    final rows = await WalletIsar.instance.read((isar) {
      return isar.walletProfileEntitys.where().sortByWalletIndex().findAll();
    });
    return rows.map(_toProfile).toList(growable: false);
  }

  Future<WalletProfile?> getWallet() async {
    final snapshot = await WalletIsar.instance.read((isar) async {
      final wallets =
          await isar.walletProfileEntitys.where().sortByWalletIndex().findAll();
      if (wallets.isEmpty) {
        return null;
      }
      final settings = await isar.walletSettingsEntitys.get(0);
      return (wallets: wallets, activeIndex: settings?.activeWalletIndex);
    });
    if (snapshot == null) {
      return null;
    }

    WalletProfileEntity selected = snapshot.wallets.last;
    if (snapshot.activeIndex != null) {
      for (final wallet in snapshot.wallets) {
        if (wallet.walletIndex == snapshot.activeIndex) {
          selected = wallet;
          break;
        }
      }
    } else {
      final expectedWalletIndex = selected.walletIndex;
      final expectedAccountId = selected.accountId;
      await _runWalletFactsMutation(() async {
        await WalletIsar.instance.writeTxn((isar) async {
          final settings = await _getSettingsInTxn(isar);
          if (settings.activeWalletIndex != null) return;
          final stillSelected = await isar.walletProfileEntitys
              .filter()
              .walletIndexEqualTo(expectedWalletIndex)
              .and()
              .accountIdEqualTo(expectedAccountId)
              .findFirst();
          if (stillSelected == null) {
            throw const WalletAuthException('钱包事实已变化，请重试');
          }
          settings.activeWalletIndex = expectedWalletIndex;
          settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
          await isar.walletSettingsEntitys.put(settings);
        });
      });
    }

    return _toProfile(selected);
  }

  Future<WalletProfile?> getWalletByIndex(int walletIndex) async {
    final row = await WalletIsar.instance.read((isar) {
      return isar.walletProfileEntitys
          .filter()
          .walletIndexEqualTo(walletIndex)
          .findFirst();
    });
    if (row == null) {
      return null;
    }
    return _toProfile(row);
  }

  /// 默认热钱包：钱包列表中最靠前的**热钱包**（钱包访问入口，取 walletIndex /
  /// 钱包元数据用）。
  ///
  /// **已退出身份主键角色**：唯一身份主键 = CID 号，身份账户经
  /// [FinalizedIdentityResolver] 解析（CID 绑定账户，可为任意 `//n`，见 memory
  /// CID 当前绑定账户解析契约）。本方法只供仍以热钱包档案执行的旧交易能力使用，
  /// 不再代表设备默认账户或默认用户。冷钱包永不从这里返回。列表中没有热钱包时返回 null，
  /// 由上层给出创建热钱包引导。
  Future<WalletProfile?> getDefaultWallet() async {
    final wallets = await getWallets();
    for (final wallet in wallets) {
      if (wallet.isHotWallet) {
        return wallet;
      }
    }
    return null;
  }

  /// 默认热钱包的 walletIndex；无热钱包时返回 null。
  Future<int?> getDefaultWalletIndex() async {
    final wallet = await getDefaultWallet();
    return wallet?.walletIndex;
  }

  /// 「有效热钱包」单源谓词 —— 门控与其他调用方共用同一把尺子。
  ///
  /// 四条全过才算有效：
  /// 1. 是热钱包（冷钱包永不作为身份依据）；
  /// 2. `accountId` 为全仓统一的规范形式；
  /// 3. `ss58Address` 非空且与 `accountId` 派生结果一致；
  /// 4. 本机只有这一只热钱包，且存在字段完全一致的账户0；
  /// 5. 严档 child 与钱包硬件 KEK 都存在（静默探测，不弹生物识别）。
  ///
  /// 只判 null 是不够的：Isar 属性改名等原因会留下「行还在、身份字段为空」的
  /// 半残钱包，它能骗过 null 判定进 App，然后下游全部静默降级成「没钱包」。
  Future<bool> isUsableHotWallet(WalletProfile wallet) async {
    final wallets = await getWallets();
    final accounts = await WalletIsar.instance.read((isar) async {
      final rows = await isar.accountEntitys.where().findAll();
      return rows.map(_toAccount).toList(growable: false);
    });
    final accountId = await usableHotWalletAccountIdForFacts(wallets, accounts);
    if (accountId == null) return false;
    final selected = wallets.singleWhere(
      (candidate) => candidate.accountId == accountId,
    );
    return selected.walletIndex == wallet.walletIndex &&
        selected.accountId == wallet.accountId &&
        selected.ss58Address == wallet.ss58Address &&
        selected.signMode == wallet.signMode;
  }

  /// 对一次已经连读完成的钱包/账户事实计算唯一可用热钱包能力。
  ///
  /// 页面把结果与同一 revision 的完整快照一起提交，build 阶段只消费该能力；不能再
  /// 根据 `signMode` 字符串挑第一行，也不能异步补探严档而产生半代 UI。
  Future<String?> usableHotWalletAccountIdForFacts(
    List<WalletProfile> wallets,
    List<Account> accounts,
  ) async {
    final localWallets =
        wallets.where((wallet) => wallet.isHotWallet).toList(growable: false);
    if (localWallets.length != 1) return null;
    final wallet = localWallets.single;
    if (!isAccountIdText(wallet.accountId) || wallet.ss58Address.isEmpty) {
      return null;
    }
    if (ss58FromAccountIdText(wallet.accountId) != wallet.ss58Address) {
      return null;
    }

    final anchors = accounts
        .where(
          (account) =>
              account.masterId == wallet.accountId && account.accountIndex == 0,
        )
        .toList(growable: false);
    if (anchors.length != 1) return null;
    final anchor = anchors.single;
    if (anchor.accountId != wallet.accountId ||
        anchor.ss58Address != wallet.ss58Address) {
      return null;
    }
    if (!await _store.hasAccountKey(wallet.accountId) ||
        !await _store.hasWalletKey(walletIndex: wallet.walletIndex)) {
      return null;
    }
    return wallet.accountId;
  }

  /// 列表中第一个**有效**热钱包；没有则 null。这是账户门禁的唯一依据。
  Future<WalletProfile?> getValidDefaultWallet() async {
    final wallets = await getWallets();
    final accounts = await WalletIsar.instance.read((isar) async {
      final rows = await isar.accountEntitys.where().findAll();
      return rows.map(_toAccount).toList(growable: false);
    });
    final accountId = await usableHotWalletAccountIdForFacts(wallets, accounts);
    if (accountId == null) return null;
    return wallets.singleWhere((wallet) => wallet.accountId == accountId);
  }

  Future<int?> getActiveWalletIndex() async {
    return WalletIsar.instance.read((isar) async {
      final settings = await isar.walletSettingsEntitys.get(0);
      return settings?.activeWalletIndex;
    });
  }

  Future<void> setActiveWallet(int walletIndex) {
    return _runWalletFactsMutation(() async {
      await WalletIsar.instance.writeTxn((isar) async {
        final exists = await isar.walletProfileEntitys
            .filter()
            .walletIndexEqualTo(walletIndex)
            .findFirst();
        if (exists == null) {
          throw Exception('未找到指定钱包');
        }
        final settings = await _getSettingsInTxn(isar);
        settings.activeWalletIndex = walletIndex;
        settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
        await isar.walletSettingsEntitys.put(settings);
      });
    });
  }

  /// 使用官方依赖链中的 BIP-39 English 实现校验助记词与 checksum。
  bool _isValidMnemonic(String mnemonic) {
    try {
      bip39.Mnemonic.fromSentence(mnemonic, bip39.Language.english);
      return true;
    } on bip39.MnemonicException {
      return false;
    }
  }

  // 热钱包创建 / 导入
  /// 创建热钱包（ROOTLESS）：生成助记词 → 派生母种子 → 派生账户0(`//0`) →
  /// **只存账户0 的 child mini-secret**，母种子派生后立即清零，助记词一次性返回
  /// 供备份、**绝不持久化**。
  ///
  /// [wordCount] 助记词个数，12（默认）或 24。
  Future<WalletCreationResult> createWallet({
    int wordCount = 12,
    String password = '',
  }) {
    return _runWalletFactsMutation(
      () => _createWalletWithinMutation(
        wordCount: wordCount,
        password: password,
      ),
    );
  }

  Future<WalletCreationResult> _createWalletWithinMutation({
    required int wordCount,
    required String password,
  }) async {
    await _ensureDeviceSecure();
    await _ensureNoExistingHotWallet();
    assert(wordCount == 12 || wordCount == 24);
    final mnemonic = bip39.Mnemonic.generate(
      bip39.Language.english,
      length: wordCount == 24
          ? bip39.MnemonicLength.words24
          : bip39.MnemonicLength.words12,
    ).sentence;
    final walletPassword = WalletPassword.parse(password);
    final account0 = await _deriveAccount0FromMnemonic(
      mnemonic,
      password: walletPassword.value,
    );
    try {
      final profile = await _appendHotWalletAtomic(
        account0: account0,
        source: 'created',
      );
      try {
        await _verifyWalletPersisted(profile);
        // 设备子钥**不在此注册**：建钱包时账户尚无 CID。已有子钥由业务静默使用，
        // 实际业务确认缺钥时才鉴权一次生成；页面进入本身绝不读取账户 child。
      } catch (_) {
        await _rollbackWalletCreation(profile.walletIndex);
        rethrow;
      }
      return WalletCreationResult(profile: profile, mnemonic: mnemonic);
    } finally {
      // 从派生成功这一刻起覆盖整个持久化/回滚周期；append 在返回 profile 前失败
      // 也必须立即清零账户0 child，不能把明文寿命交给 GC。
      account0.dispose();
    }
  }

  /// 导入热钱包（ROOTLESS）：验证助记词 → 派生账户0 → **只存账户0 的 child
  /// mini-secret**，母种子清零，助记词不持久化。
  Future<WalletProfile> importWallet(
    String mnemonic, {
    String password = '',
  }) {
    return _runWalletFactsMutation(
      () => _importWalletWithinMutation(
        mnemonic,
        password: password,
      ),
    );
  }

  Future<WalletProfile> _importWalletWithinMutation(
    String mnemonic, {
    required String password,
  }) async {
    await _ensureDeviceSecure();
    await _ensureNoExistingHotWallet();
    final trimmed = mnemonic.trim();
    if (!_isValidMnemonic(trimmed)) {
      throw Exception('助记词无效，请检查拼写和空格');
    }

    final walletPassword = WalletPassword.parse(password);
    final account0 = await _deriveAccount0FromMnemonic(
      trimmed,
      password: walletPassword.value,
    );
    try {
      final profile = await _appendHotWalletAtomic(
        account0: account0,
        source: 'imported',
      );
      try {
        await _verifyWalletPersisted(profile);
        // 与创建同理，设备子钥不在导入时注册。换机后已有子钥直接使用；实际业务确认
        // 本机缺钥时才鉴权一次生成，不能增加页面级授权流程。
      } catch (_) {
        await _rollbackWalletCreation(profile.walletIndex);
        rethrow;
      }
      return profile;
    } finally {
      account0.dispose();
    }
  }

  // 冷钱包导入
  /// 导入冷钱包：只接受本链 SS58 地址，并只保存公开账户资料。
  Future<WalletProfile> importColdWallet({required String ss58Address}) {
    return _runWalletFactsMutation(
      () => _importColdWalletWithinMutation(ss58Address: ss58Address),
    );
  }

  Future<WalletProfile> _importColdWalletWithinMutation({
    required String ss58Address,
  }) async {
    final trimmed = ss58Address.trim();
    if (trimmed.isEmpty) {
      throw Exception('地址不能为空');
    }

    final List<int> publicKeyBytes;
    try {
      publicKeyBytes = Keyring().decodeAddress(trimmed);
    } catch (_) {
      throw Exception('无效的 SS58 地址');
    }
    // 用本链前缀重新编码并逐字比较，拒绝其他网络和非规范地址。
    final normalizedSs58Address = Keyring().encodeAddress(
      publicKeyBytes,
      kGmbSs58Prefix,
    );
    if (normalizedSs58Address != trimmed) {
      throw Exception('地址前缀不匹配（本链 SS58 前缀为 $kGmbSs58Prefix），请确认地址来自本链');
    }

    final accountId = _accountIdFromBytes(publicKeyBytes);

    final repaired = await _repairColdSignMode(
      accountId: accountId,
      ss58Address: normalizedSs58Address,
    );
    if (repaired != null) return repaired;

    final profile = await _appendColdWalletAtomic(
      ss58Address: normalizedSs58Address,
      accountId: accountId,
    );
    return profile;
  }

  /// 把签名模式损坏、但公开账户事实与重新导入内容完全一致的钱包重标为 Cold。
  ///
  /// 该入口不识别任何旧值；只有“模式非法 + 账户与地址精确一致 + 本机无账户私钥、
  /// 无钱包硬件密钥、无热钱包账户行”同时成立才允许写入。合法 Hot/Cold 仍交给正常
  /// 重复检查处理，禁止借重标覆盖现有钱包类型。
  Future<WalletProfile?> _repairColdSignMode({
    required String accountId,
    required String ss58Address,
  }) async {
    final candidate = await WalletIsar.instance.read((isar) async {
      final row = await isar.walletProfileEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .findFirst();
      if (row == null || SignMode.tryParse(row.signMode) != null) return null;
      final accountRows = await isar.accountEntitys
          .filter()
          .masterIdEqualTo(row.masterId)
          .findAll();
      return (row: row, hasAccountRows: accountRows.isNotEmpty);
    });
    if (candidate == null) return null;
    final row = candidate.row;
    if (row.ss58Address != ss58Address ||
        row.masterId != accountId ||
        candidate.hasAccountRows ||
        await _store.hasAccountKey(accountId) ||
        await _store.hasWalletKey(walletIndex: row.walletIndex)) {
      throw const WalletAuthException('钱包数据异常，不能重标为冷钱包');
    }

    await WalletIsar.instance.writeTxn((isar) async {
      final current = await isar.walletProfileEntitys.get(row.id);
      if (current == null ||
          current.accountId != accountId ||
          current.ss58Address != ss58Address ||
          SignMode.tryParse(current.signMode) != null) {
        throw const WalletAuthException('钱包事实已变化，请重试');
      }
      current.signMode = SignMode.cold.name;
      await isar.walletProfileEntitys.put(current);
    });
    return (await getWalletByIndex(row.walletIndex))!;
  }

  /// 用本机受保护私钥证明目标 AccountId 的控制权后，把非法模式重标为 Hot。
  ///
  /// 挑战摘要唯一走 `signingMessage(OP_SIGN_WALLET_MODE, SCALE)`；不会把非法模式、
  /// 账户行或密钥“存在”本身当作热钱包。签名、公钥回验和写事务任一步失败都不改事实。
  Future<WalletProfile> repairHotSignMode({
    required int walletIndex,
    required String accountId,
    required Uint8List genesisHash,
  }) {
    return _runWalletFactsMutation(() async {
      if (genesisHash.length != 32) {
        throw ArgumentError('genesis_hash 必须为 32 字节');
      }
      final normalized = _normalizeAccountId(accountId);
      final snapshot = await WalletIsar.instance.read((isar) async {
        final row = await isar.walletProfileEntitys
            .filter()
            .walletIndexEqualTo(walletIndex)
            .and()
            .accountIdEqualTo(normalized)
            .findFirst();
        if (row == null || SignMode.tryParse(row.signMode) != null) {
          return null;
        }
        final anchors = await isar.accountEntitys
            .filter()
            .masterIdEqualTo(row.masterId)
            .and()
            .accountIndexEqualTo(0)
            .findAll();
        return (row: row, anchors: anchors);
      });
      if (snapshot == null ||
          snapshot.row.masterId != normalized ||
          snapshot.row.ss58Address != ss58FromAccountIdText(normalized) ||
          snapshot.row.alg != 'sr25519' ||
          snapshot.row.ss58 != kGmbSs58Prefix ||
          snapshot.anchors.length != 1 ||
          snapshot.anchors.single.accountId != normalized ||
          snapshot.anchors.single.ss58Address != snapshot.row.ss58Address) {
        throw const WalletAuthException('钱包数据异常，不能重标为热钱包');
      }

      final random = Random.secure();
      final challenge = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      final accountBytes = _hexToBytes(normalized);
      final modeBytes = utf8.encode(SignMode.hot.name);
      final payload = Uint8List.fromList(<int>[
        ...genesisHash,
        ...accountBytes,
        modeBytes.length << 2,
        ...modeBytes,
        ...challenge,
      ]);
      final message = signingMessage(
        opTag: kOpSignWalletMode,
        scalePayload: payload,
      );
      Uint8List? signature;
      try {
        final child = await _readAccountKeyOrThrow(walletIndex, normalized);
        signature = _deriveVerifyAndSign(
          childMiniSecret: child,
          expectedAccountId: normalized,
          payload: message,
          mismatchMessage: '本机私钥与目标钱包账户不一致',
        );
        if (!NativeSr25519.verify(accountBytes, signature, message)) {
          throw const WalletAuthException('热钱包控制权验证失败');
        }
        await WalletIsar.instance.writeTxn((isar) async {
          final current = await isar.walletProfileEntitys.get(snapshot.row.id);
          if (current == null ||
              current.walletIndex != walletIndex ||
              current.accountId != normalized ||
              SignMode.tryParse(current.signMode) != null) {
            throw const WalletAuthException('钱包事实已变化，请重试');
          }
          current.signMode = SignMode.hot.name;
          await isar.walletProfileEntitys.put(current);
        });
      } finally {
        challenge.fillRange(0, challenge.length, 0);
        payload.fillRange(0, payload.length, 0);
        message.fillRange(0, message.length, 0);
        signature?.fillRange(0, signature.length, 0);
      }
      return (await getWalletByIndex(walletIndex))!;
    });
  }

  // 多账户（一只钱包 masterId = 一套助记词，下辖多个 //index 账户）
  /// 某钱包(masterId)下全部账户,按 accountIndex 升序(账户0 在最前)。
  Future<List<Account>> getAccounts(String masterId) async {
    final rows = await WalletIsar.instance.read((isar) {
      return isar.accountEntitys
          .filter()
          .masterIdEqualTo(masterId)
          .sortByAccountIndex()
          .findAll();
    });
    return rows.map(_toAccount).toList(growable: false);
  }

  /// 一次读取全部账户事实，供钱包页与交易监控构建同一代完整集合。
  Future<List<Account>> getAllAccounts() async {
    final rows = await WalletIsar.instance.read(
      (isar) => isar.accountEntitys.where().findAll(),
    );
    return rows.map(_toAccount).toList(growable: false);
  }

  /// 从一份完整钱包/账户快照构建交易监控集合。热钱包必须包含全部
  /// `//index` child；冷钱包直接使用档案 AccountId。异常/孤立事实不得进入监控。
  static Map<String, String> transactionMonitorAccountsForFacts(
    List<WalletProfile> wallets,
    List<Account> accounts,
  ) {
    final result = <String, String>{};
    final hotMasters = <String>{};
    for (final wallet in wallets) {
      if (!isAccountIdText(wallet.accountId) ||
          wallet.ss58Address != ss58FromAccountIdText(wallet.accountId)) {
        continue;
      }
      if (wallet.isColdWallet) {
        result[wallet.accountId] = wallet.ss58Address;
      } else if (wallet.isHotWallet) {
        hotMasters.add(wallet.accountId);
      }
    }
    for (final account in accounts) {
      if (!hotMasters.contains(account.masterId) ||
          !isAccountIdText(account.accountId) ||
          account.ss58Address != ss58FromAccountIdText(account.accountId)) {
        continue;
      }
      result[account.accountId] = account.ss58Address;
    }
    return Map<String, String>.unmodifiable(result);
  }

  Future<Map<String, String>> getTransactionMonitorAccounts() {
    return WalletIsar.instance.read((isar) async {
      final walletRows =
          await isar.walletProfileEntitys.where().sortByWalletIndex().findAll();
      final accountRows = await isar.accountEntitys.where().findAll();
      return transactionMonitorAccountsForFacts(
        walletRows.map(_toProfile).toList(growable: false),
        accountRows.map(_toAccount).toList(growable: false),
      );
    });
  }

  /// 按 accountId 取单个账户;不存在返回 null。
  Future<Account?> getAccountByAccountId(String accountId) async {
    final row = await WalletIsar.instance.read((isar) {
      return isar.accountEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .findFirst();
    });
    return row == null ? null : _toAccount(row);
  }

  /// 返回指定热/冷链账户所属钱包的本机索引。P-256 设备子钥按 CID 保存；该索引只供
  /// 钱包主钥和设备数据钥金库定位，不得再作为用户或设备身份。
  Future<int> walletIndexForAccountId(String accountId) async {
    final fact = await _localAccountFact(accountId);
    if (fact == null) {
      throw const WalletAuthException('CID 当前绑定账户不在本机钱包中');
    }
    return fact.walletIndex;
  }

  /// 只按 `account_id` 读取钱包账户的唯一签名模式；不读取私钥、不弹生物识别。
  ///
  /// 缺失、孤立或模式损坏的账户返回 `null`，交由统一签名器拒绝，禁止调用方
  /// 根据“能否找到私钥”猜测 Hot/Cold。
  Future<SignMode?> signModeForAccountId(String accountId) async =>
      (await _localAccountFact(accountId))?.signMode;

  /// 读取一个统一热/冷账户事实；不读取私钥，也不改变默认账户顺序。
  Future<({int walletIndex, SignMode signMode, String? masterId})?>
      _localAccountFact(String accountId) async {
    return WalletIsar.instance.read((isar) async {
      final direct = await isar.walletProfileEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .findFirst();
      if (direct != null &&
          SignMode.tryParse(direct.signMode) == SignMode.cold) {
        return (
          walletIndex: direct.walletIndex,
          signMode: SignMode.cold,
          masterId: null,
        );
      }
      final account = await isar.accountEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .findFirst();
      if (account == null) return null;
      final owner = await isar.walletProfileEntitys
          .filter()
          .masterIdEqualTo(account.masterId)
          .findFirst();
      if (owner == null || SignMode.tryParse(owner.signMode) != SignMode.hot) {
        return null;
      }
      return (
        walletIndex: owner.walletIndex,
        signMode: SignMode.hot,
        masterId: account.masterId,
      );
    });
  }

  /// 在钱包(masterId)下批量追加账户(`//index`),原子写入 + 失败整批回滚。
  ///
  /// 无根:本端不存母种子,追加账户须重新录入 [mnemonic]。校验全部先于落库:
  /// 1) 助记词合法 + **归属校验**——由它派生的账户0.accountId 必须等于 [masterId],
  ///    否则抛 [WalletAuthException]（错助记词 / 换钱包早拒）。
  /// 2) [indices] 非空;每个序号在 `1.._maxAccountIndex`(账户0 是锚点不可再加);输入
  ///    内不得重复;不得与既有账户序号冲突。任一违规抛 [Exception]。
  /// 3) 逐个派生 child + accountId + ss58。
  /// 4) 原子批:一次 writeTxn 写全部 AccountEntity → 逐个 putAccountKey;任一步抛错则
  ///    整批回滚(删本批 AccountEntity + deleteAccountKey 已写入的 child)。母种子在
  ///    finally 清零。返回新增账户列表。
  Future<List<Account>> addAccounts(
    String masterId,
    String mnemonic,
    List<int> indices, {
    String password = '',
  }) {
    return _runWalletFactsMutation(
      () => _addAccountsWithinMutation(
        masterId,
        mnemonic,
        indices,
        password: password,
      ),
    );
  }

  Future<List<Account>> _addAccountsWithinMutation(
    String masterId,
    String mnemonic,
    List<int> indices, {
    required String password,
  }) async {
    final trimmed = mnemonic.trim();
    if (!_isValidMnemonic(trimmed)) {
      throw Exception('助记词无效，请检查拼写和空格');
    }

    // 归属校验:助记词派生的账户0 必须就是这只钱包(masterId)。
    final walletPassword = WalletPassword.parse(password);
    final account0 = await _deriveAccount0FromMnemonic(
      trimmed,
      password: walletPassword.value,
    );
    try {
      if (account0.accountId != masterId) {
        throw const WalletAuthException('助记词与该钱包不符');
      }

      final profile = await _requireHotWalletProfileByMasterId(masterId);
      final walletIndex = profile.walletIndex;

      // 序号校验:非空 / 范围 / 输入内去重(有重即拒) / 不与既有冲突。
      if (indices.isEmpty) {
        throw Exception('未指定要追加的账户序号');
      }
      final seen = <int>{};
      for (final index in indices) {
        if (index < 1 || index > _maxAccountIndex) {
          throw Exception('账户序号需在 1–$_maxAccountIndex,账户0 为锚点不可再加');
        }
        if (!seen.add(index)) {
          throw Exception('账户序号重复:$index');
        }
      }
      final existing = await _existingAccountIndexes(masterId);
      for (final index in seen) {
        if (existing.contains(index)) {
          throw Exception('账户$index 已存在');
        }
      }
      final targets = seen.toList(growable: false)..sort();

      // 逐个派生(母种子只在此作用域存活,finally 清零)。
      final seed = await WalletMiniSecret.fromMnemonic(
        trimmed,
        password: walletPassword.value,
      );
      final derived = <_Account0>[];
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final entities = <AccountEntity>[];
        for (final index in targets) {
          final account = _deriveAccount(seed, index);
          derived.add(account);
          entities.add(
            AccountEntity()
              ..masterId = masterId
              ..accountIndex = index
              ..accountId = account.accountId
              ..ss58Address = account.ss58Address
              ..accountName = _defaultAccountName(index)
              ..createdAtMillis = now,
          );
        }

        // 原子批 4a：唯一性检查与全部 AccountEntity 写入必须处于同一写事务。
        // 这样冷钱包导入与追加热账户并发时，后进入事务的一方会明确失败，不能
        // 依赖 unique replace 静默覆盖另一方。
        await WalletIsar.instance.writeTxn((isar) async {
          for (final entity in entities) {
            await _ensureAccountIdAvailableInTxn(
              isar,
              entity.accountId,
              requestedSignMode: SignMode.hot,
            );
            final duplicateIndex = await isar.accountEntitys
                .filter()
                .masterIdEqualTo(masterId)
                .and()
                .accountIndexEqualTo(entity.accountIndex)
                .findFirst();
            if (duplicateIndex != null) {
              throw Exception('账户${entity.accountIndex} 已存在');
            }
          }
          for (final entity in entities) {
            await isar.accountEntitys.put(entity);
          }
          final settings = await _getSettingsInTxn(isar);
          final addedIds = entities.map((entity) => entity.accountId).toSet();
          settings.orderedAccountIds = <String>[
            ...settings.orderedAccountIds.where((id) => !addedIds.contains(id)),
            ...entities.map((entity) => entity.accountId),
          ];
          settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
          await isar.walletSettingsEntitys.put(settings);
        });

        // 原子批 4b:逐个写 child;任一失败 → 整批回滚(删本批行 + 已写 child)。
        final attempted = <String>[];
        try {
          for (var i = 0; i < targets.length; i++) {
            // 后端可能在真实写入后才抛错；必须先登记当前 attempted accountId，
            // 不能只清理已经成功返回的前序项。
            attempted.add(derived[i].accountId);
            await _store.putAccountKey(
              walletIndex: walletIndex,
              accountId: derived[i].accountId,
              childMiniSecret: derived[i].childMiniSecret,
            );
          }
        } catch (_) {
          final failures = <String>[];
          for (final accountId in attempted) {
            await _attemptWalletCleanup(
              failures,
              '追加账户私钥($accountId)',
              () => _store.deleteAccountKey(
                walletIndex: walletIndex,
                accountId: accountId,
              ),
            );
            await _attemptWalletCleanup(
              failures,
              '追加账户私钥删除复核($accountId)',
              () async {
                if (await _store.hasAccountKey(accountId)) {
                  throw StateError('密文仍存在');
                }
              },
            );
          }
          // 只有所有已写机密都确认清除后才删除事实行；清理失败时保留可见事实供用户
          // 重试删除，禁止形成数据库已消失但硬件密文仍在的不可见孤儿机密。
          if (failures.isNotEmpty) {
            throw WalletLocalCleanupException(
              List<String>.unmodifiable(failures),
            );
          }
          await WalletIsar.instance.writeTxn((isar) async {
            for (final entity in entities) {
              final row = await isar.accountEntitys
                  .filter()
                  .accountIdEqualTo(entity.accountId)
                  .findFirst();
              if (row != null) await isar.accountEntitys.delete(row.id);
            }
            final settings = await _getSettingsInTxn(isar);
            final rolledBackIds = entities.map((row) => row.accountId).toSet();
            settings.orderedAccountIds = settings.orderedAccountIds
                .where((id) => !rolledBackIds.contains(id))
                .toList(growable: false);
            settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
            await isar.walletSettingsEntitys.put(settings);
          });
          rethrow;
        }

        return entities.map(_toAccount).toList(growable: false);
      } finally {
        seed.fillRange(0, seed.length, 0);
        for (final account in derived) {
          account.dispose();
        }
      }
    } finally {
      account0.dispose();
    }
  }

  /// 便捷:追加「下一个」账户(既有最大序号 + 1)。
  Future<Account> addNextAccount(
    String masterId,
    String mnemonic, {
    String password = '',
  }) async {
    final existing = await _existingAccountIndexes(masterId);
    final maxIndex = existing.fold<int>(
      0,
      (max, index) => index > max ? index : max,
    );
    final added = await addAccounts(
      masterId,
      mnemonic,
      <int>[maxIndex + 1],
      password: password,
    );
    return added.single;
  }

  /// 导出指定账户私钥(child mini-secret,`0x` + 64 hex;读硬件金库触发生物识别)。
  Future<String> getAccountPrivateKey(String accountId) async {
    final account = await getAccountByAccountId(accountId);
    if (account == null) {
      throw const WalletAuthException('未找到指定账户');
    }
    final profile = await _requireHotWalletProfileByMasterId(account.masterId);
    final child = await _readAccountKeyOrThrow(
      profile.walletIndex,
      accountId,
    );
    try {
      if (_accountIdFromBytes(NativeSr25519.publicKeyOf(child)) != accountId) {
        throw const WalletAuthException('本地私钥与目标账户不一致，请重新导入钱包');
      }
      // Flutter Text 最终只能接收不可变 String；仅在展示边界生成一次，内部全程保留
      // 可擦除字节，返回前立即清零 child。
      return '0x${_toHex(child)}';
    } finally {
      child.fillRange(0, child.length, 0);
    }
  }

  /// 用指定 accountId 的私钥对 [payload] 签名(多账户签名入口)。
  ///
  /// 读该账户 child(触发生物识别)→ fromSeed → 校验派生公钥 == accountId → 签名 →
  /// 清零。**身份账户维度签名(发布动态 / CID 注册·换绑 / 订阅 / 创作者)走本方法**
  /// (accountId = CID 绑定账户,可任意 `//n`);转账 / 治理 / 机构等资金动作走
  /// [signWithWallet](账户0)。
  Future<Uint8List> signForAccountId(
    String accountId,
    Uint8List payload,
  ) async {
    final account = await getAccountByAccountId(accountId);
    if (account == null) {
      throw const WalletAuthException('未找到指定账户');
    }
    final profile = await _requireHotWalletProfileByMasterId(account.masterId);
    final vaultStart = DateTime.now();
    final child = await _readAccountKeyOrThrow(
      profile.walletIndex,
      accountId,
    );
    final vaultMs = DateTime.now().difference(vaultStart).inMilliseconds;

    // 派生+签名走原生 schnorrkel，毫秒级，直接在调用线程完成。
    final cpuStart = DateTime.now();
    final signature = _deriveVerifyAndSign(
      childMiniSecret: child,
      expectedAccountId: accountId,
      payload: payload,
      mismatchMessage: '本地签名密钥与账户不一致，请重新导入钱包',
    );
    AppLog.d(
      '[Sign-Diag] 金库读取+生物识别 ${vaultMs}ms, 派生+签名(原生) '
      '${DateTime.now().difference(cpuStart).inMilliseconds}ms',
    );
    return signature;
  }

  /// 删除单个账户。锚点守卫:账户0 且存在兄弟账户时禁止单删(须删整只钱包);
  /// 删空该钱包全部账户则级联删钱包(同 [deleteWallet])。
  Future<WalletDeletionResult> deleteAccount(String accountId) {
    return _runWalletFactsMutation(
      () => _deleteAccountWithinMutation(_normalizeAccountId(accountId)),
    );
  }

  Future<WalletDeletionResult> _deleteAccountWithinMutation(
    String accountId,
  ) async {
    late WalletDeletionResult committed;
    await WalletIsar.instance.writeTxn((isar) async {
      final row = await isar.accountEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .findFirst();
      if (row == null) throw Exception('未找到账户');
      final profile = await isar.walletProfileEntitys
          .filter()
          .masterIdEqualTo(row.masterId)
          .findFirst();
      if (profile == null ||
          SignMode.tryParse(profile.signMode) != SignMode.hot) {
        throw const WalletAuthException('未找到指定钱包');
      }
      final siblingRows = await isar.accountEntitys
          .filter()
          .masterIdEqualTo(row.masterId)
          .findAll();
      if (row.accountIndex == 0 && siblingRows.length > 1) {
        throw Exception('账户0是钱包锚点,请删除整个钱包');
      }

      if (siblingRows.length == 1) {
        final walletFacts = await _deleteWalletFactsInTxn(isar, profile);
        committed = walletFacts;
        return;
      }

      await isar.accountEntitys.delete(row.id);
      await isar.localTxEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .deleteAll();
      await isar.walletTxSyncCursorEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .deleteAll();
      final settings = await _getSettingsInTxn(isar);
      settings.orderedAccountIds = settings.orderedAccountIds
          .where((id) => id != accountId)
          .toList(growable: false);
      settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      await isar.walletSettingsEntitys.put(settings);
      final deletedAccountIds = <String>{accountId};
      final plan = _newWalletCleanupPlan(
        walletIndex: profile.walletIndex,
        accountIds: deletedAccountIds,
        deleteAccountKeys: true,
        deleteWalletWideKeys: false,
      );
      await _mergePendingWalletCleanupPlansInTxn(isar, <WalletCleanupPlan>[
        plan,
      ]);
      committed = WalletDeletionResult(
        factCommitted: true,
        cleanupPlans: <WalletCleanupPlan>[plan],
      );
    });

    try {
      await _executeWalletCleanupPlansCore(committed.cleanupPlans);
      return committed;
    } on WalletLocalCleanupException catch (error) {
      throw WalletLocalCleanupException(
        error.failures,
        deletionResult: committed,
      );
    }
  }

  Future<Set<int>> _existingAccountIndexes(String masterId) async {
    final rows = await WalletIsar.instance.read((isar) {
      return isar.accountEntitys.filter().masterIdEqualTo(masterId).findAll();
    });
    return rows.map((row) => row.accountIndex).toSet();
  }

  Future<WalletProfile> _requireHotWalletProfileByMasterId(
    String masterId,
  ) async {
    final row = await WalletIsar.instance.read((isar) {
      return isar.walletProfileEntitys
          .filter()
          .masterIdEqualTo(masterId)
          .findFirst();
    });
    if (row == null) {
      throw const WalletAuthException('未找到指定钱包');
    }
    final profile = _toProfile(row);
    if (profile.requiredSignMode != SignMode.hot) {
      throw const WalletAuthException('当前钱包为冷钱包，请使用扫码签名');
    }
    return profile;
  }

  /// 一台设备仅允许一个热钱包(冷钱包不限)。createWallet / importWallet 前置。
  Future<void> _ensureNoExistingHotWallet() async {
    final wallets = await getWallets();
    if (wallets.any((wallet) => wallet.signMode == null)) {
      throw const WalletAuthException('存在签名模式异常的钱包，请先验证或删除该钱包');
    }
    if (wallets.any((wallet) => wallet.isHotWallet)) {
      throw Exception('本设备已存在热钱包,一台设备仅支持一个热钱包');
    }
  }

  String _defaultAccountName(int accountIndex) => '账户$accountIndex';

  Account _toAccount(AccountEntity row) => Account(
        masterId: row.masterId,
        accountIndex: row.accountIndex,
        accountId: row.accountId,
        ss58Address: row.ss58Address,
        accountName: row.accountName,
      );

  /// 尚未完成的本机删除后清理计划。计划与事实同库持久化，App 崩溃或页面 reload
  /// 失败后仍可由新页面继续执行全部秘密与清算行缓存清理。
  Future<List<WalletCleanupPlan>> getPendingWalletCleanupPlans() {
    return WalletIsar.instance.read(_readPendingWalletCleanupPlansInTxn);
  }

  /// 只有计划中的安全存储、绑定材料和全部清算行缓存都完成并回读不存在后，上层才可
  /// 确认整项计划。事务内按最新集合删除 planId，不会覆盖并发删除新合入的计划。
  Future<void> acknowledgeWalletCleanupPlan(String planId) async {
    final normalizedPlanId = planId.trim();
    if (normalizedPlanId.isEmpty) {
      throw ArgumentError.value(planId, 'planId', '清理计划 ID 不能为空');
    }
    await WalletIsar.instance.writeTxn((isar) async {
      final pending = await _readPendingWalletCleanupPlansInTxn(isar);
      final next = pending
          .where((plan) => plan.planId != normalizedPlanId)
          .toList(growable: false);
      if (next.length == pending.length) return;
      await _writePendingWalletCleanupPlansInTxn(isar, next);
    });
  }

  Future<List<WalletCleanupPlan>> _readPendingWalletCleanupPlansInTxn(
    Isar isar,
  ) async {
    final row = await isar.walletCleanupPlanStateEntitys.get(0);
    final raw = row?.payloadJson;
    if (raw == null || raw.isEmpty) return <WalletCleanupPlan>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('不是数组');
      final plans = <WalletCleanupPlan>[];
      final planIds = <String>{};
      for (final value in decoded) {
        if (value is! Map) throw const FormatException('计划不是对象');
        final planId = value['plan_id'];
        final rawWalletIndex = value['wallet_index'];
        final rawAccountIds = value['account_ids'];
        final deleteAccountKeys = value['delete_account_keys'];
        final deleteWalletWideKeys = value['delete_wallet_wide_keys'];
        if (planId is! String ||
            planId.trim().isEmpty ||
            (rawWalletIndex != null && rawWalletIndex is! int) ||
            rawAccountIds is! List ||
            deleteAccountKeys is! bool ||
            deleteWalletWideKeys is! bool ||
            !planIds.add(planId)) {
          throw const FormatException('计划字段无效');
        }
        final accountIds = rawAccountIds
            .map((item) => _normalizeAccountId(item as String))
            .toSet();
        if (accountIds.isEmpty ||
            (rawWalletIndex == null &&
                (deleteAccountKeys || deleteWalletWideKeys))) {
          throw const FormatException('计划能力与钱包索引不一致');
        }
        plans.add(
          WalletCleanupPlan(
            planId: planId,
            walletIndex: rawWalletIndex as int?,
            accountIds: accountIds,
            deleteAccountKeys: deleteAccountKeys,
            deleteWalletWideKeys: deleteWalletWideKeys,
          ),
        );
      }
      plans.sort((left, right) => left.planId.compareTo(right.planId));
      return plans;
    } catch (error) {
      throw StateError('待清理钱包计划索引损坏：$error');
    }
  }

  Future<void> _writePendingWalletCleanupPlansInTxn(
    Isar isar,
    List<WalletCleanupPlan> plans,
  ) async {
    if (plans.isEmpty) {
      await isar.walletCleanupPlanStateEntitys.delete(0);
      return;
    }
    final ordered = List<WalletCleanupPlan>.of(plans)
      ..sort((left, right) => left.planId.compareTo(right.planId));
    await isar.walletCleanupPlanStateEntitys.put(
      WalletCleanupPlanStateEntity()
        ..id = 0
        ..payloadJson = jsonEncode(
          ordered.map((plan) => plan._toJson()).toList(growable: false),
        ),
    );
  }

  Future<void> _mergePendingWalletCleanupPlansInTxn(
    Isar isar,
    List<WalletCleanupPlan> additions,
  ) async {
    final pending = await _readPendingWalletCleanupPlansInTxn(isar);
    final byId = <String, WalletCleanupPlan>{
      for (final plan in pending) plan.planId: plan,
    };
    for (final plan in additions) {
      final existing = byId[plan.planId];
      if (existing != null && !existing._sameFacts(plan)) {
        throw StateError('钱包清理计划 ID 冲突：${plan.planId}');
      }
      byId[plan.planId] = plan;
    }
    await _writePendingWalletCleanupPlansInTxn(
      isar,
      byId.values.toList(growable: false),
    );
  }

  WalletCleanupPlan _newWalletCleanupPlan({
    required int? walletIndex,
    required Set<String> accountIds,
    required bool deleteAccountKeys,
    required bool deleteWalletWideKeys,
  }) {
    final normalizedIds = accountIds.map(_normalizeAccountId).toSet();
    if (normalizedIds.isEmpty ||
        (walletIndex == null && (deleteAccountKeys || deleteWalletWideKeys))) {
      throw StateError('钱包清理计划事实不完整');
    }
    final nonce = Random.secure().nextInt(0x7fffffff);
    return WalletCleanupPlan(
      planId: 'wallet_cleanup_${DateTime.now().microsecondsSinceEpoch}_$nonce',
      walletIndex: walletIndex,
      accountIds: normalizedIds,
      deleteAccountKeys: deleteAccountKeys,
      deleteWalletWideKeys: deleteWalletWideKeys,
    );
  }

  // 删除
  Future<WalletDeletionResult> clearWallet() {
    return _runWalletFactsMutation(_clearWalletWithinMutation);
  }

  /// 全设备擦除在删除 WalletIsar 前调用：先按数据库中的精确钱包与账户事实删除并
  /// 复核硬件密钥。任一项失败都会保留数据库索引，供下次启动继续擦除。
  Future<void> wipeAllLocalSecretsBeforeDatabaseDeletion() async {
    final snapshot = await WalletIsar.instance.read((isar) async {
      final wallets = await isar.walletProfileEntitys.where().findAll();
      final accounts = await isar.accountEntitys.where().findAll();
      return (wallets: wallets, accounts: accounts);
    });
    final failures = <String>[];
    for (final wallet in snapshot.wallets.where(
      // 非法模式也可能遗留本机私钥；全设备擦除必须按精确钱包索引尝试清理，
      // 但不会据此把它认定为可签名的 Hot。
      (wallet) => SignMode.tryParse(wallet.signMode) != SignMode.cold,
    )) {
      final accountIds = <String>{
        wallet.accountId,
        ...snapshot.accounts
            .where((account) => account.masterId == wallet.masterId)
            .map((account) => account.accountId),
      };
      try {
        await _cleanupDeletedWalletSecrets(
          walletIndex: wallet.walletIndex,
          accountIds: accountIds,
          deleteAccountKeys: true,
          deleteWalletWideKeys: true,
        );
      } on WalletLocalCleanupException catch (error) {
        failures.addAll(error.failures);
      } catch (error) {
        failures.add('钱包 ${wallet.walletIndex} 本机秘密：$error');
      }
    }
    if (failures.isNotEmpty) {
      throw WalletLocalCleanupException(List<String>.unmodifiable(failures));
    }
  }

  Future<WalletDeletionResult> _clearWalletWithinMutation() async {
    late WalletDeletionResult result;
    await WalletIsar.instance.writeTxn((isar) async {
      final wallets = await isar.walletProfileEntitys.where().findAll();
      final accounts = await isar.accountEntitys.where().findAll();
      final plans = <WalletCleanupPlan>[];
      final coveredAccountIds = <String>{};
      for (final wallet in wallets) {
        final accountIds = <String>{
          wallet.accountId,
          ...accounts
              .where((account) => account.masterId == wallet.masterId)
              .map((account) => account.accountId),
        };
        coveredAccountIds.addAll(accountIds);
        final mode = SignMode.tryParse(wallet.signMode);
        final shouldDeleteSecrets = mode != SignMode.cold;
        plans.add(
          _newWalletCleanupPlan(
            walletIndex: wallet.walletIndex,
            accountIds: accountIds,
            deleteAccountKeys: shouldDeleteSecrets,
            deleteWalletWideKeys: shouldDeleteSecrets,
          ),
        );
      }
      final danglingAccountIds = accounts
          .map((account) => account.accountId)
          .where((accountId) => !coveredAccountIds.contains(accountId))
          .toSet();
      if (danglingAccountIds.isNotEmpty) {
        // 损坏事实没有可证明的 walletIndex，仍保留账户级绑定与清算行清理目标；绝不
        // 猜测某个索引并误删其它钱包的硬件密钥。
        plans.add(
          _newWalletCleanupPlan(
            walletIndex: null,
            accountIds: danglingAccountIds,
            deleteAccountKeys: false,
            deleteWalletWideKeys: false,
          ),
        );
      }

      await isar.walletProfileEntitys.clear();
      await isar.accountEntitys.clear();
      await isar.localTxEntitys.clear();
      await isar.walletTxSyncCursorEntitys.clear();
      final settings = await _getSettingsInTxn(isar);
      settings.activeWalletIndex = null;
      settings.orderedAccountIds = const [];
      settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      await isar.walletSettingsEntitys.put(settings);
      await _mergePendingWalletCleanupPlansInTxn(isar, plans);
      result = WalletDeletionResult(
        factCommitted: true,
        cleanupPlans: plans,
      );
    });

    try {
      await _executeWalletCleanupPlansCore(result.cleanupPlans);
    } on WalletLocalCleanupException catch (error) {
      throw WalletLocalCleanupException(
        error.failures,
        deletionResult: result,
      );
    }
    return result;
  }

  /// 账户0签名并本地验签后删除整只热钱包。
  ///
  /// 这里签的是本机 `Random.secure()` 产生的一次性随机挑战，只用于证明当前操作人
  /// 能解锁账户0 child；挑战和签名不落库、不联网、不进入 QR_V1 或链上协议。
  /// 任何取消、签名异常或验签失败都发生在 [deleteWallet] 前，事实数据保持不变。
  Future<WalletDeletionResult> signAndDeleteWallet({
    required int walletIndex,
    required String accountId,
  }) async {
    final profile = await _requireHotWalletProfile(walletIndex);
    final account = await getAccountByAccountId(accountId);
    if (profile.accountId != accountId ||
        account == null ||
        account.accountIndex != 0 ||
        account.masterId != profile.accountId) {
      throw const WalletAuthException('只有账户0可以签名删除整只钱包');
    }

    final random = Random.secure();
    final challenge = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    Uint8List? signature;
    try {
      signature = await signForAccountId(accountId, challenge);
      final verified = NativeSr25519.verify(
        _hexToBytes(accountId),
        signature,
        challenge,
      );
      if (!verified) {
        throw const WalletAuthException('删除钱包签名验证失败');
      }
      return await deleteWallet(
        walletIndex: walletIndex,
        expectedAccountId: accountId,
      );
    } finally {
      challenge.fillRange(0, challenge.length, 0);
      signature?.fillRange(0, signature.length, 0);
    }
  }

  Future<WalletDeletionResult> deleteWallet({
    required int walletIndex,
    required String expectedAccountId,
  }) {
    return _runWalletFactsMutation(
      () => _deleteWalletWithinMutation(
        walletIndex,
        _normalizeAccountId(expectedAccountId),
      ),
    );
  }

  Future<WalletDeletionResult> _deleteWalletWithinMutation(
    int walletIndex,
    String expectedAccountId,
  ) async {
    late WalletDeletionResult committed;
    await WalletIsar.instance.writeTxn((isar) async {
      final current = await isar.walletProfileEntitys
          .filter()
          .walletIndexEqualTo(walletIndex)
          .and()
          .accountIdEqualTo(expectedAccountId)
          .findFirst();
      if (current == null || current.masterId != expectedAccountId) {
        throw const WalletAuthException('钱包事实已变化，请重新确认删除');
      }
      committed = await _deleteWalletFactsInTxn(isar, current);
    });

    try {
      await _executeWalletCleanupPlansCore(committed.cleanupPlans);
      return committed;
    } on WalletLocalCleanupException catch (error) {
      throw WalletLocalCleanupException(
        error.failures,
        deletionResult: committed,
      );
    }
  }

  /// 只在已进入 WalletIsar 写事务时删除整只钱包。账户 ID 与待清理缓存
  /// 同一事务确定，不允许页面从旧快照反推。
  Future<WalletDeletionResult> _deleteWalletFactsInTxn(
    Isar isar,
    WalletProfileEntity current,
  ) async {
    final accountRows = await isar.accountEntitys
        .filter()
        .masterIdEqualTo(current.masterId)
        .findAll();
    final accountIds = <String>{
      current.accountId,
      ...accountRows.map((row) => row.accountId),
    };
    // 非法模式可能是损坏的热钱包事实。用户明确删除该钱包时，按精确索引和
    // AccountId 清理可能存在的秘密；这不是签名模式推断，非法模式仍不能签名。
    final shouldDeleteSecrets =
        SignMode.tryParse(current.signMode) != SignMode.cold;
    await isar.walletProfileEntitys.delete(current.id);
    await isar.accountEntitys
        .filter()
        .masterIdEqualTo(current.masterId)
        .deleteAll();
    for (final accountId in accountIds) {
      await isar.localTxEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .deleteAll();
      await isar.walletTxSyncCursorEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .deleteAll();
    }
    final settings = await _getSettingsInTxn(isar);
    settings.orderedAccountIds = settings.orderedAccountIds
        .where((id) => !accountIds.contains(id))
        .toList(growable: false);
    if (settings.activeWalletIndex == current.walletIndex) {
      final remains =
          await isar.walletProfileEntitys.where().sortByWalletIndex().findAll();
      settings.activeWalletIndex =
          remains.isEmpty ? null : remains.last.walletIndex;
    }
    settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    await isar.walletSettingsEntitys.put(settings);
    final plan = _newWalletCleanupPlan(
      walletIndex: current.walletIndex,
      accountIds: accountIds,
      deleteAccountKeys: shouldDeleteSecrets,
      deleteWalletWideKeys: shouldDeleteSecrets,
    );
    await _mergePendingWalletCleanupPlansInTxn(isar, <WalletCleanupPlan>[
      plan,
    ]);
    return WalletDeletionResult(
      factCommitted: true,
      cleanupPlans: <WalletCleanupPlan>[plan],
    );
  }

  /// 重试一项仍在持久计划集合中的删除后安全清理。
  ///
  /// 计划必须与 WalletCleanupPlanStateEntity 中的同 planId 内容完全一致；执行前再次确认目标账户事实已删除，
  /// 且钱包级计划的 walletIndex 尚未被新钱包占用，防止陈旧页面构造计划误删新钱包。
  Future<void> retryWalletCleanupPlan(WalletCleanupPlan plan) async {
    final stored = await WalletIsar.instance.read((isar) async {
      final plans = await _readPendingWalletCleanupPlansInTxn(isar);
      for (final candidate in plans) {
        if (candidate.planId == plan.planId) return candidate;
      }
      return null;
    });
    if (stored == null) return;
    if (!stored._sameFacts(plan)) {
      throw StateError('钱包清理计划事实已变化，请重新读取');
    }

    await WalletIsar.instance.read((isar) async {
      for (final accountId in stored.accountIds) {
        final wallet = await isar.walletProfileEntitys
            .filter()
            .accountIdEqualTo(accountId)
            .findFirst();
        final account = await isar.accountEntitys
            .filter()
            .accountIdEqualTo(accountId)
            .findFirst();
        if (wallet != null || account != null) {
          throw StateError('账户事实仍存在，拒绝执行删除后清理：$accountId');
        }
      }
      final walletIndex = stored.walletIndex;
      if (stored.deleteWalletWideKeys && walletIndex != null) {
        final current = await isar.walletProfileEntitys
            .filter()
            .walletIndexEqualTo(walletIndex)
            .findFirst();
        if (current != null) {
          throw StateError('walletIndex 已被新钱包占用，拒绝执行陈旧安全清理');
        }
      }
    });

    await _cleanupDeletedWalletSecrets(
      walletIndex: stored.walletIndex,
      accountIds: stored.accountIds,
      deleteAccountKeys: stored.deleteAccountKeys,
      deleteWalletWideKeys: stored.deleteWalletWideKeys,
    );
  }

  Future<void> _executeWalletCleanupPlansCore(
    List<WalletCleanupPlan> plans,
  ) async {
    final failures = <String>[];
    for (final plan in plans) {
      try {
        await retryWalletCleanupPlan(plan);
      } on WalletLocalCleanupException catch (error) {
        failures.addAll(error.failures);
      } on Object catch (error) {
        failures.add('钱包清理计划(${plan.planId})：$error');
      }
    }
    if (failures.isNotEmpty) {
      throw WalletLocalCleanupException(List<String>.unmodifiable(failures));
    }
  }

  /// 清除已删除钱包/账户的全部本机秘密。每一项独立尝试，最后统一报告失败。
  ///
  /// [deleteAccountKeys] / [deleteWalletWideKeys] 仅对热钱包为 true：冷钱包没有 child
  /// 或设备子钥。删除当前 CID 绑定账户时同时清除本机绑定元数据；链上 CID 数据不受
  /// 影响。删除单个非末账户时只开 [deleteAccountKeys]，保留整钱包共享子钥。
  Future<void> _cleanupDeletedWalletSecrets({
    required int? walletIndex,
    required Set<String> accountIds,
    required bool deleteAccountKeys,
    required bool deleteWalletWideKeys,
  }) async {
    if ((deleteAccountKeys || deleteWalletWideKeys) && walletIndex == null) {
      throw StateError('热钱包清理计划缺少 walletIndex');
    }
    final failures = <String>[];
    for (final accountId in accountIds) {
      if (deleteAccountKeys) {
        await _attemptWalletCleanup(
          failures,
          '账户私钥($accountId)',
          () => _store.deleteAccountKey(
            walletIndex: walletIndex!,
            accountId: accountId,
          ),
        );
        await _attemptWalletCleanup(
          failures,
          '账户私钥删除复核($accountId)',
          () async {
            if (await _store.hasAccountKey(accountId)) {
              throw StateError('密文仍存在');
            }
          },
        );
      }
    }
    await _clearActiveAccountDataBindingIfOwnedBy(accountIds, failures);
    if (deleteWalletWideKeys) {
      await _deleteWalletWideSecrets(walletIndex!, failures);
    }
    if (failures.isNotEmpty) {
      throw WalletLocalCleanupException(List<String>.unmodifiable(failures));
    }
  }

  Future<void> _clearActiveAccountDataBindingIfOwnedBy(
    Set<String> accountIds,
    List<String> failures,
  ) async {
    var bindings = const <AccountDataBinding>[];
    final readSucceeded = await _attemptWalletCleanup(
      failures,
      'CID 钱包绑定索引',
      () async {
        bindings = await _accountDataBindingStore.readAll();
      },
    );
    if (!readSucceeded) return;
    for (final binding in bindings) {
      if (!accountIds.contains(binding.accountId)) continue;
      final deviceDataDeleted = await _attemptWalletCleanup(
        failures,
        'CID 设备数据钥(${binding.cidNumber})',
        () => _deleteDeviceKeyMaterial(binding),
      );
      final deviceSubkeyDeleted = await _attemptWalletCleanup(
        failures,
        'CID 设备子钥(${binding.cidNumber})',
        () async {
          await _deviceSubkey.delete(binding.cidNumber);
          if (await _deviceSubkey.contains(binding.cidNumber)) {
            throw StateError('硬件子钥仍存在');
          }
        },
      );
      // 两类真实密钥都确认删除后才清公开元数据。任一失败都保留
      // 精确 CID/accountId tombstone，下次重试仍能定位并完成擦除。
      if (deviceDataDeleted && deviceSubkeyDeleted) {
        await _attemptWalletCleanup(
          failures,
          'CID 钱包绑定元数据(${binding.cidNumber})',
          () => _accountDataBindingStore.clearForCid(binding.cidNumber),
        );
      }
    }
  }

  /// 已提交删除事实后的显式安全清理重试入口。绑定元数据作为可定位
  /// tombstone 保留到设备数据钥与 P-256 子钥均删除成功。
  Future<void> retryDeletedAccountDataBindingCleanup(
    Set<String> accountIds,
  ) async {
    final failures = <String>[];
    await _clearActiveAccountDataBindingIfOwnedBy(
      accountIds.map(_normalizeAccountId).toSet(),
      failures,
    );
    if (failures.isNotEmpty) {
      throw WalletLocalCleanupException(List<String>.unmodifiable(failures));
    }
  }

  Future<void> _deleteWalletWideSecrets(
    int walletIndex,
    List<String> failures,
  ) async {
    await _attemptWalletCleanup(
      failures,
      '钱包硬件密钥($walletIndex)',
      () => _store.deleteWalletKey(walletIndex: walletIndex),
    );
    await _attemptWalletCleanup(
      failures,
      '钱包硬件密钥删除复核($walletIndex)',
      () async {
        if (await _store.hasWalletKey(walletIndex: walletIndex)) {
          throw StateError('硬件密钥仍存在');
        }
      },
    );
    await _attemptWalletCleanup(
      failures,
      '设备数据钥密文索引($walletIndex)',
      () => _deleteIndexedDeviceKeyMaterial(walletIndex),
    );
    await _attemptWalletCleanup(
      failures,
      '设备数据钥硬件钥($walletIndex)',
      () async {
        await _deviceDataKeyVault.delete(walletIndex);
        if (await _deviceDataKeyVault.contains(walletIndex)) {
          throw StateError('硬件钥仍存在');
        }
      },
    );
  }

  Future<bool> _attemptWalletCleanup(
    List<String> failures,
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } on Object catch (error) {
      failures.add('$label：$error');
      return false;
    }
  }

  // 更新
  Future<void> renameWallet(int walletIndex, String walletName) =>
      updateWalletDisplay(walletIndex, walletName: walletName);

  /// 重命名单个 `//index` 账户；账户名是本机账户标签，不联动钱包名或用户昵称。
  Future<void> renameAccount(String accountId, String accountName) {
    return _runWalletFactsMutation(
      () => _renameAccountWithinMutation(accountId, accountName),
    );
  }

  Future<void> _renameAccountWithinMutation(
    String accountId,
    String accountName,
  ) async {
    final nextName = accountName.trim();
    if (nextName.isEmpty) {
      throw Exception('账户名称不能为空');
    }
    if (nextName.runes.length > 30) {
      throw Exception('账户名称不能超过30个字符');
    }
    await WalletIsar.instance.writeTxn((isar) async {
      final row = await isar.accountEntitys
          .filter()
          .accountIdEqualTo(accountId)
          .findFirst();
      if (row == null) {
        throw Exception('未找到账户');
      }
      row.accountName = nextName;
      await isar.accountEntitys.put(row);
    });
  }

  Future<void> updateWalletDisplay(
    int walletIndex, {
    String? walletName,
    String? walletIcon,
  }) {
    return _runWalletFactsMutation(
      () => _updateWalletDisplayWithinMutation(
        walletIndex,
        walletName: walletName,
        walletIcon: walletIcon,
      ),
    );
  }

  Future<void> _updateWalletDisplayWithinMutation(
    int walletIndex, {
    String? walletName,
    String? walletIcon,
  }) async {
    if (walletName == null && walletIcon == null) {
      return;
    }

    final nextName = walletName?.trim();
    if (walletName != null && (nextName == null || nextName.isEmpty)) {
      throw Exception('钱包名称不能为空');
    }
    if (walletIcon != null && walletIcon.trim().isEmpty) {
      throw Exception('钱包图标不能为空');
    }

    await WalletIsar.instance.writeTxn((isar) async {
      final row = await isar.walletProfileEntitys
          .filter()
          .walletIndexEqualTo(walletIndex)
          .findFirst();
      if (row == null) {
        throw Exception('未找到钱包');
      }
      if (nextName != null) {
        row.walletName = nextName;
      }
      if (walletIcon != null) {
        row.walletIcon = walletIcon.trim();
      }
      await isar.walletProfileEntitys.put(row);
    });
  }

  /// 仅当钱包事实仍是发起余额 RPC 时的同一代、且索引仍归同一 AccountId 时写入。
  ///
  /// 删除 A 后导入 B 会复用 walletIndex；旧 RPC 只能得到 false，绝不能把 A 的余额
  /// 写进 B。返回值表示本次 CAS 是否实际提交。
  Future<bool> setWalletBalance({
    required int walletIndex,
    required String accountId,
    required int expectedWalletsRevision,
    required double balance,
  }) async {
    return WalletIsar.instance.writeTxn((isar) async {
      if (walletsRevision.value != expectedWalletsRevision) return false;
      final row = await isar.walletProfileEntitys
          .filter()
          .walletIndexEqualTo(walletIndex)
          .and()
          .accountIdEqualTo(accountId)
          .findFirst();
      if (row == null || walletsRevision.value != expectedWalletsRevision) {
        return false;
      }
      row.balance = balance;
      await isar.walletProfileEntitys.put(row);
      return true;
    });
  }

  /// 助记词 → 母种子 → 账户0(`//0`)；母种子派生完成后立即清零。
  ///
  /// 返回的 [_Account0] 持有账户0 的 child mini-secret 与公开身份，供上层存储；
  /// 用完须调 [_Account0.dispose] 清零 child。
  Future<_Account0> _deriveAccount0FromMnemonic(
    String mnemonic, {
    String password = '',
  }) async {
    final seed = await WalletMiniSecret.fromMnemonic(
      mnemonic,
      password: password,
    );
    try {
      return _deriveAccount(seed, 0);
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  /// 从母种子硬派生 `//index` 子密钥的 child mini-secret（32B），逐字节对齐
  /// `derivation_golden_test.dart` 金标与 citizenwallet 冷端。
  /// junction [ChainCode] 由共享真源调用 `substrate_bip39` 官方实现，慢的密码学
  /// 部分交原生 schnorrkel；两款移动产品不再各自复制 junction 编码。
  List<int> _childMiniSecret(List<int> seed, int index) {
    final cc = _hardJunctionChainCode(index);
    final child = NativeSr25519.deriveHard(seed, cc);
    cc.fillRange(0, cc.length, 0);
    return child;
  }

  /// Substrate `//index` 数字硬派生 junction 的官方 32 字节 [ChainCode]。
  List<int> _hardJunctionChainCode(int index) {
    return WalletMiniSecret.hardJunctionChainCode(index);
  }

  /// 母种子 → 账户[index]（child mini-secret + 公开身份）。
  ///
  /// 账户0 = `//0`（无 bare 根）；`fromSeed(childMiniSecret)` 逐字节等于
  /// `<助记词>//index`。账户0 的 accountId 即钱包身份（S7.1 interim identity）。
  _Account0 _deriveAccount(List<int> seed, int index) {
    final child = Uint8List.fromList(_childMiniSecret(seed, index));
    final publicKeyBytes = NativeSr25519.publicKeyOf(child);
    final accountId = _accountIdFromBytes(publicKeyBytes);
    return _Account0(
      childMiniSecret: child,
      accountId: accountId,
      ss58Address: ss58FromAccountIdText(accountId),
    );
  }
  // 签名（child mini-secret 绑定硬件，经 SecureSeedStore；私钥材料不出类）

  /// 用账户0 私钥对 [payload] 签名。
  ///
  /// 资金 / 治理 / 机构类动钱动权（转账 / 投票 / 多签 / 立法表决）走此方法（账户0）;
  /// **身份账户维度签名（发布动态 / CID 注册·换绑 / 订阅 / 创作者）走 [signForAccountId]**
  /// （CID 绑定账户,非恒账户0）。读硬件金库 child 时由硬件 + 生物识别原子解锁（一次操作
  /// 一次验证），派生后用后即弃。广场 / Chat 后台握手统一使用 P-256 设备子钥。
  Future<Uint8List> signWithWallet(int walletIndex, Uint8List payload) async {
    final profile = await _requireHotWalletProfile(walletIndex);
    final vaultStart = DateTime.now();
    final child = await _readAccountKeyOrThrow(
      walletIndex,
      profile.accountId,
    );
    final vaultMs = DateTime.now().difference(vaultStart).inMilliseconds;

    final cpuStart = DateTime.now();
    final signature = _deriveVerifyAndSign(
      childMiniSecret: child,
      expectedAccountId: profile.accountId,
      payload: payload,
      mismatchMessage: '本地签名密钥与当前钱包不一致，请重新导入钱包',
    );
    AppLog.d(
      '[Sign-Diag] 金库读取+生物识别 ${vaultMs}ms, 派生+签名(原生) '
      '${DateTime.now().difference(cpuStart).inMilliseconds}ms',
    );
    return signature;
  }

  /// child MiniSecretKey → 公钥校验 → 签名，走原生 schnorrkel（[NativeSr25519]）。
  ///
  /// 原生是毫秒级，直接在调用线程完成即可，**不需要 Isolate**（纯 Dart 实现曾是
  /// 秒级 CPU，必须离开主线程才不触发 ANR；换原生后 isolate 只剩开销）。
  /// child 明文副本在 finally 里清零，缩短其在堆上的存活窗口。
  static Uint8List _deriveVerifyAndSign({
    required Uint8List childMiniSecret,
    required String expectedAccountId,
    required Uint8List payload,
    required String mismatchMessage,
  }) {
    try {
      if (childMiniSecret.length != 32) {
        throw const WalletAuthException('本地账户 MiniSecretKey 长度异常');
      }
      final publicKey = NativeSr25519.publicKeyOf(childMiniSecret);
      final buffer = StringBuffer('0x');
      for (final byte in publicKey) {
        buffer.write(byte.toRadixString(16).padLeft(2, '0'));
      }
      if (buffer.toString() != expectedAccountId) {
        throw WalletAuthException(mismatchMessage);
      }
      return NativeSr25519.sign(childMiniSecret, payload);
    } finally {
      childMiniSecret.fillRange(0, childMiniSecret.length, 0);
    }
  }

  /// 静默读取当前 CID 的通讯录云端用途钥。
  ///
  /// 已有用途钥从本机设备数据钥金库静默读取；真实通讯录数据访问确认缺钥时才鉴权
  /// 一次生成，页面进入禁止读取钱包账户 child mini-secret。
  Future<ContactKeyMaterial> ensureContactKeyMaterialForAccountId(
    String accountId,
  ) async {
    final active = await _requireActiveAccountDataBinding(accountId);
    final keys = await readDataKeysForBinding(
      active,
      const <({LocalKeyPurpose purpose, String? context})>[
        (purpose: LocalKeyPurpose.contactsCloud, context: 'encryption'),
        (purpose: LocalKeyPurpose.contactsCloud, context: 'index'),
      ],
    );
    return ContactKeyMaterial(encryptionKey: keys[0], indexKey: keys[1]);
  }

  /// 为一次 CID 钱包换绑派生指定绑定版本的通讯录云端密钥。
  ///
  /// [binding] 必须声明同一个 [accountId]；本方法只读取该本机钱包账户自己的 child，
  /// 不接受外部密钥，也不读取当前激活标记。它只供“当前账户可签名时，将此前密文解开后
  /// 立即改用新账户密钥加密”的单次交接使用。
  Future<ContactKeyMaterial> contactKeyMaterialForBinding(
    AccountDataBinding binding,
  ) async {
    final keys = await deriveDataKeysForBindingHandover(
      binding,
      const <({LocalKeyPurpose purpose, String? context})>[
        (purpose: LocalKeyPurpose.contactsCloud, context: 'encryption'),
        (purpose: LocalKeyPurpose.contactsCloud, context: 'index'),
      ],
    );
    return ContactKeyMaterial(encryptionKey: keys[0], indexKey: keys[1]);
  }

  /// 激活 finalized 当前钱包绑定的公开元数据。
  ///
  /// 本方法只验证本机存在该账户并单调保存公开字段，绝不读取钱包账户 child。相同
  /// `account_id` 不能借 revision 变化伪装成换绑；页面进入不得初始化设备子钥。
  Future<void> activateAccountDataBinding({
    required String genesisHash,
    required String cidNumber,
    required int bindingRevision,
    required String accountId,
  }) async {
    final account = await _localAccountFact(accountId);
    if (account == null) {
      throw const WalletAuthException('CID 当前绑定账户不在本机钱包中');
    }
    final binding = AccountDataBinding(
      genesisHash: genesisHash,
      cidNumber: cidNumber,
      bindingRevision: bindingRevision,
      accountId: accountId,
    );
    await _rejectSameAccountRevisionChange(binding);
    await _accountDataBindingStore.activate(binding);
  }

  /// 从本机设备数据钥金库静默读取当前绑定的一把用途钥。
  Future<Uint8List> readDataKeyForCurrentBinding(
    String accountId,
    LocalKeyPurpose purpose, {
    String? context,
  }) async {
    final active = await _requireActiveAccountDataBinding(accountId);
    return (await readDataKeysForBinding(
      active,
      <({LocalKeyPurpose purpose, String? context})>[
        (purpose: purpose, context: context),
      ],
    ))
        .single;
  }

  /// 从本机设备数据钥金库静默读取同一绑定的多把用途钥。
  ///
  /// 已有用途钥直接静默解封；只有实际数据访问发现缺钥或密文已经失效时，才鉴权一次
  /// 生成本地设备数据钥并重试。该流程不创建、不登记 P-256 设备子钥；页面进入和身份
  /// 门禁不得调用本入口预生成密钥。
  Future<List<Uint8List>> readDataKeysForBinding(
    AccountDataBinding binding,
    List<({LocalKeyPurpose purpose, String? context})> requests,
  ) async {
    binding.validate();
    if (requests.isEmpty) {
      throw ArgumentError('私有数据用途列表不能为空');
    }
    if (!await _hasDeviceDataKeyBlobs(binding, requests)) {
      await ensureDeviceDataKeysForBinding(binding);
    }
    try {
      return await _openDeviceDataKeys(binding, requests);
    } on DeviceDataKeyVaultException {
      // 硬件钥被删除、失效或密文损坏时属于真实数据鉴权需求；只重建一次，不循环重试。
      await ensureDeviceDataKeysForBinding(binding, rebuildAll: true);
      return _openDeviceDataKeys(binding, requests);
    }
  }

  Future<List<Uint8List>> _openDeviceDataKeys(
    AccountDataBinding binding,
    List<({LocalKeyPurpose purpose, String? context})> requests,
  ) async {
    final walletIndex = await walletIndexForAccountId(binding.accountId);
    final keys = <Uint8List>[];
    try {
      for (final request in requests) {
        final blob = await _contactKeyStore.read(
          _deviceDataKeyBlobName(binding, request),
        );
        if (blob == null || blob.isEmpty) {
          throw const DeviceDataKeyVaultException('设备用途钥不存在');
        }
        final key = await _deviceDataKeyVault.open(
          walletIndex: walletIndex,
          blob: blob,
          aad: _deviceDataKeyAad(binding, walletIndex, request),
        );
        if (key.length != 32) {
          key.fillRange(0, key.length, 0);
          throw const DeviceDataKeyVaultException('设备用途钥长度无效');
        }
        keys.add(key);
      }
      return keys;
    } catch (_) {
      for (final key in keys) {
        key.fillRange(0, key.length, 0);
      }
      rethrow;
    }
  }

  /// 仅供 CID 正式换绑交接，在用户已经明确确认换绑后派生旧/新绑定用途钥。
  ///
  /// 旧、新账户都必须是本机钱包中的真实账户，
  /// [AccountDataBinding.accountId] 与读取的账户严格相等。一次读取 child 后完成全部
  /// 派生并立即清零。日常 Chat、附件、MLS、通讯录严禁调用本入口。
  Future<List<Uint8List>> deriveDataKeysForBindingHandover(
    AccountDataBinding binding,
    List<({LocalKeyPurpose purpose, String? context})> requests,
  ) async {
    binding.validate();
    if (requests.isEmpty) {
      throw ArgumentError('私有数据用途列表不能为空');
    }
    final accountId = binding.accountId;
    final account = await getAccountByAccountId(accountId);
    if (account == null) {
      throw const WalletAuthException('CID 当前绑定账户不在本机钱包中');
    }
    final profile = await _requireHotWalletProfileByMasterId(account.masterId);
    final child = await _readAccountKeyOrThrow(
      profile.walletIndex,
      accountId,
    );
    final derived = <Uint8List>[];
    try {
      for (final request in requests) {
        derived.add(
          await _accountDataKeyDeriver(
            accountSecret: child,
            binding: binding,
            purpose: request.purpose,
            context: request.context,
          ),
        );
      }
      return derived;
    } catch (_) {
      // 所有权只有在整批成功返回时才交给调用方；中途失败时，已经派生成功的明文
      // 仍归 WalletManager 管理，必须逐一清零，不能等待 GC 或只清账户 child。
      for (final key in derived) {
        key.fillRange(0, key.length, 0);
      }
      rethrow;
    } finally {
      child.fillRange(0, child.length, 0);
    }
  }

  static const List<({LocalKeyPurpose purpose, String? context})>
      _deviceDataKeyRequests = <({LocalKeyPurpose purpose, String? context})>[
    (purpose: LocalKeyPurpose.chat, context: null),
    (purpose: LocalKeyPurpose.chatIndex, context: null),
    (purpose: LocalKeyPurpose.mls, context: null),
    (purpose: LocalKeyPurpose.attachment, context: null),
    (purpose: LocalKeyPurpose.contactsLocal, context: null),
    (purpose: LocalKeyPurpose.contactsCloud, context: 'encryption'),
    (purpose: LocalKeyPurpose.contactsCloud, context: 'index'),
  ];

  /// 实际私有数据访问确认缺少本地设备数据钥时的一次性生成入口。
  ///
  /// 已有全部用途钥直接返回；同一 CID 钱包账户的并发调用全局共享一个 Future，最多
  /// 读取一次 child。该入口绝不调用设备登记后端、Turnstile 或 P-256 子钥；页面门禁
  /// 不得调用。[rebuildAll] 只用于硬件钥失效或密文损坏后的单次全量重建。
  Future<void> ensureDeviceDataKeysForBinding(
    AccountDataBinding binding, {
    bool rebuildAll = false,
  }) {
    binding.validate();
    final flightKey = _deviceKeyFlightKey(binding);
    final existing = _deviceDataKeyInitializationFlights[flightKey];
    if (existing != null) return existing;
    late final Future<void> created;
    created = _ensureDeviceDataKeysForBinding(binding, rebuildAll: rebuildAll)
        .whenComplete(() {
      if (identical(
        _deviceDataKeyInitializationFlights[flightKey],
        created,
      )) {
        _deviceDataKeyInitializationFlights.remove(flightKey);
      }
    });
    _deviceDataKeyInitializationFlights[flightKey] = created;
    return created;
  }

  Future<void> _ensureDeviceDataKeysForBinding(
    AccountDataBinding binding, {
    required bool rebuildAll,
  }) async {
    await _rejectSameAccountRevisionChange(binding);
    final account = await _localAccountFact(binding.accountId);
    if (account == null) {
      throw const WalletAuthException('CID 当前绑定账户不在本机钱包中');
    }
    final walletIndex = account.walletIndex;
    final requests = rebuildAll
        ? _deviceDataKeyRequests
        : await _missingDeviceDataKeyRequests(binding);
    if (requests.isEmpty) return;

    Uint8List? child;
    final writtenBlobNames = <String>[];
    final derived = <Uint8List>[];
    try {
      if (account.signMode == SignMode.hot) {
        child = await _readAccountKeyOrThrow(
          walletIndex,
          binding.accountId,
        );
        if (_accountIdFromBytes(NativeSr25519.publicKeyOf(child)) !=
            binding.accountId) {
          throw const WalletAuthException('本地签名密钥与 CID 当前绑定账户不一致');
        }
        for (final request in requests) {
          derived.add(
            await AccountDataKeyDeriver.derive(
              accountSecret: child,
              binding: binding,
              purpose: request.purpose,
              context: request.context,
            ),
          );
        }
      } else if (account.signMode == SignMode.cold) {
        final provider = _coldAccountDataKeyProvider;
        if (provider == null) {
          throw const WalletAuthException('冷钱包用途钥提供器未配置');
        }
        final provided = await provider(
          binding: binding,
          requests: List.unmodifiable(requests),
        );
        if (provided.length != requests.length ||
            provided.any((key) => key.length != 32)) {
          for (final key in provided) {
            key.fillRange(0, key.length, 0);
          }
          throw const WalletAuthException('冷钱包返回的用途钥清单无效');
        }
        derived.addAll(provided);
      } else {
        throw const WalletAuthException('钱包账户签名模式无效');
      }

      for (var index = 0; index < requests.length; index++) {
        final request = requests[index];
        final key = derived[index];
        final blobName = _deviceDataKeyBlobName(binding, request);
        final blob = await _deviceDataKeyVault.seal(
          walletIndex: walletIndex,
          plaintext: key,
          aad: _deviceDataKeyAad(binding, walletIndex, request),
        );
        await _contactKeyStore.write(blobName, blob);
        writtenBlobNames.add(blobName);
        key.fillRange(0, key.length, 0);
      }

      await _accountDataBindingStore.activate(binding);
      await _recordDeviceKeyMaterialIndex(walletIndex, binding);
    } catch (_) {
      for (final name in writtenBlobNames) {
        await _contactKeyStore.delete(name);
      }
      rethrow;
    } finally {
      for (final key in derived) {
        key.fillRange(0, key.length, 0);
      }
      child?.fillRange(0, child.length, 0);
    }
  }

  /// Worker 明确返回 `device_not_registered` 后登记当前钱包的 P-256 设备子钥。
  ///
  /// 每次收到该错误都按远端真源重新登记；同一绑定的并发登记全局去重且最多读取一次
  /// child。该入口不派生、不封装、不删除任何本地设备数据钥。
  Future<void> registerDeviceSubkeyForBinding(AccountDataBinding binding) {
    binding.validate();
    final flightKey = _deviceKeyFlightKey(binding);
    final existing = _deviceSubkeyRegistrationFlights[flightKey];
    if (existing != null) return existing;
    late final Future<void> created;
    created = _registerDeviceSubkeyForBinding(binding).whenComplete(() {
      if (identical(_deviceSubkeyRegistrationFlights[flightKey], created)) {
        _deviceSubkeyRegistrationFlights.remove(flightKey);
      }
    });
    _deviceSubkeyRegistrationFlights[flightKey] = created;
    return created;
  }

  Future<void> _registerDeviceSubkeyForBinding(
    AccountDataBinding binding,
  ) async {
    await _rejectSameAccountRevisionChange(binding);
    final account = await _localAccountFact(binding.accountId);
    if (account == null) {
      throw const WalletAuthException('CID 当前绑定账户不在本机钱包中');
    }
    final registrar = _subkeyRegistrar;
    if (registrar == null) {
      throw const WalletAuthException('P-256 设备子钥登记器未配置');
    }

    Uint8List? child;
    try {
      if (account.signMode == SignMode.hot) {
        child = await _readAccountKeyOrThrow(
          account.walletIndex,
          binding.accountId,
        );
        final localAccountId = _accountIdFromBytes(
          NativeSr25519.publicKeyOf(child),
        );
        if (localAccountId != binding.accountId) {
          throw const WalletAuthException('本地签名密钥与 CID 当前绑定账户不一致');
        }
      }
      await registrar(
        cidNumber: binding.cidNumber,
        bindingRevision: binding.bindingRevision,
        accountId: binding.accountId,
        signBinding: ({
          required payload,
          required signingMessage,
          required devicePublicKey,
          required issuedAtMillis,
        }) async {
          final localChild = child;
          if (localChild != null) {
            return '0x${_toHex(NativeSr25519.sign(localChild, signingMessage))}';
          }
          final coldSigner = _coldDeviceBindingSigner;
          if (coldSigner == null) {
            throw const WalletAuthException('冷钱包设备绑定签名器未配置');
          }
          return coldSigner(
            binding: binding,
            payload: payload,
            signingMessage: signingMessage,
            devicePublicKey: devicePublicKey,
            issuedAtMillis: issuedAtMillis,
          );
        },
      );
      await _accountDataBindingStore.activate(binding);
      await _recordDeviceKeyMaterialIndex(account.walletIndex, binding);
    } finally {
      child?.fillRange(0, child.length, 0);
    }
  }

  Future<bool> _hasDeviceDataKeyBlobs(
    AccountDataBinding binding,
    List<({LocalKeyPurpose purpose, String? context})> requests,
  ) async {
    for (final request in requests) {
      final blob = await _contactKeyStore.read(
        _deviceDataKeyBlobName(binding, request),
      );
      if (blob == null || blob.isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<List<({LocalKeyPurpose purpose, String? context})>>
      _missingDeviceDataKeyRequests(AccountDataBinding binding) async {
    final missing = <({LocalKeyPurpose purpose, String? context})>[];
    for (final request in _deviceDataKeyRequests) {
      final blob = await _contactKeyStore.read(
        _deviceDataKeyBlobName(binding, request),
      );
      if (blob == null || blob.isEmpty) missing.add(request);
    }
    return missing;
  }

  Future<void> _rejectSameAccountRevisionChange(
    AccountDataBinding binding,
  ) async {
    final active = await _accountDataBindingStore.readForCid(binding.cidNumber);
    if (active != null &&
        active.genesisHash == binding.genesisHash &&
        active.cidNumber == binding.cidNumber &&
        active.accountId == binding.accountId &&
        active.bindingRevision != binding.bindingRevision) {
      throw const WalletAuthException('相同钱包账户不允许通过绑定版本变化重复换绑');
    }
  }

  /// 同一钱包账户不是换绑目标；两类初始化各自去重，均不因 revision 变化重复读取
  /// 同一账户 child。
  static String _deviceKeyFlightKey(AccountDataBinding binding) =>
      '${binding.genesisHash}|${binding.cidNumber}|${binding.accountId}';

  static String _deviceDataKeyBlobName(
    AccountDataBinding binding,
    ({LocalKeyPurpose purpose, String? context}) request,
  ) =>
      'citizenapp_device_data_key_'
      '${Uri.encodeComponent(binding.genesisHash)}_'
      '${Uri.encodeComponent(binding.cidNumber)}_'
      '${binding.bindingRevision}_${binding.accountId}_'
      '${request.purpose.name}_${Uri.encodeComponent(request.context ?? '')}';

  static Uint8List _deviceDataKeyAad(
    AccountDataBinding binding,
    int walletIndex,
    ({LocalKeyPurpose purpose, String? context}) request,
  ) =>
      Uint8List.fromList(
        utf8.encode(
          'wallet_index=$walletIndex|genesis_hash=${binding.genesisHash}|'
          'cid_number=${binding.cidNumber}|binding_revision=${binding.bindingRevision}|'
          'account_id=${binding.accountId}|purpose=${request.purpose.domain}|'
          'context=${request.context ?? ''}',
        ),
      );

  static String _deviceKeyMaterialIndexName(int walletIndex) =>
      'citizenapp_device_key_material_index_$walletIndex';

  Future<void> _recordDeviceKeyMaterialIndex(
    int walletIndex,
    AccountDataBinding binding,
  ) async {
    final name = _deviceKeyMaterialIndexName(walletIndex);
    final existing = <AccountDataBinding>[];
    final raw = await _contactKeyStore.read(name);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final value in decoded.whereType<Map<String, dynamic>>()) {
            final parsed = AccountDataBinding.fromJson(jsonEncode(value));
            if (parsed != null) existing.add(parsed);
          }
        }
      } on FormatException {
        // 索引损坏时由当前真绑定重建，禁止因此回退读取钱包私钥。
      }
    }
    if (!existing.any(
      (item) => _deviceKeyFlightKey(item) == _deviceKeyFlightKey(binding),
    )) {
      existing.add(binding);
    }
    await _contactKeyStore.write(
      name,
      jsonEncode(existing.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _deleteIndexedDeviceKeyMaterial(int walletIndex) async {
    final indexName = _deviceKeyMaterialIndexName(walletIndex);
    final raw = await _contactKeyStore.read(indexName);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw StateError('设备数据钥密文索引不是数组');
      }
      for (final value in decoded) {
        if (value is! Map) {
          throw StateError('设备数据钥密文索引条目无效');
        }
        final binding = AccountDataBinding.fromJson(jsonEncode(value));
        if (binding == null) {
          throw StateError('设备数据钥密文索引绑定损坏');
        }
        await _deleteDeviceKeyMaterial(binding);
      }
    }
    await _contactKeyStore.delete(indexName);
    if (await _contactKeyStore.read(indexName) != null) {
      throw StateError('设备数据钥密文索引仍存在');
    }
  }

  Future<void> _deleteDeviceKeyMaterial(AccountDataBinding binding) async {
    for (final request in _deviceDataKeyRequests) {
      final name = _deviceDataKeyBlobName(binding, request);
      await _contactKeyStore.delete(name);
      if (await _contactKeyStore.read(name) != null) {
        throw StateError('设备数据钥密文仍存在：$name');
      }
    }
  }

  /// 读取指定 CID 的钱包绑定公开元数据；默认账户切换不覆盖其它 CID。
  Future<AccountDataBinding?> readAccountDataBindingForCid(String cidNumber) =>
      _accountDataBindingStore.readForCid(cidNumber);

  /// 按明确 `account_id` 读取本机公开绑定缓存；未命中返回 null。
  ///
  /// 普通页面只允许从当前默认账户调用本入口，禁止扫描其它账户偷换当前用户。
  /// 本入口不读链、不读取钱包 child，也不生成任何用途钥或设备子钥。
  Future<AccountDataBinding?> readAccountDataBindingForAccountId(
    String accountId,
  ) =>
      _accountDataBindingStore.readForAccountId(accountId);

  Future<AccountDataBinding> accountDataBindingForAccountId(String accountId) =>
      _requireActiveAccountDataBinding(accountId);

  /// 记录一次已完成目标密文暂存、等待链上 finalized 的换绑交接。
  /// 这里只保存公开的旧/新绑定上下文，不保存任何密钥或明文。
  Future<void> recordPendingAccountDataHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) =>
      _accountDataBindingStore.writePendingHandover(
        source: source,
        target: target,
      );

  Future<void> markPendingAccountDataHandoverReady({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) =>
      _accountDataBindingStore.markPendingHandoverReady(
        source: source,
        target: target,
      );

  Future<
          ({
            AccountDataBinding source,
            AccountDataBinding target,
            AccountDataHandoverState state,
          })?>
      readPendingAccountDataHandover() =>
          _accountDataBindingStore.readPendingHandover();

  Future<void> clearPendingAccountDataHandover({
    required AccountDataBinding source,
    required AccountDataBinding target,
  }) =>
      _accountDataBindingStore.clearPendingHandover(
        source: source,
        target: target,
      );

  Future<AccountDataBinding> _requireActiveAccountDataBinding(
    String accountId,
  ) async {
    final active = await _accountDataBindingStore.readForAccountId(accountId);
    if (active == null || active.accountId != accountId) {
      throw const WalletAuthException('当前 CID 钱包绑定尚未激活私有数据密钥');
    }
    return active;
  }

  /// 读严档账户0 child → 派生并校验 sr25519 密钥对。
  /// 读严档 child（触发生物识别）；fail-closed（无根 = 无自愈）。
  ///
  /// - 用户取消 / 超时（[AuthCancelled]）、无锁屏（[NoDeviceCredential]）、金库
  ///   不可用（[SecureStoreUnavailable]）直接上抛，由上层文案区分。
  /// - KEK 失效（[SeedKeyInvalidated]）或条目缺失 → 明确报告设备安全存储中的
  ///   私钥不可用；查看私钥流程绝不索要助记词或绕过生物识别。
  Future<Uint8List> _readAccountKeyOrThrow(
    int walletIndex,
    String accountId,
  ) async {
    try {
      final child = await _store.readAccountKey(
        walletIndex: walletIndex,
        accountId: accountId,
      );
      if (child == null) {
        throw const WalletAuthException('设备安全存储中没有该账户私钥');
      }
      if (child.length != 32) {
        child.fillRange(0, child.length, 0);
        throw const WalletAuthException('设备安全存储中的账户 MiniSecretKey 长度异常');
      }
      return child;
    } on SeedKeyInvalidated {
      throw const WalletAuthException('设备安全存储中的账户私钥不可用');
    }
  }

  /// 前置检查：设备必须有锁屏（生物识别 / 数字 / 图案 / PIN），否则拒绝
  /// 创建 / 导入热钱包（D3 fail-closed）。
  Future<void> _ensureDeviceSecure() async {
    final status = await _store.authStatus();
    if (status == SecureAuthStatus.noDeviceLock) {
      throw const WalletAuthException(
        '请先在系统设置中启用屏幕锁定（数字密码、图案或生物识别），才能创建或导入热钱包。',
      );
    }
  }

  // 内部工具
  /// 在当前写事务中检查 AccountId 是否可写。
  ///
  /// 热钱包账户0会同时存在于 `WalletProfileEntity` 与 `AccountEntity`，这是同一个逻辑
  /// 钱包的两张事实表，不是冷热重复；但任何新的冷钱包或热账户都不得复用该 AccountId。
  /// 异常 `signMode`、孤立账户行等损坏事实必须分类为异常，禁止伪装成普通“已存在”。
  Future<void> _ensureAccountIdAvailableInTxn(
    Isar isar,
    String accountId, {
    required SignMode requestedSignMode,
  }) async {
    final normalized = _normalizeAccountId(accountId);
    final pendingCleanupPlans = await _readPendingWalletCleanupPlansInTxn(isar);
    if (pendingCleanupPlans.any(
      (plan) => plan.accountIds.contains(normalized),
    )) {
      throw const WalletAccountConflictException(
        WalletAccountConflictKind.pendingLocalCleanup,
        '该账户的本机删除后清理尚未完成，请先完成清理再导入',
      );
    }
    final profile = await isar.walletProfileEntitys
        .filter()
        .accountIdEqualTo(normalized)
        .findFirst();
    if (profile != null) {
      switch (SignMode.tryParse(profile.signMode)) {
        case SignMode.hot:
          throw WalletAccountConflictException(
            WalletAccountConflictKind.existingHotAccount,
            requestedSignMode == SignMode.cold
                ? '该账户已存在于热钱包中，不能重复保存为冷钱包'
                : '该账户已存在于热钱包中，无需重复添加',
          );
        case SignMode.cold:
          throw WalletAccountConflictException(
            WalletAccountConflictKind.existingColdWallet,
            requestedSignMode == SignMode.hot
                ? '该账户已作为冷钱包存在，不能保存为热钱包账户'
                : '该冷钱包已存在，无需重复导入',
          );
        case null:
          throw const WalletAccountConflictException(
            WalletAccountConflictKind.corruptWalletData,
            '检测到账户数据异常，请先在钱包列表中处理异常记录',
          );
      }
    }

    final account = await isar.accountEntitys
        .filter()
        .accountIdEqualTo(normalized)
        .findFirst();
    if (account == null) return;
    final owner = await isar.walletProfileEntitys
        .filter()
        .masterIdEqualTo(account.masterId)
        .findFirst();
    if (owner == null || SignMode.tryParse(owner.signMode) != SignMode.hot) {
      throw const WalletAccountConflictException(
        WalletAccountConflictKind.corruptWalletData,
        '检测到账户数据异常，请先在钱包列表中处理异常记录',
      );
    }
    throw WalletAccountConflictException(
      WalletAccountConflictKind.existingHotAccount,
      requestedSignMode == SignMode.cold
          ? '该账户已存在于热钱包中，不能重复保存为冷钱包'
          : '该账户已存在于热钱包中，无需重复添加',
    );
  }

  /// 原子化创建热钱包：在同一个事务中分配 walletIndex 并写入数据库，
  /// 事务成功后再把账户0 的 child mini-secret 写入 secure storage，避免并发时
  /// index 冲突或密钥覆盖。
  Future<WalletProfile> _appendHotWalletAtomic({
    required _Account0 account0,
    required String source,
  }) async {
    final ss58Address = account0.ss58Address;
    final accountId = account0.accountId;
    late int walletIndex;
    late int createdAtMillis;
    await WalletIsar.instance.writeTxn((isar) async {
      final rows =
          await isar.walletProfileEntitys.where().sortByWalletIndex().findAll();
      // 事务外预查只负责尽早提示；最终唯一性必须与写入处于同一事务。两个并发
      // create/import 即使都通过预查，也只能有一个事务提交热钱包。
      if (rows.any((row) => SignMode.tryParse(row.signMode) == null)) {
        throw const WalletAuthException('存在签名模式异常的钱包，请先验证或删除该钱包');
      }
      if (rows.any(
        (row) => SignMode.tryParse(row.signMode) == SignMode.hot,
      )) {
        throw Exception('本设备已存在热钱包,一台设备仅支持一个热钱包');
      }
      final used = rows.map((e) => e.walletIndex).toSet();
      final pendingCleanupPlans =
          await _readPendingWalletCleanupPlansInTxn(isar);
      used.addAll(
        pendingCleanupPlans
            .where((plan) => plan.deleteWalletWideKeys)
            .map((plan) => plan.walletIndex)
            .whereType<int>(),
      );
      walletIndex = 1;
      while (used.contains(walletIndex)) {
        walletIndex++;
      }
      createdAtMillis = DateTime.now().millisecondsSinceEpoch;

      final normalizedAccountId = _normalizeAccountId(accountId);
      await _ensureAccountIdAvailableInTxn(
        isar,
        normalizedAccountId,
        requestedSignMode: SignMode.hot,
      );
      final entity = WalletProfileEntity()
        ..walletIndex = walletIndex
        ..walletName = _defaultWalletName(walletIndex)
        ..walletIcon = _defaultWalletIcon()
        ..balance = 0
        ..ss58Address = ss58Address
        ..accountId = normalizedAccountId
        ..masterId = normalizedAccountId
        ..alg = 'sr25519'
        ..ss58 = kGmbSs58Prefix
        ..createdAtMillis = createdAtMillis
        ..source = source
        ..signMode = SignMode.hot.name;
      await isar.walletProfileEntitys.put(entity);

      // 账户0(`//0`)与钱包同事务落库,masterId = 账户0.accountId;它是锚点,
      // 让账户0 也出现在 getAccounts,并成为后续追加账户的 masterId 归属。
      final account0Entity = AccountEntity()
        ..masterId = normalizedAccountId
        ..accountIndex = 0
        ..accountId = normalizedAccountId
        ..ss58Address = ss58Address
        ..accountName = _defaultAccountName(0)
        ..createdAtMillis = createdAtMillis;
      await isar.accountEntitys.put(account0Entity);

      final settings = await _getSettingsInTxn(isar);
      settings.activeWalletIndex = walletIndex;
      settings.orderedAccountIds = <String>[
        ...settings.orderedAccountIds.where((id) => id != normalizedAccountId),
        normalizedAccountId,
      ];
      settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      await isar.walletSettingsEntitys.put(settings);
    });

    final normalizedAccountId = _normalizeAccountId(accountId);
    final profile = WalletProfile(
      walletIndex: walletIndex,
      walletName: _defaultWalletName(walletIndex),
      walletIcon: _defaultWalletIcon(),
      balance: 0,
      ss58Address: ss58Address,
      accountId: normalizedAccountId,
      alg: 'sr25519',
      ss58: kGmbSs58Prefix,
      createdAtMillis: createdAtMillis,
      source: source,
      signMode: SignMode.hot,
    );
    try {
      await _store.putAccountKey(
        walletIndex: walletIndex,
        accountId: normalizedAccountId,
        childMiniSecret: account0.childMiniSecret,
      );
      await _verifyWalletPersisted(profile);
    } catch (_) {
      await _rollbackWalletCreation(walletIndex);
      rethrow;
    }
    return profile;
  }

  /// 原子化创建冷钱包：在同一个事务中分配 walletIndex 并写入数据库。
  Future<WalletProfile> _appendColdWalletAtomic({
    required String ss58Address,
    required String accountId,
  }) async {
    late int walletIndex;
    late int createdAtMillis;
    await WalletIsar.instance.writeTxn((isar) async {
      final rows =
          await isar.walletProfileEntitys.where().sortByWalletIndex().findAll();
      final used = rows.map((e) => e.walletIndex).toSet();
      final pendingCleanupPlans =
          await _readPendingWalletCleanupPlansInTxn(isar);
      used.addAll(
        pendingCleanupPlans
            .where((plan) => plan.deleteWalletWideKeys)
            .map((plan) => plan.walletIndex)
            .whereType<int>(),
      );
      walletIndex = 1;
      while (used.contains(walletIndex)) {
        walletIndex++;
      }
      createdAtMillis = DateTime.now().millisecondsSinceEpoch;

      final normalizedAccountId = _normalizeAccountId(accountId);
      await _ensureAccountIdAvailableInTxn(
        isar,
        normalizedAccountId,
        requestedSignMode: SignMode.cold,
      );
      final entity = WalletProfileEntity()
        ..walletIndex = walletIndex
        ..walletName = _defaultWalletName(walletIndex)
        ..walletIcon = _defaultWalletIcon()
        ..balance = 0
        ..ss58Address = ss58Address
        ..accountId = normalizedAccountId
        // 冷钱包无派生概念,masterId 亦取其 accountId,保持 masterId 字段全表非空。
        ..masterId = normalizedAccountId
        ..alg = 'sr25519'
        ..ss58 = kGmbSs58Prefix
        ..createdAtMillis = createdAtMillis
        ..source = 'imported'
        ..signMode = SignMode.cold.name;
      await isar.walletProfileEntitys.put(entity);

      final settings = await _getSettingsInTxn(isar);
      settings.activeWalletIndex = walletIndex;
      settings.orderedAccountIds = <String>[
        ...settings.orderedAccountIds.where((id) => id != normalizedAccountId),
        normalizedAccountId,
      ];
      settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      await isar.walletSettingsEntitys.put(settings);
    });

    final profile = WalletProfile(
      walletIndex: walletIndex,
      walletName: _defaultWalletName(walletIndex),
      walletIcon: _defaultWalletIcon(),
      balance: 0,
      ss58Address: ss58Address,
      accountId: _normalizeAccountId(accountId),
      alg: 'sr25519',
      ss58: kGmbSs58Prefix,
      createdAtMillis: createdAtMillis,
      source: 'imported',
      signMode: SignMode.cold,
    );
    try {
      await _verifyWalletPersisted(profile);
    } on Object {
      // 事务后复核本身可因瞬时读错失败；此时不能把已提交的冷钱包伪装
      // 成“导入失败”。再用真实事实独立读取一次；精确命中即按已提交处理。
      final persisted = await getWalletByIndex(walletIndex);
      if (persisted == null || persisted.accountId != profile.accountId) {
        rethrow;
      }
      return persisted;
    }
    return profile;
  }

  /// 只能在已经进入写事务时调用；这里绝不再开启嵌套 writeTxn。
  Future<WalletSettingsEntity> _getSettingsInTxn(Isar isar) async {
    final row = await isar.walletSettingsEntitys.get(0);
    if (row != null) {
      return row;
    }
    final created = WalletSettingsEntity()
      ..id = 0
      ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    await isar.walletSettingsEntitys.put(created);
    return created;
  }

  Future<WalletProfile> _requireHotWalletProfile(int walletIndex) async {
    final row = await WalletIsar.instance.read((isar) {
      return isar.walletProfileEntitys
          .filter()
          .walletIndexEqualTo(walletIndex)
          .findFirst();
    });
    if (row == null) {
      throw const WalletAuthException('未找到指定钱包');
    }
    final profile = _toProfile(row);
    if (profile.signMode != SignMode.hot) {
      throw const WalletAuthException(
        '当前钱包不是可用热钱包，无法使用本机私钥签名',
      );
    }
    return profile;
  }

  /// 创建/导入完成后立即复读本地库，防止 UI 已展示助记词但
  /// 钱包索引没有真正落库；失败时上层会回滚并提示用户重试。
  Future<void> _verifyWalletPersisted(WalletProfile profile) async {
    final testVerifier = debugWalletPersistedVerifier;
    if (testVerifier != null) {
      await testVerifier(profile);
      return;
    }
    final persisted = await getWalletByIndex(profile.walletIndex);
    if (persisted == null || persisted.accountId != profile.accountId) {
      throw Exception('钱包写入后校验失败，请重试');
    }
    // 冷钱包只保存公开 AccountId/SS58，不得虚构账户私钥或硬件 KEK。只有本机热钱包
    // 才必须同时复核账户密文与钱包作用域硬件密钥。
    if (profile.isHotWallet &&
        (!await _store.hasAccountKey(profile.accountId) ||
            !await _store.hasWalletKey(walletIndex: profile.walletIndex))) {
      throw Exception('钱包硬件机密写入后校验失败，请重试');
    }
    // 只复核密文与硬件 KEK 存在性，不解密，因此不会额外触发生物识别。
  }

  Future<void> _rollbackWalletCreation(int walletIndex) async {
    final row = await WalletIsar.instance.read((isar) => isar
        .walletProfileEntitys
        .filter()
        .walletIndexEqualTo(walletIndex)
        .findFirst());
    if (row == null) return;

    final failures = <String>[];
    await _attemptWalletCleanup(
      failures,
      '创建回滚账户私钥(${row.accountId})',
      () => _store.deleteAccountKey(
        walletIndex: walletIndex,
        accountId: row.accountId,
      ),
    );
    await _attemptWalletCleanup(
      failures,
      '创建回滚账户私钥删除复核(${row.accountId})',
      () async {
        if (await _store.hasAccountKey(row.accountId)) {
          throw StateError('密文仍存在');
        }
      },
    );
    await _attemptWalletCleanup(
      failures,
      '创建回滚钱包硬件密钥($walletIndex)',
      () => _store.deleteWalletKey(walletIndex: walletIndex),
    );
    await _attemptWalletCleanup(
      failures,
      '创建回滚钱包硬件密钥删除复核($walletIndex)',
      () async {
        if (await _store.hasWalletKey(walletIndex: walletIndex)) {
          throw StateError('硬件密钥仍存在');
        }
      },
    );
    if (failures.isNotEmpty) {
      throw WalletLocalCleanupException(List<String>.unmodifiable(failures));
    }

    await WalletIsar.instance.writeTxn((isar) async {
      final persisted = await isar.walletProfileEntitys
          .filter()
          .walletIndexEqualTo(walletIndex)
          .findFirst();
      if (persisted != null) {
        await isar.walletProfileEntitys.delete(persisted.id);
        await isar.accountEntitys
            .filter()
            .masterIdEqualTo(persisted.masterId)
            .deleteAll();
      }
      final settings = await _getSettingsInTxn(isar);
      if (settings.activeWalletIndex == walletIndex) {
        final remains = await isar.walletProfileEntitys
            .where()
            .sortByWalletIndex()
            .findAll();
        settings.activeWalletIndex =
            remains.isEmpty ? null : remains.last.walletIndex;
        settings.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
        await isar.walletSettingsEntitys.put(settings);
      }
    });
  }

  String _toHex(List<int> bytes) {
    const chars = '0123456789abcdef';
    final buf = StringBuffer();
    for (final b in bytes) {
      buf
        ..write(chars[(b >> 4) & 0x0f])
        ..write(chars[b & 0x0f]);
    }
    return buf.toString();
  }

  /// 公开 `AccountId` 文本转字节；不得用于钱包私钥或 MiniSecretKey。
  Uint8List _hexToBytes(String input) {
    final text = input.startsWith('0x') ? input.substring(2) : input;
    if (text.isEmpty || text.length.isOdd) return Uint8List(0);
    return Uint8List.fromList(
      List<int>.generate(
        text.length ~/ 2,
        (index) => int.parse(
          text.substring(index * 2, index * 2 + 2),
          radix: 16,
        ),
      ),
    );
  }

  String _accountIdFromBytes(List<int> bytes) {
    if (bytes.length != 32) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        '账户 ID 必须是 32 字节',
      );
    }
    return '0x${_toHex(bytes)}';
  }

  String _normalizeAccountId(String value) {
    if (!isAccountIdText(value)) {
      throw ArgumentError.value(
        value,
        'accountId',
        '账户 ID 必须是小写 0x 加 64 位十六进制',
      );
    }
    return value;
  }

  String _defaultWalletName(int walletIndex) {
    return '钱包$walletIndex';
  }

  String _defaultWalletIcon() {
    return 'wallet';
  }

  WalletProfile _toProfile(WalletProfileEntity row) {
    return WalletProfile(
      walletIndex: row.walletIndex,
      walletName: row.walletName,
      walletIcon: row.walletIcon,
      balance: row.balance,
      ss58Address: row.ss58Address,
      accountId: row.accountId,
      alg: row.alg,
      ss58: row.ss58,
      createdAtMillis: row.createdAtMillis,
      source: row.source,
      signMode: SignMode.tryParse(row.signMode),
    );
  }
}

/// 账户0(`//0`) 派生结果（ROOTLESS）：持有 child mini-secret 与公开身份。
///
/// [childMiniSecret] 是可清零的 [Uint8List]（明文私钥材料），上层用完须调
/// [dispose] 立即清零，缩短明文在内存中的存活窗口。
class _Account0 {
  _Account0({
    required this.childMiniSecret,
    required this.ss58Address,
    required this.accountId,
  });

  final Uint8List childMiniSecret;
  final String ss58Address;
  final String accountId;

  /// 清零 child mini-secret 明文。
  void dispose() {
    childMiniSecret.fillRange(0, childMiniSecret.length, 0);
  }
}

/// 把钱包侧的 [VaultBlobStore] 适配成 `lib/security` 的 [LocalKeyBlobStore]。
///
/// 方向固定为「钱包依赖安全基座」：基座不反向依赖钱包模块，便于独立单测。
class _LocalKeyBlobStoreAdapter implements LocalKeyBlobStore {
  const _LocalKeyBlobStoreAdapter(this._inner);

  final VaultBlobStore _inner;

  @override
  Future<String?> read(String key) {
    if (key != AccountDataBindingStore.pendingHandoverKey) {
      return _inner.read(key);
    }
    return WalletIsar.instance.read((isar) async {
      final row = await isar.walletAccountDataHandoverEntitys.get(0);
      return row?.payloadJson;
    });
  }

  @override
  Future<void> write(String key, String value) {
    if (key != AccountDataBindingStore.pendingHandoverKey) {
      return _inner.write(key, value);
    }
    return WalletIsar.instance.writeTxn((isar) async {
      await isar.walletAccountDataHandoverEntitys.put(
        WalletAccountDataHandoverEntity()
          ..id = 0
          ..payloadJson = value,
      );
    });
  }

  @override
  Future<void> delete(String key) {
    if (key != AccountDataBindingStore.pendingHandoverKey) {
      return _inner.delete(key);
    }
    return WalletIsar.instance.writeTxn((isar) async {
      await isar.walletAccountDataHandoverEntitys.delete(0);
    });
  }

  @override
  Future<bool> compareAndSet(
    String key, {
    required String? expected,
    String? next,
  }) {
    if (key != AccountDataBindingStore.pendingHandoverKey) {
      throw UnsupportedError('只有钱包换绑交接记录支持原子比较写入');
    }
    return WalletIsar.instance.writeTxn((isar) async {
      final current = await isar.walletAccountDataHandoverEntitys.get(0);
      if (expected == null
          ? current != null
          : current?.payloadJson != expected) {
        return false;
      }
      if (next == null) {
        await isar.walletAccountDataHandoverEntitys.delete(0);
      } else {
        await isar.walletAccountDataHandoverEntitys.put(
          WalletAccountDataHandoverEntity()
            ..id = 0
            ..payloadJson = next,
        );
      }
      return true;
    });
  }
}
