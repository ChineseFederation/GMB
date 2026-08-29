import 'package:citizen_sdk/src/smoldot/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> snapshot(String phase) => <String, dynamic>{
    'peerCount': 3,
    'isSyncing': phase != 'regular',
    'isUsable': phase == 'regular',
    'syncPhase': phase,
    'currentVerifiedFinalizedBlockNumber': phase == 'regular' ? 10 : 0,
    'currentVerifiedFinalizedBlockHash':
        '0x${List<String>.filled(32, '00').join()}',
    if (phase != 'regular') 'warpTargetFinalizedBlockNumber': 10,
    if (phase != 'regular')
      'warpTargetFinalizedBlockHash':
          '0x${List<String>.filled(32, '11').join()}',
    'warpRequestCount': 1,
    'activeWarpFragmentRequestCount': 0,
    'activeWarpStorageRequestCount': 0,
    'activeWarpCallProofRequestCount': 0,
    'warpReceivedFragmentCount': 1,
    'warpVerifiedFragmentCount': 1,
    'warpRejectedFragmentCount': 0,
  };

  test('regular 才能映射为可用链状态', () {
    final regular = LightClientStatusSnapshot.fromJson(snapshot('regular'));
    expect(regular.isUsable, isTrue);
    expect(regular.chainStatus, ChainStatus.synced);
    final warp = LightClientStatusSnapshot.fromJson(
      snapshot('warpBuildingRuntime'),
    );
    expect(warp.isUsable, isFalse);
    expect(warp.chainStatus, ChainStatus.syncing);
  });

  test('未知同步阶段必须拒绝', () {
    expect(
      () => LightClientStatusSnapshot.fromJson(snapshot('unknown')),
      throwsFormatException,
    );
  });
}
