import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/chat/chat_flow.dart';
import 'package:citizenapp/chat/chat_media_limits.dart';
import 'package:citizenapp/chat/chat_models.dart';
import 'package:citizenapp/chat/chat_payload.dart';
import 'package:citizenapp/chat/chat_runtime.dart';
import 'package:citizenapp/chat/crypto/mls_boundary.dart';
import 'package:citizenapp/chat/proto/chat_envelope.pb.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:citizenapp/chat/transport/chat_transport.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/isar_test_env.dart';

/// 附件本地加密测试密钥(固定 32 字节,仅测试用)。
final List<int> _testAttachmentKey = List<int>.generate(
  32,
  (i) => (i * 5) % 256,
);

/// CID 是信封、MLS 名册与投递的唯一身份键；当前账户只负责本地解锁和鉴权。
const _bobAccountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _bobCidNumber = 'CN220-CTZN2-100000002-2026';
const _ownerCidNumber = 'CN220-CTZN2-100000001-2026';
const _aliceAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _genesisHash =
    '0x4242424242424242424242424242424242424242424242424242424242424242';

Future<ChatBindingFenceToken> _activateBinding(
  ChatStore store,
  String accountId,
) =>
    store.activateBindingFence(
      AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: _ownerCidNumber,
        bindingRevision: 1,
        accountId: accountId,
      ),
    );

void main() {
  useIsolatedIsar();

  // 中文注释：一对一私信始终只生成一个 HPKE Application 信封，失败重试复用同一待发送消息。
  test('端到端密文 wire message 只写入目标 ChatEnvelope 字段', () {
    const wire = MlsWireMessage(
      wireBytes: [0x01, 0x02],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-formal',
      messageKind: MlsMessageKind.welcome,
      ratchetTreeBytes: [0x0a, 0x0b],
    );

    final restored = imMlsWireMessageFromEnvelope(
      wire.toEnvelope(
        envelopeId: 'env-formal',
        senderCidNumber: _ownerCidNumber,
        recipientCidNumber: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        createdAtMillis: 1,
        ttlMillis: 60000,
      ),
    );

    expect(restored.messageKind, MlsMessageKind.welcome);
    expect(restored.wireBytes, [0x01, 0x02]);
    expect(restored.ratchetTreeBytes, [0x0a, 0x0b]);
  });

  test('接收设备离线时密文只留发送设备本机队列', () async {
    final store = ChatStore();
    final delivered = <ChatEnvelope>[];
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (envelope, _, __) async {
        delivered.add(envelope);
        return ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.mailbox,
          state: ChatMessageDeliveryState.queued,
        );
      },
    );

    await flow.sendText(
      conversationId: 'conv-alice-bob',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientDevicePublicKey: _dummyRecipientDevicePublicKey,
      text: 'hello bob',
    );

    final queued = await store.readQueuedEnvelopes(
      ownerCidNumber: _ownerCidNumber,
      bindingToken: bindingToken,
    );
    expect(queued, hasLength(1));
    expect(
      delivered.every((item) => item.ttlMillis == chatMailboxTtlMillis),
      isTrue,
    );
    expect(
      queued.every((item) => item.recipientCidNumber == _bobCidNumber),
      isTrue,
    );
    for (final item in queued) {
      await store.markOutgoingDelivery(
        ownerCidNumber: _ownerCidNumber,
        envelopeId: item.envelopeId,
        state: ChatMessageDeliveryState.sent,
        bindingToken: bindingToken,
      );
    }
    // 邮箱写入成功后全部 Envelope 都已具备云端耐久副本，本机重试队列清零。
    expect(await store.outboundQueueCount(_ownerCidNumber), 0);
  });

  test('本地消息与出站队列落盘后立即返回，网络投递由会话后台任务继续', () async {
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    Future<void> Function()? scheduledDelivery;
    var deliveryCalls = 0;
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliveryScheduler: (conversationId, delivery) {
        expect(conversationId, 'conv-local-first');
        scheduledDelivery = delivery;
      },
      deliverer: (envelope, _, __) async {
        deliveryCalls += 1;
        return ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.mailbox,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    final results = await flow.sendText(
      conversationId: 'conv-local-first',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientDevicePublicKey: _dummyRecipientDevicePublicKey,
      text: '本地先显示',
    );

    expect(results, isEmpty, reason: '页面发送 Future 只等待本地可靠提交');
    expect(deliveryCalls, 0, reason: '网络任务尚未由后台执行器启动');
    expect(scheduledDelivery, isNotNull);
    final stored = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-local-first',
    );
    expect(stored.single.plaintext, contains('本地先显示'));

    await scheduledDelivery!.call();
    expect(deliveryCalls, 1, reason: '私信只投递一个 HPKE Application');
  });

  test('HPKE Application 落库失败后重试复用同一待发送消息', () async {
    final store = _FailFirstApplicationStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    const conversationId = 'conv-recover-after-persist-failure';
    const pendingLocalMessageId =
        'pending:conv-recover-after-persist-failure:1000:nonce';
    final payload = ChatPayloadCodec.encode(ChatContent.text('崩溃恢复'));
    await store.savePendingOutgoingMessage(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      localMessageId: pendingLocalMessageId,
      conversationId: conversationId,
      recipientCidNumber: _bobCidNumber,
      messageKind: ChatMessageKind.text,
      payload: payload,
      createdAtMillis: 1000,
    );
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (envelope, _, __) async => ChatDeliveryResult(
        envelopeId: envelope.envelopeId,
        transportType: ChatTransportType.mailbox,
        state: ChatMessageDeliveryState.queued,
      ),
    );

    await expectLater(
      flow.sendText(
        conversationId: conversationId,
        senderCidNumber: _ownerCidNumber,
        recipientCidNumber: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        recipientDevicePublicKey: _dummyRecipientDevicePublicKey,
        text: '崩溃恢复',
        pendingLocalMessageId: pendingLocalMessageId,
        createdAtMillis: 1000,
      ),
      throwsStateError,
    );
    var queued = await store.readQueuedEnvelopes(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      conversationId: conversationId,
    );
    expect(queued, isEmpty);

    await flow.sendText(
      conversationId: conversationId,
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientDevicePublicKey: _dummyRecipientDevicePublicKey,
      text: '崩溃恢复',
      pendingLocalMessageId: pendingLocalMessageId,
      createdAtMillis: 1000,
    );

    queued = await store.readQueuedEnvelopes(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      conversationId: conversationId,
    );
    expect(queued, hasLength(1));
    expect(
      queued
          .map(
            (item) => imMlsWireMessageFromEnvelope(
              ChatEnvelope.fromBuffer(item.envelopeBytes),
            ).messageKind,
          )
          .toList(),
      <MlsMessageKind>[MlsMessageKind.application],
    );
    expect(
      await store.readPendingOutgoingMessages(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
        currentAccountId: _aliceAccountId,
        conversationId: conversationId,
      ),
      isEmpty,
    );
  });

  test('实时 callback 严格串行，前一密文未完成前后一密文不会开始', () async {
    final releaseFirst = Completer<void>();
    final events = <String>[];
    final running =
        ChatRuntime.debugRunRealtimeCallbacksForTest(<Future<void> Function()>[
      () async {
        events.add('welcome-start');
        await releaseFirst.future;
        events.add('welcome-end');
      },
      () async {
        events.add('application');
      },
    ]);

    await Future<void>.delayed(Duration.zero);
    expect(events, <String>['welcome-start']);
    releaseFirst.complete();
    await running;
    expect(events, <String>['welcome-start', 'welcome-end', 'application']);
  });

  test('在线设备收到密文后立即解密并写入本机', () async {
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _bobAccountId);
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _bobAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (_, __, ___) => throw StateError('接收端不得重新投递'),
    );
    final welcome = const MlsWireMessage(
      wireBytes: [0x01],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-incoming',
      messageKind: MlsMessageKind.welcome,
      ratchetTreeBytes: [0x02],
    ).toEnvelope(
      envelopeId: 'env-first',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 1,
      ttlMillis: 60000,
    );
    final application = MlsWireMessage(
      wireBytes: utf8.encode(
        ChatPayloadCodec.encode(ChatContent.text('设备直收')),
      ),
      cipherSuite: 'MLS_128',
      conversationId: 'conv-incoming',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-app',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 2,
      ttlMillis: 60000,
    );

    await flow.processIncomingEnvelopeBytes(welcome.writeToBuffer());
    final result = await flow.processIncomingEnvelopeBytes(
      application.writeToBuffer(),
    );

    expect(ChatPayloadCodec.decode(result.plaintext!).text, '设备直收');
    expect(result.acceptedEnvelopes.map((item) => item.envelopeId), <String>[
      'env-app',
    ]);
    final messages = await ChatStore().readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _bobAccountId,
      conversationId: 'conv-incoming',
    );
    expect(ChatPayloadCodec.decode(messages.single.plaintext!).text, '设备直收');
    expect(messages.single.direction, 'incoming');
    expect(
      await store.hasIncomingEnvelope(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
        envelopeId: 'env-app',
        senderCidNumber: _ownerCidNumber,
      ),
      isTrue,
    );
  });

  // 中文注释：私信不存在 Welcome 回放，HPKE 失败必须保留云端信封而不是进入旧缓冲后误 ACK。
  test('私信HPKE解密失败必须上抛且不得进入旧Welcome待处理区', () async {
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _bobAccountId);
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _bobAccountId,
      crypto: _RejectIncomingMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (_, __, ___) => throw StateError('接收端不得重新投递'),
    );
    final application = const MlsWireMessage(
      wireBytes: [1, 2, 3],
      cipherSuite: 'HPKE_BASE_X25519_HKDF_SHA256_AES128GCM',
      conversationId: 'dm:alice:bob:reject',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-hpke-reject',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 2,
      ttlMillis: 60000,
    );

    await expectLater(
      flow.processIncomingEnvelopeBytes(application.writeToBuffer()),
      throwsStateError,
    );
    expect(
      await store.takePendingInbound(
        _ownerCidNumber,
        application.conversationId,
        bindingToken: bindingToken,
      ),
      isEmpty,
    );
  });

  test('两个独立用户可双向发送、接收并在各自本机安全落盘', () async {
    const conversationId = 'dm:alice:bob:bidirectional';
    final aliceStore = ChatStore();
    final bobStore = ChatStore();
    final aliceBinding = await aliceStore.activateBindingFence(
      const AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: _ownerCidNumber,
        bindingRevision: 1,
        accountId: _aliceAccountId,
      ),
    );
    final bobBinding = await bobStore.activateBindingFence(
      const AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: _bobCidNumber,
        bindingRevision: 1,
        accountId: _bobAccountId,
      ),
    );
    final aliceCrypto = _FakeMlsCrypto();
    final bobCrypto = _FakeMlsCrypto();
    final toBob = <List<int>>[];
    final toAlice = <List<int>>[];
    final aliceFlow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: aliceCrypto,
      store: aliceStore,
      bindingToken: aliceBinding,
      deliverer: (envelope, bytes, recipientCidNumber) async {
        expect(recipientCidNumber, _bobCidNumber);
        toBob.add(List<int>.from(bytes));
        return ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.mailbox,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );
    final bobFlow = ChatFlow(
      ownerCidNumber: _bobCidNumber,
      currentAccountId: _bobAccountId,
      crypto: bobCrypto,
      store: bobStore,
      bindingToken: bobBinding,
      deliverer: (envelope, bytes, recipientCidNumber) async {
        expect(recipientCidNumber, _ownerCidNumber);
        toAlice.add(List<int>.from(bytes));
        return ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.mailbox,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    await aliceFlow.sendText(
      conversationId: conversationId,
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientDevicePublicKey: _dummyRecipientDevicePublicKey,
      text: 'A 到 B',
    );
    expect(toBob, hasLength(1), reason: '私信始终只生成一个 HPKE application 信封');
    for (final bytes in toBob) {
      await bobFlow.processIncomingEnvelopeBytes(bytes);
    }

    await bobFlow.sendText(
      conversationId: conversationId,
      senderCidNumber: _bobCidNumber,
      recipientCidNumber: _ownerCidNumber,
      senderDeviceId: 'bob-phone',
      recipientDevicePublicKey: _dummyRecipientDevicePublicKey,
      text: 'B 到 A',
    );
    expect(toAlice, hasLength(1), reason: '回复同样只产生一个 HPKE Application');
    await aliceFlow.processIncomingEnvelopeBytes(toAlice.single);

    final aliceMessages = await aliceStore.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: conversationId,
    );
    final bobMessages = await bobStore.readMessages(
      ownerCidNumber: _bobCidNumber,
      currentAccountId: _bobAccountId,
      conversationId: conversationId,
    );
    expect(
      aliceMessages.map(
        (message) => ChatPayloadCodec.decode(message.plaintext!).text,
      ),
      ['A 到 B', 'B 到 A'],
    );
    expect(aliceMessages.map((message) => message.direction), [
      'outgoing',
      'incoming',
    ]);
    expect(
      bobMessages.map(
        (message) => ChatPayloadCodec.decode(message.plaintext!).text,
      ),
      ['A 到 B', 'B 到 A'],
    );
    expect(bobMessages.map((message) => message.direction), [
      'incoming',
      'outgoing',
    ]);
  });

  test('普通媒体控制必须携带端到端密文内的 R2 解密信息', () {
    final content = ChatContent.media(
      kind: ChatMessageKind.file,
      attachmentId: 'attachment-cloud-1234',
      fileName: 'note.txt',
      mime: 'text/plain',
      byteSize: 4,
      cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      cipherByteSize: 24,
      cipherSha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
    );
    final decoded = ChatPayloadCodec.decode(ChatPayloadCodec.encode(content));
    expect(decoded.attachmentId, 'attachment-cloud-1234');
    expect(decoded.cipherByteSize, 24);
  });

  test('downloadAttachment 拒绝非媒体控制消息', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-neg-');
    addTearDown(() => root.delete(recursive: true));
    for (final control in [
      ChatPayloadCodec.encode(ChatContent.text('hi')),
      ChatPayloadCodec.encode(
        ChatContent.sticker(packId: 'fluent3d', stickerId: 'grinning_face'),
      ),
    ]) {
      await expectLater(
        ChatFlow.downloadAttachment(
          conversationId: 'c',
          controlPlaintext: control,
          cacheDirectory: root,
          attachmentKey: _testAttachmentKey,
          plainDirectory: Directory('${root.path}/.plain'),
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('downloadAttachment 在字节未到达或截断时报错,不返回半成品', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-partial-');
    addTearDown(() => root.delete(recursive: true));
    final control = ChatPayloadCodec.encode(
      ChatContent.media(
        kind: ChatMessageKind.file,
        attachmentId: 'att-x',
        fileName: 'note.txt',
        mime: 'text/plain',
        byteSize: 10,
        cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        cipherByteSize: 30,
        cipherSha256:
            '1111111111111111111111111111111111111111111111111111111111111111',
      ),
    );

    // 缓存缺失 → 未完成传输。
    await expectLater(
      ChatFlow.downloadAttachment(
        conversationId: 'conv-x',
        controlPlaintext: control,
        cacheDirectory: root,
        attachmentKey: _testAttachmentKey,
        plainDirectory: Directory('${root.path}/.plain'),
      ),
      throwsA(isA<StateError>()),
    );

    // 缓存只有 3 字节,控制声明 10 字节 → 视为截断/损坏,拒绝返回。
    final partial = File('${root.path}/partial.txt');
    await partial.writeAsBytes(const [1, 2, 3], flush: true);
    await ChatFlow.importAttachmentFileToCache(
      conversationId: 'conv-x',
      attachmentId: 'att-x',
      fileName: 'note.txt',
      contentType: 'text/plain',
      sourcePath: partial.path,
      byteSize: 3,
      moveSource: false,
      cacheDirectory: root,
      attachmentKey: _testAttachmentKey,
      plainDirectory: Directory('${root.path}/.plain'),
    );
    await expectLater(
      ChatFlow.downloadAttachment(
        conversationId: 'conv-x',
        controlPlaintext: control,
        cacheDirectory: root,
        attachmentKey: _testAttachmentKey,
        plainDirectory: Directory('${root.path}/.plain'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('附件下载只读取设备本地缓存,返回路径(不载入整块字节)', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-device-');
    addTearDown(() => root.delete(recursive: true));
    final src = File('${root.path}/src-note.txt');
    await src.writeAsBytes(utf8.encode('local only'), flush: true);
    final saved = await ChatFlow.importAttachmentFileToCache(
      conversationId: 'conv-cache',
      attachmentId: 'attachment-1',
      fileName: 'note.txt',
      contentType: 'text/plain',
      sourcePath: src.path,
      byteSize: 10,
      moveSource: false,
      cacheDirectory: root,
      attachmentKey: _testAttachmentKey,
      plainDirectory: Directory('${root.path}/.plain'),
    );
    final control = ChatPayloadCodec.encode(
      ChatContent.media(
        kind: ChatMessageKind.file,
        attachmentId: 'attachment-1',
        fileName: 'note.txt',
        mime: 'text/plain',
        byteSize: 10,
        cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        cipherByteSize: 30,
        cipherSha256:
            '2222222222222222222222222222222222222222222222222222222222222222',
      ),
    );

    final loaded = await ChatFlow.downloadAttachment(
      conversationId: 'conv-cache',
      controlPlaintext: control,
      cacheDirectory: root,
      attachmentKey: _testAttachmentKey,
      plainDirectory: Directory('${root.path}/.plain'),
    );

    expect(loaded.filePath, saved.filePath);
    expect(await File(loaded.filePath).readAsString(), 'local only');
  });

  test('importAttachmentFileToCache moveSource 把临时文件移入缓存并删源', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-move-');
    addTearDown(() => root.delete(recursive: true));
    final temp = File('${root.path}/incoming.part');
    await temp.writeAsBytes(utf8.encode('moved bytes'), flush: true);

    final saved = await ChatFlow.importAttachmentFileToCache(
      conversationId: 'conv-move',
      attachmentId: 'att-move',
      fileName: 'clip.bin',
      contentType: 'application/octet-stream',
      sourcePath: temp.path,
      byteSize: 11,
      moveSource: true,
      cacheDirectory: root,
      attachmentKey: _testAttachmentKey,
      plainDirectory: Directory('${root.path}/.plain'),
    );

    expect(await temp.exists(), isFalse); // 源(临时)已移走,不留残余
    expect(await File(saved.filePath).readAsString(), 'moved bytes');
  });

  test('门③:接收落盘二次门控——超限删临时不入缓存,达标则移入', () async {
    ChatMediaLimits.applyMembershipLevel('freedom');
    final root = await Directory.systemTemp.createTemp('gmb-chat-gate3-');
    addTearDown(() => root.delete(recursive: true));

    // 超限:byteSize 声明超图片 100MB 上限 → 删临时,返回 null,缓存为空。
    final big = File('${root.path}/big.part');
    await big.writeAsBytes(const [1, 2, 3], flush: true);
    final rejected = await ChatFlow.acceptReceivedMediaToCache(
      conversationId: 'conv-g3',
      attachmentId: 'att-big',
      fileName: 'p.jpg',
      contentType: 'image/jpeg',
      tempFilePath: big.path,
      byteSize: ChatMediaLimits.maxBytesForLevel('freedom') + 1,
      cacheDirectory: root,
      attachmentKey: _testAttachmentKey,
      plainDirectory: Directory('${root.path}/.plain'),
    );
    expect(rejected, isNull);
    expect(await big.exists(), isFalse);

    // 达标:临时文件移入缓存并可读回。
    final ok = File('${root.path}/ok.part');
    await ok.writeAsBytes(utf8.encode('ok'), flush: true);
    final accepted = await ChatFlow.acceptReceivedMediaToCache(
      conversationId: 'conv-g3',
      attachmentId: 'att-ok',
      fileName: 'ok.bin',
      contentType: 'application/octet-stream',
      tempFilePath: ok.path,
      byteSize: 2,
      cacheDirectory: root,
      attachmentKey: _testAttachmentKey,
      plainDirectory: Directory('${root.path}/.plain'),
    );
    expect(accepted, isNotNull);
    expect(await ok.exists(), isFalse);
    expect(await File(accepted!.filePath).readAsString(), 'ok');
  });

  test('七天 TTL 过期信封转为失败并退出本机重试队列', () async {
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (envelope, _, __) async => ChatDeliveryResult(
        envelopeId: envelope.envelopeId,
        transportType: ChatTransportType.mailbox,
        state: ChatMessageDeliveryState.queued,
      ),
    );
    await flow.sendText(
      conversationId: 'conv-expired',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientDevicePublicKey: _dummyRecipientDevicePublicKey,
      text: '不会继续重试的旧消息',
    );
    final queued = await store.readQueuedEnvelopes(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
    );
    expect(queued, hasLength(1));
    for (final item in queued) {
      await store.markOutgoingDelivery(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
        envelopeId: item.envelopeId,
        state: ChatMessageDeliveryState.queued,
        errorMessage: 'chat_envelope_expired',
      );
    }
    expect(
      await store.readQueuedEnvelopes(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
      ),
      isEmpty,
    );
    final messages = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-expired',
    );
    expect(
      messages.every(
        (message) => message.deliveryState == ChatMessageDeliveryState.failed,
      ),
      isTrue,
    );
  });

  test('入站后置附件任务失败不撤销已落库消息', () async {
    final receiverStore = ChatStore();
    final receiverBinding =
        await _activateBinding(receiverStore, _aliceAccountId);
    final payload = ChatPayloadCodec.encode(
      ChatContent.text('附件后置失败也必须保留的消息'),
    );
    final application = MlsWireMessage(
      wireBytes: utf8.encode(payload),
      cipherSuite: 'HPKE_BASE_X25519_HKDF_SHA256_AES128GCM',
      conversationId: 'conv-after-store',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-after-store',
      senderCidNumber: _bobCidNumber,
      recipientCidNumber: _ownerCidNumber,
      senderDeviceId: 'bob-phone',
      createdAtMillis: 2,
      ttlMillis: 60000,
    );

    final hookCalled = Completer<void>();
    final receiver = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: receiverStore,
      bindingToken: receiverBinding,
      deliverer: (envelope, _, __) async => ChatDeliveryResult(
        envelopeId: envelope.envelopeId,
        transportType: ChatTransportType.mailbox,
        state: ChatMessageDeliveryState.sent,
      ),
      afterIncomingStore: (_, __) async {
        hookCalled.complete();
        throw StateError('模拟附件下载失败');
      },
    );

    final result = await receiver
        .processIncomingEnvelopeBytes(application.writeToBuffer());
    await hookCalled.future;
    expect(result.accepted, isTrue);
    final messages = await receiverStore.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-after-store',
    );
    expect(messages.single.plaintext, contains('附件后置失败也必须保留的消息'));
  });
}

class _FakeMlsCrypto implements MlsCrypto {
  final Set<String> _ready = <String>{};

  @override
  Future<String> readDevicePublicKey(ChatDevice identity) async =>
      identity.devicePublicKey;

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = false,
  }) async =>
      _dummyKeyPackage();

  @override
  Future<MlsOutboundMessage> encrypt({
    required String conversationId,
    required String recipientCidNumber,
    required String recipientDevicePublicKey,
    required List<int> plaintext,
  }) async {
    _ready.add(conversationId);
    if (recipientDevicePublicKey.isEmpty) throw StateError('接收设备公钥不能为空');
    return MlsOutboundMessage(
      conversationId: conversationId,
      applicationMessage: MlsWireMessage(
        wireBytes: plaintext,
        cipherSuite: 'MLS_128',
        conversationId: conversationId,
        messageKind: MlsMessageKind.application,
      ),
    );
  }

  @override
  Future<List<int>> decrypt(MlsWireMessage message) async =>
      (await processIncoming(message)).plaintext ?? const [];

  @override
  Future<MlsInboundMessage> processIncoming(MlsWireMessage message) async {
    if (message.messageKind == MlsMessageKind.welcome) {
      _ready.add(message.conversationId);
      return MlsInboundMessage(
        conversationId: message.conversationId,
        messageKind: message.messageKind,
      );
    }
    _ready.add(message.conversationId);
    return MlsInboundMessage(
      conversationId: message.conversationId,
      messageKind: message.messageKind,
      plaintext: message.wireBytes,
    );
  }
}

class _FailFirstApplicationStore extends ChatStore {
  bool _failNextApplication = true;

  @override
  Future<void> saveOutgoingEnvelope({
    required ChatBindingFenceToken bindingToken,
    required String ownerCidNumber,
    required String currentAccountId,
    required ChatEnvelope envelope,
    required List<int> envelopeBytes,
    required String recipientCidNumber,
    required ChatMessageKind messageKind,
    required ChatMessageDeliveryState deliveryState,
    String? plaintext,
    String? pendingLocalMessageId,
    ChatPendingMedia? pendingMedia,
  }) {
    if (_failNextApplication) {
      _failNextApplication = false;
      throw StateError('模拟前一密文已落盘后后一密文写入中断');
    }
    return super.saveOutgoingEnvelope(
      bindingToken: bindingToken,
      ownerCidNumber: ownerCidNumber,
      currentAccountId: currentAccountId,
      envelope: envelope,
      envelopeBytes: envelopeBytes,
      recipientCidNumber: recipientCidNumber,
      messageKind: messageKind,
      deliveryState: deliveryState,
      plaintext: plaintext,
      pendingLocalMessageId: pendingLocalMessageId,
      pendingMedia: pendingMedia,
    );
  }
}

class _RejectIncomingMlsCrypto extends _FakeMlsCrypto {
  @override
  Future<MlsInboundMessage> processIncoming(MlsWireMessage message) async {
    throw StateError('模拟 HPKE 解密失败');
  }
}

const String _dummyRecipientDevicePublicKey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

MlsKeyPackage _dummyKeyPackage() => const MlsKeyPackage(
      cidNumber: _bobCidNumber,
      deviceId: 'bob-phone',
      devicePublicKey: 'aabb',
      keyPackageId: 'kp-bob',
      keyPackageBytes: [1],
      cipherSuite: 'MLS_128',
      notBeforeMillis: 1,
      notAfterMillis: 9999999999999,
      lastResort: false,
    );
