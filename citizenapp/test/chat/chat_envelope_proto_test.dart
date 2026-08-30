import 'package:citizenapp/chat/chat_sdk_adapter.dart';
import 'package:chat_sdk/protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatEnvelope 只往返端到端密文瞬时投递字段', () {
    final envelope = ChatEnvelope(
      envelopeId: 'env-1',
      conversationId: 'conv-1',
      senderUserId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      recipientUserId:
          '0x2222222222222222222222222222222222222222222222222222222222222222',
      senderDeviceId: 'alice-phone',
      mlsMessage: [0xaa, 0xbb, 0xcc],
      encryptedMetadata: [0x01, 0x02],
      createdAtMillis: Int64(1),
      ttlMillis: Int64(60000),
      mlsMessageKind: MlsWireMessageKind.MLS_WIRE_MESSAGE_KIND_APPLICATION,
      ratchetTree: [0x0a, 0x0b],
    );

    final restored = ChatEnvelope.fromBuffer(envelope.writeToBuffer());
    expect(restored.envelopeId, 'env-1');
    expect(restored.mlsWireMessage, [0xaa, 0xbb, 0xcc]);
    expect(restored.ratchetTree, [0x0a, 0x0b]);
    expect(
      restored.recipientCidNumber,
      '0x2222222222222222222222222222222222222222222222222222222222222222',
    );
  });

  test('ChatRoute 只保存设备和近场路由', () {
    final route = ChatRoute(
      peerUserId:
          '0x2222222222222222222222222222222222222222222222222222222222222222',
      routeDisplayName: 'Bob',
      deviceId: 'bob-phone',
      devicePublicKey: 'aabbcc',
      safetyNumber: '12 34',
      nearbyPeerHint: 'bob-nearby',
      createdAtMillis: Int64(1),
      expiresAtMillis: Int64(2),
    );

    final restored = ChatRoute.fromBuffer(route.writeToBuffer());
    expect(
      restored.peerCidNumber,
      '0x2222222222222222222222222222222222222222222222222222222222222222',
    );
    expect(restored.nearbyPeerHint, 'bob-nearby');
  });
}
