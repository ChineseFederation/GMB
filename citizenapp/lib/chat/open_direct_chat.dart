import 'package:flutter/material.dart';

import 'package:citizenapp/chat/chat_page.dart';
import 'package:citizenapp/chat/chat_runtime.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';

typedef DirectChatOpener = Future<void> Function(
  BuildContext context, {
  required String peerCidNumber,
  required String title,
});

/// 打开与目标 CID 的一对一聊天。
///
/// 发起方使用当前默认账户（CID 绑定账户）的 AccountId；冷热钱包均可作为默认账户。广场用户主页「消息」与联系人详情
/// 「消息」共用此入口，复用现有 Chat 运行态，避免重复拼装。
Future<void> openDirectChat(
  BuildContext context, {
  required String peerCidNumber,
  required String title,
}) async {
  final identity = await CurrentUserContext.instance.resolve();
  final sender = identity?.accountId ?? '';
  final ownerCidNumber = identity?.cidNumber ?? '';
  if (sender.isEmpty || ownerCidNumber.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先添加钱包账户并注册 CID')),
    );
    return;
  }
  // 不能和自己发起聊天：所有私信入口的最后一道防线（广场主页/通讯录都走此收口）。
  if (peerCidNumber.trim() == ownerCidNumber) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('不能和自己发起聊天')),
    );
    return;
  }
  final runtime = ChatRuntime();
  final conversationId =
      ChatRuntime.directConversationId(ownerCidNumber, peerCidNumber);
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        conversationId: conversationId,
        ownerCidNumber: ownerCidNumber,
        accountId: sender,
        peerUserId: peerCidNumber,
        title: title,
        onSendText: (text) => runtime.sendText(
          peerCidNumber: peerCidNumber,
          conversationId: conversationId,
          text: text,
        ),
        onSendMedia: (media, {onLocalCommitted}) => runtime.sendMedia(
          peerCidNumber: peerCidNumber,
          conversationId: conversationId,
          media: media,
          onLocalCommitted: onLocalCommitted,
        ),
        onSendSticker: (packId, stickerId) => runtime.sendSticker(
          peerCidNumber: peerCidNumber,
          conversationId: conversationId,
          packId: packId,
          stickerId: stickerId,
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
        onSync: () => runtime.retryOutgoing(
          conversationId: conversationId,
          recipientCidNumber: peerCidNumber,
        ),
        onStartRealtime: ({required onNotice, onDisconnected}) =>
            runtime.startRealtimeSync(
          onNotice: onNotice,
          onDisconnected: onDisconnected,
          retryOutgoingOnConnect: false,
        ),
        onDeleteConversation: () =>
            runtime.deleteLocalConversation(conversationId),
      ),
    ),
  );
}
