import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/wallet/pages/wallet_page.dart';

/// WalletListTile v6 渲染契约 ——
/// - 不渲染「当前」标签(active 概念已废)
/// - 不渲染扫码按钮(扫码功能彻底移除)
/// - 钱包图标按冷热配色(热=AppTheme.primaryDark / 冷=AppTheme.info)
/// - 三点菜单只有 重命名/删除钱包 2 项
/// - InkWell 整卡点击触发 onTap
/// - showActions=false 时隐藏三点菜单
void main() {
  testWidgets('导入冷钱包只提示账户地址并使用公民钱包中文名称', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ImportColdWalletPage()),
    );

    expect(find.text('请输入冷钱包账户地址'), findsNWidgets(2));
    expect(
      find.text('私钥保存在 公民钱包 签名设备上，签名请通过 公民钱包 扫码完成。'),
      findsOneWidget,
    );
    expect(find.textContaining('CitizenWallet'), findsNothing);
    expect(find.textContaining('公钥'), findsNothing);
  });

  group('extractColdWalletImportAddress', () {
    const address = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
    const publicKey =
        '0x1111111111111111111111111111111111111111111111111111111111111111';

    test('从用户码 user_contact 提取地址(单字母 c/n,SS58 本机派生)', () {
      // 码内只有 CID 与 account_id;展示地址由 account_id 在本机派生。
      const raw =
          '{"p":"QR_V1","k":3,"b":{"c":"CN001-CTZN-000000001-2026","n":"$publicKey"}}';

      expect(
        extractColdWalletImportAddress(raw),
        ss58FromAccountIdText(publicKey),
      );
    });

    test('从账户码 account_id_code 提取地址', () {
      const raw = '{"p":"QR_V1","k":5,"b":{"n":"$publicKey"}}';

      expect(
        extractColdWalletImportAddress(raw),
        ss58FromAccountIdText(publicKey),
      );
    });

    test('拒绝已删除的 account scheme 扫码内容', () {
      expect(extractColdWalletImportAddress('gmb://account/$address'), isNull);
    });

    test('拒绝把 AccountId 当成冷钱包展示地址导入', () {
      expect(extractColdWalletImportAddress(publicKey), isNull);
    });

    test('非钱包地址二维码返回 null', () {
      expect(extractColdWalletImportAddress('not a wallet qr'), isNull);
    });
  });

  WalletProfile makeWallet({
    required SignMode? signMode,
    int walletIndex = 1,
    String walletName = '我的钱包',
    double balance = 1234567.89,
  }) {
    return WalletProfile(
      walletIndex: walletIndex,
      walletName: walletName,
      walletIcon: 'wallet',
      balance: balance,
      ss58Address: 'addr_$walletIndex',
      accountId: '0x${walletIndex.toRadixString(16).padLeft(64, '0')}',
      alg: 'sr25519',
      ss58: 2027,
      createdAtMillis: 0,
      source: 'test',
      signMode: signMode,
    );
  }

  Future<void> pumpTile(
    WidgetTester tester, {
    required WalletProfile wallet,
    bool showActions = true,
    bool isDefault = false,
    bool isBroken = false,
    VoidCallback? onTap,
    VoidCallback? onRename,
    VoidCallback? onDelete,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletListTile(
            wallet: wallet,
            showActions: showActions,
            isDefault: isDefault,
            isBroken: isBroken,
            onTap: onTap ?? () {},
            onRename: onRename ?? () {},
            onDelete: onDelete ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('渲染钱包名 + 余额千分位文本', (tester) async {
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.hot, walletName: '我的钱包'),
    );
    expect(find.text('我的钱包'), findsOneWidget);
    expect(find.text('1,234,567.89'), findsOneWidget);
  });

  testWidgets('热钱包不渲染「当前」文本(active 概念已废)', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.hot));
    expect(find.text('当前'), findsNothing);
  });

  testWidgets('冷钱包不渲染「当前」文本(active 概念已废)', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.cold));
    expect(find.text('当前'), findsNothing);
  });

  testWidgets('热钱包不渲染扫码按钮(扫码功能已删)', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.hot));
    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
  });

  testWidgets('冷钱包不渲染扫码按钮(扫码功能已删)', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.cold));
    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
  });

  testWidgets('热钱包图标 Icon 颜色为 AppTheme.primaryDark', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.hot));
    final iconWidget = tester.widget<Icon>(
      find.byIcon(Icons.account_balance_wallet_rounded).first,
    );
    expect(iconWidget.color, AppTheme.primaryDark);
  });

  testWidgets('冷钱包图标 Icon 颜色为 AppTheme.info', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.cold));
    final iconWidget = tester.widget<Icon>(
      find.byIcon(Icons.account_balance_wallet_rounded).first,
    );
    expect(iconWidget.color, AppTheme.info);
  });

  testWidgets('三点菜单只有「重命名」和「删除钱包」2 项,无「钱包详情」', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.hot));
    // 点开三点菜单
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('删除钱包'), findsOneWidget);
    // 关键防回归:不允许残留「钱包详情」菜单项
    expect(find.text('钱包详情'), findsNothing);
  });

  testWidgets('三点菜单点击「重命名」触发 onRename', (tester) async {
    var renamed = false;
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.hot),
      onRename: () => renamed = true,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    expect(renamed, isTrue);
  });

  testWidgets('三点菜单点击「删除钱包」触发 onDelete', (tester) async {
    var deleted = false;
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.hot),
      onDelete: () => deleted = true,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除钱包'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('整卡 InkWell 点击触发 onTap', (tester) async {
    var tapped = false;
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.hot),
      onTap: () => tapped = true,
    );
    // 点钱包名所在区域(整卡 InkWell 范围内)。
    await tester.tap(find.text('我的钱包'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('showActions=false 时不显示三点菜单', (tester) async {
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.hot),
      showActions: false,
    );
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('默认冷账户卡在钱包名称右上侧显示纯文字', (tester) async {
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.cold),
      isDefault: true,
    );

    expect(find.text('默认'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
    final labelRect = tester.getRect(find.text('默认'));
    final nameRect = tester.getRect(find.text('我的钱包'));
    expect(labelRect.left, greaterThan(nameRect.right));
    expect(labelRect.center.dy, lessThan(nameRect.center.dy));
  });

  test('非法 signMode 与地址不一致的钱包都必须判为异常行', () {
    final invalidMode = makeWallet(signMode: null);
    final invalidAddress = makeWallet(signMode: SignMode.cold, walletIndex: 9);
    final validAccountId = '0x${10.toRadixString(16).padLeft(64, '0')}';
    final valid = WalletProfile(
      walletIndex: 10,
      walletName: '正常冷钱包',
      walletIcon: 'wallet',
      balance: 0,
      accountId: validAccountId,
      ss58Address: ss58FromAccountIdText(validAccountId),
      alg: 'sr25519',
      ss58: 2027,
      createdAtMillis: 0,
      source: 'test',
      signMode: SignMode.cold,
    );

    expect(isBrokenWalletProfile(invalidMode), isTrue);
    expect(isBrokenWalletProfile(invalidAddress), isTrue);
    expect(isBrokenWalletProfile(valid), isFalse);
  });

  testWidgets('身份损坏的钱包改显警示、不显余额', (tester) async {
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.cold),
      isBroken: true,
    );

    expect(
      find.text('钱包数据异常，请验证热钱包或重新导入冷钱包'),
      findsOneWidget,
    );
    // 读不到身份就对不上链，余额没有意义，不得展示误导。
    expect(find.text('1,234,567.89'), findsNothing);
  });

  testWidgets('正常钱包不显警示', (tester) async {
    await pumpTile(tester, wallet: makeWallet(signMode: SignMode.hot));

    expect(find.text('钱包数据异常，请删除后重新导入'), findsNothing);
    expect(find.text('1,234,567.89'), findsOneWidget);
  });

  testWidgets('损坏钱包仍可通过三点菜单删除（唯一出路不能被堵死）', (tester) async {
    var deleted = false;
    await pumpTile(
      tester,
      wallet: makeWallet(signMode: SignMode.cold),
      isBroken: true,
      onDelete: () => deleted = true,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除钱包'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}
