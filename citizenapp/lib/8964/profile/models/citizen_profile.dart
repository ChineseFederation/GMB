import 'package:citizenapp/8964/profile/models/profile_presentation.dart';

/// 用户主页公开资料模型（对应 Worker `UserProfileResponse`）。
///
/// 头像/背景/签名/展示名是链下 R2 资料；计数与认证是 D1/链上派生。
/// App 侧只读展示，写入走 `PUT /square/profile`。
class CitizenProfile {
  const CitizenProfile({
    required this.accountId,
    required this.displayName,
    required this.bio,
    required this.avatarObjectKey,
    required this.bannerObjectKey,
    required this.cidNumber,
    required this.isCertified,
    required this.identityLevel,
    required this.membershipLevel,
    required this.membershipActive,
    required this.membershipConfirmed,
    required this.following,
    required this.followers,
    required this.mutualFollowing,
    required this.posts,
    required this.campaigns,
    required this.videos,
    required this.articles,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isNotifying,
    required this.updatedAt,
  });

  final String accountId;
  final String displayName;
  final String bio;
  final String? avatarObjectKey;
  final String? bannerObjectKey;
  final String? cidNumber;
  final bool isCertified;

  /// 链上身份档位：visitor 未认证 / voting 认证投票公民 / candidate 认证竞选公民。
  /// 认证真源=链上；无有效会员时，徽章据此分色（访客金/投票蓝/竞选红）。
  final String identityLevel;

  /// 已购买的会员档位（公开）：freedom/democracy/spark/null（未购买）。
  /// ADR-037 规定与链上身份档彻底解耦；有效会员徽章按本字段分色并显示对勾。
  final String? membershipLevel;

  /// 会员是否当前有效。
  final bool membershipActive;

  /// 公开会员投影是否足够新、可作明确展示结论。false 表示未知，不能用它把已确认
  /// 有效的本机展示降级成非会员；本字段只控制视觉缓存，不参与授权。
  final bool membershipConfirmed;
  final int following;
  final int followers;
  final int mutualFollowing;
  final int posts;
  final int campaigns;
  final int videos;
  final int articles;
  final bool isFollowing;

  /// 主页用户是否关注当前登录者；只用于准确计算当前操作是否形成或解除互关。
  final bool isFollowedBy;

  /// 当前登录者是否对该账户开启发帖通知（= 已关注且未静音）。本人视角恒为 false。
  final bool isNotifying;
  final int updatedAt;

  /// `display_name` 是公开昵称唯一真源；缺失时按 CID（无 CID 才按账户）
  /// 生成稳定默认昵称，绝不把钱包名、完整账户或截断账户当昵称。
  String get resolvedDisplayName {
    return ProfilePresentation.forIdentityKey(
      cidNumber ?? accountId,
    ).resolveDisplayName(publicName: displayName);
  }

  factory CitizenProfile.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'];
    if (counts is! Map<String, dynamic> ||
        !counts.containsKey('following') ||
        !counts.containsKey('followers') ||
        !counts.containsKey('mutual_following') ||
        !counts.containsKey('posts') ||
        !counts.containsKey('campaigns') ||
        !counts.containsKey('videos') ||
        !counts.containsKey('articles') ||
        json['is_followed_by'] is! bool ||
        json['membership_confirmed'] is! bool) {
      throw const FormatException(
        '用户主页响应缺少关系、内容分类统计、互关状态或会员确认态',
      );
    }
    final countsMap = counts;
    return CitizenProfile(
      accountId: _asString(json['account_id']),
      displayName: _asString(json['display_name']),
      bio: _asString(json['bio']),
      avatarObjectKey: _asNullableString(json['avatar_object_key']),
      bannerObjectKey: _asNullableString(json['banner_object_key']),
      cidNumber: _asNullableString(json['cid_number']),
      isCertified: json['is_certified'] == true,
      identityLevel: _asIdentityLevel(json['identity_level']),
      membershipLevel: _asMembershipLevel(json['membership_level']),
      membershipActive: json['membership_active'] == true,
      membershipConfirmed: json['membership_confirmed'] == true,
      following: _asInt(countsMap['following']),
      followers: _asInt(countsMap['followers']),
      mutualFollowing: _asInt(countsMap['mutual_following']),
      posts: _asInt(countsMap['posts']),
      campaigns: _asInt(countsMap['campaigns']),
      videos: _asInt(countsMap['videos']),
      articles: _asInt(countsMap['articles']),
      isFollowing: json['is_following'] == true,
      isFollowedBy: json['is_followed_by'] == true,
      isNotifying: json['is_notifying'] == true,
      updatedAt: _asInt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'account_id': accountId,
        'display_name': displayName,
        'bio': bio,
        'avatar_object_key': avatarObjectKey,
        'banner_object_key': bannerObjectKey,
        'cid_number': cidNumber,
        'is_certified': isCertified,
        'identity_level': identityLevel,
        'membership_level': membershipLevel,
        'membership_active': membershipActive,
        'membership_confirmed': membershipConfirmed,
        'counts': <String, dynamic>{
          'following': following,
          'followers': followers,
          'mutual_following': mutualFollowing,
          'posts': posts,
          'campaigns': campaigns,
          'videos': videos,
          'articles': articles,
        },
        'is_following': isFollowing,
        'is_followed_by': isFollowedBy,
        'is_notifying': isNotifying,
        'updated_at': updatedAt,
      };

  CitizenProfile copyWith({
    String? displayName,
    String? bio,
    Object? avatarObjectKey = _sentinel,
    Object? bannerObjectKey = _sentinel,
    Object? membershipLevel = _sentinel,
    bool? membershipActive,
    bool? membershipConfirmed,
    bool? isFollowing,
    bool? isFollowedBy,
    bool? isNotifying,
    int? followers,
    int? mutualFollowing,
    int? updatedAt,
  }) {
    return CitizenProfile(
      accountId: accountId,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarObjectKey: identical(avatarObjectKey, _sentinel)
          ? this.avatarObjectKey
          : avatarObjectKey as String?,
      bannerObjectKey: identical(bannerObjectKey, _sentinel)
          ? this.bannerObjectKey
          : bannerObjectKey as String?,
      cidNumber: cidNumber,
      isCertified: isCertified,
      identityLevel: identityLevel,
      membershipLevel: identical(membershipLevel, _sentinel)
          ? this.membershipLevel
          : membershipLevel as String?,
      membershipActive: membershipActive ?? this.membershipActive,
      membershipConfirmed: membershipConfirmed ?? this.membershipConfirmed,
      following: following,
      followers: followers ?? this.followers,
      mutualFollowing: mutualFollowing ?? this.mutualFollowing,
      posts: posts,
      campaigns: campaigns,
      videos: videos,
      articles: articles,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
      isNotifying: isNotifying ?? this.isNotifying,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 服务端返回会员未知态时保留上一份已确认有效展示；一旦服务端给出确认有效或确认
  /// 无效结论，立即使用新值。授权流程不得调用本方法。
  CitizenProfile preserveConfirmedMembership(CitizenProfile? previous) {
    if (membershipConfirmed ||
        previous == null ||
        !previous.membershipConfirmed ||
        !previous.membershipActive) {
      return this;
    }
    return copyWith(
      membershipLevel: previous.membershipLevel,
      membershipActive: true,
      membershipConfirmed: true,
    );
  }
}

/// 关注、关注者或互关列表的一行（对应 Worker follows 列表项 `entries`，项 = 身份主键
/// cid_number + created_at）。
class SquareFollowEntry {
  const SquareFollowEntry({required this.cidNumber, required this.createdAt});

  final String cidNumber;
  final int createdAt;

  factory SquareFollowEntry.fromJson(Map<String, dynamic> json) {
    return SquareFollowEntry(
      cidNumber: _asString(json['cid_number']),
      createdAt: _asInt(json['created_at']),
    );
  }
}

const Object _sentinel = Object();

String _asString(Object? value) => value?.toString() ?? '';

String? _asNullableString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

/// 归一化链上身份档位；未知/缺失一律 visitor（fail-closed，不误判认证）。
String _asIdentityLevel(Object? value) {
  final normalized = value?.toString().trim();
  return (normalized == 'voting' || normalized == 'candidate')
      ? normalized!
      : 'visitor';
}

/// 归一化会员档位；未知/缺失/未购买 → null（不给勾）。
/// 会员三档 = freedom / democracy / spark；ADR-037 规定会员与链上身份档彻底解耦，
/// voting / candidate 是身份档（identity_level），绝不能出现在会员白名单里。
String? _asMembershipLevel(Object? value) {
  final normalized = value?.toString().trim();
  return (normalized == 'freedom' ||
          normalized == 'democracy' ||
          normalized == 'spark')
      ? normalized
      : null;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
