import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:citizenapp/ui/app_theme.dart';
import 'topup_api.dart';
import 'topup_erc20.dart';
import 'topup_models.dart';
import 'wallet_link_dispatcher.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// WebView WalletConnect 返回结果：付款交易哈希 + 付款前已绑定账户的短期意图。
class TopupWebResult {
  const TopupWebResult({
    required this.txHash,
    required this.paymentIntent,
    required this.payerAddress,
  });

  final String txHash;
  final String paymentIntent;
  final String payerAddress;
}

/// WalletConnect 支付页(方案 A):在 WebView 内加载打包的 AppKit JS 页,连自托管钱包并发
/// ERC-20 转账。App 只把「币+链+收款地址+应付额」交给页面,拿回 txHash;不引 reown Dart SDK
/// (与 flutter_secure_storage 10 / flutter_chat_core 冲突),故走 webview 里的 JS SDK。
class TopupWebviewPage extends StatefulWidget {
  const TopupWebviewPage({
    super.key,
    required this.rail,
    required this.package,
    required this.recvAddress,
    required this.accountId,
    required this.api,
  });

  final TopupRail rail;
  final TopupPackage package;
  final String recvAddress;
  final String accountId;
  final TopupApi api;

  /// Reown Project ID 是公开客户端标识，不是授权凭据。生产只登记一个 CitizenApp
  /// 项目，因此这里固定唯一真源，禁止构建参数恢复第二条项目配置轨道。
  static const projectId = '8830074307d80484b839db4eb10b1f2c';

  @override
  State<TopupWebviewPage> createState() => _TopupWebviewPageState();
}

class _TopupWebviewPageState extends State<TopupWebviewPage> {
  late final WebViewController _controller;
  late final WalletLinkDispatcher _walletLinks;
  String? _error;
  String? _paymentIntent;
  bool _creatingIntent = false;
  bool _openingWallet = false;

  @override
  void initState() {
    super.initState();
    _walletLinks = WalletLinkDispatcher(
      launcher: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('TopupBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onPageFinished: (_) => _injectAndStart(),
        ),
      )
      ..loadFlutterAsset('assets/topup/walletconnect.html');
  }

  /// 主框架中的普通 HTTP(S) 仍由 WebView 加载；钱包自定义 scheme 才交给系统。
  ///
  /// Reown 的 HTTPS Universal Link 由 JS bridge 明确标记后走 [_openWalletLink]，不能在
  /// 这里把所有 HTTPS 导航外部化，否则 Relay、图标和条款页都会被误送到浏览器。
  Future<NavigationDecision> _onNavigation(NavigationRequest request) async {
    final decision = WalletLinkDispatcher.classify(
      request.url,
      source: WalletLinkSource.webViewNavigation,
    );
    if (decision.disposition == WalletLinkDisposition.stayInWebView) {
      return NavigationDecision.navigate;
    }
    if (decision.disposition == WalletLinkDisposition.openExternalWallet) {
      await _openWalletLink(
        request.url,
        source: WalletLinkSource.webViewNavigation,
      );
    }
    return NavigationDecision.prevent;
  }

  /// 串行打开外部钱包，避免 Reown 同一次点击的重复事件同时唤起两个系统窗口。
  Future<void> _openWalletLink(
    String rawUrl, {
    required WalletLinkSource source,
  }) async {
    if (_openingWallet) return;
    _openingWallet = true;
    final result = await _walletLinks.open(rawUrl, source: source);
    _openingWallet = false;
    if (!mounted || result == WalletLinkOpenResult.opened) return;

    final message = switch (result) {
      WalletLinkOpenResult.blocked => '该链接不是可打开的钱包链接',
      WalletLinkOpenResult.invalid => '钱包链接无效，请重新选择钱包',
      WalletLinkOpenResult.failed => '未能打开该钱包，请确认钱包已安装或选择其他钱包',
      WalletLinkOpenResult.opened => '',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _injectAndStart() async {
    if (TopupWebviewPage.projectId.isEmpty) {
      setState(() => _error = 'WalletConnect 未配置（缺少 Project ID）');
      return;
    }
    // 收款金额与 ERC-20 calldata 在 Dart 侧构造(复用已验证的编码器),页面只负责签发。
    final data = encodeErc20Transfer(
      widget.recvAddress,
      widget.package.payAmountValue,
    );
    final params = jsonEncode({
      'projectId': TopupWebviewPage.projectId,
      'caip2': widget.rail.caip2,
      'chainId': widget.rail.chainId,
      'to': widget.rail.tokenContract,
      'data': data,
      'token': widget.rail.token,
      'label': widget.rail.label,
      'payDisplay': widget.package.payDisplay,
    });
    await _controller.runJavaScript(
      'window.__TOPUP__=$params; if(window.startTopup){window.startTopup();}',
    );
  }

  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (payload['kind'] == 'external_wallet') {
      await _openWalletLink(
        payload['url']?.toString() ?? '',
        source: WalletLinkSource.walletOpenBridge,
      );
      return;
    }
    if (payload['kind'] == 'connected') {
      final payer = payload['payer']?.toString() ?? '';
      if (payer.isEmpty || _creatingIntent || _paymentIntent != null) return;
      _creatingIntent = true;
      try {
        final intent = await widget.api.createIntent(
          token: widget.rail.token,
          packageId: widget.package.packageId,
          accountId: widget.accountId,
          payerAddress: payer,
        );
        if (intent.token.isEmpty) {
          throw const TopupApiException('充值服务未返回付款意图');
        }
        _paymentIntent = intent.token;
        await _controller.runJavaScript(
          'if(window.submitTopupPayment){window.submitTopupPayment();}',
        );
      } on TopupApiException catch (error) {
        if (!mounted) return;
        setState(() => _error = error.message);
      } finally {
        _creatingIntent = false;
      }
      return;
    }
    if (payload['kind'] == 'paid') {
      final txHash = payload['txHash']?.toString() ?? '';
      final payer = payload['payer']?.toString() ?? '';
      final paymentIntent = _paymentIntent;
      if (txHash.isEmpty || payer.isEmpty || paymentIntent == null) return;
      Navigator.of(context).pop(
        TopupWebResult(
          txHash: txHash,
          paymentIntent: paymentIntent,
          payerAddress: payer,
        ),
      );
      return;
    }
    final error = payload['error']?.toString() ?? '支付未完成';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('连接钱包支付'), centerTitle: true),
      body: _error != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
