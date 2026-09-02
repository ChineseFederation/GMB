/// CitizenSDK 实例的稳定生命周期。
enum CitizenSdkLifecycle {
  created,
  importingState,
  starting,
  running,
  startFailed,
  stopped,
  disposed,
}

enum CitizenBlockFinality { best, finalized }

/// 已由 Core 验证的块引用。
final class CitizenBlockRef {
  const CitizenBlockRef({
    required this.hash,
    required this.number,
    required this.finality,
  });

  final String hash;
  final BigInt number;
  final CitizenBlockFinality finality;
}

/// finalized 块上的账户余额，单位均为整数分。
final class CitizenAccountBalance {
  const CitizenAccountBalance({
    required this.accountId,
    required this.block,
    required this.freeFen,
    required this.reservedFen,
    required this.totalFen,
  });

  final String accountId;
  final CitizenBlockRef block;
  final BigInt freeFen;
  final BigInt reservedFen;
  final BigInt totalFen;
}

/// best 块 Runtime 的精确账户 nonce；它不是交易池 nonce 租约。
final class CitizenAccountNonce {
  const CitizenAccountNonce({
    required this.accountId,
    required this.bestBlock,
    required this.nonce,
  });

  final String accountId;
  final CitizenBlockRef bestBlock;
  final BigInt nonce;
}

/// 同一 best 块读取的链上费率、最低费用和存续金额。
final class CitizenFeeSnapshot {
  const CitizenFeeSnapshot({
    required this.bestBlock,
    required this.feeRateParts,
    required this.minimumFeeFen,
    required this.existentialDepositFen,
  });

  final CitizenBlockRef bestBlock;
  final int feeRateParts;
  final BigInt minimumFeeFen;
  final BigInt existentialDepositFen;
}
