/// CitizenSDK 钱包错误根类型。
sealed class WalletException implements Exception {
  const WalletException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class WalletAlreadyExists extends WalletException {
  const WalletAlreadyExists() : super('本设备已存在热钱包');
}

final class WalletNotFound extends WalletException {
  const WalletNotFound([super.message = '未找到热钱包']);
}

final class WalletAuthenticationFailed extends WalletException {
  const WalletAuthenticationFailed(super.message);
}

final class WalletRepositoryConflict extends WalletException {
  const WalletRepositoryConflict() : super('钱包公开状态已被并发修改');
}

final class WalletInvariantViolation extends WalletException {
  const WalletInvariantViolation(super.message);
}
