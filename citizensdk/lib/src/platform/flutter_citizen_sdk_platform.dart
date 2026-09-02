import 'package:flutter/services.dart';

import '../api/citizen_sdk_error.dart';
import 'citizen_sdk_flutter_codec.dart';
import 'citizen_sdk_platform.dart';

/// Android、iOS 与 macOS 官方 binding 共用的唯一 Flutter transport。
///
/// 三个平台必须实现完全相同的 22 个 MethodChannel tuple 方法与同一
/// EventChannel 事件合同。transport 不携带平台分支、Map、秘密或原生句柄。
final class FlutterCitizenSdkPlatform implements CitizenSdkPlatform {
  FlutterCitizenSdkPlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    CitizenSdkFlutterCodec codec = const CitizenSdkFlutterCodec(),
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('citizen/sdk/core/v1'),
       _eventChannel =
           eventChannel ?? const EventChannel('citizen/sdk/events/v1'),
       _codec = codec;

  static const String methodChannelName = 'citizen/sdk/core/v1';
  static const String eventChannelName = 'citizen/sdk/events/v1';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final CitizenSdkFlutterCodec _codec;

  late final Stream<Object?> _events = _eventChannel.receiveBroadcastStream(
    const <Object?>[1],
  ).cast<Object?>();

  @override
  Stream<Object?> get events => _events;

  @override
  Future<Object?> invoke(String method, List<Object?> arguments) async {
    try {
      return await _methodChannel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      throw _codec.decodePlatformException(error);
    } on MissingPluginException catch (error) {
      throw CitizenSdkException(
        code: CitizenSdkErrorCode.unsupported,
        message: error.message ?? 'CitizenSDK Flutter binding 未安装',
      );
    }
  }
}
