import 'package:characters/characters.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Substrate BIP-39 可选 password 的规范化结果。
final class WalletPassword {
  const WalletPassword._(this.value);

  final String value;
  bool get isEmpty => value.isEmpty;

  static const int minLength = 6;
  static const int maxLength = 30;
  static final RegExp _ascii = RegExp(
    r'''^[A-Za-z0-9!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]$''',
  );
  static final RegExp _han = RegExp(r'^\p{Script=Han}$', unicode: true);

  /// 校验原文后执行 BIP-39 要求的 NFKD；不 trim、不改大小写。
  static WalletPassword parse(String raw) {
    if (raw.isEmpty) return const WalletPassword._('');
    final length = raw.characters.length;
    if (length < minLength || length > maxLength) {
      throw const WalletPasswordException('密码长度必须为 6–30 位');
    }
    if (!_allAllowed(raw)) {
      throw const WalletPasswordException('密码包含不允许的字符');
    }
    final normalized = unorm.nfkd(raw);
    if (normalized.characters.length < minLength ||
        normalized.characters.length > maxLength ||
        !_allAllowed(normalized)) {
      throw const WalletPasswordException('密码包含规范化后无法安全恢复的字符');
    }
    return WalletPassword._(normalized);
  }

  static bool _allAllowed(String value) => value.characters.every(
    (character) => _ascii.hasMatch(character) || _han.hasMatch(character),
  );
}

final class WalletPasswordException implements Exception {
  const WalletPasswordException(this.message);
  final String message;

  @override
  String toString() => message;
}
