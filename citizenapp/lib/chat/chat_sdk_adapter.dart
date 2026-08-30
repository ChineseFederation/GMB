import 'package:chat_sdk/chat_sdk.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';

/// Maps CitizenServe's product error contract without leaking it into ChatSDK.
String chatUserErrorMessage(
  Object error, {
  String fallback = '聊天暂时无法使用，请稍后重试',
}) {
  if (error is SquareApiException) {
    return switch (error.errorCode) {
      'cid_not_bound' => '当前默认账户尚未注册公民号，无法使用聊天',
      'device_not_registered' ||
      'chat_device_not_registered' ||
      'invalid_signature' =>
        '聊天设备身份尚未就绪，请重试',
      'cid_binding_changed' => '当前登录用户已切换，请重新进入聊天',
      'missing_session' ||
      'invalid_session' ||
      'session_expired' =>
        '聊天会话已失效，请重试',
      _ => error.statusCode == null || error.statusCode! >= 500
          ? '聊天服务暂时无法连接，请稍后重试'
          : fallback,
    };
  }
  return chatSdkUserErrorMessage(error, fallback: fallback);
}

/// CitizenApp's product boundary for ChatSDK's deployment-neutral identities.
///
/// A citizen number is passed to ChatSDK as `userId`. These extensions keep the
/// CitizenApp domain vocabulary outside the reusable SDK while avoiding a
/// second protocol or cryptographic implementation.
extension CitizenChatEnvelopeFields on ChatEnvelope {
  String get senderCidNumber => senderUserId;
  set senderCidNumber(String value) => senderUserId = value;

  String get recipientCidNumber => recipientUserId;
  set recipientCidNumber(String value) => recipientUserId = value;

  List<int> get mlsWireMessage => mlsMessage;
  set mlsWireMessage(List<int> value) => mlsMessage = value;
}

extension CitizenChatRouteFields on ChatRoute {
  String get peerCidNumber => peerUserId;
  set peerCidNumber(String value) => peerUserId = value;
}

extension CitizenChatDeviceFields on ChatDevice {
  String get cidNumber => userId;
}

extension CitizenMlsKeyPackageFields on MlsKeyPackage {
  String get cidNumber => userId;
}

extension CitizenMlsStateStoreFields on MlsStateStore {
  String get ownerCidNumber => ownerUserId;
}

extension CitizenGroupCommitFields on GroupCommitBundle {
  List<String> get removedCidNumbers => removedUserIds;
}

String cidNumberFromMemberIdentity(String identity) =>
    userIdFromMemberIdentity(identity);

List<String> cidNumbersFromMemberIdentities(
  Iterable<String> identities, {
  String? excludeCidNumber,
}) =>
    userIdsFromMemberIdentities(
      identities,
      excludeUserId: excludeCidNumber,
    );
