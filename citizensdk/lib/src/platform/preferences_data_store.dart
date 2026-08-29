import 'package:shared_preferences/shared_preferences.dart';

/// 平台层持久化适配与测试共同使用的最小字符串 preferences 合同。
///
/// 本接口只表达公开 JSON/轻节点数据库信封的字符串读写，不属于钱包或链
/// 任一业务层。需要跨 isolate、跨进程原子性的宿主应注入更强实现。
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
