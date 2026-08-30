import '../../core/media_content.dart';
import '../../core/serial_executor.dart';
import '../../mls/mls_boundary.dart';
import 'direct_media_inbound.dart';
import 'direct_media_outbound.dart';

/// 私聊第二类媒体消息的统一编码、HPKE 加解密通道。
final class DirectMediaChannel {
  DirectMediaChannel(this._crypto, {SerialExecutor? serialExecutor})
    : _serial = serialExecutor ?? SerialExecutor();

  final MlsCrypto _crypto;
  final SerialExecutor _serial;

  Future<DirectMediaOutbound> encrypt({
    required String conversationId,
    required String recipientUserId,
    required String recipientDevicePublicKey,
    required MediaContent content,
  }) => _serial.run(conversationId, () async {
    final encrypted = await _crypto.encrypt(
      conversationId: conversationId,
      recipientUserId: recipientUserId,
      recipientDevicePublicKey: recipientDevicePublicKey,
      plaintext: MediaContentCodec.encode(content),
    );
    return DirectMediaOutbound(content: content, encrypted: encrypted);
  });

  Future<DirectMediaInbound> decrypt(MlsWireMessage message) =>
      _serial.run(message.conversationId, () async {
        final plaintext = await _crypto.decrypt(message);
        return DirectMediaInbound(
          conversationId: message.conversationId,
          content: MediaContentCodec.decode(plaintext),
        );
      });
}
