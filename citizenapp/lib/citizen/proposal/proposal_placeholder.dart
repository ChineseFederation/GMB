import 'package:flutter/material.dart';

import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 提案占位页——某提案种类链端/客户端尚未对接时统一展示「开发中」。
///
/// proposal/ 下每种提案一个文件夹;尚未实现的提案(决议发行/决议销毁/
/// 验证密钥/发起选举)用本占位页,避免空目录,接好后替换为真实发起页。
class ProposalPlaceholderPage extends StatelessWidget {
  const ProposalPlaceholderPage({
    super.key,
    required this.title,
    required this.kind,
  });

  final String title;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.surfaceCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined,
                size: AppLayout.scaled(context, 44),
                color: AppTheme.textTertiary),
            SizedBox(height: AppLayout.scaled(context, 12)),
            Text('「$kind」提案功能开发中',
                style: TextStyle(
                    fontSize: AppLayout.scaled(context, 14),
                    color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
