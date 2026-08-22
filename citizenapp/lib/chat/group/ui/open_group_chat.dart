import 'package:flutter/material.dart';

import 'package:citizenapp/chat/chat_page.dart';
import 'package:citizenapp/chat/chat_runtime.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';

/// 打开某群的群聊详情。
///
/// 群目前支持文本 + emoji(emoji 即文本);媒体/贴纸群发是后续步,故只接
/// `onSendText`。复用 1:1 的 `ChatPage`,发送走 `runtime.sendGroupText`。
Future<void> openGroupChat(
  BuildContext context, {
  required String groupId,
  required String title,
  ChatDeleteConversationCallback? onDeleteConversation,
}) async {
  final identity = await CurrentUserContext.instance.resolve();
  final accountId = identity?.accountId ?? '';
  final ownerCidNumber = identity?.cidNumber ?? '';
  if (accountId.isEmpty || ownerCidNumber.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先在「我的 → 我的钱包」添加钱包账户')),
    );
    return;
  }
  final runtime = ChatRuntime();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        conversationId: groupId,
        ownerCidNumber: ownerCidNumber,
        accountId: accountId,
        peerUserId: groupId,
        title: title,
        isGroup: true,
        onSendText: (text) =>
            runtime.sendGroupText(groupId: groupId, text: text),
        onSendSticker: (packId, stickerId) => runtime.sendGroupSticker(
          groupId: groupId,
          packId: packId,
          stickerId: stickerId,
        ),
        onSendMedia: (media, {onLocalCommitted}) => runtime.sendGroupMedia(
          groupId: groupId,
          media: media,
          onLocalCommitted: onLocalCommitted,
        ),
        onResolveMediaPaths: (conversationId, contents) =>
            runtime.resolveCachedMediaPaths(
          conversationId: conversationId,
          contents: contents,
        ),
        onDownloadAttachment: (conversationId, controlPlaintext) =>
            runtime.downloadAttachment(
          conversationId: conversationId,
          controlPlaintext: controlPlaintext,
        ),
        onSync: () => runtime.retryOutgoing(conversationId: groupId),
        onStartRealtime: ({required onNotice, onDisconnected}) =>
            runtime.startRealtimeSync(
          onNotice: onNotice,
          onDisconnected: onDisconnected,
          retryOutgoingOnConnect: false,
        ),
        onDeleteConversation: onDeleteConversation ??
            () => runtime.deleteLocalConversation(groupId),
      ),
    ),
  );
}
