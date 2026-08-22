import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenwallet/qr/envelope.dart';
import 'package:citizenwallet/qr/generated/qr_bodies.g.dart';

class SignResponseBody implements QrBody {
  const SignResponseBody({
    required this.signerPublicKey,
    required this.signature,
  });

  /// 签名者公钥 `u`:32 字节 base64url 无填充。
  final String signerPublicKey;

  /// 签名 `s`:64 字节 sr25519 signature base64url 无填充。
  final String signature;

  Uint8List get signerPublicKeyBytes =>
      GeneratedQrBodySchema.decodeBase64Url(signerPublicKey, 'u');

  Uint8List get signatureBytes =>
      GeneratedQrBodySchema.decodeBase64Url(signature, 's');

  String get signerPublicKeyHex => '0x${_toHex(signerPublicKeyBytes)}';

  String get signatureHex => '0x${_toHex(signatureBytes)}';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'u': signerPublicKey,
        's': signature,
      };

  static SignResponseBody fromJson(Map<String, dynamic> data) {
    GeneratedQrBodySchema.validateBody(QrKind.signResponse.code, data);
    return SignResponseBody(
      signerPublicKey: data['u'] as String,
      signature: data['s'] as String,
    );
  }

  static SignResponseBody fromHex({
    required String signerPublicKeyHex,
    required String signatureHex,
  }) {
    return SignResponseBody(
      signerPublicKey: _b64NoPad(
        _strictHexBytes(
          signerPublicKeyHex,
          field: 'signer_public_key',
          expectedBytes: 32,
        ),
      ),
      signature: _b64NoPad(
        _strictHexBytes(
          signatureHex,
          field: 'signature',
          expectedBytes: 64,
        ),
      ),
    );
  }
}

String _b64NoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _strictHexBytes(
  String input, {
  required String field,
  required int expectedBytes,
}) {
  if (!input.startsWith('0x')) {
    throw FormatException('$field 必须以小写 0x 开头');
  }
  final text = input.substring(2);
  if (text.isEmpty ||
      text.length.isOdd ||
      !RegExp(r'^[0-9a-f]+$').hasMatch(text)) {
    throw FormatException('$field 必须是小写偶数字节十六进制');
  }
  final bytes = List<int>.generate(
    text.length ~/ 2,
    (i) => int.parse(text.substring(i * 2, i * 2 + 2), radix: 16),
    growable: false,
  );
  if (bytes.length != expectedBytes) {
    throw FormatException('$field 必须是 $expectedBytes 字节');
  }
  return bytes;
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
