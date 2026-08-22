import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../8964/profile/models/citizen_profile.dart';
import '../8964/profile/models/profile_presentation.dart';
import '../8964/profile/services/citizen_profile_api.dart';
import '../8964/profile/services/citizen_profile_cache.dart';
import '../8964/profile/services/square_session_provider.dart';
import '../8964/profile/widgets/profile_avatar.dart';
import '../8964/services/square_api_client.dart';
import '../my/myid/current_user_context.dart';
import '../my/myid/register_identity_flow.dart';
import '../my/user/contact_book_page.dart';
import '../my/user/contact_service.dart';
import '../qr/scan_dispatch_flow.dart';
import '../ui/app_theme.dart';
import '../ui/widgets/identity_register_guide.dart';
import '../wallet/core/wallet_manager.dart';
import '../wallet/widgets/wallet_qr_dialog.dart';
import 'chat_page.dart';
import 'chat_payload.dart';
import 'chat_runtime.dart';
import 'crypto/mls_native.dart';
import 'chat_models.dart';
import 'chat_search_page.dart';
import 'group/ui/group_create_page.dart';
import 'group/ui/group_manage_page.dart';
import 'group/ui/open_group_chat.dart';
import 'storage/chat_store.dart';
import 'package:citizenapp/ui/app_layout.dart';

typedef ChatSendTextFactory = ChatSendTextCallback? Function(
    String peerCidNumber, String conversationId);
typedef ChatSyncFactory = ChatSyncCallback? Function(String peerCidNumber);
typedef ChatSendMediaFactory = ChatSendMediaCallback? Function(
  String peerCidNumber,
  String conversationId,
);
typedef ChatDownloadAttachmentFactory = ChatDownloadAttachmentCallback?
    Function(String peerCidNumber);

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

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  // 聊天页只做前台轻量轮询；离开页面或 App 退后台即停止，不做后台常驻扫描。
  static const _normalPollInterval = Duration(seconds: 15);
  static const _backoffPollInterval = Duration(seconds: 30);

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
  bool _polling = false;
  bool _realtimeConnecting = false;
  String? _error;
  Timer? _pollTimer;
  String? _realtimeWallet;
  Future<void> Function()? _stopRealtime;
  late final _ChatTabLifecycleObserver _lifecycleObserver;
  Future<void>? _coordinatorInFlight;
  bool _appResumed = false;

  /// 后台服务世代与本地加载世代分离。补发、Realtime 或 MLS 初始化即使耗时，
  /// 也不得延长“正在读取本地会话”，更不得用旧身份的晚到结果覆盖当前列表。
  int _backgroundSyncGeneration = 0;

  bool get _isActive =>
      (widget.selectedTab == null ||
          widget.selectedTab!.value == widget.tabIndex) &&
      _appResumed;

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _lifecycleObserver = _ChatTabLifecycleObserver(
      onResume: () {
        _appResumed = true;
        _requestCoordinate();
      },
      onPause: () {
        _appResumed = false;
        _pauseSync();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    widget.selectedTab?.addListener(_onSelectedTabChanged);
    // 本页常驻 IndexedStack；切换身份账户（CID 换绑 / 切钱包）后经
    // walletsRevision 广播重载，会话列表 accountId 立即切到新身份账户，
    // 不再等 App 退后台回前台。
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
    CitizenProfileCache.revision.removeListener(_onProfileRevision);
    WalletManager.walletsRevision.removeListener(_onWalletsChanged);
    widget.selectedTab?.removeListener(_onSelectedTabChanged);
    _pauseSync();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  void _onProfileRevision() {
    final event = CitizenProfileCache.revision.value;
    if (!mounted || event == null) return;
    final matches = _conversations.any(
      (preview) => !preview.isGroup && preview.peerCidNumber == event.cidNumber,
    );
    if (!matches) return;
    unawaited(_readCachedPeerProfiles(_conversations, force: true));
  }

  void _onSelectedTabChanged() {
    if (_isActive) {
      _requestCoordinate();
    } else {
      _pauseSync();
    }
  }

  /// init、进入 Tab、App resume 全部汇入同一个 coordinator；同一时刻只允许
  /// 一个 reload/sync 链，避免系统 UI 导致 lifecycle 抖动时重复初始化。
  void _requestCoordinate() {
    if (!mounted || !_isActive || _coordinatorInFlight != null) {
      return;
    }
    late final Future<void> created;
    created = _reload(syncFirst: true).whenComplete(() {
      if (identical(_coordinatorInFlight, created)) {
        _coordinatorInFlight = null;
      }
    });
    _coordinatorInFlight = created;
  }

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
  /// 新身份；网络与 MLS 等后台服务使用独立的 [_backgroundSyncGeneration]。
  int _reloadGeneration = 0;

  List<ChatConversationPreview> _withoutDeletingConversations(
    Iterable<ChatConversationPreview> conversations,
  ) =>
      conversations
          .where(
            (preview) => !_conversationDeletesInFlight.contains(
              preview.conversationId,
            ),
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
      final ownerCidNumber = widget.cidNumber ?? identity.cidNumber;
      if (!_isActive) {
        return;
      }
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        if (_cidNumber != ownerCidNumber) {
          // 私人备注属于当前 CID；切换身份时先同步清空，禁止旧身份备注闪现。
          _peerContactRemarks.clear();
        }
        _cidNumber = ownerCidNumber;
        _accountId = activeWallet;
      });
      if (ownerCidNumber.isEmpty) {
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
        ownerCidNumber: ownerCidNumber,
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
        serviceCidNumber = ownerCidNumber;
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
        _startBackgroundSync(
          accountId: serviceAccountId,
          cidNumber: serviceCidNumber,
          reloadGeneration: generation,
        );
      } else if (mounted && _isActive && generation == _reloadGeneration) {
        // 二级页返回只需恢复既有轮询/Realtime，不重复执行首次补发链。
        _configurePolling(serviceAccountId);
      }
    }
  }

  /// 本地首屏完成后静默收敛聊天服务。该 Future 不进入页面 loading/error，
  /// 服务失败时保留已经显示的本地列表，由后续轮询或下一次进入页面重试。
  void _startBackgroundSync({
    required String accountId,
    required String cidNumber,
    required int reloadGeneration,
  }) {
    if (!_isActive || widget.runtime == null) {
      return;
    }
    final generation = ++_backgroundSyncGeneration;
    unawaited(
      _runBackgroundSync(
        accountId: accountId,
        cidNumber: cidNumber,
        reloadGeneration: reloadGeneration,
        backgroundGeneration: generation,
      ),
    );
  }

  bool _isCurrentBackgroundSync({
    required String accountId,
    required String cidNumber,
    required int reloadGeneration,
    required int backgroundGeneration,
  }) {
    return mounted &&
        _isActive &&
        reloadGeneration == _reloadGeneration &&
        backgroundGeneration == _backgroundSyncGeneration &&
        accountId == _accountId &&
        cidNumber == _cidNumber;
  }

  Iterable<String> _directPeerCidNumbers(
    List<ChatConversationPreview> conversations,
  ) sync* {
    final seen = <String>{};
    for (final preview in conversations) {
      final cidNumber = preview.peerCidNumber.trim();
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
    final ownerCidNumber = _cidNumber;
    if (ownerCidNumber.isEmpty) return;
    final peers = _directPeerCidNumbers(conversations).toSet();
    try {
      final contacts = await _contactService.getContacts();
      if (!mounted || _cidNumber != ownerCidNumber) return;
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

  /// 对端公开资料按四个 CID 一组刷新，防止大聊天列表产生无界请求；未知会员投影保留
  /// 上一次确认有效展示，所有授权仍由会员业务自己的 finalized 门禁处理。
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
            final profile = (await _profileApi.fetchProfile(
              cidNumber,
              session: _profileSession,
            ))
                .preserveConfirmedMembership(_peerProfiles[cidNumber]);
            _peerProfiles[cidNumber] = profile;
            _resolvedPeerCidNumbers.add(cidNumber);
            _peerProfileMedia[cidNumber] =
                await _profileMediaCache.read(profile);
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

  Future<void> _runBackgroundSync({
    required String accountId,
    required String cidNumber,
    required int reloadGeneration,
    required int backgroundGeneration,
  }) async {
    try {
      await _retryOutgoingSilently();
      if (!_isCurrentBackgroundSync(
        accountId: accountId,
        cidNumber: cidNumber,
        reloadGeneration: reloadGeneration,
        backgroundGeneration: backgroundGeneration,
      )) {
        return;
      }
      final conversations = await widget.store.readConversationPreviews(
        ownerCidNumber: cidNumber,
        currentAccountId: accountId,
      );
      if (!_isCurrentBackgroundSync(
        accountId: accountId,
        cidNumber: cidNumber,
        reloadGeneration: reloadGeneration,
        backgroundGeneration: backgroundGeneration,
      )) {
        return;
      }
      final visible = _withoutDeletingConversations(conversations);
      setState(() => _conversations = visible);
      unawaited(_hydratePeerProfiles(visible));
    } catch (_) {
      // 后台服务错误不得抹掉本地首屏；下一次进入或轮询会继续重试。
    }
    if (_isCurrentBackgroundSync(
      accountId: accountId,
      cidNumber: cidNumber,
      reloadGeneration: reloadGeneration,
      backgroundGeneration: backgroundGeneration,
    )) {
      _configurePolling(accountId);
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
    if (_realtimeWallet != null && _realtimeWallet != activeWallet) {
      _pauseSync();
    }
    if (_stopRealtime != null) {
      return;
    }
    _schedulePoll(_normalPollInterval);
    unawaited(_startRealtime(activeWallet));
  }

  Future<bool> _startRealtime(String activeWallet) async {
    final runtime = widget.runtime;
    if (!_isActive || runtime == null || activeWallet.isEmpty) {
      return false;
    }
    if (_stopRealtime != null || _realtimeConnecting) {
      return _stopRealtime != null;
    }
    _realtimeConnecting = true;
    try {
      final stop = await runtime.startRealtimeSync(
        onNotice: () => _syncAndRefresh(activeWallet),
        onDisconnected: () async {
          // 账户级实时通道保留订阅并自行重连；这里只启动兜底轮询，不创建第二条
          // WebSocket，也不清空订阅 disposer。
          if (_isActive &&
              mounted &&
              widget.runtime != null &&
              _accountId.isNotEmpty) {
            _schedulePoll(_backoffPollInterval);
          }
        },
      );
      if (!mounted || !_isActive || _accountId != activeWallet) {
        await stop?.call();
        return false;
      }
      _stopRealtime = stop;
      _realtimeWallet = activeWallet;
      if (stop != null) {
        _stopPolling();
      }
      return stop != null;
    } catch (_) {
      return false;
    } finally {
      _realtimeConnecting = false;
    }
  }

  Future<void> _syncAndRefresh(String accountId) async {
    if (!_isActive) {
      return;
    }
    await _retryOutgoingSilently();
    final conversations = await widget.store.readConversationPreviews(
      ownerCidNumber: _cidNumber,
      currentAccountId: accountId,
    );
    if (mounted && _accountId == accountId) {
      final visible = _withoutDeletingConversations(conversations);
      setState(() {
        _conversations = visible;
      });
      unawaited(_hydratePeerProfiles(visible));
    }
  }

  void _schedulePoll(Duration delay) {
    if (!_isActive) {
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
    // 立即废止后台任务的 UI/轮询提交权；无法取消的底层 Future 即使晚到也静默丢弃。
    _backgroundSyncGeneration += 1;
    _stopPolling();
    final stop = _stopRealtime;
    _stopRealtime = null;
    _realtimeWallet = null;
    if (stop != null) {
      unawaited(stop());
    }
  }

  Future<void> _runPoll() async {
    if (!mounted ||
        !_isActive ||
        widget.runtime == null ||
        _accountId.isEmpty) {
      return;
    }
    if (_stopRealtime != null) {
      return;
    }
    if (_polling) {
      _schedulePoll(_backoffPollInterval);
      return;
    }
    _polling = true;
    var ok = true;
    try {
      ok = await _retryOutgoingSilently();
      final conversations = await widget.store.readConversationPreviews(
        ownerCidNumber: _cidNumber,
        currentAccountId: _accountId,
      );
      if (mounted) {
        final visible = _withoutDeletingConversations(conversations);
        setState(() {
          _conversations = visible;
        });
        unawaited(_hydratePeerProfiles(visible));
      }
    } catch (_) {
      ok = false;
    }
    _polling = false;
    if (_isActive &&
        mounted &&
        widget.runtime != null &&
        _accountId.isNotEmpty) {
      if (ok && await _startRealtime(_accountId)) {
        return;
      }
      _schedulePoll(ok ? _normalPollInterval : _backoffPollInterval);
    }
  }

  Future<({String cidNumber, String accountId})> _readIdentity() async {
    if (widget.cidNumber != null && widget.accountId != null) {
      return (cidNumber: widget.cidNumber!, accountId: widget.accountId!);
    }
    final runtime = widget.runtime;
    if (runtime != null) {
      final current = await runtime.readCurrentUser();
      if (current.accountId.isNotEmpty) {
        return current;
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
    final confirmed = await _confirmDeleteConversation(context);
    if (!confirmed || !mounted) {
      return;
    }
    unawaited(_deleteConversationInBackground(preview.conversationId));
  }

  void _openConversation(ChatConversationPreview preview) {
    if (!_requireChatIdentity()) return;
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
              ownerCidNumber: _cidNumber,
              accountId: _accountId,
              peerUserId: preview.peerCidNumber,
              title: preview.title,
              store: widget.store,
              onSendText: widget.sendTextFactory?.call(
                    preview.peerCidNumber,
                    preview.conversationId,
                  ) ??
                  (widget.runtime == null
                      ? null
                      : (text) => widget.runtime!.sendText(
                            peerCidNumber: preview.peerCidNumber,
                            conversationId: preview.conversationId,
                            text: text,
                          )),
              onSendMedia: widget.sendMediaFactory?.call(
                    preview.peerCidNumber,
                    preview.conversationId,
                  ) ??
                  (widget.runtime == null
                      ? null
                      : (media, {onLocalCommitted}) =>
                          widget.runtime!.sendMedia(
                            peerCidNumber: preview.peerCidNumber,
                            conversationId: preview.conversationId,
                            media: media,
                            onLocalCommitted: onLocalCommitted,
                          )),
              onSendSticker: widget.runtime == null
                  ? null
                  : (packId, stickerId) => widget.runtime!.sendSticker(
                        peerCidNumber: preview.peerCidNumber,
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
              onDownloadAttachment: widget.downloadAttachmentFactory?.call(
                    preview.peerCidNumber,
                  ) ??
                  (widget.runtime == null
                      ? null
                      : (String conversationId, String controlPlaintext) =>
                          widget.runtime!.downloadAttachment(
                            conversationId: conversationId,
                            controlPlaintext: controlPlaintext,
                          )),
              onSync: widget.syncFactory?.call(preview.peerCidNumber) ??
                  (widget.runtime == null
                      ? null
                      : () => widget.runtime!.retryOutgoing(
                            conversationId: preview.conversationId,
                            recipientCidNumber: preview.peerCidNumber,
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
              initialProfile: _peerProfiles[preview.peerCidNumber],
              initialProfileMedia: _peerProfileMedia[preview.peerCidNumber],
              profileApi: _profileApi,
              profileCache: _profileCache,
              profileMediaCache: _profileMediaCache,
              sessionProvider: _sessionProvider,
            ),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: AppTheme.scaffoldBg,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _reload(syncFirst: true),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _ChatHeader(onAction: _onEntryAction),
                  ),
                  if (_error != null)
                    SliverToBoxAdapter(child: _ErrorBanner(message: _error!)),
                  SliverToBoxAdapter(
                    child: _SearchEntry(onTap: () => unawaited(_openSearch())),
                  ),
                  if (_loading && _conversations.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ChatSyncNotice(),
                    )
                  else if (_accountId.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoAccount(),
                    )
                  else if (_cidNumber.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: IdentityRegisterGuide(
                        description: '注册后即可使用聊天与通讯录。',
                        onRegistered: _requestCoordinate,
                      ),
                    )
                  else if (_conversations.isNotEmpty)
                    SliverList.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final preview = _conversations[index];
                        return _ConversationTile(
                          preview: preview,
                          profile: _peerProfiles[preview.peerCidNumber],
                          contactRemark:
                              _peerContactRemarks[preview.peerCidNumber],
                          profileMedia:
                              _peerProfileMedia[preview.peerCidNumber],
                          profileResolved: _resolvedPeerCidNumbers.contains(
                            preview.peerCidNumber,
                          ),
                          profileApi: _profileApi,
                          profileSession: _profileSession,
                          isFirst: index == 0,
                          isLast: index == _conversations.length - 1,
                          onTap: () => _openConversation(preview),
                          onDelete: () =>
                              _confirmAndDeleteConversation(preview),
                          onManage: preview.isGroup
                              ? () => _openGroupManage(preview)
                              : null,
                        );
                      },
                    )
                  else
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyConversationList(),
                    ),
                ],
              ),
            ),
            // 进度线覆盖在聊天标题/加号上方，不进入 sliver 高度计算；
            // 出现和消失均不得推动搜索框和聊天卡片。
            if (_loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: LinearProgressIndicator(
                    key: const ValueKey('chat-sync-progress'),
                    minHeight: AppLayout.scaled(context, 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatTabLifecycleObserver extends WidgetsBindingObserver {
  _ChatTabLifecycleObserver({required this.onResume, required this.onPause});

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

/// 弹窗底色：浅板岩，100% 不透明（实心遮住页面，绝不透出背景）。
const Color _entryMenuColor = Color(0xFF66727D);

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onAction});

  final ValueChanged<_ChatEntryAction> onAction;

  /// 以加号按钮的**实际屏幕坐标**定位弹窗，使三角顶点精确对齐加号中心。
  ///
  /// 不用 `PopupMenuButton`：它的水平位置由框架按可用空间决定，拿不到确定的
  /// 锚点，三角只能靠猜偏移量对齐。
  Future<void> _open(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchorCenterX = origin.dx + box.size.width / 2;
    final top = origin.dy + box.size.height + 2;

    final selected = await showGeneralDialog<_ChatEntryAction>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: '关闭新建菜单',
      // 不压黑整屏：只靠弹窗自身的深色区分层次。
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) =>
          _ChatEntryMenu(anchorCenterX: anchorCenterX, top: top),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (selected != null) onAction(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 右内边距略大于左侧：把圆圈加号稍向左收，配合弹窗右移让三角尖对准圆心。
      padding: const EdgeInsets.fromLTRB(20, 18, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '聊天',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 24),
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          // Builder 提供按钮自身的 context，用于取其屏幕坐标做三角对齐。
          // 圆圈与加号一起等比缩小：圈 28、描边 1.25、加号 16。
          Builder(
            builder: (buttonContext) => Container(
              key: const ValueKey('chat-add-button'),
              width: AppLayout.scaled(context, 28),
              height: AppLayout.scaled(context, 28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 1.25),
              ),
              child: IconButton(
                tooltip: '新建',
                padding: EdgeInsets.zero,
                iconSize: AppLayout.scaled(context, 16),
                constraints: BoxConstraints.tightFor(
                  width: AppLayout.scaled(context, 28),
                  height: AppLayout.scaled(context, 28),
                ),
                icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
                onPressed: () => unawaited(_open(buttonContext)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 加号弹窗本体：上方凸出三角 + 淡深色圆角面板。
class _ChatEntryMenu extends StatelessWidget {
  const _ChatEntryMenu({required this.anchorCenterX, required this.top});

  /// 加号按钮中心的屏幕横坐标 —— 三角顶点要对齐它。
  final double anchorCenterX;
  final double top;

  // 面板按内容自适应：16(左) + 20(图标) + 12(间距) + 约45(三字) + 22(右) ≈ 115，
  // 取 116；右内边距(22)略大于左(16)，右侧比左侧宽一点点。
  static const double _width = 116;
  static const double _caretWidth = 14;
  static const double _caretHeight = 7;
  static const double _edgeGap = 8;

  /// 面板圆角半径（与下方 borderRadius 一致）；三角必须落在圆角以内的平边上。
  static const double _panelRadius = 12;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    // 让三角顶点落在加号中心：按"三角距菜单右边 24"反推菜单左边界（面板整体右移，
    // 三角与右圆角留出足够间距），再夹到屏幕内；夹取后用实际左边界回算三角位置。
    final rawLeft = anchorCenterX - _width + 24;
    final left = rawLeft.clamp(_edgeGap, screenWidth - _width - _edgeGap);
    // 三角中心须离两侧至少 圆角(12)+半个三角(7)，保证三角底完全落在平边、不压圆角。
    final caretCenter = (anchorCenterX - left).clamp(
      _panelRadius + _caretWidth / 2,
      _width - _panelRadius - _caretWidth / 2,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: caretCenter - _caretWidth / 2),
                child: CustomPaint(
                  size: const Size(_caretWidth, _caretHeight),
                  painter: _CaretPainter(),
                ),
              ),
              // 面板本身用 Material：弹窗不在 Scaffold 之下，InkWell 需要它做祖先。
              Material(
                color: _entryMenuColor,
                borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: _width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: AppLayout.scaled(context, 4)),
                      for (final item in _chatEntryItems)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(item.action),
                          child: SizedBox(
                            // 411×914 基准视口下每项约 40，高度全部属于可点击区域。
                            height: AppLayout.scaled(context, 40),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 22, 0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: AppLayout.scaled(context, 20),
                                    height: AppLayout.scaled(context, 20),
                                    child: Center(
                                      child: item.asset != null
                                          ? SvgPicture.asset(
                                              item.asset!,
                                              width: AppLayout.scaled(
                                                context,
                                                18,
                                              ),
                                              height: AppLayout.scaled(
                                                context,
                                                18,
                                              ),
                                              colorFilter:
                                                  const ColorFilter.mode(
                                                Colors.white,
                                                BlendMode.srcIn,
                                              ),
                                            )
                                          : Icon(
                                              item.icon,
                                              size:
                                                  AppLayout.scaled(context, 20),
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                  SizedBox(
                                      width: AppLayout.scaled(context, 12)),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AppLayout.scaled(context, 15),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: AppLayout.scaled(context, 4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 弹窗顶部凸出的三角，与面板同色；**顶角带圆弧**，不做尖锐尖角。
class _CaretPainter extends CustomPainter {
  /// 顶角圆弧的横向收进量：越大顶角越圆。
  static const double _tipInset = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(half - _tipInset, _tipInset)
      // 控制点落在真正的顶点上，画出一段圆弧过渡。
      ..quadraticBezierTo(half, 0, half + _tipInset, _tipInset)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = _entryMenuColor);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => false;
}

class _ConversationTile extends StatelessWidget {
  // 会话列表首尾共享圆角容器，中间项保持连续边框；单聊头像仅以账户标识生成本地占位图。
  const _ConversationTile({
    required this.preview,
    required this.profile,
    required this.contactRemark,
    required this.profileMedia,
    required this.profileResolved,
    required this.profileApi,
    required this.profileSession,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
    this.onManage,
  });

  final ChatConversationPreview preview;
  final CitizenProfile? profile;
  final String? contactRemark;
  final CitizenProfileMediaSnapshot? profileMedia;
  final bool profileResolved;
  final CitizenProfileApi profileApi;
  final SquareSession? profileSession;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final subtitle = preview.lastMessage.trim().isEmpty
        ? '暂无消息'
        : preview.lastMessage.trim();
    final publicName = preview.isGroup
        ? preview.title
        : ProfilePresentation.forIdentityKey(
            preview.peerCidNumber,
          ).resolveDisplayName(
            publicName: profile?.displayName ?? preview.title,
          );
    final remark = contactRemark?.trim() ?? '';
    final title = !preview.isGroup && remark.isNotEmpty
        ? '$remark（$publicName）'
        : publicName;
    return Dismissible(
      key: ValueKey('chat-conversation-${preview.conversationId}'),
      direction: DismissDirection.endToStart,
      background: const _DeleteDismissBackground(),
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      child: _ListTileShell(
        title: title,
        subtitle: subtitle,
        trailing: _conversationTime(preview.lastUpdatedAt),
        unreadCount: preview.unreadCount,
        onTap: onTap,
        onLongPress: onManage,
        isGroup: preview.isGroup,
        peerCidNumber: preview.peerCidNumber,
        profile: profile,
        profileMedia: profileMedia,
        profileResolved: profileResolved,
        profileApi: profileApi,
        profileSession: profileSession,
        isFirst: isFirst,
        isLast: isLast,
      ),
    );
  }
}

/// 顶部搜索入口：点击进入 [ChatSearchPage]（会话 / 联系人 / 聊天记录）。
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaled(context, 16),
              vertical: AppLayout.scaled(context, 12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: AppLayout.scaled(context, 20),
                  color: AppTheme.textTertiary,
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                Expanded(
                  child: Text(
                    '搜索会话、联系人和聊天记录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: AppLayout.scaled(context, 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteDismissBackground extends StatelessWidget {
  const _DeleteDismissBackground();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.scaled(context, 16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: AppLayout.scaled(context, 20)),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListTileShell extends StatelessWidget {
  const _ListTileShell({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.unreadCount,
    required this.onTap,
    required this.peerCidNumber,
    required this.profile,
    required this.profileMedia,
    required this.profileResolved,
    required this.profileApi,
    required this.profileSession,
    required this.isFirst,
    required this.isLast,
    this.onLongPress,
    this.isGroup = false,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final int unreadCount;
  final VoidCallback onTap;
  final String peerCidNumber;
  final CitizenProfile? profile;
  final CitizenProfileMediaSnapshot? profileMedia;
  final bool profileResolved;
  final CitizenProfileApi profileApi;
  final SquareSession? profileSession;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onLongPress;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(AppTheme.radiusLg) : Radius.zero,
      bottom: isLast ? const Radius.circular(AppTheme.radiusLg) : Radius.zero,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.scaled(context, 16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: radius,
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
              child: Row(
                children: [
                  if (isGroup)
                    CircleAvatar(
                      radius: AppLayout.scaled(context, 22),
                      backgroundColor: AppTheme.primary.withAlpha(20),
                      child: const Icon(
                        Icons.groups_outlined,
                        color: AppTheme.primary,
                      ),
                    )
                  else
                    ProfileAvatar(
                      size: AppLayout.scaled(context, 44),
                      seed: peerCidNumber,
                      imagePath: profileMedia?.avatarPath,
                      imageUrl:
                          profile?.avatarObjectKey?.trim().isNotEmpty == true
                              ? profileApi.mediaUrl(
                                  profile!.avatarObjectKey!,
                                  updatedAt: profile!.updatedAt,
                                )
                              : null,
                      imageHeaders: profileSession == null
                          ? null
                          : <String, String>{
                              'authorization':
                                  'Bearer ${profileSession!.sessionToken}',
                            },
                      userImageSet: profileResolved
                          ? profile?.avatarObjectKey?.trim().isNotEmpty == true
                          : true,
                      identityLevel: profile?.identityLevel,
                      membershipLevel: profile?.membershipLevel,
                      membershipActive: profile?.membershipActive ?? false,
                      showBadge: profileResolved,
                    ),
                  SizedBox(width: AppLayout.scaled(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppLayout.scaled(context, 4)),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 13),
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppLayout.scaled(context, 10)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trailing,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        SizedBox(height: AppLayout.scaled(context, 6)),
                        CircleAvatar(
                          radius: AppLayout.scaled(context, 10),
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            '$unreadCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppLayout.scaled(context, 11),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.red,
          fontSize: AppLayout.scaled(context, 12),
        ),
      ),
    );
  }
}

class _NoAccount extends StatelessWidget {
  const _NoAccount();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 80),
        child: Text(
          '请先在「我的 → 我的钱包」添加钱包账户',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppLayout.scaled(context, 15),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ChatSyncNotice extends StatelessWidget {
  const _ChatSyncNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 80),
        child: Text(
          '正在读取本地会话',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppLayout.scaled(context, 15),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyConversationList extends StatelessWidget {
  const _EmptyConversationList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 80),
        child: Text(
          '暂无会话',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppLayout.scaled(context, 15),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

String _conversationTime(DateTime value) {
  // 会话时间按本地日历分层展示，避免把跨日消息仍误显示成纯时分。
  final local = value.toLocal();
  final now = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (difference == 1) return '昨天';
  if (difference > 1 && difference < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[local.weekday - 1];
  }
  return '${local.month}/${local.day}';
}

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
