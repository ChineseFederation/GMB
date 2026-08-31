import 'package:gmb_chat_sdk/chat_sdk.dart';

/// 聊天媒体大小上限的单一真源(收发两端共用),按会员档动态(ADR-037,会员与身份解耦)。
///
/// 会员权益之一 = 单个聊天附件上限:无订阅 0、自由 10MB、民主 100MB、薪火 5GB,与会员套餐
/// `chat_file_max_bytes` 同源。发送端、服务端和接收端将在各自边界执行同一限制；本类负责
/// 手机端当前有效会员档的本地门控，不把未知档位错误提升为自由会员。
///
/// 当前档只由 SubscriptionService 写入统一会员缓存时设置；网络 API 保持纯解析，
/// 无订阅、缓存过期或未知档位一律 fail-closed 为 0。
class ChatMediaLimits {
  ChatMediaLimits._();

  static const int _mib = 1024 * 1024;

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

  /// 当前登录会话最近一次由 CitizenServe 明确授权的聊天权益。展示快照只负责
  /// 页面稳定显示，不能写入这组字段，更不能在断网后继续授权新的发送动作。
  static int _authorizedMaxBytes = 0;
  static String? _authorizedCidNumber;
  static bool _authorizationResolved = false;

  /// 会员档 → 单个文件上限(纯函数,可测)。未知 / 无订阅一律禁止。
  static int maxBytesForLevel(String? level) => switch (level) {
        'spark' => sparkMaxBytes,
        'democracy' => democracyMaxBytes,
        'freedom' => freedomMaxBytes,
        _ => 0,
      };

  /// 会员状态载入后设置当前档上限；订阅失效或档位未知时统一关闭聊天权益。
  static void applyMembershipLevel(String? level, {String? cidNumber}) {
    final normalized = cidNumber?.trim();
    if (cidNumber == null) {
      // 无 CID 调用只用于纯函数/Widget 测试；生产快照始终携带真实 CID。
      _authorizedMaxBytes = maxBytesForLevel(level);
      _authorizedCidNumber = null;
      _authorizationResolved = true;
    }
    if (_authorizedCidNumber != null &&
        normalized != null &&
        _authorizedCidNumber != normalized) {
      _authorizedMaxBytes = 0;
      _authorizedCidNumber = normalized;
      _authorizationResolved = false;
    }
    _currentMaxBytes = maxBytesForLevel(level);
    _currentCidNumber = normalized;
    _resolved = true;
  }

  /// CitizenServe 本次会话鉴权成功后推进授权缓存；无会员同样是已解析的 0 权益。
  static void applyAuthorizedMembershipLevel(
    String? level, {
    required String cidNumber,
  }) {
    _authorizedMaxBytes = maxBytesForLevel(level);
    _authorizedCidNumber = cidNumber.trim();
    _authorizationResolved = true;
  }

  /// CitizenServe 鉴权失败时立即关闭发送授权；既有展示快照不受影响。
  static void markAuthorizationUnavailable(String cidNumber) {
    _authorizedMaxBytes = 0;
    _authorizedCidNumber = cidNumber.trim();
    _authorizationResolved = false;
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

  static bool chatAuthorizedFor(String cidNumber) =>
      _authorizationResolved &&
      _authorizedMaxBytes > 0 &&
      (_authorizedCidNumber == null ||
          _authorizedCidNumber == cidNumber.trim());

  static bool authorizationResolvedFor(String cidNumber) =>
      _authorizationResolved &&
      (_authorizedCidNumber == null ||
          _authorizedCidNumber == cidNumber.trim());

  /// 网络或会话失败不是“无会员”，但同样必须 fail-closed，后续允许重新读取。
  static void markUnresolved(String cidNumber) {
    final normalized = cidNumber.trim();
    if (_resolved &&
        (_currentCidNumber == null || _currentCidNumber == normalized)) {
      return;
    }
    _currentMaxBytes = 0;
    _currentCidNumber = normalized;
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
          _authorizedMaxBytes,
        ChatMessageKind.text || ChatMessageKind.sticker => 0,
      };

  /// 按 MIME 取上限；媒体一律取当前有效会员档上限。
  static int forMime(String mime) => _authorizedMaxBytes;

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
    return durationMs > chatMessageMaximumDuration.inMilliseconds;
  }
}

class CitizenChatMediaLimitPolicy implements ChatMediaLimitPolicy {
  const CitizenChatMediaLimitPolicy();

  @override
  int limitForKind(ChatMessageKind kind) => ChatMediaLimits.forKind(kind);

  @override
  int limitForMime(String contentType) => ChatMediaLimits.forMime(contentType);

  @override
  bool exceedsForKind(ChatMessageKind kind, int byteSize) =>
      ChatMediaLimits.exceedsForKind(kind, byteSize);
}
