import 'package:flutter/material.dart';

import 'package:citizenapp/8964/profile/models/citizen_profile.dart';
import 'package:citizenapp/8964/profile/models/profile_presentation.dart';
import 'package:citizenapp/8964/profile/widgets/profile_avatar.dart';
import 'package:citizenapp/8964/profile/widgets/profile_category_tabs.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 推特式资料卡：头图下方白底，圆角方形头像跨压头图下缘 + 认证勾 +
/// 展示名/公民号/签名/计数 + 右上三图标。
///
/// 头像用 [Positioned] 上移半个身位跨到头图上；文字为深色（落在白底）；
/// 数据来自已加载的 [profile]（可空 → 占位）。
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.cidNumber,
    required this.profile,
    required this.actions,
    this.avatarPath,
    this.avatarUrl,
    this.avatarHeaders,
    this.confirmedMembershipLevel,
    this.confirmedMembershipActive,
    this.onFollowing,
    this.onFollowers,
    this.onMutualFollowing,
  });

  /// 主页身份主键 cid_number（默认昵称/头像的稳定派生种子）。展示用的当前绑定
  /// 钱包账户从 [profile].accountId 取。
  final String cidNumber;
  final CitizenProfile? profile;

  /// 已校验的本机用户头像缓存；存在时优先于网络 URL。
  final String? avatarPath;

  /// 头像图片 URL（object_key 解析后的公开媒体地址）；为空显示占位。
  final String? avatarUrl;
  final Map<String, String>? avatarHeaders;

  /// 本人页面可传入已由 finalized 链或 verify_on_deny 确认的会员展示态。
  /// null 表示尚未确认，继续使用公开资料镜像；false 表示已确认无有效会员。
  final String? confirmedMembershipLevel;
  final bool? confirmedMembershipActive;

  /// 右上三图标（[ProfileActionIcons]）。
  final Widget actions;

  final VoidCallback? onFollowing;
  final VoidCallback? onFollowers;
  final VoidCallback? onMutualFollowing;

  /// 头像尺寸；上移半个身位跨压头图。
  static const double _avatarSize = 80;
  static const double _avatarOverlap = 40;

  /// 统计文字底部到分类文字顶部的产品视觉间距。
  static const double statsToCategoryVisualGap = 15;

  /// 资料主体在展开态需要的最小高度。
  ///
  /// SliverAppBar 不能从 FlexibleSpaceBar 的子项反向取得自然高度，因此这里按
  /// 与真实 Column 完全相同的文字样式测量。头像操作带、各段间距、统计与底部留白
  /// 均固定，只有个性签名的有无及一/两行高度会改变结果。
  static double requiredHeight(BuildContext context, {required String bio}) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    double textHeight(
      String text,
      TextStyle style, {
      int maxLines = 1,
      double maxWidth = double.infinity,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: maxLines,
      )..layout(maxWidth: maxWidth);
      return painter.height;
    }

    final nameStyle = TextStyle(
      fontSize: AppLayout.scaled(context, 18),
      fontWeight: FontWeight.w600,
    );
    final cidStyle = TextStyle(fontSize: AppLayout.scaled(context, 12));
    final bioStyle = TextStyle(
      fontSize: AppLayout.scaled(context, 13),
      height: 1.45,
    );
    final statStyle = TextStyle(
      fontSize: AppLayout.scaled(context, 13),
      fontWeight: FontWeight.w600,
    );
    final normalizedBio = bio.trim();
    final bioHeight = normalizedBio.isEmpty
        ? 0.0
        : 8 +
            textHeight(
              normalizedBio,
              bioStyle,
              maxLines: 2,
              maxWidth: MediaQuery.sizeOf(context).width - 32,
            );
    // SliverAppBar.bottom 与 flexible space 叠层会吃掉约 2.5px；外部高度需同时
    // 扣除分类文字内部顶部间距并补回叠层，才能得到产品定义的 15px 视觉间距。
    const statsToCategoryOuterGap =
        statsToCategoryVisualGap - ProfileCategoryTabs.labelTopPadding + 2.5;
    return 44 +
        8 +
        textHeight('昵称', nameStyle) +
        3 +
        textHeight('公民号', cidStyle) +
        bioHeight +
        12 +
        textHeight('0 关注者', statStyle) +
        statsToCategoryOuterGap;
  }

  /// 链上身份档位；无有效会员时徽章据此分色（访客金/投票蓝/竞选红）。
  String? get _identityLevel => profile?.identityLevel;

  /// 会员信号；有效态与合法档位共同决定会员徽章的档位色和对勾。
  String? get _membershipLevel => confirmedMembershipActive == true
      ? confirmedMembershipLevel
      : profile?.membershipLevel;
  bool get _membershipActive =>
      confirmedMembershipActive ?? profile?.membershipActive ?? false;

  String get _name {
    return ProfilePresentation.forIdentityKey(
      cidNumber,
    ).resolveDisplayName(publicName: profile?.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final bio = profile?.bio.trim() ?? '';
    return ColoredBox(
      color: AppTheme.surfaceCard,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像下半部与右上三图标同处一带；头像另由 Positioned 跨压头图。
                SizedBox(
                  height: _avatarOverlap + 4,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: AppLayout.scaled(context, 10),
                      ),
                      child: actions,
                    ),
                  ),
                ),
                SizedBox(height: AppLayout.scaled(context, 8)),
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: AppLayout.scaled(context, 18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppLayout.scaled(context, 3)),
                _IdentityDetails(cidNumber: cidNumber),
                if (bio.isNotEmpty) ...[
                  SizedBox(height: AppLayout.scaled(context, 8)),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: AppLayout.scaled(context, 13),
                      height: 1.45,
                    ),
                  ),
                ],
                SizedBox(height: AppLayout.scaled(context, 12)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Stat(
                        value: profile?.mutualFollowing ?? 0,
                        label: '互关',
                        onTap: onMutualFollowing,
                      ),
                      SizedBox(width: AppLayout.scaled(context, 18)),
                      _Stat(
                        value: profile?.following ?? 0,
                        label: '关注',
                        onTap: onFollowing,
                      ),
                      SizedBox(width: AppLayout.scaled(context, 18)),
                      _Stat(
                        value: profile?.followers ?? 0,
                        label: '关注者',
                        onTap: onFollowers,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: AppLayout.scaled(context, 16),
            top: -_avatarOverlap,
            child: ProfileAvatar(
              size: _avatarSize,
              identityLevel: _identityLevel,
              membershipLevel: _membershipLevel,
              membershipActive: _membershipActive,
              imagePath: avatarPath,
              imageUrl: avatarUrl,
              imageHeaders: avatarHeaders,
              userImageSet: profile?.avatarObjectKey?.trim().isNotEmpty == true,
              seed: cidNumber,
              borderColor: AppTheme.surfaceCard,
              borderWidth: 4,
              borderRadius: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityDetails extends StatelessWidget {
  const _IdentityDetails({required this.cidNumber});

  final String cidNumber;

  @override
  Widget build(BuildContext context) {
    final cid = cidNumber.trim();
    return Text(
      cid.isEmpty ? '公民号：暂不可用' : '公民号：$cid',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppTheme.textTertiary,
        fontSize: AppLayout.scaled(context, 12),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // 三项关系统计必须保持同一行；大字体下允许横向查看完整内容，不能把
      // 系统已经放大的文字再缩回去。
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: AppLayout.scaled(context, 13),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppLayout.scaled(context, 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
