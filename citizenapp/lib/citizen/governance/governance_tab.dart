import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:citizenapp/citizen/institution/institution.dart';
import 'package:citizenapp/citizen/institution/institution_classification.dart';
import 'package:citizenapp/citizen/institution/institution_detail_page.dart';
import 'package:citizenapp/citizen/institution/institution_repository.dart';
import 'package:citizenapp/citizen/shared/institution_info.dart' show OrgType;
import 'package:citizenapp/citizen/shared/proposal/proposal_context.dart';
import 'package:citizenapp/citizen/governance/whitepaper_page.dart';
import 'package:citizenapp/isar/user_isar.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/page_transitions.dart';
import 'package:citizenapp/ui/widgets/pressable_card.dart';
import 'package:citizenapp/ui/app_layout.dart';

const String _governanceProvincialCouncilIconAsset =
    'assets/icons/government-line.svg';
const String _governanceProvincialBankIconAsset = 'assets/icons/bank.svg';

@visibleForTesting
List<Institution> applyGovernanceInstitutionOrder(
  List<Institution> source,
  List<String>? savedOrder,
) {
  final byId = <String, Institution>{
    for (final institution in source) institution.cidNumber: institution,
  };
  final ordered = <Institution>[];
  final used = <String>{};

  if (savedOrder != null) {
    for (final cidNumber in savedOrder) {
      final institution = byId[cidNumber];
      if (institution != null && used.add(cidNumber)) {
        ordered.add(institution);
      }
    }
  }

  // 静态注册表未来若有新增机构，本机旧顺序里没有的项必须补回末尾。
  for (final institution in source) {
    if (used.add(institution.cidNumber)) {
      ordered.add(institution);
    }
  }
  return ordered;
}

@visibleForTesting
List<Institution> reorderGovernanceInstitutions(
  List<Institution> source,
  int fromIndex,
  int toIndex,
) {
  if (fromIndex < 0 ||
      fromIndex >= source.length ||
      toIndex < 0 ||
      toIndex >= source.length ||
      fromIndex == toIndex) {
    return List<Institution>.of(source);
  }
  final next = List<Institution>.of(source);
  final item = next.removeAt(fromIndex);
  next.insert(toIndex.clamp(0, next.length), item);
  return next;
}

enum _GovernanceSectionKind {
  provincialCouncil,
  provincialBank,
}

class _GovernanceDragData {
  const _GovernanceDragData({
    required this.sectionKind,
    required this.index,
  });

  final _GovernanceSectionKind sectionKind;
  final int index;
}

/// 用户自定义的治理机构展示顺序。
class GovernanceInstitutionOrder {
  const GovernanceInstitutionOrder({
    this.provincialCouncilCidNumbers = const <String>[],
    this.provincialBankCidNumbers = const <String>[],
  });

  final List<String> provincialCouncilCidNumbers;
  final List<String> provincialBankCidNumbers;
}

/// 治理页的 UserIsar 顺序仓库。
///
/// 页面只依赖这个窄接口；钱包事实、机构目录和链上权限都不得写入
/// UserIsar。
class GovernanceInstitutionOrderStore {
  const GovernanceInstitutionOrderStore();

  Future<GovernanceInstitutionOrder> read() async {
    final settings = await UserIsar.instance.read(
      (isar) async => isar.userSettingsEntitys.get(0),
    );
    return GovernanceInstitutionOrder(
      provincialCouncilCidNumbers:
          settings?.governanceProvincialCouncilOrder ?? const <String>[],
      provincialBankCidNumbers:
          settings?.governanceProvincialBankOrder ?? const <String>[],
    );
  }

  Future<void> writeProvincialCouncilCidNumbers(List<String> cidNumbers) {
    return _write(cidNumbers, isCouncil: true);
  }

  Future<void> writeProvincialBankCidNumbers(List<String> cidNumbers) {
    return _write(cidNumbers, isCouncil: false);
  }

  Future<void> _write(
    List<String> cidNumbers, {
    required bool isCouncil,
  }) {
    return UserIsar.instance.writeTxn((isar) async {
      final settings =
          await isar.userSettingsEntitys.get(0) ?? UserSettingsEntity();
      settings
        ..id = 0
        ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      if (isCouncil) {
        settings.governanceProvincialCouncilOrder = cidNumbers;
      } else {
        settings.governanceProvincialBankOrder = cidNumbers;
      }
      await isar.userSettingsEntitys.put(settings);
    });
  }
}

/// 治理 tab 视图(ADR-028 P2)：从统一目录按机构码过滤治理类机构(国家储委会/省储委会/
/// 省储行),分类展示 + 拖拽排序;详情入口走统一机构详情页。替代旧 GovernanceListPage
/// 静态烘焙注册表「列表」承载。
///
/// 提案发起与投票事件仍由机构详情页承接。
class GovernanceTab extends StatefulWidget {
  const GovernanceTab({
    super.key,
    this.repository,
    this.orderStore,
    this.whitepaperPageBuilder,
  });

  /// 统一机构仓库门面(测试注入;默认 [InstitutionRepository])。
  final InstitutionRepository? repository;

  /// 用户本机顺序仓库；生产默认使用 [GovernanceInstitutionOrderStore]。
  final GovernanceInstitutionOrderStore? orderStore;

  /// 白皮书阅读页注入点；生产固定使用官网唯一真源阅读页，
  /// 测试以轻量页面验证路由，避免启动平台 WebView。
  final WidgetBuilder? whitepaperPageBuilder;

  @override
  State<GovernanceTab> createState() => _GovernanceTabState();
}

class _GovernanceTabState extends State<GovernanceTab> {
  late final InstitutionRepository _repo =
      widget.repository ?? InstitutionRepository();
  late final GovernanceInstitutionOrderStore _orderStore =
      widget.orderStore ?? const GovernanceInstitutionOrderStore();

  /// 治理 tab 机构码集合(储备治理三档)。
  static const Set<String> _governanceCodes = kGovernanceCodes;

  List<Institution> _national = const [];
  List<Institution> _provincialCouncils = const [];
  List<Institution> _provincialBanks = const [];
  bool _loading = true;
  String? _loadError;
  _GovernanceSectionKind? _expandedSection =
      _GovernanceSectionKind.provincialCouncil;
  final ScrollController _institutionScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadInstitutions());
  }

  @override
  void dispose() {
    _institutionScrollController.dispose();
    super.dispose();
  }

  /// 从统一目录按机构码取治理机构,按 orgType 分三组,再叠加本机保存的拖拽顺序。
  Future<void> _loadInstitutions() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final all = await _repo.listByCodes(_governanceCodes);
      final national =
          all.where((i) => i.orgType == OrgType.nrc).toList(growable: false);
      final councilsRaw =
          all.where((i) => i.orgType == OrgType.prc).toList(growable: false);
      final banksRaw =
          all.where((i) => i.orgType == OrgType.prb).toList(growable: false);
      final order = await _orderStore.read();
      final councils = applyGovernanceInstitutionOrder(
        councilsRaw,
        order.provincialCouncilCidNumbers,
      );
      final banks = applyGovernanceInstitutionOrder(
        banksRaw,
        order.provincialBankCidNumbers,
      );
      if (!mounted) return;
      setState(() {
        _national = national;
        _provincialCouncils = councils;
        _provincialBanks = banks;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '治理机构读取失败，请重试';
      });
    }
  }

  Future<void> _reorderInstitution(
    _GovernanceSectionKind sectionKind,
    int fromIndex,
    int toIndex,
  ) async {
    late final List<Institution> next;
    setState(() {
      if (sectionKind == _GovernanceSectionKind.provincialCouncil) {
        next = reorderGovernanceInstitutions(
          _provincialCouncils,
          fromIndex,
          toIndex,
        );
        _provincialCouncils = next;
      } else {
        next = reorderGovernanceInstitutions(
          _provincialBanks,
          fromIndex,
          toIndex,
        );
        _provincialBanks = next;
      }
    });

    try {
      final orderedCidNumbers =
          next.map((institution) => institution.cidNumber).toList();
      if (sectionKind == _GovernanceSectionKind.provincialCouncil) {
        await _orderStore.writeProvincialCouncilCidNumbers(orderedCidNumbers);
      } else {
        await _orderStore.writeProvincialBankCidNumbers(orderedCidNumbers);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存治理机构顺序失败：$e')),
      );
    }
  }

  void _openWhitepaper() {
    final page = widget.whitepaperPageBuilder?.call(context) ??
        const CitizenWhitepaperPage();
    Navigator.of(context).push(FadeSlideRoute<void>(page: page));
  }

  void _toggleSection(_GovernanceSectionKind sectionKind) {
    if (_institutionScrollController.hasClients) {
      _institutionScrollController.jumpTo(0);
    }
    setState(() {
      // 省储委会与省储行共用一个展开状态，结构上禁止两个分类同时展开。
      _expandedSection = _expandedSection == sectionKind ? null : sectionKind;
    });
  }

  Widget _sectionHeader(_GovernanceSectionKind sectionKind) {
    final isCouncil = sectionKind == _GovernanceSectionKind.provincialCouncil;
    return _GovernanceSectionHeader(
      sectionKind: sectionKind,
      title: isCouncil ? '省储委会' : '省储行',
      icon: isCouncil
          ? Icons.groups_2_outlined
          : Icons.account_balance_wallet_outlined,
      iconAsset: isCouncil
          ? _governanceProvincialCouncilIconAsset
          : _governanceProvincialBankIconAsset,
      badgeColor: isCouncil ? AppTheme.primary : AppTheme.accent,
      institutionCount:
          isCouncil ? _provincialCouncils.length : _provincialBanks.length,
      expanded: _expandedSection == sectionKind,
      onToggleExpanded: () => _toggleSection(sectionKind),
    );
  }

  Widget _expandedInstitutionGrid() {
    final sectionKind = _expandedSection;
    if (sectionKind == null) return const SizedBox.shrink();
    final isCouncil = sectionKind == _GovernanceSectionKind.provincialCouncil;
    return _GovernanceInstitutionGrid(
      sectionKind: sectionKind,
      icon: isCouncil
          ? Icons.groups_2_outlined
          : Icons.account_balance_wallet_outlined,
      badgeColor: isCouncil ? AppTheme.primary : AppTheme.accent,
      institutions: isCouncil ? _provincialCouncils : _provincialBanks,
      onReorder: (fromIndex, toIndex) =>
          _reorderInstitution(sectionKind, fromIndex, toIndex),
      onReturnFromDetail: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 顶部双卡和两个分类标题固定，唯一滚动区只承载当前展开分类的卡片。
    // 页面结构先于本地目录读取出现，避免公民二级导航切换时只剩整页转圈。
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            AppLayout.citizenSubtabFirstRowTopInset,
            16,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 白皮书与国家储委会固定为等宽等高双列，异步读取期间也不改变首屏结构。
              SizedBox(
                height: AppLayout.scaled(
                  context,
                  AppLayout.citizenSubtabFirstRowHeight,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _whitepaperCard()),
                    SizedBox(width: AppLayout.scaled(context, 8)),
                    Expanded(child: _nationalCouncilCard()),
                  ],
                ),
              ),
              if (_loading) ...[
                SizedBox(height: AppLayout.scaled(context, 8)),
                const Text(
                  '正在读取治理机构',
                  style: TextStyle(color: AppTheme.textTertiary),
                ),
              ] else if (_loadError != null) ...[
                SizedBox(height: AppLayout.scaled(context, 8)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _loadError!,
                        style: const TextStyle(color: AppTheme.textTertiary),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadInstitutions,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ],
              SizedBox(height: AppLayout.scaled(context, 20)),
              _sectionHeader(_GovernanceSectionKind.provincialCouncil),
              if (_expandedSection !=
                  _GovernanceSectionKind.provincialCouncil) ...[
                SizedBox(height: AppLayout.scaled(context, 8)),
                _sectionHeader(_GovernanceSectionKind.provincialBank),
              ],
              SizedBox(height: AppLayout.scaled(context, 8)),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('governance-institution-scroll-view'),
                  controller: _institutionScrollController,
                  padding: EdgeInsets.only(
                    bottom: AppLayout.scaled(context, 24),
                  ),
                  child: _expandedInstitutionGrid(),
                ),
              ),
              if (_expandedSection ==
                  _GovernanceSectionKind.provincialCouncil) ...[
                SizedBox(height: AppLayout.scaled(context, 8)),
                _sectionHeader(_GovernanceSectionKind.provincialBank),
              ],
              SizedBox(height: AppLayout.scaled(context, 10)),
            ],
          ),
        ),
        if (_loading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              key: const ValueKey('governance-load-progress'),
              minHeight: AppLayout.scaled(context, 2),
            ),
          ),
      ],
    );
  }

  Widget _whitepaperCard() {
    return InkWell(
      onTap: _openWhitepaper,
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
      child: Container(
        key: const ValueKey<String>('citizen-whitepaper-card'),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
          border:
              Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.22)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(10),
        ),
        child: Row(
          children: [
            Container(
              width: AppLayout.scaledValue(30),
              height: AppLayout.scaledValue(30),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
              ),
              child: Icon(
                Icons.menu_book,
                size: AppLayout.scaledValue(17),
                color: const Color(0xFF0F6E56),
              ),
            ),
            SizedBox(width: AppLayout.scaled(context, 8)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '《公民链白皮书》',
                  key: const ValueKey<String>('citizen-whitepaper-title'),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(14),
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: AppLayout.scaledValue(18),
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _nationalCouncilCard() {
    final institution = _national.isEmpty ? null : _national.first;
    final enabled = institution != null;
    final isAdmin = institution != null &&
        ProposalContextResolver.isInstitutionAdmin(institution.cidNumber);
    final card = Container(
      key: institution == null
          ? const ValueKey('governance_national_card_placeholder')
          : ValueKey('governance_national_card_${institution.cidNumber}'),
      decoration: AppTheme.cardDecoration(selected: isAdmin),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: institution == null
              ? null
              : () async {
                  await Navigator.of(context).push(
                    FadeSlideRoute(
                      page: InstitutionDetailPage(
                        cidNumber: institution.cidNumber,
                        repository: InstitutionRepository(),
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaled(context, 10),
            ),
            child: Row(
              children: [
                _GovernanceIconBadge(
                  icon: Icons.account_balance,
                  color: enabled ? AppTheme.primaryDark : AppTheme.textTertiary,
                  boxSize: AppLayout.scaled(context, 30),
                  iconSize: AppLayout.scaled(context, 16),
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                Expanded(
                  child: Text(
                    institution?.cidShortNameOrFullName ?? '国家储委会',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 13),
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppLayout.scaled(context, 18),
                  color: AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return enabled ? PressableCard(child: card) : card;
  }
}

class _GovernanceSectionHeader extends StatelessWidget {
  const _GovernanceSectionHeader({
    required this.sectionKind,
    required this.title,
    required this.icon,
    required this.badgeColor,
    required this.institutionCount,
    required this.expanded,
    required this.onToggleExpanded,
    this.iconAsset,
  });

  final _GovernanceSectionKind sectionKind;
  final String title;
  final IconData icon;
  final String? iconAsset;
  final Color badgeColor;
  final int institutionCount;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GovernanceIconBadge(
          icon: icon,
          iconAsset: iconAsset,
          color: badgeColor,
          boxSize: 28,
          iconSize: AppLayout.scaled(context, 16),
        ),
        SizedBox(width: AppLayout.scaled(context, 10)),
        Text(
          '$title（$institutionCount）',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 16),
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        IconButton(
          key: ValueKey('governance_section_toggle_${sectionKind.name}'),
          tooltip: expanded ? '折叠$title' : '展开$title',
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints.tightFor(
            width: AppLayout.scaled(context, 32),
            height: AppLayout.scaled(context, 32),
          ),
          onPressed: onToggleExpanded,
          icon: Icon(
            expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
            size: AppLayout.scaled(context, 24),
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GovernanceInstitutionGrid extends StatelessWidget {
  const _GovernanceInstitutionGrid({
    required this.sectionKind,
    required this.icon,
    required this.badgeColor,
    required this.institutions,
    required this.onReorder,
    required this.onReturnFromDetail,
  });

  final _GovernanceSectionKind sectionKind;
  final IconData icon;
  final Color badgeColor;
  final List<Institution> institutions;
  final Future<void> Function(int fromIndex, int toIndex) onReorder;
  final VoidCallback onReturnFromDetail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) return const SizedBox.shrink();
        const crossAxisCount = 2;
        const crossAxisSpacing = 8.0;
        final childAspectRatio = constraints.maxWidth < 360 ? 2.6 : 2.9;
        // 网格自身不滚动，由治理页唯一滚动区承载当前展开分类的卡片。
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: institutions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppLayout.scaled(context, 8),
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final inst = institutions[index];
            final isAdmin = ProposalContextResolver.isInstitutionAdmin(
              inst.cidNumber,
            );
            final card = _GovernanceCard(
              institution: inst,
              icon: icon,
              badgeColor: badgeColor,
              isAdmin: isAdmin,
              pressAnimationEnabled: false,
              onReturnFromDetail: onReturnFromDetail,
            );
            return _GovernanceReorderableCard(
              sectionKind: sectionKind,
              index: index,
              institution: inst,
              icon: icon,
              badgeColor: badgeColor,
              isAdmin: isAdmin,
              onReturnFromDetail: onReturnFromDetail,
              onReorder: onReorder,
              child: card,
            );
          },
        );
      },
    );
  }
}

class _GovernanceReorderableCard extends StatelessWidget {
  const _GovernanceReorderableCard({
    required this.sectionKind,
    required this.index,
    required this.institution,
    required this.icon,
    required this.badgeColor,
    required this.isAdmin,
    required this.onReorder,
    required this.child,
    this.onReturnFromDetail,
  });

  final _GovernanceSectionKind sectionKind;
  final int index;
  final Institution institution;
  final IconData icon;
  final Color badgeColor;
  final bool isAdmin;
  final Future<void> Function(int fromIndex, int toIndex) onReorder;
  final Widget child;
  final VoidCallback? onReturnFromDetail;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_GovernanceDragData>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        return data.sectionKind == sectionKind && data.index != index;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        unawaited(onReorder(data.index, index));
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: highlighted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: badgeColor, width: 1.5),
                )
              : null,
          child: LongPressDraggable<_GovernanceDragData>(
            data: _GovernanceDragData(
              sectionKind: sectionKind,
              index: index,
            ),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: AppLayout.scaled(context, 190),
                height: AppLayout.scaled(context, 64),
                child: Opacity(
                  opacity: 0.92,
                  child: _GovernanceCard(
                    institution: institution,
                    icon: icon,
                    badgeColor: badgeColor,
                    isAdmin: isAdmin,
                    navigationEnabled: false,
                    pressAnimationEnabled: false,
                    onReturnFromDetail: onReturnFromDetail,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: child),
            child: child,
          ),
        );
      },
    );
  }
}

class _GovernanceCard extends StatelessWidget {
  const _GovernanceCard({
    required this.institution,
    required this.icon,
    required this.badgeColor,
    this.isAdmin = false,
    this.navigationEnabled = true,
    this.pressAnimationEnabled = true,
    this.onReturnFromDetail,
  });

  final Institution institution;
  final IconData icon;
  final Color badgeColor;
  final bool isAdmin;
  final bool navigationEnabled;
  final bool pressAnimationEnabled;
  final VoidCallback? onReturnFromDetail;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: AppTheme.cardDecoration(selected: isAdmin),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: navigationEnabled
              ? () async {
                  await Navigator.of(context).push(
                    FadeSlideRoute(
                      page: InstitutionDetailPage(
                        cidNumber: institution.cidNumber,
                        repository: InstitutionRepository(),
                      ),
                    ),
                  );
                  onReturnFromDetail?.call();
                }
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppLayout.scaled(context, 12),
                vertical: AppLayout.scaled(context, 10)),
            child: Row(
              children: [
                Expanded(
                  // 机构卡片不再显示名称左侧图标，只保留名称和右箭头。
                  child: Text(
                    institution.cidShortNameOrFullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 13),
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppLayout.scaled(context, 16),
                  color: AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!pressAnimationEnabled) {
      return card;
    }
    return PressableCard(child: card);
  }
}

class _GovernanceIconBadge extends StatelessWidget {
  const _GovernanceIconBadge({
    required this.icon,
    required this.color,
    required this.boxSize,
    required this.iconSize,
    this.iconAsset,
  });

  final IconData icon;
  final String? iconAsset;
  final Color color;
  final double boxSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final asset = iconAsset;
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(7)),
      ),
      child: Center(
        // 省储委会/省储行使用指定 SVG 图案；国家储委会使用 Material 图标。
        child: asset == null
            ? Icon(icon, size: iconSize, color: color)
            : SvgPicture.asset(
                asset,
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
      ),
    );
  }
}
