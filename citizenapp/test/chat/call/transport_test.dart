import 'package:chat_sdk/call.dart';
import 'package:citizenapp/chat/call/transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CitizenCallTransport 只映射 CID 和既有扁平信令', () async {
    String? recipient;
    Map<String, Object?>? wire;
    final transport = CitizenCallTransport(
      readStunUrls: () async => const ['stun:stun.example.com'],
      sendRawSignal: (value, signal) async {
        recipient = value;
        wire = signal;
        return true;
      },
    );
    expect((await transport.readIceConfiguration()).stunUrls, hasLength(1));
    await transport.sendSignal(
      recipientUserId: 'CN220-CTZN2-100000002-2026',
      signal: CallSignal.control(
        kind: CallSignalKind.hangup,
        connectionId: 'rtc.123.abc',
      ),
    );
    expect(recipient, 'CN220-CTZN2-100000002-2026');
    expect(wire, <String, Object?>{
      'signal_kind': 'hangup',
      'connection_id': 'rtc.123.abc',
    });
  });
}
