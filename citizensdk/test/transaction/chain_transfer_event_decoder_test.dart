import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/transaction/chain_rpc.dart';
import 'package:citizen_sdk/src/transaction/chain_transfer_event_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/polkadart.dart' show RuntimeMetadata, RuntimeVersion;

void main() {
  const decoder = ChainTransferEventDecoder();
  final from = Uint8List.fromList(List<int>.filled(32, 1));
  final to = Uint8List.fromList(List<int>.filled(32, 2));
  final fromAccountId = citizenAccountIdFromBytes(from);
  final toAccountId = citizenAccountIdFromBytes(to);

  test('同 extrinsic 的业务转账与 Balances 事件一对一合并并保留备注', () {
    final decoded = decoder.decodeRecords(
      records: <DecodedChainEventRecord>[
        DecodedChainEventRecord(
          eventRecordIndex: 0,
          phase: const <String, dynamic>{'ApplyExtrinsic': 7},
          event: <String, dynamic>{
            'Balances': <String, dynamic>{
              'Transfer': <String, dynamic>{
                'from': from,
                'to': to,
                'amount': BigInt.from(123),
              },
            },
          },
        ),
        DecodedChainEventRecord(
          eventRecordIndex: 1,
          phase: const <String, dynamic>{'applyExtrinsic': '7'},
          event: <String, dynamic>{
            'OnchainTransaction': <String, dynamic>{
              'TransferWithRemark': <Object?>[
                from,
                to,
                BigInt.from(123),
                Uint8List.fromList('fixture'.codeUnits),
              ],
            },
          },
        ),
      ],
      blockNumber: 9,
      blockHash: _hash(9),
    );

    expect(decoded, hasLength(1));
    expect(decoded.single.sourcePallet, 'OnchainTransaction');
    expect(decoded.single.eventRecordIndex, 1);
    expect(decoded.single.extrinsicIndex, 7);
    expect(decoded.single.fromAccountId, fromAccountId);
    expect(decoded.single.toAccountId, toAccountId);
    expect(decoded.single.amountFen, BigInt.from(123));
    expect(decoded.single.remark, 'fixture');
  });

  test('缺少 extrinsic phase 的同额事件不做武断合并', () {
    final records = <DecodedChainEventRecord>[
      for (var index = 0; index < 2; index++)
        DecodedChainEventRecord(
          eventRecordIndex: index,
          phase: const <String, dynamic>{'Finalization': null},
          event: <String, dynamic>{
            'Balances': <String, dynamic>{
              'Transfer': <Object?>[from, to, 10],
            },
          },
        ),
    ];

    final decoded = decoder.decodeRecords(
      records: records,
      blockNumber: 10,
      blockHash: _hash(10),
    );

    expect(decoded, hasLength(2));
    expect(decoded.map((entry) => entry.eventRecordIndex), <int>[0, 1]);
  });

  test('生产 metadata 字段、SS58 与 hex remark 都按官方身份归一化', () {
    final decoded = decoder.decodeRecords(
      records: <DecodedChainEventRecord>[
        DecodedChainEventRecord(
          eventRecordIndex: 3,
          phase: <String, dynamic>{'ApplyExtrinsic': BigInt.one},
          event: <String, dynamic>{
            'onchainTransaction': <String, dynamic>{
              'transfer_with_remark': <String, Object?>{
                'from_account_id': citizenSs58FromAccountId(fromAccountId),
                'beneficiary_account_id': citizenSs58FromAccountId(toAccountId),
                'amount': '42',
                'remark': '0xe4b8ade58d8e',
              },
            },
          },
        ),
      ],
      blockNumber: 11,
      blockHash: _hash(11),
    );

    expect(decoded.single.fromAccountId, fromAccountId);
    expect(decoded.single.toAccountId, toAccountId);
    expect(decoded.single.amountFen, BigInt.from(42));
    expect(decoded.single.remark, '中华');
  });

  test('自转、零金额和畸形账户被拒绝', () {
    final decoded = decoder.decodeRecords(
      records: <DecodedChainEventRecord>[
        DecodedChainEventRecord(
          eventRecordIndex: 0,
          phase: const <String, dynamic>{'ApplyExtrinsic': 0},
          event: <String, dynamic>{
            'Balances': <String, dynamic>{
              'Transfer': <Object?>[from, from, 1],
            },
          },
        ),
        DecodedChainEventRecord(
          eventRecordIndex: 1,
          phase: const <String, dynamic>{'ApplyExtrinsic': 1},
          event: <String, dynamic>{
            'Balances': <String, dynamic>{
              'Transfer': <Object?>[from, to, 0],
            },
          },
        ),
        const DecodedChainEventRecord(
          eventRecordIndex: 2,
          phase: <String, dynamic>{'ApplyExtrinsic': 2},
          event: <String, dynamic>{
            'Balances': <String, dynamic>{
              'Transfer': <Object?>['bad', 'also-bad', 10],
            },
          },
        ),
      ],
      blockNumber: 12,
      blockHash: _hash(12),
    );

    expect(decoded, isEmpty);
  });

  test('正式 SCALE 入口使用同块 runtime context，System-only 夹具不伪造转账', () {
    final metadata = RuntimeMetadata.fromHex(
      File(
        'test/transaction/fixtures/substrate-v14-system-events-metadata.hex',
      ).readAsStringSync().trim(),
    );
    final blockHash = _hash(13);
    final context = ChainRuntimeContext(
      blockHash: blockHash,
      runtimeVersion: RuntimeVersion.fromJson(_runtimeVersionJson()),
      metadata: metadata,
    );
    final events = Uint8List.fromList(<int>[0x04, ..._successEvent(0)]);

    expect(
      decoder.decode(
        eventsBytes: events,
        runtimeContext: context,
        blockNumber: 13,
        blockHash: blockHash,
      ),
      isEmpty,
    );
    expect(
      () => decoder.decode(
        eventsBytes: events,
        runtimeContext: context,
        blockNumber: 13,
        blockHash: _hash(14),
      ),
      throwsStateError,
    );
  });

  test('生产 CitizenChain v14 metadata 与 System.Events 解码真实双事件并一对一合并', () {
    final metadataHex = File(
      'test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex',
    ).readAsStringSync().trim();
    final eventsBytes = _fixtureHexBytes(
      'test/transaction/fixtures/citizenchain-runtime-system-events.hex',
    );
    final blockHash = _hash(15);
    final context = ChainRuntimeContext(
      blockHash: blockHash,
      runtimeVersion: RuntimeVersion.fromJson(_runtimeVersionJson()),
      metadata: RuntimeMetadata.fromHex(metadataHex),
    );

    final decoded = decoder.decode(
      eventsBytes: eventsBytes,
      runtimeContext: context,
      blockNumber: 15,
      blockHash: blockHash,
    );

    expect(decoded, hasLength(1));
    expect(decoded.single.sourcePallet, 'OnchainTransaction');
    expect(decoded.single.eventRecordIndex, 1);
    expect(decoded.single.extrinsicIndex, 0);
    expect(decoded.single.fromAccountId, _hash(0x11));
    expect(decoded.single.toAccountId, _hash(0x22));
    expect(decoded.single.amountFen, BigInt.from(123456));
    expect(decoded.single.remark, 'CitizenSDK production Runtime fixture');
  });
}

Uint8List _fixtureHexBytes(String path) {
  final value = File(path).readAsStringSync().trim();
  final body = value.startsWith('0x') ? value.substring(2) : value;
  if (body.isEmpty ||
      body.length.isOdd ||
      !RegExp(r'^[0-9a-f]+$').hasMatch(body)) {
    throw FormatException('夹具不是规范小写 hex：$path');
  }
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < body.length; offset += 2)
      int.parse(body.substring(offset, offset + 2), radix: 16),
  ]);
}

List<int> _successEvent(int extrinsicIndex) => <int>[
  0x00,
  ..._u32(extrinsicIndex),
  0x00,
  0x00,
  ...List<int>.filled(10, 0),
  0x00,
];

List<int> _u32(int value) => <int>[
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

String _hash(int byte) =>
    '0x${List<String>.filled(32, byte.toRadixString(16).padLeft(2, '0')).join()}';

Map<String, dynamic> _runtimeVersionJson() => <String, dynamic>{
  'specName': 'citizen',
  'implName': 'citizen',
  'authoringVersion': 1,
  'specVersion': 1,
  'implVersion': 1,
  'apis': <Object?>[],
  'transactionVersion': 1,
  'stateVersion': 1,
};
