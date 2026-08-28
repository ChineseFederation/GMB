import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:citizenapp/chat/crypto/mls_session.dart';
import 'package:citizenapp/chat/chat_models.dart';
import 'package:citizenapp/chat/chat_payload.dart';
import 'package:citizenapp/chat/group/group_model.dart';
import 'package:citizenapp/chat/proto/chat_envelope.pb.dart' as pb;
import 'package:citizenapp/isar/chat_isar.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:citizenapp/security/local_data_key.dart';

import '../support/isar_test_env.dart';

/// CID 是信封、MLS 名册和待投递路由的唯一身份键；当前钱包账户只解锁本地密钥。
const _bobCidNumber = 'CN220-CTZN2-100000002-2026';
const _ownerCidNumber = 'CN220-CTZN2-100000001-2026';
const _aliceAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _nextAccountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _carolCidNumber = 'CN220-CTZN2-100000003-2026';
const _testBinding = AccountDataBinding(
  genesisHash:
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  cidNumber: _ownerCidNumber,
  bindingRevision: 1,
  accountId: _aliceAccountId,
);
const _nextBinding = AccountDataBinding(
  genesisHash:
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  cidNumber: _ownerCidNumber,
  bindingRevision: 2,
  accountId: _nextAccountId,
);

String _payload(String text) => ChatPayloadCodec.encode(ChatContent.text(text));

void main() {
  useIsolatedIsar();

  test('Isar store persists outgoing, pending, and incoming Chat records',
      () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    final envelope = const MlsWireMessage(
      wireBytes: [0x68, 0x69],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-store',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-store',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 10,
      ttlMillis: 60000,
    );

    await store.saveOutgoingEnvelope(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
      recipientCidNumber: _bobCidNumber,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('hi'),
    );
    await store.markOutgoingDelivery(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      envelopeId: 'env-store',
      state: ChatMessageDeliveryState.sent,
    );

    final outgoing = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-store',
    );
    expect(outgoing.single.deliveryState, ChatMessageDeliveryState.sent);
    expect(ChatPayloadCodec.decode(outgoing.single.plaintext!).text, 'hi');
    // sent 表示 CitizenServe 已持久保存密文，本机可靠重试副本立即收口。
    expect(await store.outboundQueueCount(_ownerCidNumber), 0);

    await store.savePendingInbound(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
      reason: 'waiting for welcome',
    );
    expect(await store.pendingInboundCount(_ownerCidNumber), 1);

    final pending = await store.takePendingInbound(
      _ownerCidNumber,
      'conv-store',
      bindingToken: bindingToken,
    );
    expect(pending.single.envelopeId, 'env-store');
    expect(await store.pendingInboundCount(_ownerCidNumber), 0);

    await store.saveIncomingEnvelope(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
      messageKind: ChatMessageKind.text,
      plaintext: _payload('hi back'),
    );
    final conversations = await store.readConversationPreviews(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
    );
    expect(conversations.single.unreadCount, 1);
    expect(conversations.single.lastMessage, 'hi back');

    // 当前窗口只清除已展示时间点以内的未读数，保证稍后到达的新消息不会被误标已读。
    await store.markConversationRead(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      conversationId: 'conv-store',
      readThroughMillis: 10,
    );
    expect(
      (await store.readConversationPreviews(
        ownerCidNumber: _ownerCidNumber,
        currentAccountId: _aliceAccountId,
      )).single.unreadCount,
      0,
    );
  });

  test('队列与待投递媒体动作读取拒绝 fence generation 推进前的旧 token', () async {
    final store = ChatStore();
    final oldToken = await store.activateBindingFence(_testBinding);
    final envelope = const MlsWireMessage(
      wireBytes: [0x68, 0x69],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-stale-action',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-stale-action',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 10,
      ttlMillis: 60000,
    );
    await store.saveOutgoingEnvelope(
      bindingToken: oldToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
      recipientCidNumber: _bobCidNumber,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('stale action'),
    );
    await store.recordOutgoingMedia(
      bindingToken: oldToken,
      ownerCidNumber: _ownerCidNumber,
      attachmentId: 'att-stale-action',
      recipientCidNumber: _bobCidNumber,
      conversationId: 'conv-stale-action',
      fileName: 'stale.bin',
      contentType: 'application/octet-stream',
      byteSize: 3,
    );
    expect(
      await store.readQueuedEnvelopes(
        bindingToken: oldToken,
        ownerCidNumber: _ownerCidNumber,
      ),
      hasLength(1),
    );
    expect(
      await store.readPendingOutgoingMedia(
        bindingToken: oldToken,
        ownerCidNumber: _ownerCidNumber,
      ),
      hasLength(1),
    );

    await store.isolateInaccessibleBinding(
      previous: _testBinding,
      current: _nextBinding,
    );

    await expectLater(
      store.readQueuedEnvelopes(
        bindingToken: oldToken,
        ownerCidNumber: _ownerCidNumber,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.readPendingOutgoingMedia(
        bindingToken: oldToken,
        ownerCidNumber: _ownerCidNumber,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('出站重试按 envelope 创建时间排序，Welcome 始终先于 Application', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    pb.ChatEnvelope envelope({
      required String id,
      required int createdAt,
      required MlsMessageKind kind,
    }) =>
        MlsWireMessage(
          wireBytes: <int>[createdAt],
          cipherSuite: 'MLS_128',
          conversationId: 'conv-order',
          messageKind: kind,
        ).toEnvelope(
          envelopeId: id,
          senderCidNumber: _ownerCidNumber,
          recipientCidNumber: _bobCidNumber,
          senderDeviceId: 'alice-phone',
          createdAtMillis: createdAt,
          ttlMillis: 60000,
        );
    final application = envelope(
      id: 'env-application',
      createdAt: 11,
      kind: MlsMessageKind.application,
    );
    final welcome = envelope(
      id: 'env-welcome',
      createdAt: 10,
      kind: MlsMessageKind.welcome,
    );
    // 故意反序写入，读取仍必须按 MLS 创建顺序返回。
    for (final item in <pb.ChatEnvelope>[application, welcome]) {
      await store.queueOutgoingEnvelope(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
        envelope: item,
        envelopeBytes: item.writeToBuffer(),
        recipientCidNumber: _bobCidNumber,
        deliveryState: ChatMessageDeliveryState.queued,
      );
    }

    final queued = await store.readQueuedEnvelopes(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
    );
    expect(
      queued.map((item) => item.envelopeId),
      <String>['env-welcome', 'env-application'],
    );
  });

  test('聊天窗口只按当前 conversationId 索引读取待发送队列', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);

    Future<void> queue(String conversationId, String envelopeId) async {
      final envelope = MlsWireMessage(
        wireBytes: const <int>[1],
        cipherSuite: 'MLS_128',
        conversationId: conversationId,
        messageKind: MlsMessageKind.application,
      ).toEnvelope(
        envelopeId: envelopeId,
        senderCidNumber: _ownerCidNumber,
        recipientCidNumber: _bobCidNumber,
        senderDeviceId: 'alice-phone',
        createdAtMillis: 10,
        ttlMillis: 60000,
      );
      await store.queueOutgoingEnvelope(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
        envelope: envelope,
        envelopeBytes: envelope.writeToBuffer(),
        recipientCidNumber: _bobCidNumber,
        deliveryState: ChatMessageDeliveryState.queued,
      );
    }

    await queue('conv-current', 'env-current');
    await queue('conv-unrelated', 'env-unrelated');

    final current = await store.readQueuedEnvelopes(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      conversationId: 'conv-current',
    );
    expect(current.map((item) => item.envelopeId), <String>['env-current']);
  });

  test('Isar store deletes one local conversation without touching others',
      () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    final targetEnvelope = const MlsWireMessage(
      wireBytes: [0x01],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-delete',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-delete',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 10,
      ttlMillis: 60000,
    );
    final keptEnvelope = const MlsWireMessage(
      wireBytes: [0x02],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-keep',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-keep',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _carolCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 20,
      ttlMillis: 60000,
    );

    await store.saveOutgoingEnvelope(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      envelope: targetEnvelope,
      envelopeBytes: targetEnvelope.writeToBuffer(),
      recipientCidNumber: _bobCidNumber,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('delete me'),
    );
    await store.savePendingInbound(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      envelope: targetEnvelope,
      envelopeBytes: targetEnvelope.writeToBuffer(),
      reason: 'waiting',
    );
    await store.saveOutgoingEnvelope(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      envelope: keptEnvelope,
      envelopeBytes: keptEnvelope.writeToBuffer(),
      recipientCidNumber: _carolCidNumber,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.sent,
      plaintext: _payload('keep me'),
    );

    expect(await store.outboundQueueCount(_ownerCidNumber), 2);
    expect(await store.pendingInboundCount(_ownerCidNumber), 1);

    await store.deleteConversation(
      _ownerCidNumber,
      'conv-delete',
      bindingToken: bindingToken,
    );

    expect(
      await store.readMessages(
        ownerCidNumber: _ownerCidNumber,
        currentAccountId: _aliceAccountId,
        conversationId: 'conv-delete',
      ),
      isEmpty,
    );
    expect(await store.pendingInboundCount(_ownerCidNumber), 0);
    expect(await store.outboundQueueCount(_ownerCidNumber), 1);

    final conversations = await store.readConversationPreviews(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
    );
    expect(conversations.single.conversationId, 'conv-keep');
    expect(
      ChatPayloadCodec.decode((await store.readMessages(
        ownerCidNumber: _ownerCidNumber,
        currentAccountId: _aliceAccountId,
        conversationId: 'conv-keep',
      ))
              .single
              .plaintext!)
          .text,
      'keep me',
    );
  });

  test('待设备投递媒体队列:登记 / 按对端读 / 删 / 会话删连带清理', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      attachmentId: 'att-1',
      recipientCidNumber: _bobCidNumber,
      conversationId: 'conv-a',
      fileName: 'p.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
    );
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      attachmentId: 'att-2',
      recipientCidNumber: _carolCidNumber,
      conversationId: 'conv-b',
      fileName: 'v.mp4',
      contentType: 'video/mp4',
      byteSize: 200,
    );
    expect(await store.outgoingMediaCount(_ownerCidNumber), 2);

    final forBob = await store.readPendingOutgoingMedia(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
    );
    expect(forBob.single.attachmentId, 'att-1');
    expect(forBob.single.fileName, 'p.jpg');
    expect(forBob.single.conversationId, 'conv-a');
    expect(forBob.single.byteSize, 100);

    await store.deleteOutgoingMedia(
      _ownerCidNumber,
      'att-1',
      _bobCidNumber,
      bindingToken: bindingToken,
    ); // 收到 ack 后删除
    expect(await store.outgoingMediaCount(_ownerCidNumber), 1);

    // 删会话 conv-b 连带清理其待投递媒体,不留孤儿。
    await store.deleteConversation(
      _ownerCidNumber,
      'conv-b',
      bindingToken: bindingToken,
    );
    expect(await store.outgoingMediaCount(_ownerCidNumber), 0);
  });

  test('群媒体:同一 attachmentId 发多成员各占一行,按成员删', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    for (final memberCidNumber in [
      'CN220-CTZN2-100000004-2026',
      'CN220-CTZN2-100000005-2026',
      'CN220-CTZN2-100000006-2026',
    ]) {
      await store.recordOutgoingMedia(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
        attachmentId: 'att-grp',
        recipientCidNumber: memberCidNumber,
        conversationId: 'grp:a:n',
        fileName: 'g.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      );
    }
    expect(await store.outgoingMediaCount(_ownerCidNumber), 3);
    // 仅 c 收到 ack → 删 c 的行,b/d 待投递保留。
    await store.deleteOutgoingMedia(
      _ownerCidNumber,
      'att-grp',
      'CN220-CTZN2-100000005-2026',
      bindingToken: bindingToken,
    );
    expect(await store.outgoingMediaCount(_ownerCidNumber), 2);
    final forB = await store.readPendingOutgoingMedia(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      recipientCidNumber: 'CN220-CTZN2-100000004-2026',
    );
    expect(forB.single.attachmentId, 'att-grp');
  });

  test('clearAllForCidNumber 连带清理该 CID 会话的待投递媒体', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    // 以出站信封建立 owner CID 的会话行(conversationId=conv-own)。
    final envelope = const MlsWireMessage(
      wireBytes: [1],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-own',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-own',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 1,
      ttlMillis: 60000,
    );
    await store.saveOutgoingEnvelope(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
      recipientCidNumber: _bobCidNumber,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('hi'),
    );
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      attachmentId: 'att-own',
      recipientCidNumber: _bobCidNumber,
      conversationId: 'conv-own',
      fileName: 'p.jpg',
      contentType: 'image/jpeg',
      byteSize: 5,
    );
    await store.upsertGroupShell(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      groupId: 'group-clear',
      groupName: '待清理群',
      creatorCidNumber: _ownerCidNumber,
      epoch: 1,
    );
    await store.reconcileGroupRoster(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      groupId: 'group-clear',
      members: const <String, GroupMemberRole>{
        _ownerCidNumber: GroupMemberRole.admin,
        _bobCidNumber: GroupMemberRole.member,
      },
      epoch: 1,
    );
    await store.bufferGroupCommit(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      groupId: 'group-clear',
      messageEpoch: 2,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
    );
    expect(await store.outgoingMediaCount(_ownerCidNumber), 1);
    final before = await ChatIsar.instance.read((isar) async => (
          groups: await isar.chatGroupEntitys
              .filter()
              .ownerCidNumberEqualTo(_ownerCidNumber)
              .count(),
          members: await isar.chatGroupMemberEntitys
              .filter()
              .ownerCidNumberEqualTo(_ownerCidNumber)
              .count(),
          commits: await isar.chatGroupPendingCommitEntitys
              .filter()
              .ownerCidNumberEqualTo(_ownerCidNumber)
              .count(),
        ));
    expect(before.groups, 1);
    expect(before.members, 2);
    expect(before.commits, 1);

    await store.clearAllForCidNumber(_ownerCidNumber);
    expect(await store.outgoingMediaCount(_ownerCidNumber), 0);
    final after = await ChatIsar.instance.read((isar) async => (
          groups: await isar.chatGroupEntitys
              .filter()
              .ownerCidNumberEqualTo(_ownerCidNumber)
              .count(),
          members: await isar.chatGroupMemberEntitys
              .filter()
              .ownerCidNumberEqualTo(_ownerCidNumber)
              .count(),
          commits: await isar.chatGroupPendingCommitEntitys
              .filter()
              .ownerCidNumberEqualTo(_ownerCidNumber)
              .count(),
        ));
    expect(after.groups, 0);
    expect(after.members, 0);
    expect(after.commits, 0);
  });

  test('无签名交接时保留永久聊天密文并清空此前绑定的瞬时状态', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    final envelope = const MlsWireMessage(
      wireBytes: [0x68, 0x69],
      cipherSuite: 'MLS_128',
      conversationId: 'conv-isolate',
      messageKind: MlsMessageKind.application,
    ).toEnvelope(
      envelopeId: 'env-isolate',
      senderCidNumber: _ownerCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      createdAtMillis: 10,
      ttlMillis: 60000,
    );

    await store.saveOutgoingEnvelope(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
      recipientCidNumber: _bobCidNumber,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('必须保留的历史密文'),
    );
    await store.savePendingInbound(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
      reason: 'waiting',
    );
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      attachmentId: 'att-isolate',
      recipientCidNumber: _bobCidNumber,
      conversationId: 'conv-isolate',
      fileName: 'pending.bin',
      contentType: 'application/octet-stream',
      byteSize: 2,
    );
    await store.upsertRouteRecord(
      _ownerCidNumber,
      const ChatRoute(
        peerCidNumber: _bobCidNumber,
        routeDisplayName: 'Bob',
        deviceId: 'bob-phone',
        devicePublicKey: 'bob-device-public-key',
        safetyNumber: '123456',
      ),
      bindingToken: bindingToken,
    );
    await store.upsertGroupShell(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      groupId: 'group-isolate',
      groupName: '此前群上下文',
      creatorCidNumber: _ownerCidNumber,
      epoch: 1,
    );
    await store.reconcileGroupRoster(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      groupId: 'group-isolate',
      members: const <String, GroupMemberRole>{
        _ownerCidNumber: GroupMemberRole.admin,
        _bobCidNumber: GroupMemberRole.member,
      },
      epoch: 1,
    );
    await store.bufferGroupCommit(
      bindingToken: bindingToken,
      ownerCidNumber: _ownerCidNumber,
      groupId: 'group-isolate',
      messageEpoch: 2,
      envelope: envelope,
      envelopeBytes: envelope.writeToBuffer(),
    );

    await store.isolateInaccessibleBinding(
      previous: _testBinding,
      current: _nextBinding,
    );
    final nextBindingToken = await store.captureBindingFenceToken(_nextBinding);

    expect(await store.outboundQueueCount(_ownerCidNumber), 0);
    expect(await store.pendingInboundCount(_ownerCidNumber), 0);
    expect(await store.outgoingMediaCount(_ownerCidNumber), 0);
    expect(await store.readRouteRecords(_ownerCidNumber), isEmpty);
    expect(await store.readGroup(_ownerCidNumber, 'group-isolate'), isNull);
    expect(
      await store.takeGroupPendingCommit(
        _ownerCidNumber,
        'group-isolate',
        2,
        bindingToken: nextBindingToken,
      ),
      isNull,
    );

    // 隔离只移除不能跨绑定续用的任务和 MLS 镜像，不删除永久聊天密文。
    final retained = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-isolate',
    );
    expect(
      ChatPayloadCodec.decode(retained.single.plaintext!).text,
      '必须保留的历史密文',
    );
  });

  test('searchMessages 跨会话按解码摘要检索：大小写不敏感、时间倒序、limit 截断', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    const sender = _ownerCidNumber;
    const peer = _bobCidNumber;

    Future<void> save({
      required String envelopeId,
      required String conversationId,
      required int createdAtMillis,
      required String plaintext,
    }) async {
      final envelope = MlsWireMessage(
        wireBytes: const [0x68, 0x69],
        cipherSuite: 'MLS_128',
        conversationId: conversationId,
        messageKind: MlsMessageKind.application,
      ).toEnvelope(
        envelopeId: envelopeId,
        senderCidNumber: sender,
        recipientCidNumber: peer,
        senderDeviceId: 'alice-phone',
        createdAtMillis: createdAtMillis,
        ttlMillis: 60000,
      );
      await store.saveOutgoingEnvelope(
        bindingToken: bindingToken,
        ownerCidNumber: _ownerCidNumber,
        currentAccountId: _aliceAccountId,
        envelope: envelope,
        envelopeBytes: envelope.writeToBuffer(),
        recipientCidNumber: _bobCidNumber,
        messageKind: ChatMessageKind.text,
        deliveryState: ChatMessageDeliveryState.sent,
        plaintext: _payload(plaintext),
      );
    }

    await save(
      envelopeId: 'env-search-a',
      conversationId: 'conv-search-1',
      createdAtMillis: 10,
      plaintext: '明天开会的材料',
    );
    await save(
      envelopeId: 'env-search-b',
      conversationId: 'conv-search-2',
      createdAtMillis: 30,
      plaintext: 'Meeting MATERIAL ready',
    );
    await save(
      envelopeId: 'env-search-c',
      conversationId: 'conv-search-2',
      createdAtMillis: 20,
      plaintext: '开会通知',
    );

    // 跨会话命中并按时间倒序（conv-search-2 的 env-c 比 conv-search-1 的 env-a 新）
    final ordered = await store.searchMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      keyword: '开会',
    );
    expect(
      ordered.map((item) => item.envelopeId).toList(),
      <String>['env-search-c', 'env-search-a'],
    );

    // limit 截断保留最新的一条
    final limited = await store.searchMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      keyword: '开会',
      limit: 1,
    );
    expect(
      limited.map((item) => item.envelopeId).toList(),
      <String>['env-search-c'],
    );

    // 大小写不敏感
    final caseInsensitive = await store.searchMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _aliceAccountId,
      keyword: 'material',
    );
    expect(
      caseInsensitive.map((item) => item.envelopeId).toList(),
      <String>['env-search-b'],
    );

    // 空关键词 / 空账户不检索；他人账户查不到本账户消息
    expect(
      await store.searchMessages(
        ownerCidNumber: _ownerCidNumber,
        currentAccountId: sender,
        keyword: '   ',
      ),
      isEmpty,
    );
    expect(
      await store.searchMessages(
        ownerCidNumber: '',
        currentAccountId: sender,
        keyword: '开会',
      ),
      isEmpty,
    );
    expect(
      await store.searchMessages(
        ownerCidNumber: 'CN220-CTZN2-999999999-2026',
        currentAccountId: peer,
        keyword: '开会',
      ),
      isEmpty,
    );
  });
}
