import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:citizenapp/isar/user_isar.dart';

import 'package:citizenapp/8964/profile/models/citizen_profile.dart';

@immutable
class CitizenProfileRevisionEvent {
  const CitizenProfileRevisionEvent({
    required this.cidNumber,
    required this.revision,
  });

  final String cidNumber;
  final int revision;
}

/// 用户主页资料的本地离线缓存。
///
/// 先渲染缓存 → 后台刷新 → 回刷并写回。只缓存成功拉到的真实资料，
/// 兜底默认值不入缓存（避免把空资料当成真数据回读）。
class CitizenProfileCache {
  const CitizenProfileCache();

  /// 公开资料按 CID 更新的进程内通知。MyTab 常驻 IndexedStack，不能依赖
  /// initState 或重新进入页面刷新；缓存原子提交后用本事件让已挂载展示点重读。
  static final ValueNotifier<CitizenProfileRevisionEvent?> revision =
      ValueNotifier<CitizenProfileRevisionEvent?>(null);
  static int _revision = 0;

  Future<CitizenProfile?> read(String cidNumber) async {
    final normalizedCidNumber = cidNumber.trim();
    if (normalizedCidNumber.isEmpty) return null;
    final raw = await UserIsar.instance.read((isar) async {
      return (await isar.userPublicProfileCacheEntitys
              .getByCidNumber(normalizedCidNumber))
          ?.profileJson;
    });
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return CitizenProfile.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> write(CitizenProfile profile) async {
    // 缓存主键 = 身份主键 cid_number；缺失身份（cid 为空）的资料不入缓存，
    // 避免把无主键的兜底资料当真数据回读。
    final cidNumber = profile.cidNumber?.trim();
    if (cidNumber == null || cidNumber.isEmpty) return;
    final payload = jsonEncode(profile.toJson());
    final changed = await UserIsar.instance.writeTxn((isar) async {
      final current =
          await isar.userPublicProfileCacheEntitys.getByCidNumber(cidNumber);
      if (current?.profileJson == payload) return false;
      await isar.userPublicProfileCacheEntitys.putByCidNumber(
        UserPublicProfileCacheEntity()
          ..cidNumber = cidNumber
          ..profileJson = payload,
      );
      return true;
    });
    if (changed) {
      revision.value = CitizenProfileRevisionEvent(
        cidNumber: cidNumber,
        revision: ++_revision,
      );
    }
  }

  Future<void> clear(String cidNumber) async {
    final normalizedCidNumber = cidNumber.trim();
    if (normalizedCidNumber.isEmpty) return;
    final changed = await UserIsar.instance.writeTxn((isar) async {
      return isar.userPublicProfileCacheEntitys
          .deleteByCidNumber(normalizedCidNumber);
    });
    if (changed) {
      revision.value = CitizenProfileRevisionEvent(
        cidNumber: normalizedCidNumber,
        revision: ++_revision,
      );
    }
  }
}

@immutable
class CitizenProfileMediaSnapshot {
  const CitizenProfileMediaSnapshot({this.avatarPath, this.bannerPath});

  final String? avatarPath;
  final String? bannerPath;
}

/// 公开资料媒体的本机只读副本。
///
/// R2 object_key 仍是公开资料真源；本缓存只保证已设置图片的首帧和离线展示。缓存文件
/// 按 CID、媒体类型和资料 updated_at 隔离，绝不把内置默认图写成用户资料。用户已设置
/// 但下载失败时保留上一张用户图片或中性占位，不能伪装成“从未设置”而回退随机内置图。
class CitizenProfileMediaCache {
  CitizenProfileMediaCache({
    Future<Directory> Function()? supportDirectoryProvider,
    http.Client? client,
  })  : _supportDirectoryProvider =
            supportDirectoryProvider ?? getApplicationSupportDirectory,
        _client = client;

  final Future<Directory> Function() _supportDirectoryProvider;
  final http.Client? _client;

  /// 用户明确注销后删除该 CID 的公开资料媒体副本。object key 仍由服务端硬删负责；
  /// 本方法只定位哈希后的单一 CID 子目录，不能扩大到其它用户或业务文件。
  Future<void> clearCid(String cidNumber) async {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty) return;
    final root = await _profileMediaRoot();
    final cidHash = sha256.convert(utf8.encode(normalized)).toString();
    await _deleteExactTree(p.join(root.path, cidHash));
  }

  /// 只供 AppLock 的明确全量安全擦除；普通启动、资料读取和缓存刷新不得调用。
  Future<void> closeAndDeleteAll() async {
    final root = await _profileMediaRoot();
    await _deleteExactTree(root.path);
  }

  Future<CitizenProfileMediaSnapshot> read(CitizenProfile profile) async {
    return CitizenProfileMediaSnapshot(
      avatarPath: await _readBest(profile, 'avatar'),
      bannerPath: await _readBest(profile, 'banner'),
    );
  }

  /// 编辑页已经持有用户选择的原始字节；资料提交成功后直接缓存，避免返回 MyTab
  /// 又等一次网络下载。只缓存服务端已返回 object_key 的媒体。
  Future<CitizenProfileMediaSnapshot> rememberSelected({
    required CitizenProfile profile,
    Uint8List? avatarBytes,
    Uint8List? bannerBytes,
  }) async {
    if (avatarBytes == null && bannerBytes == null) {
      return const CitizenProfileMediaSnapshot();
    }
    if (avatarBytes != null && _objectKey(profile, 'avatar') != null) {
      await _write(profile, 'avatar', avatarBytes);
    }
    if (bannerBytes != null && _objectKey(profile, 'banner') != null) {
      await _write(profile, 'banner', bannerBytes);
    }
    return read(profile);
  }

  /// 为缺少当前 revision 文件的已设置媒体补齐本机缓存。调用方传入现有钱包 Session
  /// 的鉴权头；下载、文件落盘均在 UserIsar 事务外进行。
  Future<CitizenProfileMediaSnapshot> refresh({
    required CitizenProfile profile,
    required String? avatarUrl,
    required String? bannerUrl,
    required Map<String, String>? headers,
  }) async {
    await Future.wait<void>([
      _downloadIfNeeded(
        profile: profile,
        kind: 'avatar',
        url: avatarUrl,
        headers: headers,
      ),
      _downloadIfNeeded(
        profile: profile,
        kind: 'banner',
        url: bannerUrl,
        headers: headers,
      ),
    ]);
    return read(profile);
  }

  Future<void> _downloadIfNeeded({
    required CitizenProfile profile,
    required String kind,
    required String? url,
    required Map<String, String>? headers,
  }) async {
    if (_objectKey(profile, kind) == null || url == null || url.isEmpty) return;
    final target = await _exactFile(profile, kind);
    if (await target.exists()) return;
    final ownClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final limit = kind == 'avatar' ? 512 * 1024 : 1536 * 1024;
      if (response.bodyBytes.isEmpty || response.bodyBytes.length > limit) {
        return;
      }
      await _write(profile, kind, response.bodyBytes);
    } on Exception {
      // 展示缓存是 best-effort；网络失败时保留上一张用户图片，不改资料真源。
    } finally {
      if (ownClient) client.close();
    }
  }

  Future<String?> _readBest(CitizenProfile profile, String kind) async {
    if (_objectKey(profile, kind) == null) return null;
    final exact = await _exactFile(profile, kind);
    if (await exact.exists()) return exact.path;
    final directory = exact.parent;
    if (!await directory.exists()) return null;
    final candidates = await directory
        .list()
        .where((entry) =>
            entry is File && p.basename(entry.path).startsWith('${kind}_'))
        .cast<File>()
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return candidates.first.path;
  }

  Future<File> _write(
    CitizenProfile profile,
    String kind,
    Uint8List bytes,
  ) async {
    final target = await _exactFile(profile, kind);
    if (await target.exists()) return target;
    await target.parent.create(recursive: true);
    final temporary = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.writing',
    );
    await temporary.writeAsBytes(bytes, flush: true);
    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      if (!await target.exists()) rethrow;
      if (await temporary.exists()) await temporary.delete();
    }
    await _removeOlderFiles(target, kind);
    return target;
  }

  Future<void> _removeOlderFiles(File current, String kind) async {
    try {
      await for (final entry in current.parent.list()) {
        if (entry is File &&
            entry.path != current.path &&
            p.basename(entry.path).startsWith('${kind}_')) {
          await entry.delete();
        }
      }
    } on FileSystemException {
      // 当前文件已经原子落盘；旧缓存清理失败不撤销新资料展示。
    }
  }

  Future<File> _exactFile(CitizenProfile profile, String kind) async {
    final root = await _profileMediaRoot();
    final cidNumber = profile.cidNumber?.trim() ?? '';
    final cidHash = sha256.convert(utf8.encode(cidNumber)).toString();
    final key = _objectKey(profile, kind) ?? '';
    final revision = sha256
        .convert(utf8.encode(
            '$cidNumber\u0000$kind\u0000$key\u0000${profile.updatedAt}'))
        .toString();
    return File(
      p.join(root.path, cidHash, '${kind}_$revision'),
    );
  }

  Future<Directory> _profileMediaRoot() async {
    final support = await _supportDirectoryProvider();
    return Directory(p.join(support.path, 'user', 'profile_media'));
  }

  Future<void> _deleteExactTree(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
        return;
      case FileSystemEntityType.file:
      case FileSystemEntityType.link:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        await File(path).delete();
        return;
    }
  }

  String? _objectKey(CitizenProfile profile, String kind) {
    final value =
        kind == 'avatar' ? profile.avatarObjectKey : profile.bannerObjectKey;
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
