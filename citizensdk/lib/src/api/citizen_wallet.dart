import 'dart:typed_data';

import '../models/citizen_wallet.dart';

/// CitizenSDK 无根热钱包的公开控制面。
///
/// create/import/addAccounts 都只启动 SDK 自有安全界面。Dart API 故意没有 mnemonic 或
/// password 参数，也不会收到 prepared/native/result handle。
abstract interface class CitizenWallet {
  Future<CitizenWalletProfile?> getProfile();

  Future<CitizenWalletProfile> create({
    CitizenWalletWordCount wordCount = CitizenWalletWordCount.words12,
  });

  Future<CitizenWalletProfile> importWallet();

  Future<CitizenWalletProfile> addAccounts(List<int> indices);

  Future<CitizenWalletProfile> setActiveAccount(String accountId);

  Future<CitizenWalletProfile> renameAccount({
    required String accountId,
    required String name,
  });

  Future<CitizenWalletProfile?> deleteAccount(String accountId);

  Future<void> delete();

  Future<CitizenWalletProfile?> reconcileCleanup();

  Future<CitizenWalletSignature> sign({
    required String accountId,
    required Uint8List payload,
  });
}
