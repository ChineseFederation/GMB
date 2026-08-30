import 'dart:collection';

import '../../core/chat_scope.dart';
import '../../core/envelope_id.dart';
import '../../mls/mls_session.dart';
import '../../protocol/chat_envelope.pb.dart';

/// 一份群 OpenMLS 密文按成员生成独立路由信封，密文绝不重复加密。
final class GroupMediaFanout {
  GroupMediaFanout._();

  static List<ChatEnvelope> fanOut({
    required MlsWireMessage wire,
    required Iterable<String> recipientUserIds,
    required String senderUserId,
    required String senderDeviceId,
    required int createdAtMillis,
    required int ttlMillis,
  }) {
    if (senderUserId.isEmpty || senderDeviceId.isEmpty) {
      throw ArgumentError('群消息发送身份不完整');
    }
    if (ttlMillis <= 0 || ttlMillis > chatSdkMailboxRetention.inMilliseconds) {
      throw ArgumentError.value(ttlMillis, 'ttlMillis', '密文邮箱期限不合法');
    }
    final recipients = LinkedHashSet<String>.from(
      recipientUserIds.where((value) => value.isNotEmpty),
    )..remove(senderUserId);
    return recipients
        .map((recipientUserId) {
          final envelopeId = EnvelopeId.derive(
            conversationId: wire.conversationId,
            senderUserId: senderUserId,
            recipientUserId: recipientUserId,
            createdAtMillis: createdAtMillis,
            encryptedMessage: wire.wireBytes,
          );
          return wire.toEnvelope(
            envelopeId: envelopeId,
            senderUserId: senderUserId,
            recipientUserId: recipientUserId,
            senderDeviceId: senderDeviceId,
            createdAtMillis: createdAtMillis,
            ttlMillis: ttlMillis,
          );
        })
        .toList(growable: false);
  }
}
