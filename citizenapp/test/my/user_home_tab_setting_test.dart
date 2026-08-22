import 'package:citizenapp/isar/user_isar.dart';
import 'package:citizenapp/my/user/user.dart';
import 'package:citizenapp/ui/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/isar_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          return null;
        case 'containsKey':
          return false;
        case 'readAll':
          return <String, String>{};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  Future<void> pumpUntilSettingVisible(WidgetTester tester) async {
    for (var i = 0;
        i < 40 &&
            !tester.any(find.byKey(const ValueKey('home-tab-setting-switch')));
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  test('UserIsar 首页偏好缺省为广场并可原子往返', () async {
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isFalse);
    await UserIsar.instance.writeOpenChatOnLaunch(true);
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isTrue);
    await UserIsar.instance.writeOpenChatOnLaunch(false);
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isFalse);
  });

  testWidgets('首页设置位于安全和关于之间并同行显示广场与同款 Switch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (_) async {},
        ),
      ),
    );
    await pumpUntilSettingVisible(tester);

    final homeSetting = find.text('首页设置');
    final tileFinder = find.byKey(const ValueKey('home-tab-setting-tile'));
    final switchFinder = find.byKey(const ValueKey('home-tab-setting-switch'));
    expect(homeSetting, findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-tab-setting-value')), findsOneWidget);
    expect(find.text('广场'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(tester.getCenter(homeSetting).dy,
        closeTo(tester.getCenter(switchFinder).dy, 1));
    expect(tester.getTopLeft(homeSetting).dy,
        greaterThan(tester.getTopLeft(find.text('安全')).dy));
    expect(tester.getTopLeft(homeSetting).dy,
        lessThan(tester.getTopLeft(find.text('关于')).dy));
    // 首页设置与“我的”主页的“设置”入口共享唯一行高令牌，任何屏幕倍率都不得分叉。
    final tileContext = tester.element(tileFinder);
    expect(
      tester.getSize(tileFinder).height,
      closeTo(AppLayout.serviceEntryHeight(tileContext), 0.01),
    );
  });

  testWidgets('打开后保存 true 并立即同行显示聊天', (tester) async {
    bool? savedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (value) async => savedValue = value,
        ),
      ),
    );
    await pumpUntilSettingVisible(tester);

    await tester.tap(find.byKey(const ValueKey('home-tab-setting-switch')));
    await tester.pumpAndSettle();

    expect(find.text('聊天'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('home-tab-setting-switch')))
          .value,
      isTrue,
    );
    expect(savedValue, isTrue);
  });

  testWidgets('保存失败保持广场和关闭状态并给出重试提示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (_) async => throw StateError('write fail'),
        ),
      ),
    );
    await pumpUntilSettingVisible(tester);

    await tester.tap(find.byKey(const ValueKey('home-tab-setting-switch')));
    await tester.pumpAndSettle();

    expect(find.text('广场'), findsOneWidget);
    expect(find.text('首页设置保存失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('home-tab-setting-switch')))
          .value,
      isFalse,
    );
  });
}
