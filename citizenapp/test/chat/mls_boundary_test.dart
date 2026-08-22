import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/chat/crypto/mls_boundary.dart';
import 'package:citizenapp/chat/crypto/mls_native.dart';
import 'package:citizenapp/chat/crypto/mls_state_store.dart';
import 'package:citizenapp/chat/chat_runtime.dart';
import 'package:citizenapp/chat/storage/chat_crypto.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';

import '../support/isar_test_env.dart';

class _TargetHandoverKeyFailureWalletManager extends WalletManager {
  final List<Uint8List> sourceKeys = <Uint8List>[
    Uint8List.fromList(List<int>.filled(32, 17)),
    Uint8List.fromList(List<int>.filled(32, 29)),
  ];

  @override
  Future<List<Uint8List>> deriveDataKeysForBindingHandover(
    AccountDataBinding binding,
    List<({String? context, LocalKeyPurpose purpose})> requests,
  ) async {
    if (binding.bindingRevision == 1) return sourceKeys;
    throw StateError('target-key-derivation-failed');
  }
}

void main() {
  useIsolatedIsar();

  group('ChatDevice', () {
    test('accepts CID as chat identity without wallet private key', () {
      const identity = ChatDevice(
        cidNumber: 'CN220-CTZN2-100000001-2026',
        deviceId: 'alice-phone',
        devicePublicKey: '0xaabbcc',
      );

      expect(identity.validate(), isNull);
      expect(identity.cidNumber, 'CN220-CTZN2-100000001-2026');
      expect(identity.deviceId, 'alice-phone');
    });

    test('rejects invalid device public key hex', () {
      const identity = ChatDevice(
        cidNumber: 'CN220-CTZN2-100000001-2026',
        deviceId: 'alice-phone',
        devicePublicKey: 'xyz',
      );

      expect(identity.validate(), contains('hex'));
    });
  });

  group('Chat 设备身份 CID 隔离', () {
    test('不同 CID 使用不同 device_id 和派生公钥缓存键', () {
      final aId = ChatRuntime.deviceIdPreferenceKey('CID-A');
      final bId = ChatRuntime.deviceIdPreferenceKey('CID-B');
      final aKey = ChatRuntime.devicePublicKeyCachePreferenceKey('CID-A');
      final bKey = ChatRuntime.devicePublicKeyCachePreferenceKey('CID-B');
      expect(aId, isNot(bId));
      expect(aKey, isNot(bKey));
      expect(aId, contains('chat.by_cid.CID-A'));
      expect(aKey, contains('device.public_key_cache_hex'));
    });
  });

  group('Chat 换绑用途钥清理', () {
    late Directory deviceDirectory;

    setUp(() async {
      deviceDirectory = await Directory.systemTemp.createTemp(
        'citizenapp_mls_handover_keys_',
      );
    });

    tearDown(() async {
      if (await deviceDirectory.exists()) {
        await deviceDirectory.delete(recursive: true);
      }
    });

    test('MLS native 与 Dart 预演成功后清零两份临时钥副本', () async {
      final source = Uint8List.fromList(List<int>.filled(32, 31));
      final target = Uint8List.fromList(List<int>.filled(32, 47));
      late Uint8List nativeSourceCopy;
      late Uint8List nativeTargetCopy;
      late Uint8List storeSourceCopy;
      late Uint8List pendingTargetCopy;

      await ChatRuntime.debugStageMlsDeviceHandoverForTest(
        deviceDirectory: deviceDirectory,
        ownerCidNumber: 'CN220-CTZN2-100000001-2026',
        sourceStateKey: source,
        targetStateKey: target,
        runNativeRekey: (sourceCopy, targetCopy) {
          nativeSourceCopy = sourceCopy;
          nativeTargetCopy = targetCopy;
          expect(sourceCopy, everyElement(31));
          expect(targetCopy, everyElement(47));
        },
        stagePending: (store, targetCopy) async {
          storeSourceCopy = store.stateKey;
          pendingTargetCopy = targetCopy;
          expect(store.stateKey, everyElement(31));
          expect(targetCopy, everyElement(47));
        },
      );

      expect(identical(nativeSourceCopy, storeSourceCopy), isTrue);
      expect(identical(nativeTargetCopy, pendingTargetCopy), isTrue);
      expect(nativeSourceCopy, everyElement(0));
      expect(nativeTargetCopy, everyElement(0));
      expect(source, everyElement(31), reason: '外层用途钥由外层 finally 单独管理');
      expect(target, everyElement(47), reason: '设备预演只清零自己的短命副本');
    });

    test('MLS native 预演失败仍清零 source/target 副本且不进入 Dart', () async {
      final source = Uint8List.fromList(List<int>.filled(32, 53));
      final target = Uint8List.fromList(List<int>.filled(32, 59));
      late Uint8List nativeSourceCopy;
      late Uint8List nativeTargetCopy;
      var pendingCalled = false;

      await expectLater(
        ChatRuntime.debugStageMlsDeviceHandoverForTest(
          deviceDirectory: deviceDirectory,
          ownerCidNumber: 'CN220-CTZN2-100000001-2026',
          sourceStateKey: source,
          targetStateKey: target,
          runNativeRekey: (sourceCopy, targetCopy) {
            nativeSourceCopy = sourceCopy;
            nativeTargetCopy = targetCopy;
            throw StateError('native-rekey-failed');
          },
          stagePending: (MlsStateStore store, Uint8List targetCopy) async {
            pendingCalled = true;
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(pendingCalled, isFalse);
      expect(nativeSourceCopy, everyElement(0));
      expect(nativeTargetCopy, everyElement(0));
    });

    test('MLS Dart pending 预演失败仍 dispose Store 并清零目标副本', () async {
      final source = Uint8List.fromList(List<int>.filled(32, 61));
      final target = Uint8List.fromList(List<int>.filled(32, 67));
      late Uint8List nativeSourceCopy;
      late Uint8List nativeTargetCopy;
      late Uint8List storeSourceCopy;

      await expectLater(
        ChatRuntime.debugStageMlsDeviceHandoverForTest(
          deviceDirectory: deviceDirectory,
          ownerCidNumber: 'CN220-CTZN2-100000001-2026',
          sourceStateKey: source,
          targetStateKey: target,
          runNativeRekey: (sourceCopy, targetCopy) {
            nativeSourceCopy = sourceCopy;
            nativeTargetCopy = targetCopy;
          },
          stagePending: (store, targetCopy) async {
            storeSourceCopy = store.stateKey;
            expect(targetCopy, same(nativeTargetCopy));
            throw StateError('dart-pending-rekey-failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(storeSourceCopy, same(nativeSourceCopy));
      expect(storeSourceCopy, everyElement(0));
      expect(nativeTargetCopy, everyElement(0));
    });

    test('目标用途钥取得失败时立即清零已经取得的来源用途钥', () async {
      const source = AccountDataBinding(
        genesisHash:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        bindingRevision: 1,
        accountId:
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      const target = AccountDataBinding(
        genesisHash:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        bindingRevision: 2,
        accountId:
            '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final walletManager = _TargetHandoverKeyFailureWalletManager();
      final store = ChatStore(
        crypto: ChatCrypto(walletManager: walletManager),
      );
      await store.activateBindingFence(source);
      final runtime = ChatRuntime(
        store: store,
        walletManager: walletManager,
        documentsDirectoryProvider: () async => deviceDirectory,
      );

      await expectLater(
        runtime.stageAccountHandover(source: source, target: target),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'target-key-derivation-failed',
          ),
        ),
      );
      for (final key in walletManager.sourceKeys) {
        expect(key, everyElement(0));
      }
    });
  });

  group('Chat 用户错误文案', () {
    test('未知 StateError 不泄漏 Bad state 或底层乱码', () {
      final message = chatUserErrorMessage(
        StateError('native /tmp/libsmoldot \uFFFD\u0000 debug'),
      );

      expect(message, '聊天暂时无法使用，请稍后重试');
      expect(message.toLowerCase(), isNot(contains('bad state')));
      expect(message, isNot(contains('libsmoldot')));
    });

    test('MLS 状态所有权错误映射固定中文且不透传技术码', () {
      const error = MlsNativeException(
        MlsNativeErrorCode.stateOwnerMismatch,
        'CHAT_MLS_STATE_OWNER_MISMATCH:debug',
      );

      final message = chatUserErrorMessage(error);
      expect(message, contains('其他用户'));
      expect(message, isNot(contains('CHAT_MLS')));
    });

    test('Cloudflare 未绑定 CID 与设备子钥失败分层提示', () {
      const unregistered = SquareApiException(
        '该钱包账户未绑定 CID',
        statusCode: 403,
        errorCode: 'cid_not_bound',
      );
      const deviceMissing = SquareApiException(
        '设备子钥未注册',
        statusCode: 401,
        errorCode: 'device_not_registered',
      );

      expect(chatUserErrorMessage(unregistered), contains('当前默认账户'));
      expect(chatUserErrorMessage(deviceMissing), contains('聊天设备身份'));
    });

    test('Cloudflare 服务端异常不误报为 OpenMLS 加载失败', () {
      const error = SquareApiException(
        'internal trace',
        statusCode: 503,
        errorCode: 'internal_error',
      );

      final message = chatUserErrorMessage(error);
      expect(message, '聊天服务暂时无法连接，请稍后重试');
      expect(message, isNot(contains('OpenMLS')));
      expect(message, isNot(contains('安全组件')));
    });
  });
}
