import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:citizenapp/8964/compose/drafts/compose_draft.dart';
import 'package:citizenapp/8964/compose/drafts/compose_draft_media.dart';
import 'package:citizenapp/8964/compose/drafts/compose_draft_store.dart';
import 'package:citizenapp/8964/models/square_models.dart';
import 'package:citizenapp/isar/social_isar.dart';

import '../../support/isar_test_env.dart';

SquareComposeDraft _draft(String id, int updatedAt,
        {String cidNumber = 'CN001-CTZN-100000001-2026'}) =>
    SquareComposeDraft(
      draftId: id,
      cidNumber: cidNumber,
      postType: SquarePostType.document,
      text: '内容 $id',
      media: const <SquareLocalMediaDraft>[],
      updatedAtMillis: updatedAt,
    );

void main() {
  useIsolatedIsar();
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = SquareComposeDraftStore.instance;
  late Directory documentsDirectory;

  setUpAll(() {
    documentsDirectory =
        Directory.systemTemp.createTempSync('citizenapp_square_drafts_');
    ComposeDraftMedia.debugDocumentsDirectoryProvider =
        () async => documentsDirectory;
  });
  setUp(() async {
    await ComposeDraftMedia.resetForTest(
      documentsDirectoryProvider: () async => documentsDirectory,
    );
  });
  tearDown(() async {
    await ComposeDraftMedia.resetForTest(
      documentsDirectoryProvider: () async => documentsDirectory,
    );
  });
  tearDownAll(() async {
    ComposeDraftMedia.debugDocumentsDirectoryProvider = null;
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
  });

  test('多草稿按 updated_at 新→旧列出，仅本人可见', () async {
    await store.save(_draft('a', 1000));
    await store.save(_draft('b', 3000));
    await store.save(_draft('c', 2000));
    await store.save(_draft('x', 9999, cidNumber: 'CN001-CTZN-999999999-2026'));

    final drafts = await store.list('CN001-CTZN-100000001-2026');
    expect(drafts.map((d) => d.draftId).toList(), ['b', 'c', 'a']);
    expect(
      drafts.every((d) => d.cidNumber == 'CN001-CTZN-100000001-2026'),
      isTrue,
    );
  });

  test('同 draftId 再存为覆盖，不新增', () async {
    await store.save(
      _draft('s', 1000, cidNumber: 'CN001-CTZN-200000001-2026'),
    );
    await store.save(
      _draft('s', 5000, cidNumber: 'CN001-CTZN-200000001-2026'),
    );
    final drafts = await store.list('CN001-CTZN-200000001-2026');
    expect(drafts.length, 1);
    expect(drafts.single.updatedAtMillis, 5000);
  });

  test('损坏草稿读取 fail-closed，数据库行与媒体目录均原样保留', () async {
    const cidNumber = 'CN001-CTZN-300000001-2026';
    const draftId = 'broken';
    final entity = SquareComposeDraftEntity()
      ..draftKey = '${cidNumber.length}:$cidNumber$draftId'
      ..cidNumber = cidNumber
      ..draftId = draftId
      ..postType = 'document'
      ..text = '损坏行'
      ..mediaJson = '{bad-json'
      ..updatedAtMillis = 1000;
    await SocialIsar.instance.writeTxn((isar) async {
      await isar.squareComposeDraftEntitys.putByDraftKey(entity);
    });
    final mediaDir = Directory(
      '${documentsDirectory.path}/square_drafts/'
      '${Uri.encodeComponent(cidNumber)}/${Uri.encodeComponent(draftId)}',
    );
    mediaDir.createSync(recursive: true);
    File('${mediaDir.path}/sentinel.bin').writeAsBytesSync(<int>[1, 2, 3]);

    await expectLater(
      store.list(cidNumber),
      throwsA(isA<SquareComposeDraftStoreException>()),
    );

    final retained = await SocialIsar.instance.read(
      (isar) => isar.squareComposeDraftEntitys.getByDraftKey(entity.draftKey),
    );
    expect(retained, isNotNull);
    expect(File('${mediaDir.path}/sentinel.bin').existsSync(), isTrue);
  });

  test('明确删除先提交事实与清理计划，文件失败保留计划并可重试', () async {
    const cidNumber = 'CN001-CTZN-400000001-2026';
    const draftId = 'delete-retry';
    await store.save(_draft(draftId, 1000, cidNumber: cidNumber));

    final invalidRoot = File('${documentsDirectory.path}/square_drafts');
    invalidRoot.writeAsStringSync('阻断目录删除');
    await expectLater(
      store.delete(cidNumber, draftId),
      throwsA(isA<SquareComposeDraftStoreException>()),
    );

    expect(await store.list(cidNumber), isEmpty);
    final pending = await SocialIsar.instance.read(
      (isar) => isar.squareFileCleanupEntitys.where().findAll(),
    );
    expect(pending, hasLength(1));
    expect(pending.single.attemptCount, 1);

    invalidRoot.deleteSync();
    await store.retryPendingFileCleanup(cidNumber: cidNumber);
    final remaining = await SocialIsar.instance.read(
      (isar) => isar.squareFileCleanupEntitys.where().count(),
    );
    expect(remaining, 0);
  });

  test('非法路径段和属主符号链接均 fail-closed，不扩大删除范围', () async {
    final root = Directory('${documentsDirectory.path}/square_drafts')
      ..createSync(recursive: true);
    final rootMarker = File('${root.path}/root-marker.bin')
      ..writeAsBytesSync(<int>[1]);

    await expectLater(
      store.delete('CN001-CTZN-500000001-2026', '..'),
      throwsA(isA<SquareComposeDraftStoreException>()),
    );
    expect(rootMarker.existsSync(), isTrue);

    const cidNumber = 'CN001-CTZN-500000002-2026';
    final outside = Directory('${documentsDirectory.path}/outside')
      ..createSync();
    final outsideMarker = File('${outside.path}/must-survive.bin')
      ..writeAsBytesSync(<int>[2]);
    Link('${root.path}/${Uri.encodeComponent(cidNumber)}')
        .createSync(outside.path);

    await expectLater(
      ComposeDraftMedia.deleteDir(cidNumber, 'draft-a'),
      throwsA(isA<StateError>()),
    );
    expect(outsideMarker.existsSync(), isTrue);
  });
}
