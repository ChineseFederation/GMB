import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';
import 'package:citizenapp/rpc/chain_bootstrap_api.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/wallet/core/device_subkey.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';

/// 广场登录态提供器（全 App 共享单例）。
///
/// 后端会话握手用**当前 CID 的 P-256 硬件设备子钥静默签名**（不读 seed、不弹
/// 生物识别）换取 session token，由 [SquareApiClient] 内部按 accountId 缓存复用。
///
/// 已有子钥直接静默登录。只有实际登录被 Worker 明确拒绝为 `device_not_registered` 时，
/// 才鉴权一次生成并登记子钥，然后重试原登录；页面门禁不检查、不生成设备子钥。
class SquareSessionProvider {
  SquareSessionProvider({
    SquareApiClient? client,
    WalletManager? walletManager,
    DeviceSubkey? deviceSubkey,
    CurrentUserContext? currentUserContext,
    ChainBootstrapApi? bootstrapApi,
  })  : _client = client ?? SquareApiClient(),
        _walletManager = walletManager ?? WalletManager(),
        _deviceSubkey = deviceSubkey ?? DeviceSubkey(),
        _currentUserContext = currentUserContext,
        _bootstrapApi = bootstrapApi ?? ChainBootstrapApi();

  static final SquareSessionProvider instance = SquareSessionProvider();

  final SquareApiClient _client;
  final WalletManager _walletManager;
  final DeviceSubkey _deviceSubkey;
  final CurrentUserContext? _currentUserContext;
  final ChainBootstrapApi _bootstrapApi;

  CurrentUserContext get _currentUser =>
      _currentUserContext ?? CurrentUserContext.instance;

  /// 返回当前默认用户的可用 session；访客返回 null（调用方按不可用处理）。
  ///
  /// **身份主键 = CID 号**：会话 `accountId` 取当前默认账户，P-256 子钥按该 CID
  /// 隔离。冷热账户走同一静默设备会话；只有设备首次登记的 sr25519 证明区分热签/冷签。
  Future<SquareSession?> ensureSession() async {
    final current = await _currentUser.resolve();
    if (current == null || current.accountId.isEmpty) return null;
    final session = await _client.ensureSession(
      accountId: current.accountId,
      signLoginPayload: (context, loginMessage) async {
        _requireCurrentAccount(current.accountId, context);
        // 会话握手 = 非用户动权 → 按挑战 CID 选择 P-256 硬件子钥静默签名。
        // CID 来自 Cloudflare finalized 用户投影，不再为登录预读链。
        final raw = await _deviceSubkey.signRawHex(
          context.cidNumber,
          loginMessage,
        );
        return '0x$raw';
      },
      onDeviceNotRegistered: (context) async {
        _requireCurrentAccount(current.accountId, context);
        await _registerMissingDeviceSubkey(
          await _bindingForContext(context),
        );
      },
    );
    await _activateSessionBinding(session);
    return session;
  }

  /// Worker 明确返回 401 后清除当前身份账户的本地缓存并重新握手一次。
  ///
  /// 仅供已经收到未授权响应的前台请求调用；普通首次加载仍走 [ensureSession] 的缓存与
  /// in-flight 去重，避免把每次页面进入都放大成新的登录挑战。
  Future<SquareSession?> refreshSession() async {
    final current = await _currentUser.resolve();
    if (current == null || current.accountId.isEmpty) return null;
    _client.clearSession(current.accountId);
    return ensureSession();
  }

  /// 已由精确 finalized 交易结果确认换绑后，为目标账户建立新会话。
  ///
  /// 本入口不再自行解析身份或读链；Worker 登录挑战仍会按链上当前绑定 fail-closed。
  /// 只供同一次换绑交接提交目标密文使用。
  Future<SquareSession?> ensureSessionForAccountId(String accountId) async {
    final binding = await _walletManager.accountDataBindingForAccountId(
      accountId,
    );
    return _client.ensureSession(
      accountId: accountId,
      signLoginPayload: (context, loginMessage) async {
        if (context.accountId != accountId ||
            context.cidNumber != binding.cidNumber ||
            context.bindingRevision != binding.bindingRevision) {
          throw const WalletAuthException('换绑目标会话与 finalized 绑定不一致');
        }
        final raw = await _deviceSubkey.signRawHex(
          binding.cidNumber,
          loginMessage,
        );
        return '0x$raw';
      },
      onDeviceNotRegistered: (_) => _registerMissingDeviceSubkey(binding),
    );
  }

  /// Worker 是设备登记状态真源；只有它明确报告缺钥时才进入一次钱包鉴权。
  Future<void> _registerMissingDeviceSubkey(AccountDataBinding binding) async {
    await _walletManager.registerDeviceSubkeyForBinding(binding);
    _currentUser.invalidate();
  }

  Future<AccountDataBinding> _bindingForContext(
    SquareLoginContext context,
  ) async {
    final existing = await _walletManager.readAccountDataBindingForAccountId(
      context.accountId,
    );
    if (existing != null &&
        existing.cidNumber == context.cidNumber &&
        existing.bindingRevision == context.bindingRevision) {
      return existing;
    }
    final manifest = await _bootstrapApi.fetchManifest();
    return AccountDataBinding(
      genesisHash: manifest.chain.genesisHash,
      cidNumber: context.cidNumber,
      bindingRevision: context.bindingRevision,
      accountId: context.accountId,
    );
  }

  Future<void> _activateSessionBinding(SquareSession session) async {
    final binding = await _bindingForContext(
      SquareLoginContext(
        cidNumber: session.cidNumber,
        bindingRevision: session.bindingRevision,
        accountId: session.accountId,
      ),
    );
    await _walletManager.activateAccountDataBinding(
      genesisHash: binding.genesisHash,
      cidNumber: binding.cidNumber,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
    );
    _currentUser.invalidate();
  }

  static void _requireCurrentAccount(
    String expectedAccountId,
    SquareLoginContext context,
  ) {
    if (context.accountId != expectedAccountId) {
      throw const WalletAuthException('Cloudflare 登录挑战与当前默认账户不一致');
    }
  }
}
