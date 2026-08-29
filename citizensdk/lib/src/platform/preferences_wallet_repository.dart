import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../wallet/models.dart';
import '../wallet/wallet_error.dart';
import '../wallet/wallet_repository.dart';

/// Minimal string preferences contract used by persistence adapters and tests.
abstract interface class PreferencesDataStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

final class SharedPreferencesDataStore implements PreferencesDataStore {
  SharedPreferencesDataStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Persists only wallet public facts and the crash-recovery cleanup plan.
///
/// Mutations across repository instances in the same Dart isolate are
/// serialized and use the persisted revision as compare-and-swap.
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
    required WalletCleanupPlan? cleanup,
  }) => _serialize(() async {
    final current = await load();
    if (current.revision != expectedRevision) {
      throw const WalletRepositoryConflict();
    }
    final next = WalletState(
      revision: current.revision + 1,
      profile: profile,
      cleanup: cleanup,
    );
    await _preferences.setString(storageKey, _encode(next));
    return next;
  });

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final previous = _mutationTail;
    _mutationTail = () async {
      try {
        await previous;
      } on Object {
        // A prior operation must not permanently poison the queue.
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
    'cleanup': _encodeCleanup(state.cleanup),
  });

  static Map<String, Object?>? _encodeProfile(WalletProfile? profile) {
    if (profile == null) return null;
    return <String, Object?>{
      'wallet_index': profile.walletIndex,
      'master_account_id': profile.masterAccountId,
      'origin': profile.origin.name,
      'created_at_millis': profile.createdAtMillis,
      'active_account_id': profile.activeAccountId,
      'accounts': profile.accounts
          .map(
            (account) => <String, Object>{
              'index': account.index,
              'account_id': account.accountId,
              'ss58_address': account.ss58Address,
              'name': account.name,
              'created_at_millis': account.createdAtMillis,
            },
          )
          .toList(growable: false),
    };
  }

  static Map<String, Object?>? _encodeCleanup(WalletCleanupPlan? cleanup) {
    if (cleanup == null) return null;
    return <String, Object?>{
      'wallet_index': cleanup.walletIndex,
      'account_ids': cleanup.accountIds,
      'delete_wallet_key': cleanup.deleteWalletKey,
    };
  }

  static WalletState _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final root = _strictMap(decoded, const <String>{
        'schema',
        'revision',
        'profile',
        'cleanup',
      }, '钱包状态');
      if (root['schema'] != schema || root['revision'] is! int) {
        throw const FormatException('钱包状态 schema 或 revision 无效');
      }
      final revision = root['revision']! as int;
      if (revision < 0) throw const FormatException('钱包状态 revision 无效');
      return WalletState(
        revision: revision,
        profile: _decodeProfile(root['profile']),
        cleanup: _decodeCleanup(root['cleanup']),
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
      'master_account_id',
      'origin',
      'created_at_millis',
      'active_account_id',
      'accounts',
    }, '钱包资料');
    final walletIndex = map['wallet_index'];
    final masterAccountId = map['master_account_id'];
    final originName = map['origin'];
    final createdAtMillis = map['created_at_millis'];
    final activeAccountId = map['active_account_id'];
    final accountsValue = map['accounts'];
    if (walletIndex is! int ||
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
      'ss58_address',
      'name',
      'created_at_millis',
    }, '钱包账户');
    final index = map['index'];
    final accountId = map['account_id'];
    final ss58Address = map['ss58_address'];
    final name = map['name'];
    final createdAtMillis = map['created_at_millis'];
    if (index is! int ||
        accountId is! String ||
        ss58Address is! String ||
        name is! String ||
        createdAtMillis is! int) {
      throw const FormatException('钱包账户字段类型无效');
    }
    return WalletAccount(
      index: index,
      accountId: accountId,
      ss58Address: ss58Address,
      name: name,
      createdAtMillis: createdAtMillis,
    );
  }

  static WalletCleanupPlan? _decodeCleanup(Object? value) {
    if (value == null) return null;
    final map = _strictMap(value, const <String>{
      'wallet_index',
      'account_ids',
      'delete_wallet_key',
    }, '钱包清理计划');
    final walletIndex = map['wallet_index'];
    final accountIdsValue = map['account_ids'];
    final deleteWalletKey = map['delete_wallet_key'];
    if (walletIndex is! int ||
        accountIdsValue is! List<Object?> ||
        deleteWalletKey is! bool ||
        accountIdsValue.any((entry) => entry is! String)) {
      throw const FormatException('钱包清理计划字段类型无效');
    }
    return WalletCleanupPlan(
      walletIndex: walletIndex,
      accountIds: List<String>.unmodifiable(accountIdsValue.cast<String>()),
      deleteWalletKey: deleteWalletKey,
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
