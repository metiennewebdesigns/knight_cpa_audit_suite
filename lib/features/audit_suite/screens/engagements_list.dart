import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/engagement_models.dart';
import '../data/models/client_models.dart';
import '../data/models/risk_assessment_models.dart';

import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';

import '../services/ai_priority.dart';


class EngagementsListScreen extends StatefulWidget {
  const EngagementsListScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<EngagementsListScreen> createState() => _EngagementsListScreenState();
}

enum _SortMode { updatedDesc, aiDesc, riskDesc, titleAsc }

class _EngagementsListScreenState extends State<EngagementsListScreen> {
  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;
  late final RiskAssessmentsRepository _riskRepo;

  late Future<_Vm> _future;

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _busy = false;

  // ✅ New: priority filter + sort
  String _aiFilter = 'All'; // All | Low | Medium | High | Critical
  _SortMode _sort = _SortMode.aiDesc;

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
    _riskRepo = RiskAssessmentsRepository(widget.store);

    _future = _load();

    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_Vm> _load() async {
    final engagements = await _engRepo.getEngagements();
    final clients = await _clientsRepo.getClients();

    final clientNameById = <String, String>{
      for (final c in clients) c.id: c.name,
    };

    final riskByEngId = <String, RiskAssessmentModel>{};
    for (final e in engagements) {
      riskByEngId[e.id] = await _riskRepo.ensureForEngagement(e.id);
    }

    return _Vm(
      engagements: engagements,
      clientNameById: clientNameById,
      riskByEngId: riskByEngId,
      clients: clients,
    );
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _engRepo.clearCache();
      await _clientsRepo.clearCache();
      await _riskRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEngagement(EngagementModel e) async {
    final changed = await context.push<bool>('/engagements/${e.id}');
    if (changed == true) await _refresh();
  }

  Future<void> _createEngagement(List<ClientModel> clients) async {
    if (_busy) return;

    final created = await showDialog<EngagementModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateEngagementDialog(clients: clients),
    );

    if (created == null) return;

    setState(() => _busy = true);
    try {
      await _engRepo.upsert(created);
      await _riskRepo.ensureForEngagement(created.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Engagement created ✅')),
      );

      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  _AiPillVm _aiVmForRow(EngagementModel e, RiskAssessmentModel? risk, ColorScheme cs) {
    // if saved, show saved
    if (e.hasAiPriority) {
      return _AiPillVm.fromLabel(
        cs,
        e.aiPriorityLabel.isEmpty ? 'Medium' : e.aiPriorityLabel,
        e.aiPriorityScore,
        e.aiPriorityReason,
      );
    }

    // compute preview from risk only (list screen doesn’t load other stats)
    final res = AiPriorityScorer.score(
      engagement: e,
      risk: risk,
      pbcOverdueCount: 0,
      integrityIssues: 0,
      openWorkpapers: 0,
      totalWorkpapers: 0,
      discrepancyOpenCount: 0,
      discrepancyOpenTotal: 0.0,
    );

    return _AiPillVm.fromLabel(cs, res.label, res.score, res.reason);
  }

  List<EngagementModel> _applySearch(_Vm vm) {
    if (_query.isEmpty) return vm.engagements;
    return vm.engagements.where((e) {
      final clientName = vm.clientNameById[e.clientId] ?? e.clientId;
      final hay = '${e.title} $clientName ${e.status} ${e.updated} ${e.clientId} ${e.id}'.toLowerCase();
      return hay.contains(_query);
    }).toList();
  }

  List<EngagementModel> _applyAiFilter(_Vm vm, List<EngagementModel> list, ColorScheme cs) {
    if (_aiFilter == 'All') return list;

    return list.where((e) {
      final risk = vm.riskByEngId[e.id];
      final ai = _aiVmForRow(e, risk, cs);
      return ai.label.toLowerCase() == _aiFilter.toLowerCase();
    }).toList();
  }

  List<EngagementModel> _applySort(_Vm vm, List<EngagementModel> list, ColorScheme cs) {
    final out = [...list];

    int riskScore(EngagementModel e) => vm.riskByEngId[e.id]?.overallScore1to5() ?? 0;
    int aiScore(EngagementModel e) => _aiVmForRow(e, vm.riskByEngId[e.id], cs).score;

    switch (_sort) {
      case _SortMode.updatedDesc:
        out.sort((a, b) => b.updated.compareTo(a.updated));
        break;
      case _SortMode.aiDesc:
        out.sort((a, b) => aiScore(b).compareTo(aiScore(a)));
        break;
      case _SortMode.riskDesc:
        out.sort((a, b) => riskScore(b).compareTo(riskScore(a)));
        break;
      case _SortMode.titleAsc:
        out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    return out;
  }

  String _sortLabel(_SortMode s) {
    switch (s) {
      case _SortMode.aiDesc:
        return 'AI Priority';
      case _SortMode.updatedDesc:
        return 'Updated';
      case _SortMode.riskDesc:
        return 'Risk';
      case _SortMode.titleAsc:
        return 'Title';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engagements'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_Vm>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorState(
              title: 'Failed to load engagements',
              message: snap.error.toString(),
              onRetry: _busy ? null : _refresh,
            );
          }

          final vm = snap.data!;
          final searched = _applySearch(vm);
          final filtered = _applyAiFilter(vm, searched, cs);
          final sorted = _applySort(vm, filtered, cs);

          return Stack(
            children: [
              ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  _SearchField(
                    controller: _searchCtrl,
                    hint: 'Search engagements (title, client, status, id)…',
                  ),
                  const SizedBox(height: 12),

                  // ✅ Filters + sort
                  Card(
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChip(
                                label: 'All',
                                selected: _aiFilter == 'All',
                                onTap: () => setState(() => _aiFilter = 'All'),
                              ),
                              _FilterChip(
                                label: 'Low',
                                selected: _aiFilter == 'Low',
                                onTap: () => setState(() => _aiFilter = 'Low'),
                              ),
                              _FilterChip(
                                label: 'Medium',
                                selected: _aiFilter == 'Medium',
                                onTap: () => setState(() => _aiFilter = 'Medium'),
                              ),
                              _FilterChip(
                                label: 'High',
                                selected: _aiFilter == 'High',
                                onTap: () => setState(() => _aiFilter = 'High'),
                              ),
                              _FilterChip(
                                label: 'Critical',
                                selected: _aiFilter == 'Critical',
                                onTap: () => setState(() => _aiFilter = 'Critical'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<_SortMode>(
                                  initialValue: _sort,
                                  items: _SortMode.values
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text('Sort: ${_sortLabel(s)}'),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _sort = v ?? _sort),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Sort',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _busy ? null : _refresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reload'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (vm.engagements.isEmpty)
                    _EmptyState(
                      icon: Icons.work_outline,
                      title: 'No engagements yet',
                      subtitle: 'Create your first engagement.',
                      actionLabel: 'Create Engagement',
                      onAction: () => _createEngagement(vm.clients),
                    )
                  else if (sorted.isEmpty)
                    _EmptyState(
                      icon: Icons.search_off,
                      title: 'No results',
                      subtitle: 'Try changing filters or search.',
                      actionLabel: 'Clear filters',
                      onAction: () {
                        setState(() {
                          _aiFilter = 'All';
                          _sort = _SortMode.aiDesc;
                        });
                        _searchCtrl.clear();
                        FocusScope.of(context).unfocus();
                      },
                    )
                  else
                    ...sorted.map((e) {
                      final clientName = vm.clientNameById[e.clientId] ?? e.clientId;
                      final risk = vm.riskByEngId[e.id];
                      final riskLabel = risk == null
                          ? 'Not assessed'
                          : '${risk.overallLevel()} (${risk.overallScore1to5()}/5)';

                      final ai = _aiVmForRow(e, risk, cs);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LuxuryCard(
                          onTap: () => _openEngagement(e),
                          child: Row(
                            children: [
                              _IconBadge(
                                icon: Icons.work_outline,
                                tone: cs.primary.withOpacity(0.14),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      clientName,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: cs.onSurface.withOpacity(0.70),
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _Chip(text: 'Status: ${e.status}'),
                                        _Chip(text: 'Risk: $riskLabel'),
                                        _Chip(text: 'Updated: ${_prettyMonth(e.updated)}'),
                                        _Chip(
                                          text: 'AI: ${ai.label} (${ai.score})',
                                          bg: ai.bg,
                                          border: ai.border,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.55)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: _busy ? null : () => _createEngagement(vm.clients),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Engagement'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Vm {
  final List<EngagementModel> engagements;
  final Map<String, String> clientNameById;
  final Map<String, RiskAssessmentModel> riskByEngId;
  final List<ClientModel> clients;

  const _Vm({
    required this.engagements,
    required this.clientNameById,
    required this.riskByEngId,
    required this.clients,
  });
}

class _AiPillVm {
  final String label;
  final int score;
  final String reason;
  final Color bg;
  final Color border;

  const _AiPillVm({
    required this.label,
    required this.score,
    required this.reason,
    required this.bg,
    required this.border,
  });

  static _AiPillVm fromLabel(ColorScheme cs, String label, int score, String reason) {
    final l = label.trim().toLowerCase();

    if (l == 'critical') {
      return _AiPillVm(
        label: 'Critical',
        score: score,
        reason: reason,
        bg: cs.errorContainer,
        border: cs.error.withOpacity(0.35),
      );
    }
    if (l == 'high') {
      return _AiPillVm(
        label: 'High',
        score: score,
        reason: reason,
        bg: cs.tertiaryContainer,
        border: cs.tertiary.withOpacity(0.35),
      );
    }
    if (l == 'medium') {
      return _AiPillVm(
        label: 'Medium',
        score: score,
        reason: reason,
        bg: cs.surfaceContainerHighest,
        border: cs.onSurface.withOpacity(0.12),
      );
    }
    return _AiPillVm(
      label: 'Low',
      score: score,
      reason: reason,
      bg: cs.secondaryContainer,
      border: cs.secondary.withOpacity(0.35),
    );
  }
}

/* ======================= UI ======================= */

class _LuxuryCard extends StatelessWidget {
  const _LuxuryCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.tone});
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
      ),
      child: Icon(icon, size: 22),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.bg, this.border});
  final String text;
  final Color? bg;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final useBg = bg ?? cs.surface.withOpacity(0.55);
    final useBorder = border ?? cs.onSurface.withOpacity(0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: useBg,
        border: Border.all(color: useBorder),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary.withOpacity(0.18) : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? cs.primary.withOpacity(0.45) : cs.onSurface.withOpacity(0.10)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  FocusScope.of(context).unfocus();
                },
                icon: const Icon(Icons.close),
              ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 46),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.message, required this.onRetry});
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, size: 44),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _CreateEngagementDialog extends StatefulWidget {
  const _CreateEngagementDialog({required this.clients});
  final List<ClientModel> clients;

  @override
  State<_CreateEngagementDialog> createState() => _CreateEngagementDialogState();
}

class _CreateEngagementDialogState extends State<_CreateEngagementDialog> {
  final _titleCtrl = TextEditingController();
  static const _statuses = ['Open', 'In Progress', 'Complete'];
  String _status = 'Open';
  String? _clientId;

  @override
  void initState() {
    super.initState();
    _clientId = widget.clients.isNotEmpty ? widget.clients.first.id : null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _clientId == null) return;

    Navigator.of(context).pop(
      EngagementModel(
        id: '',
        clientId: _clientId!,
        title: title,
        status: _status,
        updated: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Engagement'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Engagement Title', border: OutlineInputBorder()),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _clientId,
              items: widget.clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _clientId = v),
              decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

String _prettyMonth(String iso) {
  final s = iso.trim();
  if (s.isEmpty || s.length < 7) return s.isEmpty ? '—' : s;
  final y = s.substring(0, 4);
  final m = s.substring(5, 7);
  const months = {
    '01': 'Jan',
    '02': 'Feb',
    '03': 'Mar',
    '04': 'Apr',
    '05': 'May',
    '06': 'Jun',
    '07': 'Jul',
    '08': 'Aug',
    '09': 'Sep',
    '10': 'Oct',
    '11': 'Nov',
    '12': 'Dec',
  };
  return '${months[m] ?? m} $y';
}