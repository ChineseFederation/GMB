import 'package:flutter/foundation.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/wallet/core/default_account_service.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';

/// 普通业务的当前用户快照。
///
/// 当前用户只由钱包列表第一名决定；[binding] 只是该账户最近一次经 finalized
/// 动作或 Cloudflare `users` 投影确认后的本机公开缓存，不是第二授权真源。
class CurrentUser {
  const CurrentUser({required this.account, required this.binding});

  final DefaultAccount account;
  final AccountDataBinding? binding;

  String get accountId => account.accountId;
  String get ss58Address => account.ss58Address;
  String get cidNumber => binding?.cidNumber ?? '';
  int get bindingRevision => binding?.bindingRevision ?? 0;
  bool get isRegistered => binding != null;
}

typedef CurrentUserBindingReader = Future<AccountDataBinding?> Function(
  String accountId,
);

/// Chat、通讯录、主页和动态共用的本机当前用户入口。
///
/// 本类绝不读取链、绝不启动 smoldot，也绝不遍历其它钱包账户寻找 CID。默认账户
/// 没有本机绑定时返回未注册/待 Cloudflare 确认状态；调用方可建立 Cloudflare 会话，
/// 会话成功后激活精确绑定并调用 [invalidate]。网络故障不得删除任何 CID 数据。
class CurrentUserContext {
  CurrentUserContext({
    WalletManager? walletManager,
    DefaultAccountReader? defaultAccountReader,
    CurrentUserBindingReader? bindingReader,
  })  : _walletManager = walletManager ?? WalletManager(),
        _bindingReader = bindingReader {
    _defaultAccountReader = defaultAccountReader ??
        DefaultAccountService(walletManager: _walletManager);
  }

  static CurrentUserContext _instance = CurrentUserContext();
  static CurrentUserContext get instance => _instance;

  @visibleForTesting
  static set debugInstance(CurrentUserContext context) => _instance = context;

  @visibleForTesting
  static void resetDebugInstance() => _instance = CurrentUserContext();

  final WalletManager _walletManager;
  late final DefaultAccountReader _defaultAccountReader;
  final CurrentUserBindingReader? _bindingReader;

  CurrentUser? _cached;
  int _cachedRevision = -1;
  Future<CurrentUser?>? _inflight;
  int? _inflightRevision;
  int _generation = 0;

  Future<CurrentUser?> resolve() async {
    final revision = WalletManager.walletsRevision.value;
    final cached = _cached;
    if (cached != null && _cachedRevision == revision) return cached;
    final inflight = _inflight;
    if (inflight != null && _inflightRevision == revision) return inflight;

    final generation = _generation;
    final future = _resolveFresh(revision, generation);
    _inflight = future;
    _inflightRevision = revision;
    try {
      return await future;
    } finally {
      if (identical(_inflight, future)) {
        _inflight = null;
        _inflightRevision = null;
      }
    }
  }

  Future<String?> accountId() async => (await resolve())?.accountId;

  Future<AccountDataBinding?> binding() async => (await resolve())?.binding;

  Future<CurrentUser?> _resolveFresh(int revision, int generation) async {
    final account = await _defaultAccountReader.getDefaultAccount();
    if (account == null) return null;
    final binding = await (_bindingReader?.call(account.accountId) ??
        _walletManager.readAccountDataBindingForAccountId(account.accountId));
    final current = CurrentUser(account: account, binding: binding);
    if (_generation == generation &&
        WalletManager.walletsRevision.value == revision) {
      _cached = current;
      _cachedRevision = revision;
    }
    return current;
  }

  /// finalized 动作或 Cloudflare 会话确认绑定后显式失效；不会删除任何用户数据。
  void invalidate() {
    _generation++;
    _cached = null;
    _cachedRevision = -1;
    _inflight = null;
    _inflightRevision = null;
  }
}
