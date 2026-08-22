/// 钱包账户签名模式。
///
/// 只有 [hot] 与 [cold] 两种合法值。持久化或边界输入无法精确解析时返回 `null`，
/// 调用方必须拒绝当前操作，不能把非法值默认归入任一签名路径。
enum SignMode {
  /// 私钥由当前联网设备保存，必须在本机完成签名。
  hot,

  /// 当前联网设备不保存私钥，必须交由离线 CitizenWallet 扫码签名。
  cold;

  /// 严格解析持久化值；不兼容任何旧值、别名或大小写变体。
  static SignMode? tryParse(String value) => switch (value) {
        'hot' => SignMode.hot,
        'cold' => SignMode.cold,
        _ => null,
      };
}
