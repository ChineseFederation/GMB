/// 公民广场手机端媒体成品规则。
///
/// 本文件只描述手机本地生成的最终媒体，不替代 Worker 的独立额度与文件复核。
/// 所有字节上限均采用十进制 MB/GB，与 R2 计量和产品展示保持一致。
final class SquareMediaPolicy {
  const SquareMediaPolicy({
    required this.membershipLevel,
    required this.imageMaxEdge,
    required this.imageQuality,
    required this.imageMaxBytes,
    required this.videoShortSide,
    required this.videoLongSide,
    required this.videoTotalBitrate,
    required this.videoPeakBitrate,
    required this.audioBitrate,
    required this.maxVideoSeconds,
    required this.maxVideoBytes,
  });

  static const int imageThumbnailMaxEdge = 480;
  static const int imageThumbnailQuality = 70;
  static const int imageThumbnailMaxBytes = 256000;
  static const int videoCoverMaxEdge = 720;
  static const int videoCoverQuality = 75;
  static const int videoCoverMaxBytes = 512000;
  static const int videoMaxFrameRate = 30;
  static const int videoKeyFrameIntervalSeconds = 2;
  static const int audioSampleRate = 48000;

  final String membershipLevel;
  final int imageMaxEdge;
  final int imageQuality;
  final int imageMaxBytes;
  final int videoShortSide;
  final int videoLongSide;

  /// 音视频合计目标平均码率，单位 bit/s。
  final int videoTotalBitrate;

  /// 一秒滑动窗口允许的音视频合计峰值码率，单位 bit/s。
  final int videoPeakBitrate;
  final int audioBitrate;
  final int maxVideoSeconds;
  final int maxVideoBytes;

  int get videoBitrate => videoTotalBitrate - audioBitrate;

  static SquareMediaPolicy forMembershipLevel(String membershipLevel) {
    return switch (membershipLevel) {
      'freedom' => freedom,
      'democracy' => democracy,
      'spark' => spark,
      _ => throw const FormatException('会员档位不支持广场媒体处理'),
    };
  }

  static const freedom = SquareMediaPolicy(
    membershipLevel: 'freedom',
    imageMaxEdge: 1280,
    imageQuality: 72,
    imageMaxBytes: 1000000,
    videoShortSide: 480,
    videoLongSide: 854,
    videoTotalBitrate: 600000,
    videoPeakBitrate: 900000,
    audioBitrate: 96000,
    maxVideoSeconds: 3 * 60,
    maxVideoBytes: 16000000,
  );

  static const democracy = SquareMediaPolicy(
    membershipLevel: 'democracy',
    imageMaxEdge: 1920,
    imageQuality: 80,
    imageMaxBytes: 2000000,
    videoShortSide: 720,
    videoLongSide: 1280,
    videoTotalBitrate: 1200000,
    videoPeakBitrate: 1800000,
    audioBitrate: 96000,
    maxVideoSeconds: 30 * 60,
    maxVideoBytes: 300000000,
  );

  static const spark = SquareMediaPolicy(
    membershipLevel: 'spark',
    imageMaxEdge: 2560,
    imageQuality: 85,
    imageMaxBytes: 4000000,
    videoShortSide: 1080,
    videoLongSide: 1920,
    videoTotalBitrate: 2000000,
    videoPeakBitrate: 3000000,
    audioBitrate: 128000,
    maxVideoSeconds: 3 * 60 * 60,
    // 低于 R2 单次 PUT 的约 5GiB 上限，且给封装与传输保留充分余量。
    maxVideoBytes: 3000000000,
  );
}
