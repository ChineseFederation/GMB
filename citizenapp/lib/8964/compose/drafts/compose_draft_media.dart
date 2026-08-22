import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:citizenapp/8964/models/square_models.dart';

enum _ComposeDraftMediaLifecycle { active, closing, closed }

/// 草稿媒体文件域。
///
/// 文件操作使用独立串行队列和终态，不依赖任何 Isar 队列。AppLock 显式擦除一旦进入
/// closing，新写入会同步拒绝；晚到 copy 也会清除自己产生的目录，不能在擦除后复活。
class ComposeDraftMedia {
  const ComposeDraftMedia();

  static final Object _operationZoneKey = Object();
  static Future<void> _operationTail = Future<void>.value();
  static _ComposeDraftMediaLifecycle _lifecycle =
      _ComposeDraftMediaLifecycle.active;
  static int _generation = 0;
  static Future<void>? _closing;

  static const Duration _drainTimeout = Duration(seconds: 2);

  @visibleForTesting
  static Future<Directory> Function()? debugDocumentsDirectoryProvider;

  static Future<Directory> _documentsDirectory(
    Future<Directory> Function()? override,
  ) =>
      (override ??
          debugDocumentsDirectoryProvider ??
          getApplicationDocumentsDirectory)();

  static Future<Directory> _root({
    required bool create,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final docs = await _documentsDirectory(documentsDirectoryProvider);
    final dir = Directory('${docs.path}/square_drafts');
    final type = await FileSystemEntity.type(dir.path, followLinks: false);
    if (type == FileSystemEntityType.link ||
        type == FileSystemEntityType.file) {
      throw StateError('广场草稿根路径不是目录，拒绝继续文件操作。');
    }
    if (create && type == FileSystemEntityType.notFound) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _draftDir(
    String cidNumber,
    String draftId, {
    required bool create,
  }) async {
    _validatePathSegment(cidNumber, 'cid_number');
    _validatePathSegment(draftId, 'draft_id');
    final root = await _root(create: create);
    final ownerDir = Uri.encodeComponent(cidNumber);
    final encodedDraftId = Uri.encodeComponent(draftId);
    final owner = Directory('${root.path}/$ownerDir');
    final ownerType =
        await FileSystemEntity.type(owner.path, followLinks: false);
    if (ownerType == FileSystemEntityType.link ||
        ownerType == FileSystemEntityType.file) {
      throw StateError('广场草稿属主路径不是目录，拒绝继续文件操作。');
    }
    if (create && ownerType == FileSystemEntityType.notFound) {
      await owner.create(recursive: true);
    }
    final dir = Directory('${owner.path}/$encodedDraftId');
    final type = await FileSystemEntity.type(dir.path, followLinks: false);
    if (type == FileSystemEntityType.link ||
        type == FileSystemEntityType.file) {
      throw StateError('广场草稿媒体路径不是目录，拒绝继续文件操作。');
    }
    if (create && type == FileSystemEntityType.notFound) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static void _validatePathSegment(String value, String field) {
    if (value.trim().isEmpty ||
        value.trim() != value ||
        value == '.' ||
        value == '..') {
      throw ArgumentError.value(value, field, '不是合法的草稿路径标识');
    }
  }

  /// 已在本草稿目录内则原样返回；否则复制到 Social 文件域。
  static Future<SquareLocalMediaDraft> persist(
    String cidNumber,
    String draftId,
    SquareLocalMediaDraft media,
  ) {
    Directory? createdDirectory;
    return _enqueueMutation(
      () async {
        final dir = await _draftDir(cidNumber, draftId, create: true);
        createdDirectory = dir;
        if (media.path.startsWith('${dir.path}/')) return media;
        final ext = media.fileExt.isNotEmpty ? '.${media.fileExt}' : '';
        final target =
            File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext');
        await File(media.path).copy(target.path);
        return SquareLocalMediaDraft(
          mediaKind: media.mediaKind,
          path: target.path,
          fileName: media.fileName,
          contentType: media.contentType,
          byteSize: media.byteSize,
          durationSeconds: media.durationSeconds,
          photoManagerAssetId: media.photoManagerAssetId,
        );
      },
      onInvalidated: () async {
        final dir = createdDirectory;
        if (dir != null && await dir.exists()) {
          await dir.delete(recursive: true);
        }
      },
    );
  }

  /// 删除一条草稿的整个媒体目录；路径不存在时不创建任何目录。
  static Future<void> deleteDir(String cidNumber, String draftId) {
    return _enqueueMutation(() async {
      final dir = await _draftDir(cidNumber, draftId, create: false);
      if (await dir.exists()) await dir.delete(recursive: true);
    });
  }

  static Future<T> _enqueueMutation<T>(
    Future<T> Function() action, {
    Future<void> Function()? onInvalidated,
  }) {
    if (identical(Zone.current[_operationZoneKey], true)) {
      throw StateError('禁止在广场草稿文件操作内再次进入同一文件队列。');
    }
    if (_lifecycle != _ComposeDraftMediaLifecycle.active) {
      throw StateError('广场草稿文件域已关闭，禁止继续写入。');
    }

    final generation = _generation;
    final previous = _operationTail;
    final completer = Completer<T>();
    _operationTail = completer.future.then<void>((_) {}, onError: (_) {});
    () async {
      try {
        await previous.catchError((_) {});
        if (_lifecycle != _ComposeDraftMediaLifecycle.active ||
            generation != _generation) {
          throw StateError('广场草稿文件域已关闭，排队操作已取消。');
        }
        final result = await runZoned(
          action,
          zoneValues: <Object?, Object?>{_operationZoneKey: true},
        );
        if (_lifecycle != _ComposeDraftMediaLifecycle.active ||
            generation != _generation) {
          await onInvalidated?.call();
          throw StateError('广场草稿文件域已关闭，旧操作结果已取消。');
        }
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  /// AppLock 显式安全擦除调用；只删除 Documents 下精确的 `square_drafts/`。
  static Future<void> closeAndDeleteAll({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) {
    final inFlight = _closing;
    if (_lifecycle == _ComposeDraftMediaLifecycle.closing && inFlight != null) {
      return inFlight;
    }

    _lifecycle = _ComposeDraftMediaLifecycle.closing;
    _generation += 1;
    late final Future<void> task;
    task = _closeAndDeleteInternal(documentsDirectoryProvider).whenComplete(() {
      _lifecycle = _ComposeDraftMediaLifecycle.closed;
      if (identical(_closing, task)) _closing = null;
    });
    _closing = task;
    return task;
  }

  static Future<void> _closeAndDeleteInternal(
    Future<Directory> Function()? documentsDirectoryProvider,
  ) async {
    try {
      await _operationTail.timeout(_drainTimeout);
    } on TimeoutException {
      // 晚到写入会在完成后检查 generation 并删除自己创建的草稿目录。
    }
    final root = await _root(
      create: false,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    if (await root.exists()) await root.delete(recursive: true);
  }

  @visibleForTesting
  static Future<void> resetForTest({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    await closeAndDeleteAll(
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    _operationTail = Future<void>.value();
    _closing = null;
    _generation += 1;
    _lifecycle = _ComposeDraftMediaLifecycle.active;
  }
}
