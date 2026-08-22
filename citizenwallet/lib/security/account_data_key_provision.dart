import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/digests/blake2b.dart';
import 'package:citizenwallet/security/native_account_crypto.dart';

const int accountDataKeyProvisionOpTag = 0x22;

/// `blake2_256(GMB || 0x22 || authorization_payload)`。
Uint8List accountDataKeyProvisionSigningMessage(
  List<int> authorizationPayload,
) {
  return _blake2(<int>[
    0x47,
    0x4d,
    0x42,
    accountDataKeyProvisionOpTag,
    ...authorizationPayload,
  ]);
}

class AccountDataKeyProvisionRequest {
  const AccountDataKeyProvisionRequest({
    required this.payload,
    required this.genesisHash,
    required this.cidNumber,
    required this.bindingRevision,
    required this.accountId,
    required this.recipientPublicKey,
    required this.purposes,
    required this.expiresAt,
  });

  final Uint8List payload;
  final Uint8List genesisHash;
  final String cidNumber;
  final int bindingRevision;
  final String accountId;
  final Uint8List recipientPublicKey;
  final List<({int purpose, int context})> purposes;
  final int expiresAt;

  static AccountDataKeyProvisionRequest? decode(Uint8List bytes) {
    try {
      var offset = 0;
      if (bytes.length < 32 + 1 + 1 + 8 + 32 + 32 + 1 + 2 + 8 + 16) return null;
      final genesisHash = Uint8List.fromList(
        bytes.sublist(offset, offset + 32),
      );
      offset += 32;
      final cidLength = _readCompactOneByte(bytes, offset++);
      if (cidLength < 1 ||
          cidLength > 32 ||
          offset + cidLength > bytes.length) {
        return null;
      }
      final cidBytes = bytes.sublist(offset, offset + cidLength);
      final cidNumber = utf8.decode(cidBytes, allowMalformed: false);
      if (utf8.encode(cidNumber).length != cidLength) return null;
      offset += cidLength;
      final revision = _readU64(bytes, offset);
      offset += 8;
      if (revision <= 0) return null;
      final accountBytes = bytes.sublist(offset, offset + 32);
      final accountId = '0x${_hex(accountBytes)}';
      offset += 32;
      final recipient = Uint8List.fromList(bytes.sublist(offset, offset + 32));
      offset += 32;
      final count = _readCompactOneByte(bytes, offset++);
      if (count < 1 || count > 7 || offset + count * 2 + 24 != bytes.length) {
        return null;
      }
      final purposes = <({int purpose, int context})>[];
      final seen = <String>{};
      for (var index = 0; index < count; index++) {
        final purpose = bytes[offset++];
        final context = bytes[offset++];
        if (!_validPurpose(purpose, context) ||
            !seen.add('$purpose:$context')) {
          return null;
        }
        purposes.add((purpose: purpose, context: context));
      }
      final expiresAt = _readU64(bytes, offset);
      offset += 8;
      if (expiresAt <= 0) return null;
      offset += 16;
      if (offset != bytes.length) return null;
      return AccountDataKeyProvisionRequest(
        payload: Uint8List.fromList(bytes),
        genesisHash: genesisHash,
        cidNumber: cidNumber,
        bindingRevision: revision,
        accountId: accountId,
        recipientPublicKey: recipient,
        purposes: List.unmodifiable(purposes),
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }
}

class AccountDataKeyProvisionMaterial {
  const AccountDataKeyProvisionMaterial({
    required this.senderPublicKey,
    required this.nonce,
    required this.ciphertext,
    required this.authorizationPayload,
  });

  final Uint8List senderPublicKey;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List authorizationPayload;
}

AccountDataKeyProvisionMaterial createAccountDataKeyProvision({
  required AccountDataKeyProvisionRequest request,
  required List<int> accountSecret,
  List<int>? senderSecret,
  List<int>? nonce,
}) {
  final sender = Uint8List.fromList(senderSecret ?? _randomBytes(32));
  final encryptionNonce = Uint8List.fromList(nonce ?? _randomBytes(12));
  final keys = <Uint8List>[];
  final plaintext = <int>[request.purposes.length << 2];
  try {
    for (final entry in request.purposes) {
      final purpose = _purposeDomain(entry.purpose);
      final context = _contextText(entry.purpose, entry.context);
      final key = NativeAccountCrypto.deriveKey(
        accountSecret: accountSecret,
        genesisHash: request.genesisHash,
        cidNumber: utf8.encode(request.cidNumber),
        bindingRevision: request.bindingRevision,
        accountId: _hexBytes(request.accountId),
        purpose: utf8.encode(purpose),
        context: utf8.encode(context),
      );
      keys.add(key);
      plaintext
        ..add(entry.purpose)
        ..add(entry.context)
        ..addAll(key);
    }
    final senderPublicKey = NativeAccountCrypto.x25519PublicKey(sender);
    final ciphertext = NativeAccountCrypto.seal(
      recipientPublicKey: request.recipientPublicKey,
      senderSecret: sender,
      nonce: encryptionNonce,
      plaintext: plaintext,
      aad: request.payload,
    );
    final authorization = Uint8List.fromList(<int>[
      ...request.payload,
      ...senderPublicKey,
      ...encryptionNonce,
      ..._blake2(ciphertext),
    ]);
    return AccountDataKeyProvisionMaterial(
      senderPublicKey: senderPublicKey,
      nonce: encryptionNonce,
      ciphertext: ciphertext,
      authorizationPayload: authorization,
    );
  } finally {
    sender.fillRange(0, sender.length, 0);
    plaintext.fillRange(0, plaintext.length, 0);
    for (final key in keys) {
      key.fillRange(0, key.length, 0);
    }
  }
}

String _purposeDomain(int purpose) => switch (purpose) {
      1 => 'citizenapp.account-data/chat',
      2 => 'citizenapp.account-data/chat-index',
      3 => 'citizenapp.account-data/mls',
      4 => 'citizenapp.account-data/attachment',
      5 => 'citizenapp.account-data/contacts-local',
      6 => 'citizenapp.account-data/contacts-cloud',
      _ => throw const FormatException('用途编号未登记'),
    };

String _contextText(int purpose, int context) {
  if (context == 0) return '';
  if (purpose == 6 && context == 1) return 'encryption';
  if (purpose == 6 && context == 2) return 'index';
  throw const FormatException('用途 context 未登记');
}

bool _validPurpose(int purpose, int context) {
  if (purpose < 1 || purpose > 6) return false;
  return context == 0 || (purpose == 6 && (context == 1 || context == 2));
}

int _readCompactOneByte(Uint8List bytes, int offset) {
  if (offset >= bytes.length || bytes[offset] & 3 != 0) return -1;
  return bytes[offset] >> 2;
}

int _readU64(Uint8List bytes, int offset) {
  if (offset + 8 > bytes.length) return -1;
  var value = 0;
  for (var index = 7; index >= 0; index--) {
    value = value * 256 + bytes[offset + index];
  }
  return value;
}

Uint8List _blake2(List<int> bytes) {
  final digest = Blake2bDigest(digestSize: 32)
    ..update(Uint8List.fromList(bytes), 0, bytes.length);
  final output = Uint8List(32);
  digest.doFinal(output, 0);
  return output;
}

Uint8List _hexBytes(String value) {
  final text = value.substring(2);
  return Uint8List.fromList(
    List<int>.generate(
      text.length ~/ 2,
      (index) => int.parse(text.substring(index * 2, index * 2 + 2), radix: 16),
    ),
  );
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(
    length,
    (_) => random.nextInt(256),
    growable: false,
  );
}
