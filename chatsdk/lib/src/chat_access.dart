/// ChatSDK 对外公开的四类聊天能力。
enum ChatCapability { message, attachment, call, extension }

/// 当前用户可使用的聊天能力快照，不绑定任何产品的会员名称。
final class ChatCapabilities {
  ChatCapabilities(Iterable<ChatCapability> enabled)
    : enabled = Set<ChatCapability>.unmodifiable(enabled);

  final Set<ChatCapability> enabled;

  bool allows(ChatCapability capability) => enabled.contains(capability);
}

/// 宿主应用提供权限真源，ChatSDK 只消费最终能力快照。
abstract interface class ChatAccess {
  Future<ChatCapabilities> capabilities();
}
