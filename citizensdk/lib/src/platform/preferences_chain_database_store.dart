import '../node/chain_database_store.dart';
import 'preferences_wallet_repository.dart';

/// Public smoldot finalized database storage, isolated from wallet namespaces.
final class PreferencesChainDatabaseStore implements ChainDatabaseStore {
  PreferencesChainDatabaseStore({PreferencesDataStore? preferences})
    : _preferences = preferences ?? SharedPreferencesDataStore();

  static const String storageKey = 'citizensdk.smoldot.database.v1';

  final PreferencesDataStore _preferences;

  @override
  Future<String?> read() => _preferences.getString(storageKey);

  @override
  Future<void> write(String envelope) =>
      _preferences.setString(storageKey, envelope);

  @override
  Future<void> delete() => _preferences.remove(storageKey);
}
