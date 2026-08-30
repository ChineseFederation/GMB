import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 源码合同锁定私信持久化、附件传输和可靠队列的先后顺序。
void main() {
  test('媒体先持久落库且R2上传不得阻塞同会话后续消息', () {
    final source = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final sendMediaStart = source.indexOf(
      'Future<List<ChatDeliveryResult>> sendMedia',
    );
    final prepareStart = source.indexOf(
      'Future<ChatContent> _prepareEncryptedMedia',
    );
    final schedulerStart = source.indexOf('void _schedulePendingMediaUpload');
    final uploadStart = source.indexOf(
      'Future<void> _uploadPendingDirectMedia',
    );
    final flushStart = source.indexOf('Future<bool> _flushPendingOutgoing');
    final flushEnd = source.indexOf(
      'Future<void> _expirePendingOutgoing',
      flushStart,
    );
    final flushBody = source.substring(flushStart, flushEnd);

    expect(sendMediaStart, greaterThanOrEqualTo(0));
    expect(prepareStart, greaterThan(sendMediaStart));
    expect(schedulerStart, greaterThan(prepareStart));
    expect(uploadStart, greaterThan(schedulerStart));
    expect(source, contains("/\${_safePath(conversationId)}/.pending_upload/"));
    expect(source, contains("\${_safePath(attachmentId)}.cipher"));
    expect(source, contains('scheduleDelivery: false'));
    expect(source, contains('uploadEncryptedAttachment('));
    expect(flushBody, contains('_schedulePendingMediaUpload('));
    expect(flushBody, contains('continue;'));
    expect(source, contains('Chat 附件密文仍在后台上传'));
    expect(
      source,
      isNot(contains('Future<ChatContent> _uploadEncryptedMedia')),
    );
  });

  test('附件下载必须先创建临时目录再打开R2目标文件', () {
    final source = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final cacheStart = source.indexOf(
      'Future<void> _cacheIncomingCloudAttachment',
    );
    final createDirectory = source.indexOf(
      'await tempDirectory.create(recursive: true);',
      cacheStart,
    );
    final downloadStart = source.indexOf(
      'await context.transport.downloadEncryptedAttachment(',
      cacheStart,
    );

    expect(cacheStart, greaterThanOrEqualTo(0));
    expect(createDirectory, greaterThan(cacheStart));
    expect(downloadStart, greaterThan(createDirectory));
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

  // 中文注释：先建立实时收件再补拉邮箱，锁死两步之间不得出现消息滞留窗口。
  test('普通消息先建立WSS再补拉可靠邮箱且不依赖WebRTC', () {
    final runtime = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final mailboxFetch = runtime.indexOf(
      'await signalContext.transport.fetchMailbox()',
    );
    final socketConnect = runtime.indexOf('connectRealtime(');

    expect(mailboxFetch, greaterThanOrEqualTo(0));
    expect(socketConnect, greaterThanOrEqualTo(0));
    expect(mailboxFetch, greaterThan(socketConnect));
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

  test('本机状态认证失败只重建Chat域且停止盲重试', () {
    final source = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final resetStart = source.indexOf('Future<void> _resetLocalChatState');
    final resetEnd = source.indexOf(
      'Future<_ChatAccountContext> _buildAccountContext',
      resetStart,
    );
    final resetBody = source.substring(resetStart, resetEnd);
    final scheduleStart = source.indexOf('void _schedulePendingOutgoing');
    final scheduleEnd = source.indexOf(
      'void _schedulePendingOutgoingRetry',
      scheduleStart,
    );
    final scheduleBody = source.substring(scheduleStart, scheduleEnd);

    expect(source, contains('_buildAccountContextWithStateReset(account)'));
    expect(resetBody, contains('await _store.clearAllForCidNumber'));
    expect(resetBody, contains('await stateStore.reset();'));
    expect(resetBody, contains('await _store.convergeFinalizedBinding'));
    expect(resetBody, contains('devicePublicKeyCachePreferenceKey'));
    expect(
      resetBody,
      isNot(contains('prefs.remove(deviceIdPreferenceKey(account.cidNumber))')),
    );
    expect(resetBody, isNot(contains('_kPushRegistrationPrefix')));
    expect(
      scheduleBody,
      contains('error is MlsNativeException && error.requiresStateReset'),
    );
    expect(source, contains('stage=state_reset_complete code=ok'));
  });

  test('附件上传失败按附件退避且只由transport中止一次', () {
    final runtime = File('lib/chat/chat_runtime.dart').readAsStringSync();
    final transport = File(
      'lib/chat/transport/chat_cloud_transport.dart',
    ).readAsStringSync();
    final uploadStart = runtime.indexOf(
      'Future<void> _uploadPendingDirectMedia',
    );
    final uploadEnd = runtime.indexOf(
      'Future<void> _sendPendingOutgoing',
      uploadStart,
    );
    final uploadBody = runtime.substring(uploadStart, uploadEnd);

    expect(runtime, contains('_mediaUploadRetryAt[attachmentId]'));
    expect(runtime, contains('static bool _mediaUploadBusy = false;'));
    expect(runtime, contains('static final Set<String> _mediaBytesInFlight'));
    expect(runtime, contains('receiveOnly: true'));
    expect(runtime, contains('if (_receiveOnly) return false;'));
    expect(runtime, contains('1 => const Duration(seconds: 5)'));
    expect(runtime, contains('2 => const Duration(seconds: 15)'));
    expect(runtime, contains('3 => const Duration(minutes: 1)'));
    expect(runtime, contains('_ => const Duration(minutes: 5)'));
    final headersAt = transport.indexOf('..headers.addAll(');
    final lengthAt = transport.indexOf(
      '..contentLength = byteSize;',
      headersAt,
    );
    expect(headersAt, greaterThanOrEqualTo(0));
    expect(lengthAt, greaterThan(headersAt));
    expect(
      uploadBody,
      isNot(
        contains('context.transport\n          .abortAttachment(attachmentId)'),
      ),
    );
  });
}
