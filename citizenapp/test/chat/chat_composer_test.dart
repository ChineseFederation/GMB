import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:citizenapp/chat/chat_entry.dart';
import 'package:citizenapp/chat/chat_product_policy.dart';
import 'package:citizenapp/ui/app_layout.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

const _iphone16ProLogicalSize = Size(402, 874);

Widget _productionThemeBuilder(BuildContext context, Widget? child) =>
    Theme(data: AppTheme.lightThemeFor(context), child: child!);

class _EmptyStore extends ChatStore {
  @override
  Future<List<ChatStoredMessage>> readMessages({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
  }) async =>
      const [];
}

Widget _host({
  bool isGroup = false,
  ChatResolvePeerAddressCallback? resolvePeerAddress,
}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: _productionThemeBuilder,
      home: ChatPage(
        conversationId: isGroup ? 'group:test' : 'dm:me:peer',
        ownerUserId: 'CN220-CTZN2-100000001-2026',
        accountId:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        peerUserId: isGroup ? 'group:test' : 'CN220-CTZN2-100000002-2026',
        title: isGroup ? '测试群' : '对方',
        isGroup: isGroup,
        store: _EmptyStore(),
        onSync: () async => 0,
        resolvePeerAddress: resolvePeerAddress,
      ),
    );

Future<void> _open(
  WidgetTester tester, {
  bool isGroup = false,
  ChatResolvePeerAddressCallback? resolvePeerAddress,
}) async {
  tester.view.physicalSize = _iphone16ProLogicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _host(
      isGroup: isGroup,
      resolvePeerAddress: resolvePeerAddress,
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Widget _voiceComposerHost({
  required ValueNotifier<bool> recording,
  required TextEditingController controller,
  required FocusNode focusNode,
  required VoidCallback onStart,
  required ValueChanged<bool> onEnd,
  Duration recordingDuration = const Duration(seconds: 8),
}) {
  return ChangeNotifierProvider(
    create: (_) => ComposerHeightNotifier(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      builder: _productionThemeBuilder,
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: recording,
          builder: (context, active, _) => Stack(
            children: [
              ComposerBar(
                controller: controller,
                focusNode: focusNode,
                inputMode: ChatInputMode.voice,
                expressionOpen: false,
                actionsOpen: false,
                recording: active,
                recordingDuration: recordingDuration,
                onToggleInputMode: () {},
                onToggleExpression: () {},
                onToggleActions: () {},
                onTextInputTap: () {},
                onSendText: (_) {},
                onVoicePressStart: onStart,
                onVoicePressEnd: onEnd,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => ChatMediaLimits.applyMembershipLevel('freedom'));
  tearDown(() => ChatMediaLimits.applyMembershipLevel(null));

  testWidgets('输入栏顺序固定且键盘语音切换保留文本草稿', (tester) async {
    await _open(tester);
    final voice = find.byKey(const ValueKey('chat-input-mode-toggle'));
    final input = find.byKey(const ValueKey('chat-text-input'));
    final expression = find.byKey(const ValueKey('chat-expression-toggle'));
    final actions = find.byKey(const ValueKey('chat-actions-toggle'));
    final inputSurface = find.byKey(const ValueKey('chat-input-surface'));
    final textField = tester.widget<TextField>(input);
    final visualScale = AppLayout.visualScaleForSize(_iphone16ProLogicalSize);

    // 中间区只绘制一层紧凑圆角长方形，TextField 不得再套第二层。
    expect(inputSurface, findsOneWidget);
    expect(textField.decoration?.filled, isFalse);
    expect(textField.decoration?.border, InputBorder.none);
    expect(textField.decoration?.enabledBorder, InputBorder.none);
    expect(textField.decoration?.focusedBorder, InputBorder.none);
    expect(textField.textAlignVertical, TextAlignVertical.center);
    expect(textField.style?.height, closeTo(22 / 15, 0.0001));
    expect(textField.strutStyle?.forceStrutHeight, isTrue);
    expect(textField.cursorHeight, closeTo(22 * visualScale, 0.01));
    expect(textField.decoration?.isCollapsed, isTrue);
    expect(
      textField.decoration?.constraints?.minHeight,
      closeTo(42 * visualScale, 0.01),
    );
    expect(
      textField.decoration?.contentPadding,
      EdgeInsets.symmetric(
        horizontal: 14 * visualScale,
        vertical: 10 * visualScale,
      ),
    );
    expect(tester.getSize(inputSurface).height, closeTo(42 * visualScale, 0.5));
    final inputDecoration =
        tester.widget<DecoratedBox>(inputSurface).decoration as BoxDecoration;
    final inputRadius = inputDecoration.borderRadius! as BorderRadius;
    expect(inputRadius.topLeft.x, closeTo(10 * visualScale, 0.01));

    for (final button in [voice, expression, actions]) {
      final icon = tester.widget<Icon>(
        find.descendant(of: button, matching: find.byType(Icon)),
      );
      expect(icon.size, closeTo(30 * visualScale, 0.01));
    }

    expect(tester.getCenter(voice).dx, lessThan(tester.getCenter(input).dx));
    expect(
      tester.getCenter(input).dx,
      lessThan(tester.getCenter(expression).dx),
    );
    expect(
      tester.getCenter(expression).dx,
      lessThan(tester.getCenter(actions).dx),
    );
    final inputCenterY = tester.getCenter(input).dy;
    expect(tester.getCenter(voice).dy, closeTo(inputCenterY, 0.01));
    expect(tester.getCenter(expression).dy, closeTo(inputCenterY, 0.01));
    expect(tester.getCenter(actions).dy, closeTo(inputCenterY, 0.01));

    await tester.enterText(input, '保留的草稿');
    final editableText = find.descendant(
      of: input,
      matching: find.byType(EditableText),
    );
    expect(
      tester.getCenter(editableText).dy,
      closeTo(tester.getCenter(inputSurface).dy, 0.5),
    );
    await tester.tap(voice);
    await tester.pump();
    final holdToTalk = find.byKey(const ValueKey('chat-hold-to-talk'));
    expect(holdToTalk, findsOneWidget);
    expect(find.text('按住 说话'), findsOneWidget);
    final voiceSurface = tester.widget<AnimatedContainer>(
      find.descendant(of: holdToTalk, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (voiceSurface.decoration as BoxDecoration).color,
      Colors.transparent,
    );
    final voiceCenterY = tester.getCenter(holdToTalk).dy;
    expect(tester.getSize(holdToTalk).height, closeTo(42 * visualScale, 0.5));
    expect(tester.getCenter(voice).dy, closeTo(voiceCenterY, 0.01));
    expect(tester.getCenter(expression).dy, closeTo(voiceCenterY, 0.01));
    expect(tester.getCenter(actions).dy, closeTo(voiceCenterY, 0.01));

    await tester.tap(voice);
    await tester.pump();
    final restored = tester.widget<TextField>(input);
    expect(restored.controller?.text, '保留的草稿');
    expect(find.byTooltip('同步'), findsNothing);
  });

  testWidgets('录音浮层中央麦克风在上计时在下，左右目标分别取消和发送', (tester) async {
    tester.view.physicalSize = _iphone16ProLogicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recording = ValueNotifier(false);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(recording.dispose);
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final outcomes = <bool>[];

    await tester.pumpWidget(
      _voiceComposerHost(
        recording: recording,
        controller: controller,
        focusNode: focusNode,
        onStart: () => recording.value = true,
        recordingDuration: const Duration(minutes: 2, seconds: 59),
        onEnd: (cancel) {
          outcomes.add(cancel);
          recording.value = false;
        },
      ),
    );
    await tester.pump();

    final hold = find.byKey(const ValueKey('chat-hold-to-talk'));
    var gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump();

    final overlay = find.byKey(const ValueKey('chat-voice-recording-overlay'));
    final mic = find.byKey(const ValueKey('chat-voice-recording-mic'));
    final timer = find.byKey(const ValueKey('chat-voice-recording-timer'));
    final cancel = find.byKey(const ValueKey('chat-voice-cancel-target'));
    final send = find.byKey(const ValueKey('chat-voice-send-target'));
    expect(overlay, findsOneWidget);
    expect(find.text('02:59'), findsOneWidget);
    expect(tester.getCenter(timer).dx, closeTo(tester.getCenter(mic).dx, 0.01));
    expect(tester.getCenter(timer).dy, greaterThan(tester.getCenter(mic).dy));
    expect(
      tester.getCenter(overlay).dy,
      greaterThan(tester.view.physicalSize.height / 2),
    );
    expect(
      tester.getCenter(hold).dy - tester.getCenter(overlay).dy,
      inInclusiveRange(145, 190),
    );

    await gesture.moveTo(tester.getCenter(cancel));
    await tester.pump();
    expect(find.text('松开取消'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(outcomes, [true]);
    expect(overlay, findsNothing);

    gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump();
    await gesture.moveTo(tester.getCenter(send));
    await tester.pump();
    expect(find.text('松开发送'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(outcomes, [true, false]);
    expect(overlay, findsNothing);
  });

  testWidgets('一对一加号面板为七项且本阶段禁用语音视频通话', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('chat-actions-toggle')));
    await tester.pump();

    for (final name in const [
      'gallery',
      'capture',
      'videoCall',
      'voiceCall',
      'transfer',
      'location',
      'file',
    ]) {
      expect(find.byKey(ValueKey('chat-action-$name')), findsOneWidget);
    }
    final transferMark = tester.widget<Image>(
      find.byKey(const ValueKey('chat-action-transfer-gmb-mark')),
    );
    expect(
      (transferMark.image as AssetImage).assetName,
      'assets/icons/gmb-mark.png',
    );
    final input = find.byKey(const ValueKey('chat-text-input'));
    final panel = find.byKey(const ValueKey('chat-composer-action-panel'));
    expect(
      tester.getTopLeft(panel).dy,
      greaterThanOrEqualTo(tester.getBottomRight(input).dy),
    );

    final videoCall = find.byKey(const ValueKey('chat-action-videoCall'));
    final voiceCall = find.byKey(const ValueKey('chat-action-voiceCall'));
    expect(tester.widget<InkWell>(videoCall).onTap, isNull);
    expect(tester.widget<InkWell>(voiceCall).onTap, isNull);
  });

  testWidgets('群聊移除转账并禁用语音视频通话', (tester) async {
    await _open(tester, isGroup: true);
    await tester.tap(find.byKey(const ValueKey('chat-actions-toggle')));
    await tester.pump();
    final input = find.byKey(const ValueKey('chat-text-input'));
    final panel = find.byKey(const ValueKey('chat-composer-action-panel'));
    expect(
      tester.getTopLeft(panel).dy,
      greaterThanOrEqualTo(tester.getBottomRight(input).dy),
    );
    expect(find.byKey(const ValueKey('chat-action-transfer')), findsNothing);
    final videoCall = find.byKey(const ValueKey('chat-action-videoCall'));
    final voiceCall = find.byKey(const ValueKey('chat-action-voiceCall'));
    expect(videoCall, findsOneWidget);
    expect(voiceCall, findsOneWidget);
    expect(tester.widget<InkWell>(videoCall).onTap, isNull);
    expect(tester.widget<InkWell>(voiceCall).onTap, isNull);
    expect(find.byKey(const ValueKey('chat-action-location')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-action-file')), findsOneWidget);
  });

  testWidgets('无会员聊天窗口只显示订阅门禁且不创建输入操作', (tester) async {
    ChatMediaLimits.applyMembershipLevel(null);
    await _open(tester);

    expect(
      find.byKey(const ValueKey('chat-membership-required')),
      findsOneWidget,
    );
    expect(find.text('尚未开通会员，订阅任一会员后即可使用聊天'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-text-input')), findsNothing);
    expect(find.byKey(const ValueKey('chat-actions-toggle')), findsNothing);
  });

  testWidgets('一对一转账把对方 CID 交给 finalized 地址解析边界', (tester) async {
    String? resolvedCidNumber;
    await _open(
      tester,
      resolvePeerAddress: (cidNumber) async {
        resolvedCidNumber = cidNumber;
        throw StateError('测试停止在 finalized 地址解析边界');
      },
    );
    await tester.tap(find.byKey(const ValueKey('chat-actions-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-action-transfer')));
    await tester.pump();
    expect(resolvedCidNumber, 'CN220-CTZN2-100000002-2026');
  });
}
