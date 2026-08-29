import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('未启动实例可幂等销毁且销毁后 fail-closed', () async {
    final client = CitizenLightClient();
    await client.dispose();
    await client.dispose();
    expect(client.health.status, ChainHealthStatus.disposed);
    expect(() => client.ensureStarted(), throwsStateError);
  });

  test('初始状态不伪装为可用', () {
    final client = CitizenLightClient();
    expect(client.isReady, isFalse);
    expect(client.health.isUsable, isFalse);
    expect(client.health.status, ChainHealthStatus.uninitialized);
  });
}
