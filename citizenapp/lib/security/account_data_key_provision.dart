import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:citizenapp/qr/bodies/account_data_key_response_body.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/security/native_account_crypto.dart';
import 'package:citizenapp/signer/qr_signer.dart';
import 'package:citizenapp/signer/signing.dart';

typedef DataKeyRequest = ({LocalKeyPurpose purpose, String? context});

/// 冷钱包用途钥请求会话。一次性 X25519 私钥只活在此对象内，扫码完成或失败后清零。
class AccountDataKeyProvisionSession {
  AccountDataKeyProvisionSession._({
    required this.binding,
    required this.requests,
    required this.expiresAt,
    required this.payload,
    required Uint8List recipientSecret,
  }) : _recipientSecret = recipientSecret;

  final AccountDataBinding binding;
  final List<DataKeyRequest> requests;
  final int expiresAt;
  final Uint8List payload;
  final Uint8List _recipientSecret;

  static AccountDataKeyProvisionSession create({
    required AccountDataBinding binding,
    required List<DataKeyRequest> requests,
    required int expiresAt,
    List<int>? recipientSecret,
    List<int>? requestNonce,
  }) {
    binding.validate();
    _validateRequests(requests);
    final secret = Uint8List.fromList(
      recipientSecret ?? _randomBytes(NativeAccountCrypto.keyLength),
    );
    final nonce = requestNonce ?? _randomBytes(16);
    if (secret.length != 32 || nonce.length != 16) {
      secret.fillRange(0, secret.length, 0);
      throw const AccountDataKeyException('用途钥会话随机数长度无效');
    }
    final recipientPublicKey = NativeAccountCrypto.x25519PublicKey(secret);
    final payload = encodeAccountDataKeyProvisionRequest(
      binding: binding,
      recipientPublicKey: recipientPublicKey,
      requests: requests,
      expiresAt: expiresAt,
      requestNonce: nonce,
    );
    return AccountDataKeyProvisionSession._(
      binding: binding,
      requests: List<DataKeyRequest>.unmodifiable(requests),
      expiresAt: expiresAt,
      payload: payload,
      recipientSecret: secret,
    );
  }

  /// 验签后解封 `k=6`，并逐项核对用途编号、context 和32字节密钥。
  List<Uint8List> open(AccountDataKeyResponseBody body) {
    if (body.signerPublicKeyHex != binding.accountId) {
      throw const AccountDataKeyException('用途钥响应签名账户不一致');
    }
    final authorization = accountDataKeyProvisionAuthorization(
      requestPayload: payload,
      senderPublicKey: body.keyExchangePublicKeyBytes,
      nonce: body.encryptionNonceBytes,
      ciphertext: body.ciphertextBytes,
    );
    if (!QrSigner.verifySr25519Signature(
      signerPublicKeyHex: binding.accountId,
      signatureHex: body.signatureHex,
      message: signingMessage(
        opTag: kOpSignAccountDataKeyProvision,
        scalePayload: authorization,
      ),
    )) {
      throw const AccountDataKeyException('用途钥响应签名无效');
    }
    final plaintext = NativeAccountCrypto.open(
      recipientSecret: _recipientSecret,
      senderPublicKey: body.keyExchangePublicKeyBytes,
      nonce: body.encryptionNonceBytes,
      ciphertext: body.ciphertextBytes,
      aad: payload,
    );
    try {
      return decodeAccountDataKeyBundle(plaintext, requests);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  void dispose() => _recipientSecret.fillRange(0, _recipientSecret.length, 0);
}

Uint8List encodeAccountDataKeyProvisionRequest({
  required AccountDataBinding binding,
  required List<int> recipientPublicKey,
  required List<DataKeyRequest> requests,
  required int expiresAt,
  required List<int> requestNonce,
}) {
  _validateRequests(requests);
  if (recipientPublicKey.length != 32 ||
      requestNonce.length != 16 ||
      expiresAt <= 0) {
    throw const AccountDataKeyException('用途钥请求字段长度无效');
  }
  final cid = Uint8List.fromList(utf8.encode(binding.cidNumber));
  final purposeEntries = <int>[];
  for (final request in requests) {
    purposeEntries
      ..add(request.purpose.provisionCode)
      ..add(_contextCode(request));
  }
  return Uint8List.fromList(<int>[
    ..._hex32(binding.genesisHash),
    ..._compact(cid.length),
    ...cid,
    ...u64Le(binding.bindingRevision),
    ..._hex32(binding.accountId),
    ...recipientPublicKey,
    ..._compact(requests.length),
    ...purposeEntries,
    ...u64Le(expiresAt),
    ...requestNonce,
  ]);
}

Uint8List accountDataKeyProvisionAuthorization({
  required List<int> requestPayload,
  required List<int> senderPublicKey,
  required List<int> nonce,
  required List<int> ciphertext,
}) {
  if (senderPublicKey.length != 32 ||
      nonce.length != 12 ||
      ciphertext.length <= 16) {
    throw const AccountDataKeyException('用途钥响应加密字段无效');
  }
  return Uint8List.fromList(<int>[
    ...requestPayload,
    ...senderPublicKey,
    ...nonce,
    ...Hasher.blake2b256.hash(Uint8List.fromList(ciphertext)),
  ]);
}

List<Uint8List> decodeAccountDataKeyBundle(
  List<int> plaintext,
  List<DataKeyRequest> expected,
) {
  if (plaintext.isEmpty || plaintext[0] != expected.length << 2) {
    throw const AccountDataKeyException('用途钥密文清单数量不一致');
  }
  if (plaintext.length != 1 + expected.length * 34) {
    throw const AccountDataKeyException('用途钥密文包长度无效');
  }
  final result = <Uint8List>[];
  var offset = 1;
  for (final request in expected) {
    if (plaintext[offset] != request.purpose.provisionCode ||
        plaintext[offset + 1] != _contextCode(request)) {
      for (final key in result) {
        key.fillRange(0, key.length, 0);
      }
      throw const AccountDataKeyException('用途钥密文清单与请求不一致');
    }
    offset += 2;
    result.add(Uint8List.fromList(plaintext.sublist(offset, offset + 32)));
    offset += 32;
  }
  return result;
}

int _contextCode(DataKeyRequest request) {
  final context = request.context;
  if (context == null || context.isEmpty) return 0;
  if (request.purpose == LocalKeyPurpose.contactsCloud &&
      context == 'encryption') {
    return 1;
  }
  if (request.purpose == LocalKeyPurpose.contactsCloud && context == 'index') {
    return 2;
  }
  throw const AccountDataKeyException('用途钥 context 未登记');
}

void _validateRequests(List<DataKeyRequest> requests) {
  if (requests.isEmpty || requests.length > 7) {
    throw const AccountDataKeyException('用途钥请求数量必须为 1-7');
  }
  final seen = <String>{};
  for (final request in requests) {
    final key = '${request.purpose.provisionCode}:${_contextCode(request)}';
    if (!seen.add(key)) {
      throw const AccountDataKeyException('用途钥请求禁止重复');
    }
  }
}

Uint8List _hex32(String value) {
  if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(value)) {
    throw const AccountDataKeyException('32字节十六进制字段无效');
  }
  return Uint8List.fromList(
    List<int>.generate(
      32,
      (index) =>
          int.parse(value.substring(2 + index * 2, 4 + index * 2), radix: 16),
    ),
  );
}

List<int> _compact(int value) {
  if (value < 0 || value >= 64) {
    throw const AccountDataKeyException('SCALE compact 超出范围');
  }
  return <int>[value << 2];
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(
    length,
    (_) => random.nextInt(256),
    growable: false,
  );
}
