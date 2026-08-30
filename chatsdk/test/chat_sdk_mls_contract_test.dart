import 'dart:io';
import 'dart:typed_data';

import 'package:chat_sdk/chat_sdk.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

// 合同测试锁定 ChatSDK 的中性身份、状态清理边界和脱敏错误码。
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

  test(
    'MLS state reset removes only SDK state and keeps the active key',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chat-sdk-state-reset-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
      final directory = Directory('${root.path}/device-a');
      final store = MlsStateStore(
        directory,
        ownerUserId: 'user-a',
        stateKey: key,
      );
      await directory.create(recursive: true);
      await File(
        '${directory.path}/openmls_storage.bin',
      ).writeAsBytes(<int>[1]);
      await File('${directory.path}/device.bin').writeAsBytes(<int>[2]);
      await File(
        '${directory.path}/pending_inbound.bin',
      ).writeAsBytes(<int>[3]);

      await store.reset();

      expect(await directory.exists(), isTrue);
      expect(await directory.list().toList(), isEmpty);
      expect(
        store.stateKey,
        orderedEquals(List<int>.generate(32, (index) => index)),
      );
    },
  );

  test('native state failures expose stable redacted codes', () {
    final storage = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STORAGE_AUTH_FAILED:detail',
    );
    final device = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_DEVICE_AUTH_FAILED:detail',
    );
    final invalid = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STATE_INVALID:detail',
    );

    expect(storage.code, MlsNativeErrorCode.storageAuthFailed);
    expect(storage.diagnosticCode, 'storage_auth_failed');
    expect(storage.requiresStateReset, isTrue);
    expect(device.code, MlsNativeErrorCode.deviceAuthFailed);
    expect(invalid.code, MlsNativeErrorCode.stateInvalid);
    expect(chatSdkDiagnosticCode(StateError('hidden')), 'operation_failed');
  });
}
