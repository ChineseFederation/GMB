/// 宿主应用提供当前用户、设备和短期访问凭证。
abstract interface class ChatIdentity {
  Future<String> accessToken();

  Future<String> currentUserId();

  Future<String> currentDeviceId();
}
