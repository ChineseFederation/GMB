import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenwallet/qr/envelope.dart';
import 'package:citizenwallet/qr/generated/qr_bodies.g.dart';

/// `k=6` 账户数据用途钥加密响应；结构与 CitizenApp 完全一致。
class AccountDataKeyResponseBody implements QrBody {
  const AccountDataKeyResponseBody({
    required this.signerPublicKey,
    required this.signature,
    required this.keyExchangePublicKey,
    required this.encryptionNonce,
    required this.ciphertext,
  });

  final String signerPublicKey;
  final String signature;
  final String keyExchangePublicKey;
  final String encryptionNonce;
  final String ciphertext;

  Uint8List get signerPublicKeyBytes =>
      GeneratedQrBodySchema.decodeBase64Url(signerPublicKey, 'u');
  Uint8List get signatureBytes =>
      GeneratedQrBodySchema.decodeBase64Url(signature, 's');
  Uint8List get keyExchangePublicKeyBytes =>
      GeneratedQrBodySchema.decodeBase64Url(keyExchangePublicKey, 'x');
  Uint8List get encryptionNonceBytes =>
      GeneratedQrBodySchema.decodeBase64Url(encryptionNonce, 'q');
  Uint8List get ciphertextBytes =>
      GeneratedQrBodySchema.decodeBase64Url(ciphertext, 'z');
  String get signerPublicKeyHex => '0x${_toHex(signerPublicKeyBytes)}';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'u': signerPublicKey,
        's': signature,
        'x': keyExchangePublicKey,
        'q': encryptionNonce,
        'z': ciphertext,
      };

  static AccountDataKeyResponseBody fromJson(Map<String, dynamic> data) {
    GeneratedQrBodySchema.validateBody(
      QrKind.accountDataKeyResponse.code,
      data,
    );
    return AccountDataKeyResponseBody(
      signerPublicKey: data['u'] as String,
      signature: data['s'] as String,
      keyExchangePublicKey: data['x'] as String,
      encryptionNonce: data['q'] as String,
      ciphertext: data['z'] as String,
    );
  }

  static AccountDataKeyResponseBody fromBytes({
    required List<int> signerPublicKey,
    required List<int> signature,
    required List<int> keyExchangePublicKey,
    required List<int> encryptionNonce,
    required List<int> ciphertext,
  }) {
    final body = AccountDataKeyResponseBody(
      signerPublicKey: _b64(signerPublicKey),
      signature: _b64(signature),
      keyExchangePublicKey: _b64(keyExchangePublicKey),
      encryptionNonce: _b64(encryptionNonce),
      ciphertext: _b64(ciphertext),
    );
    GeneratedQrBodySchema.validateBody(
      QrKind.accountDataKeyResponse.code,
      body.toJson(),
    );
    return body;
  }
}

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
String _toHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
