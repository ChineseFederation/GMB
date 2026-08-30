import 'package:chat_sdk/call.dart';

import '../chat_runtime.dart';

typedef CitizenStunReader = Future<List<String>> Function();
typedef CitizenSignalSender = Future<bool> Function(
  String recipientCidNumber,
  Map<String, Object?> signal,
);

/// 把 CitizenApp 的 CID/WSS 合同适配为部署无关的 ChatSDK 通话传输。
class CitizenCallTransport implements CallTransport {
  const CitizenCallTransport({
    required CitizenStunReader readStunUrls,
    required CitizenSignalSender sendRawSignal,
  })  : _readStunUrls = readStunUrls,
        _sendRawSignal = sendRawSignal;

  factory CitizenCallTransport.fromRuntime(ChatRuntime runtime) =>
      CitizenCallTransport(
        readStunUrls: runtime.readCallStunUrls,
        sendRawSignal: (recipientCidNumber, signal) => runtime.sendCallSignal(
          recipientCidNumber: recipientCidNumber,
          signal: signal,
        ),
      );

  final CitizenStunReader _readStunUrls;
  final CitizenSignalSender _sendRawSignal;

  @override
  Future<CallIceConfiguration> readIceConfiguration() async =>
      CallIceConfiguration(await _readStunUrls());

  @override
  Future<bool> sendSignal({
    required String recipientUserId,
    required CallSignal signal,
  }) =>
      _sendRawSignal(recipientUserId, signal.toWire());
}
