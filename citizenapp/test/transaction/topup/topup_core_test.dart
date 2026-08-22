import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizenapp/transaction/onchain-topup/topup_api.dart';
import 'package:citizenapp/transaction/onchain-topup/topup_erc20.dart';
import 'package:citizenapp/transaction/onchain-topup/topup_models.dart';
import 'package:citizenapp/transaction/onchain-topup/wallet_link_dispatcher.dart';

void main() {
  group('WalletConnect WebView CSP', () {
    final html = File('assets/topup/walletconnect.html').readAsStringSync();

    test('只给钱包图片开放 blob 并固定 Reown 字体域名', () {
      expect(html, contains("img-src 'self' data: blob: https:;"));
      expect(html, contains('font-src https://fonts.reown.com;'));
    });

    test('不向脚本或框架开放 blob，正式官网元数据保持不变', () {
      expect(html, contains("script-src 'self' 'unsafe-inline';"));
      expect(html, isNot(contains('script-src blob:')));
      expect(html, isNot(contains('frame-src blob:')));
      expect(html, contains("url: 'https://www.crcfrcn.com'"));
    });

    test('Reown 新窗口统一交给 bridge，且 metadata 声明双端回跳', () {
      expect(html, contains("window.open = (url, target, features) =>"));
      expect(html, contains("kind: 'external_wallet'"));
      expect(
        html,
        contains("redirect: { native: 'citizenapp://walletconnect' }"),
      );
      // 不配置 includeWalletIds，保持 WalletGuide 全部兼容钱包可见。
      expect(html, isNot(contains('includeWalletIds')));
    });
  });

  group('WalletLinkDispatcher', () {
    test('普通 HTTPS 导航留在 WebView，Reown 钱包打开事件外部化', () {
      final navigation = WalletLinkDispatcher.classify(
        'https://wallet.example/connect',
        source: WalletLinkSource.webViewNavigation,
      );
      final walletOpen = WalletLinkDispatcher.classify(
        'https://wallet.example/connect',
        source: WalletLinkSource.walletOpenBridge,
      );
      expect(navigation.disposition, WalletLinkDisposition.stayInWebView);
      expect(walletOpen.disposition, WalletLinkDisposition.openExternalWallet);
    });

    test('WalletGuide 自定义 scheme 不按钱包品牌裁剪', () {
      final decision = WalletLinkDispatcher.classify(
        'future-wallet://wc?uri=redacted',
        source: WalletLinkSource.webViewNavigation,
      );
      expect(decision.disposition, WalletLinkDisposition.openExternalWallet);
    });

    test('危险协议拒绝，WebView 内部资源不交给系统', () {
      for (final url in const [
        'javascript:alert(1)',
        'data:text/plain,secret',
        'tel:10086',
        'mailto:test@example.com',
      ]) {
        final decision = WalletLinkDispatcher.classify(
          url,
          source: WalletLinkSource.walletOpenBridge,
        );
        expect(decision.disposition, WalletLinkDisposition.blocked);
      }
      final asset = WalletLinkDispatcher.classify(
        'file:///walletconnect.html',
        source: WalletLinkSource.webViewNavigation,
      );
      expect(asset.disposition, WalletLinkDisposition.stayInWebView);
    });

    test('系统打开成功、返回 false 和抛异常均转换为固定结果', () async {
      final opened = WalletLinkDispatcher(launcher: (_) async => true);
      final failed = WalletLinkDispatcher(launcher: (_) async => false);
      final crashed = WalletLinkDispatcher(
        launcher: (_) async {
          throw Exception('platform failure');
        },
      );

      expect(
        await opened.open(
          'wc:topic@2?relay-protocol=irn&symKey=redacted',
          source: WalletLinkSource.webViewNavigation,
        ),
        WalletLinkOpenResult.opened,
      );
      expect(
        await failed.open(
          'another-wallet://wc',
          source: WalletLinkSource.walletOpenBridge,
        ),
        WalletLinkOpenResult.failed,
      );
      expect(
        await crashed.open(
          'https://wallet.example/connect',
          source: WalletLinkSource.walletOpenBridge,
        ),
        WalletLinkOpenResult.failed,
      );
    });

    test('钱包专属链接失效时回退标准 wc URI，不维护品牌兼容表', () async {
      final attempts = <Uri>[];
      final dispatcher = WalletLinkDispatcher(launcher: (uri) async {
        attempts.add(uri);
        return uri.scheme == 'wc';
      });

      final result = await dispatcher.open(
        'legacy-wallet://main/wc?uri='
        'wc%3Atopic%402%3Frelay-protocol%3Dirn%26symKey%3Dredacted',
        source: WalletLinkSource.walletOpenBridge,
      );

      expect(result, WalletLinkOpenResult.opened);
      expect(attempts.map((uri) => uri.scheme), ['legacy-wallet', 'wc']);
    });
  });

  group('WalletConnect 双端回跳配置', () {
    test('iOS 与 Android 都注册 citizenapp://walletconnect', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      final androidManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(infoPlist, contains('<string>citizenapp</string>'));
      expect(infoPlist, contains('citizenapp.walletconnect'));
      expect(androidManifest, contains('android:scheme="citizenapp"'));
      expect(androidManifest, contains('android:host="walletconnect"'));
    });
  });

  group('iOS 静态 XCFramework 构建配置', () {
    test('Isar 输出清单按真实 libisar.a 建立 Xcode 依赖', () {
      final podfile = File('ios/Podfile').readAsStringSync();
      expect(
        podfile,
        contains(
          r'${PODS_XCFRAMEWORKS_BUILD_DIR}/'
          r'isar_community_flutter_libs/libisar.a',
        ),
      );
      expect(
        podfile,
        contains(
          "'isar_community_flutter_libs-xcframeworks-output-files.xcfilelist'",
        ),
      );
    });
  });

  group('encodeErc20Transfer', () {
    test('按 selector + 32B 地址 + 32B 金额编码', () {
      final data = encodeErc20Transfer('0x${'ab' * 20}', BigInt.from(15000000));
      final expected = '0xa9059cbb'
          '${'0' * 24}${'ab' * 20}'
          '${'0' * 58}e4e1c0';
      expect(data, expected);
      expect(data.length, 2 + 8 + 64 + 64);
    });

    test('非法地址抛错', () {
      expect(
        () => encodeErc20Transfer('0x1234', BigInt.one),
        throwsArgumentError,
      );
    });

    test('负数金额抛错', () {
      expect(
        () => encodeErc20Transfer('0x${'ab' * 20}', BigInt.from(-1)),
        throwsArgumentError,
      );
    });
  });

  group('TopupConfig 解析', () {
    test('解析币轨与套餐', () {
      final config = TopupConfig.fromJson({
        'network': 'production',
        'recv_address': '0x${'cd' * 20}',
        'rails': [
          {
            'token': 'USDC',
            'chain_id': 8453,
            'token_contract': '0x${'11' * 20}',
            'token_decimals': 6,
            'label': 'USDC · Base',
          },
        ],
        'packages': [
          {
            'package_id': 'pkg_15',
            'pay_display': '15',
            'pay_amount': '15000000',
            'coin_display': '10,000.00',
            'coin_fen': '1000000',
          },
        ],
      });
      expect(config.rails.single.chainId, 8453);
      expect(config.rails.single.caip2, 'eip155:8453');
      expect(config.packages.single.payAmountValue, BigInt.from(15000000));
    });
  });

  group('TopupApi', () {
    const accountId =
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    // 充值已与广场会话解耦:客户端不再持有 / 传递任何 session。
    TopupApi apiWith(MockClient client) =>
        TopupApi(baseUrl: 'https://x.test/api', httpClient: client);

    test('fetchConfig 走 /square/topup/config', () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.url.path, '/api/square/topup/config');
          return http.Response(
            jsonEncode({
              'ok': true,
              'network': 'testnet',
              'recv_address': '0x${'cd' * 20}',
              'rails': [],
              'packages': [],
            }),
            200,
          );
        }),
      );
      final config = await api.fetchConfig();
      expect(config.network, 'testnet');
    });

    test('createIntent 上传充值目标 account_id 且不带任何会话头', () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/square/topup/intent');
          expect(request.headers.containsKey('authorization'), isFalse);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['account_id'], accountId);
          return http.Response(
            jsonEncode({
              'ok': true,
              'payment_intent': 'signed-intent',
              'expires_at': 123,
            }),
            200,
          );
        }),
      );
      final result = await api.createIntent(
        token: 'USDC',
        packageId: 'pkg_15',
        accountId: accountId,
        payerAddress: '0x${'22' * 20}',
      );
      expect(result.token, 'signed-intent');
    });

    test('confirm 未确认 → confirming，且不带会话头', () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(
            jsonEncode({'ok': true, 'status': 'confirming'}),
            200,
          );
        }),
      );
      final result = await api.confirm(
        paymentIntent: 'signed-intent',
        evmTxHash: '0x${'22' * 32}',
      );
      expect(result.status, TopupOrderStatus.confirming);
    });

    test('status 走 POST，凭付款意图查单，订单号不入 URL', () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/square/topup/status');
          expect(request.headers.containsKey('authorization'), isFalse);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['order_id'], 'top_123');
          expect(body['payment_intent'], 'signed-intent');
          return http.Response(jsonEncode({'ok': true, 'status': 'paid'}), 200);
        }),
      );
      final status = await api.status(
        orderId: 'top_123',
        paymentIntent: 'signed-intent',
      );
      expect(status, TopupOrderStatus.paid);
    });

    test('非 2xx 抛 TopupApiException 带 error_code', () async {
      final api = apiWith(
        MockClient(
          (request) async => http.Response(
            jsonEncode({
              'ok': false,
              'error_code': 'topup_payment_invalid',
              'message': '未确认到有效到账',
            }),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      expect(
        () => api.confirm(
          paymentIntent: 'signed-intent',
          evmTxHash: '0x${'11' * 32}',
        ),
        throwsA(
          isA<TopupApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'topup_payment_invalid',
          ),
        ),
      );
    });
  });
}
