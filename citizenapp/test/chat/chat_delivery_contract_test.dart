import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('媒体先持久落库再由后台队列上传 R2 密文', () {
    final source = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final sendMediaStart =
        source.indexOf('Future<List<ChatDeliveryResult>> sendMedia');
    final prepareStart =
        source.indexOf('Future<ChatContent> _prepareEncryptedMedia');
    final flushStart = source.indexOf('Future<void> _sendPendingMedia');

    expect(sendMediaStart, greaterThanOrEqualTo(0));
    expect(prepareStart, greaterThan(sendMediaStart));
    expect(flushStart, greaterThan(prepareStart));
    expect(
      source,
      contains("/\${_safePath(conversationId)}/.pending_upload/"),
    );
    expect(source, contains("\${_safePath(attachmentId)}.cipher"));
    expect(source, contains('scheduleDelivery: false'));
    expect(source, contains('uploadEncryptedAttachment('));
    expect(
        source, isNot(contains('Future<ChatContent> _uploadEncryptedMedia')));
  });
}
