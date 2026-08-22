import 'package:flutter/material.dart';

import 'package:citizenapp/my/creator/creator_money.dart';
import 'package:citizenapp/my/creator/models/creator_overview.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 创作者概览卡：订阅人数 + 预计月收入（金色锚点）+ 预计提示。
class CreatorOverviewCard extends StatelessWidget {
  const CreatorOverviewCard({
    super.key,
    required this.overview,
    this.resolved = true,
  });

  final CreatorOverview overview;

  /// false 表示尚未取得本地展示快照；只展示中性结构，不出现等待或同步文案。
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
      padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppLayout.scaled(context, 26),
                height: AppLayout.scaled(context, 26),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(Icons.storefront_outlined,
                    size: AppLayout.scaled(context, 16),
                    color: AppTheme.primary),
              ),
              SizedBox(width: AppLayout.scaled(context, 8)),
              Text(
                '我的创作者会员',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.scaled(context, 8),
                    vertical: AppLayout.scaled(context, 2)),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(24),
                  borderRadius:
                      BorderRadius.circular(AppLayout.scaledValue(20)),
                ),
                child: Text(
                  resolved ? '已开通' : '创作者',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 11),
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 12)),
          Row(
            children: [
              Expanded(
                child: _stat(
                  '订阅人数',
                  resolved ? overview.subscriberCount.toString() : '--',
                  AppTheme.primary,
                ),
              ),
              SizedBox(width: AppLayout.scaled(context, 12)),
              Expanded(
                child: _stat(
                  '本月已收入',
                  resolved
                      ? '${fenToYuanLabel(overview.monthIncomeFen)} 元'
                      : '--',
                  AppTheme.gold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 10)),
          Text(
            '数据来自链上扣款投影 · 完整收入台账随税务功能上线',
            style: TextStyle(
                fontSize: AppLayout.scaled(context, 11),
                color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(12),
          vertical: AppLayout.scaledValue(10)),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: AppLayout.scaledValue(12),
                  color: AppTheme.textSecondary)),
          SizedBox(height: AppLayout.scaledValue(2)),
          Text(
            value,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(24),
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
