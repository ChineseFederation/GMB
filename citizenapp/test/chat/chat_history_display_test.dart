import 'package:citizenapp/chat/chat_models.dart';
import 'package:citizenapp/chat/chat_page.dart';
import 'package:citizenapp/chat/chat_payload.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 中文注释：统一构造已落盘的接收消息，确保各场景只改变待验证的载荷或消息类型。
  ChatStoredMessage message({
    required String envelopeId,
    required ChatMessageKind messageKind,
    required String plaintext,
  }) =>
      ChatStoredMessage(
        envelopeId: envelopeId,
        conversationId: 'conv-display',
        direction: 'incoming',
        senderCidNumber: 'sender-cid',
        recipientCidNumber: 'owner-cid',
        messageKind: messageKind,
        deliveryState: ChatMessageDeliveryState.receivedByDevice,
        createdAtMillis: 1,
        plaintext: plaintext,
      );

  // 中文注释：历史记录中单条损坏消息不能导致同一批其余有效消息从聊天窗口消失。
  test('单条畸形载荷只被隔离，其余严格载荷继续显示', () {
    final validA = message(
      envelopeId: 'valid-a',
      messageKind: ChatMessageKind.text,
      plaintext: ChatPayloadCodec.encode(ChatContent.text('第一条')),
    );
    final malformed = message(
      envelopeId: 'malformed',
      messageKind: ChatMessageKind.text,
      plaintext: '不是目标聊天 JSON',
    );
    final validB = message(
      envelopeId: 'valid-b',
      messageKind: ChatMessageKind.text,
      plaintext: ChatPayloadCodec.encode(ChatContent.text('第二条')),
    );

    final batch = filterChatMessagesForDisplay([validA, malformed, validB]);

    expect(batch.messages.map((item) => item.envelopeId), ['valid-a', 'valid-b']);
    expect(batch.integrityFailureCount, 1);
  });

  // 中文注释：落盘类型与加密载荷解码后的类型冲突时，必须按完整性失败处理而不是错误渲染。
  test('记录类型与载荷类型不一致时严格隔离', () {
    final mismatch = message(
      envelopeId: 'kind-mismatch',
      messageKind: ChatMessageKind.image,
      plaintext: ChatPayloadCodec.encode(ChatContent.text('正文')),
    );

    final batch = filterChatMessagesForDisplay(
      [mismatch],
      initialIntegrityFailureCount: 1,
    );

    expect(batch.messages, isEmpty);
    expect(batch.integrityFailureCount, 2);
  });

  // 中文注释：只有读取完成且没有错误时才能显示空态，加载或校验失败不得误导用户为暂无消息。
  test('只有成功且无错误的零消息读取显示真实空态', () {
    expect(
      shouldShowChatEmptyState(loading: false, error: null),
      isTrue,
    );
    expect(
      shouldShowChatEmptyState(loading: true, error: null),
      isFalse,
    );
    expect(
      shouldShowChatEmptyState(
        loading: false,
        error: '本机历史消息无法验证',
      ),
      isFalse,
    );
  });
}
