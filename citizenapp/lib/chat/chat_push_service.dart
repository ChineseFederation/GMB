import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wakeSendersKey = 'chat.push.wake_senders';
// Firebase 客户端标识属于公开应用配置，不是服务端授权凭据。Android 与 iOS 必须使用
// Firebase 为各自应用登记的独立 Key 与 App ID；当前只有一套正式项目，禁止构建参数覆盖、
// 跨平台回退或恢复历史 Bundle ID / package name 对应值。
const _firebaseAndroidApiKey = 'AIzaSyBfXLIwqGoOX_h75MxZYcorJncT3uSZrm4';
const _firebaseIosApiKey = 'AIzaSyBIVrjuAzf_TguwS88lf50PTeYXYlxTocU';
const _firebaseProjectId = 'citizenapp-23542';
const _firebaseSenderId = '124593150477';
const _firebaseAndroidAppId =
    '1:124593150477:android:436c372ca4779924ba1344';
const _firebaseIosAppId = '1:124593150477:ios:dcff6e612fb28795ba1344';

FirebaseOptions _firebaseOptions() {
  final apiKey = Platform.isIOS ? _firebaseIosApiKey : _firebaseAndroidApiKey;
  final appId = Platform.isIOS ? _firebaseIosAppId : _firebaseAndroidAppId;
  if (apiKey.isEmpty ||
      _firebaseProjectId.isEmpty ||
      _firebaseSenderId.isEmpty ||
      appId.isEmpty) {
    throw StateError('Chat 推送缺少 Firebase 构建参数');
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: _firebaseSenderId,
    projectId: _firebaseProjectId,
    iosBundleId: Platform.isIOS ? 'ios.citizenapp' : null,
  );
}

Future<void> ensureChatFirebaseReady() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: _firebaseOptions());
  }
}

class ChatPushToken {
  const ChatPushToken({
    required this.provider,
    required this.token,
    required this.apnsEnvironment,
  });

  final String provider;
  final String token;
  // 只有 APNs Token 携带签名环境；FCM 没有 sandbox/production 二分，固定为空。
  final String? apnsEnvironment;

  /// 本地只缓存登记输入摘要，不把 Token 是否仍在 Worker 当作权威状态。
  String get registrationCacheValue =>
      '$provider|${apnsEnvironment ?? ''}|$token';
}

/// iOS 原生侧已把签名包配置的 development/production 映射为这两个值。
/// Dart 再做一次严格校验，避免 MethodChannel 被错误实现或测试替身注入未知环境。
String requireApnsEnvironment(String? value) {
  if (value == 'sandbox' || value == 'production') return value!;
  throw StateError('iOS 应用签名缺少有效 APNs 环境');
}

/// 平台推送只负责唤醒本地重试，不承载消息、会话或附件内容。
class ChatPushService {
  ChatPushService({MethodChannel? permissionsChannel})
      : _permissionsChannel =
            permissionsChannel ?? const MethodChannel('citizenapp/permissions');

  final MethodChannel _permissionsChannel;

  final StreamController<String> _wakeController =
      StreamController<String>.broadcast();
  final StreamController<ChatPushToken> _tokenController =
      StreamController<ChatPushToken>.broadcast();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Stream<String> get wakeSenders => _wakeController.stream;
  Stream<ChatPushToken> get tokenChanges => _tokenController.stream;

  Future<ChatPushToken> initialize() async {
    final token = await readToken(requestPermission: true);
    _messageSubscription ??= FirebaseMessaging.onMessage.listen(_handleMessage);
    _tokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      _,
    ) async {
      try {
        _tokenController.add(await readToken(requestPermission: false));
      } catch (_) {
        // Token 刷新读取失败时等待下一次平台回调或 Chat 初始化重试。
      }
    });
    return token;
  }

  /// 后台唤醒只读取已有平台 Token，不触发权限弹窗或前台消息订阅。
  Future<ChatPushToken> readToken({required bool requestPermission}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Chat 推送只支持 Android 和 iOS');
    }
    await ensureChatFirebaseReady();
    final messaging = FirebaseMessaging.instance;
    if (requestPermission) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }

    if (Platform.isIOS) {
      final token = await messaging.getAPNSToken();
      if (token == null || token.isEmpty) {
        throw StateError('APNs Token 尚未生成');
      }
      final environment = requireApnsEnvironment(
        await _permissionsChannel.invokeMethod<String>('getApnsEnvironment'),
      );
      return ChatPushToken(
        provider: 'apns',
        token: token,
        apnsEnvironment: environment,
      );
    }
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('FCM Token 尚未生成');
    }
    return ChatPushToken(provider: 'fcm', token: token, apnsEnvironment: null);
  }

  static Future<void> storeWakeSender(String sender) async {
    final prefs = await SharedPreferences.getInstance();
    final senders = prefs.getStringList(_wakeSendersKey) ?? <String>[];
    if (!senders.contains(sender)) senders.add(sender);
    await prefs.setStringList(_wakeSendersKey, senders);
  }

  Future<List<String>> takePendingWakeSenders() async {
    final prefs = await SharedPreferences.getInstance();
    final senders = prefs.getStringList(_wakeSendersKey) ?? const <String>[];
    await prefs.remove(_wakeSendersKey);
    return List<String>.unmodifiable(senders);
  }

  void _handleMessage(RemoteMessage message) {
    final sender = wakeSenderFromData(message.data);
    if (sender != null) _wakeController.add(sender);
  }

  /// 推送正文只能识别无内容唤醒，不接受消息或附件字段。
  ///
  /// 唤醒发件人以身份主键 CID 号（`sender_cid_number`）标识，与 Worker R5 对齐；
  /// 下游 peer_ready / 补发一律按 CID 语义寻址。
  static String? wakeSenderFromData(Map<String, dynamic> data) {
    if (data['kind'] != 'chat_wake' || data.length != 2) return null;
    final sender = data['sender_cid_number'];
    return sender is String && sender.isNotEmpty ? sender : null;
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _wakeController.close();
    await _tokenController.close();
  }
}
