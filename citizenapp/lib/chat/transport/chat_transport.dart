import '../chat_models.dart';

/// Chat 传输类型。
enum ChatTransportType {
  /// 互联网聊天，消息通过 WebRTC DataChannel 在两台设备之间直传。
  webrtc,

  /// 手机近场直连。
  nearby,
}

/// Chat 传输结果。
class ChatDeliveryResult {
  const ChatDeliveryResult({
    required this.envelopeId,
    required this.transportType,
    required this.state,
    this.errorMessage,
  });

  final String envelopeId;
  final ChatTransportType transportType;
  final ChatMessageDeliveryState state;
  final String? errorMessage;
}

/// 页面层只依赖加密 Envelope 传输，不接触 WebRTC 建连细节。
abstract class ChatTransport {
  ChatTransportType get type;

  /// 投递密文 Envelope。
  ///
  /// [recipientCidNumber] 是收件人身份主键 CID 号，也是 MLS 与直连路由的唯一身份键。
  Future<ChatDeliveryResult> sendEncryptedEnvelope({
    required String envelopeId,
    required List<int> envelopeBytes,
    required String recipientCidNumber,
  });
}
