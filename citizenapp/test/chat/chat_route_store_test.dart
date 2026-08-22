import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/chat/storage/chat_store.dart';
import 'package:citizenapp/security/local_data_key.dart';

import '../support/isar_test_env.dart';

const _ownerCidNumber = 'CN220-CTZN2-100000001-2026';
const _peerCidNumber = 'CN220-CTZN2-100000002-2026';
const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _binding = AccountDataBinding(
  genesisHash:
      '0x4242424242424242424242424242424242424242424242424242424242424242',
  cidNumber: _ownerCidNumber,
  bindingRevision: 1,
  accountId: _accountId,
);

void main() {
  useIsolatedIsar();

  test('Chat route cache creates, reads, and replaces route records', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_binding);

    await store.upsertRouteRecord(
      _ownerCidNumber,
      const ChatRoute(
        peerCidNumber: _peerCidNumber,
        routeDisplayName: 'Bob',
        deviceId: 'bob-phone',
        devicePublicKey: '0a0b',
        safetyNumber: '12 34',
        nearbyPeerHint: 'bob-nearby',
        note: 'first',
      ),
      bindingToken: bindingToken,
    );

    final created = await store.getRouteRecord(_ownerCidNumber, _peerCidNumber);
    expect(created, isNotNull);
    expect(created!.routeDisplayName, 'Bob');
    expect(created.nearbyPeerHint, 'bob-nearby');

    await store.upsertRouteRecord(
      _ownerCidNumber,
      ChatRoute(
        peerCidNumber: _peerCidNumber,
        routeDisplayName: 'Bob New',
        deviceId: created.deviceId,
        devicePublicKey: created.devicePublicKey,
        safetyNumber: created.safetyNumber,
        nearbyPeerHint: created.nearbyPeerHint,
        createdAtMillis: created.createdAtMillis,
      ),
      bindingToken: bindingToken,
    );

    final routes = await store.readRouteRecords(_ownerCidNumber);
    expect(routes, hasLength(1));
    expect(routes.single.routeDisplayName, 'Bob New');
    expect(routes.single.createdAtMillis, created.createdAtMillis);
    expect(
      routes.single.updatedAtMillis,
      greaterThanOrEqualTo(created.updatedAtMillis ?? 0),
    );
  });
}
