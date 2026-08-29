import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../log/app_log.dart';

import 'package:citizenapp/8964/services/square_request_signer.dart';
import 'package:http/http.dart' as http;

import '../chat_models.dart';
import '../crypto/mls_boundary.dart';
import '../proto/chat_envelope.pb.dart';
import 'chat_transport.dart';

const _chatServiceUnavailable = 'Chat 服务尚未配置';
const _chatWsReadyType = 'citizen_chat_ws_ready';
const _chatWsPongType = 'citizen_chat_ws_pong';
const _chatWsSignalType = 'citizen_chat_signal';
const _chatWsEnvelopeType = 'citizen_chat_envelope';
const _chatWsSignalResultType = 'citizen_chat_signal_result';
const _chatHeartbeatInterval = Duration(seconds: 25);
const _chatHeartbeatTimeout = Duration(seconds: 12);
const _chatIceCacheDuration = Duration(minutes: 55);

/// Chat Worker 结构化错误；页面只映射错误码，不展示服务端或请求路径原文。
class ChatCloudException implements Exception {
  const ChatCloudException({
    required this.statusCode,
    required this.errorCode,
    required this.technicalMessage,
  });

  final int statusCode;
  final String errorCode;
  final String technicalMessage;

  @override
  String toString() => errorCode;
}

/// CitizenServe 邮箱返回的一条端到端密文；本类不解析 OpenMLS 正文。
class ChatMailboxEnvelope {
  const ChatMailboxEnvelope({
    required this.envelopeId,
    required this.senderCidNumber,
    required this.recipientCidNumber,
    required this.conversationId,
    required this.envelopeBytes,
    required this.createdAtMillis,
    required this.ttlMillis,
  });

  final String envelopeId;
  final String senderCidNumber;
  final String recipientCidNumber;
  final String conversationId;
  final List<int> envelopeBytes;
  final int createdAtMillis;
  final int ttlMillis;

  factory ChatMailboxEnvelope.fromJson(
    Map<String, dynamic> value, {
    required String localCidNumber,
    required bool realtime,
  }) {
    final expected = realtime
        ? const <String>{
            'type',
            'envelope_id',
            'sender_cid_number',
            'conversation_id',
            'envelope',
            'created_at_millis',
            'ttl_millis',
          }
        : const <String>{
            'envelope_id',
            'sender_cid_number',
            'recipient_cid_number',
            'conversation_id',
            'envelope',
            'created_at_millis',
            'ttl_millis',
          };
    if (value.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(value.keys.toSet()).isNotEmpty ||
        (realtime && value['type'] != _chatWsEnvelopeType)) {
      throw const FormatException('Chat 邮箱密文字段不合法');
    }
    final envelopeId = value['envelope_id'];
    final senderCidNumber = value['sender_cid_number'];
    final recipientCidNumber =
        realtime ? localCidNumber : value['recipient_cid_number'];
    final conversationId = value['conversation_id'];
    final envelope = value['envelope'];
    final createdAtMillis = value['created_at_millis'];
    final ttlMillis = value['ttl_millis'];
    if (envelopeId is! String ||
        envelopeId.isEmpty ||
        senderCidNumber is! String ||
        senderCidNumber.isEmpty ||
        recipientCidNumber != localCidNumber ||
        conversationId is! String ||
        conversationId.isEmpty ||
        envelope is! String ||
        envelope.isEmpty ||
        createdAtMillis is! int ||
        createdAtMillis <= 0 ||
        ttlMillis is! int ||
        ttlMillis <= 0) {
      throw const FormatException('Chat 邮箱密文内容不合法');
    }
    late final List<int> envelopeBytes;
    try {
      envelopeBytes = base64Url.decode(
        envelope.padRight((envelope.length + 3) ~/ 4 * 4, '='),
      );
    } on FormatException {
      throw const FormatException('Chat 邮箱密文编码不合法');
    }
    if (envelopeBytes.isEmpty) {
      throw const FormatException('Chat 邮箱密文不能为空');
    }
    return ChatMailboxEnvelope(
      envelopeId: envelopeId,
      senderCidNumber: senderCidNumber,
      recipientCidNumber: localCidNumber,
      conversationId: conversationId,
      envelopeBytes: envelopeBytes,
      createdAtMillis: createdAtMillis,
      ttlMillis: ttlMillis,
    );
  }
}

/// 固定 STUN 配置。产品禁止 TURN；无法直连时必须明确失败。
class ChatIceConfiguration {
  const ChatIceConfiguration({required this.iceServers});

  final List<Map<String, dynamic>> iceServers;
}

/// CitizenServe Chat 网络边界。
///
/// HTTPS 只承载系统推送端点、设备公开加密钥、端到端密文邮箱和固定
/// STUN 配置；同一账户级 WSS 只承载在线密文与音视频通话信令。Worker 不接收
/// OpenMLS 私钥、聊天明文或附件明文字节。
class ChatCloudTransport implements ChatTransport {
  ChatCloudTransport({
    required this.accountId,
    required this.localCidNumber,
    required this.localDeviceId,
    this.serviceBaseUrl,
    this.sessionToken,
    this.requestSigner,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _httpClient = httpClient ?? http.Client();

  final String accountId;
  final String localCidNumber;
  final String localDeviceId;
  final Uri? serviceBaseUrl;
  final String? sessionToken;
  final SquareDeviceSigner? requestSigner;
  final Duration requestTimeout;
  final http.Client _httpClient;

  WebSocket? _socket;
  Completer<Map<String, dynamic>>? _signalResult;
  Future<void> _signalTail = Future<void>.value();
  ChatIceConfiguration? _cachedIce;
  DateTime? _iceCachedAt;

  /// 只记录不含 URL、Token、CID、正文或服务端原文的阶段码，供本机诊断连接失败。
  String? lastRealtimeDiagnosticCode;

  /// 真机诊断只记录稳定阶段码；Release 下 [AppLog] 会被编译期剥离。
  /// 禁止在这里写入 token、签名、消息正文、账户或服务端异常正文。
  void _recordRealtimeDiagnostic(String? code) {
    lastRealtimeDiagnosticCode = code;
    AppLog.d('[ChatTrace] realtime=${code ?? 'chat_signal_ready'}');
  }

  @override
  ChatTransportType get type => ChatTransportType.mailbox;

  /// 当前绑定失效时关闭 HTTP 连接池；WSS 由账户级 Hub 的 stop closure 先行关闭。
  void dispose() {
    _httpClient.close();
  }

  Future<void> registerPushEndpoint({
    required String pushProvider,
    required String pushToken,
    required String? apnsEnvironment,
    required int expiresAtMillis,
  }) async {
    await _putMap('/chat/push-endpoint', {
      'device_id': localDeviceId,
      'push_provider': pushProvider,
      'push_token': pushToken,
      'apns_environment': apnsEnvironment,
      'expires_at': expiresAtMillis,
    });
  }

  /// 幂等登记当前认证设备唯一的 HPKE 公开加密钥；私钥只存在于手机加密状态。
  Future<void> publishDeviceKey(String devicePublicKey) async {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(devicePublicKey)) {
      throw const FormatException('Chat 设备公开加密钥必须为 32 字节 hex');
    }
    await _putMap('/chat/device-key', {
      'device_id': localDeviceId,
      'device_public_key_hex': devicePublicKey.toLowerCase(),
    });
  }

  /// 读取接收 CID 当前认证设备的 HPKE 公开加密钥，不创建会话或 WebRTC 连接。
  Future<String> resolveDeviceKey(String recipientCidNumber) async {
    final response = await _postMap('/chat/device-key/resolve', {
      'recipient_cid_number': recipientCidNumber,
    });
    final key = response['device_public_key_hex'];
    if (key is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key)) {
      throw const FormatException('CitizenServe 未返回合法 Chat 设备公开加密钥');
    }
    return key.toLowerCase();
  }

  /// 发布当前设备唯一的 RFC 9420 last-resort 包，仅供 OpenMLS 群成员加入。
  /// 私聊始终使用 HPKE 设备公钥，不读取本接口，也不维护普通包库存。
  Future<void> publishGroupKeyPackage(MlsKeyPackage keyPackage) async {
    if (keyPackage.cidNumber != localCidNumber ||
        keyPackage.deviceId != localDeviceId ||
        !keyPackage.lastResort) {
      throw const FormatException('群聊 KeyPackage 与当前设备身份不一致');
    }
    await _putMap('/chat/groups/key-package', {
      'key_package': _keyPackageToJson(keyPackage),
    });
  }

  /// 读取被邀请设备的群聊公开包；读取不消费、不旋转，也不建立 WebRTC。
  Future<MlsKeyPackage> resolveGroupKeyPackage(
      String recipientCidNumber) async {
    final response = await _postMap('/chat/groups/key-package/resolve', {
      'recipient_cid_number': recipientCidNumber,
    });
    final raw = response['key_package'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('CitizenServe 未返回 Chat KeyPackage');
    }
    final claimed = _keyPackageFromJson(raw);
    if (claimed.cidNumber != recipientCidNumber) {
      throw const FormatException('CitizenServe KeyPackage CID 不一致');
    }
    return claimed;
  }

  /// HTTP 200 表示 CitizenServe 已持久保存同一密文；失败时保留本机可靠队列。
  @override
  Future<ChatDeliveryResult> sendEncryptedEnvelope({
    required String envelopeId,
    required List<int> envelopeBytes,
    required String recipientCidNumber,
  }) async {
    try {
      final envelope = ChatEnvelope.fromBuffer(envelopeBytes);
      if (envelope.envelopeId != envelopeId ||
          envelope.senderCidNumber != localCidNumber ||
          envelope.recipientCidNumber != recipientCidNumber) {
        throw const FormatException('Chat Envelope 与邮箱路由不一致');
      }
      await _postMap('/chat/messages', {
        'envelope_id': envelopeId,
        'recipient_cid_number': recipientCidNumber,
        'conversation_id': envelope.conversationId,
        'envelope': base64Url.encode(envelopeBytes),
        'created_at_millis': envelope.createdAtMillis.toInt(),
        'ttl_millis': envelope.ttlMillis.toInt(),
      });
      return ChatDeliveryResult(
        envelopeId: envelopeId,
        transportType: type,
        state: ChatMessageDeliveryState.sent,
      );
    } catch (error) {
      return ChatDeliveryResult(
        envelopeId: envelopeId,
        transportType: type,
        state: ChatMessageDeliveryState.queued,
        // 本机可靠队列只保存稳定阶段码；禁止把 URL、CID、响应正文或系统异常
        // 原文写进消息状态。失败仍保留同一 Envelope 等待有界退避重试。
        errorMessage: _deliveryErrorCode(error),
      );
    }
  }

  /// WSS 建立后补拉邮箱，和在线推送采用相同严格密文字段。
  Future<List<ChatMailboxEnvelope>> fetchMailbox() async {
    final value = await _getJson('/chat/messages');
    if (value is! List<dynamic>) {
      throw const FormatException('Chat 邮箱响应不是数组');
    }
    return value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Chat 邮箱条目不是对象');
      }
      return ChatMailboxEnvelope.fromJson(
        item,
        localCidNumber: localCidNumber,
        realtime: false,
      );
    }).toList(growable: false);
  }

  /// 只有密文已完成 OpenMLS 处理并写入本机数据库后才调用。
  Future<void> acknowledgeMailbox(List<String> envelopeIds) async {
    if (envelopeIds.isEmpty) return;
    await _postMap('/chat/messages/ack', envelopeIds);
  }

  /// 手机把已经端到端加密的临时文件分片直传 R2；Worker 只返回签名 URL。
  Future<void> uploadEncryptedAttachment({
    required String attachmentId,
    required List<String> recipientCidNumbers,
    required File cipherFile,
    required int cipherByteSize,
    required String cipherSha256,
  }) async {
    final plan = await _postMap('/chat/attachments/prepare', {
      'attachment_id': attachmentId,
      'recipient_cid_numbers': recipientCidNumbers,
      'cipher_byte_size': cipherByteSize,
      'cipher_sha256': cipherSha256,
    });
    if (plan['upload_state'] == 'ready') return;
    final rawParts = plan['parts'];
    if (rawParts is! List<dynamic> || rawParts.isEmpty) {
      throw const FormatException('Chat 附件上传分片计划不合法');
    }
    final etags = <String>[];
    try {
      for (final rawPart in rawParts) {
        if (rawPart is! Map<String, dynamic>) {
          throw const FormatException('Chat 附件上传分片不合法');
        }
        final offset = rawPart['offset'];
        final byteSize = rawPart['byte_size'];
        final uploadUrl = rawPart['upload_url'];
        final uploadHeaders = rawPart['upload_headers'];
        if (offset is! int ||
            offset < 0 ||
            byteSize is! int ||
            byteSize <= 0 ||
            uploadUrl is! String ||
            uploadHeaders is! Map<String, dynamic>) {
          throw const FormatException('Chat 附件上传分片内容不合法');
        }
        final uri = Uri.parse(uploadUrl);
        if (uri.scheme != 'https' || uri.host.isEmpty) {
          throw const FormatException('Chat 附件只允许 HTTPS 直传地址');
        }
        final request = http.StreamedRequest('PUT', uri)
          ..contentLength = byteSize
          ..headers.addAll(
            uploadHeaders.map((key, value) => MapEntry(key, value.toString())),
          );
        final sending =
            _httpClient.send(request).timeout(const Duration(hours: 6));
        await request.sink.addStream(
          cipherFile.openRead(offset, offset + byteSize),
        );
        await request.sink.close();
        final response = await sending;
        await response.stream.drain<void>();
        final etag = response.headers['etag'];
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            etag == null ||
            etag.isEmpty) {
          throw StateError('chat_attachment_part_upload_failed');
        }
        etags.add(etag);
      }
      await _postMap('/chat/attachments/complete', {
        'attachment_id': attachmentId,
        'etags': etags,
      });
    } catch (_) {
      await abortAttachment(attachmentId).catchError((Object _) {});
      rethrow;
    }
  }

  /// 接收端把 R2 密文流式写入临时文件并复核长度；SHA-256 由运行态统一校验。
  Future<void> downloadEncryptedAttachment({
    required String attachmentId,
    required File target,
    required int expectedByteSize,
    required String expectedSha256,
  }) async {
    final plan = await _postMap('/chat/attachments/download', {
      'attachment_id': attachmentId,
    });
    if (plan['cipher_byte_size'] != expectedByteSize ||
        plan['cipher_sha256'] != expectedSha256) {
      throw const FormatException('Chat 附件密文索引与 OpenMLS 控制消息不一致');
    }
    final rawUrl = plan['download_url'];
    if (rawUrl is! String) throw const FormatException('Chat 附件下载地址缺失');
    final uri = Uri.parse(rawUrl);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Chat 附件只允许 HTTPS 下载地址');
    }
    await target.parent.create(recursive: true);
    if (await target.exists()) await target.delete();
    final response = await _httpClient
        .send(http.Request('GET', uri))
        .timeout(const Duration(hours: 6));
    if (response.statusCode != 200) {
      throw StateError('chat_attachment_download_failed');
    }
    final sink = target.openWrite();
    try {
      await sink.addStream(response.stream);
    } finally {
      await sink.close();
    }
    if (await target.length() != expectedByteSize) {
      await target.delete();
      throw const FormatException('Chat 附件密文下载长度不一致');
    }
  }

  Future<void> acknowledgeAttachment(String attachmentId) =>
      _postMap('/chat/attachments/ack', {'attachment_id': attachmentId});

  Future<void> abortAttachment(String attachmentId) =>
      _postMap('/chat/attachments/abort', {'attachment_id': attachmentId});

  /// 每个缓存周期只读取一次固定 STUN 配置；响应出现 TURN 字段也不会采用。
  Future<ChatIceConfiguration> fetchIceConfiguration() async {
    final cached = _cachedIce;
    final cachedAt = _iceCachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _chatIceCacheDuration) {
      return cached;
    }
    final value = await _postMap('/chat/ice', const <String, Object?>{});
    final stunUrls = _iceUrls(value['stun_urls'], const {'stun:', 'stuns:'});
    if (stunUrls.isEmpty) {
      throw const FormatException('Chat ICE 配置不完整');
    }
    final configuration = ChatIceConfiguration(
      iceServers: [
        <String, dynamic>{'urls': stunUrls},
      ],
    );
    _cachedIce = configuration;
    _iceCachedAt = DateTime.now();
    return configuration;
  }

  /// 经当前账户唯一 WSS 串行发送一条扁平信令，并等待唯一 sent/unavailable 结果。
  Future<bool> sendSignal({
    required String recipientCidNumber,
    required Map<String, Object?> signal,
  }) {
    final result = Completer<bool>();
    _signalTail = _signalTail.catchError((Object _) {}).then((_) async {
      try {
        result.complete(await _sendSignalNow(recipientCidNumber, signal));
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<bool> _sendSignalNow(
    String recipientCidNumber,
    Map<String, Object?> signal,
  ) async {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('Chat 账户级 WSS 尚未连接');
    }
    _validateSignal(signal);
    final frame = <String, Object?>{
      'type': _chatWsSignalType,
      'recipient_cid_number': recipientCidNumber,
      ...signal,
    };
    final pending = Completer<Map<String, dynamic>>();
    _signalResult = pending;
    try {
      socket.add(jsonEncode(frame));
      final response = await pending.future.timeout(requestTimeout);
      final expectedConnectionId = signal['connection_id'];
      if (expectedConnectionId != null &&
          response['connection_id'] != expectedConnectionId) {
        throw const FormatException('Chat WSS 信令结果连接不一致');
      }
      final state = response['delivery_state'];
      if (state == 'sent') return true;
      if (state == 'unavailable') {
        _recordRealtimeDiagnostic('chat_signal_unavailable');
        return false;
      }
      throw const FormatException('Chat WSS 信令结果不合法');
    } on TimeoutException {
      _recordRealtimeDiagnostic('chat_signal_result_timeout');
      unawaited(socket.close(1011, 'signal_result_timeout'));
      rethrow;
    } finally {
      if (identical(_signalResult, pending)) _signalResult = null;
    }
  }

  Future<Future<void> Function()?> connectRealtime({
    required Future<void> Function(Map<String, dynamic> message) onMessage,
    Future<void> Function()? onDisconnected,
  }) async {
    if (_socket != null) throw StateError('Chat 账户级 WSS 已连接');
    final uri = _signalUri('/chat/signals');
    if (AppLog.diagnosticsEnabled) {
      await _diagnoseRealtimePreflight(uri);
    }
    WebSocket socket;
    try {
      socket = await WebSocket.connect(
        uri.toString(),
        headers: await _wsHeaders(uri),
      ).timeout(requestTimeout);
    } on TimeoutException {
      _recordRealtimeDiagnostic('chat_signal_connect_timeout');
      return null;
    } on SocketException {
      _recordRealtimeDiagnostic('chat_signal_connect_socket_error');
      return null;
    } on WebSocketException catch (error) {
      _recordRealtimeDiagnostic(_webSocketFailureDiagnostic(error));
      return null;
    } catch (_) {
      _recordRealtimeDiagnostic('chat_signal_connect_failed');
      return null;
    }
    var closedByClient = false;
    var disconnectedNotified = false;
    var established = false;
    final ready = Completer<void>();
    Timer? heartbeatTimer;
    Timer? pongTimer;

    void stopHeartbeat() {
      heartbeatTimer?.cancel();
      heartbeatTimer = null;
      pongTimer?.cancel();
      pongTimer = null;
    }

    void failPendingSignal(String code) {
      final pending = _signalResult;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(StateError(code));
      }
    }

    void notifyDisconnected(String code) {
      stopHeartbeat();
      if (identical(_socket, socket)) _socket = null;
      failPendingSignal(code);
      if (closedByClient || disconnectedNotified || !established) return;
      disconnectedNotified = true;
      _recordRealtimeDiagnostic(code);
      unawaited(onDisconnected?.call() ?? Future<void>.value());
    }

    void startHeartbeat() {
      heartbeatTimer ??= Timer.periodic(_chatHeartbeatInterval, (_) {
        if (closedByClient || pongTimer != null) return;
        try {
          socket.add('ping');
          pongTimer = Timer(_chatHeartbeatTimeout, () {
            pongTimer = null;
            if (closedByClient) return;
            _recordRealtimeDiagnostic('chat_signal_pong_timeout');
            unawaited(socket.close(1011, 'pong_timeout'));
          });
        } catch (_) {
          _recordRealtimeDiagnostic('chat_signal_transport_error');
          unawaited(socket.close(1011, 'ping_failed'));
        }
      });
    }

    late final StreamSubscription<dynamic> subscription;
    subscription = socket.listen(
      (event) {
        try {
          final text =
              event is List<int> ? utf8.decode(event) : event.toString();
          final decoded = jsonDecode(text);
          if (decoded is! Map<String, dynamic>) {
            _recordRealtimeDiagnostic('chat_signal_message_invalid');
            return;
          }
          final type = decoded['type'];
          if (type == _chatWsReadyType) {
            if (!ready.isCompleted) ready.complete();
            startHeartbeat();
          } else if (type == _chatWsPongType) {
            pongTimer?.cancel();
            pongTimer = null;
          } else if (type == _chatWsSignalResultType && ready.isCompleted) {
            final pending = _signalResult;
            if (pending == null || pending.isCompleted) {
              _recordRealtimeDiagnostic('chat_signal_result_unexpected');
            } else {
              pending.complete(decoded);
            }
          } else if (ready.isCompleted &&
              (type == _chatWsSignalType || type == _chatWsEnvelopeType)) {
            unawaited(onMessage(decoded));
          } else {
            _recordRealtimeDiagnostic('chat_signal_message_invalid');
          }
        } catch (_) {
          // 畸形帧只记录安全阶段码，不让一条坏帧杀死后续实时收件。
          _recordRealtimeDiagnostic('chat_signal_message_invalid');
        }
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(StateError('chat_signal_closed'));
        }
        notifyDisconnected('chat_signal_closed');
      },
      onError: (_) {
        if (!ready.isCompleted) {
          ready.completeError(StateError('chat_signal_transport_error'));
        }
        notifyDisconnected('chat_signal_transport_error');
      },
      cancelOnError: true,
    );
    try {
      await ready.future.timeout(requestTimeout);
      if (socket.readyState != WebSocket.open) {
        throw StateError('chat_signal_closed');
      }
    } on TimeoutException {
      _recordRealtimeDiagnostic('chat_signal_ready_timeout');
      closedByClient = true;
      stopHeartbeat();
      await subscription.cancel();
      await socket.close(1011, 'ready_timeout');
      return null;
    } catch (_) {
      _recordRealtimeDiagnostic('chat_signal_connect_failed');
      closedByClient = true;
      stopHeartbeat();
      await subscription.cancel();
      await socket.close(1011, 'connect_failed');
      return null;
    }
    established = true;
    _socket = socket;
    _recordRealtimeDiagnostic(null);
    return () async {
      closedByClient = true;
      stopHeartbeat();
      if (identical(_socket, socket)) _socket = null;
      failPendingSignal('chat_signal_closed');
      await subscription.cancel();
      await socket.close(WebSocketStatus.normalClosure, 'client_close');
    };
  }

  /// 用独立 nonce 对同一路径做一次无 Upgrade 的 HTTPS 鉴权预检。
  /// 鉴权通过的官方响应应为 426；这里只记录状态码与稳定 error_code。
  Future<void> _diagnoseRealtimePreflight(Uri wsUri) async {
    try {
      final response = await _httpClient
          .get(wsUri.replace(scheme: 'https'), headers: await _wsHeaders(wsUri))
          .timeout(requestTimeout);
      var errorCode = '-';
      try {
        final decoded = jsonDecode(response.body);
        final candidate =
            decoded is Map<String, dynamic> ? decoded['error_code'] : null;
        if (candidate is String &&
            RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(candidate)) {
          errorCode = candidate;
        }
      } on Object {
        // 响应正文不合法时只保留状态码，禁止把正文写入日志。
      }
      AppLog.d(
        '[ChatTrace] realtime_preflight status=${response.statusCode} '
        'code=$errorCode',
      );
    } on TimeoutException {
      AppLog.d('[ChatTrace] realtime_preflight timeout');
    } on SocketException {
      AppLog.d('[ChatTrace] realtime_preflight socket_error');
    } on Object catch (error) {
      AppLog.d(
        '[ChatTrace] realtime_preflight failed '
        'type=${error.runtimeType}',
      );
    }
  }

  Future<Map<String, dynamic>> _postMap(String path, Object body) async {
    final value = await _requestJson('POST', path, body: body);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('CitizenServe 响应不是对象');
    }
    return value;
  }

  Future<Map<String, dynamic>> _putMap(String path, Object body) async {
    final value = await _requestJson('PUT', path, body: body);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('CitizenServe 响应不是对象');
    }
    return value;
  }

  Future<Object?> _getJson(String path) => _requestJson('GET', path);

  Future<Object?> _requestJson(
    String method,
    String path, {
    Object? body,
  }) async {
    final uri = _uri(path);
    final encoded = body == null ? '' : jsonEncode(body);
    final headers = await _headers(method, uri, encoded);
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = encoded;
    final streamed = await _httpClient.send(request).timeout(requestTimeout);
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Uri _uri(String path) {
    final base = serviceBaseUrl;
    if (base == null || (sessionToken ?? '').trim().isEmpty) {
      throw StateError(_chatServiceUnavailable);
    }
    if (base.scheme.toLowerCase() != 'https' || base.host.isEmpty) {
      throw StateError('Chat 云端只允许 HTTPS 加密地址');
    }
    // 正式 API 使用同域 `/api` 前缀，不能用 Uri.resolve 丢掉该前缀。
    final root = base.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$root$path');
  }

  Uri _signalUri(String path) => _uri(path).replace(scheme: 'wss');

  Future<Map<String, String>> _headers(
    String method,
    Uri uri,
    String body,
  ) async {
    final token = sessionToken?.trim() ?? '';
    final headers = <String, String>{
      'authorization': 'Bearer $token',
      'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
    };
    final signer = requestSigner;
    if (signer != null) {
      headers.addAll(
        await squareRequestHeaders(
          method: method,
          uri: uri,
          body: body,
          sessionToken: token,
          sign: signer,
        ),
      );
    }
    return headers;
  }

  Future<Map<String, String>> _wsHeaders(Uri uri) async {
    final headers = await _headers('GET', uri, '');
    headers['x-chat-device'] = localDeviceId;
    return headers;
  }
}

Map<String, dynamic> _keyPackageToJson(MlsKeyPackage keyPackage) =>
    <String, dynamic>{
      'cid_number': keyPackage.cidNumber,
      'device_id': keyPackage.deviceId,
      'device_public_key_hex': keyPackage.devicePublicKey,
      'key_package_id': keyPackage.keyPackageId,
      'key_package':
          base64Url.encode(keyPackage.keyPackageBytes).replaceAll('=', ''),
      'cipher_suite': keyPackage.cipherSuite,
      'not_before': keyPackage.notBeforeMillis,
      'not_after': keyPackage.notAfterMillis,
      'last_resort': keyPackage.lastResort,
    };

MlsKeyPackage _keyPackageFromJson(Map<String, dynamic> value) {
  const fields = <String>{
    'cid_number',
    'device_id',
    'device_public_key_hex',
    'key_package_id',
    'key_package',
    'cipher_suite',
    'not_before',
    'not_after',
    'last_resort',
  };
  if (value.keys.toSet().difference(fields).isNotEmpty ||
      fields.difference(value.keys.toSet()).isNotEmpty ||
      value['cid_number'] is! String ||
      value['device_id'] is! String ||
      value['device_public_key_hex'] is! String ||
      value['key_package_id'] is! String ||
      value['key_package'] is! String ||
      value['cipher_suite'] is! String ||
      value['not_before'] is! int ||
      value['not_after'] is! int ||
      value['last_resort'] is! bool) {
    throw const FormatException('CitizenServe KeyPackage 字段不合法');
  }
  late final List<int> bytes;
  try {
    final encoded = value['key_package'] as String;
    bytes = base64Url.decode(
      encoded.padRight((encoded.length + 3) ~/ 4 * 4, '='),
    );
  } on FormatException {
    throw const FormatException('CitizenServe KeyPackage 编码不合法');
  }
  if (bytes.isEmpty) {
    throw const FormatException('CitizenServe KeyPackage 不能为空');
  }
  return MlsKeyPackage(
    cidNumber: value['cid_number'] as String,
    deviceId: value['device_id'] as String,
    devicePublicKey: value['device_public_key_hex'] as String,
    keyPackageId: value['key_package_id'] as String,
    keyPackageBytes: bytes,
    cipherSuite: value['cipher_suite'] as String,
    notBeforeMillis: value['not_before'] as int,
    notAfterMillis: value['not_after'] as int,
    lastResort: value['last_resort'] as bool,
  );
}

/// WebSocket 握手异常只提取 HTTP 状态类别，不把 URL、Header 或响应正文写入日志。
String _webSocketFailureDiagnostic(WebSocketException error) {
  final status = RegExp(
    r'\b([45][0-9]{2})\b',
  ).firstMatch(error.message)?.group(1);
  return status == null
      ? 'chat_signal_handshake_failed'
      : 'chat_signal_http_$status';
}

Object? _decodeResponse(http.Response response) {
  late final Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } on FormatException {
    throw const FormatException('CitizenServe 响应不是 JSON');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final error =
        decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    throw ChatCloudException(
      statusCode: response.statusCode,
      errorCode: (error['error_code'] ?? 'chat_request_failed').toString(),
      technicalMessage: (error['message'] ?? '').toString(),
    );
  }
  if (decoded is Map<String, dynamic> && decoded['ok'] == false) {
    throw ChatCloudException(
      statusCode: response.statusCode,
      errorCode: (decoded['error_code'] ?? 'chat_request_failed').toString(),
      technicalMessage: (decoded['message'] ?? '').toString(),
    );
  }
  return decoded;
}

String _deliveryErrorCode(Object error) => switch (error) {
      ChatCloudException(:final errorCode) => errorCode,
      TimeoutException() => 'chat_request_timeout',
      SocketException() => 'chat_request_network_unavailable',
      FormatException() => 'chat_response_invalid',
      _ => 'chat_delivery_failed',
    };

List<String> _iceUrls(Object? value, Set<String> schemes) {
  if (value is! List<dynamic>) throw const FormatException('Chat ICE URL 不合法');
  final urls = <String>[];
  for (final item in value) {
    if (item is! String ||
        item.isEmpty ||
        !schemes.any((scheme) => item.startsWith(scheme))) {
      throw const FormatException('Chat ICE URL 不合法');
    }
    urls.add(item);
  }
  return urls;
}

void _validateSignal(Map<String, Object?> signal) {
  final signalKind = signal['signal_kind'];
  final expected = <String>{'signal_kind'};
  switch (signalKind) {
    case 'peer_ready':
      break;
    case 'offer':
    case 'answer':
      expected.addAll(const {'connection_id', 'sdp', 'sdp_type'});
      if (signal['sdp_type'] != signalKind) {
        throw const FormatException('Chat SDP 类型不合法');
      }
    case 'ice':
      expected.addAll(const {'connection_id', 'candidate'});
      if (signal.containsKey('sdp_mid')) expected.add('sdp_mid');
      if (signal.containsKey('sdp_mline_index')) {
        expected.add('sdp_mline_index');
      }
    case 'hangup':
    case 'ice_restart':
      expected.add('connection_id');
    default:
      throw const FormatException('Chat 信令类型不合法');
  }
  final actual = signal.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw const FormatException('Chat 信令字段不合法');
  }
}
