import 'dart:typed_data';

import 'citizen_account.dart';

enum CitizenWalletOrigin { created, imported }

enum CitizenWalletWordCount {
  words12(12),
  words24(24);

  const CitizenWalletWordCount(this.value);

  final int value;
}

/// 一只无根热钱包的公开资料；不包含 generation、secret owner 或任何秘密。
final class CitizenWalletProfile {
  CitizenWalletProfile({
    required this.walletIndex,
    required this.masterAccountId,
    required this.origin,
    required this.createdAtMillis,
    required this.activeAccountId,
    required List<CitizenAccount> accounts,
  }) : accounts = List<CitizenAccount>.unmodifiable(accounts);

  final int walletIndex;
  final String masterAccountId;
  final CitizenWalletOrigin origin;
  final BigInt createdAtMillis;
  final String activeAccountId;
  final List<CitizenAccount> accounts;

  CitizenAccount? accountById(String accountId) {
    for (final account in accounts) {
      if (account.accountId == accountId) return account;
    }
    return null;
  }
}

/// sr25519 的公开签名结果；消息及私钥生命周期不进入该模型。
final class CitizenWalletSignature {
  CitizenWalletSignature({required this.accountId, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes) {
    if (this.bytes.length != 64) {
      throw ArgumentError.value(this.bytes.length, 'bytes', '必须是 64 字节');
    }
  }

  final String accountId;
  final Uint8List bytes;
}
