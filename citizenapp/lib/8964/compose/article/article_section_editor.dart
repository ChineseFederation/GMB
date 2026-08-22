import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:citizenapp/ui/app_theme.dart';

/// 文章富文本协议只允许这些稳定令牌；客户端和 Cloudflare 必须保持同一集合。
const articleFontTokens = <String>{
  'heiti',
  'songti',
  'kaiti',
  'monospace',
  'jinglei',
};
const articleSizeTokens = <String>{
  'small',
  'body',
  'large',
  'subtitle',
  'title',
};
const articleColorTokens = <String>{
  'default',
  'secondary',
  'primary',
  'info',
  'success',
  'warning',
  'danger',
};
const articleBackgroundTokens = <String>{
  'neutral_soft',
  'primary_soft',
  'info_soft',
  'success_soft',
  'warning_soft',
  'danger_soft',
};

const _inlineBooleanAttributes = <String>{
  'bold',
  'italic',
  'underline',
  'strike',
};
const _blockAttributes = <String>{'align', 'list'};

/// 把任意 Delta 输入规范化为文章协议允许的纯文字操作。
///
/// 媒体对象、未知属性、任意字号/颜色均会被删除；换行会拆成独立操作，
/// 从而保证块属性只出现在换行符上。返回值始终以一个换行符结束。
List<Map<String, Object?>> normalizeArticleDelta(Object? raw) {
  final source = raw is List ? raw : const <Object?>[];
  final normalized = <Map<String, Object?>>[];
  for (final rawOperation in source) {
    if (rawOperation is! Map) continue;
    final insert = rawOperation['insert'];
    if (insert is! String || insert.isEmpty) continue;
    final rawAttributes = rawOperation['attributes'];
    final inline = _normalizeInlineAttributes(rawAttributes);
    final block = _normalizeBlockAttributes(rawAttributes);
    var start = 0;
    for (var index = 0; index < insert.length; index++) {
      if (insert.codeUnitAt(index) != 10) continue;
      if (index > start) {
        _appendArticleOperation(
            normalized, insert.substring(start, index), inline);
      }
      _appendArticleOperation(normalized, '\n', block);
      start = index + 1;
    }
    if (start < insert.length) {
      _appendArticleOperation(normalized, insert.substring(start), inline);
    }
  }
  if (normalized.isEmpty || normalized.last['insert'] != '\n') {
    normalized.add(const {'insert': '\n'});
  }
  return normalized;
}

Map<String, Object?> _normalizeInlineAttributes(Object? raw) {
  if (raw is! Map) return const {};
  final result = <String, Object?>{};
  for (final key in _inlineBooleanAttributes) {
    if (raw[key] == true) result[key] = true;
  }
  final font = raw['font'];
  if (font is String && articleFontTokens.contains(font)) {
    result['font'] = font;
  }
  final size = raw['size'];
  if (size is String && articleSizeTokens.contains(size)) {
    result['size'] = size;
  }
  final color = raw['color'];
  if (color is String && articleColorTokens.contains(color)) {
    result['color'] = color;
  }
  final background = raw['background'];
  if (background is String && articleBackgroundTokens.contains(background)) {
    result['background'] = background;
  }
  return result;
}

Map<String, Object?> _normalizeBlockAttributes(Object? raw) {
  if (raw is! Map) return const {};
  final result = <String, Object?>{};
  final align = raw['align'];
  if (align == 'center' || align == 'right') result['align'] = align;
  final list = raw['list'];
  if (list == 'ordered' || list == 'bullet') result['list'] = list;
  return result;
}

void _appendArticleOperation(
  List<Map<String, Object?>> target,
  String insert,
  Map<String, Object?> attributes,
) {
  if (insert.isEmpty) return;
  final operation = <String, Object?>{
    'insert': insert,
    if (attributes.isNotEmpty)
      'attributes': Map<String, Object?>.of(attributes),
  };
  if (target.isNotEmpty &&
      target.last['insert'] is String &&
      target.last['insert'] != '\n' &&
      insert != '\n' &&
      _sameAttributes(target.last['attributes'], operation['attributes'])) {
    target.last['insert'] = '${target.last['insert']}$insert';
  } else {
    target.add(operation);
  }
}

bool _sameAttributes(Object? left, Object? right) {
  final a = left is Map ? left : const {};
  final b = right is Map ? right : const {};
  if (a.length != b.length) return false;
  return a.entries.every((entry) => b[entry.key] == entry.value);
}

/// 供摘要、搜索和长度校验使用的唯一纯文本提取口径。
String articleDeltaPlainText(Object? raw) {
  final buffer = StringBuffer();
  for (final operation in normalizeArticleDelta(raw)) {
    buffer.write(operation['insert']);
  }
  return buffer.toString().trim();
}

QuillController articleQuillController([Object? delta]) => QuillController(
      document: Document.fromJson(
        normalizeArticleDelta(delta).map(_protocolToQuillOperation).toList(),
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

List<Map<String, Object?>> articleControllerDelta(QuillController controller) =>
    normalizeArticleDelta(
      controller.document
          .toDelta()
          .toJson()
          .map(_quillToProtocolOperation)
          .toList(),
    );

const _fontToQuill = <String, String>{
  'heiti': 'sans-serif',
  'songti': 'serif',
  'kaiti': 'LXGWWenKaiLite',
  'monospace': 'monospace',
  'jinglei': 'FZJingLeiS',
};
const _sizeToQuill = <String, String>{
  'small': '14',
  'body': '16',
  'large': '18',
  'subtitle': '20',
  'title': '24',
};
const _colorToQuill = <String, String>{
  'default': '#1A2B3C',
  'secondary': '#5A6B7C',
  'primary': '#007A74',
  'info': '#3B82F6',
  'success': '#22C55E',
  'warning': '#F59E0B',
  'danger': '#EF4444',
};
const _backgroundToQuill = <String, String>{
  'neutral_soft': '#F0F4F8',
  'primary_soft': '#D9F0EE',
  'info_soft': '#E1ECFE',
  'success_soft': '#E0F7E8',
  'warning_soft': '#FEF0D5',
  'danger_soft': '#FDE4E4',
};

Map<String, Object?> _protocolToQuillOperation(
        Map<String, Object?> operation) =>
    _mapOperationAttributes(
        operation,
        (key, value) => switch (key) {
              'font' => _fontToQuill[value] ?? value,
              'size' => _sizeToQuill[value] ?? value,
              'color' => _colorToQuill[value] ?? value,
              'background' => _backgroundToQuill[value] ?? value,
              _ => value,
            });

Map<String, Object?> _quillToProtocolOperation(Object? raw) {
  if (raw is! Map) return const {'insert': '\n'};
  final operation = raw.map((key, value) => MapEntry(key.toString(), value));
  return _mapOperationAttributes(
      operation,
      (key, value) => switch (key) {
            'font' => _fontToQuill.entries
                    .where((entry) => entry.value == value)
                    .map((entry) => entry.key)
                    .firstOrNull ??
                value,
            'size' => _sizeToQuill.entries
                    .where((entry) => entry.value == value.toString())
                    .map((entry) => entry.key)
                    .firstOrNull ??
                value,
            'color' => _colorToQuill.entries
                    .where((entry) =>
                        entry.value.toLowerCase() ==
                        value.toString().toLowerCase())
                    .map((entry) => entry.key)
                    .firstOrNull ??
                value,
            'background' => _backgroundToQuill.entries
                    .where((entry) =>
                        entry.value.toLowerCase() ==
                        value.toString().toLowerCase())
                    .map((entry) => entry.key)
                    .firstOrNull ??
                value,
            _ => value,
          });
}

Map<String, Object?> _mapOperationAttributes(
  Map<String, Object?> operation,
  Object? Function(String key, Object? value) convert,
) {
  final rawAttributes = operation['attributes'];
  if (rawAttributes is! Map || rawAttributes.isEmpty) {
    return {'insert': operation['insert'] ?? ''};
  }
  return {
    'insert': operation['insert'] ?? '',
    'attributes': {
      for (final entry in rawAttributes.entries)
        entry.key.toString(): convert(entry.key.toString(), entry.value),
    },
  };
}

/// 单个段落的富文本输入框。左滑手势只作用于文本框，删除结果由父级决定。
class ArticleSectionEditor extends StatelessWidget {
  const ArticleSectionEditor({
    super.key,
    required this.sectionKey,
    required this.controller,
    required this.focusNode,
    required this.invalid,
    required this.mediaAction,
    required this.confirmDelete,
    required this.onDeleted,
  });

  final Key sectionKey;
  final QuillController controller;
  final FocusNode focusNode;
  final bool invalid;
  final Widget mediaAction;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultStyles.getInstance(context);
    return Dismissible(
      key: sectionKey,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(),
      onDismissed: (_) => onDeleted(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border:
              Border.all(color: invalid ? AppTheme.danger : AppTheme.border),
        ),
        // 右、下边距统一为 0，使媒体入口与首图、添加图文框共享同一内容右边界。
        padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              // 右下角固定媒体入口不占正文命中区，富文本为其预留足够空间。
              padding: const EdgeInsets.only(right: 36, bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuillEditor.basic(
                    controller: controller,
                    focusNode: focusNode,
                    config: QuillEditorConfig(
                      scrollable: false,
                      expands: false,
                      minHeight: 76,
                      placeholder: '正文…',
                      embedBuilders: const [],
                      customStyles: DefaultStyles(
                        paragraph: defaults.paragraph?.copyWith(
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (invalid)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '输入内容后至少需要 10 个字',
                        style: TextStyle(color: AppTheme.danger, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(right: 0, bottom: 0, child: mediaAction),
          ],
        ),
      ),
    );
  }
}

/// 当前聚焦段落使用的规范工具栏；所有操作只写入白名单令牌。
class ArticleRichTextToolbar extends StatefulWidget {
  const ArticleRichTextToolbar({super.key, required this.controller});

  final QuillController controller;

  @override
  State<ArticleRichTextToolbar> createState() => _ArticleRichTextToolbarState();
}

class _ArticleRichTextToolbarState extends State<ArticleRichTextToolbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant ArticleRichTextToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool _selected(Attribute attribute) =>
      widget.controller.getSelectionStyle().attributes[attribute.key]?.value ==
      attribute.value;

  void _toggle(Attribute attribute) {
    widget.controller.formatSelection(
      _selected(attribute) ? Attribute.clone(attribute, null) : attribute,
    );
  }

  void _formatToken(Attribute origin, String? value) {
    final quillValue = switch (origin.key) {
      'font' => value == null ? null : _fontToQuill[value],
      'size' => value == null ? null : _sizeToQuill[value],
      'color' => value == null ? null : _colorToQuill[value],
      'background' => value == null ? null : _backgroundToQuill[value],
      _ => value,
    };
    widget.controller.formatSelection(Attribute.clone(origin, quillValue));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _history(
              Icons.undo, widget.controller.hasUndo, widget.controller.undo),
          _history(
              Icons.redo, widget.controller.hasRedo, widget.controller.redo),
          _toggleButton(Icons.format_bold, Attribute.bold),
          _toggleButton(Icons.format_italic, Attribute.italic),
          _toggleButton(Icons.format_underlined, Attribute.underline),
          _toggleButton(Icons.strikethrough_s, Attribute.strikeThrough),
          _menu(
            Icons.font_download_outlined,
            const {
              '黑体': 'heiti',
              '宋体': 'songti',
              '楷体': 'kaiti',
              '等宽': 'monospace',
              '静蕾体': 'jinglei',
            },
            (value) => _formatToken(Attribute.font, value),
          ),
          _menu(
            Icons.format_size,
            const {
              '小': 'small',
              '正文': 'body',
              '大': 'large',
              '副标题': 'subtitle',
              '标题': 'title'
            },
            (value) => _formatToken(Attribute.size, value),
          ),
          _menu(
            Icons.format_color_text,
            const {
              '默认': 'default',
              '次要': 'secondary',
              '主题': 'primary',
              '蓝': 'info',
              '绿': 'success',
              '橙': 'warning',
              '红': 'danger'
            },
            (value) => _formatToken(Attribute.color, value),
          ),
          _menu(
            Icons.format_color_fill,
            const {
              '无': '',
              '浅灰': 'neutral_soft',
              '浅主题': 'primary_soft',
              '浅蓝': 'info_soft',
              '浅绿': 'success_soft',
              '浅橙': 'warning_soft',
              '浅红': 'danger_soft'
            },
            (value) => _formatToken(
                Attribute.background, value.isEmpty ? null : value),
          ),
          _toggleButton(Icons.format_align_left, Attribute.leftAlignment),
          _toggleButton(Icons.format_align_center, Attribute.centerAlignment),
          _toggleButton(Icons.format_align_right, Attribute.rightAlignment),
          _toggleButton(Icons.format_list_bulleted, Attribute.ul),
          _toggleButton(Icons.format_list_numbered, Attribute.ol),
          IconButton(
            tooltip: '清除格式',
            onPressed: () {
              for (final key in <String>{
                ..._inlineBooleanAttributes,
                ..._blockAttributes,
                'font',
                'size',
                'color',
                'background',
              }) {
                final origin = Attribute.fromKeyValue(key, null);
                if (origin != null) widget.controller.formatSelection(origin);
              }
            },
            icon: const Icon(Icons.format_clear),
          ),
        ],
      ),
    );
  }

  Widget _history(IconData icon, bool enabled, VoidCallback action) =>
      IconButton(
        onPressed: enabled ? action : null,
        icon: Icon(icon),
      );

  Widget _toggleButton(IconData icon, Attribute attribute) => IconButton(
        onPressed: () => _toggle(attribute),
        color: _selected(attribute) ? AppTheme.primary : AppTheme.textSecondary,
        icon: Icon(icon),
      );

  Widget _menu(
    IconData icon,
    Map<String, String> values,
    ValueChanged<String> onSelected,
  ) =>
      PopupMenuButton<String>(
        tooltip: '选择格式',
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final entry in values.entries)
            PopupMenuItem(value: entry.value, child: Text(entry.key)),
        ],
        icon: Icon(icon, color: AppTheme.textSecondary),
      );
}
