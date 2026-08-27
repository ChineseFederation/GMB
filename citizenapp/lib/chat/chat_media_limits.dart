import 'chat_models.dart';

/// 聊天媒体大小上限的单一真源(收发两端共用),按会员档动态(ADR-037,会员与身份解耦)。
///
/// 会员权益之一 = 单个聊天附件上限:无订阅 0、自由 10MB、民主 100MB、薪火 5GB,与会员套餐
/// `chat_file_max_bytes` 同源。发送端、服务端和接收端将在各自边界执行同一限制；本类负责
/// 手机端当前有效会员档的本地门控，不把未知档位错误提升为自由会员。
///
/// 当前档由 [applyMembershipLevel] 在会员状态载入时设置（见
/// `SquareApiClient.fetchMembership`），无订阅或未知档位 fail-closed 为 0。
class ChatMediaLimits {
  ChatMediaLimits._();

  static const int _mib = 1024 * 1024;
  static const Duration messageMaximumDuration = Duration(minutes: 3);

  /// 三档单个文件上限(字节),与会员套餐 `chat_file_max_bytes` 单源对齐。
  static const int freedomMaxBytes = 10 * _mib;
  static const int democracyMaxBytes = 100 * _mib;
  static const int sparkMaxBytes = 5120 * _mib;

  /// 传输字节层的绝对硬顶(= 最高档上限)，不能作为未知会员的兜底权益。
  static const int absoluteMaxBytes = sparkMaxBytes;

  /// 当前默认钱包会员档的单个文件上限；0 表示无有效聊天权益。
  static int _currentMaxBytes = 0;
  static String? _currentCidNumber;
  static bool _resolved = false;

  /// 会员档 → 单个文件上限(纯函数,可测)。未知 / 无订阅一律禁止。
  static int maxBytesForLevel(String? level) => switch (level) {
        'spark' => sparkMaxBytes,
        'democracy' => democracyMaxBytes,
        'freedom' => freedomMaxBytes,
        _ => 0,
      };

  /// 会员状态载入后设置当前档上限；订阅失效或档位未知时统一关闭聊天权益。
  static void applyMembershipLevel(String? level, {String? cidNumber}) {
    _currentMaxBytes = maxBytesForLevel(level);
    _currentCidNumber = cidNumber?.trim();
    _resolved = true;
  }

  /// 当前钱包是否具备有效聊天权益。
  static bool get chatEnabled => _currentMaxBytes > 0;

  /// 权益必须属于当前 CID；`cidNumber == null` 只保留给无账户纯函数测试。
  static bool chatEnabledFor(String cidNumber) =>
      _resolved &&
      _currentMaxBytes > 0 &&
      (_currentCidNumber == null || _currentCidNumber == cidNumber.trim());

  /// 当前 CID 已取得 CitizenServe 明确的有效或无会员结果。
  static bool resolvedFor(String cidNumber) =>
      _resolved &&
      (_currentCidNumber == null || _currentCidNumber == cidNumber.trim());

  /// 网络或会话失败不是“无会员”，但同样必须 fail-closed，后续允许重新读取。
  static void markUnresolved(String cidNumber) {
    _currentMaxBytes = 0;
    _currentCidNumber = cidNumber.trim();
    _resolved = false;
  }

  static String get currentLimitLabel {
    if (_currentMaxBytes >= 1024 * _mib) {
      return '${_currentMaxBytes ~/ (1024 * _mib)}GB';
    }
    return '${_currentMaxBytes ~/ _mib}MB';
  }

  /// 当前档单个文件上限(字节)。
  static int get currentMaxBytes => _currentMaxBytes;

  /// 按消息类型取上限。媒体(image/video/file/audio)= 当前档上限;text / sticker 无字节返回 0。
  static int forKind(ChatMessageKind kind) => switch (kind) {
        ChatMessageKind.image ||
        ChatMessageKind.video ||
        ChatMessageKind.file ||
        ChatMessageKind.audio =>
          _currentMaxBytes,
        ChatMessageKind.text || ChatMessageKind.sticker => 0,
      };

  /// 按 MIME 取上限；媒体一律取当前有效会员档上限。
  static int forMime(String mime) => _currentMaxBytes;

  /// 该类消息的 [byteSize] 是否超限。0 上限(text/sticker)一律视为不超限,
  /// 因为它们不携带媒体字节。
  static bool exceedsForKind(ChatMessageKind kind, int byteSize) {
    final limit = forKind(kind);
    if (kind == ChatMessageKind.text || kind == ChatMessageKind.sticker) {
      return false;
    }
    return byteSize > limit;
  }

  /// 语音和视频消息统一为每条 3 分钟；其他消息没有媒体时长字段。
  static bool exceedsDurationForKind(ChatMessageKind kind, int? durationMs) {
    if (durationMs == null || durationMs <= 0) return false;
    if (kind != ChatMessageKind.audio && kind != ChatMessageKind.video) {
      return false;
    }
    return durationMs > messageMaximumDuration.inMilliseconds;
  }
}

/// 媒体超出大小上限。发送端在把任何字节送入通道前抛出;UI 据此给用户明确提示。
class ChatMediaTooLargeException implements Exception {
  const ChatMediaTooLargeException({
    required this.byteSize,
    required this.limitBytes,
    this.kind,
  });

  final int byteSize;
  final int limitBytes;
  final ChatMessageKind? kind;

  @override
  String toString() => '媒体大小 $byteSize 字节超出上限 $limitBytes 字节';
}

/// 语音或视频消息超过统一的 3 分钟上限。
class ChatMediaTooLongException implements Exception {
  const ChatMediaTooLongException({required this.kind, required this.durationMs});

  final ChatMessageKind kind;
  final int durationMs;

  @override
  String toString() => '语音、视频消息每条最长 3 分钟';
}
