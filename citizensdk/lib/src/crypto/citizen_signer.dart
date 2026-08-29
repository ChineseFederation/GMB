import 'dart:typed_data';

import 'native_sr25519.dart';

/// 公民链 sr25519 公钥验签入口。
///
/// 使用钱包账户签名任意协议载荷应调用 `WalletService.sign`，避免产品代码读取
/// child mini-secret。TUYU v1 可以复用该签名入口，但协议消息构造仍属于 TUYU。
final class CitizenSigner {
  const CitizenSigner();

  bool verify({
    required Uint8List publicKey,
    required Uint8List signature,
    required Uint8List message,
  }) => NativeSr25519.verify(publicKey, signature, message);
}
