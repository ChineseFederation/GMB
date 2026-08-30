import 'dart:async';
import 'dart:math';

import 'package:chat_sdk/call.dart';

import 'peer.dart';

typedef CitizenCallPeerFactory = CallPeer Function();
typedef CitizenCallUserReader = Future<String> Function();

class CitizenCallHandle {
  const CitizenCallHandle({
    required this.session,
    required this.peer,
    required this.title,
    required this.incoming,
  });

  final DirectCallSession session;
  final CallPeer peer;
  final String title;
  final bool incoming;
}

/// App 级唯一通话协调器；所有页面共享同一账户 WSS 信令。
class CitizenCallCoordinator {
  CitizenCallCoordinator({
    required CallTransport transport,
    required CitizenCallUserReader readLocalUserId,
    CitizenCallPeerFactory? peerFactory,
    Random? random,
  })  : _transport = transport,
        _readLocalUserId = readLocalUserId,
        _peerFactory = peerFactory ?? CitizenCallPeer.new,
        _random = random ?? Random.secure();

  static const _signalFields = <String>{
    'signal_kind',
    'connection_id',
    'sdp',
    'sdp_type',
    'candidate',
    'sdp_mid',
    'sdp_mline_index',
  };

  final CallTransport _transport;
  final CitizenCallUserReader _readLocalUserId;
  final CitizenCallPeerFactory _peerFactory;
  final Random _random;
  final StreamController<CitizenCallHandle> _incoming =
      StreamController<CitizenCallHandle>.broadcast(sync: true);
  CitizenCallHandle? _active;
  StreamSubscription<DirectCallState>? _activeState;

  Stream<CitizenCallHandle> get incomingCalls => _incoming.stream;
  CitizenCallHandle? get activeCall => _active;

  Future<CitizenCallHandle> startOutgoing({
    required String localCidNumber,
    required String peerCidNumber,
    required String title,
    required bool video,
  }) async {
    if (_active != null) throw StateError('当前已有通话');
    if (localCidNumber.isEmpty || peerCidNumber.isEmpty) {
      throw StateError('通话身份不完整');
    }
    final peer = _peerFactory();
    final session = DirectCallSession.outgoing(
      connectionId: _newConnectionId(),
      localUserId: localCidNumber,
      remoteUserId: peerCidNumber,
      mediaKind: video ? CallMediaKind.video : CallMediaKind.voice,
      transport: _transport,
      peer: peer,
    );
    final handle = CitizenCallHandle(
      session: session,
      peer: peer,
      title: title,
      incoming: false,
    );
    _setActive(handle);
    return handle;
  }

  Future<void> handleFrame(Map<String, dynamic> frame) async {
    if (frame['type'] != 'citizen_chat_signal') return;
    final sender = frame['sender_cid_number'];
    if (sender is! String || sender.isEmpty) return;
    final wire = <String, Object?>{};
    for (final key in _signalFields) {
      if (frame.containsKey(key)) wire[key] = frame[key];
    }
    final signal = CallSignal.fromWire(wire);
    final active = _active;
    if (active != null) {
      if (active.session.connectionId == signal.connectionId &&
          active.session.remoteUserId == sender) {
        await active.session.receive(signal);
      } else if (signal.kind == CallSignalKind.offer) {
        await _transport.sendSignal(
          recipientUserId: sender,
          signal: CallSignal.control(
            kind: CallSignalKind.hangup,
            connectionId: signal.connectionId,
          ),
        );
      }
      return;
    }
    if (signal.kind != CallSignalKind.offer) return;
    final localUserId = await _readLocalUserId();
    if (localUserId.isEmpty) return;
    final peer = _peerFactory();
    final session = DirectCallSession.incoming(
      connectionId: signal.connectionId,
      localUserId: localUserId,
      remoteUserId: sender,
      mediaKind:
          signal.containsVideo ? CallMediaKind.video : CallMediaKind.voice,
      offer: signal,
      transport: _transport,
      peer: peer,
    );
    final handle = CitizenCallHandle(
      session: session,
      peer: peer,
      title: sender,
      incoming: true,
    );
    _setActive(handle);
    _incoming.add(handle);
  }

  void _setActive(CitizenCallHandle handle) {
    _active = handle;
    unawaited(_activeState?.cancel());
    _activeState = handle.session.states.listen((state) {
      if (state.isTerminal && identical(_active, handle)) {
        _active = null;
        unawaited(_activeState?.cancel());
        _activeState = null;
      }
    });
  }

  String _newConnectionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final randomHex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'rtc.${DateTime.now().microsecondsSinceEpoch}.$randomHex';
  }

  Future<void> dispose() async {
    await _active?.session.hangUp();
    await _activeState?.cancel();
    _activeState = null;
    _active = null;
    await _incoming.close();
  }
}
