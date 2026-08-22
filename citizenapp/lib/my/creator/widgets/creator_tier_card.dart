import 'package:flutter/material.dart';

import 'package:citizenapp/my/creator/creator_money.dart';
import 'package:citizenapp/my/creator/models/creator_plan.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 单个会员档卡：档名 + 月/季/年价格 pill（未开启周期灰显「未设」）+ 编辑入口。
class CreatorTierCard extends StatelessWidget {
  const CreatorTierCard({super.key, required this.tier, required this.onEdit});

  final CreatorTier tier;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 14),
        vertical: AppLayout.scaled(context, 13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.tierName.isEmpty ? '未命名档位' : tier.tierName,
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 15),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.scaledValue(4)),
                  child: Icon(
                    Icons.edit_outlined,
                    size: AppLayout.scaled(context, 18),
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 10)),
          Wrap(
            spacing: AppLayout.scaled(context, 8),
            runSpacing: AppLayout.scaled(context, 8),
            children: BillingPeriod.values.map(_pricePill).toList(),
          ),
        ],
      ),
    );
  }

  Widget _pricePill(BillingPeriod period) {
    final fen = tier.priceFenOf(period);
    final has = fen != null;
    final short = switch (period) {
      BillingPeriod.monthly => '月',
      BillingPeriod.quarterly => '季',
      BillingPeriod.yearly => '年',
    };
    final label = has ? '$short ${fenToYuanLabel(fen)} 元' : '$short 未设';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(10),
        vertical: AppLayout.scaledValue(4),
      ),
      decoration: BoxDecoration(
        color: has ? AppTheme.primary.withAlpha(20) : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppLayout.scaledValue(12),
          color: has ? AppTheme.primaryDark : AppTheme.textTertiary,
        ),
      ),
    );
  }
}
