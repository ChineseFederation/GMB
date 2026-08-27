import 'package:flutter/foundation.dart';

/// CitizenServe 会员缓存已经推进的定向事件。
///
/// 事件只通知已挂载页面按永久 [cidNumber] 重读本机统一缓存；它不携带会员档位、
/// 有效态或到期时间，避免各页面复制第二份会员状态。
@immutable
class MembershipRevisionEvent {
  const MembershipRevisionEvent({
    required this.cidNumber,
    required this.revision,
  });

  final String cidNumber;
  final int revision;
}

/// CitizenApp 会员缓存刷新唯一广播器。
///
/// 钱包 revision 只表示钱包／身份绑定变化，不能混入纯会员变化；CitizenServe 快照写入
/// 统一缓存后通过本广播器按 CID 定向刷新页面。网络读取只由会员服务在身份鉴权边界执行。
class MembershipRevision {
  MembershipRevision._();

  static final MembershipRevision instance = MembershipRevision._();

  final ValueNotifier<MembershipRevisionEvent?> listenable =
      ValueNotifier<MembershipRevisionEvent?>(null);

  int _revision = 0;

  void notifyChanged(String cidNumber) {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty) return;
    listenable.value = MembershipRevisionEvent(
      cidNumber: normalized,
      revision: ++_revision,
    );
  }
}
