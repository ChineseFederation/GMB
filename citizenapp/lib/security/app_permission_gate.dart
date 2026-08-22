import 'package:flutter/material.dart';
import 'package:citizenapp/security/app_permission_bootstrap.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 首次启动权限说明入口。
///
/// 该页只解释并申请通知权限；网络权限由系统安装时自动授予，
/// 相机和相册等敏感权限仍在用户进入扫码、选图、保存二维码时由对应功能申请。
class AppPermissionGate extends StatefulWidget {
  const AppPermissionGate({
    super.key,
    required this.child,
    this.guideStateLoader,
    this.guideStateWriter,
    this.notificationPermissionRequester,
    this.operationTimeout = const Duration(seconds: 5),
  });

  final Widget child;

  /// 以下注入点只用于钉死 UserIsar 永久 pending/重试语义；生产固定使用
  /// [AppPermissionBootstrap]，不会绕过用户设置真源。
  @visibleForTesting
  final Future<bool> Function()? guideStateLoader;

  @visibleForTesting
  final Future<void> Function()? guideStateWriter;

  @visibleForTesting
  final Future<bool> Function()? notificationPermissionRequester;

  @visibleForTesting
  final Duration operationTimeout;

  @override
  State<AppPermissionGate> createState() => _AppPermissionGateState();
}

class _AppPermissionGateState extends State<AppPermissionGate> {
  bool _loading = true;
  bool _showGuide = false;
  bool _requesting = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadGuideState();
  }

  Future<void> _loadGuideState() async {
    final generation = ++_loadGeneration;
    try {
      final shouldShow = await (widget.guideStateLoader ??
              AppPermissionBootstrap.shouldShowGuide)()
          .timeout(widget.operationTimeout);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _showGuide = shouldShow;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = '用户设置读取失败，请重试';
      });
    }
  }

  Future<void> _continue({required bool requestNotification}) async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      if (requestNotification) {
        await (widget.notificationPermissionRequester ??
                AppPermissionBootstrap.requestNotificationPermission)()
            .timeout(widget.operationTimeout);
      }
      await (widget.guideStateWriter ?? AppPermissionBootstrap.markGuideSeen)()
          .timeout(widget.operationTimeout);
      if (!mounted) return;
      setState(() {
        _showGuide = false;
        _requesting = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _error = '用户设置保存失败，请重试';
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _requesting = false;
      _error = null;
    });
    _loadGuideState();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                key: const ValueKey('permission-gate-error'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('permission-gate-retry'),
                onPressed: _retry,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppTheme.primary,
          ),
        ),
      );
    }

    if (!_showGuide) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceCard,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppLayout.scaled(context, 56),
                height: AppLayout.scaled(context, 56),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius:
                      BorderRadius.circular(AppLayout.scaledValue(16)),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: AppLayout.scaled(context, 28),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 28)),
              Text(
                '权限设置',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: AppLayout.scaled(context, 24),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 12)),
              Text(
                '网络权限用于链同步和版本更新，系统会自动授予，不会弹窗。通知权限用于后续交易、投票和更新提醒；相机与相册会在扫码、选图或保存二维码时再申请。',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppLayout.scaled(context, 15),
                  height: 1.55,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 24)),
              const _PermissionRow(
                icon: Icons.public_rounded,
                title: '网络',
                body: '安装时自动授予，用于轻节点和更新检查。',
              ),
              SizedBox(height: AppLayout.scaled(context, 14)),
              const _PermissionRow(
                icon: Icons.notifications_none_rounded,
                title: '通知',
                body: '现在可授权；拒绝后仍可正常进入应用。',
              ),
              SizedBox(height: AppLayout.scaled(context, 14)),
              const _PermissionRow(
                icon: Icons.photo_camera_outlined,
                title: '相机与相册',
                body: '扫码、选图、保存二维码时按功能申请。',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _requesting
                      ? null
                      : () => _continue(requestNotification: true),
                  child: _requesting
                      ? SizedBox(
                          width: AppLayout.scaled(context, 18),
                          height: AppLayout.scaled(context, 18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('开启通知并继续'),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 10)),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _requesting
                      ? null
                      : () => _continue(requestNotification: false),
                  child: const Text('稍后再说'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppLayout.scaled(context, 38),
          height: AppLayout.scaled(context, 38),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
          ),
          child: Icon(icon,
              color: AppTheme.primary, size: AppLayout.scaled(context, 20)),
        ),
        SizedBox(width: AppLayout.scaled(context, 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: AppLayout.scaled(context, 15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 2)),
              Text(
                body,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppLayout.scaled(context, 13),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
