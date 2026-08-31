import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../attachment/image_viewer_page.dart';
import '../attachment/video_player_page.dart';
import '../attachment/voice_message_player.dart';
import '../sticker_pack.dart';
import '../style.dart';

typedef ChatGroupSenderBuilder =
    Widget Function(BuildContext context, String userId);

/// Reusable direct/group message viewport, including all message categories.
class ChatMessageListView extends StatelessWidget {
  const ChatMessageListView({
    super.key,
    required this.currentUserId,
    required this.chatController,
    required this.onMessageSend,
    required this.resolveUser,
    required this.composerBuilder,
    required this.onDownloadAttachment,
    required this.onMessagesChanged,
    this.isGroup = false,
    this.loading = false,
    this.error,
    this.groupSenderBuilder,
    this.style = const ChatViewStyle(),
  });

  final String currentUserId;
  final ChatController chatController;
  final Future<void> Function(String text) onMessageSend;
  final Future<User> Function(String userId) resolveUser;
  final Widget Function(BuildContext context) composerBuilder;
  final Future<void> Function(String controlPlaintext) onDownloadAttachment;
  final Future<void> Function() onMessagesChanged;
  final bool isGroup;
  final bool loading;
  final String? error;
  final ChatGroupSenderBuilder? groupSenderBuilder;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: style.scale(context, 2),
          child: loading
              ? const LinearProgressIndicator(
                  key: ValueKey('chat-page-progress'),
                )
              : null,
        ),
        SizedBox(
          height: style.scale(context, 36),
          child: error == null
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(
                    horizontal: style.scale(context, 16),
                  ),
                  color: style.error(context).withValues(alpha: 0.08),
                  child: Text(
                    error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.error(context),
                      fontSize: style.scale(context, 12),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: Chat(
            currentUserId: currentUserId,
            chatController: chatController,
            onMessageSend: (text) => unawaited(onMessageSend(text)),
            backgroundColor: style.background(context),
            builders: Builders(
              textMessageBuilder: isGroup ? _buildGroupTextMessage : null,
              imageMessageBuilder: _buildImageMessage,
              videoMessageBuilder: _buildVideoMessage,
              fileMessageBuilder: _buildFileMessage,
              audioMessageBuilder: _buildAudioMessage,
              customMessageBuilder: _buildStickerMessage,
              composerBuilder: composerBuilder,
              emptyChatListBuilder: (context) =>
                  !shouldShowChatEmptyState(loading: loading, error: error)
                  ? const SizedBox.shrink()
                  : const Padding(
                      padding: EdgeInsets.only(bottom: 120),
                      child: Center(child: Text('暂无消息')),
                    ),
            ),
            resolveUser: resolveUser,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final showSender = !isSentByMe && (groupStatus?.isFirst ?? true);
    return SimpleTextMessage(
      message: message,
      index: index,
      topWidget: showSender ? _sender(context, message.authorId) : null,
    );
  }

  Widget _buildImageMessage(
    BuildContext context,
    ImageMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.62;
    final hasFile = message.source.isNotEmpty;
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    final ratio = _mediaAspectRatio(message.width, message.height);
    final cacheWidth = (maxWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    final Widget content = hasFile
        ? GestureDetector(
            onTap: () => _openImageViewer(context, message),
            child: Image.file(
              File(message.source),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (_, __, ___) => _mediaPlaceholder(
                context,
                icon: Icons.broken_image_rounded,
                label: '图片无法显示',
              ),
            ),
          )
        : GestureDetector(
            onTap: control.isEmpty
                ? null
                : () => unawaited(_downloadAndReload(control)),
            child: _blurhashOrPlaceholder(
              context,
              message.blurhash,
              '接收中…',
              key: const ValueKey('chat-image-blurhash'),
            ),
          );
    return _mediaAligned(
      context,
      isSentByMe,
      ClipRRect(
        borderRadius: BorderRadius.circular(style.scale(context, 14)),
        child: SizedBox(
          width: maxWidth,
          child: AspectRatio(aspectRatio: ratio, child: content),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildVideoMessage(
    BuildContext context,
    VideoMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.62;
    final hasFile = message.source.isNotEmpty;
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    final hash = message.metadata?['blurhash']?.toString();
    return _mediaAligned(
      context,
      isSentByMe,
      GestureDetector(
        onTap: hasFile
            ? () => _openVideoPlayer(context, message)
            : control.isEmpty
            ? null
            : () => unawaited(_downloadAndReload(control)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(style.scale(context, 14)),
          child: SizedBox(
            width: maxWidth,
            child: AspectRatio(
              aspectRatio: _mediaAspectRatio(message.width, message.height),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hash != null && hash.isNotEmpty)
                    BlurHash(
                      key: const ValueKey('chat-video-blurhash'),
                      hash: hash,
                      imageFit: BoxFit.cover,
                    )
                  else
                    Container(color: style.surface(context)),
                  Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: style.scale(context, 44),
                      color: Colors.white70,
                    ),
                  ),
                  if (!hasFile)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: style.scale(context, 8),
                      child: Text(
                        '接收中…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: style.scale(context, 12),
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildFileMessage(
    BuildContext context,
    FileMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    return _mediaAligned(
      context,
      isSentByMe,
      GestureDetector(
        onTap: control.isEmpty
            ? null
            : () => unawaited(_downloadAndReload(control)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: style.scale(context, 14),
            vertical: style.scale(context, 12),
          ),
          decoration: BoxDecoration(
            color: style.surface(context),
            borderRadius: BorderRadius.circular(style.scale(context, 14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: style.scale(context, 28),
                color: style.textSecondary(context),
              ),
              SizedBox(width: style.scale(context, 10)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: style.scale(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (message.size != null)
                      Text(
                        formatChatByteSize(message.size!),
                        style: TextStyle(
                          fontSize: style.scale(context, 11),
                          color: style.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildAudioMessage(
    BuildContext context,
    AudioMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    return _mediaAligned(
      context,
      isSentByMe,
      VoiceMessagePlayer(
        message: message,
        isSentByMe: isSentByMe,
        onRequestDownload: () => _downloadAndReload(control),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildStickerMessage(
    BuildContext context,
    CustomMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final packId = message.metadata?['pack_id']?.toString() ?? '';
    final stickerId = message.metadata?['sticker_id']?.toString() ?? '';
    final known = StickerPack.isKnown(packId: packId, stickerId: stickerId);
    final content = known
        ? Image.asset(
            StickerPack.assetPath(stickerId),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _stickerFallback(context),
          )
        : _stickerFallback(context);
    return _mediaAligned(
      context,
      isSentByMe,
      SizedBox(
        key: ValueKey('chat-sticker-message-${message.id}'),
        width: 128,
        height: 128,
        child: content,
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _mediaAligned(
    BuildContext context,
    bool isSentByMe,
    Widget child, {
    String? senderId,
    MessageGroupStatus? groupStatus,
  }) {
    final aligned = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: style.scale(context, 12),
        vertical: style.scale(context, 4),
      ),
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    final showSender =
        isGroup &&
        !isSentByMe &&
        senderId != null &&
        (groupStatus?.isFirst ?? true);
    if (!showSender) return aligned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: style.scale(context, 16),
            top: style.scale(context, 4),
          ),
          child: _sender(context, senderId),
        ),
        aligned,
      ],
    );
  }

  Widget _sender(BuildContext context, String userId) {
    return groupSenderBuilder?.call(context, userId) ??
        Text(
          userId,
          style: TextStyle(
            fontSize: style.scale(context, 11),
            color: style.textSecondary(context),
          ),
        );
  }

  Widget _blurhashOrPlaceholder(
    BuildContext context,
    String? hash,
    String label, {
    Key? key,
  }) {
    if (hash != null && hash.isNotEmpty) {
      return Stack(
        key: key,
        fit: StackFit.expand,
        children: [
          BlurHash(hash: hash, imageFit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: style.scale(context, 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: style.scale(context, 12),
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    return _mediaPlaceholder(context, icon: Icons.image_rounded, label: label);
  }

  Widget _mediaPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: style.surface(context),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: style.textSecondary(context),
            size: style.scale(context, 28),
          ),
          SizedBox(height: style.scale(context, 6)),
          Text(
            label,
            style: TextStyle(
              fontSize: style.scale(context, 12),
              color: style.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stickerFallback(BuildContext context) => _mediaPlaceholder(
    context,
    icon: Icons.emoji_emotions_outlined,
    label: '[贴纸]',
  );

  Future<void> _downloadAndReload(String control) async {
    if (control.isEmpty) return;
    await onDownloadAttachment(control);
    await onMessagesChanged();
  }

  void _openImageViewer(BuildContext context, ImageMessage message) {
    final fileName = message.metadata?['file_name']?.toString() ?? '图片';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImageViewerPage(filePath: message.source, fileName: fileName),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, VideoMessage message) {
    final fileName =
        message.metadata?['file_name']?.toString() ?? message.name ?? '视频';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            VideoPlayerPage(filePath: message.source, fileName: fileName),
      ),
    );
  }
}

bool shouldShowChatEmptyState({
  required bool loading,
  required String? error,
}) => !loading && error == null;

double _mediaAspectRatio(double? width, double? height) {
  if (width != null && height != null && width > 0 && height > 0) {
    return (width / height).clamp(0.6, 1.9);
  }
  return 1;
}

String formatChatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
