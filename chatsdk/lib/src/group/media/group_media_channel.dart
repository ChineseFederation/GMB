import '../../core/media_content.dart';
import '../../core/serial_executor.dart';
import '../../mls/mls_group_boundary.dart';
import 'group_media_inbound.dart';
import 'group_media_outbound.dart';

/// 群聊第二类媒体消息只加密一次，同一群内密码学操作严格串行。
final class GroupMediaChannel {
  GroupMediaChannel(this._crypto, {SerialExecutor? serialExecutor})
    : _serial = serialExecutor ?? SerialExecutor();

  final MlsGroupCrypto _crypto;
  final SerialExecutor _serial;

  Future<GroupMediaOutbound> encrypt({
    required String groupId,
    required MediaContent content,
  }) => _serial.run(groupId, () async {
    final wire = await _crypto.groupCreateMessage(
      groupId,
      MediaContentCodec.encode(content),
    );
    return GroupMediaOutbound(content: content, wire: wire);
  });

  Future<GroupMediaInbound> decodeApplication({
    required String groupId,
    required List<int> plaintext,
  }) => _serial.run(
    groupId,
    () async => GroupMediaInbound(
      groupId: groupId,
      content: MediaContentCodec.decode(plaintext),
    ),
  );
}
