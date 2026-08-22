import 'package:flutter/material.dart';

import 'package:citizenapp/ui/app_layout.dart';
import 'package:citizenapp/ui/app_theme.dart';

/// 聊天加号面板的唯一动作集合。通话和位置保留目标动作名，但当前只允许显示未开放提示。
enum ChatComposerAction {
  gallery,
  capture,
  videoCall,
  voiceCall,
  transfer,
  location,
  file,
}

/// 输入栏下方四列动作网格。一对一为 4+3，群聊移除转账后为 4+2。
class ComposerActionPanel extends StatelessWidget {
  const ComposerActionPanel({
    super.key,
    required this.isGroup,
    required this.onAction,
  });

  final bool isGroup;
  final ValueChanged<ChatComposerAction> onAction;

  static const _items = <_ActionItem>[
    _ActionItem(ChatComposerAction.gallery, Icons.photo_library_rounded, '相册'),
    _ActionItem(ChatComposerAction.capture, Icons.photo_camera_rounded, '拍摄'),
    _ActionItem(ChatComposerAction.videoCall, Icons.videocam_rounded, '视频通话',
        unavailable: true),
    _ActionItem(ChatComposerAction.voiceCall, Icons.call_rounded, '语音通话',
        unavailable: true),
    _ActionItem(
      ChatComposerAction.transfer,
      null,
      '转账',
      iconAsset: 'assets/icons/gmb-mark.png',
    ),
    _ActionItem(ChatComposerAction.location, Icons.location_on_rounded, '位置',
        unavailable: true),
    _ActionItem(ChatComposerAction.file, Icons.insert_drive_file_rounded, '文件'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final item in _items)
        if (!(isGroup && item.action == ChatComposerAction.transfer)) item,
    ];
    return ColoredBox(
      key: const ValueKey('chat-composer-action-panel'),
      color: AppTheme.surfaceCard,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppLayout.scaled(context, 18),
          AppLayout.scaled(context, 18),
          AppLayout.scaled(context, 18),
          AppLayout.scaled(context, 22),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: AppLayout.scaled(context, 86),
          mainAxisSpacing: AppLayout.scaled(context, 12),
          crossAxisSpacing: AppLayout.scaled(context, 14),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _ActionButton(item: item, onTap: () => onAction(item.action));
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item, required this.onTap});

  final _ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = item.unavailable
        ? AppTheme.textSecondary.withValues(alpha: 0.48)
        : AppTheme.textPrimary;
    return Semantics(
      button: true,
      label: item.unavailable ? '${item.label}，功能完善中' : item.label,
      child: InkWell(
        key: ValueKey('chat-action-${item.action.name}'),
        borderRadius: BorderRadius.circular(AppLayout.scaled(context, 14)),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppLayout.scaled(context, 56),
              height: AppLayout.scaled(context, 56),
              decoration: BoxDecoration(
                color: item.unavailable
                    ? AppTheme.surfaceElevated.withValues(alpha: 0.6)
                    : AppTheme.surfaceElevated,
                borderRadius:
                    BorderRadius.circular(AppLayout.scaled(context, 14)),
              ),
              alignment: Alignment.center,
              child: item.iconAsset == null
                  ? Icon(
                      item.icon!,
                      size: AppLayout.scaled(context, 25),
                      color: foreground,
                    )
                  : ExcludeSemantics(
                      child: Image.asset(
                        item.iconAsset!,
                        key: ValueKey(
                          'chat-action-${item.action.name}-gmb-mark',
                        ),
                        width: AppLayout.scaled(context, 25),
                        height: AppLayout.scaled(context, 25),
                        color: foreground,
                        colorBlendMode: BlendMode.srcIn,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
            ),
            SizedBox(height: AppLayout.scaled(context, 6)),
            Text(
              item.label,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: AppLayout.scaled(context, 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem(
    this.action,
    this.icon,
    this.label, {
    this.unavailable = false,
    this.iconAsset,
  }) : assert(icon != null || iconAsset != null);

  final ChatComposerAction action;
  final IconData? icon;
  final String label;
  final bool unavailable;
  final String? iconAsset;
}
