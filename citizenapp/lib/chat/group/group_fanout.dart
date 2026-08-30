// CitizenApp 只把 CID 产品字段映射为 ChatSDK user_id；群密文扇出算法只在 SDK。

import 'package:chat_sdk/chat_sdk.dart' as sdk;

/// 公民产品的群聊扇出适配，不复制信封 ID 或协议逻辑。
final class GroupFanout {
  GroupFanout._();

  static List<sdk.ChatEnvelope> fanOut({
    required sdk.MlsWireMessage wire,
    required List<String> recipientCidNumbers,
    required String senderCidNumber,
    required String senderDeviceId,
    required int nowMillis,
    required int ttlMillis,
  }) =>
      sdk.GroupBasicFanout.fanOut(
        wire: wire,
        recipientUserIds: recipientCidNumbers,
        senderUserId: senderCidNumber,
        senderDeviceId: senderDeviceId,
        createdAtMillis: nowMillis,
        ttlMillis: ttlMillis,
      );
}
