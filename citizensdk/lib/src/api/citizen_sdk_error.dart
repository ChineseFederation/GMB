/// 与 CitizenSDK C ABI v1 一一对应的稳定错误分类。
enum CitizenSdkErrorCode {
  invalidArgument,
  invalidHandle,
  invalidState,
  unsupported,
  unavailable,
  notReady,
  notFound,
  conflict,
  integrity,
  authenticationCancelled,
  authenticationRequired,
  keyInvalidated,
  permissionDenied,
  storage,
  network,
  decode,
  timeout,
  busy,
  queueFull,
  internal,
  panic,
  cancelled,
}

/// 原生 Core、宿主服务或严格 channel 解码返回的稳定异常。
final class CitizenSdkException implements Exception {
  const CitizenSdkException({
    required this.code,
    required this.message,
    this.sessionId,
    this.requestSequence,
  });

  final CitizenSdkErrorCode code;
  final String message;
  final String? sessionId;
  final int? requestSequence;

  @override
  String toString() => 'CitizenSdkException(${code.name}): $message';
}
