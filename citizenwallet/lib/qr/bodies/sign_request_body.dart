import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenwallet/qr/envelope.dart';
import 'package:citizenwallet/qr/generated/qr_bodies.g.dart';
import 'package:citizenwallet/qr/qr_protocols.dart';

class SignRequestBody implements QrBody {
  const SignRequestBody({
    required this.action,
    required this.signerPublicKey,
    required this.payload,
    this.alg = 1,
  });

  /// 业务动作码 `a`:扫码流向以 `k` 表达,业务语义统一放这里。
  final int action;

  /// 签名算法 `g`:当前 1=sr25519。
  final int alg;

  /// 期望签名者公钥 `u`:32 字节公钥的 base64url 无填充编码。
  final String signerPublicKey;

  /// 审阅载荷 `d`:原始 review_payload bytes 的 base64url 无填充编码。
  ///
  /// 普通链交易必须是可完整解码和中文展示的 review_payload；实际签名字节由
  /// 签名端按 action 重新计算，不能把 32 字节 signing bytes 冒充成这里的载荷。
  final String payload;

  Uint8List get payloadBytes =>
      GeneratedQrBodySchema.decodeBase64Url(payload, 'd');

  Uint8List get signerPublicKeyBytes => signerPublicKey.isEmpty
      ? Uint8List(0)
      : GeneratedQrBodySchema.decodeBase64Url(signerPublicKey, 'u');

  String get payloadHex => '0x${_toHex(payloadBytes)}';

  String get signerPublicKeyHex => '0x${_toHex(signerPublicKeyBytes)}';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'a': action,
        'g': alg,
        'u': signerPublicKey,
        'd': payload,
      };

  static SignRequestBody fromJson(Map<String, dynamic> data) {
    GeneratedQrBodySchema.validateBody(QrKind.signRequest.code, data);
    return SignRequestBody(
      action: data['a'] as int,
      alg: data['g'] as int,
      signerPublicKey: data['u'] as String,
      payload: data['d'] as String,
    );
  }

  static SignRequestBody fromHex({
    required int action,
    required String signerPublicKeyHex,
    required String payloadHex,
  }) {
    // 注册局占号/换绑请求按协议把 u 留空，由离线钱包选择账户后原位填授权模板零槽。
    // 测试/本地构造入口必须与 fromJson 遵守同一规则，不能强迫伪造 32 字节账户。
    final signerPublicKeyBytes = signerPublicKeyHex.isEmpty &&
            QrActions.isSelfAccountDomainAction(action)
        ? Uint8List(0)
        : _strictHexBytes(
            signerPublicKeyHex,
            field: 'signer_public_key',
            expectedBytes: 32,
          );
    return SignRequestBody(
      action: action,
      signerPublicKey: _b64NoPad(signerPublicKeyBytes),
      payload: _b64NoPad(_strictHexBytes(payloadHex, field: 'payload')),
    );
  }
}

String _b64NoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _strictHexBytes(
  String input, {
  required String field,
  int? expectedBytes,
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
  if (expectedBytes != null && bytes.length != expectedBytes) {
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
