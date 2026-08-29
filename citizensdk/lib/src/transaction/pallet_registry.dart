/// CitizenSDK 当前公开交易所需的公民链 pallet/call ABI。
///
/// 其它治理、身份、广场和聊天相关 pallet 不属于基础钱包转账接口，不在这里复制。
final class PalletRegistry {
  const PalletRegistry._();

  static const int balancesPallet = 2;
  static const int onchainTransactionPallet = 4;
  static const int transferWithRemarkCall = 0;
}
