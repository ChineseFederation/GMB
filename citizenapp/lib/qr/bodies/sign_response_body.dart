import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenapp/qr/envelope.dart';
import 'package:citizenapp/qr/generated/qr_bodies.g.dart';

/// k = 2 签名响应。
///
/// 生成方按同一 `i` 找回本地 session,因此响应只需要签名者公钥和签名本身。
class SignResponseBody implements QrBody {
  const SignResponseBody({
    required this.signerPublicKey,
    required this.signature,
    this.currentAccountId,
    this.currentAccountSignature,
  });

  /// 签名者公钥 `u`:32 字节 base64url 无填充。
  final String signerPublicKey;

  /// 签名 `s`:64 字节 sr25519 signature base64url 无填充。
  final String signature;

  /// 换绑且当前账户可签名时，`o` / `r` 同时携带当前账户与当前账户授权签名。
  /// 其它动作两字段都省略；禁止只出现其中一个。
  final String? currentAccountId;
  final String? currentAccountSignature;

  Uint8List get signerPublicKeyBytes =>
      GeneratedQrBodySchema.decodeBase64Url(signerPublicKey, 'u');

  Uint8List get signatureBytes =>
      GeneratedQrBodySchema.decodeBase64Url(signature, 's');

  String get signerPublicKeyHex => '0x${_toHex(signerPublicKeyBytes)}';

  String get signatureHex => '0x${_toHex(signatureBytes)}';

  String? get currentAccountIdHex => currentAccountId == null
      ? null
      : '0x${_toHex(GeneratedQrBodySchema.decodeBase64Url(currentAccountId!, 'o'))}';

  String? get currentAccountSignatureHex => currentAccountSignature == null
      ? null
      : '0x${_toHex(GeneratedQrBodySchema.decodeBase64Url(currentAccountSignature!, 'r'))}';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'u': signerPublicKey,
    's': signature,
    if (currentAccountId != null) 'o': currentAccountId,
    if (currentAccountSignature != null) 'r': currentAccountSignature,
  };

  static SignResponseBody fromJson(Map<String, dynamic> data) {
    GeneratedQrBodySchema.validateBody(QrKind.signResponse.code, data);
    return SignResponseBody(
      signerPublicKey: data['u'] as String,
      signature: data['s'] as String,
      currentAccountId: data['o'] as String?,
      currentAccountSignature: data['r'] as String?,
    );
  }

  static SignResponseBody fromHex({
    required String signerPublicKeyHex,
    required String signatureHex,
    String? currentAccountIdHex,
    String? currentAccountSignatureHex,
  }) {
    if ((currentAccountIdHex == null) != (currentAccountSignatureHex == null)) {
      throw const FormatException('当前账户与当前账户签名必须同时提供');
    }
    return SignResponseBody(
      signerPublicKey: _b64NoPad(_hexToBytes(signerPublicKeyHex)),
      signature: _b64NoPad(_hexToBytes(signatureHex)),
      currentAccountId: currentAccountIdHex == null
          ? null
          : _b64NoPad(_hexToBytes(currentAccountIdHex)),
      currentAccountSignature: currentAccountSignatureHex == null
          ? null
          : _b64NoPad(_hexToBytes(currentAccountSignatureHex)),
    );
  }
}

String _b64NoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// 严格 hex:强制小写 `0x` 前缀 + 小写偶数字节,与冷端同口径。
List<int> _hexToBytes(String input) {
  if (!input.startsWith('0x')) {
    throw const FormatException('hex 必须以小写 0x 开头');
  }
  final text = input.substring(2);
  if (text.isEmpty ||
      text.length.isOdd ||
      !RegExp(r'^[0-9a-f]+$').hasMatch(text)) {
    throw const FormatException('hex 必须是小写偶数字节十六进制');
  }
  return List<int>.generate(
    text.length ~/ 2,
    (i) => int.parse(text.substring(i * 2, i * 2 + 2), radix: 16),
    growable: false,
  );
}

String _toHex(List<int> bytes) {
  const chars = '0123456789abcdef';
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer
      ..write(chars[(byte >> 4) & 0x0f])
      ..write(chars[byte & 0x0f]);
  }
  return buffer.toString();
}
