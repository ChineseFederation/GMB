import 'dart:async';

import 'package:citizenapp/isar/social_isar.dart';
import 'package:gmb_chat_sdk/chat_sdk.dart';
import 'package:citizenapp/isar/app_isar.dart';
import 'package:citizenapp/isar/user_isar.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../support/isar_test_env.dart';

const Duration _timeout = Duration(seconds: 1);
const String _ownerUserId = 'CN220-CTZN2-100000011-2026';
const String _peerUserId = 'CN220-CTZN2-100000012-2026';

void main() {
  useIsolatedIsar();

  test('五个数据库使用独立文件名和独立 Isar 实例', () async {
    await Future.wait<void>(<Future<void>>[
      AppIsar.instance.db().then<void>((_) {}),
      SocialIsar.instance.db().then<void>((_) {}),
      ChatIsar.instance.db().then<void>((_) {}),
      UserIsar.instance.db().then<void>((_) {}),
      WalletIsar.instance.db().then<void>((_) {}),
    ]);

    final instances = <Isar?>[
      Isar.getInstance('citizenapp_app'),
      Isar.getInstance('citizenapp_social'),
      Isar.getInstance('chat_sdk_chat'),
      Isar.getInstance('citizenapp_user'),
      Isar.getInstance('citizenapp_wallet'),
    ];
    expect(instances, everyElement(isNotNull));
    expect(instances.toSet(), hasLength(5));
  });

  test('AppIsar 队列挂起时其余四域仍可独立读写', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocked = AppIsar.instance.read<void>((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(_timeout);

    try {
      await Future.wait<void>(<Future<void>>[
        WalletIsar.instance.writeTxn<void>((isar) async {
          await isar.walletAttestationEntitys.put(
            WalletAttestationEntity()
              ..id = 0
              ..lastRequestPayload = 'wallet',
          );
        }),
        UserIsar.instance.writeTxn<void>((isar) async {
          await isar.userPublicProfileCacheEntitys.putByCidNumber(
            UserPublicProfileCacheEntity()
              ..cidNumber = _ownerUserId
              ..profileJson = '{"display_name":"用户资料"}',
          );
        }),
        SocialIsar.instance.writeTxn<void>((isar) async {
          await isar.squarePostSyncCheckpointEntitys.putByCidNumber(
            SquarePostSyncCheckpointEntity()
              ..cidNumber = _ownerUserId
              ..newestPostId = 'post'
              ..newestCreatedAt = 1,
          );
        }),
        ChatIsar.instance.writeTxn<void>((isar) async {
          await isar.chatRouteCacheEntitys.put(
            ChatRouteCacheEntity()
              ..ownerUserId = _ownerUserId
              ..peerUserId = _peerUserId
              ..routeDisplayName = '联系人'
              ..deviceId = 'device'
              ..safetyNumber = '1234'
              ..createdAtMillis = 1
              ..updatedAtMillis = 1,
          );
        }),
      ]).timeout(_timeout);

      expect(AppIsar.instance.hasActiveOperation, isTrue);
      expect(WalletIsar.instance.hasActiveOperation, isFalse);
      expect(UserIsar.instance.hasActiveOperation, isFalse);
      expect(SocialIsar.instance.hasActiveOperation, isFalse);
      expect(ChatIsar.instance.hasActiveOperation, isFalse);
    } finally {
      release.complete();
      await blocked.timeout(_timeout);
    }
  });

  test('WalletIsar 队列挂起时 App 通用目录仍可独立读写', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocked = WalletIsar.instance.read<void>((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(_timeout);

    try {
      await AppIsar.instance
          .writeTxn<void>((isar) async {
            await isar.appDataVersionEntitys.putByNamespace(
              AppDataVersionEntity()
                ..namespace = 'storage-isolation'
                ..globalVersion = 'app-ready'
                ..updatedAtMillis = 1,
            );
          })
          .timeout(_timeout);
      final value = await AppIsar.instance
          .read<String?>((isar) async {
            return (await isar.appDataVersionEntitys.getByNamespace(
              'storage-isolation',
            ))?.globalVersion;
          })
          .timeout(_timeout);

      expect(value, 'app-ready');
      expect(WalletIsar.instance.hasActiveOperation, isTrue);
      expect(AppIsar.instance.hasActiveOperation, isFalse);
    } finally {
      release.complete();
      await blocked.timeout(_timeout);
    }
  });

  test('关闭 AppIsar 只删除通用数据库，其余四域事实保持可用', () async {
    await AppIsar.instance.writeTxn<void>((isar) async {
      await isar.appDataVersionEntitys.putByNamespace(
        AppDataVersionEntity()
          ..namespace = 'delete-boundary'
          ..globalVersion = 'app'
          ..updatedAtMillis = 1,
      );
    });
    await WalletIsar.instance.writeTxn<void>((isar) async {
      await isar.walletAttestationEntitys.put(
        WalletAttestationEntity()
          ..id = 0
          ..lastRequestPayload = 'wallet',
      );
    });
    await UserIsar.instance.writeTxn<void>((isar) async {
      await isar.userPublicProfileCacheEntitys.putByCidNumber(
        UserPublicProfileCacheEntity()
          ..cidNumber = _ownerUserId
          ..profileJson = '{"display_name":"保留用户资料"}',
      );
    });
    await SocialIsar.instance.writeTxn<void>((isar) async {
      await isar.squarePostSyncCheckpointEntitys.putByCidNumber(
        SquarePostSyncCheckpointEntity()
          ..cidNumber = _ownerUserId
          ..newestPostId = 'social'
          ..newestCreatedAt = 1,
      );
    });
    await ChatIsar.instance.writeTxn<void>((isar) async {
      await isar.chatRouteCacheEntitys.put(
        ChatRouteCacheEntity()
          ..ownerUserId = _ownerUserId
          ..peerUserId = _peerUserId
          ..routeDisplayName = 'chat'
          ..deviceId = 'device'
          ..safetyNumber = '5678'
          ..createdAtMillis = 1
          ..updatedAtMillis = 1,
      );
    });

    await AppIsar.instance.closeAndDeleteFromDisk();
    await expectLater(AppIsar.instance.db(), throwsA(isA<StateError>()));

    expect(
      await WalletIsar.instance.read(
        (isar) async =>
            (await isar.walletAttestationEntitys.get(0))?.lastRequestPayload,
      ),
      'wallet',
    );
    expect(
      await UserIsar.instance.read(
        (isar) async =>
            (await isar.userPublicProfileCacheEntitys.getByCidNumber(
              _ownerUserId,
            ))?.profileJson,
      ),
      '{"display_name":"保留用户资料"}',
    );
    expect(
      await SocialIsar.instance.read(
        (isar) async =>
            (await isar.squarePostSyncCheckpointEntitys.getByCidNumber(
              _ownerUserId,
            ))?.newestPostId,
      ),
      'social',
    );
    expect(
      await ChatIsar.instance.read(
        (isar) async =>
            (await isar.chatRouteCacheEntitys.getByOwnerUserIdPeerUserId(
              _ownerUserId,
              _peerUserId,
            ))?.routeDisplayName,
      ),
      'chat',
    );
  });

  test('AppIsar 回调内重入快速失败，不形成同域自锁', () async {
    final nested = AppIsar.instance.read<void>((_) async {
      await AppIsar.instance.read<void>((_) async {});
    });
    await expectLater(nested.timeout(_timeout), throwsA(isA<StateError>()));
  });
}
