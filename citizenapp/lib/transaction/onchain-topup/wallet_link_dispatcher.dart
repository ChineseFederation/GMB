/// WalletConnect 外链来自本地打包的 Reown 页面，但最终目标由 WalletGuide 中用户选择的
/// 钱包决定。这里限制危险协议和触发来源，不按钱包品牌建立白名单，避免新钱包必须等
/// CitizenApp 发版才能连接。
enum WalletLinkSource {
  /// Reown 通过受控 JS bridge 明确请求打开钱包，包括自定义 scheme 与 Universal Link。
  walletOpenBridge,

  /// WebView 主框架直接导航；HTTP(S) 仍留在 WebView，只有钱包自定义 scheme 才外部打开。
  webViewNavigation,
}

enum WalletLinkDisposition { stayInWebView, openExternalWallet, blocked }

class WalletLinkDecision {
  const WalletLinkDecision(this.disposition, {this.uri});

  final WalletLinkDisposition disposition;
  final Uri? uri;
}

/// 系统外部打开注入点。测试以假实现验证失败和异常分支，生产由 `url_launcher` 提供。
typedef WalletUriLauncher = Future<bool> Function(Uri uri);

enum WalletLinkOpenResult { opened, invalid, blocked, failed }

/// WalletConnect 钱包链接分类与系统打开单源。
class WalletLinkDispatcher {
  WalletLinkDispatcher({required WalletUriLauncher launcher})
      : _launcher = launcher;

  final WalletUriLauncher _launcher;

  /// 这些协议不属于钱包打开能力；即使页面脚本请求，也不得交给系统。
  static const Set<String> _blockedSchemes = {
    'javascript',
    'data',
    'file',
    'blob',
    'about',
    'tel',
    'sms',
    'mailto',
    'geo',
  };

  static WalletLinkDecision classify(
    String rawUrl, {
    required WalletLinkSource source,
  }) {
    final value = rawUrl.trim();
    final uri = Uri.tryParse(value);
    if (value.isEmpty || uri == null || uri.scheme.isEmpty) {
      return const WalletLinkDecision(WalletLinkDisposition.blocked);
    }

    final scheme = uri.scheme.toLowerCase();
    if (_blockedSchemes.contains(scheme)) {
      // about/file/blob 是 WebView 自己的内部资源类型；其余危险协议同样不得外部打开。
      if (scheme == 'about' || scheme == 'file' || scheme == 'blob') {
        return WalletLinkDecision(
          WalletLinkDisposition.stayInWebView,
          uri: uri,
        );
      }
      return const WalletLinkDecision(WalletLinkDisposition.blocked);
    }

    if (scheme == 'http' || scheme == 'https') {
      // 普通网络资源继续由 WebView 加载；只有 Reown 明确发出的钱包打开事件，才把
      // Universal Link 交给系统，不能用域名白名单裁掉 WalletGuide 的其他钱包。
      return WalletLinkDecision(
        source == WalletLinkSource.walletOpenBridge
            ? WalletLinkDisposition.openExternalWallet
            : WalletLinkDisposition.stayInWebView,
        uri: uri,
      );
    }

    // WalletGuide 钱包可以声明各自的自定义 scheme。来源已被限制为本地 Reown 页面，
    // 因此这里只拦危险协议，不维护会过期的钱包品牌 / scheme 白名单。
    return WalletLinkDecision(
      WalletLinkDisposition.openExternalWallet,
      uri: uri,
    );
  }

  Future<WalletLinkOpenResult> open(
    String rawUrl, {
    required WalletLinkSource source,
  }) async {
    final decision = classify(rawUrl, source: source);
    if (decision.disposition == WalletLinkDisposition.blocked) {
      return WalletLinkOpenResult.blocked;
    }
    if (decision.disposition != WalletLinkDisposition.openExternalWallet ||
        decision.uri == null) {
      return WalletLinkOpenResult.invalid;
    }
    try {
      if (await _launcher(decision.uri!)) {
        return WalletLinkOpenResult.opened;
      }
    } catch (_) {
      // 专属链接异常也继续尝试下面的标准 WalletConnect URI。
    }

    // WalletGuide 个别钱包的专属 scheme 可能落后于已安装钱包版本。专属链接失败时，
    // 从其标准 `uri=wc:...` 参数提取 WalletConnect URI 再交给系统；这是协议级兜底，
    // 不按 OKX、MetaMask 等品牌建立兼容表，也不会阻止其他兼容钱包接管。
    final walletConnectUri = _nestedWalletConnectUri(decision.uri!);
    if (walletConnectUri != null) {
      try {
        if (await _launcher(walletConnectUri)) {
          return WalletLinkOpenResult.opened;
        }
      } catch (_) {
        // 外部钱包未安装或系统拒绝 URL 时，不把平台异常和配对 URI 上抛到 UI。
      }
    }
    return WalletLinkOpenResult.failed;
  }

  static Uri? _nestedWalletConnectUri(Uri walletUri) {
    final nested = walletUri.queryParameters['uri'];
    if (nested == null || nested.isEmpty) return null;
    final uri = Uri.tryParse(nested);
    if (uri == null || uri.scheme.toLowerCase() != 'wc') return null;
    return uri;
  }
}
