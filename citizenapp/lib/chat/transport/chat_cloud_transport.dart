import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:citizenapp/8964/services/square_request_signer.dart';

const _chatServiceUnavailable = 'Chat 无内容建连服务尚未配置';
const _chatWsReadyType = 'citizen_chat_ws_ready';
const _chatWsPongType = 'citizen_chat_ws_pong';
const _chatHeartbeatInterval = Duration(seconds: 25);
const _chatHeartbeatTimeout = Duration(seconds: 12);

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

/// Cloudflare 最小 Chat 协调边界。
///
/// 只维护系统推送端点、无内容唤醒和 WebRTC SDP/ICE 信令；该类没有 Envelope、
/// KeyPackage、附件上传或媒体下载 API，避免业务代码重新把聊天内容送入云端。
class ChatCloudTransport {
  ChatCloudTransport({
    required this.accountId,
    required this.localDeviceId,
    this.serviceBaseUrl,
    this.sessionToken,
    this.requestSigner,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _httpClient = httpClient ?? http.Client();

  final String accountId;
  final String localDeviceId;
  final Uri? serviceBaseUrl;
  final String? sessionToken;
  final SquareDeviceSigner? requestSigner;
  final Duration requestTimeout;
  final http.Client _httpClient;

  /// 只记录不含 URL、Token、CID、正文或服务端原文的阶段码，供本机诊断连接失败。
  String? lastRealtimeDiagnosticCode;

  /// 当前绑定失效时关闭该上下文持有的 HTTP 连接池。
  void dispose() {
    _httpClient.close();
  }

  Future<void> registerPushEndpoint({
    required String pushProvider,
    required String pushToken,
    required String? apnsEnvironment,
    required int expiresAtMillis,
  }) async {
    await _putJson('/chat/push-endpoint', {
      'device_id': localDeviceId,
      'push_provider': pushProvider,
      'push_token': pushToken,
      'apns_environment': apnsEnvironment,
      'expires_at': expiresAtMillis,
    });
  }

  Future<bool> sendSignal({
    required String recipientCidNumber,
    String? recipientDeviceId,
    required Map<String, dynamic> signal,
  }) async {
    final json = await _postJson('/chat/signals', {
      'sender_device_id': localDeviceId,
      'recipient_cid_number': recipientCidNumber,
      'recipient_device_id': recipientDeviceId ?? '',
      'signal': signal,
    });
    final sent = json['delivery_state'] == 'sent';
    if (!sent) lastRealtimeDiagnosticCode = 'chat_signal_unavailable';
    return sent;
  }

  Future<Future<void> Function()?> connectRealtime({
    required Future<void> Function(Map<String, dynamic> message) onMessage,
    Future<void> Function()? onDisconnected,
  }) async {
    final uri = _signalUri('/chat/signals');
    WebSocket socket;
    try {
      socket = await WebSocket.connect(uri.toString(),
              headers: await _wsHeaders(uri))
          .timeout(requestTimeout);
    } on TimeoutException {
      lastRealtimeDiagnosticCode = 'chat_signal_connect_timeout';
      return null;
    } on SocketException {
      lastRealtimeDiagnosticCode = 'chat_signal_connect_socket_error';
      return null;
    } catch (_) {
      lastRealtimeDiagnosticCode = 'chat_signal_connect_failed';
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

    void notifyDisconnected(String code) {
      stopHeartbeat();
      if (closedByClient || disconnectedNotified || !established) return;
      disconnectedNotified = true;
      lastRealtimeDiagnosticCode = code;
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
            lastRealtimeDiagnosticCode = 'chat_signal_pong_timeout';
            unawaited(socket.close(1011, 'pong_timeout'));
          });
        } catch (_) {
          lastRealtimeDiagnosticCode = 'chat_signal_transport_error';
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
          if (decoded is Map<String, dynamic>) {
            final type = decoded['type'];
            if (type == _chatWsReadyType) {
              if (!ready.isCompleted) ready.complete();
              startHeartbeat();
            } else if (type == _chatWsPongType) {
              pongTimer?.cancel();
              pongTimer = null;
            } else if (ready.isCompleted) {
              unawaited(onMessage(decoded));
            } else {
              lastRealtimeDiagnosticCode = 'chat_signal_message_invalid';
            }
          } else {
            lastRealtimeDiagnosticCode = 'chat_signal_message_invalid';
          }
        } catch (_) {
          // 畸形帧只记录安全阶段码，不让一条坏帧杀死后续实时收件。
          lastRealtimeDiagnosticCode = 'chat_signal_message_invalid';
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
      lastRealtimeDiagnosticCode = 'chat_signal_ready_timeout';
      closedByClient = true;
      stopHeartbeat();
      await subscription.cancel();
      await socket.close(1011, 'ready_timeout');
      return null;
    } catch (_) {
      lastRealtimeDiagnosticCode = 'chat_signal_connect_failed';
      closedByClient = true;
      stopHeartbeat();
      await subscription.cancel();
      await socket.close(1011, 'connect_failed');
      return null;
    }
    established = true;
    lastRealtimeDiagnosticCode = null;
    return () async {
      closedByClient = true;
      stopHeartbeat();
      await subscription.cancel();
      await socket.close(WebSocketStatus.normalClosure, 'client_close');
    };
  }

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, Object?> body) async {
    final uri = _uri(path);
    final encoded = jsonEncode(body);
    final response = await _httpClient
        .post(uri, headers: await _headers('POST', uri, encoded), body: encoded)
        .timeout(requestTimeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _putJson(
      String path, Map<String, Object?> body) async {
    final uri = _uri(path);
    final encoded = jsonEncode(body);
    final response = await _httpClient
        .put(uri, headers: await _headers('PUT', uri, encoded), body: encoded)
        .timeout(requestTimeout);
    return _decodeResponse(response);
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final base = serviceBaseUrl;
    if (base == null || (sessionToken ?? '').trim().isEmpty) {
      throw StateError(_chatServiceUnavailable);
    }
    if (base.scheme.toLowerCase() != 'https' || base.host.isEmpty) {
      throw StateError('Chat 云端只允许 HTTPS 加密地址');
    }
    // 正式 API 使用同域 `/api` 前缀，不能用 Uri.resolve 丢掉该前缀。
    final root = base.toString().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$root$path');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  Uri _signalUri(String path) {
    final uri = _uri(path);
    return uri.replace(scheme: 'wss');
  }

  Future<Map<String, String>> _headers(
      String method, Uri uri, String body) async {
    final token = sessionToken?.trim() ?? '';
    final headers = <String, String>{
      'authorization': 'Bearer $token',
      'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
    };
    final signer = requestSigner;
    if (signer != null) {
      headers.addAll(await squareRequestHeaders(
        method: method,
        uri: uri,
        body: body,
        sessionToken: token,
        sign: signer,
      ));
    }
    return headers;
  }

  Future<Map<String, String>> _wsHeaders(Uri uri) async {
    final headers = await _headers('GET', uri, '');
    headers['x-chat-device'] = localDeviceId;
    return headers;
  }
}

Map<String, dynamic> _decodeResponse(http.Response response) {
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Cloudflare Chat 响应不是JSON对象', response.body);
  }
  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      decoded['ok'] != true) {
    throw ChatCloudException(
      statusCode: response.statusCode,
      errorCode: (decoded['error_code'] ?? 'chat_request_failed').toString(),
      technicalMessage: (decoded['message'] ?? '').toString(),
    );
  }
  return decoded;
}
