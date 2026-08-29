/// CitizenSDK 内部日志等级。
enum CitizenSdkLogLevel { debug, info, warning, error }

/// 不包含助记词、私钥、child mini-secret 或签名载荷的诊断事件。
final class CitizenSdkLogEvent {
  const CitizenSdkLogEvent({
    required this.level,
    required this.scope,
    required this.message,
    this.error,
  });

  final CitizenSdkLogLevel level;
  final String scope;
  final String message;
  final Object? error;
}

typedef CitizenSdkLogger = void Function(CitizenSdkLogEvent event);

void discardCitizenSdkLog(CitizenSdkLogEvent _) {}
