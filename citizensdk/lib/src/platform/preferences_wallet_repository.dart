import 'dart:async';
import 'dart:convert';

import '../wallet/models.dart';
import '../wallet/wallet_error.dart';
import '../wallet/wallet_repository.dart';
import 'preferences_data_store.dart';

export 'preferences_data_store.dart';

/// 只持久化钱包公开事实、秘密写入计划、active cleanup 和精确补偿队列。
///
/// 同一 Dart isolate 内的所有仓储实例通过静态队列串行变更，并以
/// 持久 revision 执行 compare-and-swap。SharedPreferences 不提供
/// 跨 isolate 的 CAS；需要该范围的调用方必须同时提供强原子仓储与覆盖
/// 整个钱包操作的单写协调。
final class PreferencesWalletRepository implements WalletRepository {
  PreferencesWalletRepository({PreferencesDataStore? preferences})
    : _preferences = preferences ?? SharedPreferencesDataStore();

  static const String storageKey = 'citizensdk.wallet.state.v1';
  static const String schema = 'citizen_sdk.wallet.state.v1';

  final PreferencesDataStore _preferences;
  static Future<void> _mutationTail = Future<void>.value();

  @override
  Future<WalletState> load() async {
    final raw = await _preferences.getString(storageKey);
    if (raw == null) return const WalletState.empty();
    return _decode(raw);
  }

  @override
  Future<WalletState> commit({
    required int expectedRevision,
    required WalletProfile? profile,
    required WalletProvisioningPlan? provisioning,
    required WalletCleanupPlan? cleanup,
    required List<WalletCleanupPlan> cleanupQueue,
  }) => _serialize(() async {
    final current = await load();
    if (current.revision != expectedRevision) {
      throw const WalletRepositoryConflict();
    }
    final next = WalletState(
      revision: current.revision + 1,
      profile: profile,
      provisioning: provisioning,
      cleanup: cleanup,
      cleanupQueue: cleanupQueue,
    );
    final encoded = _encode(next);
    Object? writeError;
    StackTrace? writeStackTrace;
    try {
      await _preferences.setString(storageKey, encoded);
    } on Object catch (error, stackTrace) {
      // SharedPreferences 或平台通道可能先完成写入再报告错误；
      // 最终结果只能由持久事实决定，不能由调用返回路径决定。
      writeError = error;
      writeStackTrace = stackTrace;
    }

    String? persistedRaw;
    try {
      persistedRaw = await _preferences.getString(storageKey);
    } on Object catch (readError, readStackTrace) {
      if (writeError != null) {
        Error.throwWithStackTrace(writeError, writeStackTrace!);
      }
      Error.throwWithStackTrace(readError, readStackTrace);
    }

    if (persistedRaw != encoded) {
      if (writeError != null) {
        Error.throwWithStackTrace(writeError, writeStackTrace!);
      }
      // 写调用正常返回但完整回读不同，说明其它写者胜出或后端
      // 违反写后可读合同。
      throw const WalletRepositoryConflict();
    }

    // 返回精确持久字节的解码结果，而不是内存候选，禁止确认
    // 畸形或截断写入。
    return _decode(persistedRaw!);
  });

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final previous = _mutationTail;
    _mutationTail = () async {
      try {
        await previous;
      } on Object {
        // 前一次失败不能永久污染后续变更队列。
      }
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  static String _encode(WalletState state) => jsonEncode(<String, Object?>{
    'schema': schema,
    'revision': state.revision,
    'profile': _encodeProfile(state.profile),
    'provisioning': _encodeProvisioning(state.provisioning),
    'cleanup': _encodeCleanup(state.cleanup),
    'cleanup_queue': state.cleanupQueue
        .map(_encodeCleanup)
        .toList(growable: false),
  });

  static Map<String, Object?>? _encodeProfile(WalletProfile? profile) {
    if (profile == null) return null;
    return <String, Object?>{
      'wallet_index': profile.walletIndex,
      'wallet_generation': profile.walletGeneration,
      'master_account_id': profile.masterAccountId,
      'origin': profile.origin.name,
      'created_at_millis': profile.createdAtMillis,
      'active_account_id': profile.activeAccountId,
      'accounts': profile.accounts
          .map(
            (account) => <String, Object>{
              'index': account.index,
              'account_id': account.accountId,
              'secret_owner': account.secretOwner,
              'ss58_address': account.ss58Address,
              'name': account.name,
              'created_at_millis': account.createdAtMillis,
            },
          )
          .toList(growable: false),
    };
  }

  static Map<String, Object?>? _encodeProvisioning(
    WalletProvisioningPlan? provisioning,
  ) {
    if (provisioning == null) return null;
    return <String, Object?>{
      'operation_id': provisioning.operationId,
      'wallet_index': provisioning.walletIndex,
      'wallet_generation': provisioning.walletGeneration,
      'previous_profile': _encodeProfile(provisioning.previousProfile),
      'secret_refs': provisioning.secretRefs
          .map(_encodeSecretRef)
          .toList(growable: false),
      'delete_wallet_key_on_rollback': provisioning.deleteWalletKeyOnRollback,
    };
  }

  static Map<String, Object?>? _encodeCleanup(WalletCleanupPlan? cleanup) {
    if (cleanup == null) return null;
    return <String, Object?>{
      'operation_id': cleanup.operationId,
      'wallet_index': cleanup.walletIndex,
      'wallet_generation': cleanup.walletGeneration,
      'secret_refs': cleanup.secretRefs
          .map(_encodeSecretRef)
          .toList(growable: false),
      'delete_wallet_key': cleanup.deleteWalletKey,
    };
  }

  static Map<String, Object> _encodeSecretRef(WalletSecretRef ref) =>
      <String, Object>{
        'wallet_generation': ref.walletGeneration,
        'secret_owner': ref.secretOwner,
        'account_id': ref.accountId,
      };

  static WalletState _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final root = _strictMap(decoded, const <String>{
        'schema',
        'revision',
        'profile',
        'provisioning',
        'cleanup',
        'cleanup_queue',
      }, '钱包状态');
      if (root['schema'] != schema || root['revision'] is! int) {
        throw const FormatException('钱包状态 schema 或 revision 无效');
      }
      final revision = root['revision']! as int;
      if (revision < 0) throw const FormatException('钱包状态 revision 无效');
      return WalletState(
        revision: revision,
        profile: _decodeProfile(root['profile']),
        provisioning: _decodeProvisioning(root['provisioning']),
        cleanup: _decodeCleanup(root['cleanup']),
        cleanupQueue: _decodeCleanupQueue(root['cleanup_queue']),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('钱包公开状态 JSON 无效');
    }
  }

  static WalletProfile? _decodeProfile(Object? value) {
    if (value == null) return null;
    final map = _strictMap(value, const <String>{
      'wallet_index',
      'wallet_generation',
      'master_account_id',
      'origin',
      'created_at_millis',
      'active_account_id',
      'accounts',
    }, '钱包资料');
    final walletIndex = map['wallet_index'];
    final walletGeneration = map['wallet_generation'];
    final masterAccountId = map['master_account_id'];
    final originName = map['origin'];
    final createdAtMillis = map['created_at_millis'];
    final activeAccountId = map['active_account_id'];
    final accountsValue = map['accounts'];
    if (walletIndex is! int ||
        walletGeneration is! String ||
        masterAccountId is! String ||
        originName is! String ||
        createdAtMillis is! int ||
        activeAccountId is! String ||
        accountsValue is! List<Object?>) {
      throw const FormatException('钱包资料字段类型无效');
    }
    final origin = WalletOrigin.values.where(
      (entry) => entry.name == originName,
    );
    if (origin.length != 1) throw const FormatException('钱包来源无效');
    final accounts = accountsValue.map(_decodeAccount).toList(growable: false);
    return WalletProfile(
      walletIndex: walletIndex,
      walletGeneration: walletGeneration,
      masterAccountId: masterAccountId,
      origin: origin.single,
      createdAtMillis: createdAtMillis,
      activeAccountId: activeAccountId,
      accounts: List<WalletAccount>.unmodifiable(accounts),
    );
  }

  static WalletAccount _decodeAccount(Object? value) {
    final map = _strictMap(value, const <String>{
      'index',
      'account_id',
      'secret_owner',
      'ss58_address',
      'name',
      'created_at_millis',
    }, '钱包账户');
    final index = map['index'];
    final accountId = map['account_id'];
    final secretOwner = map['secret_owner'];
    final ss58Address = map['ss58_address'];
    final name = map['name'];
    final createdAtMillis = map['created_at_millis'];
    if (index is! int ||
        accountId is! String ||
        secretOwner is! String ||
        ss58Address is! String ||
        name is! String ||
        createdAtMillis is! int) {
      throw const FormatException('钱包账户字段类型无效');
    }
    return WalletAccount(
      index: index,
      accountId: accountId,
      secretOwner: secretOwner,
      ss58Address: ss58Address,
      name: name,
      createdAtMillis: createdAtMillis,
    );
  }

  static WalletProvisioningPlan? _decodeProvisioning(Object? value) {
    if (value == null) return null;
    final map = _strictMap(value, const <String>{
      'operation_id',
      'wallet_index',
      'wallet_generation',
      'previous_profile',
      'secret_refs',
      'delete_wallet_key_on_rollback',
    }, '钱包 provision 计划');
    final operationId = map['operation_id'];
    final walletIndex = map['wallet_index'];
    final walletGeneration = map['wallet_generation'];
    final refsValue = map['secret_refs'];
    final deleteWalletKeyOnRollback = map['delete_wallet_key_on_rollback'];
    if (operationId is! String ||
        walletIndex is! int ||
        walletGeneration is! String ||
        refsValue is! List<Object?> ||
        deleteWalletKeyOnRollback is! bool) {
      throw const FormatException('钱包 provision 计划字段类型无效');
    }
    return WalletProvisioningPlan(
      operationId: operationId,
      walletIndex: walletIndex,
      walletGeneration: walletGeneration,
      previousProfile: _decodeProfile(map['previous_profile']),
      secretRefs: List<WalletSecretRef>.unmodifiable(
        refsValue.map(_decodeSecretRef),
      ),
      deleteWalletKeyOnRollback: deleteWalletKeyOnRollback,
    );
  }

  static WalletCleanupPlan? _decodeCleanup(Object? value) {
    if (value == null) return null;
    final map = _strictMap(value, const <String>{
      'operation_id',
      'wallet_index',
      'wallet_generation',
      'secret_refs',
      'delete_wallet_key',
    }, '钱包清理计划');
    final operationId = map['operation_id'];
    final walletIndex = map['wallet_index'];
    final walletGeneration = map['wallet_generation'];
    final refsValue = map['secret_refs'];
    final deleteWalletKey = map['delete_wallet_key'];
    if (operationId is! String ||
        walletIndex is! int ||
        walletGeneration is! String ||
        refsValue is! List<Object?> ||
        deleteWalletKey is! bool) {
      throw const FormatException('钱包清理计划字段类型无效');
    }
    return WalletCleanupPlan(
      operationId: operationId,
      walletIndex: walletIndex,
      walletGeneration: walletGeneration,
      secretRefs: List<WalletSecretRef>.unmodifiable(
        refsValue.map(_decodeSecretRef),
      ),
      deleteWalletKey: deleteWalletKey,
    );
  }

  static List<WalletCleanupPlan> _decodeCleanupQueue(Object? value) {
    if (value is! List<Object?>) {
      throw const FormatException('钱包清理队列字段类型无效');
    }
    return List<WalletCleanupPlan>.unmodifiable(
      value.map((entry) {
        final cleanup = _decodeCleanup(entry);
        if (cleanup == null) {
          throw const FormatException('钱包清理队列元素无效');
        }
        return cleanup;
      }),
    );
  }

  static WalletSecretRef _decodeSecretRef(Object? value) {
    final map = _strictMap(value, const <String>{
      'wallet_generation',
      'secret_owner',
      'account_id',
    }, '钱包秘密引用');
    final walletGeneration = map['wallet_generation'];
    final secretOwner = map['secret_owner'];
    final accountId = map['account_id'];
    if (walletGeneration is! String ||
        secretOwner is! String ||
        accountId is! String) {
      throw const FormatException('钱包秘密引用字段类型无效');
    }
    return WalletSecretRef(
      walletGeneration: walletGeneration,
      secretOwner: secretOwner,
      accountId: accountId,
    );
  }

  static Map<String, dynamic> _strictMap(
    Object? value,
    Set<String> keys,
    String label,
  ) {
    if (value is! Map<String, dynamic> ||
        value.length != keys.length ||
        !keys.every(value.containsKey)) {
      throw FormatException('$label字段集合无效');
    }
    return value;
  }
}
