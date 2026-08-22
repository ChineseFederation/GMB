import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:citizenapp/8964/widgets/article_rich_text_view.dart';

void main() {
  testWidgets('只读文章富文本渲染规范 Delta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArticleRichTextView(
            delta: [
              {
                'insert': '静蕾体正文内容满足十字',
                'attributes': {'font': 'jinglei', 'color': 'primary'},
              },
              {'insert': '\n'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('五档规范字号按14至24像素真实渲染', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArticleRichTextView(
            delta: [
              {
                'insert': '小',
                'attributes': {'size': 'small'}
              },
              {
                'insert': '正文',
                'attributes': {'size': 'body'}
              },
              {
                'insert': '大',
                'attributes': {'size': 'large'}
              },
              {
                'insert': '副标题',
                'attributes': {'size': 'subtitle'}
              },
              {
                'insert': '标题',
                'attributes': {'size': 'title'}
              },
              {'insert': '\n'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final sizes = <String, double?>{};
    void collect(InlineSpan span) {
      if (span case TextSpan(:final text, :final style, :final children)) {
        if (text != null && text.isNotEmpty) sizes[text] = style?.fontSize;
        for (final child in children ?? const <InlineSpan>[]) {
          collect(child);
        }
      }
    }

    for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
      collect(richText.text);
    }
    expect(sizes['小'], 14);
    expect(sizes['正文'], 16);
    expect(sizes['大'], 18);
    expect(sizes['副标题'], 20);
    expect(sizes['标题'], 24);
  });
}
