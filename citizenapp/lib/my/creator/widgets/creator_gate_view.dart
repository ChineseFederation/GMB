import 'package:flutter/material.dart';

import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 未开通门禁态：runtime 要求创作者具有当前有效的平台会员权益。
///
/// [onOpenMembership] 引导去现有会员页完成订阅。
class CreatorGateView extends StatelessWidget {
  const CreatorGateView({super.key, required this.onOpenMembership});

  final VoidCallback onOpenMembership;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 20),
            vertical: AppLayout.scaled(context, 28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppLayout.scaled(context, 64),
              height: AppLayout.scaled(context, 64),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(24),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(Icons.storefront_outlined,
                  size: AppLayout.scaled(context, 32), color: AppTheme.primary),
            ),
            SizedBox(height: AppLayout.scaled(context, 14)),
            Text(
              '成为创作者',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 18),
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            Text(
              '设置你的会员档位，粉丝用公民币订阅你，订阅款全额进你的钱包。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 13),
                height: 1.6,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 20)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
              decoration: AppTheme.bannerDecoration(AppTheme.warning),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline,
                      size: AppLayout.scaled(context, 18),
                      color: AppTheme.warning),
                  SizedBox(width: AppLayout.scaled(context, 10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '需要有效平台会员',
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 13),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppLayout.scaled(context, 2)),
                        Text(
                          '平台会员权益有效时，可以创建会员档并直接收取公民币订阅款。',
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 12),
                            height: 1.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 16)),
            FilledButton.icon(
              onPressed: onOpenMembership,
              icon: Icon(Icons.workspace_premium_outlined,
                  size: AppLayout.scaled(context, 19)),
              label: const Text('去订阅平台会员'),
            ),
          ],
        ),
      ),
    );
  }
}
