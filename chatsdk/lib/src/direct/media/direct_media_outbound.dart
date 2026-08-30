import '../../core/media_content.dart';
import '../../mls/mls_boundary.dart';

/// 已完成端到端加密、等待宿主持久化和发送的私聊结果。
final class DirectMediaOutbound {
  const DirectMediaOutbound({required this.content, required this.encrypted});

  final MediaContent content;
  final MlsOutboundMessage encrypted;
}
