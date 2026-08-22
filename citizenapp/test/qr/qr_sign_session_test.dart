import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/qr/pages/qr_sign_session_page.dart';
import 'package:citizenapp/qr/qr_protocols.dart';
import 'package:citizenapp/signer/qr_signer.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';

class _FakeWalletManager extends WalletManager {
  int hotSignCalls = 0;

  @override
  Future<Uint8List> signForAccountId(
    String accountId,
    Uint8List payload,
  ) async {
    hotSignCalls += 1;
    return Uint8List.fromList([1, 2, 3]);
  }
}

void main() {
  group('WalletAccountSigner', () {
    const accountId =
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('Hot 只调用本机账户私钥签名', () async {
      final manager = _FakeWalletManager();
      final signature = await WalletAccountSigner(walletManager: manager).sign(
        context: null,
        accountId: accountId,
        signMode: SignMode.hot,
        payload: Uint8List.fromList([9]),
        action: QrActions.depositClearingBank,
        requestPrefix: 'test_',
      );

      expect(signature, [1, 2, 3]);
      expect(manager.hotSignCalls, 1);
    });

    testWidgets('Cold 只生成指定 action 的 CitizenWallet QR_V1 会话', (tester) async {
      final manager = _FakeWalletManager();
      Object? error;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              try {
                await WalletAccountSigner(walletManager: manager).sign(
                  context: context,
                  accountId: accountId,
                  signMode: SignMode.cold,
                  payload: Uint8List.fromList([9]),
                  action: QrActions.depositClearingBank,
                  requestPrefix: 'test_',
                );
              } catch (caught) {
                error = caught;
              }
            },
            child: const Text('sign'),
          ),
        ),
      ));

      await tester.tap(find.text('sign'));
      await tester.pumpAndSettle();
      final page = tester.widget<QrSignSessionPage>(
        find.byType(QrSignSessionPage),
      );
      expect(page.request.body.action, QrActions.depositClearingBank);
      expect(manager.hotSignCalls, 0);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(error, isA<WalletAuthException>());
    });

    test('缺失模式直接拒绝', () async {
      await expectLater(
        WalletAccountSigner(walletManager: _FakeWalletManager()).sign(
          context: null,
          accountId: accountId,
          signMode: null,
          payload: Uint8List.fromList([9]),
          action: QrActions.depositClearingBank,
          requestPrefix: 'test_',
        ),
        throwsA(isA<WalletAuthException>()),
      );
    });
  });

  group('QrSignSessionPage', () {
    late QrSigner signer;
    late SignRequestEnvelope request;
    late String requestJson;

    setUp(() {
      signer = QrSigner();
      request = signer.buildRequest(
        requestId: 'tx-test-12345678901234',
        signerPublicKey:
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        payloadHex: '0x01020304',
        action: QrActions.transferWithRemark,
      );
      requestJson = signer.encodeRequest(request);
    });

    testWidgets('should display countdown and QR code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QrSignSessionPage(
            request: request,
            requestJson: requestJson,
            expectedSignerPublicKey: request.body.signerPublicKeyHex,
          ),
        ),
      );

      expect(find.text('公民钱包签名'), findsOneWidget);
      expect(find.textContaining('签名请求有效期剩余'), findsOneWidget);
      expect(find.textContaining('请用离线设备扫描此二维码'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('扫描响应'), findsOneWidget);
    });

    testWidgets('cancel should pop with null', (tester) async {
      SignResponseEnvelope? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await Navigator.push<SignResponseEnvelope>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QrSignSessionPage(
                      request: request,
                      requestJson: requestJson,
                      expectedSignerPublicKey: request.body.signerPublicKeyHex,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('should show expired state when request expires',
        (tester) async {
      final expiredRequest = signer.buildRequest(
        requestId: 'tx-expired-12345678901',
        signerPublicKey:
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        payloadHex: '0x01020304',
        action: QrActions.transferWithRemark,
        nowEpochSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 200,
      );
      final expiredJson = signer.encodeRequest(expiredRequest);

      await tester.pumpWidget(
        MaterialApp(
          home: QrSignSessionPage(
            request: expiredRequest,
            requestJson: expiredJson,
            expectedSignerPublicKey: expiredRequest.body.signerPublicKeyHex,
          ),
        ),
      );

      expect(find.textContaining('签名请求已过期'), findsOneWidget);

      final scanButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '扫描响应'),
      );
      expect(scanButton.onPressed, isNull);
    });
  });
}
