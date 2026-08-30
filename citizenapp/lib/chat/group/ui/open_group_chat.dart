import 'package:flutter/material.dart';

import 'package:citizenapp/chat/chat_page.dart';
import 'package:citizenapp/chat/chat_runtime.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';

/// 打开某群的群聊详情。
///
/// 群聊复用与私聊相同的 `ChatPage` 会员门禁和消息入口；文本、贴纸、媒体分别
/// 进入 `ChatRuntime` 的群发送方法，不另建第二套权限实现。群语音/视频通话不在当前范围。
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
        peerCidNumber: groupId,
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
        onMarkRead: (readThroughMillis) => runtime.markConversationRead(
          conversationId: groupId,
          readThroughMillis: readThroughMillis,
        ),
      ),
    ),
  );
}
