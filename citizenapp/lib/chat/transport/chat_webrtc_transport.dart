import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../crypto/mls_boundary.dart';
import 'chat_cloud_transport.dart';

/// 对端通过直连请求首次会话 KeyPackage 时，运行态在本机 OpenMLS 中即时生成。
typedef ChatDirectKeyPackageProvider = Future<MlsKeyPackage> Function();

/// WebRTC 只能把扁平 KeyPackage 信令交给账户级 WSS；不得自行建立第二条 socket。
typedef ChatSignalSender = Future<bool> Function({
  required String recipientCidNumber,
  required Map<String, Object?> signal,
});

/// 把 WebRTC 控制连接中的密钥动作纳入当前 binding 的持久 CID 临界区。
typedef ChatWebrtcMutationRunner = Future<T> Function<T>(
  Future<T> Function() operation,
);

/// WebRTC 控制 DataChannel 的严格帧编解码边界。
///
/// 控制帧只允许按需 KeyPackage 交换。文本、表情、贴纸、附件和 MLS
/// Envelope 全部使用 CitizenServe 有界密文存转，禁止进入 DataChannel。
class ChatWebrtcControlFrame {
  const ChatWebrtcControlFrame._();

  static Map<String, dynamic> keyPackageRequest(String requestId) =>
      <String, dynamic>{
        'kind': 'key_package_request',
        'request_id': requestId,
      };

  static Map<String, dynamic> keyPackageResponse(
    String requestId,
    MlsKeyPackage keyPackage,
  ) =>
      <String, dynamic>{
        'kind': 'key_package_response',
        'request_id': requestId,
        'key_package': _keyPackageToJson(keyPackage),
      };

  static Map<String, dynamic> decode(String text) {
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Chat 控制帧必须是对象');
    }
    switch (value['kind']) {
      case 'key_package_request':
        _requireExactFrameKeys(value, const ['kind', 'request_id']);
        _requireControlToken(value['request_id'], 'request_id');
      case 'key_package_response':
        _requireExactFrameKeys(
          value,
          const ['kind', 'request_id', 'key_package'],
        );
        _requireControlToken(value['request_id'], 'request_id');
        keyPackage(value);
      default:
        throw const FormatException('Chat 控制帧类型不合法');
    }
    return value;
  }

  static MlsKeyPackage keyPackage(Map<String, dynamic> frame) {
    final value = frame['key_package'];
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Chat KeyPackage 帧格式不合法');
    }
    _requireExactFrameKeys(value, const [
      'cid_number',
      'device_id',
      'device_public_key_hex',
      'key_package_id',
      'key_package',
      'cipher_suite',
      'not_before',
      'not_after',
      'last_resort',
    ]);
    for (final field in const [
      'cid_number',
      'device_id',
      'device_public_key_hex',
      'key_package_id',
      'cipher_suite',
    ]) {
      _requireControlToken(value[field], field, maxLength: 512);
    }
    final encoded = value['key_package'];
    if (encoded is! String || encoded.isEmpty) {
      throw const FormatException('Chat KeyPackage 字节缺失');
    }
    final keyPackageBytes = _base64UrlDecode(encoded);
    if (keyPackageBytes.isEmpty || keyPackageBytes.length > 1024 * 1024) {
      throw const FormatException('Chat KeyPackage 字节大小不合法');
    }
    final notBefore = value['not_before'];
    final notAfter = value['not_after'];
    if (notBefore is! int ||
        notAfter is! int ||
        notBefore < 0 ||
        notAfter <= notBefore ||
        value['last_resort'] is! bool) {
      throw const FormatException('Chat KeyPackage 生命周期不合法');
    }
    return MlsKeyPackage(
      cidNumber: value['cid_number'] as String,
      deviceId: value['device_id'] as String,
      devicePublicKey: value['device_public_key_hex'] as String,
      keyPackageId: value['key_package_id'] as String,
      keyPackageBytes: keyPackageBytes,
      cipherSuite: value['cipher_suite'] as String,
      notBeforeMillis: notBefore,
      notAfterMillis: notAfter,
      lastResort: value['last_resort'] as bool,
    );
  }
}

void _requireExactFrameKeys(
  Map<String, dynamic> value,
  List<String> expected,
) {
  if (value.length != expected.length || !expected.every(value.containsKey)) {
    throw const FormatException('Chat 控制帧字段不合法');
  }
}

void _requireControlToken(
  Object? value,
  String field, {
  int maxLength = 256,
}) {
  if (value is! String || value.isEmpty || value.length > maxLength) {
    throw FormatException('Chat 控制帧 $field 不合法');
  }
}

/// WebRTC 仅建立短命控制连接交换 KeyPackage；普通消息和附件不经过本类。
class ChatWebrtcTransport {
  ChatWebrtcTransport({
    required this.accountId,
    required this.localCidNumber,
    required this.cloud,
    required this.sendSignal,
    required this.createKeyPackage,
    required this.runBindingMutation,
  });

  static const _timeout = Duration(seconds: 8);
  static const _controlIdleTimeout = Duration(seconds: 90);

  final String accountId;
  final String localCidNumber;
  final ChatCloudTransport cloud;
  final ChatSignalSender sendSignal;
  final ChatDirectKeyPackageProvider createKeyPackage;
  final ChatWebrtcMutationRunner runBindingMutation;

  final Map<String, _ControlPeer> _controlPeers = {};
  final Map<String, String> _outboundControlPeerIds = {};
  final Map<String, Future<_ControlPeer>> _controlFlights = {};
  final Map<String, Completer<MlsKeyPackage>> _keyPackageRequests = {};
  final Map<String, Future<void>> _signalTails = {};
  final Map<String, _LocalSignalState> _localSignals = {};

  /// 首次会话 KeyPackage 只通过已经建立的设备直连请求，不建立云端库存。
  Future<MlsKeyPackage> requestKeyPackage(String recipientCidNumber) async {
    final peer = await _controlPeer(recipientCidNumber);
    _touchControlPeer(peer);
    final requestId = _newControlId('key-package');
    final completer = Completer<MlsKeyPackage>();
    _keyPackageRequests[requestId] = completer;
    try {
      await peer.channel!.send(RTCDataChannelMessage(
        jsonEncode(ChatWebrtcControlFrame.keyPackageRequest(requestId)),
      ));
      final keyPackage = await completer.future.timeout(_timeout);
      if (keyPackage.cidNumber != recipientCidNumber) {
        throw StateError('直连 KeyPackage CID 与请求目标不一致');
      }
      return keyPackage;
    } finally {
      _keyPackageRequests.remove(requestId);
    }
  }

  Future<_ControlPeer> _controlPeer(String peerCidNumber) {
    final existingId = _outboundControlPeerIds[peerCidNumber];
    final existing = existingId == null ? null : _controlPeers[existingId];
    if (existing?.channel != null &&
        existing!.open.isCompleted &&
        !existing.closing) {
      _touchControlPeer(existing);
      return Future<_ControlPeer>.value(existing);
    }
    final flight = _controlFlights[peerCidNumber];
    if (flight != null) return flight;
    late final Future<_ControlPeer> created;
    created = _openOutboundControlPeer(peerCidNumber).whenComplete(() {
      if (identical(_controlFlights[peerCidNumber], created)) {
        _controlFlights.remove(peerCidNumber);
      }
    });
    _controlFlights[peerCidNumber] = created;
    return created;
  }

  Future<_ControlPeer> _openOutboundControlPeer(String peerCidNumber) async {
    final connectionId = _newControlId('control');
    final peer = await _createControlPeer(connectionId, peerCidNumber);
    _outboundControlPeerIds[peerCidNumber] = connectionId;
    final channel = await peer.connection.createDataChannel(
      'chat-control',
      RTCDataChannelInit()..ordered = true,
    );
    peer.channel = channel;
    _bindControlChannel(peer, channel);
    final offer = await peer.connection.createOffer();
    final localOffer = await _setLocalDescription(peer.connection, offer);
    try {
      final sent = await _sendDescription(connectionId, <String, Object?>{
        'signal_kind': 'offer',
        'connection_id': connectionId,
        'sdp': localOffer.sdp,
        'sdp_type': localOffer.type,
      });
      if (!sent) {
        throw TimeoutException('接收设备信令未在线，无法交换 KeyPackage');
      }
      await peer.open.future.timeout(_timeout);
      _touchControlPeer(peer);
      return peer;
    } catch (error) {
      await _closeControlPeer(connectionId);
      if (error is TimeoutException) {
        throw TimeoutException('接收设备暂未建立直连，无法交换 KeyPackage');
      }
      rethrow;
    }
  }

  Future<RTCSessionDescription> _setLocalDescription(
    RTCPeerConnection connection,
    RTCSessionDescription description,
  ) async {
    await connection.setLocalDescription(description);
    final localDescription = await connection.getLocalDescription();
    if (localDescription == null ||
        (localDescription.sdp ?? '').trim().isEmpty ||
        (localDescription.type ?? '').trim().isEmpty) {
      throw StateError('WebRTC 本地 SDP 未完成');
    }
    return localDescription;
  }

  void _bindLocalIce(
    RTCPeerConnection connection,
    String connectionId,
    String peerCidNumber,
  ) {
    _localSignals[connectionId] = _LocalSignalState(peerCidNumber);
    connection.onIceCandidate = (candidate) {
      final value = candidate.candidate?.trim() ?? '';
      if (value.isEmpty) return;
      unawaited(_queueLocalIce(connectionId, <String, Object?>{
        'signal_kind': 'ice',
        'connection_id': connectionId,
        'candidate': value,
        if ((candidate.sdpMid ?? '').isNotEmpty) 'sdp_mid': candidate.sdpMid,
        if (candidate.sdpMLineIndex != null)
          'sdp_mline_index': candidate.sdpMLineIndex,
      }));
    };
    connection.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        unawaited(_restartIce(connectionId, notifyPeer: true));
      }
    };
  }

  Future<bool> _sendDescription(
    String connectionId,
    Map<String, Object?> signal,
  ) async {
    final state = _localSignals[connectionId];
    if (state == null) return false;
    final sent = await sendSignal(
      recipientCidNumber: state.peerCidNumber,
      signal: signal,
    );
    if (!sent) return false;
    state.descriptionSent = true;
    final pending = state.pendingIce.toList(growable: false);
    state.pendingIce.clear();
    for (final candidate in pending) {
      if (!await sendSignal(
        recipientCidNumber: state.peerCidNumber,
        signal: candidate,
      )) {
        await _closeControlPeer(connectionId);
        return false;
      }
    }
    return true;
  }

  Future<void> _queueLocalIce(
    String connectionId,
    Map<String, Object?> signal,
  ) async {
    final state = _localSignals[connectionId];
    if (state == null) return;
    if (!state.descriptionSent) {
      state.pendingIce.add(signal);
      return;
    }
    try {
      if (!await sendSignal(
        recipientCidNumber: state.peerCidNumber,
        signal: signal,
      )) {
        await _closeControlPeer(connectionId);
      }
    } catch (_) {
      await _closeControlPeer(connectionId);
    }
  }

  Future<void> _addRemoteIce(
    String senderCidNumber,
    String connectionId,
    Map<String, dynamic> signal,
  ) async {
    final peer = _controlPeers[connectionId];
    if (peer == null || peer.peerCidNumber != senderCidNumber) return;
    final candidate = signal['candidate'];
    final sdpMid = signal['sdp_mid'];
    final sdpMLineIndex = signal['sdp_mline_index'];
    if (candidate is! String ||
        candidate.isEmpty ||
        (sdpMid != null && sdpMid is! String) ||
        (sdpMLineIndex != null && sdpMLineIndex is! int)) {
      return;
    }
    final ice = RTCIceCandidate(
      candidate,
      sdpMid as String?,
      sdpMLineIndex as int?,
    );
    if (peer.remoteDescriptionSet) {
      await peer.connection.addCandidate(ice);
    } else {
      peer.pendingIce.add(ice);
    }
  }

  Future<void> _flushRemoteIce(_ControlPeer peer) async {
    final candidates = peer.pendingIce.toList(growable: false);
    peer.pendingIce.clear();
    for (final candidate in candidates) {
      await peer.connection.addCandidate(candidate);
    }
  }

  Future<void> _restartIce(
    String connectionId, {
    required bool notifyPeer,
  }) async {
    final state = _localSignals[connectionId];
    final peer = _controlPeers[connectionId];
    if (state == null || peer == null || state.restarting) return;
    state.restarting = true;
    try {
      if (notifyPeer &&
          !await sendSignal(
            recipientCidNumber: state.peerCidNumber,
            signal: <String, Object?>{
              'signal_kind': 'ice_restart',
              'connection_id': connectionId,
            },
          )) {
        await _closeControlPeer(connectionId);
        return;
      }
      state
        ..descriptionSent = false
        ..pendingIce.clear();
      peer.answerSignal = null;
      await peer.connection.restartIce();
      if (!notifyPeer) return;
      peer
        ..remoteDescriptionSet = false
        ..remoteSdp = null;
      final offer = await peer.connection.createOffer(<String, dynamic>{
        'iceRestart': true,
      });
      final localOffer = await _setLocalDescription(peer.connection, offer);
      if (!await _sendDescription(connectionId, <String, Object?>{
        'signal_kind': 'offer',
        'connection_id': connectionId,
        'sdp': localOffer.sdp,
        'sdp_type': localOffer.type,
      })) {
        await _closeControlPeer(connectionId);
      }
    } finally {
      state.restarting = false;
    }
  }

  Future<void> handleSignal(
    String senderCidNumber,
    Map<String, dynamic> signal,
  ) {
    final signalId = signal['connection_id']?.toString();
    if (signalId == null || !signalId.startsWith('control-')) {
      return Future<void>.value();
    }
    final key = '$senderCidNumber|$signalId';
    final previous = _signalTails[key] ?? Future<void>.value();
    late final Future<void> current;
    current = previous
        .catchError((Object _, StackTrace __) {})
        .then((_) => _handleSignal(senderCidNumber, signal))
        .whenComplete(() {
      if (identical(_signalTails[key], current)) _signalTails.remove(key);
    });
    _signalTails[key] = current;
    return current;
  }

  Future<void> _handleSignal(
    String senderCidNumber,
    Map<String, dynamic> signal,
  ) async {
    final signalKind = signal['signal_kind']?.toString();
    final connectionId = signal['connection_id']?.toString() ?? '';
    if (!connectionId.startsWith('control-')) return;
    if (signalKind == 'ice') {
      await _addRemoteIce(senderCidNumber, connectionId, signal);
      return;
    }
    if (signalKind == 'hangup') {
      await _closeControlPeer(connectionId);
      return;
    }
    if (signalKind == 'ice_restart') {
      await _restartIce(connectionId, notifyPeer: false);
      return;
    }
    await _handleControlSignal(senderCidNumber, signal);
  }

  Future<void> _handleControlSignal(
    String senderCidNumber,
    Map<String, dynamic> signal,
  ) async {
    final kind = signal['signal_kind']?.toString();
    final connectionId = signal['connection_id']?.toString() ?? '';
    if (!connectionId.startsWith('control-')) return;
    if (kind == 'offer') {
      final peer = await _createControlPeer(connectionId, senderCidNumber);
      final cachedAnswer = peer.answerSignal;
      final remoteSdp = signal['sdp']?.toString() ?? '';
      if (cachedAnswer != null && peer.remoteSdp == remoteSdp) {
        await sendSignal(
          recipientCidNumber: senderCidNumber,
          signal: cachedAnswer,
        );
        return;
      }
      peer.connection.onDataChannel = (channel) {
        peer.channel = channel;
        _bindControlChannel(peer, channel);
      };
      await peer.connection.setRemoteDescription(
        RTCSessionDescription(remoteSdp, signal['sdp_type']?.toString()),
      );
      peer.remoteDescriptionSet = true;
      peer.remoteSdp = remoteSdp;
      await _flushRemoteIce(peer);
      final answer = await peer.connection.createAnswer();
      final localAnswer = await _setLocalDescription(peer.connection, answer);
      final answerSignal = <String, Object?>{
        'signal_kind': 'answer',
        'connection_id': connectionId,
        'sdp': localAnswer.sdp,
        'sdp_type': localAnswer.type,
      };
      peer.answerSignal = answerSignal;
      await _sendDescription(connectionId, answerSignal);
      return;
    }
    final peer = _controlPeers[connectionId];
    if (peer == null || peer.peerCidNumber != senderCidNumber) return;
    if (kind == 'answer' && !peer.remoteDescriptionSet) {
      await peer.connection.setRemoteDescription(
        RTCSessionDescription(
          signal['sdp']?.toString(),
          signal['sdp_type']?.toString(),
        ),
      );
      peer.remoteDescriptionSet = true;
      peer.remoteSdp = signal['sdp']?.toString();
      await _flushRemoteIce(peer);
    }
  }

  Future<_ControlPeer> _createControlPeer(
    String connectionId,
    String peerCidNumber,
  ) async {
    final existing = _controlPeers[connectionId];
    if (existing != null) {
      if (existing.peerCidNumber != peerCidNumber) {
        throw StateError('Chat 控制连接 CID 与既有连接不一致');
      }
      return existing;
    }
    final ice = await cloud.fetchIceConfiguration();
    final connection = await createPeerConnection(<String, dynamic>{
      'iceServers': ice.iceServers,
    });
    final peer = _ControlPeer(connectionId, peerCidNumber, connection);
    _controlPeers[connectionId] = peer;
    _bindLocalIce(connection, connectionId, peerCidNumber);
    return peer;
  }

  void _bindControlChannel(_ControlPeer peer, RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !peer.open.isCompleted) {
        peer.open.complete();
        _touchControlPeer(peer);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        unawaited(_closeControlPeer(peer.id));
      }
    };
    channel.onMessage = (message) {
      _touchControlPeer(peer);
      peer.tail = peer.tail
          .then((_) => _handleControlFrame(peer, message))
          .catchError((Object _) {});
    };
  }

  Future<void> _handleControlFrame(
    _ControlPeer peer,
    RTCDataChannelMessage message,
  ) async {
    if (message.isBinary || peer.closing) return;
    final decoded = ChatWebrtcControlFrame.decode(message.text);
    switch (decoded['kind']) {
      case 'key_package_request':
        final requestId = decoded['request_id'];
        if (requestId is! String || requestId.isEmpty) return;
        final keyPackage = await runBindingMutation(createKeyPackage);
        await peer.channel?.send(RTCDataChannelMessage(
          jsonEncode(
            ChatWebrtcControlFrame.keyPackageResponse(requestId, keyPackage),
          ),
        ));
      case 'key_package_response':
        final requestId = decoded['request_id'];
        final completer = _keyPackageRequests[requestId];
        if (completer != null && !completer.isCompleted) {
          completer.complete(ChatWebrtcControlFrame.keyPackage(decoded));
        }
    }
  }

  void _touchControlPeer(_ControlPeer peer) {
    peer.idleTimer?.cancel();
    peer.idleTimer = Timer(_controlIdleTimeout, () {
      unawaited(_closeControlPeer(peer.id));
    });
  }

  Future<void> _closeControlPeer(String connectionId) async {
    final peer = _controlPeers.remove(connectionId);
    if (peer == null || peer.closing) return;
    _localSignals.remove(connectionId);
    peer.closing = true;
    peer.idleTimer?.cancel();
    peer.idleTimer = null;
    if (_outboundControlPeerIds[peer.peerCidNumber] == connectionId) {
      _outboundControlPeerIds.remove(peer.peerCidNumber);
    }
    final channel = peer.channel;
    peer.channel = null;
    if (channel != null) {
      channel.onDataChannelState = null;
      channel.onMessage = null;
      await channel.close();
    }
    await peer.tail.catchError((Object _) {});
    peer.connection.onDataChannel = null;
    peer.connection.onIceCandidate = null;
    peer.connection.onIceConnectionState = null;
    await peer.connection.close();
  }

  Future<void> dispose() async {
    for (final id in _controlPeers.keys.toList(growable: false)) {
      await _closeControlPeer(id);
    }
    for (final completer in _keyPackageRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Chat 直连运行态已关闭'));
      }
    }
    _keyPackageRequests.clear();
  }

  static String _newControlId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

Map<String, dynamic> _keyPackageToJson(MlsKeyPackage keyPackage) =>
    <String, dynamic>{
      'cid_number': keyPackage.cidNumber,
      'device_id': keyPackage.deviceId,
      'device_public_key_hex': keyPackage.devicePublicKey,
      'key_package_id': keyPackage.keyPackageId,
      'key_package': _base64UrlEncode(keyPackage.keyPackageBytes),
      'cipher_suite': keyPackage.cipherSuite,
      'not_before': keyPackage.notBeforeMillis,
      'not_after': keyPackage.notAfterMillis,
      'last_resort': keyPackage.lastResort,
    };

String _base64UrlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _base64UrlDecode(String value) {
  final normalized = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(normalized);
}

class _ControlPeer {
  _ControlPeer(this.id, this.peerCidNumber, this.connection);

  final String id;
  final String peerCidNumber;
  final RTCPeerConnection connection;
  final Completer<void> open = Completer<void>();
  RTCDataChannel? channel;
  Future<void> tail = Future<void>.value();
  Map<String, dynamic>? answerSignal;
  final List<RTCIceCandidate> pendingIce = <RTCIceCandidate>[];
  Timer? idleTimer;
  bool remoteDescriptionSet = false;
  String? remoteSdp;
  bool closing = false;
}

class _LocalSignalState {
  _LocalSignalState(this.peerCidNumber);

  final String peerCidNumber;
  final List<Map<String, Object?>> pendingIce = <Map<String, Object?>>[];
  bool descriptionSent = false;
  bool restarting = false;
}
