import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:citizenapp/isar/social_isar.dart';
import 'package:citizenapp/isar/chat_isar.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/isar/user_isar.dart';

import '../support/isar_test_env.dart';

void main() {
  useIsolatedIsar();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UserIsar 队列挂起时 Wallet、Social、Chat 仍独立读写', () async {
    await WalletIsar.instance.db();
    await ChatIsar.instance.db();
    await SocialIsar.instance.db();
    await UserIsar.instance.db();

    final entered = Completer<void>();
    final release = Completer<void>();
    final blockedUser = UserIsar.instance.read<void>((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(const Duration(seconds: 1));

    try {
      await WalletIsar.instance.writeTxn<void>((isar) async {
        await isar.walletAttestationEntitys.put(
          WalletAttestationEntity()
            ..id = 0
            ..lastRequestPayload = 'wallet',
        );
      }).timeout(const Duration(seconds: 1));
      await SocialIsar.instance.writeTxn<void>((isar) async {
        await isar.squarePostSyncCheckpointEntitys.putByCidNumber(
          SquarePostSyncCheckpointEntity()
            ..cidNumber = 'R5-K3P1C1-N9-D4'
            ..newestPostId = 'post'
            ..newestCreatedAt = 1,
        );
      }).timeout(const Duration(seconds: 1));
      await ChatIsar.instance.writeTxn<void>((isar) async {
        await isar.chatRouteCacheEntitys.put(
          ChatRouteCacheEntity()
            ..ownerCidNumber = 'R5-K3P1C1-N9-D4'
            ..peerCidNumber = 'R5-K3P1C1-N8-D5'
            ..routeDisplayName = 'chat'
            ..deviceId = 'device-user-isolation'
            ..devicePublicKey = 'public-key-user-isolation'
            ..safetyNumber = '1234'
            ..createdAtMillis = 1
            ..updatedAtMillis = 1,
        );
      }).timeout(const Duration(seconds: 1));

      expect(UserIsar.instance.hasActiveOperation, isTrue);
      expect(WalletIsar.instance.hasActiveOperation, isFalse);
      expect(SocialIsar.instance.hasActiveOperation, isFalse);
      expect(ChatIsar.instance.hasActiveOperation, isFalse);
    } finally {
      release.complete();
      await blockedUser.timeout(const Duration(seconds: 1));
    }
  });

  test('Wallet、Social、Chat 同时挂起也不阻塞 User 资料读写', () async {
    await WalletIsar.instance.db();
    await ChatIsar.instance.db();
    await SocialIsar.instance.db();
    await UserIsar.instance.db();

    final walletEntered = Completer<void>();
    final chatEntered = Completer<void>();
    final socialEntered = Completer<void>();
    final release = Completer<void>();
    final blockedWallet = WalletIsar.instance.read<void>((_) async {
      walletEntered.complete();
      await release.future;
    });
    final blockedChat = ChatIsar.instance.read<void>((_) async {
      chatEntered.complete();
      await release.future;
    });
    final blockedSocial = SocialIsar.instance.read<void>((_) async {
      socialEntered.complete();
      await release.future;
    });
    await Future.wait<void>(<Future<void>>[
      walletEntered.future,
      chatEntered.future,
      socialEntered.future,
    ]).timeout(const Duration(seconds: 1));

    try {
      await UserIsar.instance.writeTxn<void>((isar) async {
        await isar.userPublicProfileCacheEntitys.putByCidNumber(
          UserPublicProfileCacheEntity()
            ..cidNumber = 'R5-K3P1C1-N9-D4'
            ..profileJson = '{"display_name":"独立用户资料"}',
        );
      }).timeout(const Duration(seconds: 1));
      final profileJson = await UserIsar.instance.read((isar) async {
        return (await isar.userPublicProfileCacheEntitys
                .getByCidNumber('R5-K3P1C1-N9-D4'))
            ?.profileJson;
      }).timeout(const Duration(seconds: 1));

      expect(profileJson, '{"display_name":"独立用户资料"}');
      expect(UserIsar.instance.hasActiveOperation, isFalse);
      expect(WalletIsar.instance.hasActiveOperation, isTrue);
      expect(SocialIsar.instance.hasActiveOperation, isTrue);
      expect(ChatIsar.instance.hasActiveOperation, isTrue);
    } finally {
      release.complete();
      await Future.wait<void>(<Future<void>>[
        blockedWallet,
        blockedChat,
        blockedSocial,
      ]).timeout(const Duration(seconds: 1));
    }
  });

  test('UserIsar 回调内重入快速失败，不形成同域自锁', () async {
    final nested = UserIsar.instance.read<void>((_) async {
      await UserIsar.instance.read<void>((_) async {});
    });
    await expectLater(
      nested.timeout(const Duration(seconds: 1)),
      throwsA(isA<StateError>()),
    );
  });

  test('UserIsar 永久挂起不阻止显式关闭，旧结果不能复活', () async {
    await UserIsar.instance.db();
    final entered = Completer<void>();
    final release = Completer<void>();
    final oldOperation = UserIsar.instance.read<String>((_) async {
      entered.complete();
      await release.future;
      return 'stale-user-result';
    });
    await entered.future.timeout(const Duration(seconds: 1));

    await UserIsar.instance
        .closeAndDeleteFromDisk()
        .timeout(const Duration(seconds: 3));
    await expectLater(UserIsar.instance.db(), throwsA(isA<StateError>()));

    release.complete();
    await expectLater(
      oldOperation.timeout(const Duration(seconds: 1)),
      throwsA(isA<StateError>()),
    );
    await UserIsar.instance.resetForTest();
  });

  test('关闭 UserIsar 只删除用户数据库，已写入的其他业务域事实保持可用', () async {
    await UserIsar.instance.writeTxn<void>((isar) async {
      await isar.userPublicProfileCacheEntitys.putByCidNumber(
        UserPublicProfileCacheEntity()
          ..cidNumber = 'R5-K3P1C1-N9-D4'
          ..profileJson = '{"display_name":"用户资料"}',
      );
    });
    await WalletIsar.instance.writeTxn<void>((isar) async {
      await isar.walletAttestationEntitys.put(
        WalletAttestationEntity()
          ..id = 0
          ..lastRequestPayload = 'wallet',
      );
    });
    await SocialIsar.instance.writeTxn<void>((isar) async {
      await isar.squarePostSyncCheckpointEntitys.putByCidNumber(
        SquarePostSyncCheckpointEntity()
          ..cidNumber = 'R5-K3P1C1-N9-D4'
          ..newestPostId = 'social'
          ..newestCreatedAt = 2,
      );
    });
    await ChatIsar.instance.writeTxn<void>((isar) async {
      await isar.chatRouteCacheEntitys.put(
        ChatRouteCacheEntity()
          ..ownerCidNumber = 'R5-K3P1C1-N9-D4'
          ..peerCidNumber = 'R5-K3P1C1-N8-D5'
          ..routeDisplayName = 'chat'
          ..deviceId = 'device-user-close'
          ..devicePublicKey = 'public-key-user-close'
          ..safetyNumber = '5678'
          ..createdAtMillis = 1
          ..updatedAtMillis = 1,
      );
    });

    await UserIsar.instance.closeAndDeleteFromDisk();
    await expectLater(UserIsar.instance.db(), throwsA(isA<StateError>()));

    expect(
      await WalletIsar.instance.read((isar) async =>
          (await isar.walletAttestationEntitys.get(0))?.lastRequestPayload),
      'wallet',
    );
    expect(
      await SocialIsar.instance.read((isar) async => (await isar
              .squarePostSyncCheckpointEntitys
              .getByCidNumber('R5-K3P1C1-N9-D4'))
          ?.newestPostId),
      'social',
    );
    expect(
      await ChatIsar.instance.read((isar) async =>
          (await isar.chatRouteCacheEntitys.getByOwnerCidNumberPeerCidNumber(
            'R5-K3P1C1-N9-D4',
            'R5-K3P1C1-N8-D5',
          ))
              ?.routeDisplayName),
      'chat',
    );

    await UserIsar.instance.resetForTest();
    expect(
      await UserIsar.instance.read(
        (isar) => isar.userPublicProfileCacheEntitys.where().count(),
      ),
      0,
    );
  });
}
