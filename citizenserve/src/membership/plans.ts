// 会员套餐真源（ADR-037：链上 GMB 会员与身份彻底解耦）。会员档 `membership_level` 是纯付费订阅轴，
// **不再绑定任何身份档**——任意身份（访客/投票/竞选）可订阅任意会员档，全组合放行。
// 三档：freedom 自由 / democracy 民主 / spark 薪火。发帖额度、媒体质量、聊天文件上限均按
// 所购套餐（membershipPlan(level)）。**价格真源与实际扣款属于链上 `square-post`，真实公历
// 到期时间由 runtime 根据共识时间戳确定**；本表只定档位与配额，不涉计价。一改此表须同步 App 卡片。
import { resourceLimit, usageLimits } from '../limits/catalog';

export type MembershipLevel = 'freedom' | 'democracy' | 'spark';

export type MediaQuality = 'sd' | 'hd';

const mib = 1024 * 1024;

export interface DocumentQuota {
  text_max_chars: number;
  image_quality: MediaQuality;
  max_images: number;
}

export interface VideoQuota {
  text_max_chars: number;
  video_quality: MediaQuality;
  max_video_seconds: number;
  /// 单个视频体积上限来自 limits 唯一资源表，会员接口只负责展示同一值。
  max_video_bytes: number;
}

export interface ArticleQuota {
  title_min_chars: number;
  title_max_chars: number;
  body_max_chars: number;
  cover_quality: MediaQuality;
  cover_required: true;
  image_quality: MediaQuality;
  /// 单篇文章全部图片总数，包含首图。
  max_images: number;
  /// 单篇文章视频数量；每个视频仍逐个执行本档时长和体积限制。
  max_videos: number;
}

export interface MembershipPlan {
  membership_level: MembershipLevel;
  display_name: string;
  /// 聊天文件大小上限（字节，会员权益之一，ADR-037）。媒体走 WebRTC P2P，客户端按此档强制；
  /// >100MB（仅 spark）的 Cloudflare 瞬时中转 transport 归卡2 阶段3，本表只定档位上限值。
  chat_file_max_bytes: number;
  document: DocumentQuota;
  video: VideoQuota;
  article: ArticleQuota;
  /// 订阅周期累计用量额度（每月）。真源 limits/catalog.ts `usageLimits`，会员接口透传展示。
  usage: {
    monthly_images: number;
    monthly_video_seconds: number;
    active_uploads: number;
  };
}

export const membershipPlans: Record<MembershipLevel, MembershipPlan> = {
  freedom: {
    membership_level: 'freedom',
    display_name: '自由会员',
    chat_file_max_bytes: 10 * mib,
    document: {
      text_max_chars: 300,
      image_quality: 'sd',
      max_images: 9,
    },
    video: {
      text_max_chars: 300,
      video_quality: 'sd',
      max_video_seconds: 3 * 60,
      max_video_bytes: resourceLimit('square_video_freedom').max_bytes
    },
    article: {
      title_min_chars: 10,
      title_max_chars: 50,
      body_max_chars: 30_000,
      cover_quality: 'hd',
      cover_required: true,
      image_quality: 'sd',
      max_images: 50,
      max_videos: 1
    },
    usage: usageLimits.freedom
  },
  democracy: {
    membership_level: 'democracy',
    display_name: '民主会员',
    chat_file_max_bytes: 100 * mib,
    document: {
      text_max_chars: 300,
      image_quality: 'hd',
      max_images: 9,
    },
    video: {
      text_max_chars: 300,
      video_quality: 'hd',
      max_video_seconds: 30 * 60,
      max_video_bytes: resourceLimit('square_video_democracy').max_bytes
    },
    article: {
      title_min_chars: 10,
      title_max_chars: 50,
      body_max_chars: 30_000,
      cover_quality: 'hd',
      cover_required: true,
      image_quality: 'hd',
      max_images: 100,
      max_videos: 3
    },
    usage: usageLimits.democracy
  },
  spark: {
    membership_level: 'spark',
    display_name: '薪火会员',
    chat_file_max_bytes: 5120 * mib,
    document: {
      text_max_chars: 300,
      image_quality: 'hd',
      max_images: 9,
    },
    video: {
      text_max_chars: 300,
      video_quality: 'hd',
      max_video_seconds: 3 * 60 * 60,
      max_video_bytes: resourceLimit('square_video_spark').max_bytes
    },
    article: {
      title_min_chars: 10,
      title_max_chars: 50,
      body_max_chars: 30_000,
      cover_quality: 'hd',
      cover_required: true,
      image_quality: 'hd',
      max_images: 100,
      max_videos: 10
    },
    usage: usageLimits.spark
  }
};

export function assertMembershipLevel(value: unknown): MembershipLevel {
  if (value === 'freedom' || value === 'democracy' || value === 'spark') {
    return value;
  }
  throw new Error('invalid membership level');
}

export function membershipPlan(level: string): MembershipPlan {
  if (level === 'democracy' || level === 'spark') {
    return membershipPlans[level];
  }
  return membershipPlans.freedom;
}

export function membershipPlanList(): MembershipPlan[] {
  return [membershipPlans.freedom, membershipPlans.democracy, membershipPlans.spark];
}
