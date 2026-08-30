import '../../core/basic_content.dart';
import '../../core/serial_executor.dart';
import '../../mls/mls_boundary.dart';
import 'direct_basic_inbound.dart';
import 'direct_basic_outbound.dart';

/// 私聊第一类消息的统一编码、HPKE 加解密通道。
final class DirectBasicChannel {
  DirectBasicChannel(this._crypto, {SerialExecutor? serialExecutor})
    : _serial = serialExecutor ?? SerialExecutor();

  final MlsCrypto _crypto;
  final SerialExecutor _serial;

  Future<DirectBasicOutbound> encrypt({
    required String conversationId,
    required String recipientUserId,
    required String recipientDevicePublicKey,
    required BasicContent content,
  }) => _serial.run(conversationId, () async {
    final encrypted = await _crypto.encrypt(
      conversationId: conversationId,
      recipientUserId: recipientUserId,
      recipientDevicePublicKey: recipientDevicePublicKey,
      plaintext: BasicContentCodec.encode(content),
    );
    return DirectBasicOutbound(content: content, encrypted: encrypted);
  });

  Future<DirectBasicInbound> decrypt(MlsWireMessage message) =>
      _serial.run(message.conversationId, () async {
        final plaintext = await _crypto.decrypt(message);
        return DirectBasicInbound(
          conversationId: message.conversationId,
          content: BasicContentCodec.decode(plaintext),
        );
      });
}
