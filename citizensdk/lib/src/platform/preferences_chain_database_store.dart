import '../node/chain_database_store.dart';
import 'preferences_data_store.dart';

/// Public smoldot finalized database storage, isolated from wallet namespaces.
///
/// 同一 Dart isolate 内的实例共用串行队列，并对每次写入和删除做结果
/// 回读。
/// SharedPreferences 不提供跨 isolate 或跨进程原子性；需要更强合同的宿主必须
/// 注入自己的 [ChainDatabaseStore]。
final class PreferencesChainDatabaseStore implements ChainDatabaseStore {
  PreferencesChainDatabaseStore({PreferencesDataStore? preferences})
    : _preferences = preferences ?? SharedPreferencesDataStore();

  static const String storageKey = 'citizensdk.smoldot.database.v1';

  final PreferencesDataStore _preferences;
  static Future<void> _mutationTail = Future<void>.value();

  @override
  Future<String?> read() => _preferences.getString(storageKey);

  @override
  Future<void> write(String envelope) => _serialize(() async {
    Object? writeError;
    try {
      await _preferences.setString(storageKey, envelope);
    } on Object catch (error) {
      writeError = error;
    }
    if (await _preferences.getString(storageKey) == envelope) return;
    if (writeError != null) throw writeError;
    throw StateError('轻节点同步缓存写入后回读不一致');
  });

  @override
  Future<void> delete() => _serialize(() async {
    Object? deleteError;
    try {
      await _preferences.remove(storageKey);
    } on Object catch (error) {
      deleteError = error;
    }
    if (await _preferences.getString(storageKey) == null) return;
    if (deleteError != null) throw deleteError;
    throw StateError('轻节点同步缓存删除后仍然存在');
  });

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final previous = _mutationTail;
    late final Future<T> task;
    task = previous.catchError((Object _) {}).then((_) => action());
    _mutationTail = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return task;
  }
}
