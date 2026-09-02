import 'dart:async';
import 'dart:io';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'chat_product_policy.dart';
import 'package:citizenapp/8964/profile/models/citizen_profile.dart';
import 'package:citizenapp/8964/profile/models/profile_presentation.dart';
import 'package:citizenapp/8964/profile/services/citizen_profile_api.dart';
import 'package:citizenapp/8964/profile/services/citizen_profile_cache.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/8964/profile/user_profile_page.dart';
import 'package:citizenapp/8964/profile/widgets/profile_avatar.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/chat/tatachat_sdk_adapter.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/my/membership/membership_revision.dart';
import 'package:citizenapp/my/membership/subscription_service.dart';
import 'package:citizenapp/my/myid/citizen_identity_chain_reader.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';
import 'package:citizenapp/my/myid/register_identity_flow.dart';
import 'package:citizenapp/my/user/contact_book_page.dart';
import 'package:citizenapp/my/user/contact_service.dart';
import 'package:citizenapp/qr/scan_dispatch_flow.dart';
import 'package:citizenapp/transaction/onchain-transaction/onchain_payment_page.dart';
import 'package:citizenapp/ui/app_layout.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/widgets/identity_register_guide.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/wallet/widgets/wallet_qr_dialog.dart';
import 'package:file_picker/file_picker.dart';

typedef ChatPickMediaCallback = Future<ChatMediaDraft?> Function();
typedef CitizenChatDownloadAttachmentCallback = Future<ChatDownloadedAttachment>
    Function(
  String conversationId,
  String controlPlaintext,
);
typedef CitizenChatResolveMediaPathsCallback = Future<Map<String, String>>
    Function(
  String conversationId,
  List<ChatContent> contents,
);
typedef ChatDeleteConversationCallback = Future<void> Function();
typedef ChatResolvePeerAddressCallback = Future<String> Function(
    String peerUserId);

/// 公民 Chat 聊天详情页。
///
/// 页面只使用现成聊天 UI 展示和输入，消息真源仍是本地
/// [ChatStore]，发送和同步由上层注入的 P2P/MLS 状态机完成。
class ChatPage extends StatefulWidget {
  ChatPage({
    super.key,
    required this.conversationId,
    required this.ownerUserId,
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
    this.onMarkRead,
    this.resolvePeerAddress,
    this.initialProfile,
    this.initialProfileMedia,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
  }) : store = store ?? ChatStore();

  final String conversationId;
  final String ownerUserId;
  final String accountId;
  final String peerUserId;
  final String title;

  /// 群聊模式:入站消息按各自 `senderUserId` 归属并在气泡上方显示发送者名。
  final bool isGroup;
  final ChatStore store;
  final ChatSendTextCallback? onSendText;
  final ChatSendMediaCallback? onSendMedia;
  final ChatSendStickerCallback? onSendSticker;
  final CitizenChatDownloadAttachmentCallback? onDownloadAttachment;
  final CitizenChatResolveMediaPathsCallback? onResolveMediaPaths;
  final ChatPickMediaCallback? pickMedia;
  final ChatSyncCallback? onSync;
  final ChatStartRealtimeCallback? onStartRealtime;
  final ChatDeleteConversationCallback? onDeleteConversation;
  final ChatMarkReadCallback? onMarkRead;
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
  late final ChatConversationController _conversationController;
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
  bool _deleting = false;
  bool _productActionBusy = false;
  ChatComposerPanel _openPanel = ChatComposerPanel.none;
  ChatExpressionTab _expressionTab = ChatExpressionTab.emoji;
  ChatInputMode _inputMode = ChatInputMode.keyboard;
  late final VoiceRecorder _voiceRecorder;
  VoiceRecordingState _voiceState = VoiceRecordingState.idle;
  Future<void>? _voiceStartInFlight;
  String? _productError;

  final MediaPicker _mediaPicker = MediaPicker();
  final MediaCompressor _mediaCompressor = MediaCompressor(
    limitForKind: ChatMediaLimits.forKind,
  );
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
    _conversationController = ChatConversationController(
      conversationId: widget.conversationId,
      currentUserId: widget.ownerUserId,
      loadSnapshot: () async {
        final batch = await widget.store.readMessagesForDisplay(
          ownerUserId: widget.ownerUserId,
          currentAccountId: widget.accountId,
          conversationId: widget.conversationId,
        );
        return (
          messages: batch.messages,
          integrityFailureCount: batch.integrityFailureCount,
        );
      },
      onSendText: widget.onSendText,
      onSendMedia: widget.onSendMedia,
      onSendSticker: widget.onSendSticker,
      onSync: widget.onSync,
      onStartRealtime: widget.onStartRealtime,
      onDownloadAttachment: widget.onDownloadAttachment == null
          ? null
          : (controlPlaintext) => widget.onDownloadAttachment!(
                widget.conversationId,
                controlPlaintext,
              ),
      onResolveMediaPaths: widget.onResolveMediaPaths == null
          ? null
          : (contents) =>
              widget.onResolveMediaPaths!(widget.conversationId, contents),
      onMarkRead: widget.onMarkRead,
      isVisible: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      onPause: _cancelVoiceRecording,
      mediaLimits: const CitizenChatMediaLimitPolicy(),
      errorMessage: chatUserErrorMessage,
    );
    _conversationController.addListener(_onConversationControllerChanged);
    _conversationController.start();
  }

  /// 首次打开和 resume 共享同一个同步 future，系统生命周期抖动不得重复建立
  /// WebSocket 或重复重试本机发送队列。
  void _onConversationControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CitizenProfileCache.revision.removeListener(_onPeerProfileRevision);
    _conversationController.removeListener(_onConversationControllerChanged);
    _conversationController.dispose();
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

  Future<void> _handleSend(String text) async {
    if (!_requireChatEntitlement()) return;
    await _conversationController.sendText(text);
  }

  Future<void> _sendMediaDrafts(Iterable<ChatMediaDraft> drafts) async {
    if (_conversationController.attachmentBusy || !_requireChatEntitlement()) {
      return;
    }
    final prepared = drafts.toList(growable: false);
    for (final draft in prepared) {
      if (ChatMediaLimits.exceedsForKind(draft.kind, draft.byteSize)) {
        setState(() {
          _productError =
              '文件超出当前会员单个附件上限（${ChatMediaLimits.currentLimitLabel}）';
        });
        return;
      }
      if (ChatMediaLimits.exceedsDurationForKind(
        draft.kind,
        draft.durationMs,
      )) {
        setState(() => _productError = '语音、视频消息每条最长 3 分钟');
        return;
      }
    }
    await _conversationController.sendMediaDrafts(prepared);
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

  /// 发送贴纸:只把 `(packId, stickerId)` 交给发送链路(走 MLS 消息瞬时中转,
  /// 零字节、零 WebRTC)。面板保持打开以便连发,不自动关闭。
  Future<void> _handleSendSticker(String packId, String stickerId) async {
    if (!_requireChatEntitlement()) return;
    await _conversationController.sendSticker(packId, stickerId);
  }

  /// 键盘、表情/贴纸、加号面板互斥；打开辅助面板时收起系统键盘。
  void _togglePanel(ChatComposerPanel panel) {
    if (panel == ChatComposerPanel.none) {
      if (_openPanel != ChatComposerPanel.none) {
        setState(() => _openPanel = ChatComposerPanel.none);
      }
      return;
    }
    final closingCurrentPanel = _openPanel == panel;
    setState(() {
      _openPanel = closingCurrentPanel ? ChatComposerPanel.none : panel;
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
    if (_openPanel == ChatComposerPanel.none) return;
    setState(() => _openPanel = ChatComposerPanel.none);
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
      _openPanel = ChatComposerPanel.none;
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
    if (ChatMediaLimits.exceedsDurationForKind(picked.kind, probe.durationMs)) {
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
    _togglePanel(ChatComposerPanel.none);
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
          return;
        case ChatComposerAction.voiceCall:
          return;
        case ChatComposerAction.location:
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('功能完善中，敬请期待')));
      }
    } on ChatMediaTooLargeException {
      if (mounted) {
        setState(() {
          _productError =
              '文件超出当前会员单个附件上限（${ChatMediaLimits.currentLimitLabel}）';
        });
      }
    } on ChatMediaTooLongException {
      if (mounted) setState(() => _productError = '语音、视频消息每条最长 3 分钟');
    } catch (error) {
      if (mounted) setState(() => _productError = chatUserErrorMessage(error));
    }
  }

  Future<void> _openTransfer() async {
    if (widget.isGroup || _productActionBusy) return;
    setState(() {
      _productActionBusy = true;
      _productError = null;
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
      if (mounted) setState(() => _productError = chatUserErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _productActionBusy = false);
      }
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
      if (mounted) setState(() => _productError = chatUserErrorMessage(error));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('说话时间太短')));
        }
        return;
      }
      await _sendVoiceResult(result);
    } catch (error) {
      if (mounted) setState(() => _productError = chatUserErrorMessage(error));
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
            chatMessageMaximumDuration.inMilliseconds,
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
    final downloaded = await _conversationController.downloadAttachment(
      controlPlaintext,
    );
    if (!mounted || downloaded == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存：${downloaded.fileName}')),
    );
  }

  Future<void> _handleDeleteConversation() async {
    final confirmed = await _confirmDeleteConversationPage(context);
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _deleting = true;
      _productError = null;
    });
    try {
      _conversationController.pause();
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
        await _conversationController.chatController.setMessages(
          const [],
          animated: false,
        );
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
          _productError = chatUserErrorMessage(error);
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

  /// 统一输入栏：键盘/语音两态，共用表达面板与 4+3 动作面板。
  Widget _buildComposer(BuildContext context) {
    if (!ChatMediaLimits.chatAuthorizedFor(widget.ownerUserId)) {
      final resolved =
          ChatMediaLimits.authorizationResolvedFor(widget.ownerUserId) &&
              ChatMediaLimits.resolvedFor(widget.ownerUserId);
      return Container(
        key: const ValueKey('chat-membership-required'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaled(context, 16),
          vertical: AppLayout.scaled(context, 14),
        ),
        color: AppTheme.surfaceCard,
        child: Text(
          resolved ? '尚未开通会员，订阅任一会员后即可使用聊天' : '暂时无法验证会员状态，请稍后重试',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppLayout.scaled(context, 13),
          ),
        ),
      );
    }
    final Widget? panel = switch (_openPanel) {
      ChatComposerPanel.none => null,
      ChatComposerPanel.expression => _buildExpressionPanel(context),
      ChatComposerPanel.actions => ComposerActionPanel(
          isGroup: widget.isGroup,
          callsEnabled: false,
          onAction: (action) => unawaited(_handleComposerAction(action)),
          iconBuilder: (context, action, color, size) {
            if (action != ChatComposerAction.transfer) return null;
            return Image.asset(
              'assets/icons/gmb-mark.png',
              key: const ValueKey('chat-action-transfer-gmb-mark'),
              width: size,
              height: size,
              color: color,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.high,
            );
          },
        ),
    };
    return ComposerBar(
      controller: _composerController,
      focusNode: _composerFocusNode,
      inputMode: _inputMode,
      expressionOpen: _openPanel == ChatComposerPanel.expression,
      actionsOpen: _openPanel == ChatComposerPanel.actions,
      recording: _voiceState.recording,
      recordingDuration: _voiceState.duration,
      onToggleInputMode: _toggleInputMode,
      onToggleExpression: () => _togglePanel(ChatComposerPanel.expression),
      onToggleActions: () => _togglePanel(ChatComposerPanel.actions),
      onTextInputTap: _handleTextInputTap,
      onSendText: (text) => unawaited(_handleSend(text)),
      onVoicePressStart: () => unawaited(_startVoiceRecording()),
      onVoicePressEnd: (cancel) => unawaited(_finishVoiceRecording(cancel)),
      panel: panel,
    );
  }

  bool _requireChatEntitlement() {
    if (ChatMediaLimits.chatAuthorizedFor(widget.ownerUserId)) return true;
    if (mounted) {
      setState(() {
        _productError =
            ChatMediaLimits.authorizationResolvedFor(widget.ownerUserId) &&
                    ChatMediaLimits.resolvedFor(widget.ownerUserId)
                ? '尚未开通会员，订阅任一会员后即可使用聊天'
                : '暂时无法验证会员状态，请稍后重试';
      });
    }
    return false;
  }

  Widget _buildExpressionPanel(BuildContext context) {
    return ChatExpressionPanel(
      controller: _composerController,
      selectedTab: _expressionTab,
      onTabChanged: (tab) => setState(() => _expressionTab = tab),
      onStickerPick: (packId, stickerId) =>
          unawaited(_handleSendSticker(packId, stickerId)),
      onSendText: (text) => unawaited(_handleSend(text)),
      style: const ChatViewStyle(
        surfaceColor: AppTheme.surfaceCard,
        accentColor: AppTheme.accent,
        textSecondaryColor: AppTheme.textSecondary,
        textTertiaryColor: AppTheme.textTertiary,
        scaler: AppLayout.scaled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peerName = ProfilePresentation.forIdentityKey(
      widget.peerUserId,
    ).resolveDisplayName(publicName: _peerProfile?.displayName ?? widget.title);
    const style = ChatViewStyle(
      backgroundColor: AppTheme.scaffoldBg,
      surfaceColor: AppTheme.surfaceCard,
      primaryColor: AppTheme.primary,
      accentColor: AppTheme.accent,
      textPrimaryColor: AppTheme.textPrimary,
      textSecondaryColor: AppTheme.textSecondary,
      textTertiaryColor: AppTheme.textTertiary,
      scaler: AppLayout.scaled,
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
      body: ChatMessageListView(
        currentUserId: widget.ownerUserId,
        chatController: _conversationController.chatController,
        onMessageSend: _handleSend,
        resolveUser: (id) async {
          final isMe = id == widget.ownerUserId;
          return User(
            id: id,
            name: isMe
                ? '我'
                : widget.isGroup
                    ? ProfilePresentation.forIdentityKey(id).fallbackName
                    : peerName,
          );
        },
        composerBuilder: _buildComposer,
        onDownloadAttachment: _downloadMedia,
        onMessagesChanged: _conversationController.reloadMessages,
        isGroup: widget.isGroup,
        loading: _conversationController.loading,
        error: _productError ?? _conversationController.error,
        groupSenderBuilder: widget.isGroup
            ? (context, userId) => Username(
                  userId: userId,
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 11),
                    color: AppTheme.textSecondary,
                  ),
                )
            : null,
        style: style,
      ),
    );
  }
}

enum _ChatMenuAction { deleteConversation }

Future<bool> _confirmDeleteConversationPage(BuildContext context) async {
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

String _shortAccount(String value) {
  if (value.length <= 16) {
    return value;
  }
  return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
}

typedef ChatSendTextFactory = ChatSendTextCallback? Function(
    String peerUserId, String conversationId);
typedef ChatSyncFactory = ChatSyncCallback? Function(String peerUserId);
typedef ChatSendMediaFactory = ChatSendMediaCallback? Function(
    String peerUserId, String conversationId);
typedef ChatDownloadAttachmentFactory = CitizenChatDownloadAttachmentCallback?
    Function(String peerUserId);

/// 聊天页加号菜单 5 个动作的可注入入口。
///
/// 默认全为 null，各动作走真实实现；测试整体替换后即可断言路由，
/// 而不会真的拉起相机、建群页或通讯录（它们会触发 Isar / ChatRuntime / 相机）。
class ChatEntryOpeners {
  const ChatEntryOpeners({
    this.openScan,
    this.openReceivePay,
    this.openSendMessage,
    this.openCreateGroup,
    this.openAddFriend,
  });

  /// 扫一扫 = 交易·扫一扫统一分派（扫到用户码按收款人进入转账）。
  final ChatEntryOpener? openScan;

  /// 收付款 = 展示本账户账户码（收款码 `k=4` 生成方待实现）。
  final ChatEntryOpener? openReceivePay;

  /// 发私信 = 通讯录单选后直开私聊。
  final ChatEntryOpener? openSendMessage;

  /// 发群聊 = 通讯录多选（≥2 人）建群。
  final ChatEntryOpener? openCreateGroup;

  /// 加好友 = 扫对方二维码写入本人通讯录。
  final ChatEntryOpener? openAddFriend;
}

/// 加号菜单单个动作的入口签名；默认钱包等依赖一律由真实实现内部解析，
/// 注入替身时不触碰 WalletManager / Isar / 相机。
typedef ChatEntryOpener = Future<void> Function(BuildContext context);

/// 公民“聊天”Tab。
///
/// 顶部为搜索框（进入 [ChatSearchPage]），右上角加号弹出 5 个入口：
/// 扫一扫 / 收付款 / 发私信 / 发群聊 / 加好友。会话列表在其下方。
class ChatTab extends StatefulWidget {
  ChatTab({
    super.key,
    ChatStore? store,
    WalletManager? walletManager,
    this.cidNumber,
    this.accountId,
    this.sendTextFactory,
    this.sendMediaFactory,
    this.downloadAttachmentFactory,
    this.syncFactory,
    this.runtime,
    this.selectedTab,
    this.tabIndex = 2,
    this.openers,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
    this.contactService,
    this.subscriptionService,
  })  : store = store ?? ChatStore(),
        walletManager = walletManager ?? WalletManager();

  final ChatStore store;
  final WalletManager walletManager;
  final String? cidNumber;
  final String? accountId;
  final ChatSendTextFactory? sendTextFactory;
  final ChatSendMediaFactory? sendMediaFactory;
  final ChatDownloadAttachmentFactory? downloadAttachmentFactory;
  final ChatSyncFactory? syncFactory;
  final ChatRuntime? runtime;
  final ValueListenable<int>? selectedTab;
  final int tabIndex;

  /// 加号菜单动作入口；仅测试注入，正式运行为 null 走真实实现。
  final ChatEntryOpeners? openers;
  final CitizenProfileApi? profileApi;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquareSessionProvider? sessionProvider;
  final UserContactService? contactService;
  final SubscriptionService? subscriptionService;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  List<ChatConversationPreview> _conversations = const [];
  // 用户确认删除后先从所有页面读取结果中屏蔽该会话；物理清理即使仍在
  // 等待文件 lease，轮询、Realtime 或路由返回重载也不得把卡片重新插回。
  final Set<String> _conversationDeletesInFlight = <String>{};
  late final CitizenProfileApi _profileApi =
      widget.profileApi ?? CitizenProfileApi();
  late final CitizenProfileCache _profileCache =
      widget.profileCache ?? const CitizenProfileCache();
  late final CitizenProfileMediaCache _profileMediaCache =
      widget.profileMediaCache ?? CitizenProfileMediaCache();
  late final SquareSessionProvider _sessionProvider =
      widget.sessionProvider ?? SquareSessionProvider.instance;
  late final SubscriptionService _subscriptionService =
      widget.subscriptionService ?? SubscriptionService();
  late final UserContactService _contactService = widget.contactService ??
      UserContactService(walletManager: widget.walletManager);
  final Map<String, CitizenProfile> _peerProfiles = <String, CitizenProfile>{};
  final Map<String, CitizenProfileMediaSnapshot> _peerProfileMedia =
      <String, CitizenProfileMediaSnapshot>{};
  final Set<String> _resolvedPeerCidNumbers = <String>{};
  final Map<String, String> _peerContactRemarks = <String, String>{};
  SquareSession? _profileSession;
  String _cidNumber = '';
  String _accountId = '';
  bool _loading = true;
  String? _error;

  late final ChatConversationListController _listController;

  bool get _isTabSelected =>
      widget.selectedTab == null ||
      widget.selectedTab!.value == widget.tabIndex;

  bool get _isActive => _listController.isActive;

  @override
  void initState() {
    super.initState();
    _listController = ChatConversationListController(
      onCoordinate: () => _reload(syncFirst: true),
      onRefresh: _syncAndRefresh,
      onStartRealtime: _startRealtime,
    );
    _listController.start(visible: _isTabSelected);
    MembershipRevision.instance.listenable.addListener(_onMembershipChanged);
    widget.selectedTab?.addListener(_onSelectedTabChanged);
    WalletManager.walletsRevision.addListener(_onWalletsChanged);
    CitizenProfileCache.revision.addListener(_onProfileRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCoordinate());
  }

  @override
  void didUpdateWidget(covariant ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      oldWidget.selectedTab?.removeListener(_onSelectedTabChanged);
      widget.selectedTab?.addListener(_onSelectedTabChanged);
      _onSelectedTabChanged();
    }
  }

  @override
  void dispose() {
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    CitizenProfileCache.revision.removeListener(_onProfileRevision);
    WalletManager.walletsRevision.removeListener(_onWalletsChanged);
    widget.selectedTab?.removeListener(_onSelectedTabChanged);
    _listController.dispose();
    super.dispose();
  }

  void _onMembershipChanged() {
    final event = MembershipRevision.instance.listenable.value;
    if (mounted && event != null && event.cidNumber == _cidNumber) {
      setState(() {});
    }
  }

  void _onProfileRevision() {
    final event = CitizenProfileCache.revision.value;
    if (!mounted || event == null) return;
    final matches = _conversations.any(
      (preview) => !preview.isGroup && preview.peerUserId == event.cidNumber,
    );
    if (!matches) return;
    unawaited(_readCachedPeerProfiles(_conversations, force: true));
  }

  void _onSelectedTabChanged() {
    _listController.setVisible(_isTabSelected);
    if (_isActive) {
      _requestCoordinate();
    } else {
      _pauseSync();
    }
  }

  /// init、进入 Tab、App resume 全部汇入同一个 coordinator；同一时刻只允许
  /// 一个 reload/sync 链，避免系统 UI 导致 lifecycle 抖动时重复初始化。
  void _requestCoordinate() => _listController.requestCoordinate();

  Future<void> _onWalletsChanged() async {
    // 先廉价比对(纯 Isar 读):默认聊天身份没变的钱包操作(重命名/导入
    // 未置顶钱包)不触发发送队列重试,避免整页转圈与无谓网络请求。
    final identity = await _readIdentity();
    if (!mounted ||
        (identity.accountId == _accountId &&
            identity.cidNumber == _cidNumber)) {
      return;
    }
    if (_accountId.isNotEmpty) {
      await widget.runtime?.invalidateAccount(_accountId);
    }
    _profileSession = null;
    _pauseSync();
    _requestCoordinate();
  }

  /// 本地加载世代号。切默认钱包后并发 reload 乱序完成时，旧身份不得覆写
  /// 新身份；网络与 MLS 后台任务由 SDK 列表控制器的内部世代隔离。
  int _reloadGeneration = 0;

  List<ChatConversationPreview> _withoutDeletingConversations(
    Iterable<ChatConversationPreview> conversations,
  ) =>
      conversations
          .where(
            (preview) =>
                !_conversationDeletesInFlight.contains(preview.conversationId),
          )
          .toList(growable: false);

  Future<void> _reload({bool syncFirst = false}) async {
    if (!_isActive) {
      return;
    }
    final generation = ++_reloadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    String? serviceAccountId;
    String? serviceCidNumber;
    try {
      final identity = await _readIdentity();
      final activeWallet = widget.accountId ?? identity.accountId;
      final ownerUserId = widget.cidNumber ?? identity.cidNumber;
      if (!_isActive) {
        return;
      }
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        if (_cidNumber != ownerUserId) {
          // 私人备注属于当前 CID；切换身份时先同步清空，禁止旧身份备注闪现。
          _peerContactRemarks.clear();
        }
        _cidNumber = ownerUserId;
        _accountId = activeWallet;
      });
      unawaited(_ensureChatEntitlement(ownerUserId, generation));
      if (ownerUserId.isEmpty) {
        // 默认账户未注册 CID 是合法状态；禁止回退到其他账户，必须在此
        // 短路。会话存储读取第一步就要解析密钥绑定,对未注册身份必抛
        // WalletAuthException,catch 成 _error 横幅后会盖住注册引导;轮询/realtime
        // 同样是注定失败的空转。渲染层 `_cidNumber.isEmpty` 分支显示统一注册引导。
        _pauseSync();
        return;
      }
      // 本地阶段只读 ChatIsar。发送队列、Realtime、MLS、FCM 与唤醒端点
      // 全部在本地结果显示后静默执行，不得延长本地加载提示。
      final conversations = await widget.store.readConversationPreviews(
        ownerUserId: ownerUserId,
        currentAccountId: activeWallet,
      );
      if (!mounted || !_isActive || generation != _reloadGeneration) {
        return;
      }
      final visible = _withoutDeletingConversations(conversations);
      setState(() {
        _conversations = visible;
      });
      unawaited(_hydratePeerProfiles(visible));
      if (activeWallet.isNotEmpty) {
        serviceAccountId = activeWallet;
        serviceCidNumber = ownerUserId;
      }
    } catch (error) {
      if (mounted && generation == _reloadGeneration) {
        setState(() {
          _error = chatUserErrorMessage(error);
        });
      }
    } finally {
      if (mounted && generation == _reloadGeneration) {
        setState(() {
          _loading = false;
        });
      }
    }
    if (serviceAccountId != null && serviceCidNumber != null) {
      if (syncFirst) {
        _listController.synchronizeScope(serviceAccountId);
      } else if (mounted && _isActive && generation == _reloadGeneration) {
        // 二级页返回只需恢复既有轮询/Realtime，不重复执行首次补发链。
        _configurePolling(serviceAccountId);
      }
    }
  }

  /// 当前 CID 在身份鉴权时读取一次 CitizenServe；聊天列表和窗口复用统一本地缓存。
  /// 结果由 [ChatMediaLimits] 绑定 CID，切换钱包后旧 CID 权益不能复用。
  Future<void> _ensureChatEntitlement(
    String cidNumber,
    int reloadGeneration,
  ) async {
    if (cidNumber.isEmpty) return;
    // 展示先恢复上一次服务端确认的本地快照，避免每次进入页面先显示无会员；
    // 随后的服务端鉴权仍由 authorizeMembership 在同一登录会话内严格去重一次。
    await _subscriptionService.readDisplaySnapshot(cidNumber);
    if (mounted &&
        reloadGeneration == _reloadGeneration &&
        cidNumber == _cidNumber) {
      setState(() {});
    }
    try {
      final session = _profileSession ?? await _sessionProvider.ensureSession();
      if (session == null || session.cidNumber.trim() != cidNumber) return;
      _profileSession = session;
      await _subscriptionService.authorizeMembership(session);
    } on Exception {
      // 展示仍可复用本地快照，但发送授权必须由本次会话的 CitizenServe 结果确认。
      ChatMediaLimits.markAuthorizationUnavailable(cidNumber);
    }
    if (mounted &&
        reloadGeneration == _reloadGeneration &&
        cidNumber == _cidNumber) {
      setState(() {});
    }
  }

  /// 本地首屏完成后静默收敛聊天服务。该 Future 不进入页面 loading/error，
  /// 服务失败时保留已经显示的本地列表，由后续轮询或下一次进入页面重试。
  Iterable<String> _directPeerCidNumbers(
    List<ChatConversationPreview> conversations,
  ) sync* {
    final seen = <String>{};
    for (final preview in conversations) {
      final cidNumber = preview.peerUserId.trim();
      if (!preview.isGroup && cidNumber.isNotEmpty && seen.add(cidNumber)) {
        yield cidNumber;
      }
    }
  }

  /// Chat UI 只按 CID 联合读取 UserIsar 公开资料；不会向 ChatIsar 增加头像、昵称或会员列。
  Future<void> _readCachedPeerProfiles(
    List<ChatConversationPreview> conversations, {
    bool force = false,
  }) async {
    await Future.wait(
      _directPeerCidNumbers(conversations).map((cidNumber) async {
        if (!force && _resolvedPeerCidNumbers.contains(cidNumber)) return;
        final profile = await _profileCache.read(cidNumber);
        if (profile == null) return;
        _peerProfiles[cidNumber] = profile;
        _peerProfileMedia[cidNumber] = await _profileMediaCache.read(profile);
        _resolvedPeerCidNumbers.add(cidNumber);
      }),
    );
    if (mounted && force) setState(() {});
  }

  /// 会话标题先用 ChatIsar 已有预览立即显示；公开资料缓存随后把中性头像替换为真实
  /// 头像。缓存读取或网络失败都不能阻塞聊天列表，也不能回退成旧默认头像。
  Future<void> _hydratePeerProfiles(
    List<ChatConversationPreview> conversations,
  ) async {
    unawaited(_hydrateContactRemarks(conversations));
    try {
      await _readCachedPeerProfiles(conversations);
      if (mounted) setState(() {});
      await _refreshPeerProfiles(conversations);
    } on Exception {
      // 公开资料是 Chat UI 的联合展示数据；失败不影响加密会话本身。
    }
  }

  /// 通讯录备注是本机私人数据，只与当前 CID 下的直接会话联合展示。读取失败不阻塞
  /// ChatIsar 首屏，也不允许用 CID 代替昵称回退到界面。
  Future<void> _hydrateContactRemarks(
    List<ChatConversationPreview> conversations,
  ) async {
    final ownerUserId = _cidNumber;
    if (ownerUserId.isEmpty) return;
    final peers = _directPeerCidNumbers(conversations).toSet();
    try {
      final contacts = await _contactService.getContacts();
      if (!mounted || _cidNumber != ownerUserId) return;
      final remarks = <String, String>{
        for (final contact in contacts)
          if (peers.contains(contact.cidNumber) &&
              contact.contactRemark.trim().isNotEmpty)
            contact.cidNumber: contact.contactRemark.trim(),
      };
      setState(() {
        _peerContactRemarks
          ..removeWhere((cidNumber, _) => peers.contains(cidNumber))
          ..addAll(remarks);
      });
    } on Exception {
      // 通讯录不可用不影响消息收发；卡片继续显示公开昵称或稳定默认昵称。
    }
  }

  /// 对端公开资料按四个 CID 一组刷新，防止大聊天列表产生无界请求；会员展示只采用
  /// CitizenServe 当前 D1 结果；本人的聊天授权统一由会员缓存与服务端 D1 门禁处理。
  Future<void> _refreshPeerProfiles(
    List<ChatConversationPreview> conversations,
  ) async {
    final cidNumbers = _directPeerCidNumbers(conversations).toList();
    if (cidNumbers.isEmpty || !mounted) return;
    try {
      _profileSession ??= await _sessionProvider.ensureSession();
    } on Exception {
      return;
    }
    for (var offset = 0; offset < cidNumbers.length; offset += 4) {
      final end =
          offset + 4 < cidNumbers.length ? offset + 4 : cidNumbers.length;
      final batch = cidNumbers.sublist(offset, end);
      await Future.wait(
        batch.map((cidNumber) async {
          try {
            final profile = await _profileApi.fetchProfile(
              cidNumber,
              session: _profileSession,
            );
            _peerProfiles[cidNumber] = profile;
            _resolvedPeerCidNumbers.add(cidNumber);
            _peerProfileMedia[cidNumber] = await _profileMediaCache.read(
              profile,
            );
            await _profileCache.write(profile);
            final avatarKey = profile.avatarObjectKey?.trim();
            if (avatarKey == null ||
                avatarKey.isEmpty ||
                _profileSession == null) {
              return;
            }
            final media = await _profileMediaCache.refresh(
              profile: profile,
              avatarUrl: _profileApi.mediaUrl(
                avatarKey,
                updatedAt: profile.updatedAt,
              ),
              bannerUrl: null,
              headers: <String, String>{
                'authorization': 'Bearer ${_profileSession!.sessionToken}',
              },
            );
            if (_peerProfiles[cidNumber]?.updatedAt == profile.updatedAt) {
              _peerProfileMedia[cidNumber] = media;
            }
          } on Exception {
            // Chat 继续使用本机资料或中性占位，单个公开资料失败不影响会话可用性。
          }
        }),
      );
      if (mounted) setState(() {});
    }
  }

  Future<bool> _retryOutgoingSilently() async {
    if (!_isActive) {
      return false;
    }
    final runtime = widget.runtime;
    if (runtime == null) {
      return true;
    }
    try {
      await runtime.retryOutgoing();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _configurePolling(String activeWallet) {
    if (!_isActive || activeWallet.isEmpty || widget.runtime == null) {
      _pauseSync();
      return;
    }
    _listController.configureScope(activeWallet);
  }

  Future<Future<void> Function()?> _startRealtime(
    String activeWallet, {
    required Future<void> Function() onNotice,
    Future<void> Function()? onDisconnected,
  }) async {
    final runtime = widget.runtime;
    if (!_isActive || runtime == null || _accountId != activeWallet) {
      return null;
    }
    return runtime.startRealtimeSync(
      onNotice: onNotice,
      onDisconnected: onDisconnected,
    );
  }

  Future<bool> _syncAndRefresh(String accountId) async {
    if (!_isActive || _accountId != accountId) return false;
    final retried = await _retryOutgoingSilently();
    final conversations = await widget.store.readConversationPreviews(
      ownerUserId: _cidNumber,
      currentAccountId: accountId,
    );
    if (!mounted || !_isActive || _accountId != accountId) return false;
    final visible = _withoutDeletingConversations(conversations);
    setState(() {
      _conversations = visible;
    });
    unawaited(_hydratePeerProfiles(visible));
    return retried;
  }

  void _pauseSync() {
    _listController.pause();
  }

  Future<({String cidNumber, String accountId})> _readIdentity() async {
    if (widget.cidNumber != null && widget.accountId != null) {
      return (cidNumber: widget.cidNumber!, accountId: widget.accountId!);
    }
    final runtime = widget.runtime;
    if (runtime != null) {
      final current = await runtime.readCurrentUser();
      if (current.accountId.isNotEmpty) {
        return (cidNumber: current.userId, accountId: current.accountId);
      }
    }
    final identity = await CurrentUserContext.instance.resolve();
    return (
      cidNumber: identity?.cidNumber ?? '',
      accountId: identity?.accountId ?? '',
    );
  }

  Future<void> _deleteLocalConversation(String conversationId) {
    final runtime = widget.runtime;
    if (runtime != null) {
      return runtime.deleteLocalConversation(conversationId);
    }
    return Future<void>.error(
      StateError('删除 Chat 会话必须由持久 binding fence Runtime 协调'),
    );
  }

  /// 逻辑删除先于物理删除完成：调用本方法的同步阶段立刻移除卡片并登记过滤，
  /// 返回的 Future 只代表后台 Store/附件清理。成功后解除过滤；失败才恢复
  /// 本地真值并显示错误，不能让页面因等待内部锁而停在不可操作状态。
  Future<void> _deleteConversationInBackground(String conversationId) async {
    if (!_conversationDeletesInFlight.add(conversationId)) return;
    if (mounted) {
      setState(() {
        _conversations = _conversations
            .where((item) => item.conversationId != conversationId)
            .toList(growable: false);
        _error = null;
      });
    }
    try {
      await _deleteLocalConversation(conversationId);
      // 物理删除完成后再读一次真值；在这次读取结束前继续保留过滤标记，
      // 防止与路由返回重载竞速的旧快照把卡片短暂插回。
      if (mounted) await _reload();
      _conversationDeletesInFlight.remove(conversationId);
    } catch (error) {
      _conversationDeletesInFlight.remove(conversationId);
      if (mounted) {
        await _reload();
        if (mounted) {
          setState(() {
            _error = chatUserErrorMessage(error);
          });
        }
      }
    }
  }

  Future<void> _confirmAndDeleteConversation(
    ChatConversationPreview preview,
  ) async {
    final confirmed = await _confirmDeleteConversationList(context);
    if (!confirmed || !mounted) {
      return;
    }
    unawaited(_deleteConversationInBackground(preview.conversationId));
  }

  void _openConversation(ChatConversationPreview preview) {
    if (!_requireChatIdentity()) return;
    if (!_requireChatMembership()) return;
    if (preview.isGroup) {
      openGroupChat(
        context,
        groupId: preview.conversationId,
        title: preview.title,
        onDeleteConversation: () =>
            _deleteConversationInBackground(preview.conversationId),
      ).then((_) => _reload());
      return;
    }
    _openDirectConversation(preview);
  }

  void _openCreateGroup() {
    if (!_requireChatIdentity()) return;
    if (!_requireChatMembership()) return;
    final opener = widget.openers?.openCreateGroup;
    if (opener != null) {
      unawaited(opener(context));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GroupCreatePage()))
        .then((_) => _reload());
  }

  /// 没有默认钱包账户时统一提示并拦截；冷热钱包均可作为当前账户。
  bool _requireAccount() {
    if (_accountId.isEmpty) {
      setState(() => _error = '请先在「我的 → 我的钱包」添加钱包账户');
      return false;
    }
    return true;
  }

  /// 页面浏览直接开放；私信、群聊、加好友等动作发生时再严格要求热钱包与 CID。
  ///
  /// 未注册不再打错误横幅,而是就地弹全 App 统一注册面板;占号成功后
  /// coordinator 回刷进正常聊天,原动作由用户重新触发(不自动续跑)。
  bool _requireChatIdentity() {
    if (!_requireAccount()) return false;
    if (_cidNumber.isEmpty) {
      unawaited(
        startCidRegistrationFlow(context).then((registered) {
          if (registered && mounted) _requestCoordinate();
        }),
      );
      return false;
    }
    return true;
  }

  bool _requireChatMembership() {
    if (ChatMediaLimits.chatAuthorizedFor(_cidNumber)) return true;
    setState(() {
      _error = ChatMediaLimits.authorizationResolvedFor(_cidNumber) &&
              ChatMediaLimits.resolvedFor(_cidNumber)
          ? '尚未开通会员，订阅任一会员后即可使用聊天'
          : '暂时无法验证会员状态，请稍后重试';
    });
    return false;
  }

  /// 加号菜单动作分派。
  Future<void> _onEntryAction(_ChatEntryAction action) async {
    switch (action) {
      case _ChatEntryAction.scan:
        await _openScan();
      case _ChatEntryAction.receivePay:
        await _openReceivePay();
      case _ChatEntryAction.sendMessage:
        await _openSendMessage();
      case _ChatEntryAction.createGroup:
        _openCreateGroup();
      case _ChatEntryAction.addFriend:
        await _openAddFriend();
    }
  }

  /// 扫一扫 = 交易·扫一扫统一分派；扫到用户码按收款人进入转账。
  Future<void> _openScan() async {
    final opener = widget.openers?.openScan;
    if (opener != null) {
      await opener(context);
      return;
    }
    final wallet = await widget.walletManager.getDefaultWallet();
    if (!mounted) return;
    await openScanDispatchFlow(context: context, paymentWallet: wallet);
  }

  /// 收付款 = 展示本账户账户码（`k=5`），他人扫码后按账户向我转账。
  ///
  /// 本入口最终归属是收款码（`k=4`，带金额与备注、临时有效），当前其生成方尚未实现，
  /// 暂出账户码；收款码落地时只切这一处，码型契约由共享 QR registry 固定。
  Future<void> _openReceivePay() async {
    if (!_requireAccount()) return;
    final opener = widget.openers?.openReceivePay;
    if (opener != null) {
      await opener(context);
      return;
    }
    final wallet = await widget.walletManager.getDefaultWallet();
    if (!mounted) return;
    if (wallet == null) {
      setState(() => _error = '请先在「我的 → 我的钱包」添加钱包账户');
      return;
    }
    await showWalletQrDialog(
      context,
      accountId: wallet.accountId,
      accountName: wallet.walletName,
    );
  }

  /// 发私信 = 通讯录单选，点联系人直接开私聊。
  Future<void> _openSendMessage() async {
    if (!_requireChatIdentity()) return;
    if (!_requireChatMembership()) return;
    final opener = widget.openers?.openSendMessage;
    if (opener != null) {
      await opener(context);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ContactBookPage(mode: ContactPickMode.pickForMessage),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  /// 加好友 = 扫对方二维码写入本人密文通讯录。
  Future<void> _openAddFriend() async {
    if (!_requireChatIdentity()) return;
    final opener = widget.openers?.openAddFriend;
    if (opener != null) {
      await opener(context);
      return;
    }
    await scanAndAddContact(context);
  }

  /// 搜索 = 进入独立搜索页；透传 store 与账户，避免搜索页重复解析依赖。
  Future<void> _openSearch() async {
    if (!_requireChatIdentity()) return;
    if (!_requireChatMembership()) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatSearchPage(
          store: widget.store,
          cidNumber: _cidNumber,
          accountId: _accountId,
        ),
      ),
    );
  }

  void _openGroupManage(ChatConversationPreview preview) {
    if (!_requireChatMembership()) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => GroupManagePage(
              groupId: preview.conversationId,
              cidNumber: _cidNumber,
            ),
          ),
        )
        .then((_) => _reload());
  }

  void _openDirectConversation(ChatConversationPreview preview) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => ChatPage(
              conversationId: preview.conversationId,
              ownerUserId: _cidNumber,
              accountId: _accountId,
              peerUserId: preview.peerUserId,
              title: preview.title,
              store: widget.store,
              onSendText: widget.sendTextFactory?.call(
                    preview.peerUserId,
                    preview.conversationId,
                  ) ??
                  (widget.runtime == null
                      ? null
                      : (text) => widget.runtime!.sendText(
                            peerUserId: preview.peerUserId,
                            conversationId: preview.conversationId,
                            text: text,
                          )),
              onSendMedia: widget.sendMediaFactory?.call(
                    preview.peerUserId,
                    preview.conversationId,
                  ) ??
                  (widget.runtime == null
                      ? null
                      : (media, {onLocalCommitted}) =>
                          widget.runtime!.sendMedia(
                            peerUserId: preview.peerUserId,
                            conversationId: preview.conversationId,
                            media: media,
                            onLocalCommitted: onLocalCommitted,
                          )),
              onSendSticker: widget.runtime == null
                  ? null
                  : (packId, stickerId) => widget.runtime!.sendSticker(
                        peerUserId: preview.peerUserId,
                        conversationId: preview.conversationId,
                        packId: packId,
                        stickerId: stickerId,
                      ),
              onResolveMediaPaths: widget.runtime == null
                  ? null
                  : (String conversationId, List<ChatContent> contents) =>
                      widget.runtime!.resolveCachedMediaPaths(
                        conversationId: conversationId,
                        contents: contents,
                      ),
              onDownloadAttachment:
                  widget.downloadAttachmentFactory?.call(preview.peerUserId) ??
                      (widget.runtime == null
                          ? null
                          : (String conversationId, String controlPlaintext) =>
                              widget.runtime!.downloadAttachment(
                                conversationId: conversationId,
                                controlPlaintext: controlPlaintext,
                              )),
              onSync: widget.syncFactory?.call(preview.peerUserId) ??
                  (widget.runtime == null
                      ? null
                      : () => widget.runtime!.retryOutgoing(
                            conversationId: preview.conversationId,
                            recipientUserId: preview.peerUserId,
                          )),
              onStartRealtime: widget.runtime == null
                  ? null
                  : ({required onNotice, onDisconnected}) =>
                      widget.runtime!.startRealtimeSync(
                        onNotice: onNotice,
                        onDisconnected: onDisconnected,
                        retryOutgoingOnConnect: false,
                      ),
              onDeleteConversation: () =>
                  _deleteConversationInBackground(preview.conversationId),
              onMarkRead: widget.runtime == null
                  ? null
                  : (readThroughMillis) => widget.runtime!.markConversationRead(
                        conversationId: preview.conversationId,
                        readThroughMillis: readThroughMillis,
                      ),
              initialProfile: _peerProfiles[preview.peerUserId],
              initialProfileMedia: _peerProfileMedia[preview.peerUserId],
              profileApi: _profileApi,
              profileCache: _profileCache,
              profileMediaCache: _profileMediaCache,
              sessionProvider: _sessionProvider,
            ),
          ),
        )
        .then((_) => _reload());
  }

  ChatConversationListItem _conversationItem(
    BuildContext context,
    ChatConversationPreview preview,
  ) {
    final profile = _peerProfiles[preview.peerUserId];
    final media = _peerProfileMedia[preview.peerUserId];
    final resolved = _resolvedPeerCidNumbers.contains(preview.peerUserId);
    final publicName = preview.isGroup
        ? preview.title
        : ProfilePresentation.forIdentityKey(
            preview.peerUserId,
          ).resolveDisplayName(
            publicName: profile?.displayName ?? preview.title,
          );
    final remark = _peerContactRemarks[preview.peerUserId]?.trim() ?? '';
    final title = !preview.isGroup && remark.isNotEmpty
        ? '$remark（$publicName）'
        : publicName;
    final leading = preview.isGroup
        ? CircleAvatar(
            radius: AppLayout.scaled(context, 22),
            backgroundColor: AppTheme.primary.withAlpha(20),
            child: const Icon(Icons.groups_outlined, color: AppTheme.primary),
          )
        : ProfileAvatar(
            size: AppLayout.scaled(context, 44),
            seed: preview.peerUserId,
            imagePath: media?.avatarPath,
            imageUrl: profile?.avatarObjectKey?.trim().isNotEmpty == true
                ? _profileApi.mediaUrl(
                    profile!.avatarObjectKey!,
                    updatedAt: profile.updatedAt,
                  )
                : null,
            imageHeaders: _profileSession == null
                ? null
                : <String, String>{
                    'authorization': 'Bearer ${_profileSession!.sessionToken}',
                  },
            userImageSet: resolved
                ? profile?.avatarObjectKey?.trim().isNotEmpty == true
                : true,
            identityLevel: profile?.identityLevel,
            membershipLevel: profile?.membershipLevel,
            membershipActive: profile?.membershipActive ?? false,
            showBadge: resolved,
          );
    return ChatConversationListItem(
      id: preview.conversationId,
      title: title,
      subtitle: preview.lastMessage,
      updatedAt: preview.lastUpdatedAt,
      unreadCount: preview.unreadCount,
      leading: leading,
      onTap: () => _openConversation(preview),
      onDelete: () => _confirmAndDeleteConversation(preview),
      onLongPress: preview.isGroup ? () => _openGroupManage(preview) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const style = ChatViewStyle(
      backgroundColor: AppTheme.scaffoldBg,
      surfaceColor: AppTheme.surfaceCard,
      borderColor: AppTheme.borderLight,
      primaryColor: AppTheme.primary,
      textPrimaryColor: AppTheme.textPrimary,
      textSecondaryColor: AppTheme.textSecondary,
      textTertiaryColor: AppTheme.textTertiary,
      menuColor: Color(0xFF66727D),
      scaler: AppLayout.scaled,
    );
    final Widget? unavailable = _accountId.isEmpty
        ? const ChatConversationPlaceholder(
            message: '请先在「我的 → 我的钱包」添加钱包账户',
            style: style,
          )
        : _cidNumber.isEmpty
            ? IdentityRegisterGuide(
                description: '注册后即可使用聊天与通讯录。',
                onRegistered: _requestCoordinate,
              )
            : null;
    return ChatConversationOverview(
      header: ChatSectionHeader<_ChatEntryAction>(
        onAction: _onEntryAction,
        style: style,
        actions: [
          for (final item in _chatEntryItems)
            ChatHeaderAction<_ChatEntryAction>(
              value: item.action,
              label: item.label,
              icon: item.asset != null
                  ? SvgPicture.asset(
                      item.asset!,
                      width: AppLayout.scaled(context, 18),
                      height: AppLayout.scaled(context, 18),
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      item.icon,
                      size: AppLayout.scaled(context, 20),
                      color: Colors.white,
                    ),
            ),
        ],
      ),
      onRefresh: () => _reload(syncFirst: true),
      onSearch: () => unawaited(_openSearch()),
      items: [
        for (final preview in _conversations)
          _conversationItem(context, preview),
      ],
      loading: _loading,
      errorMessage: _error,
      unavailable: unavailable,
      style: style,
    );
  }
}

/// 加号菜单的 5 个动作。
enum _ChatEntryAction { scan, receivePay, sendMessage, createGroup, addFriend }

/// 加号菜单的一项：图标 + 文案。
///
/// [asset] 与 [icon] 二选一：扫一扫必须用与「交易 → 扫一扫」同一份
/// `assets/icons/scan-line.svg`（扫码图标），不能拿 Material 的二维码图标顶替。
class _ChatEntryItem {
  const _ChatEntryItem(this.action, this.label, {this.icon, this.asset});

  final _ChatEntryAction action;
  final String label;
  final IconData? icon;
  final String? asset;
}

const List<_ChatEntryItem> _chatEntryItems = [
  _ChatEntryItem(
    _ChatEntryAction.scan,
    '扫一扫',
    asset: 'assets/icons/scan-line.svg',
  ),
  _ChatEntryItem(
    _ChatEntryAction.receivePay,
    '收付款',
    icon: Icons.payments_outlined,
  ),
  // 与底部导航「聊天」tab 同一个图标，保持同一语义同一形。
  _ChatEntryItem(
    _ChatEntryAction.sendMessage,
    '发私信',
    icon: Icons.textsms_outlined,
  ),
  _ChatEntryItem(
    _ChatEntryAction.createGroup,
    '发群聊',
    icon: Icons.group_outlined,
  ),
  _ChatEntryItem(
    _ChatEntryAction.addFriend,
    '加好友',
    icon: Icons.person_add_alt_1_outlined,
  ),
];

Future<bool> _confirmDeleteConversationList(BuildContext context) async {
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

/// 群聊打开器；测试可注入替身，正式运行走 [openGroupChat]。
typedef GroupChatOpener = Future<void> Function(
  BuildContext context, {
  required String groupId,
  required String title,
});

/// 聊天搜索页：一个输入框，三段结果 —— 会话 / 联系人 / 聊天记录。
///
/// - 会话与联系人在内存里过滤（进页时一次性载入，数据量小）。
/// - 聊天记录走 [ChatStore.searchMessages] 跨会话检索本机已解密消息。
/// - 点任一结果都复用既有打开收口：群聊 [openGroupChat]、单聊 [openDirectChat]，
///   不在本页复刻 ChatPage 装配。
/// - 聊天记录命中当前**只打开所在会话**，不定位到具体消息（消息级锚点需
///   ChatPage 支持滚动定位，单列后续任务）。
class ChatSearchPage extends StatefulWidget {
  const ChatSearchPage({
    super.key,
    this.store,
    this.contactService,
    this.cidNumber,
    this.accountId,
    this.directChatOpener,
    this.groupChatOpener,
  });

  final ChatStore? store;
  final UserContactService? contactService;

  /// 当前永久身份主键；不传则页面只读本地当前用户快照。
  final String? cidNumber;

  /// 当前身份账户（CID 绑定账户）；不传则页面自行读取。
  final String? accountId;
  final DirectChatOpener? directChatOpener;
  final GroupChatOpener? groupChatOpener;

  @override
  State<ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<ChatSearchPage> {
  late final ChatStore _store = widget.store ?? ChatStore();
  late final UserContactService _contactService =
      widget.contactService ?? UserContactService();
  final TextEditingController _controller = TextEditingController();

  String _accountId = '';
  String _cidNumber = '';
  List<ChatConversationPreview> _conversations =
      const <ChatConversationPreview>[];
  List<UserContact> _contacts = const <UserContact>[];
  List<ChatStoredMessage> _messageHits = const <ChatStoredMessage>[];
  String _query = '';
  bool _loading = true;
  bool _searching = false;
  String? _error;

  /// 消息检索是异步的：用递增序号丢弃过期结果，
  /// 避免快速输入时旧关键词的结果覆盖新关键词的结果。
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final identity = widget.cidNumber != null && widget.accountId != null
          ? null
          : await CurrentUserContext.instance.resolve();
      final accountId = widget.accountId ?? identity?.accountId ?? '';
      final cidNumber = widget.cidNumber ?? identity?.cidNumber ?? '';
      final conversations = await _store.readConversationPreviews(
        ownerUserId: cidNumber,
        currentAccountId: accountId,
      );
      List<UserContact> contacts;
      try {
        contacts = await _contactService.getContacts();
      } on Exception {
        // 通讯录读失败只让「联系人」段为空，不阻塞会话与聊天记录搜索。
        contacts = const <UserContact>[];
      }
      if (!mounted) return;
      setState(() {
        _accountId = accountId;
        _cidNumber = cidNumber;
        _conversations = conversations;
        _contacts = contacts;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '本地聊天数据读取失败';
      });
    }
  }

  Future<void> _onQueryChanged(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      ++_searchSeq;
      setState(() {
        _query = query;
        _messageHits = const <ChatStoredMessage>[];
        _searching = false;
        _error = null;
      });
      return;
    }
    final seq = ++_searchSeq;
    setState(() {
      _query = query;
      _searching = true;
      _error = null;
    });
    try {
      final hits = await _store.searchMessages(
        ownerUserId: _cidNumber,
        currentAccountId: _accountId,
        keyword: query,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _messageHits = hits;
        _searching = false;
      });
    } on Exception {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _messageHits = const <ChatStoredMessage>[];
        _searching = false;
        _error = '聊天记录搜索失败';
      });
    }
  }

  List<ChatConversationPreview> get _conversationHits {
    if (_query.isEmpty) return const <ChatConversationPreview>[];
    final needle = _query.toLowerCase();
    return _conversations
        .where(
          (item) =>
              item.title.toLowerCase().contains(needle) ||
              item.lastMessage.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  List<UserContact> get _contactHits {
    if (_query.isEmpty) return const <UserContact>[];
    final needle = _query.toLowerCase();
    // 只匹配私人备注、CID 与账户：公开昵称要联网拉取，搜索页不引入网络依赖。
    return _contacts
        .where(
          (item) =>
              item.contactRemark.toLowerCase().contains(needle) ||
              item.cidNumber.toLowerCase().contains(needle) ||
              item.accountId.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  Future<void> _openConversation(ChatConversationPreview preview) async {
    if (preview.isGroup) {
      final opener = widget.groupChatOpener ?? openGroupChat;
      await opener(
        context,
        groupId: preview.conversationId,
        title: preview.title,
      );
      return;
    }
    final opener = widget.directChatOpener ?? openDirectChat;
    await opener(context, peerUserId: preview.peerUserId, title: preview.title);
  }

  Future<void> _openContact(UserContact contact) async {
    final opener = widget.directChatOpener ?? openDirectChat;
    final title = contact.contactRemark.isEmpty
        ? ProfilePresentation.forIdentityKey(contact.cidNumber).fallbackName
        : contact.contactRemark;
    await opener(context, peerUserId: contact.cidNumber, title: title);
  }

  /// 聊天记录命中：只打开消息所在会话，不定位到具体消息。
  Future<void> _openMessageHit(ChatStoredMessage message) async {
    ChatConversationPreview? preview;
    for (final item in _conversations) {
      if (item.conversationId == message.conversationId) {
        preview = item;
        break;
      }
    }
    if (preview == null) return;
    await _openConversation(preview);
  }

  @override
  Widget build(BuildContext context) {
    const style = ChatViewStyle(
      backgroundColor: AppTheme.scaffoldBg,
      textTertiaryColor: AppTheme.textTertiary,
      scaler: AppLayout.scaled,
    );
    return ChatSearchView(
      controller: _controller,
      query: _query,
      onQueryChanged: (value) => unawaited(_onQueryChanged(value)),
      onClear: () {
        _controller.clear();
        unawaited(_onQueryChanged(''));
      },
      loading: _loading,
      searching: _searching,
      error: _error,
      style: style,
      sections: [
        ChatSearchSection(
          title: '会话',
          items: [
            for (final item in _conversationHits)
              ChatSearchItem(
                key: ValueKey('search-conversation-${item.conversationId}'),
                leading: Icon(
                  item.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: item.title,
                subtitle: item.lastMessage,
                onTap: () => unawaited(_openConversation(item)),
              ),
          ],
        ),
        ChatSearchSection(
          title: '联系人',
          items: [
            for (final item in _contactHits)
              ChatSearchItem(
                key: ValueKey('search-contact-${item.cidNumber}'),
                leading: const Icon(
                  Icons.account_circle_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: item.contactRemark.isEmpty
                    ? ProfilePresentation.forIdentityKey(
                        item.cidNumber,
                      ).fallbackName
                    : item.contactRemark,
                subtitle: item.cidNumber,
                onTap: () => unawaited(_openContact(item)),
              ),
          ],
        ),
        ChatSearchSection(
          title: '聊天记录',
          items: [
            for (final item in _messageHits)
              ChatSearchItem(
                key: ValueKey('search-message-${item.messageId}'),
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: ChatPayloadCodec.decode(item.plaintext ?? '').summary,
                onTap: () => unawaited(_openMessageHit(item)),
              ),
          ],
        ),
      ],
    );
  }
}

/// 建群页:输群名 + 从通讯录多选成员 → `createGroup`(创建者自动为 admin)。
class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key, this.runtime, this.contactService});

  final ChatRuntime? runtime;
  final UserContactService? contactService;

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final TextEditingController _nameController = TextEditingController();
  late final UserContactService _contactService =
      widget.contactService ?? UserContactService();
  late final ChatRuntime _runtime = widget.runtime ?? ChatRuntime();

  List<UserContact> _contacts = const <UserContact>[];
  final Set<String> _selected = <String>{};
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contacts = await _contactService.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = chatUserErrorMessage(error, fallback: '加载通讯录失败，请稍后重试');
        _loading = false;
      });
    }
  }

  /// 发群聊最少 2 人(1 人应走「发私信」),群名非空方可创建。
  bool get _canCreate =>
      !_loading &&
      _nameController.text.trim().isNotEmpty &&
      _selected.length >= 2;

  Future<void> _create() async {
    if (!_canCreate || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final group = await _runtime.createGroup(
        name: _nameController.text.trim(),
        inviteeUserIds: _selected.toList(growable: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await openGroupChat(context, groupId: group.groupId, title: group.name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = chatUserErrorMessage(error);
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatGroupCreateView(
      nameController: _nameController,
      users: [
        for (final contact in _contacts)
          ChatSelectableUser(
            userId: contact.cidNumber,
            displayName: contact.contactRemark.isEmpty
                ? _shortCreateContact(contact.cidNumber)
                : contact.contactRemark,
            subtitle: _shortCreateContact(contact.cidNumber),
          ),
      ],
      selectedUserIds: _selected,
      onSelectionChanged: (userId, selected) => setState(() {
        if (selected) {
          _selected.add(userId);
        } else {
          _selected.remove(userId);
        }
      }),
      canCreate: _canCreate,
      onCreate: _create,
      loading: _loading,
      creating: _creating,
      error: _error,
      emptyMessage: '通讯录为空,先在「我的 → 通讯录」添加联系人',
      style: const ChatViewStyle(scaler: AppLayout.scaled),
    );
  }
}

String _shortCreateContact(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}

/// 成员管理页:名册 + 加/删(仅 admin)+ 改群名(仅 admin)+ 退群(任何人)。
class GroupManagePage extends StatefulWidget {
  const GroupManagePage({
    super.key,
    required this.groupId,
    this.runtime,
    this.store,
    this.cidNumber,
  });

  final String groupId;
  final ChatRuntime? runtime;
  final ChatStore? store;
  final String? cidNumber;

  @override
  State<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  late final ChatRuntime _runtime = widget.runtime ?? ChatRuntime();
  late final ChatStore _store = widget.store ?? ChatStore();

  ChatGroup? _group;
  String _myCidNumber = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final identity = widget.cidNumber != null
          ? null
          : await CurrentUserContext.instance.resolve();
      final ownerUserId = widget.cidNumber ?? identity?.cidNumber ?? '';
      final group = await _store.readGroup(ownerUserId, widget.groupId);
      if (!mounted) return;
      setState(() {
        _myCidNumber = ownerUserId;
        _group = group;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = chatUserErrorMessage(error);
        _loading = false;
      });
    }
  }

  bool get _isAdmin => _group?.adminSet.contains(_myCidNumber) ?? false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = chatUserErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final name = await showChatRenameGroupDialog(
      context,
      currentName: _group?.name ?? '',
    );
    if (name != null && name.isNotEmpty) {
      await _run(
        () => _runtime.renameGroup(groupId: widget.groupId, name: name),
      );
    }
  }

  Future<void> _addMembers() async {
    final existing = _group?.memberCidNumbers.toSet() ?? <String>{};
    final selected = await _pickContacts(existing);
    if (selected != null && selected.isNotEmpty) {
      await _run(
        () => _runtime.addGroupMembers(
          groupId: widget.groupId,
          inviteeUserIds: selected,
        ),
      );
    }
  }

  Future<void> _leave() async {
    if (await showChatLeaveGroupDialog(context)) {
      await _run(() => _runtime.leaveGroup(widget.groupId));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<List<String>?> _pickContacts(Set<String> exclude) async {
    List<UserContact> contacts;
    try {
      contacts = await UserContactService().getContacts();
    } catch (_) {
      contacts = const <UserContact>[];
    }
    if (!mounted) return null;
    return showChatUserPickerDialog(
      context,
      users: [
        for (final contact in contacts)
          if (!exclude.contains(contact.cidNumber))
            ChatSelectableUser(
              userId: contact.cidNumber,
              displayName: contact.contactRemark.isEmpty
                  ? _shortManageContact(contact.cidNumber)
                  : contact.contactRemark,
              subtitle: _shortManageContact(contact.cidNumber),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return ChatGroupManageView(
      title: group?.name ?? '群聊',
      members: [
        if (group != null)
          for (final member in group.roster)
            ChatGroupMemberItem(
              userId: member.cidNumber,
              displayName: _shortManageContact(member.cidNumber),
              isAdmin: member.isAdmin,
              canRemove: _isAdmin &&
                  member.cidNumber != _myCidNumber &&
                  member.cidNumber != group.creatorCidNumber,
              onRemove: () => _run(
                () => _runtime.removeGroupMembers(
                  groupId: widget.groupId,
                  targetUserIds: [member.cidNumber],
                ),
              ),
            ),
      ],
      isAdmin: _isAdmin,
      onRename: _rename,
      onAddMembers: _addMembers,
      onLeave: _leave,
      loading: _loading,
      busy: _busy,
      groupAvailable: group != null,
      error: _error,
      style: const ChatViewStyle(scaler: AppLayout.scaled),
    );
  }
}

String _shortManageContact(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}

/// 打开某群的群聊详情。
///
/// 群聊复用与私聊相同的 `ChatPage` 会员门禁和消息入口；文本、贴纸、媒体分别
/// 进入 `ChatRuntime` 的群发送方法，不另建第二套权限实现。群语音/视频通话不在当前范围。
Future<void> openGroupChat(
  BuildContext context, {
  required String groupId,
  required String title,
  ChatDeleteConversationCallback? onDeleteConversation,
}) async {
  final identity = await CurrentUserContext.instance.resolve();
  final accountId = identity?.accountId ?? '';
  final ownerUserId = identity?.cidNumber ?? '';
  if (accountId.isEmpty || ownerUserId.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先在「我的 → 我的钱包」添加钱包账户')));
    return;
  }
  final runtime = ChatRuntime();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        conversationId: groupId,
        ownerUserId: ownerUserId,
        accountId: accountId,
        peerUserId: groupId,
        title: title,
        isGroup: true,
        onSendText: (text) =>
            runtime.sendGroupText(groupId: groupId, text: text),
        onSendSticker: (packId, stickerId) => runtime.sendGroupSticker(
          groupId: groupId,
          packId: packId,
          stickerId: stickerId,
        ),
        onSendMedia: (media, {onLocalCommitted}) => runtime.sendGroupAttachment(
          groupId: groupId,
          media: media,
          onLocalCommitted: onLocalCommitted,
        ),
        onResolveMediaPaths: (conversationId, contents) =>
            runtime.resolveCachedMediaPaths(
          conversationId: conversationId,
          contents: contents,
        ),
        onDownloadAttachment: (conversationId, controlPlaintext) =>
            runtime.downloadAttachment(
          conversationId: conversationId,
          controlPlaintext: controlPlaintext,
        ),
        onSync: () => runtime.retryOutgoing(conversationId: groupId),
        onStartRealtime: ({required onNotice, onDisconnected}) =>
            runtime.startRealtimeSync(
          onNotice: onNotice,
          onDisconnected: onDisconnected,
          retryOutgoingOnConnect: false,
        ),
        onDeleteConversation: onDeleteConversation ??
            () => runtime.deleteLocalConversation(groupId),
        onMarkRead: (readThroughMillis) => runtime.markConversationRead(
          conversationId: groupId,
          readThroughMillis: readThroughMillis,
        ),
      ),
    ),
  );
}

typedef DirectChatOpener = Future<void> Function(
  BuildContext context, {
  required String peerUserId,
  required String title,
});

/// 打开与目标 CID 的一对一聊天。
///
/// 发起方使用当前默认账户（CID 绑定账户）的 AccountId；冷热钱包均可作为默认账户。广场用户主页「消息」与联系人详情
/// 「消息」共用此入口，复用现有 Chat 运行态，避免重复拼装。
Future<void> openDirectChat(
  BuildContext context, {
  required String peerUserId,
  required String title,
}) async {
  final identity = await CurrentUserContext.instance.resolve();
  final sender = identity?.accountId ?? '';
  final ownerUserId = identity?.cidNumber ?? '';
  if (sender.isEmpty || ownerUserId.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先添加钱包账户并注册 CID')));
    return;
  }
  // 不能和自己发起聊天：所有私信入口的最后一道防线（广场主页/通讯录都走此收口）。
  if (peerUserId.trim() == ownerUserId) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('不能和自己发起聊天')));
    return;
  }
  final runtime = ChatRuntime();
  final conversationId = ChatRuntime.directConversationId(
    ownerUserId,
    peerUserId,
  );
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        conversationId: conversationId,
        ownerUserId: ownerUserId,
        accountId: sender,
        peerUserId: peerUserId,
        title: title,
        onSendText: (text) => runtime.sendText(
          peerUserId: peerUserId,
          conversationId: conversationId,
          text: text,
        ),
        onSendMedia: (media, {onLocalCommitted}) => runtime.sendMedia(
          peerUserId: peerUserId,
          conversationId: conversationId,
          media: media,
          onLocalCommitted: onLocalCommitted,
        ),
        onSendSticker: (packId, stickerId) => runtime.sendSticker(
          peerUserId: peerUserId,
          conversationId: conversationId,
          packId: packId,
          stickerId: stickerId,
        ),
        onResolveMediaPaths: (conversationId, contents) =>
            runtime.resolveCachedMediaPaths(
          conversationId: conversationId,
          contents: contents,
        ),
        onDownloadAttachment: (conversationId, controlPlaintext) =>
            runtime.downloadAttachment(
          conversationId: conversationId,
          controlPlaintext: controlPlaintext,
        ),
        onSync: () => runtime.retryOutgoing(
          conversationId: conversationId,
          recipientUserId: peerUserId,
        ),
        onStartRealtime: ({required onNotice, onDisconnected}) =>
            runtime.startRealtimeSync(
          onNotice: onNotice,
          onDisconnected: onDisconnected,
          retryOutgoingOnConnect: false,
        ),
        onDeleteConversation: () =>
            runtime.deleteLocalConversation(conversationId),
      ),
    ),
  );
}
