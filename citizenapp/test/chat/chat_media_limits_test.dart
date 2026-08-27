import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/chat/chat_media_limits.dart';
import 'package:citizenapp/chat/chat_models.dart';

void main() {
  const mib = 1024 * 1024;

  // 每个用例后复位到无会员，避免用例间的档位串扰。
  tearDown(() => ChatMediaLimits.applyMembershipLevel(null));

  test('单个文件上限按会员档（ADR-037）:自由 10MB、民主 100MB、薪火 5GB', () {
    expect(ChatMediaLimits.maxBytesForLevel('freedom'), 10 * mib);
    expect(ChatMediaLimits.maxBytesForLevel('democracy'), 100 * mib);
    expect(ChatMediaLimits.maxBytesForLevel('spark'), 5120 * mib);
    // 未知 / 无订阅 fail-closed 为 0，不能错误获得自由会员权益。
    expect(ChatMediaLimits.maxBytesForLevel(null), 0);
    expect(ChatMediaLimits.maxBytesForLevel('voting'), 0);
    expect(ChatMediaLimits.absoluteMaxBytes, 5120 * mib);
  });

  test('applyMembershipLevel 设置当前档上限;无会员或未知档禁止聊天', () {
    ChatMediaLimits.applyMembershipLevel(null);
    expect(ChatMediaLimits.currentMaxBytes, 0);
    expect(ChatMediaLimits.chatEnabled, isFalse);
    ChatMediaLimits.applyMembershipLevel('unknown');
    expect(ChatMediaLimits.currentMaxBytes, 0);
    expect(ChatMediaLimits.chatEnabled, isFalse);
    ChatMediaLimits.applyMembershipLevel('democracy');
    expect(ChatMediaLimits.currentMaxBytes, 100 * mib);
    expect(ChatMediaLimits.chatEnabled, isTrue);
    ChatMediaLimits.applyMembershipLevel('spark');
    expect(ChatMediaLimits.currentMaxBytes, 5120 * mib);
  });

  test('聊天权益绑定 CID，其他 CID 不能复用当前会员状态', () {
    ChatMediaLimits.applyMembershipLevel(
      'freedom',
      cidNumber: 'CN220-CTZN2-100000001-2026',
    );
    expect(
      ChatMediaLimits.chatEnabledFor('CN220-CTZN2-100000001-2026'),
      isTrue,
    );
    expect(
      ChatMediaLimits.chatEnabledFor('CN220-CTZN2-100000002-2026'),
      isFalse,
    );
  });

  test('语音和视频消息统一为 3 分钟', () {
    expect(
      ChatMediaLimits.exceedsDurationForKind(
        ChatMessageKind.audio,
        const Duration(minutes: 3).inMilliseconds,
      ),
      isFalse,
    );
    expect(
      ChatMediaLimits.exceedsDurationForKind(
        ChatMessageKind.video,
        const Duration(minutes: 3, milliseconds: 1).inMilliseconds,
      ),
      isTrue,
    );
  });

  test('forKind:媒体含 audio 取当前档上限;text/sticker 无字节返回 0', () {
    ChatMediaLimits.applyMembershipLevel('democracy');
    expect(ChatMediaLimits.forKind(ChatMessageKind.image), 100 * mib);
    expect(ChatMediaLimits.forKind(ChatMessageKind.video), 100 * mib);
    expect(ChatMediaLimits.forKind(ChatMessageKind.file), 100 * mib);
    expect(ChatMediaLimits.forKind(ChatMessageKind.audio), 100 * mib);
    expect(ChatMediaLimits.forKind(ChatMessageKind.text), 0);
    expect(ChatMediaLimits.forKind(ChatMessageKind.sticker), 0);
  });

  test('forMime:任何媒体 mime 取当前档上限', () {
    ChatMediaLimits.applyMembershipLevel('spark');
    expect(ChatMediaLimits.forMime('image/png'), 5120 * mib);
    expect(ChatMediaLimits.forMime('video/quicktime'), 5120 * mib);
    expect(ChatMediaLimits.forMime('application/pdf'), 5120 * mib);
  });

  test('exceedsForKind:精确边界(按当前档)', () {
    ChatMediaLimits.applyMembershipLevel(null);
    expect(
      ChatMediaLimits.exceedsForKind(ChatMessageKind.image, 1),
      isTrue,
    );
    ChatMediaLimits.applyMembershipLevel('freedom');
    expect(
      ChatMediaLimits.exceedsForKind(ChatMessageKind.image, 10 * mib),
      isFalse,
    );
    expect(
      ChatMediaLimits.exceedsForKind(ChatMessageKind.image, 10 * mib + 1),
      isTrue,
    );
    ChatMediaLimits.applyMembershipLevel('spark');
    expect(
      ChatMediaLimits.exceedsForKind(ChatMessageKind.video, 5120 * mib),
      isFalse,
    );
    expect(
      ChatMediaLimits.exceedsForKind(ChatMessageKind.video, 5120 * mib + 1),
      isTrue,
    );
    // text/sticker 无字节,任何大小都视为不超限(它们不携带媒体字节)。
    expect(
        ChatMediaLimits.exceedsForKind(ChatMessageKind.text, 1 << 40), isFalse);
    expect(
      ChatMediaLimits.exceedsForKind(ChatMessageKind.sticker, 1 << 40),
      isFalse,
    );
  });
}
