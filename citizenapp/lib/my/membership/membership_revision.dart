import 'package:flutter/foundation.dart';

/// 已由 Worker 确认推进的会员镜像事件。
///
/// 事件只通知已挂载页面按永久 [cidNumber] 重读 Worker；它不携带会员档位、有效态或
/// 到期时间，更不能作为展示或授权真源。
@immutable
class MembershipRevisionEvent {
  const MembershipRevisionEvent({
    required this.cidNumber,
    required this.revision,
  });

  final String cidNumber;
  final int revision;
}

/// CitizenApp 会员镜像刷新唯一广播器。
///
/// 钱包 revision 只表示钱包／身份绑定变化，不能混入纯会员变化；因此会员确认成功后
/// 通过本广播器按 CID 定向失效页面数据。页面收到事件后仍须重新读取 Worker，禁止直接
/// 从事件推导会员权益。
class MembershipRevision {
  MembershipRevision._();

  static final MembershipRevision instance = MembershipRevision._();

  final ValueNotifier<MembershipRevisionEvent?> listenable =
      ValueNotifier<MembershipRevisionEvent?>(null);

  int _revision = 0;

  void notifyConfirmed(String cidNumber) {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty) return;
    listenable.value = MembershipRevisionEvent(
      cidNumber: normalized,
      revision: ++_revision,
    );
  }
}
