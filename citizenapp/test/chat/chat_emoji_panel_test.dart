import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizenapp/chat/chat_page.dart';
import 'package:citizenapp/chat/compose/sticker_panel.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';

class _EmptyStore extends ChatStore {
  @override
  Future<List<ChatStoredMessage>> readMessages({
    required String ownerCidNumber,
    required String currentAccountId,
    required String conversationId,
  }) async =>
      const [];
}

Widget _host({ChatSendTextCallback? onSendText}) => MaterialApp(
      home: ChatPage(
        conversationId: 'conv-emoji',
        ownerCidNumber: 'CN220-CTZN2-100000001-2026',
        accountId:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        peerUserId:
            '0x2222222222222222222222222222222222222222222222222222222222222222',
        title: 'Bob',
        store: _EmptyStore(),
        onSync: () async => 0,
        onSendText: onSendText,
      ),
    );

Future<void> _settleOpen(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('点表情开关弹 EmojiPicker,再点收起', (tester) async {
    await tester.pumpWidget(_host());
    await _settleOpen(tester);

    expect(find.byType(EmojiPicker), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-expression-toggle')));
    await tester.pump();
    expect(find.byType(EmojiPicker), findsOneWidget);
    final input = find.byKey(const ValueKey('chat-text-input'));
    final panel = find.byKey(const ValueKey('chat-expression-panel'));
    expect(
      tester.getTopLeft(panel).dy,
      greaterThanOrEqualTo(tester.getBottomRight(input).dy),
    );
    await tester.tap(find.byKey(const ValueKey('chat-expression-toggle')));
    await tester.pump();
    expect(find.byType(EmojiPicker), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-text-input')))
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('表情面板打开时点文本框，关闭面板并只打开键盘', (tester) async {
    await tester.pumpWidget(_host());
    await _settleOpen(tester);

    final toggle = find.byKey(const ValueKey('chat-expression-toggle'));
    final input = find.byKey(const ValueKey('chat-text-input'));
    await tester.tap(toggle);
    await tester.pump();
    expect(find.byType(EmojiPicker), findsOneWidget);
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isFalse);

    await tester.tap(input);
    await tester.pump();
    expect(find.byType(EmojiPicker), findsNothing);
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('表情底栏左侧删除、右侧发送，发送不弹系统键盘', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_host(onSendText: (text) async => sent.add(text)));
    await _settleOpen(tester);

    await tester.tap(find.byKey(const ValueKey('chat-expression-toggle')));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-text-input')),
    );
    final controller = input.controller!;
    final backspace = find.byKey(const ValueKey('chat-emoji-backspace'));
    final send = find.byKey(const ValueKey('chat-emoji-send'));
    expect(backspace, findsOneWidget);
    expect(send, findsOneWidget);
    expect(tester.getCenter(backspace).dx, lessThan(tester.getCenter(send).dx));

    controller.text = '🙂🙂';
    await tester.pump();
    await tester.tap(backspace);
    await tester.pump();
    expect(controller.text, '🙂');

    controller.text = '你好🙂';
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(sent, <String>['你好🙂']);
    expect(controller.text, isEmpty);
    expect(find.byType(EmojiPicker), findsOneWidget);
    expect(input.focusNode?.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('EmojiPicker 与输入框共用同一 controller,文本经 onSendText 发出',
      (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_host(onSendText: (text) async => sent.add(text)));
    await _settleOpen(tester);

    // 开表情面板,断言 EmojiPicker 与 Composer 的 controller 为同一实例——emoji 插入
    // 的文本才会进入将被发送的输入框(接错 controller 会静默丢字)。
    await tester.tap(find.byKey(const ValueKey('chat-expression-toggle')));
    await tester.pump();
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-text-input')),
    );
    final picker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    expect(
      identical(input.controller, picker.textEditingController),
      isTrue,
    );

    // 直接向 composer 文本框输入(确定性替代点真 emoji 格:网格异步加载不可靠),
    // 走键盘 action 的共享文本发送链路。
    await tester.enterText(
      find.byKey(const ValueKey('chat-text-input')),
      '你好🙂',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sent.single, '你好🙂');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('同一表达面板内切换表情与贴纸', (tester) async {
    await tester.pumpWidget(_host());
    await _settleOpen(tester);

    // 开表情
    await tester.tap(find.byKey(const ValueKey('chat-expression-toggle')));
    await tester.pump();
    expect(find.byType(EmojiPicker), findsOneWidget);
    expect(find.byType(StickerPanel), findsNothing);

    // 切贴纸 → 表情自动关
    await tester.tap(find.byKey(const ValueKey('chat-expression-sticker')));
    await tester.pump();
    expect(find.byType(EmojiPicker), findsNothing);
    expect(find.byType(StickerPanel), findsOneWidget);
    final input = find.byKey(const ValueKey('chat-text-input'));
    final panel = find.byKey(const ValueKey('chat-expression-panel'));
    expect(
      tester.getTopLeft(panel).dy,
      greaterThanOrEqualTo(tester.getBottomRight(input).dy),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
