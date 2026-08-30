/// ChatSDK 交给宿主实现的 HTTPS 密文邮箱边界。
final class MailboxEndpoint {
  MailboxEndpoint._(this.uri);

  factory MailboxEndpoint.secure(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'uri', '密文邮箱只允许 HTTPS');
    }
    return MailboxEndpoint._(uri);
  }

  final Uri uri;
}

/// 服务端只需保存和返回密文信封字节，不得解析端到端明文。
final class MailboxEnvelope {
  const MailboxEnvelope({
    required this.envelopeId,
    required this.recipientUserId,
    required this.envelopeBytes,
    required this.createdAtMillis,
    required this.expiresAtMillis,
  });

  final String envelopeId;
  final String recipientUserId;
  final List<int> envelopeBytes;
  final int createdAtMillis;
  final int expiresAtMillis;
}

/// 任意自建服务只要实现发送、拉取、确认三项即可承载 ChatSDK 密文邮箱。
abstract interface class MailboxTransport {
  MailboxEndpoint get endpoint;

  Future<void> send(MailboxEnvelope envelope);

  Future<List<MailboxEnvelope>> pull({required int limit});

  Future<void> acknowledge(Iterable<String> envelopeIds);
}
