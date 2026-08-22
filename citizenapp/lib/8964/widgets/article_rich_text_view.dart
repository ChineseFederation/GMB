import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:citizenapp/8964/compose/article/article_section_editor.dart';
import 'package:citizenapp/ui/app_theme.dart';

/// 公开文章与本地发布副本共用的只读富文本渲染器。
class ArticleRichTextView extends StatefulWidget {
  const ArticleRichTextView({super.key, required this.delta});

  final List<Map<String, Object?>> delta;

  @override
  State<ArticleRichTextView> createState() => _ArticleRichTextViewState();
}

class _ArticleRichTextViewState extends State<ArticleRichTextView> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode(canRequestFocus: false);
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = articleQuillController(widget.delta)..readOnly = true;
  }

  @override
  void didUpdateWidget(covariant ArticleRichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delta != widget.delta) {
      _controller.dispose();
      _controller = articleQuillController(widget.delta)..readOnly = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultStyles.getInstance(context);
    return QuillEditor(
      controller: _controller,
      focusNode: _focusNode,
      scrollController: _scrollController,
      config: QuillEditorConfig(
        scrollable: false,
        showCursor: false,
        enableInteractiveSelection: true,
        embedBuilders: const [],
        padding: const EdgeInsets.symmetric(vertical: 6),
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
    );
  }
}
