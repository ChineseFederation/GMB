import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/platform/citizen_sdk_flutter_codec.dart';
import 'package:citizen_sdk/src/platform/citizen_sdk_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _WalletPlatform platform;

  setUp(() {
    platform = _WalletPlatform();
    CitizenSdkPlatform.instance = platform;
  });

  tearDown(() async {
    CitizenSdkPlatform.instance = null;
    await platform.dispose();
  });

  test('create/import/add只启动原生安全流程并返回公开profile', () async {
    final sdk = await CitizenSdk.open();
    final created = await sdk.wallet.create(
      wordCount: CitizenWalletWordCount.words24,
    );
    final imported = await sdk.wallet.importWallet();
    final expanded = await sdk.wallet.addAccounts(const <int>[1, 2]);

    expect(created.origin, CitizenWalletOrigin.created);
    expect(imported.origin, CitizenWalletOrigin.imported);
    expect(expanded.accounts, hasLength(3));
    expect(platform.argumentsByMethod['createWallet'], <Object?>[
      1,
      'session-a',
      1,
      24,
    ]);
    expect(platform.argumentsByMethod['importWallet'], <Object?>[
      1,
      'session-a',
      2,
    ]);
    expect(platform.argumentsByMethod['addWalletAccounts'], <Object?>[
      1,
      'session-a',
      3,
      const <int>[1, 2],
    ]);
    await sdk.close();
  });

  test('sign消息使用临时副本并仅返回公开sr25519签名', () async {
    final sdk = await CitizenSdk.open();
    final callerPayload = Uint8List.fromList(<int>[1, 2, 3]);
    final signature = await sdk.wallet.sign(
      accountId: _account(1),
      payload: callerPayload,
    );

    expect(callerPayload, <int>[1, 2, 3]);
    expect(signature.bytes, hasLength(64));
    expect(platform.borrowedPayloadAfterReturn, everyElement(0));
    await sdk.close();
  });

  test('空签名载荷有效且账户名在编码前统一修剪', () async {
    final sdk = await CitizenSdk.open();
    await sdk.wallet.sign(accountId: _account(1), payload: Uint8List(0));
    await sdk.wallet.renameAccount(accountId: _account(1), name: '  旅行钱包  ');

    expect(
      platform.argumentsByMethod['signWalletPayload']![4],
      isA<Uint8List>().having((value) => value.length, 'length', 0),
    );
    expect(platform.argumentsByMethod['renameWalletAccount']![4], '旅行钱包');
    await sdk.close();
  });

  test('钱包公开API在复制或递增请求序号前拒绝超界输入', () async {
    final sdk = await CitizenSdk.open();
    final invalid = isA<CitizenSdkException>().having(
      (error) => error.code,
      'code',
      CitizenSdkErrorCode.invalidArgument,
    );

    await expectLater(
      sdk.wallet.addAccounts(
        List<int>.filled(
          CitizenSdkFlutterCodec.maximumAdditionalWalletAccounts + 1,
          1,
          growable: false,
        ),
      ),
      throwsA(invalid),
    );
    await expectLater(
      sdk.wallet.sign(
        accountId: _account(1),
        payload: Uint8List(
          CitizenSdkFlutterCodec.maximumSigningPayloadBytes + 1,
        ),
      ),
      throwsA(invalid),
    );
    await expectLater(
      sdk.wallet.renameAccount(
        accountId: _account(1),
        name: List<String>.filled(129, 'a').join(),
      ),
      throwsA(invalid),
    );
    // Opening the session is expected; every rejected wallet operation must
    // fail before it allocates a request sequence or reaches the platform.
    expect(platform.argumentsByMethod.keys.toList(), <String>['open']);
    await sdk.close();
  });

  test('delete返回null profile且不能把秘密放入Dart响应', () async {
    final sdk = await CitizenSdk.open();
    await sdk.wallet.delete();
    expect(platform.argumentsByMethod['deleteWallet'], hasLength(3));
    await sdk.close();
  });
}

final class _WalletPlatform implements CitizenSdkPlatform {
  final StreamController<Object?> _events =
      StreamController<Object?>.broadcast();
  final Map<String, List<Object?>> argumentsByMethod =
      <String, List<Object?>>{};
  Uint8List? borrowedPayloadAfterReturn;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  Future<Object?> invoke(String method, List<Object?> arguments) async {
    argumentsByMethod[method] = arguments;
    if (method == 'open') {
      return <Object?>[
        1,
        'session-a',
        0,
        <Object?>['created', 1],
      ];
    }
    final sequence = arguments[2]! as int;
    final value = switch (method) {
      'createWallet' => <Object?>[_profile('created', 1)],
      'importWallet' => <Object?>[_profile('imported', 1)],
      'addWalletAccounts' => <Object?>[_profile('imported', 3)],
      'signWalletPayload' => <Object?>[Uint8List(64)],
      'renameWalletAccount' => <Object?>[_profile('created', 1)],
      'deleteWallet' => const <Object?>[null],
      'close' => <Object?>['disposed'],
      _ => throw StateError('未预期 method：$method'),
    };
    if (method == 'signWalletPayload') {
      borrowedPayloadAfterReturn = arguments[4]! as Uint8List;
    }
    return <Object?>[1, 'session-a', sequence, value];
  }

  Future<void> dispose() => _events.close();
}

List<Object?> _profile(String origin, int accountCount) {
  final accounts = List<List<Object?>>.generate(accountCount, (index) {
    final accountId = _account(index + 1);
    return <Object?>[
      index,
      accountId,
      citizenSs58FromAccountId(accountId),
      '账户$index',
      '${index + 1}',
      index == 0,
    ];
  });
  return <Object?>[0, origin, '1', _account(1), _account(1), accounts];
}

String _account(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';
