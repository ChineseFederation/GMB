import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/chat/chat_flow.dart';
import 'package:citizenapp/chat/chat_models.dart';
import 'package:citizenapp/chat/chat_payload.dart';
import 'package:chat_sdk/chat_sdk.dart';
import 'package:citizenapp/isar/chat_isar.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:citizenapp/chat/transport/chat_transport.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/isar_test_env.dart';
import '../support/chat_sdk_native_probe.dart';

/// MLS 本地状态信封测试密钥（固定 32 字节，仅测试用）。
final Uint8List _testStateKey = Uint8List.fromList(
  List<int>.generate(32, (i) => i),
);
const _aliceCidNumber = 'CN220-CTZN2-100000001-2026';
const _bobCidNumber = 'CN220-CTZN2-100000002-2026';
const _aliceAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _bobAccountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _genesisHash =
    '0x4242424242424242424242424242424242424242424242424242424242424242';

// 原生会话测试使用隔离身份与固定测试密钥验证 MLS 状态边界。
void main() {
  useIsolatedIsar();

  final skip = chatSdkNativeSkipReason();

  test('native HPKE 设备公钥以当前 CID 加密状态为唯一真源', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-identity-');
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(
      Directory('${root.path}/alice'),
      ownerUserId: _aliceCidNumber,
      stateKey: Uint8List.fromList(_testStateKey),
    );
    const bootstrap = ChatDevice(
      userId: _aliceCidNumber,
      deviceId: 'alice-phone',
      devicePublicKey: '00',
    );
    final crypto = NativeMlsCrypto(identity: bootstrap, stateStore: store);

    final first = await crypto.readDevicePublicKey(bootstrap);
    final second = await crypto.readDevicePublicKey(bootstrap);
    expect(first, isNotEmpty);
    expect(second, first);

    const wrongOwner = ChatDevice(
      userId: _bobCidNumber,
      deviceId: 'bob-phone',
      devicePublicKey: '00',
    );
    await expectLater(
      crypto.readDevicePublicKey(wrongOwner),
      throwsA(
        isA<MlsNativeException>().having(
          (error) => error.code,
          'code',
          MlsNativeErrorCode.stateOwnerMismatch,
        ),
      ),
    );
  }, skip: skip);

  test('native 状态重建保持同一设备 HPKE 公钥', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-reset-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final store = MlsStateStore(
      Directory('${root.path}/alice'),
      ownerUserId: _aliceCidNumber,
      stateKey: Uint8List.fromList(_testStateKey),
    );
    const identity = ChatDevice(
      userId: _aliceCidNumber,
      deviceId: 'alice-phone',
      devicePublicKey: '00',
    );
    final first = await NativeMlsCrypto(
      identity: identity,
      stateStore: store,
    ).readDevicePublicKey(identity);

    await store.reset();

    final second = await NativeMlsCrypto(
      identity: identity,
      stateStore: store,
    ).readDevicePublicKey(identity);
    expect(second, first);
  }, skip: skip);

  test(
    'native HPKE uses the recipient device key for every direct message',
    () async {
      final root = await Directory.systemTemp.createTemp('gmb-chat-native-');
      addTearDown(() => root.delete(recursive: true));
      final aliceStore = MlsStateStore(
        Directory('${root.path}/alice'),
        ownerUserId: _aliceCidNumber,
        stateKey: _testStateKey,
      );
      final bobStore = MlsStateStore(
        Directory('${root.path}/bob'),
        ownerUserId: _bobCidNumber,
        stateKey: _testStateKey,
      );
      const alice = ChatDevice(
        userId: _aliceCidNumber,
        deviceId: 'alice-phone',
        devicePublicKey: 'aabbcc',
      );
      const bob = ChatDevice(
        userId: _bobCidNumber,
        deviceId: 'bob-phone',
        devicePublicKey: 'ddeeff',
      );
      final bobCrypto = NativeMlsCrypto(identity: bob, stateStore: bobStore);
      final bobDevicePublicKey = await bobCrypto.readDevicePublicKey(bob);
      final aliceCrypto = NativeMlsCrypto(
        identity: alice,
        stateStore: aliceStore,
      );
      final first = await aliceCrypto.encrypt(
        conversationId: 'conv-alice-bob',
        recipientUserId: _bobCidNumber,
        recipientDevicePublicKey: bobDevicePublicKey,
        plaintext: utf8.encode('第一条消息'),
      );

      final bobAfterRestart = NativeMlsCrypto(
        identity: bob,
        stateStore: bobStore,
      );
      expect(first.welcomeMessage, isNull);
      expect(
        utf8.decode(await bobAfterRestart.decrypt(first.applicationMessage)),
        '第一条消息',
      );

      final aliceAfterRestart = NativeMlsCrypto(
        identity: alice,
        stateStore: aliceStore,
      );
      final second = await aliceAfterRestart.encrypt(
        conversationId: 'conv-alice-bob',
        recipientUserId: _bobCidNumber,
        recipientDevicePublicKey: bobDevicePublicKey,
        plaintext: utf8.encode('重启后的第二条消息'),
      );
      expect(second.createdNewSession, isFalse);
      expect(
        utf8.decode(await bobAfterRestart.decrypt(second.applicationMessage)),
        '重启后的第二条消息',
      );
    },
    skip: skip,
  );

  test('native HPKE 密文经邮箱边界到达接收设备并落本机', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-direct-');
    addTearDown(() => root.delete(recursive: true));
    const alice = ChatDevice(
      userId: _aliceCidNumber,
      deviceId: 'alice-phone',
      devicePublicKey: 'aabbcc',
    );
    const bob = ChatDevice(
      userId: _bobCidNumber,
      deviceId: 'bob-phone',
      devicePublicKey: 'ddeeff',
    );
    final aliceCrypto = NativeMlsCrypto(
      identity: alice,
      stateStore: MlsStateStore(
        Directory('${root.path}/alice'),
        ownerUserId: _aliceCidNumber,
        stateKey: _testStateKey,
      ),
    );
    final bobCrypto = NativeMlsCrypto(
      identity: bob,
      stateStore: MlsStateStore(
        Directory('${root.path}/bob'),
        ownerUserId: _bobCidNumber,
        stateKey: _testStateKey,
      ),
    );
    final bobDevicePublicKey = await bobCrypto.readDevicePublicKey(bob);
    final relayed = <List<int>>[];
    final senderStore = ChatStore();
    final senderBindingToken = await senderStore.activateBindingFence(
      const AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: _aliceCidNumber,
        bindingRevision: 1,
        accountId: _aliceAccountId,
      ),
    );
    final senderFlow = ChatFlow(
      ownerCidNumber: _aliceCidNumber,
      currentAccountId: _aliceAccountId,
      crypto: aliceCrypto,
      store: senderStore,
      bindingToken: senderBindingToken,
      deliverer: (envelope, bytes, recipientCidNumber) async {
        relayed.add(List<int>.from(bytes));
        return ChatDeliveryResult(
          envelopeId: envelope.envelopeId,
          transportType: ChatTransportType.mailbox,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    await senderFlow.sendText(
      conversationId: 'conv-direct',
      senderCidNumber: _aliceCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientDevicePublicKey: bobDevicePublicKey,
      text: '瞬时直达',
    );
    expect(relayed, hasLength(1));

    await ChatIsar.instance.resetForTest();
    final receiverStore = ChatStore();
    final receiverBindingToken = await receiverStore.activateBindingFence(
      const AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: _bobCidNumber,
        bindingRevision: 1,
        accountId: _bobAccountId,
      ),
    );
    final receiverFlow = ChatFlow(
      ownerCidNumber: _bobCidNumber,
      currentAccountId: _bobAccountId,
      crypto: bobCrypto,
      store: receiverStore,
      bindingToken: receiverBindingToken,
      deliverer: (_, __, ___) => throw StateError('接收端不得重新投递'),
    );
    for (final bytes in relayed) {
      await receiverFlow.processIncomingEnvelopeBytes(bytes);
    }

    final messages = await ChatStore().readMessages(
      ownerCidNumber: _bobCidNumber,
      currentAccountId: _bobAccountId,
      conversationId: 'conv-direct',
    );
    // 落库 plaintext 是 ChatPayloadCodec 载荷 JSON(全仓消息类型单一真源),
    // 不是裸文本;展示端一律解码后取值,断言与之对齐。
    final content = ChatPayloadCodec.decode(messages.single.plaintext ?? '');
    expect(content.kind, ChatMessageKind.text);
    expect(content.text, '瞬时直达');
    expect(messages.single.direction, 'incoming');
  }, skip: skip);
}
