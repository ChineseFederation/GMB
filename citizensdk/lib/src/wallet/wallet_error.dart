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

/// 钱包公开事实与硬件金库无法在同一个平台事务内完成时的本机
/// 清理错误。
///
/// 清理流程会继续尝试全部账户 child 与钱包 KEK，并在每次删除后
/// 回读确认；任一项失败时公开事实或持久 cleanup plan 必须保留，
/// 供后续实例精确重试。
final class WalletLocalCleanupException extends WalletException {
  WalletLocalCleanupException(List<String> failures)
    : failures = List<String>.unmodifiable(failures),
      super('钱包本机安全存储清理未完成：${failures.join('；')}');

  final List<String> failures;
}
