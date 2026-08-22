import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/my/util/screenshot_guard.dart';
import 'package:citizenapp/wallet/core/fake_hardware_bound_seed_vault.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/wallet/pages/create_wallet_onboarding_page.dart';
import 'package:citizenapp/wallet/pages/import_wallet_page.dart';
import 'package:citizenapp/wallet/wallet_gate.dart';

import '../support/isar_test_env.dart';

WalletProfile _hotProfile() {
  return const WalletProfile(
    walletIndex: 1,
    walletName: '钱包1',
    walletIcon: 'wallet',
    balance: 0,
    ss58Address: 'gate-test-address',
    accountId:
        '0xabababababababababababababababababababababababababababababababab',
    alg: 'sr25519',
    ss58: 2027,
    createdAtMillis: 0,
    source: 'created',
    signMode: SignMode.hot,
  );
}

Widget _gate({
  required Future<WalletProfile?> Function() loader,
  void Function(BuildContext context)? onInitialized,
  Duration loadTimeout = const Duration(seconds: 5),
}) {
  return MaterialApp(
    home: WalletGate(
      defaultWalletLoader: loader,
      // 默认注入 no-op,挡掉真身份页 push(会触发真链读);验证引导的用例另注入探针。
      onInitialized: onInitialized ?? (_) {},
      loadTimeout: loadTimeout,
      child: const Scaffold(body: Text('main-shell')),
    ),
  );
}

Widget _onboarding({
  required Future<bool> Function() probe,
  VoidCallback? onCreated,
}) {
  return MaterialApp(
    home: CreateWalletOnboardingPage(
      onCreated: onCreated ?? () {},
      deviceSecureProbe: probe,
    ),
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('公民敏感页截屏保护按引用计数切换原生开关', () async {
    const channel = MethodChannel('citizenapp/security');
    final calls = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    await ScreenshotGuard.enable();
    await ScreenshotGuard.enable();
    expect(calls, ['enableScreenshotProtection']);

    await ScreenshotGuard.disable();
    expect(calls, ['enableScreenshotProtection']);

    await ScreenshotGuard.disable();
    expect(calls, [
      'enableScreenshotProtection',
      'disableScreenshotProtection',
    ]);
  });

  // 强制创建页内容较长，用高视口避免 ListView 懒加载导致断言目标未构建。
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('WalletGate', () {
    testWidgets('无钱包时进入门禁页，含创建与导入入口', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_gate(loader: () async => null));
      await tester.pumpAndSettle();

      // 标题与创建按钮同为"创建钱包"，故 findsWidgets（≥1）。
      expect(find.text('创建钱包'), findsWidgets);
      expect(find.text('main-shell'), findsNothing);
      // 门禁页提供创建与导入两条入口。
      expect(find.widgetWithText(FilledButton, '创建钱包'), findsOneWidget);
      expect(find.text('已有钱包？导入助记词'), findsOneWidget);
      // 门禁页自身无 AppBar 返回键（PopScope 禁止退出门禁）。
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('有热钱包直接放行主界面', (tester) async {
      await tester.pumpWidget(_gate(loader: () async => _hotProfile()));
      await tester.pumpAndSettle();

      expect(find.text('main-shell'), findsOneWidget);
      expect(find.byType(CreateWalletOnboardingPage), findsNothing);
    });

    testWidgets('创建成功后翻转到主界面', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_gate(loader: () async => null));
      await tester.pumpAndSettle();

      final page = tester.widget<CreateWalletOnboardingPage>(
        find.byType(CreateWalletOnboardingPage),
      );
      page.onCreated();
      await tester.pumpAndSettle();

      expect(find.text('main-shell'), findsOneWidget);
      expect(find.byType(CreateWalletOnboardingPage), findsNothing);
    });

    testWidgets('首次初始化后一次性引导到身份页(onInitialized 触发)', (tester) async {
      useTallViewport(tester);
      var introduced = 0;
      await tester.pumpWidget(_gate(
        loader: () async => null,
        onInitialized: (_) => introduced++,
      ));
      await tester.pumpAndSettle();

      tester
          .widget<CreateWalletOnboardingPage>(
            find.byType(CreateWalletOnboardingPage),
          )
          .onCreated();
      await tester.pumpAndSettle();

      expect(find.text('main-shell'), findsOneWidget);
      expect(introduced, 1, reason: '本次会话从 onboarding 建/导入应引导一次');
    });

    testWidgets('冷启动即有钱包不触发身份引导', (tester) async {
      var introduced = 0;
      await tester.pumpWidget(_gate(
        loader: () async => _hotProfile(),
        onInitialized: (_) => introduced++,
      ));
      await tester.pumpAndSettle();

      expect(find.text('main-shell'), findsOneWidget);
      expect(introduced, 0, reason: '老用户冷启动即放行,不打扰');
    });

    testWidgets('本地库读取失败停在错误态，重试后恢复', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_gate(loader: () async {
        calls++;
        if (calls == 1) {
          throw Exception('isar busy');
        }
        return _hotProfile();
      }));
      await tester.pumpAndSettle();

      // 读取失败既不误判成「无钱包」，也不放行。
      expect(find.text('本地钱包数据库繁忙，请稍后重试'), findsOneWidget);
      expect(find.text('main-shell'), findsNothing);
      expect(find.byType(CreateWalletOnboardingPage), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('main-shell'), findsOneWidget);
    });

    testWidgets('本地钱包读取永久 pending 会有界进入错误态，重试后恢复', (tester) async {
      final blocked = Completer<WalletProfile?>();
      var calls = 0;
      await tester.pumpWidget(_gate(
        loadTimeout: const Duration(milliseconds: 20),
        loader: () {
          calls++;
          return calls == 1 ? blocked.future : Future.value(_hotProfile());
        },
      ));

      await tester.pump(const Duration(milliseconds: 25));
      expect(find.textContaining('本地钱包读取失败'), findsOneWidget);
      expect(find.text('main-shell'), findsNothing);
      expect(find.byType(CreateWalletOnboardingPage), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('main-shell'), findsOneWidget);

      // 晚到旧结果不得覆盖重试后的成功状态。
      blocked.complete(null);
      await tester.pump();
      expect(find.text('main-shell'), findsOneWidget);
    });

    testWidgets('运行期钱包被删光时立即踢回门禁页', (tester) async {
      useTallViewport(tester);
      WalletProfile? current = _hotProfile();
      await tester.pumpWidget(_gate(loader: () async => current));
      await tester.pumpAndSettle();
      expect(find.text('main-shell'), findsOneWidget);

      // 模拟「我的 → 钱包列表」里删光钱包：数据没了 + 版本号自增。
      current = null;
      WalletManager.walletsRevision.value++;
      await tester.pumpAndSettle();

      expect(find.text('main-shell'), findsNothing);
      expect(find.byType(CreateWalletOnboardingPage), findsOneWidget);
    });
  });

  group('有效热钱包谓词', () {
    const accountId =
        '0xabababababababababababababababababababababababababababababababab';

    WalletProfile profile({
      String id = accountId,
      String? ss58,
      SignMode signMode = SignMode.hot,
    }) {
      return WalletProfile(
        walletIndex: 1,
        walletName: '钱包1',
        walletIcon: 'wallet',
        balance: 0,
        accountId: id,
        ss58Address: ss58 ?? ss58FromAccountIdText(accountId),
        alg: 'sr25519',
        ss58: 2027,
        createdAtMillis: 0,
        source: 'created',
        signMode: signMode,
      );
    }

    late FakeHardwareBoundSeedVault vault;

    setUp(() {
      vault = FakeHardwareBoundSeedVault();
      WalletManager.debugSeedStore = vault;
    });

    Future<void> putKey(String id) => vault.putAccountKey(
          walletIndex: 1,
          accountId: id,
          childMiniSecret: Uint8List(32),
        );

    Future<void> seedFacts(
      WalletProfile wallet, {
      bool includeAccount0 = true,
      bool includeSecondLocalWallet = false,
    }) async {
      await WalletIsar.instance.writeTxn((isar) async {
        await isar.walletProfileEntitys.put(
          WalletProfileEntity()
            ..walletIndex = wallet.walletIndex
            ..walletName = wallet.walletName
            ..walletIcon = wallet.walletIcon
            ..balance = wallet.balance
            ..accountId = wallet.accountId
            ..ss58Address = wallet.ss58Address
            ..masterId = wallet.accountId
            ..alg = wallet.alg
            ..ss58 = wallet.ss58
            ..createdAtMillis = wallet.createdAtMillis
            ..source = wallet.source
            ..signMode = wallet.signMode!.name,
        );
        if (includeAccount0 && wallet.signMode == SignMode.hot) {
          await isar.accountEntitys.put(
            AccountEntity()
              ..masterId = wallet.accountId
              ..accountIndex = 0
              ..accountId = wallet.accountId
              ..ss58Address = wallet.ss58Address
              ..accountName = '账户0'
              ..createdAtMillis = 0,
          );
        }
        if (includeSecondLocalWallet) {
          const secondId =
              '0xcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
          final secondSs58 = ss58FromAccountIdText(secondId);
          await isar.walletProfileEntitys.put(
            WalletProfileEntity()
              ..walletIndex = 2
              ..walletName = '钱包2'
              ..walletIcon = 'wallet'
              ..balance = 0
              ..accountId = secondId
              ..ss58Address = secondSs58
              ..masterId = secondId
              ..alg = 'sr25519'
              ..ss58 = 2027
              ..createdAtMillis = 0
              ..source = 'created'
              ..signMode = SignMode.hot.name,
          );
          await isar.accountEntitys.put(
            AccountEntity()
              ..masterId = secondId
              ..accountIndex = 0
              ..accountId = secondId
              ..ss58Address = secondSs58
              ..accountName = '账户0'
              ..createdAtMillis = 0,
          );
        }
      });
    }

    test('热钱包 + accountId 规范 + ss58 一致 + 有 child → 有效', () async {
      await seedFacts(profile());
      await putKey(accountId);
      expect(await WalletManager().isUsableHotWallet(profile()), isTrue);
    });

    test('冷钱包不作为门控依据', () async {
      await seedFacts(profile(signMode: SignMode.cold));
      await putKey(accountId);
      expect(
        await WalletManager().isUsableHotWallet(
          profile(signMode: SignMode.cold),
        ),
        isFalse,
      );
    });

    test('accountId 为空的半残钱包不作为门控依据', () async {
      await seedFacts(
        profile(id: '', ss58: 'x'),
        includeAccount0: false,
      );
      await putKey(accountId);
      expect(
        await WalletManager().isUsableHotWallet(profile(id: '', ss58: 'x')),
        isFalse,
      );
    });

    test('ss58 与 accountId 对不上不作为门控依据', () async {
      await seedFacts(profile(ss58: 'wrong-address'));
      await putKey(accountId);
      expect(
        await WalletManager().isUsableHotWallet(profile(ss58: '对不上的地址')),
        isFalse,
      );
    });

    test('有壳无钥（严档 child 条目缺失）不作为门控依据', () async {
      await seedFacts(profile());
      expect(await WalletManager().isUsableHotWallet(profile()), isFalse);
    });

    test('缺账户0锚点即使有 child 也不得开放热钱包能力', () async {
      await seedFacts(profile(), includeAccount0: false);
      await putKey(accountId);

      expect(await WalletManager().isUsableHotWallet(profile()), isFalse);
    });

    test('重复 Hot 钱包不得静默选第一只开放热钱包能力', () async {
      await seedFacts(profile(), includeSecondLocalWallet: true);
      await putKey(accountId);

      expect(await WalletManager().isUsableHotWallet(profile()), isFalse);
    });
  });

  group('CreateWalletOnboardingPage', () {
    testWidgets('创建页展示完整备份风险文案并删除重复截屏提示', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_onboarding(probe: () async => true));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '钱包账户是 公民App 唯一的账户，请务必妥善保存助记词和钱包密码（如设置），'
          '若丢失或遗忘将永久无法找回。',
        ),
        findsOneWidget,
      );
      expect(
        find.text('账户私钥经硬件加密储存在本机，本机不会保存助记词'),
        findsOneWidget,
      );
      expect(find.text('展示助记词时禁止截屏，不支持复制'), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('未开启系统锁屏：警示卡展示且创建按钮禁用', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_onboarding(probe: () async => false));
      await tester.pumpAndSettle();

      expect(find.text('未检测到系统锁屏'), findsOneWidget);
      expect(find.text('开启系统锁屏后可创建'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '创建钱包'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('重新检测通过后创建按钮启用', (tester) async {
      useTallViewport(tester);
      var secure = false;
      await tester.pumpWidget(_onboarding(probe: () async => secure));
      await tester.pumpAndSettle();
      expect(find.text('未检测到系统锁屏'), findsOneWidget);

      secure = true;
      await tester.tap(find.text('重新检测'));
      await tester.pumpAndSettle();

      expect(find.text('未检测到系统锁屏'), findsNothing);
      expect(find.text('创建完成后进入公民广场'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '创建钱包'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('默认选中 12 词（推荐），可切换 24 词', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_onboarding(probe: () async => true));
      await tester.pumpAndSettle();

      expect(find.text('12 个助记词'), findsOneWidget);
      expect(find.text('24 个助记词'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);

      Finder selectedIconIn(String cardTitle) => find.descendant(
            of: find.ancestor(
              of: find.text(cardTitle),
              matching: find.byType(InkWell),
            ),
            matching: find.byIcon(Icons.check_circle),
          );

      expect(selectedIconIn('12 个助记词'), findsOneWidget);
      expect(selectedIconIn('24 个助记词'), findsNothing);

      await tester.tap(find.text('24 个助记词'));
      await tester.pump();

      expect(selectedIconIn('24 个助记词'), findsOneWidget);
      expect(selectedIconIn('12 个助记词'), findsNothing);
    });

    testWidgets('点导入入口进入 ImportWalletPage', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_onboarding(probe: () async => true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('已有钱包？导入助记词'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportWalletPage), findsOneWidget);
      expect(find.text('输入助记词'), findsOneWidget);
      expect(find.text('导入热钱包'), findsNothing);
      expect(find.text('逐个输入单词，从候选列表中选择匹配项'), findsNothing);
      expect(find.text('仅使用默认派生路径，不暴露自定义路径。'), findsNothing);
    });
  });
}
