import 'package:citizenapp/qr/envelope.dart';
import 'package:citizenapp/qr/generated/qr_bodies.g.dart';

/// k = 5 账户码(**固定码**,envelope 顶层无 id / expires_at)。
///
/// 语义 = 「这是**哪个账户**」。**钱包没有码,账户才有码** —— 一个钱包由多个账户组成,
/// 二维码描述的始终是其中某一个账户。冷热两端都能生成。
///
/// body 只有一个单字母键:
///
/// - `n` = `account_id` 账户标识(`0x` 小写 64 位 hex)
///
/// **不得携带账户名、昵称、CID、SS58 或任何时效字段**:本机账户标签用户可随意改写、
/// 无任何链上或服务端约束,一旦进入二维码就会被扫码端当成对方公开身份显示。
/// 展示用 SS58 由扫码端从 `n` 自行派生。
///
/// 与 `citizenwallet/lib/qr/bodies/account_id_code_body.dart` 逐字节一致。
class AccountIdCodeBody implements QrBody {
  const AccountIdCodeBody({required this.accountId});

  /// 小写 `0x` 加 64 位十六进制,即 sr25519 公钥原字节。
  final String accountId;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'n': accountId};

  static AccountIdCodeBody fromJson(Map<String, dynamic> data) {
    GeneratedQrBodySchema.validateBody(QrKind.accountIdCode.code, data);
    return AccountIdCodeBody(accountId: data['n'] as String);
  }
}
