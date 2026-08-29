// 公民 Chat 的端到端加密边界模型。
//
// 本文件只定义 Dart 侧可测试的数据边界。真正的 OpenMLS 加解密由
// Rust OpenMLS native 边界实现；这里禁止自研密码学。

export 'mls_session.dart';

import 'mls_session.dart';

/// 本机 Chat 设备身份。
///
/// `cidNumber` 是 Chat 永久身份主键；钱包账户只负责外层会话授权。
/// 私信 HPKE 私钥由本机按 CID/设备隔离的状态钥派生，不通过网络或单独落盘。
class ChatDevice {
  const ChatDevice({
    required this.cidNumber,
    required this.deviceId,
    required this.devicePublicKey,
  });

  /// Chat 与 MLS 唯一成员身份。
  final String cidNumber;

  /// Chat 设备 ID，独立于钱包地址。
  final String deviceId;

  /// Chat 设备身份公钥 hex，不包含私钥。
  final String devicePublicKey;

  /// 校验身份边界，避免把空账户或空公钥写入 Chat 路由记录。
  String? validate() {
    if (cidNumber.trim().isEmpty) {
      return 'Chat CID 不能为空';
    }
    if (deviceId.trim().isEmpty) {
      return 'Chat 设备 ID 不能为空';
    }
    if (devicePublicKey.trim().isEmpty) {
      return 'Chat 设备公钥不能为空';
    }
    final normalized = _stripHexPrefix(devicePublicKey);
    if (normalized.length.isOdd || !_isHex(normalized)) {
      return 'Chat 设备公钥必须是合法 hex';
    }
    return null;
  }
}

/// OpenMLS KeyPackage。
class MlsKeyPackage {
  const MlsKeyPackage({
    required this.cidNumber,
    required this.deviceId,
    required this.keyPackageId,
    required this.keyPackageBytes,
    required this.cipherSuite,
    required this.notBeforeMillis,
    required this.notAfterMillis,
    required this.lastResort,
    this.devicePublicKey = '',
  });

  /// KeyPackage 所属设备所有者的永久身份主键，也是 MLS BasicCredential 身份。
  final String cidNumber;

  /// 发布设备 ID。
  final String deviceId;

  /// OpenMLS 设备签名公钥 hex，用于 Chat 路由记录和安全码展示。
  final String devicePublicKey;

  /// KeyPackage 全局去重 ID。
  final String keyPackageId;

  /// OpenMLS 标准 KeyPackage wire bytes。
  final List<int> keyPackageBytes;

  /// MLS cipher suite。
  final String cipherSuite;

  /// OpenMLS Lifetime 的 not_before，Unix 毫秒。
  final int notBeforeMillis;

  /// OpenMLS Lifetime 的 not_after，Unix 毫秒。
  final int notAfterMillis;

  /// 是否含 RFC 9420 LastResort 扩展；仅供 OpenMLS 群成员加入。
  /// 一对一聊天使用 HPKE 设备公钥，不使用 KeyPackage。
  final bool lastResort;

  /// OpenMLS FFI 使用的 KeyPackage 十六进制编码。
  String get keyPackageHex => _bytesToHex(keyPackageBytes);
}

/// 私信使用设备静态公开加密钥和 RFC 9180 HPKE；群聊继续由 OpenMLS FFI 实现。
///
/// 后续实现必须调用成熟 OpenMLS 库，不允许在 Dart 中自研加密协议。
abstract class MlsCrypto {
  /// 从当前 CID/设备专属的 OpenMLS 加密状态读取设备签名公钥。
  ///
  /// OpenMLS 状态是唯一真源；Dart 偏好值只能作为后台登记的可丢弃缓存，不能参与
  /// 身份一致性判断。该方法不得生成新的 KeyPackage。
  Future<String> readDevicePublicKey(ChatDevice identity);

  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = false,
  });

  Future<MlsOutboundMessage> encrypt({
    required String conversationId,
    required String recipientCidNumber,
    required String recipientDevicePublicKey,
    required List<int> plaintext,
  });

  Future<List<int>> decrypt(MlsWireMessage message);

  Future<MlsInboundMessage> processIncoming(MlsWireMessage message);
}

/// 未注入 OpenMLS native 实现时的显式占位。
class UnsupportedMlsCrypto implements MlsCrypto {
  const UnsupportedMlsCrypto();

  @override
  Future<String> readDevicePublicKey(ChatDevice identity) async {
    throw UnimplementedError('OpenMLS native 实现未注入');
  }

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = false,
  }) async {
    throw UnimplementedError('OpenMLS native 实现未注入');
  }

  @override
  Future<MlsOutboundMessage> encrypt({
    required String conversationId,
    required String recipientCidNumber,
    required String recipientDevicePublicKey,
    required List<int> plaintext,
  }) async {
    throw UnimplementedError('OpenMLS native 实现未注入');
  }

  @override
  Future<List<int>> decrypt(MlsWireMessage message) async {
    throw UnimplementedError('OpenMLS native 实现未注入');
  }

  @override
  Future<MlsInboundMessage> processIncoming(MlsWireMessage message) async {
    throw UnimplementedError('OpenMLS native 实现未注入');
  }
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String _stripHexPrefix(String value) {
  return value.startsWith('0x') ? value.substring(2) : value;
}

bool _isHex(String value) {
  return RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
}
