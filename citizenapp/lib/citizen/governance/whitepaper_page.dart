import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:citizenapp/ui/app_layout.dart';
import 'package:citizenapp/ui/app_theme.dart';

/// 公民链白皮书的公开唯一阅读地址。
///
/// 该官网页唯一读取 `citizenweb/src/whitepaper.md`；CitizenApp 不内置、
/// 复制或另行维护白皮书正文，避免形成第二真源。
const String citizenWhitepaperUrl = 'https://www.crcfrcn.com/whitepaper';

/// 只允许白皮书主文档在当前 WebView 内导航。
///
/// 静态资源请求不是主框架导航，不经过此判断；页内锚点仍保持
/// `/whitepaper#...`。网站导航栏的其它链接不得把该页变成通用浏览器。
@visibleForTesting
bool isCitizenWhitepaperNavigationAllowed(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return false;
  return uri.scheme == 'https' &&
      uri.host == 'www.crcfrcn.com' &&
      uri.path == '/whitepaper' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort;
}

class CitizenWhitepaperPage extends StatefulWidget {
  const CitizenWhitepaperPage({super.key});

  @override
  State<CitizenWhitepaperPage> createState() => _CitizenWhitepaperPageState();
}

class _CitizenWhitepaperPageState extends State<CitizenWhitepaperPage> {
  late final WebViewController _controller;
  var _loadingProgress = 0;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.scaffoldBg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loadError = null;
              _loadingProgress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loadingProgress = 100);
          },
          onWebResourceError: (error) {
            // iframe/图片等子资源错误不得覆盖已成功显示的主文档。
            if (error.isForMainFrame != true || !mounted) return;
            setState(() => _loadError = '白皮书加载失败，请重试');
          },
          onNavigationRequest: (request) =>
              isCitizenWhitepaperNavigationAllowed(request.url)
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent,
        ),
      )
      ..loadRequest(Uri.parse(citizenWhitepaperUrl));
  }

  void _retry() {
    setState(() {
      _loadError = null;
      _loadingProgress = 0;
    });
    _controller.loadRequest(Uri.parse(citizenWhitepaperUrl));
  }

  @override
  Widget build(BuildContext context) {
    final error = _loadError;
    return Scaffold(
      appBar: AppBar(title: const Text('公民链白皮书'), centerTitle: true),
      body: Stack(
        children: [
          if (error == null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: AppTheme.textTertiary,
                      size: 40,
                    ),
                    SizedBox(height: AppLayout.scaled(context, 12)),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    SizedBox(height: AppLayout.scaled(context, 12)),
                    FilledButton(onPressed: _retry, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          if (error == null && _loadingProgress < 100)
            LinearProgressIndicator(
              key: const ValueKey('citizen-whitepaper-load-progress'),
              minHeight: AppLayout.scaled(context, 2),
              value: _loadingProgress == 0 ? null : _loadingProgress / 100,
            ),
        ],
      ),
    );
  }
}
