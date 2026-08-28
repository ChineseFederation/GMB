import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:file_picker/file_picker.dart';

import 'package:citizenapp/8964/profile/user_profile_page.dart';
import 'package:citizenapp/8964/profile/models/citizen_profile.dart';
import 'package:citizenapp/8964/profile/models/profile_presentation.dart';
import 'package:citizenapp/8964/profile/services/citizen_profile_api.dart';
import 'package:citizenapp/8964/profile/services/citizen_profile_cache.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/8964/profile/widgets/profile_avatar.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/my/myid/citizen_identity_chain_reader.dart';
import 'package:citizenapp/transaction/onchain-transaction/onchain_payment_page.dart';
import '../ui/app_theme.dart';
import 'chat_ui_adapter.dart';
import 'chat_flow.dart';
import 'chat_media_limits.dart';
import 'chat_models.dart';
import 'chat_payload.dart';
import 'crypto/mls_native.dart';
import 'compose/camera_capture_page.dart';
import 'compose/composer_action_panel.dart';
import 'compose/composer_bar.dart';
import 'compose/sticker_panel.dart';
import 'media/media_compressor.dart';
import 'media/media_mime.dart';
import 'media/media_picker.dart';
import 'media/media_probe.dart';
import 'media/voice_message_player.dart';
import 'media/voice_recorder.dart';
import 'stickers/sticker_pack.dart';
import 'storage/chat_store.dart';
import 'viewer/image_viewer_page.dart';
import 'viewer/video_player_page.dart';
import 'package:citizenapp/ui/app_layout.dart';

typedef ChatSendTextCallback = Future<void> Function(String text);
typedef ChatSendMediaCallback = Future<void> Function(
  ChatMediaDraft media, {
  ChatMediaLocalCommitNotifier? onLocalCommitted,
});
typedef ChatSendStickerCallback = Future<void> Function(
    String packId, String stickerId);
typedef ChatSyncCallback = Future<int> Function();
typedef ChatStartRealtimeCallback = Future<Future<void> Function()?> Function({
  required Future<void> Function() onNotice,
  Future<void> Function()? onDisconnected,
});
typedef ChatDownloadAttachmentCallback = Future<ChatDownloadedAttachment>
    Function(
  String conversationId,
  String controlPlaintext,
);
typedef ChatPickMediaCallback = Future<ChatMediaDraft?> Function();
typedef ChatResolveMediaPathsCallback = Future<Map<String, String>> Function(
  String conversationId,
  List<ChatContent> contents,
);
typedef ChatDeleteConversationCallback = Future<void> Function();
typedef ChatResolvePeerAddressCallback = Future<String> Function(
  String peerCidNumber,
);
typedef ChatStartCallCallback = Future<void> Function({required bool video});

/// 公民 Chat 聊天详情页。
///
/// 页面只使用现成聊天 UI 展示和输入，消息真源仍是本地
/// [ChatStore]，发送和同步由上层注入的 P2P/MLS 状态机完成。
class ChatPage extends StatefulWidget {
  ChatPage({
    super.key,
    required this.conversationId,
    required this.ownerCidNumber,
    required this.accountId,
    required this.peerUserId,
    required this.title,
    this.isGroup = false,
    ChatStore? store,
    this.onSendText,
    this.onSendMedia,
    this.onSendSticker,
    this.onDownloadAttachment,
    this.onResolveMediaPaths,
    this.pickMedia,
    this.onSync,
    this.onStartRealtime,
    this.onDeleteConversation,
    this.onStartCall,
    this.resolvePeerAddress,
    this.initialProfile,
    this.initialProfileMedia,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
  }) : store = store ?? ChatStore();

  final String conversationId;
  final String ownerCidNumber;
  final String accountId;
  final String peerUserId;
  final String title;

  /// 群聊模式:入站消息按各自 `senderCidNumber` 归属并在气泡上方显示发送者名。
  final bool isGroup;
  final ChatStore store;
  final ChatSendTextCallback? onSendText;
  final ChatSendMediaCallback? onSendMedia;
  final ChatSendStickerCallback? onSendSticker;
  final ChatDownloadAttachmentCallback? onDownloadAttachment;
  final ChatResolveMediaPathsCallback? onResolveMediaPaths;
  final ChatPickMediaCallback? pickMedia;
  final ChatSyncCallback? onSync;
  final ChatStartRealtimeCallback? onStartRealtime;
  final ChatDeleteConversationCallback? onDeleteConversation;
  final ChatStartCallCallback? onStartCall;
  final ChatResolvePeerAddressCallback? resolvePeerAddress;
  final CitizenProfile? initialProfile;
  final CitizenProfileMediaSnapshot? initialProfileMedia;
  final CitizenProfileApi? profileApi;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquareSessionProvider? sessionProvider;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // 实时连接不可用时只重试发送设备本机队列；失败后退避，避免弱网持续请求。
  static const _normalPollInterval = Duration(seconds: 8);
  static const _backoffPollInterval = Duration(seconds: 30);
  // 实时已连时仍保留的低频心跳兜底：即使 WS 推送静默丢失，也能在此间隔内收到。
  static const _heartbeatPollInterval = Duration(seconds: 20);

  late final InMemoryChatController _chatController;
  late final _ChatLifecycleObserver _lifecycleObserver;
  late final CitizenProfileApi _profileApi;
  late final CitizenProfileCache _profileCache;
  late final CitizenProfileMediaCache _profileMediaCache;
  late final SquareSessionProvider _sessionProvider;
  CitizenProfile? _peerProfile;
  CitizenProfileMediaSnapshot _peerProfileMedia =
      const CitizenProfileMediaSnapshot();
  SquareSession? _profileSession;
  bool _peerProfileResolved = false;

  // 自绘输入栏的文本控制器：键盘态、表情插入和语音态切回共同持有同一草稿。
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  bool _loading = true;
  bool _attachmentBusy = false;
  bool _deleting = false;
  bool _polling = false;
  bool _realtimeConnecting = false;
  bool _appResumed = false;
  _ComposerPanel _openPanel = _ComposerPanel.none;
  _ExpressionTab _expressionTab = _ExpressionTab.emoji;
  ChatInputMode _inputMode = ChatInputMode.keyboard;
  late final VoiceRecorder _voiceRecorder;
  VoiceRecordingState _voiceState = VoiceRecordingState.idle;
  Future<void>? _voiceStartInFlight;
  String? _error;
  Timer? _pollTimer;
  Future<void> Function()? _stopRealtime;
  Future<void>? _openCoordinatorInFlight;
  int _messageReloadGeneration = 0;
  int? _renderedMessageFingerprint;
  final Map<String, String> _resolvedMediaPaths = <String, String>{};
  final Map<String, Message> _optimisticMessages = <String, Message>{};
  int _optimisticMessageSequence = 0;

  final MediaPicker _mediaPicker = MediaPicker();
  final MediaCompressor _mediaCompressor = MediaCompressor();
  final MediaProbe _mediaProbe = MediaProbe();

  @override
  void initState() {
    super.initState();
    _voiceRecorder = VoiceRecorder(onMaximumReached: _sendVoiceResult);
    _voiceRecorder.state.addListener(_onVoiceStateChanged);
    _profileApi = widget.profileApi ?? CitizenProfileApi();
    _profileCache = widget.profileCache ?? const CitizenProfileCache();
    _profileMediaCache = widget.profileMediaCache ?? CitizenProfileMediaCache();
    _sessionProvider = widget.sessionProvider ?? SquareSessionProvider.instance;
    _peerProfile = widget.initialProfile;
    _peerProfileMedia =
        widget.initialProfileMedia ?? const CitizenProfileMediaSnapshot();
    _peerProfileResolved = widget.initialProfile != null;
    CitizenProfileCache.revision.addListener(_onPeerProfileRevision);
    unawaited(_loadPeerProfile());
    _chatController = InMemoryChatController();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _lifecycleObserver = _ChatLifecycleObserver(
      onResume: () {
        _appResumed = true;
        _requestOpenCoordinate();
      },
      onPause: () {
        _appResumed = false;
        unawaited(_cancelVoiceRecording());
        _pauseSync();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    // 本地密文读取与首帧 Widget 构建可以并行启动；不再人为多等一个 post-frame。
    _requestOpenCoordinate();
  }

  /// 首次打开和 resume 共享同一个同步 future，系统生命周期抖动不得重复建立
  /// WebSocket 或重复重试本机发送队列。
  void _requestOpenCoordinate() {
    if (!mounted || !_appResumed || _openCoordinatorInFlight != null) {
      return;
    }
    late final Future<void> created;
    created = _syncOnOpen().whenComplete(() {
      if (identical(_openCoordinatorInFlight, created)) {
        _openCoordinatorInFlight = null;
      }
    });
    _openCoordinatorInFlight = created;
  }

  @override
  void dispose() {
    _messageReloadGeneration += 1;
    CitizenProfileCache.revision.removeListener(_onPeerProfileRevision);
    _pauseSync();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _chatController.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _voiceRecorder.state.removeListener(_onVoiceStateChanged);
    unawaited(_voiceRecorder.dispose());
    super.dispose();
  }

  void _onVoiceStateChanged() {
    if (!mounted) return;
    setState(() => _voiceState = _voiceRecorder.state.value);
  }

  void _onPeerProfileRevision() {
    final event = CitizenProfileCache.revision.value;
    if (!mounted || event?.cidNumber != widget.peerUserId) return;
    unawaited(_readPeerProfileCache());
  }

  Future<void> _readPeerProfileCache() async {
    if (widget.isGroup || widget.peerUserId.trim().isEmpty) return;
    final cached = await _profileCache.read(widget.peerUserId);
    if (cached == null) return;
    final media = await _profileMediaCache.read(cached);
    if (!mounted) return;
    setState(() {
      _peerProfile = cached;
      _peerProfileMedia = media;
      _peerProfileResolved = true;
    });
  }

  /// Chat 只按 CID 联合读取 User 公开资料，不把头像或会员字段写入 ChatIsar。
  Future<void> _loadPeerProfile() async {
    if (widget.isGroup || widget.peerUserId.trim().isEmpty) return;
    if (_peerProfile == null) {
      await _readPeerProfileCache();
    } else if (_peerProfileMedia.avatarPath == null) {
      final media = await _profileMediaCache.read(_peerProfile!);
      if (mounted) setState(() => _peerProfileMedia = media);
    }
    SquareSession? session;
    try {
      session = await _sessionProvider.ensureSession();
      final profile = await _profileApi.fetchProfile(
        widget.peerUserId,
        session: session,
      );
      final localMedia = await _profileMediaCache.read(profile);
      if (!mounted) return;
      setState(() {
        _peerProfile = profile;
        _peerProfileMedia = localMedia;
        _peerProfileResolved = true;
        _profileSession = session;
      });
      await _profileCache.write(profile);
      final avatarKey = profile.avatarObjectKey?.trim();
      if (avatarKey == null || avatarKey.isEmpty || session == null) return;
      final refreshed = await _profileMediaCache.refresh(
        profile: profile,
        avatarUrl: _profileApi.mediaUrl(
          avatarKey,
          updatedAt: profile.updatedAt,
        ),
        bannerUrl: null,
        headers: <String, String>{
          'authorization': 'Bearer ${session.sessionToken}',
        },
      );
      if (mounted && _peerProfile?.updatedAt == profile.updatedAt) {
        setState(() => _peerProfileMedia = refreshed);
      }
    } on Exception {
      // 会话与消息仍可用；公开资料失败保留缓存或中性占位，不回退伪造默认资料。
    }
  }

  Future<void> _reloadMessages() async {
    final generation = ++_messageReloadGeneration;
    try {
      final batch = await widget.store.readMessagesForDisplay(
        ownerCidNumber: widget.ownerCidNumber,
        currentAccountId: widget.accountId,
        conversationId: widget.conversationId,
      );
      if (!mounted || generation != _messageReloadGeneration) return;
      final messages = batch.messages;
      final fingerprint = Object.hashAll(messages.map(
        (message) => Object.hash(
          message.envelopeId,
          message.direction,
          message.messageKind,
          message.deliveryState,
          message.createdAtMillis,
          message.plaintext,
        ),
      ));
      // 心跳轮询只在真实快照变化时替换控制器，禁止每 8/20/30 秒把相同消息
      // 清空后重建，造成聊天内容短暂消失或滚动位置抖动。
      if (_renderedMessageFingerprint != fingerprint) {
        await _chatController.setMessages(
          _visibleMessages(messages),
          animated: false,
        );
        if (!mounted || generation != _messageReloadGeneration) return;
        _renderedMessageFingerprint = fingerprint;
      }
      // 正文解密完成就提交首屏；媒体缓存路径随后批量解析并原位更新，不能反向
      // 阻塞文字记录、输入栏或本地加载状态。
      unawaited(_resolveAndApplyMediaPaths(messages, generation));
      _commitReloadState(
        generation,
        batch.integrityFailureCount == 0
            ? null
            : '部分本机历史消息完整性校验失败，损坏记录已隔离',
      );
    } catch (error) {
      _commitReloadState(generation, chatUserErrorMessage(error));
    }
  }

  void _commitReloadState(int generation, String? nextError) {
    if (!mounted || generation != _messageReloadGeneration) return;
    if (!_loading && _error == nextError) return;
    setState(() {
      _loading = false;
      _error = nextError;
    });
  }

  /// 预解析媒体消息在本机缓存中的绝对路径,按 attachment_id 建表。字节未到达
  /// (对方离线/仍在传输)的媒体不入表,由渲染层显示占位。
  Future<void> _resolveAndApplyMediaPaths(
    List<ChatStoredMessage> messages,
    int generation,
  ) async {
    final resolver = widget.onResolveMediaPaths;
    if (resolver == null) return;
    try {
      final contents = <ChatContent>[];
      for (final message in messages) {
        final content = ChatPayloadCodec.decode(message.plaintext ?? '');
        final attachmentId = content.attachmentId ?? '';
        if (!content.isMedia || attachmentId.isEmpty) {
          continue;
        }
        // 门④对应:声明超限的媒体已在字节层拒收、UI 显"已拒收",不解析路径。
        if (ChatMediaLimits.exceedsForKind(
          content.kind,
          content.byteSize ?? 0,
        )) {
          continue;
        }
        if (!_resolvedMediaPaths.containsKey(attachmentId)) {
          contents.add(content);
        }
      }
      if (contents.isEmpty) return;
      final paths = await resolver(widget.conversationId, contents);
      if (!mounted || generation != _messageReloadGeneration || paths.isEmpty) {
        return;
      }
      _resolvedMediaPaths.addAll(paths);
      await _chatController.setMessages(
        _visibleMessages(messages),
        animated: false,
      );
    } catch (_) {
      // 媒体缓存仍未到达或本机短命明文已清理时继续显示占位；它不属于正文首读失败。
    }
  }

  Future<void> _syncOnOpen() async {
    // 会话首帧先读取本地消息；网络重试随后进行，离线或慢网不得挡住聊天页面。
    await _reloadMessages();
    if (!mounted || widget.onSync == null) return;

    // 当前会话队列重试与 Realtime 建连都在本地首屏之后静默并行；重试只改变
    // 可靠投递内部状态，UI 不展示该状态，因此禁止再次完整解密全部消息。
    final realtimeFuture = _startRealtime();
    await _syncOnly(silent: true);
    final realtimeReady = await realtimeFuture;
    if (!realtimeReady && mounted && widget.onSync != null) {
      _schedulePoll(_normalPollInterval);
    }
  }

  Future<bool> _startRealtime() async {
    final starter = widget.onStartRealtime;
    if (!_appResumed || starter == null) {
      return false;
    }
    if (_stopRealtime != null || _realtimeConnecting) {
      return _stopRealtime != null;
    }
    _realtimeConnecting = true;
    try {
      final stop = await starter(
        // Runtime 已经把入站 envelope 或确认写入本地；通知只刷新当前会话，
        // 不在显示新消息之前再次发起网络队列重试。
        onNotice: _reloadMessages,
        onDisconnected: () async {
          // Runtime 的账户级通道会自行退避重连；本页面继续持有同一订阅 disposer，
          // 不把物理断线误当成订阅已经失效。轮询只作为重连期间的本地补发兜底。
          if (_appResumed && mounted && widget.onSync != null) {
            _schedulePoll(_backoffPollInterval);
          }
        },
      );
      if (!mounted || !_appResumed) {
        await stop?.call();
        return false;
      }
      _stopRealtime = stop;
      if (stop != null) {
        // 实时已连也保留低频心跳兜底，防止推送静默丢失导致收不到新消息。
        _schedulePoll(_heartbeatPollInterval);
      }
      return stop != null;
    } catch (_) {
      return false;
    } finally {
      _realtimeConnecting = false;
    }
  }

  Future<bool> _syncAndReload({required bool silent}) async {
    final ok = await _syncOnly(silent: silent);
    if (!ok) return false;
    await _reloadMessages();
    return true;
  }

  Future<bool> _syncOnly({required bool silent}) async {
    final sync = widget.onSync;
    if (sync == null) {
      if (!silent && mounted) {
        setState(() {
          _error = '当前会话尚未绑定同步链路';
        });
      }
      return false;
    }
    try {
      await sync();
      return true;
    } catch (error) {
      if (!silent && mounted) {
        setState(() {
          _error = chatUserErrorMessage(error);
        });
      }
      return false;
    }
  }

  void _schedulePoll(Duration delay) {
    if (!_appResumed) {
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer(delay, _runPoll);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _pauseSync() {
    _stopPolling();
    final stop = _stopRealtime;
    _stopRealtime = null;
    if (stop != null) {
      unawaited(stop());
    }
  }

  Future<void> _runPoll() async {
    if (!mounted || !_appResumed || widget.onSync == null) {
      return;
    }
    if (_polling) {
      _schedulePoll(_backoffPollInterval);
      return;
    }
    _polling = true;
    final ok = await _syncAndReload(silent: true);
    _polling = false;
    if (!mounted || !_appResumed || widget.onSync == null) {
      return;
    }
    // 实时在线：保留低频心跳兜底，按心跳间隔继续复查。
    if (_stopRealtime != null) {
      _schedulePoll(_heartbeatPollInterval);
      return;
    }
    // 实时离线：尝试重连；重连成功由 _startRealtime 起心跳，否则常规/退避轮询。
    if (ok && await _startRealtime()) {
      return;
    }
    _schedulePoll(ok ? _normalPollInterval : _backoffPollInterval);
  }

  /// 本地 ChatIsar 真值与尚未完成可靠落盘的短命气泡合并后一次提交。任何后台
  /// 重载都必须保留仍在发送中的气泡，不能让并发发送出现闪退或暂时消失。
  List<Message> _visibleMessages(List<ChatStoredMessage> storedMessages) {
    final messages = <Message>[
      ...storedMessagesToChatMessages(
        storedMessages,
        currentCidNumber: widget.ownerCidNumber,
        resolveLocalMediaPath: (content) =>
            _resolvedMediaPaths[content.attachmentId],
      ),
      ..._optimisticMessages.values,
    ];
    messages.sort((left, right) {
      final leftAt = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightAt = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return leftAt.compareTo(rightAt);
    });
    return messages;
  }

  String _nextOptimisticMessageId() {
    _optimisticMessageSequence += 1;
    return 'local:${widget.conversationId}:'
        '${DateTime.now().microsecondsSinceEpoch}:$_optimisticMessageSequence';
  }

  Map<String, dynamic> _optimisticMetadata(ChatMessageKind kind) =>
      <String, dynamic>{
        'conversation_id': widget.conversationId,
        'direction': 'outgoing',
        'is_mine': true,
        'message_kind': kind.name,
        'optimistic': true,
      };

  Message _optimisticTextMessage(String text) => Message.text(
        id: _nextOptimisticMessageId(),
        authorId: widget.ownerCidNumber,
        createdAt: DateTime.now().toUtc(),
        text: text,
        metadata: _optimisticMetadata(ChatMessageKind.text),
      );

  Message _optimisticStickerMessage(String packId, String stickerId) =>
      Message.custom(
        id: _nextOptimisticMessageId(),
        authorId: widget.ownerCidNumber,
        createdAt: DateTime.now().toUtc(),
        metadata: <String, dynamic>{
          ..._optimisticMetadata(ChatMessageKind.sticker),
          'pack_id': packId,
          'sticker_id': stickerId,
        },
      );

  Message _optimisticMediaMessage(ChatMediaDraft draft) {
    final id = _nextOptimisticMessageId();
    final createdAt = DateTime.now().toUtc();
    final metadata = <String, dynamic>{
      ..._optimisticMetadata(draft.kind),
      'attachment_id': id,
      'file_name': draft.fileName,
    };
    return switch (draft.kind) {
      ChatMessageKind.image => Message.image(
          id: id,
          authorId: widget.ownerCidNumber,
          createdAt: createdAt,
          source: draft.sourcePath,
          width: draft.width?.toDouble(),
          height: draft.height?.toDouble(),
          size: draft.byteSize,
          metadata: metadata,
        ),
      ChatMessageKind.video => Message.video(
          id: id,
          authorId: widget.ownerCidNumber,
          createdAt: createdAt,
          source: draft.sourcePath,
          name: draft.fileName,
          width: draft.width?.toDouble(),
          height: draft.height?.toDouble(),
          size: draft.byteSize,
          metadata: metadata,
        ),
      ChatMessageKind.audio => Message.audio(
          id: id,
          authorId: widget.ownerCidNumber,
          createdAt: createdAt,
          source: draft.sourcePath,
          duration: Duration(milliseconds: draft.durationMs ?? 0),
          size: draft.byteSize,
          metadata: metadata,
        ),
      ChatMessageKind.file => Message.file(
          id: id,
          authorId: widget.ownerCidNumber,
          createdAt: createdAt,
          source: draft.sourcePath,
          name: draft.fileName,
          size: draft.byteSize,
          mimeType: draft.contentType,
          metadata: metadata,
        ),
      ChatMessageKind.text || ChatMessageKind.sticker => throw StateError(
          '文字和贴纸不能进入媒体乐观气泡',
        ),
    };
  }

  Future<void> _insertOptimisticMessage(Message message) async {
    _optimisticMessages[message.id] = message;
    if (!mounted) return;
    // InMemoryChatController 在 Future 首次挂起前完成插入，因此点击发送的同一帧
    // 就能看到气泡；这里只保存短命 UI 对象，不写磁盘、不伪造投递状态。
    await _chatController.insertMessage(message, animated: false);
  }

  Future<void> _reconcileOptimisticMessage(String messageId) async {
    if (_optimisticMessages.remove(messageId) == null || !mounted) return;
    await _reloadMessages();
  }

  Future<void> _discardOptimisticMessage(String messageId) async {
    if (_optimisticMessages.remove(messageId) == null || !mounted) return;
    await _reloadMessages();
  }

  Future<void> _discardOptimisticMessages(Iterable<String> messageIds) async {
    var removed = false;
    for (final messageId in messageIds) {
      removed = _optimisticMessages.remove(messageId) != null || removed;
    }
    if (removed && mounted) await _reloadMessages();
  }

  Future<void> _handleSend(String text) async {
    if (!_requireChatEntitlement()) return;
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    final sender = widget.onSendText;
    if (sender == null) {
      setState(() {
        _error = '当前会话尚未绑定发送链路';
      });
      return;
    }
    final optimistic = _optimisticTextMessage(normalized);
    await _insertOptimisticMessage(optimistic);
    try {
      await sender(normalized);
      await _reconcileOptimisticMessage(optimistic.id);
    } catch (error) {
      await _discardOptimisticMessage(optimistic.id);
      if (mounted) {
        setState(() {
          _error = chatUserErrorMessage(error);
        });
      }
    }
  }

  Future<void> _sendMediaDrafts(Iterable<ChatMediaDraft> drafts) async {
    if (_attachmentBusy || !_requireChatEntitlement()) return;
    final prepared = drafts.toList(growable: false);
    for (final draft in prepared) {
      if (ChatMediaLimits.exceedsForKind(draft.kind, draft.byteSize)) {
        setState(() {
          _error = '文件超出当前会员单个附件上限（${ChatMediaLimits.currentLimitLabel}）';
        });
        return;
      }
      if (ChatMediaLimits.exceedsDurationForKind(
        draft.kind,
        draft.durationMs,
      )) {
        setState(() => _error = '语音、视频消息每条最长 3 分钟');
        return;
      }
    }
    final sender = widget.onSendMedia;
    if (sender == null) {
      setState(() {
        _error = '当前会话尚未绑定媒体发送链路';
      });
      return;
    }
    setState(() {
      _attachmentBusy = true;
      _error = null;
    });
    final pending = <({ChatMediaDraft draft, Message message})>[];
    for (final draft in prepared) {
      final message = _optimisticMediaMessage(draft);
      pending.add((draft: draft, message: message));
      await _insertOptimisticMessage(message);
    }
    try {
      for (final item in pending) {
        var reconciled = false;
        await sender(
          item.draft,
          // 媒体消息和发送方本地附件一旦安全落盘就立即刷新；不再等待云端
          // 控制消息和 WebRTC 字节确认后才让语音气泡出现。
          onLocalCommitted: () async {
            if (reconciled) return;
            reconciled = true;
            await _reconcileOptimisticMessage(item.message.id);
          },
        );
        if (!reconciled) {
          await _reconcileOptimisticMessage(item.message.id);
        }
      }
    } on ChatMediaTooLargeException {
      await _discardOptimisticMessages(
        pending.map((item) => item.message.id),
      );
      if (mounted) {
        setState(() {
          _error = '文件超出当前会员单个附件上限（${ChatMediaLimits.currentLimitLabel}）';
        });
      }
    } catch (error) {
      await _discardOptimisticMessages(
        pending.map((item) => item.message.id),
      );
      if (mounted) {
        setState(() {
          _error = chatUserErrorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _attachmentBusy = false;
        });
      }
    }
  }

  Future<void> _handleGallery() async {
    if (widget.pickMedia != null) {
      final draft = await widget.pickMedia!.call();
      if (draft != null) await _sendMediaDrafts([draft]);
      return;
    }
    final picked = await _mediaPicker.gallery(context);
    if (picked.isEmpty) return;
    final drafts = <ChatMediaDraft>[];
    for (final item in picked) {
      drafts.add(await _buildMediaDraft(item));
    }
    await _sendMediaDrafts(drafts);
  }

  Future<void> _handleCapture() async {
    final picked = await openChatCameraCapture(context);
    if (picked == null || !mounted) return;
    ChatMediaDraft? draft;
    try {
      draft = await _buildMediaDraft(picked);
      await _sendMediaDrafts([draft]);
    } finally {
      final paths = <String>{picked.path, if (draft != null) draft.sourcePath};
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<void> _handleFile() async {
    final picked = await _pickFileViaFilePicker();
    if (picked == null) return;
    await _sendMediaDrafts([await _buildMediaDraft(picked)]);
  }

  /// 发送贴纸:只把 `(packId, stickerId)` 交给发送链路(走 MLS 信封瞬时中转,
  /// 零字节、零 WebRTC)。面板保持打开以便连发,不自动关闭。
  Future<void> _handleSendSticker(String packId, String stickerId) async {
    if (!_requireChatEntitlement()) return;
    final sender = widget.onSendSticker;
    if (sender == null) {
      setState(() {
        _error = '当前会话尚未绑定发送链路';
      });
      return;
    }
    final optimistic = _optimisticStickerMessage(packId, stickerId);
    await _insertOptimisticMessage(optimistic);
    try {
      await sender(packId, stickerId);
      await _reconcileOptimisticMessage(optimistic.id);
    } catch (error) {
      await _discardOptimisticMessage(optimistic.id);
      if (mounted) {
        setState(() {
          _error = chatUserErrorMessage(error);
        });
      }
    }
  }

  /// 键盘、表情/贴纸、加号面板互斥；打开辅助面板时收起系统键盘。
  void _togglePanel(_ComposerPanel panel) {
    if (panel == _ComposerPanel.none) {
      if (_openPanel != _ComposerPanel.none) {
        setState(() => _openPanel = _ComposerPanel.none);
      }
      return;
    }
    final closingCurrentPanel = _openPanel == panel;
    setState(() {
      _openPanel = closingCurrentPanel ? _ComposerPanel.none : panel;
    });
    if (closingCurrentPanel) {
      _requestComposerKeyboard();
    } else {
      _composerFocusNode.unfocus();
    }
  }

  /// 表情/动作面板打开时点文本框，必须先拆掉辅助面板再显示键盘，
  /// 禁止两块输入区同时占用屏幕。
  void _handleTextInputTap() {
    if (_openPanel == _ComposerPanel.none) return;
    setState(() => _openPanel = _ComposerPanel.none);
    _requestComposerKeyboard();
  }

  void _requestComposerKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _inputMode != ChatInputMode.keyboard) return;
      _composerFocusNode.requestFocus();
    });
  }

  void _toggleInputMode() {
    unawaited(_cancelVoiceRecording());
    setState(() {
      _inputMode = _inputMode == ChatInputMode.keyboard
          ? ChatInputMode.voice
          : ChatInputMode.keyboard;
      _openPanel = _ComposerPanel.none;
    });
    if (_inputMode == ChatInputMode.voice) {
      _composerFocusNode.unfocus();
    } else {
      _composerFocusNode.requestFocus();
    }
  }

  Future<ChatMediaDraft> _buildMediaDraft(PickedMediaFile picked) async {
    // 压缩门控:图超限压一次仍超则抛;视频/文件超限抛(采集侧,门①上游)。
    final finalPath = await _mediaCompressor.ensureWithinLimit(
      path: picked.path,
      kind: picked.kind,
    );
    final probe = await _mediaProbe.probe(path: finalPath, kind: picked.kind);
    final byteSize = await File(finalPath).length();
    if (ChatMediaLimits.exceedsDurationForKind(
      picked.kind,
      probe.durationMs,
    )) {
      throw ChatMediaTooLongException(
        kind: picked.kind,
        durationMs: probe.durationMs ?? 0,
      );
    }
    return ChatMediaDraft(
      kind: picked.kind,
      fileName: picked.fileName,
      contentType: picked.mime,
      sourcePath: finalPath,
      byteSize: byteSize,
      width: probe.width,
      height: probe.height,
      durationMs: probe.durationMs,
      blurhash: probe.blurhash,
    );
  }

  Future<void> _handleComposerAction(ChatComposerAction action) async {
    if (!_requireChatEntitlement()) return;
    _togglePanel(_ComposerPanel.none);
    try {
      switch (action) {
        case ChatComposerAction.gallery:
          await _handleGallery();
        case ChatComposerAction.capture:
          await _handleCapture();
        case ChatComposerAction.file:
          await _handleFile();
        case ChatComposerAction.transfer:
          await _openTransfer();
        case ChatComposerAction.videoCall:
          await _startCall(video: true);
        case ChatComposerAction.voiceCall:
          await _startCall(video: false);
        case ChatComposerAction.location:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('功能完善中，敬请期待')),
          );
      }
    } on ChatMediaTooLargeException {
      if (mounted) {
        setState(() {
          _error = '文件超出当前会员单个附件上限（${ChatMediaLimits.currentLimitLabel}）';
        });
      }
    } on ChatMediaTooLongException {
      if (mounted) setState(() => _error = '语音、视频消息每条最长 3 分钟');
    } catch (error) {
      if (mounted) setState(() => _error = chatUserErrorMessage(error));
    }
  }

  Future<void> _startCall({required bool video}) async {
    final starter = widget.onStartCall;
    if (starter == null) {
      if (mounted) setState(() => _error = '通话链路尚未就绪');
      return;
    }
    await starter(video: video);
  }

  Future<void> _openTransfer() async {
    if (widget.isGroup || _attachmentBusy) return;
    setState(() {
      _attachmentBusy = true;
      _error = null;
    });
    try {
      final String ss58Address;
      if (widget.resolvePeerAddress != null) {
        ss58Address = await widget.resolvePeerAddress!(widget.peerUserId);
      } else {
        final binding = await CitizenIdentityChainReader()
            .readBindingByCidNumber(widget.peerUserId);
        if (binding == null) {
          throw StateError('对方 CID 当前没有有效钱包绑定');
        }
        ss58Address = ss58FromAccountIdText(binding.accountIdText);
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OnchainPaymentPage(initialToAddress: ss58Address),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = chatUserErrorMessage(error));
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _startVoiceRecording() async {
    if (!_requireChatEntitlement() ||
        _voiceStartInFlight != null ||
        _voiceState.recording) {
      return;
    }
    late final Future<void> created;
    created = _voiceRecorder.start();
    _voiceStartInFlight = created;
    try {
      await created;
    } catch (error) {
      if (mounted) setState(() => _error = chatUserErrorMessage(error));
    } finally {
      if (identical(_voiceStartInFlight, created)) {
        _voiceStartInFlight = null;
      }
    }
  }

  Future<void> _finishVoiceRecording(bool cancel) async {
    try {
      final starting = _voiceStartInFlight;
      if (starting != null) await starting;
      final result = await _voiceRecorder.stop(cancel: cancel);
      if (result == null) return;
      if (result.duration < const Duration(milliseconds: 800)) {
        await File(result.path).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('说话时间太短')),
          );
        }
        return;
      }
      await _sendVoiceResult(result);
    } catch (error) {
      if (mounted) setState(() => _error = chatUserErrorMessage(error));
    }
  }

  Future<void> _cancelVoiceRecording() async {
    try {
      final starting = _voiceStartInFlight;
      if (starting != null) await starting;
      await _voiceRecorder.cancel();
    } catch (_) {
      // 页面切态、退后台与销毁只能静默取消，不把生命周期错误写回已离开的页面。
    }
  }

  Future<void> _sendVoiceResult(VoiceRecordingResult result) async {
    final file = File(result.path);
    try {
      final byteSize = await file.length();
      await _sendMediaDrafts([
        ChatMediaDraft(
          kind: ChatMessageKind.audio,
          fileName: result.path.split(Platform.pathSeparator).last,
          contentType: 'audio/mp4',
          sourcePath: result.path,
          byteSize: byteSize,
          durationMs: result.duration.inMilliseconds.clamp(
            1,
            ChatMediaLimits.messageMaximumDuration.inMilliseconds,
          ),
        ),
      ]);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// 通用文件(非图非视频)走 file_picker,取路径不载入字节。
  Future<PickedMediaFile?> _pickFileViaFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      throw StateError('无法读取所选文件');
    }
    final mime = mimeFromFileName(file.name);
    return PickedMediaFile(
      path: path,
      fileName: file.name,
      mime: mime,
      kind: mediaKindFromMime(mime),
    );
  }

  /// 把已收到的媒体从本机缓存另存并提示。控制载荷来自消息 metadata。
  Future<void> _downloadMedia(String controlPlaintext) async {
    if (_attachmentBusy) return;
    if (controlPlaintext.isEmpty) {
      setState(() {
        _error = '媒体控制消息为空，无法保存';
      });
      return;
    }
    final downloader = widget.onDownloadAttachment;
    if (downloader == null) {
      setState(() {
        _error = '当前会话尚未绑定媒体下载链路';
      });
      return;
    }
    setState(() {
      _attachmentBusy = true;
      _error = null;
    });
    try {
      final downloaded = await downloader(
        widget.conversationId,
        controlPlaintext,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已保存：${downloaded.fileName}')));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = chatUserErrorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _attachmentBusy = false;
        });
      }
    }
  }

  Future<void> _handleDeleteConversation() async {
    final confirmed = await _confirmDeleteConversation(context);
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      _pauseSync();
      final deleter = widget.onDeleteConversation;
      if (deleter == null) {
        throw StateError('聊天会话删除必须由 ChatRuntime 协调执行');
      }
      // 删除确认是用户可见边界：先启动后台物理清理，当前路由同一帧退出，
      // 绝不能等待 CID lease、待发送队列、网络超时或附件目录删除。
      final deletion = deleter();
      if (Navigator.of(context).canPop()) {
        // ChatPage 的正式路由类型是 void；禁止传 bool 结果，否则运行时会因
        // `bool` 不能作为 `void` 路由结果而拒绝出栈。
        Navigator.of(context).pop();
      } else {
        await _chatController.setMessages(const [], animated: false);
        setState(() {
          _deleting = false;
        });
      }
      // 页面退出后 Future 仍由 Runtime/上级 Chat Tab 持有并完成；异常由
      // 调用方更新列表错误态，这里只防止已销毁页面产生未处理异步异常。
      unawaited(deletion.catchError((Object _) {}));
    } catch (error) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = chatUserErrorMessage(error);
        });
      }
    }
  }

  Future<void> _openPeerProfile() async {
    // Chat 路由主键本来就是对端 CID，普通打开主页不得再把它当成
    // account_id 去读 finalized 链。主页资料直接由 Cloudflare 持久用户提供。
    final cidNumber = widget.peerUserId.trim();
    if (cidNumber.isEmpty || widget.isGroup) return;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          cidNumber: cidNumber,
          isSelf: false,
          initialProfile: _peerProfile,
          initialProfileMedia: _peerProfileMedia,
        ),
      ),
    );
  }

  // 群聊文本:入站消息在气泡上方显示发送者名(连续同发送者只在首条显示)。
  // 复用 flyer 默认气泡 SimpleTextMessage 的 topWidget 挂 Username(经 resolveUser 解析)。
  Widget _buildGroupTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final showSender = !isSentByMe && (groupStatus?.isFirst ?? true);
    return SimpleTextMessage(
      message: message,
      index: index,
      topWidget: showSender ? Username(userId: message.authorId) : null,
    );
  }

  // 图片消息:blurhash 占位(字节未到)→ 本机图(点开全屏可缩放/存相册)。
  // 内联图按显示宽度 cacheWidth 降采样解码,100MB 图也不整解码。
  Widget _buildImageMessage(
    BuildContext context,
    ImageMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.62;
    final hasFile = message.source.isNotEmpty;
    final ratio = _mediaAspectRatio(message.width, message.height);
    final cacheWidth =
        (maxWidth * MediaQuery.of(context).devicePixelRatio).round();
    final Widget content = hasFile
        ? GestureDetector(
            onTap: () => _openImageViewer(message),
            child: Image.file(
              File(message.source),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (_, __, ___) => _mediaPlaceholder(
                icon: Icons.broken_image_rounded,
                label: '图片无法显示',
              ),
            ),
          )
        : _blurhashOrPlaceholder(message.blurhash, '接收中…');
    return _mediaAligned(
      isSentByMe,
      ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(14)),
        child: SizedBox(
          width: maxWidth,
          child: AspectRatio(aspectRatio: ratio, child: content),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  // 视频消息:blurhash 封面 + 播放图标;字节就绪点开播放页(可存相册)。
  Widget _buildVideoMessage(
    BuildContext context,
    VideoMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.62;
    final hasFile = message.source.isNotEmpty;
    final hash = message.metadata?['blurhash']?.toString();
    final ratio = _mediaAspectRatio(message.width, message.height);
    return _mediaAligned(
      isSentByMe,
      GestureDetector(
        onTap: hasFile ? () => _openVideoPlayer(message) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(14)),
          child: SizedBox(
            width: maxWidth,
            child: AspectRatio(
              aspectRatio: ratio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (hash != null && hash.isNotEmpty)
                      ? BlurHash(hash: hash, imageFit: BoxFit.cover)
                      : Container(color: AppTheme.surfaceCard),
                  Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: AppLayout.scaled(context, 44),
                      color: Colors.white70,
                    ),
                  ),
                  if (!hasFile)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppLayout.scaled(context, 8),
                      child: Text(
                        '接收中…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  double _mediaAspectRatio(double? width, double? height) {
    if (width != null && height != null && width > 0 && height > 0) {
      return (width / height).clamp(0.6, 1.9);
    }
    return 1.0;
  }

  Widget _blurhashOrPlaceholder(String? hash, String label) {
    if (hash != null && hash.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          BlurHash(hash: hash, imageFit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppLayout.scaledValue(8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(12),
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    return _mediaPlaceholder(icon: Icons.image_rounded, label: label);
  }

  void _openImageViewer(ImageMessage message) {
    final fileName = message.metadata?['file_name']?.toString() ?? '图片';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImageViewerPage(filePath: message.source, fileName: fileName),
      ),
    );
  }

  void _openVideoPlayer(VideoMessage message) {
    final fileName =
        message.metadata?['file_name']?.toString() ?? message.name ?? '视频';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            VideoPlayerPage(filePath: message.source, fileName: fileName),
      ),
    );
  }

  // 文件消息:文件条 + 点按另存。
  Widget _buildFileMessage(
    BuildContext context,
    FileMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    return _mediaAligned(
      isSentByMe,
      GestureDetector(
        onTap: () => unawaited(_downloadMedia(control)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 14),
            vertical: AppLayout.scaled(context, 12),
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: AppLayout.scaled(context, 28),
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: AppLayout.scaled(context, 10)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (message.size != null)
                      Text(
                        _formatByteSize(message.size!),
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 11),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildAudioMessage(
    BuildContext context,
    AudioMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    return _mediaAligned(
      isSentByMe,
      VoiceMessagePlayer(
        message: message,
        isSentByMe: isSentByMe,
        onRequestDownload: () async {
          await _downloadMedia(control);
          await _reloadMessages();
        },
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _mediaAligned(
    bool isSentByMe,
    Widget child, {
    String? senderId,
    MessageGroupStatus? groupStatus,
  }) {
    final aligned = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(12),
        vertical: AppLayout.scaledValue(4),
      ),
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    // 群聊入站媒体/贴纸在气泡上方显示发送者名(连续同发送者只首条),与文本一致。
    final showSender = widget.isGroup &&
        !isSentByMe &&
        senderId != null &&
        (groupStatus?.isFirst ?? true);
    if (!showSender) return aligned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: AppLayout.scaledValue(16),
            top: AppLayout.scaledValue(4),
          ),
          child: Username(
            userId: senderId,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(11),
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        aligned,
      ],
    );
  }

  Widget _mediaPlaceholder({required IconData icon, required String label}) {
    return Container(
      color: AppTheme.surfaceCard,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppTheme.textSecondary,
            size: AppLayout.scaledValue(28),
          ),
          SizedBox(height: AppLayout.scaledValue(6)),
          Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(12),
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static const double _stickerRenderSize = 128;

  /// 贴纸消息:按 `(packId, stickerId)` 渲染内置 Fluent 3D PNG,无气泡大图。
  /// id 未内置(对端资产旧/缺)或解码失败时降级为占位,绝不崩。
  Widget _buildStickerMessage(
    BuildContext context,
    CustomMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final packId = message.metadata?['pack_id']?.toString() ?? '';
    final stickerId = message.metadata?['sticker_id']?.toString() ?? '';
    final known = StickerPack.isKnown(packId: packId, stickerId: stickerId);
    final Widget content = known
        ? Image.asset(
            StickerPack.assetPath(stickerId),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _stickerFallback(),
          )
        : _stickerFallback();
    return _mediaAligned(
      isSentByMe,
      SizedBox(
        key: ValueKey('chat-sticker-message-${message.id}'),
        width: _stickerRenderSize,
        height: _stickerRenderSize,
        child: content,
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _stickerFallback() =>
      _mediaPlaceholder(icon: Icons.emoji_emotions_outlined, label: '[贴纸]');

  /// 统一输入栏：键盘/语音两态，共用表达面板与 4+3 动作面板。
  Widget _buildComposer(BuildContext context) {
    if (!ChatMediaLimits.chatEnabledFor(widget.ownerCidNumber)) {
      final resolved =
          ChatMediaLimits.resolvedFor(widget.ownerCidNumber);
      return Container(
        key: const ValueKey('chat-membership-required'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaled(context, 16),
          vertical: AppLayout.scaled(context, 14),
        ),
        color: AppTheme.surfaceCard,
        child: Text(
          resolved
              ? '尚未开通会员，订阅任一会员后即可使用聊天'
              : '暂时无法验证会员状态，请稍后重试',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppLayout.scaled(context, 13),
          ),
        ),
      );
    }
    final Widget? panel = switch (_openPanel) {
      _ComposerPanel.none => null,
      _ComposerPanel.expression => _buildExpressionPanel(context),
      _ComposerPanel.actions => ComposerActionPanel(
          isGroup: widget.isGroup,
          onAction: (action) => unawaited(_handleComposerAction(action)),
        ),
    };
    return ComposerBar(
      controller: _composerController,
      focusNode: _composerFocusNode,
      inputMode: _inputMode,
      expressionOpen: _openPanel == _ComposerPanel.expression,
      actionsOpen: _openPanel == _ComposerPanel.actions,
      recording: _voiceState.recording,
      recordingDuration: _voiceState.duration,
      onToggleInputMode: _toggleInputMode,
      onToggleExpression: () => _togglePanel(_ComposerPanel.expression),
      onToggleActions: () => _togglePanel(_ComposerPanel.actions),
      onTextInputTap: _handleTextInputTap,
      onSendText: (text) => unawaited(_handleSend(text)),
      onVoicePressStart: () => unawaited(_startVoiceRecording()),
      onVoicePressEnd: (cancel) => unawaited(_finishVoiceRecording(cancel)),
      panel: panel,
    );
  }

  bool _requireChatEntitlement() {
    if (ChatMediaLimits.chatEnabledFor(widget.ownerCidNumber)) return true;
    if (mounted) {
      setState(() {
        _error = ChatMediaLimits.resolvedFor(widget.ownerCidNumber)
            ? '尚未开通会员，订阅任一会员后即可使用聊天'
            : '暂时无法验证会员状态，请稍后重试';
      });
    }
    return false;
  }

  Widget _buildExpressionPanel(BuildContext context) {
    final height = math.min(304.0, MediaQuery.sizeOf(context).height * 0.44);
    return SizedBox(
      key: const ValueKey('chat-expression-panel'),
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: AppLayout.scaled(context, 42),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _expressionTabButton(_ExpressionTab.emoji, '表情'),
                SizedBox(width: AppLayout.scaled(context, 18)),
                _expressionTabButton(_ExpressionTab.sticker, '贴纸'),
              ],
            ),
          ),
          Expanded(
            child: _expressionTab == _ExpressionTab.emoji
                ? Column(
                    children: [
                      Expanded(
                        child: EmojiPicker(
                          textEditingController: _composerController,
                          config: Config(
                            height: height - AppLayout.scaled(context, 42 + 48),
                            checkPlatformCompatibility: true,
                            emojiViewConfig: const EmojiViewConfig(
                              columns: 8,
                              backgroundColor: AppTheme.surfaceCard,
                            ),
                            categoryViewConfig: const CategoryViewConfig(
                              backgroundColor: AppTheme.surfaceCard,
                              indicatorColor: AppTheme.accent,
                              iconColorSelected: AppTheme.accent,
                              backspaceColor: AppTheme.accent,
                            ),
                            // 底部操作由 Chat 自己绘制，不再使用三方
                            // 默认的“左空、右删除”布局。
                            bottomActionBarConfig:
                                const BottomActionBarConfig(enabled: false),
                          ),
                        ),
                      ),
                      _buildEmojiBottomActionBar(context),
                    ],
                  )
                : StickerPanel(
                    height: height - AppLayout.scaled(context, 42),
                    onPick: (packId, stickerId) =>
                        unawaited(_handleSendSticker(packId, stickerId)),
                  ),
          ),
        ],
      ),
    );
  }

  /// 表情面板底部操作栏：删除固定在左，发送固定在右。发送直接走文本
  /// 消息链路，不为发送再弹出系统键盘。
  Widget _buildEmojiBottomActionBar(BuildContext context) {
    return SizedBox(
      height: AppLayout.scaled(context, 48),
      child: ColoredBox(
        color: AppTheme.surfaceCard,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BackspaceButton(
              key: const ValueKey('chat-emoji-backspace'),
              const Config(),
              _deleteComposerCharacter,
              _deleteComposerWord,
              AppTheme.textSecondary,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _composerController,
              builder: (context, value, child) {
                final canSend = value.text.trim().isNotEmpty;
                return IconButton(
                  key: const ValueKey('chat-emoji-send'),
                  tooltip: '发送',
                  color: AppTheme.accent,
                  disabledColor: AppTheme.textTertiary,
                  onPressed: canSend ? _sendComposerDraft : null,
                  icon: const Icon(Icons.send_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteComposerCharacter() => _deleteComposerText(deleteWord: false);

  void _deleteComposerWord() => _deleteComposerText(deleteWord: true);

  /// 按照光标/选区删除；单次删除以 Unicode 字素为单位，不会把组合
  /// emoji 截成半个无效字符。
  void _deleteComposerText({required bool deleteWord}) {
    final value = _composerController.value;
    final text = value.text;
    if (text.isEmpty) return;
    final selection = value.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final start = hasSelection
        ? math.min(selection.start, selection.end)
        : (selection.isValid ? selection.extentOffset : text.length)
            .clamp(0, text.length);
    final end = hasSelection ? math.max(selection.start, selection.end) : start;
    if (hasSelection) {
      final next = text.replaceRange(start, end, '');
      _composerController.value = value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      return;
    }
    if (start == 0) return;
    final before = text.substring(0, start);
    final retained = deleteWord
        ? before.replaceFirst(RegExp(r'(?:\s+|\S+\s*)$'), '')
        : before.characters.skipLast(1).toString();
    final next = '$retained${text.substring(start)}';
    _composerController.value = value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: retained.length),
      composing: TextRange.empty,
    );
  }

  void _sendComposerDraft() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    _composerController.clear();
    unawaited(_handleSend(text));
  }

  Widget _expressionTabButton(_ExpressionTab tab, String label) {
    final selected = _expressionTab == tab;
    return TextButton(
      key: ValueKey('chat-expression-${tab.name}'),
      onPressed: () => setState(() => _expressionTab = tab),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.accent : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peerName = ProfilePresentation.forIdentityKey(
      widget.peerUserId,
    ).resolveDisplayName(
      publicName: _peerProfile?.displayName ?? widget.title,
    );
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: InkWell(
          key: const ValueKey('chat-peer-profile-entry'),
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
          onTap: widget.isGroup ? null : _openPeerProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                seed: widget.peerUserId,
                size: AppLayout.scaled(context, 36),
                imagePath: _peerProfileMedia.avatarPath,
                imageUrl:
                    _peerProfile?.avatarObjectKey?.trim().isNotEmpty == true
                        ? _profileApi.mediaUrl(
                            _peerProfile!.avatarObjectKey!,
                            updatedAt: _peerProfile!.updatedAt,
                          )
                        : null,
                imageHeaders: _profileSession == null
                    ? null
                    : <String, String>{
                        'authorization':
                            'Bearer ${_profileSession!.sessionToken}',
                      },
                userImageSet: _peerProfileResolved
                    ? _peerProfile?.avatarObjectKey?.trim().isNotEmpty == true
                    : true,
                identityLevel: _peerProfile?.identityLevel,
                membershipLevel: _peerProfile?.membershipLevel,
                membershipActive: _peerProfile?.membershipActive ?? false,
                showBadge: _peerProfileResolved,
              ),
              SizedBox(width: AppLayout.scaled(context, 9)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 17),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _shortAccount(widget.peerUserId),
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 12),
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<_ChatMenuAction>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert_rounded),
            enabled: !_deleting,
            onSelected: (action) {
              switch (action) {
                case _ChatMenuAction.deleteConversation:
                  unawaited(_handleDeleteConversation());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ChatMenuAction.deleteConversation,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: AppLayout.scaled(context, 18),
                    ),
                    SizedBox(width: AppLayout.scaled(context, 10)),
                    const Text('删除聊天记录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 固定占位避免状态线消失时消息区跳动；该线只表示首次本地消息读取，
          // 静默补发、附件和删除动作不得长期占用页面级加载状态。
          SizedBox(
            height: AppLayout.scaled(context, 2),
            child: _loading
                ? const LinearProgressIndicator(
                    key: ValueKey('chat-page-progress'),
                  )
                : null,
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.scaled(context, 16),
                vertical: AppLayout.scaled(context, 10),
              ),
              color: Colors.red.withAlpha(20),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: AppLayout.scaled(context, 12),
                ),
              ),
            ),
          Expanded(
            child: Chat(
              currentUserId: widget.ownerCidNumber,
              chatController: _chatController,
              onMessageSend: _handleSend,
              backgroundColor: AppTheme.scaffoldBg,
              builders: Builders(
                textMessageBuilder:
                    widget.isGroup ? _buildGroupTextMessage : null,
                imageMessageBuilder: _buildImageMessage,
                videoMessageBuilder: _buildVideoMessage,
                fileMessageBuilder: _buildFileMessage,
                audioMessageBuilder: _buildAudioMessage,
                customMessageBuilder: _buildStickerMessage,
                composerBuilder: _buildComposer,
                // 本地记录尚未读完时禁止闪现组件默认英文空态；
                // 只有首读确认为空后才显示中文真空态。
                emptyChatListBuilder: (context) => _loading
                    ? const SizedBox.shrink()
                    : const Padding(
                        padding: EdgeInsets.only(bottom: 120),
                        child: Center(child: Text('暂无消息')),
                      ),
              ),
              resolveUser: (id) async {
                final isMe = id == widget.ownerCidNumber;
                return User(
                  id: id,
                  name: isMe
                      ? '我'
                      : widget.isGroup
                          ? ProfilePresentation.forIdentityKey(id).fallbackName
                          : peerName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

enum _ChatMenuAction { deleteConversation }

/// 系统键盘、表达面板和动作面板互斥。
enum _ComposerPanel { none, expression, actions }

enum _ExpressionTab { emoji, sticker }

Future<bool> _confirmDeleteConversation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除聊天记录'),
      content: const Text('确定删除这台设备上的聊天记录？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _ChatLifecycleObserver extends WidgetsBindingObserver {
  _ChatLifecycleObserver({required this.onResume, required this.onPause});

  final VoidCallback onResume;
  final VoidCallback onPause;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    } else {
      onPause();
    }
  }
}

String _shortAccount(String value) {
  if (value.length <= 16) {
    return value;
  }
  return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
}
