import 'dart:convert';

import 'package:citizenapp/chat/chat_flow.dart';
import 'package:citizenapp/chat/chat_models.dart';
import 'package:citizenapp/chat/chat_payload.dart';
import 'package:citizenapp/chat/crypto/mls_boundary.dart';
import 'package:citizenapp/chat/crypto/mls_group_boundary.dart';
import 'package:citizenapp/chat/group/group_control.dart';
import 'package:citizenapp/chat/group/group_flow.dart';
import 'package:citizenapp/chat/group/group_membership.dart';
import 'package:citizenapp/chat/proto/chat_envelope.pb.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:citizenapp/chat/transport/chat_transport.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/isar_test_env.dart';

const _ownerCidNumber = 'CN220-CTZN2-100000001-2026';
const _accountA =
    '0x3333333333333333333333333333333333333333333333333333333333333333';
const _binding = AccountDataBinding(
  genesisHash:
      '0x4242424242424242424242424242424242424242424242424242424242424242',
  cidNumber: _ownerCidNumber,
  bindingRevision: 1,
  accountId: _accountA,
);

Future<ChatBindingFenceToken> _bindingToken(ChatStore store) =>
    store.activateBindingFence(_binding);

/// 内存态 fake:模拟 MLS 群语义(roster + epoch),不做真加密。
class _FakeGroupCrypto implements MlsGroupCrypto {
  _FakeGroupCrypto({required this.cidNumber, required this.localDeviceId});

  final String cidNumber;
  final String localDeviceId;
  final Map<String, List<String>> _roster = {};
  final Map<String, int> _epoch = {};

  String get _localIdentity => '$cidNumber:$localDeviceId';

  @override
  Future<GroupCreated> createGroup(String groupId) async {
    _roster[groupId] = [_localIdentity];
    _epoch[groupId] = 0;
    return GroupCreated(groupId: groupId, epoch: 0);
  }

  @override
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  ) async {
    final roster = _roster[groupId]!;
    for (final keyPackage in keyPackages) {
      roster.add('${keyPackage.cidNumber}:${keyPackage.deviceId}');
    }
    _epoch[groupId] = (_epoch[groupId] ?? 0) + 1;
    return GroupCommitBundle(
      groupId: groupId,
      epoch: _epoch[groupId]!,
      commit: _wire(groupId, 'commit'),
      welcome: _wire(groupId, 'welcome'),
    );
  }

  @override
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberCidNumbers,
  ) async {
    final roster = _roster[groupId]!;
    roster.removeWhere(
        (identity) => memberCidNumbers.contains(identity.split(':').first));
    _epoch[groupId] = (_epoch[groupId] ?? 0) + 1;
    return GroupCommitBundle(
      groupId: groupId,
      epoch: _epoch[groupId]!,
      commit: _wire(groupId, 'commit'),
      removedCidNumbers: memberCidNumbers,
    );
  }

  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) async {
    return MlsWireMessage(
      wireBytes: plaintext,
      cipherSuite: '',
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
  }

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) async {
    // 测试只驱动 application 入站:回显明文。
    final epoch = _epoch[wire.conversationId] ?? 0;
    return GroupInbound(
      groupId: wire.conversationId,
      kind: GroupInboundKind.application,
      status: GroupProcessStatus.applied,
      messageEpoch: epoch,
      groupEpoch: epoch,
      selfRemoved: false,
      plaintext: wire.wireBytes,
    );
  }

  @override
  Future<GroupState> groupState(String groupId) async {
    return GroupState(
      groupId: groupId,
      epoch: _epoch[groupId] ?? 0,
      memberIdentities: List.of(_roster[groupId] ?? const []),
    );
  }

  MlsWireMessage _wire(String groupId, String tag) => MlsWireMessage(
        wireBytes: utf8.encode(tag),
        cipherSuite: '',
        conversationId: groupId,
        messageKind: MlsMessageKind.application,
      );
}

/// 群名册、信封、扇出队列与 WebRTC 信令均以 CID 为唯一身份键。
const _cidA = 'CN220-CTZN2-100000003-2026';
const _cidB = 'CN220-CTZN2-100000004-2026';
const _cidC = 'CN220-CTZN2-100000005-2026';
const _cidD = 'CN220-CTZN2-100000006-2026';

Future<ChatDeliveryResult> _okDeliverer(
  ChatEnvelope envelope,
  List<int> bytes,
  String recipientCidNumber,
) async =>
    ChatDeliveryResult(
      envelopeId: envelope.envelopeId,
      transportType: ChatTransportType.mailbox,
      state: ChatMessageDeliveryState.sent,
    );

MlsKeyPackage _keyPackage(String cidNumber, String device) => MlsKeyPackage(
      cidNumber: cidNumber,
      deviceId: device,
      keyPackageId: 'kp-$cidNumber',
      keyPackageBytes: const [1, 2],
      cipherSuite: '',
      notBeforeMillis: 0,
      notAfterMillis: 0,
      lastResort: false,
    );

void main() {
  useIsolatedIsar();

  test('建群→发文本→收文本→删人 全链路(fake 密码学 + 真 Isar)', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(
      cidNumber: _cidA,
      localDeviceId: 'devA',
    );
    final delivered = <ChatEnvelope>[];
    final deliveredCidNumbers = <String>[];
    Future<ChatDeliveryResult> deliverer(
      ChatEnvelope envelope,
      List<int> bytes,
      String recipientCidNumber,
    ) async {
      delivered.add(envelope);
      deliveredCidNumbers.add(recipientCidNumber);
      return ChatDeliveryResult(
        envelopeId: envelope.envelopeId,
        transportType: ChatTransportType.mailbox,
        state: ChatMessageDeliveryState.sent,
      );
    }

    final flow = ChatGroupFlow(
      ownerCidNumber: _ownerCidNumber,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: deliverer,
      cidNumber: _cidA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_cidA:testnonce';

    // 建群 + 邀请 B、C。
    final group = await flow.createGroup(
      groupId: groupId,
      name: '测试群',
      cidNumber: _cidA,
      localDeviceId: 'devA',
      invitees: [
        _keyPackage(_cidB, 'devB'),
        _keyPackage(_cidC, 'devC'),
      ],
    );
    expect(group.memberCidNumbers.toSet(), {_cidA, _cidB, _cidC});
    expect(group.adminSet, {_cidA});
    // Welcome 扇给 B、C(建群时无其他现有成员,无 Commit 扇出)。
    expect(delivered.map((e) => e.recipientCidNumber).toSet(), {_cidB, _cidC});
    expect(deliveredCidNumbers.toSet(), {_cidB, _cidC});

    // 群发文本 → 扇给 B、C,落 1 条逻辑消息。
    delivered.clear();
    deliveredCidNumbers.clear();
    final results = await flow.sendGroupText(
      groupId: groupId,
      senderCidNumber: _cidA,
      senderDeviceId: 'devA',
      text: '大家好',
    );
    expect(results.length, 2);
    expect(delivered.map((e) => e.recipientCidNumber).toSet(), {_cidB, _cidC});
    // 同一份密文扇 2 封。
    expect(delivered[0].mlsWireMessage, delivered[1].mlsWireMessage);
    expect(deliveredCidNumbers.toSet(), {_cidB, _cidC});
    final afterSend = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _accountA,
      conversationId: groupId,
    );
    final outgoing = afterSend.where((m) => m.direction == 'outgoing').toList();
    expect(outgoing.length, 1);
    expect(outgoing.single.plaintext, contains('大家好'));

    // 收到 B 的文本。
    final payload = ChatPayloadCodec.encode(ChatContent.text('收到'));
    final inboundWire = MlsWireMessage(
      wireBytes: utf8.encode(payload),
      cipherSuite: '',
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
    final inbound = inboundWire.toEnvelope(
      envelopeId: 'in-1',
      senderCidNumber: _cidB,
      recipientCidNumber: _cidA,
      senderDeviceId: 'devB',
      createdAtMillis: 100,
      ttlMillis: 60,
    );
    await flow.processIncomingGroupEnvelope(inbound.writeToBuffer());
    final afterIncoming = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _accountA,
      conversationId: groupId,
    );
    final incoming =
        afterIncoming.where((m) => m.direction == 'incoming').toList();
    expect(incoming.length, 1);
    expect(incoming.single.plaintext, contains('收到'));

    // 删除 C → 名册剩 A、B;Commit 扇给删前成员 B、C(减自己)。
    delivered.clear();
    deliveredCidNumbers.clear();
    await flow.removeMembers(
      groupId: groupId,
      actorCidNumber: _cidA,
      actorDeviceId: 'devA',
      targetCidNumbers: [_cidC],
    );
    final afterRemove = await store.readGroup(_ownerCidNumber, groupId);
    expect(afterRemove!.memberCidNumbers.toSet(), {_cidA, _cidB});
    expect(delivered.map((e) => e.recipientCidNumber).toSet(), {_cidB, _cidC});
  });

  test('非 admin 加人被拒', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(
      cidNumber: _cidA,
      localDeviceId: 'devA',
    );
    Future<ChatDeliveryResult> deliverer(
      ChatEnvelope envelope,
      List<int> bytes,
      String recipientCidNumber,
    ) async =>
        ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.mailbox,
          state: ChatMessageDeliveryState.sent,
        );
    final flow = ChatGroupFlow(
      ownerCidNumber: _ownerCidNumber,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: deliverer,
      cidNumber: _cidA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_cidA:n';
    await flow.createGroup(
      groupId: groupId,
      name: 'g',
      cidNumber: _cidA,
      localDeviceId: 'devA',
      invitees: [_keyPackage(_cidB, 'devB')],
    );

    await expectLater(
      flow.addMembers(
        groupId: groupId,
        actorCidNumber: _cidB, // 非 admin
        actorDeviceId: 'devB',
        invitees: [_keyPackage(_cidD, 'devD')],
      ),
      throwsA(isA<GroupMembershipException>()),
    );
  });

  test('admin 收到 leave_request → 自动移除退群者(后向保密)', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(
      cidNumber: _cidA,
      localDeviceId: 'devA',
    );
    final flow = ChatGroupFlow(
      ownerCidNumber: _ownerCidNumber,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: (envelope, bytes, recipientCidNumber) async =>
          ChatDeliveryResult(
        envelopeId: envelope.envelopeId,
        transportType: ChatTransportType.mailbox,
        state: ChatMessageDeliveryState.sent,
      ),
      cidNumber: _cidA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_cidA:n';
    await flow.createGroup(
      groupId: groupId,
      name: 'g',
      cidNumber: _cidA,
      localDeviceId: 'devA',
      invitees: [
        _keyPackage(_cidB, 'devB'),
        _keyPackage(_cidC, 'devC'),
      ],
    );

    // CID B 发来退群请求(fake groupProcess 回显 wire 明文)。
    final payload = GroupControlCodec.encode(const GroupControl.leaveRequest());
    final wire = MlsWireMessage(
      wireBytes: utf8.encode(payload),
      cipherSuite: '',
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
    final envelope = wire.toEnvelope(
      envelopeId: 'lr-1',
      senderCidNumber: _cidB,
      recipientCidNumber: _cidA,
      senderDeviceId: 'devB',
      createdAtMillis: 1,
      ttlMillis: 60,
    );
    await flow.processIncomingGroupEnvelope(envelope.writeToBuffer());
    final group = await store.readGroup(_ownerCidNumber, groupId);
    expect(group!.memberCidNumbers.toSet(), {_cidA, _cidC}); // B 被移除
  });

  test('收到 rename → 群名更新(非 admin 收端也同步)', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(
      cidNumber: _cidB,
      localDeviceId: 'devB',
    );
    final flow = ChatGroupFlow(
      ownerCidNumber: _ownerCidNumber,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: (envelope, bytes, recipientCidNumber) async =>
          ChatDeliveryResult(
        envelopeId: envelope.envelopeId,
        transportType: ChatTransportType.mailbox,
        state: ChatMessageDeliveryState.sent,
      ),
      cidNumber: _cidB,
      currentAccountId: _accountA,
      localDeviceId: 'devB',
    );
    const groupId = 'grp:$_cidA:n2';
    await store.upsertGroupShell(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _accountA,
      groupId: groupId,
      groupName: '旧名',
      creatorCidNumber: _cidA,
      epoch: 1,
      bindingToken: await _bindingToken(store),
    );

    final payload = GroupControlCodec.encode(GroupControl.rename('新群名'));
    final wire = MlsWireMessage(
      wireBytes: utf8.encode(payload),
      cipherSuite: '',
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
    final envelope = wire.toEnvelope(
      envelopeId: 'rn-1',
      senderCidNumber: _cidA,
      recipientCidNumber: _cidB,
      senderDeviceId: 'devA',
      createdAtMillis: 1,
      ttlMillis: 60,
    );
    await flow.processIncomingGroupEnvelope(envelope.writeToBuffer());
    final group = await store.readGroup(_ownerCidNumber, groupId);
    expect(group!.name, '新群名');
  });

  test('群发贴纸:落 sticker 消息 + 扇出', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(
      cidNumber: _cidA,
      localDeviceId: 'devA',
    );
    final delivered = <ChatEnvelope>[];
    final flow = ChatGroupFlow(
      ownerCidNumber: _ownerCidNumber,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: (envelope, bytes, recipientCidNumber) async {
        delivered.add(envelope);
        return ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.mailbox,
          state: ChatMessageDeliveryState.sent,
        );
      },
      cidNumber: _cidA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_cidA:ns';
    await flow.createGroup(
      groupId: groupId,
      name: 'g',
      cidNumber: _cidA,
      localDeviceId: 'devA',
      invitees: [_keyPackage(_cidB, 'devB')],
    );

    delivered.clear();
    await flow.sendGroupSticker(
      groupId: groupId,
      senderCidNumber: _cidA,
      senderDeviceId: 'devA',
      packId: 'fluent3d',
      stickerId: 'grinning_face',
    );
    expect(delivered.map((e) => e.recipientCidNumber).toSet(), {_cidB});
    final messages = await store.readMessages(
      ownerCidNumber: _ownerCidNumber,
      currentAccountId: _accountA,
      conversationId: groupId,
    );
    final sticker =
        messages.firstWhere((m) => m.messageKind == ChatMessageKind.sticker);
    expect(sticker.direction, 'outgoing');
  });

  group('群媒体云端密文控制消息', () {
    Future<ChatGroupFlow> buildGroup(
      ChatStore store, {
      ChatEnvelopeDeliverer deliverer = _okDeliverer,
    }) async {
      final crypto = _FakeGroupCrypto(
        cidNumber: _cidA,
        localDeviceId: 'devA',
      );
      final flow = ChatGroupFlow(
        ownerCidNumber: _ownerCidNumber,
        crypto: crypto,
        store: store,
        bindingToken: await _bindingToken(store),
        deliverer: deliverer,
        cidNumber: _cidA,
        currentAccountId: _accountA,
        localDeviceId: 'devA',
      );
      await flow.createGroup(
        groupId: 'grp:$_cidA:nm',
        name: 'g',
        cidNumber: _cidA,
        localDeviceId: 'devA',
        invitees: [
          _keyPackage(_cidB, 'devB'),
          _keyPackage(_cidC, 'devC'),
        ],
      );
      return flow;
    }

    ChatContent mediaContent(int byteSize) => ChatContent.media(
          kind: ChatMessageKind.file,
          attachmentId: 'att-group-1',
          fileName: 'archive.bin',
          mime: 'application/octet-stream',
          byteSize: byteSize,
          cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          cipherByteSize: byteSize + 16,
          cipherSha256: List<String>.filled(64, 'a').join(),
        );

    test('群附件收件人只包含其他成员且每个 CID 只出现一次', () async {
      final store = ChatStore();
      final flow = await buildGroup(store);

      final recipients = await flow.recipientCidNumbers(
        groupId: 'grp:$_cidA:nm',
        senderCidNumber: _cidA,
      );

      expect(recipients.toSet(), {_cidB, _cidC});
      expect(recipients, hasLength(2));
    });

    test('群附件只保存一条控制消息并向所有成员扇出', () async {
      final store = ChatStore();
      final delivered = <ChatEnvelope>[];
      final events = <String>[];
      final flow = await buildGroup(
        store,
        deliverer: (envelope, _, __) async {
          events.add('deliver');
          delivered.add(envelope);
          return ChatDeliveryResult(
            envelopeId: envelope.envelopeId,
            transportType: ChatTransportType.mailbox,
            state: ChatMessageDeliveryState.sent,
          );
        },
      );
      events.clear();
      delivered.clear();

      await flow.sendGroupMediaControl(
        groupId: 'grp:$_cidA:nm',
        senderCidNumber: _cidA,
        senderDeviceId: 'devA',
        content: mediaContent(200 * 1024 * 1024),
        onApplicationStored: () async => events.add('stored'),
      );

      expect(events.first, 'stored');
      expect(
          delivered.map((e) => e.recipientCidNumber).toSet(), {_cidB, _cidC});
      expect(
          delivered.every((e) => e.ttlMillis == chatMailboxTtlMillis), isTrue);
      final messages = await store.readMessages(
        ownerCidNumber: _ownerCidNumber,
        currentAccountId: _accountA,
        conversationId: 'grp:$_cidA:nm',
      );
      final content = ChatPayloadCodec.decode(messages.last.plaintext ?? '');
      expect(content.attachmentId, 'att-group-1');
      expect(content.byteSize, 200 * 1024 * 1024);
      expect(content.cipherSha256, List<String>.filled(64, 'a').join());
    });
  });
}
