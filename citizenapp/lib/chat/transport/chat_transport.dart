import '../chat_models.dart';

/// Chat 传输类型。
enum ChatTransportType {
  /// CitizenServe 有界端到端密文邮箱。
  mailbox,

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

/// 页面层只依赖加密 Envelope 传输，不接触邮箱或媒体建连细节。
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
