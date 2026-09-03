import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/src/platform/citizen_sdk_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FacadePlatform platform;

  setUp(() {
    platform = _FacadePlatform();
    CitizenSdkPlatform.instance = platform;
  });

  tearDown(() async {
    CitizenSdkPlatform.instance = null;
    await platform.dispose();
  });

  test('根入口只装配最终公开 CitizenSdk、链、钱包、交易和公开模型', () async {
    final sdk = await CitizenSdk.open();

    expect(sdk.chain, isA<CitizenChain>());
    expect(sdk.wallet, isA<CitizenWallet>());
    expect(sdk.transactions, isA<CitizenTransactions>());
    expect(sdk.lifecycle, CitizenSdkLifecycle.created);

    await sdk.close();
    expect(sdk.lifecycle, CitizenSdkLifecycle.disposed);
    expect(platform.calls, <List<Object?>>[
      <Object?>[
        'open',
        <Object?>[1],
      ],
      <Object?>[
        'close',
        <Object?>[1, 'session-1', 1],
      ],
    ]);
  });
}

final class _FacadePlatform implements CitizenSdkPlatform {
  final StreamController<Object?> _events =
      StreamController<Object?>.broadcast();
  final List<List<Object?>> calls = <List<Object?>>[];

  @override
  Stream<Object?> get events => _events.stream;

  @override
  Future<Object?> invoke(String method, List<Object?> arguments) async {
    calls.add(<Object?>[method, arguments]);
    return switch (method) {
      'open' => <Object?>[
        1,
        'session-1',
        0,
        <Object?>['created', 1],
      ],
      'close' => <Object?>[
        1,
        'session-1',
        1,
        <Object?>['disposed'],
      ],
      _ => throw StateError('未预期 method：$method'),
    };
  }

  Future<void> dispose() => _events.close();
}
