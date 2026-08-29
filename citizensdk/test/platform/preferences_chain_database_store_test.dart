import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a namespace isolated from wallet public state', () async {
    final preferences = _MemoryPreferences();
    final store = PreferencesChainDatabaseStore(preferences: preferences);

    await store.write('database-envelope');
    expect(await store.read(), 'database-envelope');
    expect(
      PreferencesChainDatabaseStore.storageKey,
      isNot(PreferencesWalletRepository.storageKey),
    );
    await store.delete();
    expect(await store.read(), isNull);
  });
}

final class _MemoryPreferences implements PreferencesDataStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
