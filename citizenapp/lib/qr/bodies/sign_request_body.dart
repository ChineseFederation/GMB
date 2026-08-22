import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenapp/qr/envelope.dart';
import 'package:citizenapp/qr/generated/qr_bodies.g.dart';

/// k = 1 签名请求。
///
/// CitizenApp、CID、节点桌面端都只生成这一种请求流向;具体业务场景由
/// `action`(`a`) 区分,扫码端展示内容必须由 `action + payload` 本地解码得出。
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
    return SignRequestBody(
      action: action,
      signerPublicKey: _b64NoPad(_hexToBytes(signerPublicKeyHex)),
      payload: _b64NoPad(_hexToBytes(payloadHex)),
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
