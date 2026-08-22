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

  test('MLS wire message 只写入目标 ChatEnvelope 字段', () {
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
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (envelope, _, __) async => ChatDeliveryResult(
        envelopeId: envelope.envelopeId,
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.queued,
      ),
    );

    await flow.sendText(
      conversationId: 'conv-alice-bob',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: _dummyKeyPackage(),
      text: 'hello bob',
    );

    final queued = await store.readQueuedEnvelopes(
      ownerCidNumber: _ownerCidNumber,
      bindingToken: bindingToken,
    );
    expect(queued, hasLength(2));
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
    final awaitingStoredConfirmation = await store.readQueuedEnvelopes(
      ownerCidNumber: _ownerCidNumber,
      bindingToken: bindingToken,
    );
    expect(awaitingStoredConfirmation, hasLength(1));
    expect(
      imMlsWireMessageFromEnvelope(
        ChatEnvelope.fromBuffer(
          awaitingStoredConfirmation.single.envelopeBytes,
        ),
      ).messageKind,
      MlsMessageKind.application,
    );
    expect(
      await store.acknowledgeStoredEnvelope(
        ownerCidNumber: _ownerCidNumber,
        envelopeId: awaitingStoredConfirmation.single.envelopeId,
        recipientCidNumber: _bobCidNumber,
        bindingToken: bindingToken,
      ),
      isTrue,
    );
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
          transportType: ChatTransportType.webrtc,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    final results = await flow.sendText(
      conversationId: 'conv-local-first',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: _dummyKeyPackage(),
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
    expect(deliveryCalls, 2, reason: 'Welcome 与 Application 仍按原顺序投递');
  });

  test('首次会话只保存 Welcome 后重试，Application 不覆盖握手信封', () async {
    final store = _FailFirstApplicationStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    const conversationId = 'conv-recover-after-welcome';
    const pendingLocalMessageId =
        'pending:conv-recover-after-welcome:1000:nonce';
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.queued,
      ),
    );

    await expectLater(
      flow.sendText(
        conversationId: conversationId,
        senderCidNumber: _ownerCidNumber,
        recipientCidNumber: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        recipientKeyPackage: _dummyKeyPackage(),
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
    expect(queued, hasLength(1));
    expect(
      imMlsWireMessageFromEnvelope(
        ChatEnvelope.fromBuffer(queued.single.envelopeBytes),
      ).messageKind,
      MlsMessageKind.welcome,
    );

    await flow.sendText(
      conversationId: conversationId,
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      text: '崩溃恢复',
      pendingLocalMessageId: pendingLocalMessageId,
      createdAtMillis: 1000,
    );

    queued = await store.readQueuedEnvelopes(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      conversationId: conversationId,
    );
    expect(queued, hasLength(2));
    expect(queued.map((item) => item.envelopeId).toSet(), hasLength(2));
    expect(
      queued
          .map((item) => imMlsWireMessageFromEnvelope(
                ChatEnvelope.fromBuffer(item.envelopeBytes),
              ).messageKind)
          .toList(),
      <MlsMessageKind>[
        MlsMessageKind.welcome,
        MlsMessageKind.application,
      ],
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

  test('实时 callback 严格串行，Welcome 未完成前 Application 不会开始', () async {
    final releaseWelcome = Completer<void>();
    final events = <String>[];
    final running =
        ChatRuntime.debugRunRealtimeCallbacksForTest(<Future<void> Function()>[
      () async {
        events.add('welcome-start');
        await releaseWelcome.future;
        events.add('welcome-end');
      },
      () async {
        events.add('application');
      },
    ]);

    await Future<void>.delayed(Duration.zero);
    expect(events, <String>['welcome-start']);
    releaseWelcome.complete();
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
      envelopeId: 'env-welcome',
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

    expect(
      ChatPayloadCodec.decode(result.plaintext!).text,
      '设备直收',
    );
    expect(result.acceptedEnvelopes.map((item) => item.envelopeId),
        <String>['env-app']);
    final messages = await ChatStore().readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _bobAccountId,
      conversationId: 'conv-incoming',
    );
    expect(
      ChatPayloadCodec.decode(messages.single.plaintext!).text,
      '设备直收',
    );
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
          transportType: ChatTransportType.webrtc,
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
          transportType: ChatTransportType.webrtc,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    await aliceFlow.sendText(
      conversationId: conversationId,
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: _dummyKeyPackage(),
      text: 'A 到 B',
    );
    expect(toBob, hasLength(2), reason: '首次私聊必须按 Welcome、Application 顺序到达');
    for (final bytes in toBob) {
      await bobFlow.processIncomingEnvelopeBytes(bytes);
    }

    await bobFlow.sendText(
      conversationId: conversationId,
      senderCidNumber: _bobCidNumber,
      recipientCidNumber: _ownerCidNumber,
      senderDeviceId: 'bob-phone',
      text: 'B 到 A',
    );
    expect(toAlice, hasLength(1), reason: '已有 MLS 会话回复只产生 Application');
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
      aliceMessages
          .map((message) => ChatPayloadCodec.decode(message.plaintext!).text),
      ['A 到 B', 'B 到 A'],
    );
    expect(
      aliceMessages.map((message) => message.direction),
      ['outgoing', 'incoming'],
    );
    expect(
      bobMessages
          .map((message) => ChatPayloadCodec.decode(message.plaintext!).text),
      ['A 到 B', 'B 到 A'],
    );
    expect(
      bobMessages.map((message) => message.direction),
      ['incoming', 'outgoing'],
    );
  });

  test('媒体经设备通道流式发送、控制不含云端引用,且路径/自存以同一 attachmentId 关联', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-send-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/photo.jpg');
    await source.writeAsBytes(const [1, 2, 3, 4], flush: true);

    String? sentSourcePath;
    int? sentByteSize;
    String? sentAttachmentId;
    String? sentFileName;
    String? savedSourcePath;
    String? savedAttachmentId;
    int? savedByteSize;
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.sent,
      ),
    );

    await flow.sendMedia(
      conversationId: 'conv-attachment',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: _dummyKeyPackage(),
      media: ChatMediaDraft(
        kind: ChatMessageKind.image,
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
        sourcePath: source.path,
        byteSize: 4,
      ),
      sendDeviceAttachment: ({
        required recipientCidNumber,
        required conversationId,
        required attachmentId,
        required fileName,
        required contentType,
        required sourcePath,
        required byteSize,
      }) async {
        sentSourcePath = sourcePath;
        sentByteSize = byteSize;
        sentAttachmentId = attachmentId;
        sentFileName = fileName;
      },
      saveLocalAttachment: ({
        required conversationId,
        required attachmentId,
        required fileName,
        required contentType,
        required sourcePath,
        required byteSize,
      }) async {
        savedSourcePath = sourcePath;
        savedAttachmentId = attachmentId;
        savedByteSize = byteSize;
      },
    );

    expect(sentSourcePath, source.path);
    expect(sentByteSize, 4);
    final message = (await ChatStore().readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-attachment',
    ))
        .single
        .plaintext!;
    // 控制载荷是端到端明文,只带元数据,绝无任何云端对象引用。
    expect(message, contains('"kind":"image"'));
    expect(message, contains('"byte_size":4'));
    expect(message, isNot(contains('object_key')));
    expect(message, isNot(contains('manifest')));
    // WebRTC 字节与 MLS 控制消息必须以同一 attachmentId 关联,否则接收端按控制
    // 里的 id 找不到设备通道存下的字节。
    final controlAttachmentId = ChatPayloadCodec.decode(message).attachmentId;
    expect(controlAttachmentId, isNotNull);
    expect(sentAttachmentId, controlAttachmentId);
    expect(sentFileName, 'photo.jpg');
    // 发送方本机自存副本用同一 id/源/大小,发送方才能在会话里看到自己发出的媒体。
    expect(savedAttachmentId, controlAttachmentId);
    expect(savedSourcePath, source.path);
    expect(savedByteSize, 4);
  });

  test('语音经 sendMedia 完整发送并保留 60 秒上限内的时长元数据', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-voice-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/voice.m4a');
    await source.writeAsBytes(const [1, 2, 3, 4], flush: true);

    String? sentContentType;
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.sent,
      ),
    );

    await flow.sendMedia(
      conversationId: 'conv-voice',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: _dummyKeyPackage(),
      media: ChatMediaDraft(
        kind: ChatMessageKind.audio,
        fileName: 'voice.m4a',
        contentType: 'audio/mp4',
        sourcePath: source.path,
        byteSize: 4,
        durationMs: 60000,
      ),
      sendDeviceAttachment: ({
        required recipientCidNumber,
        required conversationId,
        required attachmentId,
        required fileName,
        required contentType,
        required sourcePath,
        required byteSize,
      }) async {
        sentContentType = contentType;
      },
      saveLocalAttachment: ({
        required conversationId,
        required attachmentId,
        required fileName,
        required contentType,
        required sourcePath,
        required byteSize,
      }) async {},
    );

    final message = (await ChatStore().readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-voice',
    ))
        .single
        .plaintext!;
    final content = ChatPayloadCodec.decode(message);
    expect(content.kind, ChatMessageKind.audio);
    expect(content.mime, 'audio/mp4');
    expect(content.durationMs, 60000);
    expect(content.width, isNull);
    expect(content.height, isNull);
    expect(sentContentType, 'audio/mp4');
  });

  test('语音本地落盘后立即通知界面，不等待唤醒、建连和 WebRTC 投递', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-voice-local-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/voice.m4a');
    await source.writeAsBytes(const [1, 2, 3, 4], flush: true);

    final callbackEntered = Completer<void>();
    final releaseCallback = Completer<void>();
    final deliveryEntered = Completer<void>();
    final releaseDelivery = Completer<void>();
    final events = <String>[];
    var sendCompleted = false;
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    final flow = ChatFlow(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (envelope, _, __) async {
        events.add('network-delivery');
        if (!deliveryEntered.isCompleted) deliveryEntered.complete();
        await releaseDelivery.future;
        return ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.webrtc,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    final sending = flow
        .sendMedia(
          conversationId: 'conv-voice-local',
          senderCidNumber: _ownerCidNumber,
          recipientCidNumber: _bobCidNumber,
          senderDeviceId: 'alice-phone',
          recipientKeyPackage: _dummyKeyPackage(),
          media: ChatMediaDraft(
            kind: ChatMessageKind.audio,
            fileName: 'voice.m4a',
            contentType: 'audio/mp4',
            sourcePath: source.path,
            byteSize: 4,
            durationMs: 8000,
          ),
          sendDeviceAttachment: ({
            required recipientCidNumber,
            required conversationId,
            required attachmentId,
            required fileName,
            required contentType,
            required sourcePath,
            required byteSize,
          }) async {},
          saveLocalAttachment: ({
            required conversationId,
            required attachmentId,
            required fileName,
            required contentType,
            required sourcePath,
            required byteSize,
          }) async {
            events.add('local-attachment');
          },
          onLocalCommitted: () async {
            events.add('local-commit');
            callbackEntered.complete();
            await releaseCallback.future;
          },
        )
        .whenComplete(() => sendCompleted = true);

    await callbackEntered.future.timeout(const Duration(seconds: 2));
    expect(events, <String>['local-attachment', 'local-commit']);
    expect(deliveryEntered.isCompleted, isFalse);
    expect(sendCompleted, isFalse);
    final localMessages = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-voice-local',
    );
    expect(localMessages, hasLength(1));
    expect(localMessages.single.messageKind, ChatMessageKind.audio);

    releaseCallback.complete();
    await deliveryEntered.future.timeout(const Duration(seconds: 2));
    expect(sendCompleted, isFalse);
    releaseDelivery.complete();
    await sending;
    expect(sendCompleted, isTrue);
  });

  test('门①:sendMedia 超限文件抛 ChatMediaTooLargeException 且不发字节', () async {
    var deviceSendCalls = 0;
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.sent,
      ),
    );

    await expectLater(
      flow.sendMedia(
        conversationId: 'conv-oversize',
        senderCidNumber: _ownerCidNumber,
        recipientCidNumber: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        recipientKeyPackage: _dummyKeyPackage(),
        // byteSize 超出自由档 10MB 上限;门控看 byteSize 字段,发前即拦,不触碰源文件。
        media: ChatMediaDraft(
          kind: ChatMessageKind.image,
          fileName: 'huge.jpg',
          contentType: 'image/jpeg',
          sourcePath: '/nonexistent',
          byteSize: ChatMediaLimits.maxBytesForLevel('freedom') + 1,
        ),
        sendDeviceAttachment: ({
          required recipientCidNumber,
          required conversationId,
          required attachmentId,
          required fileName,
          required contentType,
          required sourcePath,
          required byteSize,
        }) async {
          deviceSendCalls += 1;
        },
      ),
      throwsA(isA<ChatMediaTooLargeException>()),
    );
    expect(deviceSendCalls, 0);
  });

  test('sendMedia 控制消息加密失败时绝不先发 WebRTC 字节(零泄漏顺序)', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-leak-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/photo.jpg');
    await source.writeAsBytes(const [9, 9, 9], flush: true);
    var deviceSendCalls = 0;
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.sent,
      ),
    );

    // 全新会话且不提供 KeyPackage:_FakeMlsCrypto.encrypt 抛错,模拟首次会话缺
    // KeyPackage。字节必须在加密成功之后才发,否则会泄漏一条永远送不达的媒体。
    await expectLater(
      flow.sendMedia(
        conversationId: 'conv-no-keypackage',
        senderCidNumber: _ownerCidNumber,
        recipientCidNumber: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        media: ChatMediaDraft(
          kind: ChatMessageKind.image,
          fileName: 'photo.jpg',
          contentType: 'image/jpeg',
          sourcePath: source.path,
          byteSize: 3,
        ),
        sendDeviceAttachment: ({
          required recipientCidNumber,
          required conversationId,
          required attachmentId,
          required fileName,
          required contentType,
          required sourcePath,
          required byteSize,
        }) async {
          deviceSendCalls += 1;
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(deviceSendCalls, 0);
  });

  test('sendMedia 在线送达:登记待投递后随即标记已送达(同一 attachmentId,净零)', () async {
    final root = await Directory.systemTemp.createTemp('gmb-online-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/photo.jpg');
    await source.writeAsBytes(const [1, 2, 3, 4], flush: true);
    final recorded = <String>[];
    final delivered = <String>[];
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.sent,
      ),
    );

    await flow.sendMedia(
      conversationId: 'conv-online',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: _dummyKeyPackage(),
      media: ChatMediaDraft(
        kind: ChatMessageKind.image,
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
        sourcePath: source.path,
        byteSize: 4,
      ),
      // sendDeviceAttachment 成功(对方在线)。
      sendDeviceAttachment: ({
        required recipientCidNumber,
        required conversationId,
        required attachmentId,
        required fileName,
        required contentType,
        required sourcePath,
        required byteSize,
      }) async {},
      recordPendingMedia: (id) async => recorded.add(id),
      onDeviceDelivered: (id) async => delivered.add(id),
    );

    // 先登记待投递、字节送达后随即标记已送达:同一 attachmentId,净零残留。
    expect(recorded, hasLength(1));
    expect(delivered, hasLength(1));
    expect(recorded.single, delivered.single);
  });

  test('sendMedia 对离线对端:控制消息仍成立、登记待投递、不抛错', () async {
    final root = await Directory.systemTemp.createTemp('gmb-offline-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/photo.jpg');
    await source.writeAsBytes(const [1, 2, 3, 4], flush: true);
    final recorded = <String>[];
    final delivered = <String>[];
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.queued,
      ),
    );

    // sendDeviceAttachment 抛错模拟对方离线(WebRTC 连不上);sendMedia 必须吞掉
    // 该异常:控制消息已成立,字节留待上线补发。
    final results = await flow.sendMedia(
      conversationId: 'conv-offline',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: _dummyKeyPackage(),
      media: ChatMediaDraft(
        kind: ChatMessageKind.image,
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
        sourcePath: source.path,
        byteSize: 4,
      ),
      sendDeviceAttachment: ({
        required recipientCidNumber,
        required conversationId,
        required attachmentId,
        required fileName,
        required contentType,
        required sourcePath,
        required byteSize,
      }) async {
        throw const SocketException('offline');
      },
      recordPendingMedia: (id) async => recorded.add(id),
      onDeviceDelivered: (id) async => delivered.add(id),
    );

    // 控制消息仍落库成立,sendMedia 未抛错。
    expect(results, isNotEmpty);
    final message = (await ChatStore().readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-offline',
    ))
        .single;
    expect(message.messageKind, ChatMessageKind.image);
    // 登记了待投递,但未标记已送达(离线,字节没发出去)。
    expect(recorded, hasLength(1));
    expect(delivered, isEmpty);
  });

  test('媒体正式控制消息与待补发字节事实原子落盘', () async {
    final root = await Directory.systemTemp.createTemp('gmb-media-atomic-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/photo.jpg');
    await source.writeAsBytes(const [1, 2, 3, 4], flush: true);
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
        transportType: ChatTransportType.webrtc,
        state: ChatMessageDeliveryState.queued,
      ),
    );

    await expectLater(
      flow.sendMedia(
        conversationId: 'conv-media-atomic',
        senderCidNumber: _ownerCidNumber,
        recipientCidNumber: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        recipientKeyPackage: _dummyKeyPackage(),
        media: ChatMediaDraft(
          kind: ChatMessageKind.image,
          fileName: 'photo.jpg',
          contentType: 'image/jpeg',
          sourcePath: source.path,
          byteSize: 4,
        ),
        sendDeviceAttachment: ({
          required recipientCidNumber,
          required conversationId,
          required attachmentId,
          required fileName,
          required contentType,
          required sourcePath,
          required byteSize,
        }) async {},
        // 模拟正式消息事务提交后的后置通知中断；可靠字节事实不能依赖它。
        recordPendingMedia: (_) async => throw StateError('模拟后置媒体通知中断'),
      ),
      throwsStateError,
    );

    final pending = await store.readPendingOutgoingMedia(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
    );
    expect(pending, hasLength(1));
    expect(pending.single.conversationId, 'conv-media-atomic');
    expect(pending.single.fileName, 'photo.jpg');
    expect(await store.outboundQueueCount(_ownerCidNumber), 2);
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
      fileName: 'ok.txt',
      contentType: 'text/plain',
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
    MlsKeyPackage? recipientKeyPackage,
    required List<int> plaintext,
  }) async {
    if (!_ready.add(conversationId) && recipientKeyPackage == null) {
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
    if (recipientKeyPackage == null) {
      throw StateError('首次 MLS 会话必须提供对方 KeyPackage');
    }
    return MlsOutboundMessage(
      conversationId: conversationId,
      welcomeMessage: MlsWireMessage(
        wireBytes: const [1],
        cipherSuite: 'MLS_128',
        conversationId: conversationId,
        messageKind: MlsMessageKind.welcome,
        ratchetTreeBytes: const [2],
      ),
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
    if (!_ready.contains(message.conversationId)) {
      throw StateError('MLS group missing');
    }
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
      throw StateError('模拟 Welcome 已落盘后 Application 写入中断');
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
