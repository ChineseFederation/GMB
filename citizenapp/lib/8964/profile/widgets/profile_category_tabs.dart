import 'package:flutter/material.dart';

import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 用户主页四类互斥内容：竞选优先，普通文章归文章，普通视频归视频，
/// 其余普通公文（纯文字或图片）归公文。底层使用
/// posts 数据语义，避免展示文案调整污染 API 与存储契约。
enum ProfileTab {
  posts('公文'),
  campaign('竞选'),
  videos('视频'),
  articles('文章');

  const ProfileTab(this.label);

  final String label;
}

/// 折叠头下方固定的分类标签栏（挂在 SliverAppBar.bottom，折叠后固定）。
///
/// 屏幕边缘到首尾文字、相邻分类文字之间共五段视觉空隙必须相等。间距按当前
/// 可用宽度、平台字体和系统文字倍率动态计算，不能依赖等宽 Tab 或固定像素。
class ProfileCategoryTabs extends StatelessWidget
    implements PreferredSizeWidget {
  const ProfileCategoryTabs({
    super.key,
    this.controller,
    this.posts = 0,
    this.campaigns = 0,
    this.videos = 0,
    this.articles = 0,
  });

  final TabController? controller;
  final int posts;
  final int campaigns;
  final int videos;
  final int articles;

  /// 分类栏保持紧凑，避免 Tab 默认高度在统计文字下方制造假空白。
  static const double height = 36;

  /// 增高后的分类栏上下留白保持均衡，不恢复 Material 默认的过高 Tab。
  static const double labelTopPadding = 8;

  static final TextStyle _labelStyle = TextStyle(
    fontSize: AppLayout.scaledValue(16),
    fontWeight: FontWeight.w700,
  );

  /// 数量作为分类名称的次级信息，字号和字重必须明显更轻，不与分类名称争夺层级。
  static final TextStyle _countStyle = TextStyle(
    color: AppTheme.textTertiary,
    fontSize: AppLayout.scaledValue(11),
    fontWeight: FontWeight.w400,
  );

  /// Flutter 可滚动 TabBar 对混合字号 TextSpan 的实际取整宽度比 TextPainter 汇总值
  /// 多 2.2px；计算间距时先扣除，避免仅最右侧空隙比其余四段更窄。
  static const double _trailingLayoutBoundary = 2.2;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  int _countOf(ProfileTab tab) => switch (tab) {
        ProfileTab.posts => posts,
        ProfileTab.campaign => campaigns,
        ProfileTab.videos => videos,
        ProfileTab.articles => articles,
      };

  TextSpan _labelSpan(ProfileTab tab) => TextSpan(
        children: [
          TextSpan(text: tab.label, style: _labelStyle),
          TextSpan(text: '{${_countOf(tab)}}', style: _countStyle),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textDirection = Directionality.of(context);
          final textScaler = MediaQuery.textScalerOf(context);
          final labelsWidth = ProfileTab.values.fold<double>(0, (sum, tab) {
            final painter = TextPainter(
              text: _labelSpan(tab),
              textDirection: textDirection,
              textScaler: textScaler,
              maxLines: 1,
            )..layout();
            return sum + painter.width;
          });
          // 四项复合文字形成左外侧、三段内部、右外侧共五段空隙。TabBar 的外部
          // padding 与每个标签的单侧 padding 各取空隙的一半，组合后恰好相等。
          final visualGap =
              ((constraints.maxWidth - labelsWidth - _trailingLayoutBoundary) /
                      (ProfileTab.values.length + 1))
                  .clamp(0.0, double.infinity)
                  .toDouble();
          final halfGap = visualGap / 2;
          final gapInsets = EdgeInsetsDirectional.symmetric(
            horizontal: halfGap,
          );
          return TabBar(
            controller: controller,
            isScrollable: true,
            // 显式使用 start，禁止 Material 3 默认 startOffset 再注入 52px。
            tabAlignment: TabAlignment.start,
            padding: gapInsets,
            labelPadding: gapInsets,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textPrimary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppTheme.divider,
            labelStyle: _labelStyle,
            unselectedLabelStyle: _labelStyle,
            tabs: [
              for (final tab in ProfileTab.values)
                Tab(
                  height: height,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: labelTopPadding),
                      child: Text.rich(
                        _labelSpan(tab),
                        key: ValueKey<String>('profile-tab-${tab.name}'),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
