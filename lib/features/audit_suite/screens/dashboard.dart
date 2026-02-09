import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/workpapers_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum ActivityType { workpaper, engagement, risk }
enum _DashFilter { all, atRisk, needsAttention, healthy, finalized }
enum _HealthTone { healthy, attention, risk, finalized, unknown }

class _DashboardScreenState extends State<DashboardScreen> {
  late final ClientsRepository _clientsRepo;
  late final EngagementsRepository _engRepo;
  late final WorkpapersRepository _wpRepo;
  late final RiskAssessmentsRepository _riskRepo;

  late Future<_Vm> _future;
  bool _busy = false;
  _DashFilter _filter = _DashFilter.all;

  @override
  void initState() {
    super.initState();
    _clientsRepo = ClientsRepository(widget.store);
    _engRepo = EngagementsRepository(widget.store);
    _wpRepo = WorkpapersRepository(widget.store);
    _riskRepo = RiskAssessmentsRepository(widget.store);
    _future = _load();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _clientsRepo.clearCache();
      await _engRepo.clearCache();
      await _wpRepo.clearCache();
      await _riskRepo.clearCache();

      final next = _load();
      setState(() => _future = next);
      await next;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openEngagement(String id) {
    context.pushNamed('engagementDetail', pathParameters: {'id': id});
  }

  void _onActivityTap(_ActivityItem a) {
    switch (a.type) {
      case ActivityType.workpaper:
        if ((a.workpaperId ?? '').isNotEmpty) {
          context.pushNamed('workpaperDetail', pathParameters: {'id': a.workpaperId!});
        } else if ((a.engagementId ?? '').isNotEmpty) {
          _openEngagement(a.engagementId!);
        }
        break;

      case ActivityType.engagement:
      case ActivityType.risk:
        if ((a.engagementId ?? '').isNotEmpty) {
          _openEngagement(a.engagementId!);
        }
        break;
    }
  }

  List<_RecentEngagementCardVm> _applyFilter(List<_RecentEngagementCardVm> list) {
    switch (_filter) {
      case _DashFilter.all:
        return list;
      case _DashFilter.atRisk:
        return list.where((e) => e.healthTone == _HealthTone.risk).toList();
      case _DashFilter.needsAttention:
        return list.where((e) => e.healthTone == _HealthTone.attention).toList();
      case _DashFilter.healthy:
        return list.where((e) => e.healthTone == _HealthTone.healthy).toList();
      case _DashFilter.finalized:
        return list.where((e) => e.healthTone == _HealthTone.finalized).toList();
    }
  }

  Future<_Vm> _load() async {
    // ✅ Web-safe: no filesystem calls anywhere in this dashboard.
    final clients = await _clientsRepo.getClients();
    final engagements = await _engRepo.getEngagements();
    final workpapers = await _wpRepo.getWorkpapers();

    final clientNameById = <String, String>{
      for (final c in clients) c.id: c.name,
    };

    // Group workpapers by engagement
    final wpByEng = <String, List<dynamic>>{};
    for (final wp in workpapers) {
      final eid = (wp.engagementId as String);
      (wpByEng[eid] ??= <dynamic>[]).add(wp);
    }

    // Sort engagements by updated desc (fallback to empty string if null)
    final sortedEngagements = [...engagements]
      ..sort((a, b) => ((b.updated ?? '') as String).compareTo((a.updated ?? '') as String));
    final recentEngagements = sortedEngagements.take(8).toList();

    int atRisk = 0;
    int needsAttention = 0;
    int healthy = 0;
    int finalized = 0;

    // Readiness rollup (web-safe)
    int readinessSum = 0;
    int readinessCount = 0;
    final lowestReadiness = <_ReadinessLowVm>[];

    final recentCards = <_RecentEngagementCardVm>[];
    final activity = <_ActivityItem>[];

    for (final e in engagements) {
      final id = e.id;
      final title = e.title;
      final status = e.status;
      final clientName = clientNameById[e.clientId] ?? e.clientId;

      // Risk (repo-backed, no filesystem)
      String riskLevel = '—';
      String riskUpdated = '';
      try {
        final risk = await _riskRepo.ensureForEngagement(id);
        riskLevel = risk.overallLevel();
        riskUpdated = (risk.updated).trim();

        if (riskUpdated.isNotEmpty) {
          activity.add(
            _ActivityItem(
              type: ActivityType.risk,
              title: 'Risk updated',
              subtitle: '$title • $riskLevel',
              when: _parseIso(riskUpdated),
              engagementId: id,
            ),
          );
        }
      } catch (_) {
        // ignore
      }

      // Workpaper completion
      final list = (wpByEng[id] ?? const <dynamic>[]);
      final totalWps = list.length;
      final completeWps = list.where((w) {
        final s = (w.status as String?) ?? '';
        return s.trim().toLowerCase() == 'complete';
      }).length;
      final openWps = (totalWps - completeWps).clamp(0, 999999);

      final healthRes = _computeHealth(
        engagementStatus: status,
        riskLevel: riskLevel,
        openWorkpapers: openWps,
      );

      switch (healthRes.tone) {
        case _HealthTone.risk:
          atRisk++;
          break;
        case _HealthTone.attention:
          needsAttention++;
          break;
        case _HealthTone.healthy:
          healthy++;
          break;
        case _HealthTone.finalized:
          finalized++;
          break;
        case _HealthTone.unknown:
          break;
      }

      // Web-safe readiness (risk completion + workpaper completion)
      final readiness = _computeReadinessPercentWebSafe(
        engagementStatus: status,
        riskCompleted: riskUpdated.isNotEmpty,
        totalWorkpapers: totalWps,
        completeWorkpapers: completeWps,
      );

      readinessSum += readiness;
      readinessCount++;

      lowestReadiness.add(
        _ReadinessLowVm(id: id, title: title, clientName: clientName, pct: readiness),
      );
      lowestReadiness.sort((a, b) => a.pct.compareTo(b.pct));
      if (lowestReadiness.length > 3) lowestReadiness.removeLast();

      final upd = ((e.updated ?? '') as String).trim();
      if (upd.isNotEmpty) {
        activity.add(
          _ActivityItem(
            type: ActivityType.engagement,
            title: 'Engagement updated',
            subtitle: '$title • $status',
            when: _parseIso(upd),
            engagementId: id,
          ),
        );
      }

      // Only build cards for recent engagements
      final isRecent = recentEngagements.any((r) => r.id == id);
      if (isRecent) {
        recentCards.add(
          _RecentEngagementCardVm(
            id: id,
            title: title,
            clientName: clientName,
            status: status,
            updated: (e.updated ?? '') as String,
            riskLevel: riskLevel,
            lettersGenerated: 0, // keep field, web-safe placeholder
            openWorkpapers: openWps,
            totalWorkpapers: totalWps,
            healthLabel: healthRes.label,
            healthTone: healthRes.tone,
            readinessPct: readiness,
          ),
        );
      }
    }

    // Workpaper activity
    for (final wp in workpapers) {
      final upd = ((wp.updated ?? '') as String).trim();
      if (upd.isEmpty) continue;
      activity.add(
        _ActivityItem(
          type: ActivityType.workpaper,
          title: 'Workpaper updated',
          subtitle: wp.title,
          when: _parseIso(upd),
          engagementId: wp.engagementId,
          workpaperId: wp.id,
        ),
      );
    }

    activity.sort((a, b) => b.when.compareTo(a.when));
    recentCards.sort((a, b) => b.updated.compareTo(a.updated));

    final avgReadiness = readinessCount == 0 ? 0 : (readinessSum / readinessCount).round();

    // ✅ placeholders for future sections (PBC + integrity) to keep the VM stable
    return _Vm(
      clients: clients.length,
      engagements: engagements.length,
      workpapers: workpapers.length,
      recent: recentCards,
      activity: activity.take(10).toList(),
      healthAtRisk: atRisk,
      healthNeedsAttention: needsAttention,
      healthHealthy: healthy,
      healthFinalized: finalized,
      avgReadinessPct: avgReadiness,
      lowestReadiness: lowestReadiness,
      totalPbcOverdue: 0,
      pbcBottlenecks: const <_PbcBottleneckVm>[],
      totalIntegrityIssues: 0,
      integrityAlerts: const <_IntegrityAlertVm>[],
      webMode: kIsWeb,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_Vm>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.error_outline, size: 44),
                  const SizedBox(height: 10),
                  Text(
                    'Dashboard failed to load.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              );
            }

            final vm = snap.data!;
            final filteredRecent = _applyFilter(vm.recent);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                if (vm.webMode) ...[
                  Card(
                    color: cs.surfaceContainerHighest,
                    child: const ListTile(
                      leading: Icon(Icons.public),
                      title: Text('Web demo mode'),
                      subtitle: Text(
                        'Exports/logs that require a local Documents folder are disabled on web.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _HeroCard(
                  title: 'Auditron',
                  subtitle: 'Quick actions + workspace summary',
                  rightTop: _TinyPill(
                    text: _busy ? 'Syncing…' : 'Ready',
                    bg: cs.surfaceContainerHighest,
                    border: cs.onSurface.withValues(alpha: 0.10),
                  ),
                  rightBottom: Text(
                    'Today',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 14),

                _KpiRow(
                  children: [
                    _KpiCard(
                      icon: Icons.apartment_outlined,
                      label: 'Clients',
                      value: vm.clients.toString(),
                      onTap: () => context.go('/clients'),
                    ),
                    _KpiCard(
                      icon: Icons.work_outline,
                      label: 'Engagements',
                      value: vm.engagements.toString(),
                      onTap: () => context.go('/engagements'),
                    ),
                    _KpiCard(
                      icon: Icons.folder_open_outlined,
                      label: 'Workpapers',
                      value: vm.workpapers.toString(),
                      onTap: () => context.go('/workpapers'),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _SectionCard(
                  title: 'Portfolio Health',
                  subtitle: 'At-a-glance engagement health distribution.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _TinyPill(
                        text: '${vm.healthAtRisk} At Risk',
                        bg: cs.errorContainer,
                        border: cs.error.withValues(alpha: 0.40),
                      ),
                      _TinyPill(
                        text: '${vm.healthNeedsAttention} Needs Attention',
                        bg: cs.tertiaryContainer,
                        border: cs.tertiary.withValues(alpha: 0.40),
                      ),
                      _TinyPill(
                        text: '${vm.healthHealthy} Healthy',
                        bg: cs.secondaryContainer,
                        border: cs.secondary.withValues(alpha: 0.40),
                      ),
                      _TinyPill(
                        text: '${vm.healthFinalized} Finalized',
                        bg: cs.surface,
                        border: cs.onSurface.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _SectionCard(
                  title: 'Audit Readiness',
                  subtitle: 'Web-safe readiness = Risk completion + Workpaper completion.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _TinyPill(
                            text: 'Avg Ready: ${vm.avgReadinessPct}%',
                            bg: cs.secondaryContainer,
                            border: cs.secondary.withValues(alpha: 0.40),
                          ),
                          _TinyPill(
                            text: vm.lowestReadiness.isEmpty
                                ? 'Lowest: —'
                                : 'Lowest: ${vm.lowestReadiness.first.pct}%',
                            bg: cs.tertiaryContainer,
                            border: cs.tertiary.withValues(alpha: 0.40),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (vm.lowestReadiness.isEmpty)
                        Text(
                          'No engagements yet.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.70),
                              ),
                        )
                      else
                        Column(
                          children: [
                            for (final r in vm.lowestReadiness)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ReadinessRow(
                                  title: r.title,
                                  subtitle: r.clientName,
                                  pct: r.pct,
                                  onTap: () => _openEngagement(r.id),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _SectionCard(
                  title: 'Filters',
                  subtitle: 'Filter recent engagements by health.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter == _DashFilter.all,
                        onTap: () => setState(() => _filter = _DashFilter.all),
                      ),
                      _FilterChip(
                        label: 'At Risk',
                        selected: _filter == _DashFilter.atRisk,
                        onTap: () => setState(() => _filter = _DashFilter.atRisk),
                      ),
                      _FilterChip(
                        label: 'Needs Attention',
                        selected: _filter == _DashFilter.needsAttention,
                        onTap: () => setState(() => _filter = _DashFilter.needsAttention),
                      ),
                      _FilterChip(
                        label: 'Healthy',
                        selected: _filter == _DashFilter.healthy,
                        onTap: () => setState(() => _filter = _DashFilter.healthy),
                      ),
                      _FilterChip(
                        label: 'Finalized',
                        selected: _filter == _DashFilter.finalized,
                        onTap: () => setState(() => _filter = _DashFilter.finalized),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  'Workspace',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 10),

                if (vm.activity.isEmpty)
                  const _InfoCard(
                    icon: Icons.history,
                    title: 'No recent activity',
                    body: 'Update a workpaper or engagement to populate this timeline.',
                  )
                else
                  _SectionCard(
                    title: 'Recent Activity',
                    subtitle: 'Tap an item to open it.',
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 10),
                        title: Text(
                          '${vm.activity.length} items • latest ${_prettyWhen(vm.activity.first.when)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        trailing: const Icon(Icons.expand_more),
                        children: [
                          for (int i = 0; i < vm.activity.length; i++) ...[
                            _ActivityRow(
                              item: vm.activity[i],
                              onTap: () => _onActivityTap(vm.activity[i]),
                            ),
                            if (i != vm.activity.length - 1)
                              Divider(
                                height: 16,
                                color: cs.onSurface.withValues(alpha: 0.08),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                if (filteredRecent.isEmpty)
                  const _InfoCard(
                    icon: Icons.filter_alt_off,
                    title: 'No matches',
                    body: 'No recent engagements match this filter.',
                  )
                else
                  _SectionCard(
                    title: 'Recent Engagements',
                    subtitle: 'Includes Ready % on each engagement.',
                    child: Column(
                      children: [
                        for (int i = 0; i < filteredRecent.length; i++) ...[
                          _RecentEngagementRow(
                            vm: filteredRecent[i],
                            onTap: () => _openEngagement(filteredRecent[i].id),
                          ),
                          if (i != filteredRecent.length - 1)
                            Divider(
                              height: 16,
                              color: cs.onSurface.withValues(alpha: 0.08),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
// ===================== VIEW MODELS =====================

class _Vm {
  final int clients;
  final int engagements;
  final int workpapers;

  final List<_RecentEngagementCardVm> recent;
  final List<_ActivityItem> activity;

  final int healthAtRisk;
  final int healthNeedsAttention;
  final int healthHealthy;
  final int healthFinalized;

  final int avgReadinessPct;
  final List<_ReadinessLowVm> lowestReadiness;

  final int totalPbcOverdue;
  final List<_PbcBottleneckVm> pbcBottlenecks;

  final int totalIntegrityIssues;
  final List<_IntegrityAlertVm> integrityAlerts;

  final bool webMode;

  const _Vm({
    required this.clients,
    required this.engagements,
    required this.workpapers,
    required this.recent,
    required this.activity,
    required this.healthAtRisk,
    required this.healthNeedsAttention,
    required this.healthHealthy,
    required this.healthFinalized,
    required this.avgReadinessPct,
    required this.lowestReadiness,
    required this.totalPbcOverdue,
    required this.pbcBottlenecks,
    required this.totalIntegrityIssues,
    required this.integrityAlerts,
    required this.webMode,
  });
}

class _ReadinessLowVm {
  final String id;
  final String title;
  final String clientName;
  final int pct;

  const _ReadinessLowVm({
    required this.id,
    required this.title,
    required this.clientName,
    required this.pct,
  });
}

class _PbcBottleneckVm {
  final String engagementId;
  final String engagementTitle;
  final String clientName;
  final int overdueCount;

  const _PbcBottleneckVm({
    required this.engagementId,
    required this.engagementTitle,
    required this.clientName,
    required this.overdueCount,
  });
}

class _IntegrityAlertVm {
  final String engagementId;
  final String engagementTitle;
  final String clientName;
  final int issueCount;

  const _IntegrityAlertVm({
    required this.engagementId,
    required this.engagementTitle,
    required this.clientName,
    required this.issueCount,
  });
}

class _RecentEngagementCardVm {
  final String id;
  final String title;
  final String clientName;
  final String status;
  final String updated;
  final String riskLevel;

  final int lettersGenerated;
  final int openWorkpapers;
  final int totalWorkpapers;

  final String healthLabel;
  final _HealthTone healthTone;

  final int readinessPct;

  const _RecentEngagementCardVm({
    required this.id,
    required this.title,
    required this.clientName,
    required this.status,
    required this.updated,
    required this.riskLevel,
    required this.lettersGenerated,
    required this.openWorkpapers,
    required this.totalWorkpapers,
    required this.healthLabel,
    required this.healthTone,
    required this.readinessPct,
  });
}

class _ActivityItem {
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime when;
  final String? engagementId;
  final String? workpaperId;
  final String? letterType;

  const _ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.when,
    this.engagementId,
    this.workpaperId,
    this.letterType,
  });
}

// ===================== HELPERS =====================

DateTime _parseIso(String iso) {
  try {
    return DateTime.parse(iso);
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

String _prettyWhen(DateTime dt) {
  if (dt.millisecondsSinceEpoch == 0) return '—';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _inferLetterType(String fileName) {
  final n = fileName.toLowerCase();
  if (n.contains('engagement')) return 'engagement';
  if (n.contains('pbc')) return 'pbc';
  if (n.contains('mrl')) return 'mrl';
  return '';
}

class _HealthResult {
  final String label;
  final _HealthTone tone;
  const _HealthResult(this.label, this.tone);
}

_HealthResult _computeHealth({
  required String engagementStatus,
  required String riskLevel,
  required int openWorkpapers,
}) {
  final s = engagementStatus.trim().toLowerCase();
  if (s == 'final' || s == 'finalized' || s == 'complete' || s == 'completed') {
    return const _HealthResult('Finalized', _HealthTone.finalized);
  }

  final r = riskLevel.trim().toLowerCase();

  // Conservative: high risk or too many open workpapers => at risk
  if (r.contains('high') || r.contains('severe') || openWorkpapers >= 12) {
    return const _HealthResult('At Risk', _HealthTone.risk);
  }

  // Medium risk or some open workpapers => needs attention
  if (r.contains('medium') || r.contains('moderate') || openWorkpapers >= 5) {
    return const _HealthResult('Needs Attention', _HealthTone.attention);
  }

  // Low risk & low open => healthy
  if (r.contains('low') || r.isEmpty || r == '—') {
    if (openWorkpapers <= 4) {
      return const _HealthResult('Healthy', _HealthTone.healthy);
    }
  }

  return const _HealthResult('Unknown', _HealthTone.unknown);
}

int _computeReadinessPercentWebSafe({
  required String engagementStatus,
  required bool riskCompleted,
  required int totalWorkpapers,
  required int completeWorkpapers,
}) {
  final s = engagementStatus.trim().toLowerCase();
  if (s == 'final' || s == 'finalized' || s == 'complete' || s == 'completed') {
    return 100;
  }

  // Weighting:
  // - Risk completion: 40%
  // - Workpaper completion: 60%
  final riskScore = riskCompleted ? 40 : 0;

  final wpPct = (totalWorkpapers <= 0)
      ? 0
      : ((completeWorkpapers / totalWorkpapers) * 60).round();

  final total = (riskScore + wpPct).clamp(0, 100);
  return total;
}

// ===================== UI WIDGETS =====================

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.rightTop,
    required this.rightBottom,
  });

  final String title;
  final String subtitle;
  final Widget rightTop;
  final Widget rightBottom;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                rightTop,
                const SizedBox(height: 8),
                rightBottom,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 220, child: children[i]),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.text,
    required this.bg,
    required this.border,
  });

  final String text;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.70),
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surfaceContainerHighest;
    final border = selected ? cs.primary.withValues(alpha: 0.55) : cs.onSurface.withValues(alpha: 0.10);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.title,
    required this.subtitle,
    required this.pct,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int pct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text('$pct%'),
      onTap: onTap,
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.onTap,
  });

  final _ActivityItem item;
  final VoidCallback onTap;

  IconData _iconFor(ActivityType t) {
    switch (t) {
      case ActivityType.workpaper:
        return Icons.description_outlined;
      case ActivityType.engagement:
        return Icons.work_outline;
      case ActivityType.risk:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        ),
        child: Icon(_iconFor(item.type), size: 20),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
      subtitle: Text(
        '${item.subtitle} • ${_prettyWhen(item.when)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.70),
            ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _RecentEngagementRow extends StatelessWidget {
  const _RecentEngagementRow({
    required this.vm,
    required this.onTap,
  });

  final _RecentEngagementCardVm vm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tone = vm.healthTone;
    final Color chipBg;
    final Color chipBorder;

    switch (tone) {
      case _HealthTone.risk:
        chipBg = cs.errorContainer;
        chipBorder = cs.error.withValues(alpha: 0.45);
        break;
      case _HealthTone.attention:
        chipBg = cs.tertiaryContainer;
        chipBorder = cs.tertiary.withValues(alpha: 0.45);
        break;
      case _HealthTone.healthy:
        chipBg = cs.secondaryContainer;
        chipBorder = cs.secondary.withValues(alpha: 0.45);
        break;
      case _HealthTone.finalized:
        chipBg = cs.surfaceContainerHighest;
        chipBorder = cs.onSurface.withValues(alpha: 0.14);
        break;
      case _HealthTone.unknown:
        chipBg = cs.surfaceContainerHighest;
        chipBorder = cs.onSurface.withValues(alpha: 0.14);
        break;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(vm.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${vm.clientName} • ${vm.healthLabel} • Risk ${vm.riskLevel} • Ready ${vm.readinessPct}%',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.70),
            ),
      ),
      trailing: _TinyPill(
        text: '${vm.readinessPct}%',
        bg: chipBg,
        border: chipBorder,
      ),
      onTap: onTap,
    );
  }
}