/// ChatSDK 的加密网络入口配置。
final class ChatConfig {
  ChatConfig({required this.httpsEndpoint, required this.wssEndpoint}) {
    _validate(httpsEndpoint, 'https', 'HTTPS');
    _validate(wssEndpoint, 'wss', 'WSS');
  }

  final Uri httpsEndpoint;
  final Uri wssEndpoint;

  static void _validate(Uri value, String scheme, String label) {
    if (!value.isAbsolute ||
        value.scheme.toLowerCase() != scheme ||
        value.host.isEmpty) {
      throw ArgumentError.value(value, label, '$label 地址必须是包含主机名的绝对地址');
    }
    // 网络入口禁止夹带账户信息，避免凭据进入地址、日志或系统历史。
    if (value.userInfo.isNotEmpty) {
      throw ArgumentError.value(value, label, '$label 地址禁止包含用户名或密码');
    }
    if (value.hasQuery || value.hasFragment) {
      throw ArgumentError.value(value, label, '$label 地址禁止包含查询参数或片段');
    }
  }
}
