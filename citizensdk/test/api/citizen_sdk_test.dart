import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/src/platform/citizen_sdk_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _SdkPlatform platform;

  setUp(() {
    platform = _SdkPlatform();
    CitizenSdkPlatform.instance = platform;
  });

  tearDown(() async {
    CitizenSdkPlatform.instance = null;
    await platform.dispose();
  });

  test('CitizenSdk按open-start-capabilities-stop-close顺序投影Core', () async {
    final sdk = await CitizenSdk.open();
    await sdk.start();
    final capabilities = await sdk.getCapabilities();
    await sdk.stop();
    await sdk.close();

    expect(capabilities.statuses, hasLength(10));
    expect(capabilities[CitizenCapabilityName.chainRead].ready, isTrue);
    expect(sdk.lifecycle, CitizenSdkLifecycle.disposed);
    expect(platform.methods, <String>[
      'open',
      'start',
      'getCapabilities',
      'stop',
      'close',
    ]);
    expect(platform.sequences, <int>[1, 2, 3, 4]);
  });

  test('事件只接收当前session且event sequence独立连续', () async {
    final sdk = await CitizenSdk.open();
    final events = <CitizenSdkEvent>[];
    final subscription = sdk.events.listen(events.add);

    platform.emit(<Object?>[
      1,
      'another-session',
      1,
      'lifecycleChanged',
      <Object?>['running'],
    ]);
    platform.emit(<Object?>[
      1,
      'session-a',
      1,
      'lifecycleChanged',
      <Object?>['running'],
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(sdk.lifecycle, CitizenSdkLifecycle.running);
    await subscription.cancel();
    await sdk.close();
  });

  test('余额与nonce响应必须精确绑定请求账户', () async {
    platform.wrongAccountResponses = true;
    final sdk = await CitizenSdk.open();

    await expectLater(
      sdk.chain.getAccountBalance(_account(1)),
      throwsA(isA<CitizenSdkException>()),
    );
    await expectLater(
      sdk.chain.getAccountNonce(_account(1)),
      throwsA(isA<CitizenSdkException>()),
    );
    await sdk.close();
  });
}

final class _SdkPlatform implements CitizenSdkPlatform {
  final StreamController<Object?> _events =
      StreamController<Object?>.broadcast();
  final List<String> methods = <String>[];
  final List<int> sequences = <int>[];
  bool wrongAccountResponses = false;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  Future<Object?> invoke(String method, List<Object?> arguments) async {
    methods.add(method);
    if (method == 'open') {
      return <Object?>[
        1,
        'session-a',
        0,
        <Object?>['created', 1],
      ];
    }
    final sequence = arguments[2]! as int;
    sequences.add(sequence);
    final value = switch (method) {
      'start' => <Object?>['running'],
      'stop' => <Object?>['stopped'],
      'close' => <Object?>['disposed'],
      'getCapabilities' => <Object?>[_capabilitySnapshot()],
      'getAccountBalance' => <Object?>[
        <Object?>[
          _account(wrongAccountResponses ? 2 : 1),
          _block(9, 'finalized'),
          '1',
          '0',
          '1',
        ],
      ],
      'getAccountNonce' => <Object?>[
        <Object?>[
          _account(wrongAccountResponses ? 2 : 1),
          _block(9, 'best'),
          '1',
        ],
      ],
      _ => throw StateError('未预期 method：$method'),
    };
    return <Object?>[1, 'session-a', sequence, value];
  }

  void emit(Object? event) => _events.add(event);

  Future<void> dispose() => _events.close();
}

List<Object?> _capabilitySnapshot() => <Object?>[
  '1',
  CitizenCapabilityName.values
      .map<List<Object?>>(
        (name) => <Object?>[name.name, true, true, true, true, 'none'],
      )
      .toList(growable: false),
];

String _account(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';

List<Object?> _block(int number, String finality) => <Object?>[
  _account(number),
  '$number',
  finality,
];
