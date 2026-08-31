import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/chat/chat_product_policy.dart';
import 'package:gmb_chat_sdk/chat_sdk.dart';

import 'package:flutter_test/flutter_test.dart';

import '../support/isar_test_env.dart';

/// 附件本地加密测试密钥(固定 32 字节,仅测试用)。
final List<int> _testAttachmentKey = List<int>.generate(
  32,
  (i) => (i * 5) % 256,
);

/// CID 是消息、MLS 名册与投递的唯一身份键；当前账户只负责本地解锁和鉴权。
const _bobAccountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _bobCidNumber = 'CN220-CTZN2-100000002-2026';
const _ownerUserId = 'CN220-CTZN2-100000001-2026';
const _aliceAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _genesisHash =
    '0x4242424242424242424242424242424242424242424242424242424242424242';

Future<ChatBindingFenceToken> _activateBinding(
  ChatStore store,
  String accountId,
) => store.activateBindingFence(
  ChatDataBinding(
    keyDomain: _genesisHash,
    userId: _ownerUserId,
    bindingRevision: 1,
    accountId: accountId,
  ),
);

void main() {
  useIsolatedIsar();

  // 中文注释：消息只承载标准 MLS wire，接收端必须交由 OpenMLS 判型。
  test('端到端密文 wire message 只写入目标 EncryptedMessage 字段', () {
    const wire = MlsWireMessage(
      wireBytes: [0x01, 0x02],
      conversationId: 'conv-formal',
      messageKind: MlsMessageKind.welcome,
    );

    final restored = mlsWireMessageFromEncryptedMessage(
      wire.toEncryptedMessage(
        messageId: 'env-formal',
        senderUserId: _ownerUserId,
        recipientUserId: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        recipientDeviceId: 'bob-phone',
        createdAtMillis: 1,
      ),
    );

    expect(restored.messageKind, MlsMessageKind.unknown);
    expect(restored.wireBytes, [0x01, 0x02]);
  });

  test('接收设备离线时密文只留发送设备本机队列', () async {
    final store = ChatStore();
    final delivered = <EncryptedMessage>[];
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    final flow = ChatFlow(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (message, _, __, ___) async {
        delivered.add(message);
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.queued,
        );
      },
    );

    await flow.sendText(
      conversationId: 'conv-alice-bob',
      senderUserId: _ownerUserId,
      recipientUserId: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackages: <MlsKeyPackage>[_dummyKeyPackage()],
      text: 'hello bob',
    );

    final queued = await store.readQueuedMessages(
      ownerUserId: _ownerUserId,
      bindingToken: bindingToken,
    );
    expect(queued, hasLength(1));
    expect(delivered.every((item) => item.deliveries.length == 1), isTrue);
    expect(
      queued.every((item) => item.recipientUserId == _bobCidNumber),
      isTrue,
    );
    for (final item in queued) {
      await store.markOutgoingDelivery(
        ownerUserId: _ownerUserId,
        messageId: item.messageId,
        state: ChatMessageDeliveryState.sent,
        bindingToken: bindingToken,
      );
    }
    // 邮箱写入成功后全部 Message 都已具备云端耐久副本，本机重试队列清零。
    expect(await store.outboundQueueCount(_ownerUserId), 0);
  });

  test('本地消息与出站队列落盘后立即返回，网络投递由会话后台任务继续', () async {
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    Future<void> Function()? scheduledDelivery;
    var deliveryCalls = 0;
    final flow = ChatFlow(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliveryScheduler: (conversationId, delivery) {
        expect(conversationId, 'conv-local-first');
        scheduledDelivery = delivery;
      },
      deliverer: (message, _, __, ___) async {
        deliveryCalls += 1;
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    final results = await flow.sendText(
      conversationId: 'conv-local-first',
      senderUserId: _ownerUserId,
      recipientUserId: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackages: <MlsKeyPackage>[_dummyKeyPackage()],
      text: '本地先显示',
    );

    expect(results, isEmpty, reason: '页面发送 Future 只等待本地可靠提交');
    expect(deliveryCalls, 0, reason: '网络任务尚未由后台执行器启动');
    expect(scheduledDelivery, isNotNull);
    final stored = await store.readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-local-first',
    );
    expect(
      ChatPayloadCodec.decode(stored.single.plaintext ?? '').text,
      '本地先显示',
    );

    await scheduledDelivery!.call();
    expect(deliveryCalls, 1, reason: '既有双人 MLS 群只投递一个 Application');
  });

  test('OpenMLS Application 落库失败后重试复用同一待发送消息', () async {
    final store = _FailFirstApplicationStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    const conversationId = 'conv-recover-after-persist-failure';
    const pendingLocalMessageId =
        'pending:conv-recover-after-persist-failure:1000:nonce';
    final payload = ChatPayloadCodec.encode(ChatContent.text('崩溃恢复'));
    await store.savePendingOutgoingMessage(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      localMessageId: pendingLocalMessageId,
      conversationId: conversationId,
      recipientUserId: _bobCidNumber,
      messageKind: ChatMessageKind.text,
      payload: payload,
      createdAtMillis: 1000,
    );
    final flow = ChatFlow(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (message, _, __, ___) async => ChatDeliveryResult(
        messageId: message.messageId,
        transportType: ChatTransportType.server,
        state: ChatMessageDeliveryState.queued,
      ),
    );

    await expectLater(
      flow.sendText(
        conversationId: conversationId,
        senderUserId: _ownerUserId,
        recipientUserId: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        recipientKeyPackages: <MlsKeyPackage>[_dummyKeyPackage()],
        text: '崩溃恢复',
        pendingLocalMessageId: pendingLocalMessageId,
        createdAtMillis: 1000,
      ),
      throwsStateError,
    );
    var queued = await store.readQueuedMessages(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      conversationId: conversationId,
    );
    expect(queued, isEmpty);

    await flow.sendText(
      conversationId: conversationId,
      senderUserId: _ownerUserId,
      recipientUserId: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackages: <MlsKeyPackage>[_dummyKeyPackage()],
      text: '崩溃恢复',
      pendingLocalMessageId: pendingLocalMessageId,
      createdAtMillis: 1000,
    );

    queued = await store.readQueuedMessages(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      conversationId: conversationId,
    );
    expect(queued, hasLength(1));
    expect(
      queued
          .map(
            (item) => mlsWireMessageFromEncryptedMessage(
              EncryptedMessage.fromBuffer(item.messageBytes),
            ).messageKind,
          )
          .toList(),
      // 中文注释：传输消息不携带业务类型，接收端必须由 OpenMLS 解密结果确定语义。
      <MlsMessageKind>[MlsMessageKind.unknown],
    );
    expect(
      await store.readPendingOutgoingMessages(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
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
        ChatRuntimeCore.debugRunRealtimeCallbacksForTest(<Future<void> Function()>[
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
      ownerUserId: _ownerUserId,
      currentAccountId: _bobAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (_, __, ___, ____) => throw StateError('接收端不得重新投递'),
    );
    final welcome =
        const MlsWireMessage(
          wireBytes: [0x01],
          conversationId: 'conv-incoming',
          messageKind: MlsMessageKind.welcome,
        ).toEncryptedMessage(
          messageId: 'env-first',
          senderUserId: _ownerUserId,
          recipientUserId: _bobCidNumber,
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'bob-phone',
          createdAtMillis: 1,
        );
    final application =
        MlsWireMessage(
          wireBytes: utf8.encode(
            ChatPayloadCodec.encode(ChatContent.text('设备直收')),
          ),
          conversationId: 'conv-incoming',
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'env-app',
          senderUserId: _ownerUserId,
          recipientUserId: _bobCidNumber,
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'bob-phone',
          createdAtMillis: 2,
        );

    await flow.processIncomingMessageBytes(welcome.writeToBuffer());
    final result = await flow.processIncomingMessageBytes(
      application.writeToBuffer(),
    );

    expect(ChatPayloadCodec.decode(result.plaintext!).text, '设备直收');
    expect(result.acceptedMessages.map((item) => item.messageId), <String>[
      'env-app',
    ]);
    final messages = await ChatStore().readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _bobAccountId,
      conversationId: 'conv-incoming',
    );
    expect(ChatPayloadCodec.decode(messages.single.plaintext!).text, '设备直收');
    expect(messages.single.direction, 'incoming');
    expect(
      await store.hasIncomingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        messageId: 'env-app',
        senderUserId: _ownerUserId,
      ),
      isTrue,
    );
  });

  // 中文注释：非缺失 Welcome 的 OpenMLS 失败必须保留云端消息，禁止错误 ACK。
  test('私信OpenMLS处理失败必须上抛且不得进入Welcome待处理区', () async {
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _bobAccountId);
    final flow = ChatFlow(
      ownerUserId: _ownerUserId,
      currentAccountId: _bobAccountId,
      crypto: _RejectIncomingMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (_, __, ___, ____) => throw StateError('接收端不得重新投递'),
    );
    final application =
        const MlsWireMessage(
          wireBytes: [1, 2, 3],
          conversationId: 'dm:alice:bob:reject',
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'env-mls-reject',
          senderUserId: _ownerUserId,
          recipientUserId: _bobCidNumber,
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'bob-phone',
          createdAtMillis: 2,
        );

    await expectLater(
      flow.processIncomingMessageBytes(application.writeToBuffer()),
      throwsStateError,
    );
    expect(
      await store.takePendingInbound(
        _ownerUserId,
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
      const ChatDataBinding(
        keyDomain: _genesisHash,
        userId: _ownerUserId,
        bindingRevision: 1,
        accountId: _aliceAccountId,
      ),
    );
    final bobBinding = await bobStore.activateBindingFence(
      const ChatDataBinding(
        keyDomain: _genesisHash,
        userId: _bobCidNumber,
        bindingRevision: 1,
        accountId: _bobAccountId,
      ),
    );
    final aliceCrypto = _FakeMlsCrypto();
    final bobCrypto = _FakeMlsCrypto();
    final toBob = <List<int>>[];
    final toAlice = <List<int>>[];
    final aliceFlow = ChatFlow(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      crypto: aliceCrypto,
      store: aliceStore,
      bindingToken: aliceBinding,
      deliverer: (message, bytes, recipientUserId, recipientDeviceId) async {
        expect(recipientUserId, _bobCidNumber);
        toBob.add(List<int>.from(bytes));
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );
    final bobFlow = ChatFlow(
      ownerUserId: _bobCidNumber,
      currentAccountId: _bobAccountId,
      crypto: bobCrypto,
      store: bobStore,
      bindingToken: bobBinding,
      deliverer: (message, bytes, recipientUserId, recipientDeviceId) async {
        expect(recipientUserId, _ownerUserId);
        toAlice.add(List<int>.from(bytes));
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    await aliceFlow.sendText(
      conversationId: conversationId,
      senderUserId: _ownerUserId,
      recipientUserId: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackages: <MlsKeyPackage>[_dummyKeyPackage()],
      text: 'A 到 B',
    );
    expect(toBob, hasLength(1), reason: '既有双人 MLS 群只生成一个 Application 消息');
    for (final bytes in toBob) {
      await bobFlow.processIncomingMessageBytes(bytes);
    }

    await bobFlow.sendText(
      conversationId: conversationId,
      senderUserId: _bobCidNumber,
      recipientUserId: _ownerUserId,
      senderDeviceId: 'bob-phone',
      recipientKeyPackages: <MlsKeyPackage>[
        _dummyKeyPackage(userId: _ownerUserId, deviceId: 'alice-phone'),
      ],
      text: 'B 到 A',
    );
    expect(toAlice, hasLength(1), reason: '回复同样只产生一个 OpenMLS Application');
    await aliceFlow.processIncomingMessageBytes(toAlice.single);

    final aliceMessages = await aliceStore.readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      conversationId: conversationId,
    );
    final bobMessages = await bobStore.readMessages(
      ownerUserId: _bobCidNumber,
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
      maxByteSize: ChatMediaLimits.forMime('image/jpeg'),
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
      maxByteSize: ChatMediaLimits.forMime('application/octet-stream'),
      cacheDirectory: root,
      attachmentKey: _testAttachmentKey,
      plainDirectory: Directory('${root.path}/.plain'),
    );
    expect(accepted, isNotNull);
    expect(await ok.exists(), isFalse);
    expect(await File(accepted!.filePath).readAsString(), 'ok');
  });

  test('七天 TTL 过期消息转为失败并退出本机重试队列', () async {
    final store = ChatStore();
    final bindingToken = await _activateBinding(store, _aliceAccountId);
    final flow = ChatFlow(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: store,
      bindingToken: bindingToken,
      deliverer: (message, _, __, ___) async => ChatDeliveryResult(
        messageId: message.messageId,
        transportType: ChatTransportType.server,
        state: ChatMessageDeliveryState.queued,
      ),
    );
    await flow.sendText(
      conversationId: 'conv-expired',
      senderUserId: _ownerUserId,
      recipientUserId: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackages: <MlsKeyPackage>[_dummyKeyPackage()],
      text: '不会继续重试的旧消息',
    );
    final queued = await store.readQueuedMessages(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
    );
    expect(queued, hasLength(1));
    for (final item in queued) {
      await store.markOutgoingDelivery(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        messageId: item.messageId,
        state: ChatMessageDeliveryState.queued,
        errorMessage: 'chat_message_expired',
      );
    }
    expect(
      await store.readQueuedMessages(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
      ),
      isEmpty,
    );
    final messages = await store.readMessages(
      ownerUserId: _ownerUserId,
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

  // 回归：附件网络失败发生在持久化之后，不能撤销消息或阻断邮箱 ACK。
  test('入站后置附件任务失败不撤销已落库消息', () async {
    final receiverStore = ChatStore();
    final receiverBinding = await _activateBinding(
      receiverStore,
      _aliceAccountId,
    );
    final payload = ChatPayloadCodec.encode(ChatContent.text('附件后置失败也必须保留的消息'));
    final application =
        MlsWireMessage(
          wireBytes: utf8.encode(payload),
          conversationId: 'conv-after-store',
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'env-after-store',
          senderUserId: _bobCidNumber,
          recipientUserId: _ownerUserId,
          senderDeviceId: 'bob-phone',
          recipientDeviceId: 'alice-phone',
          createdAtMillis: 2,
        );

    final hookCalled = Completer<void>();
    final receiver = ChatFlow(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      crypto: _FakeMlsCrypto(),
      store: receiverStore,
      bindingToken: receiverBinding,
      deliverer: (message, _, __, ___) async => ChatDeliveryResult(
        messageId: message.messageId,
        transportType: ChatTransportType.server,
        state: ChatMessageDeliveryState.sent,
      ),
      afterIncomingStore: (_, __) async {
        hookCalled.complete();
        throw StateError('模拟附件下载失败');
      },
    );

    final result = await receiver.processIncomingMessageBytes(
      application.writeToBuffer(),
    );
    await hookCalled.future;
    expect(result.accepted, isTrue);
    final messages = await receiverStore.readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-after-store',
    );
    expect(
      ChatPayloadCodec.decode(messages.single.plaintext ?? '').text,
      '附件后置失败也必须保留的消息',
    );
  });
}

class _FakeMlsCrypto implements MlsGroupCrypto {
  final Map<String, List<String>> _rosters = <String, List<String>>{};
  final Map<String, int> _epochs = <String, int>{};

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = true,
  }) async =>
      _dummyKeyPackage(userId: identity.userId, deviceId: identity.deviceId);

  @override
  Future<GroupCreated> createGroup(String groupId) async {
    _roster(groupId);
    _epochs[groupId] = 0;
    return GroupCreated(groupId: groupId, epoch: 0);
  }

  @override
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  ) async {
    final roster = _roster(groupId);
    for (final keyPackage in keyPackages) {
      final identity = '${keyPackage.userId}:${keyPackage.deviceId}';
      if (!roster.contains(identity)) roster.add(identity);
    }
    final epoch = (_epochs[groupId] ?? 0) + 1;
    _epochs[groupId] = epoch;
    return GroupCommitBundle(
      groupId: groupId,
      epoch: epoch,
      commit: _wire(groupId, const <int>[0x02], MlsMessageKind.commit),
      welcome: _wire(groupId, const <int>[0x01], MlsMessageKind.welcome),
    );
  }

  @override
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberUserIds,
  ) async {
    _roster(groupId).removeWhere(
      (identity) => memberUserIds.contains(identity.split(':').first),
    );
    final epoch = (_epochs[groupId] ?? 0) + 1;
    _epochs[groupId] = epoch;
    return GroupCommitBundle(
      groupId: groupId,
      epoch: epoch,
      commit: _wire(groupId, const <int>[0x02], MlsMessageKind.commit),
      removedUserIds: memberUserIds,
    );
  }

  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) async => _wire(groupId, plaintext, MlsMessageKind.application);

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage message) async {
    if (message.wireBytes.length == 1 && message.wireBytes.single == 0x01) {
      return GroupInbound(
        groupId: message.conversationId,
        kind: GroupInboundKind.welcome,
        status: GroupProcessStatus.applied,
        messageEpoch: _epochs[message.conversationId] ?? 0,
        groupEpoch: _epochs[message.conversationId] ?? 0,
        selfRemoved: false,
        memberIdentities: _roster(message.conversationId),
      );
    }
    return GroupInbound(
      groupId: message.conversationId,
      kind: GroupInboundKind.application,
      status: GroupProcessStatus.applied,
      messageEpoch: _epochs[message.conversationId] ?? 0,
      groupEpoch: _epochs[message.conversationId] ?? 0,
      selfRemoved: false,
      plaintext: message.wireBytes,
    );
  }

  @override
  Future<GroupState> groupState(String groupId) async => GroupState(
    groupId: groupId,
    epoch: _epochs[groupId] ?? 0,
    memberIdentities: List<String>.from(_roster(groupId)),
  );

  List<String> _roster(String groupId) => _rosters.putIfAbsent(
    groupId,
    () => <String>['$_ownerUserId:alice-phone', '$_bobCidNumber:bob-phone'],
  );

  MlsWireMessage _wire(
    String conversationId,
    List<int> bytes,
    MlsMessageKind kind,
  ) => MlsWireMessage(
    wireBytes: bytes,
    conversationId: conversationId,
    messageKind: kind,
  );
}

class _FailFirstApplicationStore extends ChatStore {
  bool _failNextApplication = true;

  @override
  Future<void> saveOutgoingMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required String recipientUserId,
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
    return super.saveOutgoingMessage(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      message: message,
      messageBytes: messageBytes,
      recipientUserId: recipientUserId,
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
  Future<GroupInbound> groupProcess(MlsWireMessage message) async {
    throw StateError('模拟 OpenMLS 处理失败');
  }
}

MlsKeyPackage _dummyKeyPackage({
  String userId = _bobCidNumber,
  String deviceId = 'bob-phone',
}) => MlsKeyPackage(
  userId: userId,
  deviceId: deviceId,
  keyPackageRef: List<String>.filled(64, 'a').join(),
  keyPackageBytes: [1],
  cipherSuite: 'MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519',
  notBeforeMillis: 1,
  notAfterMillis: 9999999999999,
  lastResort: true,
);
