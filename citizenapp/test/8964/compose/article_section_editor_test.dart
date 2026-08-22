import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:citizenapp/8964/compose/article/article_section_editor.dart';

void main() {
  group('文章 Delta 规范化', () {
    test('保留开放样式并删除任意值、链接和媒体嵌入', () {
      final normalized = normalizeArticleDelta([
        {
          'insert': '规范文字',
          'attributes': {
            'bold': true,
            'font': 'jinglei',
            'size': 99,
            'color': '#123456',
            'link': 'https://invalid.test',
          },
        },
        {
          'insert': {'image': 'x'}
        },
        const {
          'insert': '\n',
          'attributes': {'align': 'center'}
        },
      ]);
      expect(normalized, [
        {
          'insert': '规范文字',
          'attributes': {'bold': true, 'font': 'jinglei'},
        },
        const {
          'insert': '\n',
          'attributes': {'align': 'center'}
        },
      ]);
    });

    test('块格式只留在换行符并始终补规范结尾', () {
      expect(
        normalizeArticleDelta([
          const {
            'insert': '正文',
            'attributes': {'list': 'bullet'},
          },
        ]),
        [
          const {'insert': '正文'},
          const {'insert': '\n'}
        ],
      );
    });

    test('纯文本按 Unicode 内容提取', () {
      expect(
        articleDeltaPlainText([
          const {'insert': '你好🙂'},
          const {'insert': '\n'},
        ]),
        '你好🙂',
      );
    });
  });

  testWidgets('字号菜单把选中文字写为规范标题字号', (tester) async {
    final controller = articleQuillController([
      const {'insert': '规范文字'},
      const {'insert': '\n'},
    ]);
    addTearDown(controller.dispose);
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      ChangeSource.local,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArticleRichTextToolbar(controller: controller)),
      ),
    );

    await tester.tap(find.byIcon(Icons.format_size));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标题'));
    await tester.pumpAndSettle();

    expect(articleControllerDelta(controller), [
      const {
        'insert': '规范文字',
        'attributes': {'size': 'title'},
      },
      const {'insert': '\n'},
    ]);
  });
}
