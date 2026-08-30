import 'dart:io';

import 'package:chat_sdk/chat_sdk.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protocol uses deployment-neutral user identifiers', () {
    final route = ChatRoute(
      peerUserId: 'user-42',
      deviceId: 'device-a',
      createdAtMillis: Int64.ONE,
      expiresAtMillis: Int64.TWO,
    );
    final envelope = ChatEnvelope(
      envelopeId: 'envelope-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-1',
      recipientUserId: 'user-2',
      senderDeviceId: 'device-a',
      mlsMessage: <int>[1, 2, 3],
      createdAtMillis: Int64.ONE,
      ttlMillis: Int64.TWO,
    );

    expect(route.peerUserId, 'user-42');
    expect(envelope.senderUserId, 'user-1');
    expect(envelope.recipientUserId, 'user-2');
    expect(envelope.mlsMessage, <int>[1, 2, 3]);
  });

  test('ChatSDK source does not own product identity names', () {
    final sourceRoot = Directory('lib');
    final forbidden = RegExp(
      r'cid_number|CidNumber|cidNumber|citizen_chat_mls_|libsmoldot',
    );
    final violations = <String>[];

    for (final entity in sourceRoot.listSync(recursive: true)) {
      if (entity is! File ||
          !(entity.path.endsWith('.dart') || entity.path.endsWith('.proto'))) {
        continue;
      }
      if (forbidden.hasMatch(entity.readAsStringSync())) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty);
  });
}
