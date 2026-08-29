import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('媒体先持久落库再由后台队列上传 R2 密文', () {
    final source = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final sendMediaStart = source.indexOf(
      'Future<List<ChatDeliveryResult>> sendMedia',
    );
    final prepareStart = source.indexOf(
      'Future<ChatContent> _prepareEncryptedMedia',
    );
    final flushStart = source.indexOf('Future<void> _sendPendingMedia');

    expect(sendMediaStart, greaterThanOrEqualTo(0));
    expect(prepareStart, greaterThan(sendMediaStart));
    expect(flushStart, greaterThan(prepareStart));
    expect(source, contains("/\${_safePath(conversationId)}/.pending_upload/"));
    expect(source, contains("\${_safePath(attachmentId)}.cipher"));
    expect(source, contains('scheduleDelivery: false'));
    expect(source, contains('uploadEncryptedAttachment('));
    expect(
      source,
      isNot(contains('Future<ChatContent> _uploadEncryptedMedia')),
    );
  });

  // 中文注释：源码合同锁定成功落库才 ACK 与有限退避，防止再次出现静默丢消息或无限请求。
  test('私信只在本机成功落库后ACK且失败执行有界低频退避', () {
    final runtime = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final flow = File('lib/chat/chat_flow.dart').readAsStringSync();

    expect(runtime, contains('static const _outboundRetryDelays'));
    expect(runtime, contains('Duration(seconds: 60)'));
    expect(runtime, contains('attempt >= _outboundRetryDelays.length'));
    expect(
      runtime,
      contains("lastRealtimeDiagnosticCode = 'chat_mailbox_envelope_retry'"),
    );
    expect(runtime, isNot(contains("'chat_mailbox_envelope_rejected'")));
    expect(flow, contains('不存在等待 Welcome 后回放的状态'));
    expect(flow, isNot(contains('await _store.savePendingInbound(')));
  });

  // 中文注释：锁定邮箱补拉发生在实时 socket 之前，并禁止旧在线探测信令回流。
  test('普通消息补拉邮箱不依赖WSS、WebRTC或对端在线', () {
    final runtime = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final mailboxFetch = runtime.indexOf(
      'await signalContext.transport.fetchMailbox()',
    );
    final socketConnect = runtime.indexOf('connectRealtime(');

    expect(mailboxFetch, greaterThanOrEqualTo(0));
    expect(socketConnect, greaterThan(mailboxFetch));
    expect(runtime, isNot(contains('peer_ready')));
    expect(runtime, contains('_scheduleOutgoingRetry'));
  });

  test('会员只在创建待发送消息时校验且可靠队列不重复读取可变缓存', () {
    final source = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final saveStart = source.indexOf(
      'Future<String> _savePendingDirectPayload',
    );
    final scheduleStart = source.indexOf('void _schedulePendingOutgoing');
    final flushStart = source.indexOf('Future<bool> _flushPendingOutgoing');
    final expireStart = source.indexOf('Future<void> _expirePendingOutgoing');

    expect(saveStart, greaterThanOrEqualTo(0));
    expect(scheduleStart, greaterThan(saveStart));
    expect(flushStart, greaterThan(scheduleStart));
    expect(expireStart, greaterThan(flushStart));
    expect(
      source.substring(saveStart, scheduleStart),
      contains('ChatMediaLimits.chatAuthorizedFor(account.cidNumber)'),
    );
    expect(
      source.substring(flushStart, expireStart),
      isNot(contains('ChatMediaLimits.chatAuthorizedFor')),
    );
  });
}
