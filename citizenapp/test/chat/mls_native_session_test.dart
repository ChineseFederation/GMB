import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/chat/chat_flow.dart';
import 'package:citizenapp/chat/chat_models.dart';
import 'package:citizenapp/chat/chat_payload.dart';
import 'package:citizenapp/chat/crypto/mls_boundary.dart';
import 'package:citizenapp/chat/crypto/mls_native.dart';
import 'package:citizenapp/chat/crypto/mls_state_store.dart';
import 'package:citizenapp/isar/chat_isar.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:citizenapp/chat/transport/chat_transport.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/isar_test_env.dart';
import '../support/smoldot_native_probe.dart';

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

void main() {
  useIsolatedIsar();

  final skip = smoldotNativeSkipReason();

  test('native 设备公钥以当前 CID 加密状态为唯一真源且不生成 KeyPackage', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-identity-');
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(
      Directory('${root.path}/alice'),
      ownerCidNumber: _aliceCidNumber,
      stateKey: Uint8List.fromList(_testStateKey),
    );
    const bootstrap = ChatDevice(
      cidNumber: _aliceCidNumber,
      deviceId: 'alice-phone',
      devicePublicKey: '00',
    );
    final crypto = NativeMlsCrypto(identity: bootstrap, stateStore: store);

    final first = await crypto.readDevicePublicKey(bootstrap);
    final second = await crypto.readDevicePublicKey(bootstrap);
    expect(first, isNotEmpty);
    expect(second, first);

    const wrongOwner = ChatDevice(
      cidNumber: _bobCidNumber,
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

  test(
    'native OpenMLS creates, persists, and resumes a two-party session',
    () async {
      final root = await Directory.systemTemp.createTemp('gmb-chat-native-');
      addTearDown(() => root.delete(recursive: true));
      final aliceStore = MlsStateStore(
        Directory('${root.path}/alice'),
        ownerCidNumber: _aliceCidNumber,
        stateKey: _testStateKey,
      );
      final bobStore = MlsStateStore(
        Directory('${root.path}/bob'),
        ownerCidNumber: _bobCidNumber,
        stateKey: _testStateKey,
      );
      const alice = ChatDevice(
        cidNumber: _aliceCidNumber,
        deviceId: 'alice-phone',
        devicePublicKey: 'aabbcc',
      );
      const bob = ChatDevice(
        cidNumber: _bobCidNumber,
        deviceId: 'bob-phone',
        devicePublicKey: 'ddeeff',
      );
      final bobCrypto = NativeMlsCrypto(identity: bob, stateStore: bobStore);
      final bobKeyPackage = await bobCrypto.createKeyPackage(bob);
      final aliceCrypto = NativeMlsCrypto(
        identity: alice,
        stateStore: aliceStore,
      );
      final first = await aliceCrypto.encrypt(
        conversationId: 'conv-alice-bob',
        recipientCidNumber: _bobCidNumber,
        recipientKeyPackage: bobKeyPackage,
        plaintext: utf8.encode('第一条消息'),
      );

      final bobAfterRestart = NativeMlsCrypto(
        identity: bob,
        stateStore: bobStore,
      );
      await bobAfterRestart.processIncoming(first.welcomeMessage!);
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
        recipientCidNumber: _bobCidNumber,
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

  test('native OpenMLS 密文经设备直连边界到达接收设备并落本机', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-direct-');
    addTearDown(() => root.delete(recursive: true));
    const alice = ChatDevice(
      cidNumber: _aliceCidNumber,
      deviceId: 'alice-phone',
      devicePublicKey: 'aabbcc',
    );
    const bob = ChatDevice(
      cidNumber: _bobCidNumber,
      deviceId: 'bob-phone',
      devicePublicKey: 'ddeeff',
    );
    final aliceCrypto = NativeMlsCrypto(
      identity: alice,
      stateStore: MlsStateStore(
        Directory('${root.path}/alice'),
        ownerCidNumber: _aliceCidNumber,
        stateKey: _testStateKey,
      ),
    );
    final bobCrypto = NativeMlsCrypto(
      identity: bob,
      stateStore: MlsStateStore(
        Directory('${root.path}/bob'),
        ownerCidNumber: _bobCidNumber,
        stateKey: _testStateKey,
      ),
    );
    final keyPackage = await bobCrypto.createKeyPackage(bob);
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
          transportType: ChatTransportType.webrtc,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    await senderFlow.sendText(
      conversationId: 'conv-direct',
      senderCidNumber: _aliceCidNumber,
      recipientCidNumber: _bobCidNumber,
      senderDeviceId: 'alice-phone',
      recipientKeyPackage: keyPackage,
      text: '瞬时直达',
    );
    expect(relayed, hasLength(2));

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
