import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../node/chain_database_store.dart';
import '../wallet/secure_seed_store.dart';
import '../wallet/wallet_repository.dart';
import 'hardware_bound_seed_store.dart';
import 'hardware_secret_vault.dart';
import 'preferences_chain_database_store.dart';
import 'preferences_wallet_repository.dart';
import 'secure_blob_store.dart';

/// Ready-to-wire Android/iOS persistence components for `CitizenSdk`.
///
/// Kept separate from the facade to make each security boundary replaceable in
/// tests and in future platform ports.
final class MobileCitizenSdkComponents {
  const MobileCitizenSdkComponents({
    required this.walletRepository,
    required this.secureSeedStore,
    required this.chainDatabaseStore,
  });

  factory MobileCitizenSdkComponents.standard({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
    HardwareSecretVault? hardwareVault,
  }) {
    final preferenceStore = SharedPreferencesDataStore(preferences);
    final blobStore = FlutterSecureBlobStore(secureStorage);
    return MobileCitizenSdkComponents(
      walletRepository: PreferencesWalletRepository(
        preferences: preferenceStore,
      ),
      secureSeedStore: HardwareBoundSeedStore(
        hardwareVault: hardwareVault,
        blobStore: blobStore,
      ),
      chainDatabaseStore: PreferencesChainDatabaseStore(
        preferences: preferenceStore,
      ),
    );
  }

  final WalletRepository walletRepository;
  final SecureSeedStore secureSeedStore;
  final ChainDatabaseStore chainDatabaseStore;
}
