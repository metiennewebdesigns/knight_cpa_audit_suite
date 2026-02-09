import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/engagement_models.dart';
import '../data/models/workpaper_models.dart';
import '../data/models/risk_assessment_models.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/workpapers_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';

class EngagementDetailScreen extends StatefulWidget {
  const EngagementDetailScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<EngagementDetailScreen> createState() => _EngagementDetailScreenState();
}

class _EngagementDetailScreenState extends State<EngagementDetailScreen> {
  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;
  late final WorkpapersRepository _wpRepo;
  late final RiskAssessmentsRepository _riskRepo;

  late Future<_Vm> _future;

  bool _busy = false;
  bool _changed = false;
  bool _seeded = false;

  final _titleCtrl = TextEditingController();
  static const _statusOptions = <String>['Open', 'In Progress', 'Complete'];
  String _status = 'Open';

  EngagementModel? _loadedEngagement;

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
    _wpRepo = WorkpapersRepository(widget.store);
    _riskRepo = RiskAssessmentsRepository(widget.store);

    _future = _load();
    _titleCtrl.addListener(_onEdit);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onEdit);
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onEdit() {
    if (!_seeded) return;
    if (mounted) setState(() {});
  }

  bool get _isDirty {
    final base = _loadedEngagement;
    if (!_seeded || base == null) return false;
    return _titleCtrl.text.trim() != base.title.trim() || _status != base.status;
  }

  Future<_Vm> _load() async {
    final eng = await _engRepo.getById(widget.engagementId);
    if (eng == null) throw StateError('Engagement not found: ${widget.engagementId}');

    final clients = await _clientsRepo.getClients();
    final clientNameById = <String, String>{for (final c in clients) c.id: c.name};
    final clientName = clientNameById[eng.clientId] ?? eng.clientId;

    final wps = await _wpRepo.getByEngagementId(widget.engagementId);
    final risk = await _riskRepo.ensureForEngagement(widget.engagementId);

    _loadedEngagement = eng;

    _seeded = false;
    _titleCtrl.text = eng.title;
    _status = _statusOptions.contains(eng.status) ? eng.status : 'Open';
    _seeded = true;

    return _Vm(engagement: eng, clientName: clientName, workpapers: wps, risk: risk);
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _engRepo.clearCache();
      await _clientsRepo.clearCache();
      await _wpRepo.clearCache();
      await _riskRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;

    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved edits. If you leave now, they will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  Future<void> _saveEngagement() async {
    if (_busy || !_isDirty) return;

    final base = _loadedEngagement;
    if (base == null) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }

    setState(() => _busy = true);
    try {
      final draft = base.copyWith(title: title, status: _status, updated: '');
      final saved = await _engRepo.upsert(draft);

      _loadedEngagement = saved;
      _changed = true;

      _seeded = false;
      _titleCtrl.text = saved.title;
      _status = saved.status;
      _seeded = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Engagement saved ✅')));

      setState(() {});
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWorkpaper(String id) async {
    final changed = await context.push<bool>('/workpapers/$id');
    if (changed == true) {
      _changed = true;
      await _refresh();
    }
  }

  Future<void> _openRisk() async {
    final changed = await context.push<bool>('/engagements/${widget.engagementId}/risk');
    if (changed == true) {
      _changed = true;
      await _refresh();
    }
  }

  Future<void> _openPlanning() async {
    final changed = await context.push<bool>('/engagements/${widget.engagementId}/planning');
    if (changed == true) {
      _changed = true;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDirty = _isDirty && !_busy;

    return WillPopScope(
      onWillPop: () async {
        final ok = await _confirmDiscardIfDirty();
        if (!ok) return false;
        context.pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Engagement Detail'),
              if (showDirty) ...const [
                SizedBox(width: 10),
                _UnsavedPill(),
              ],
            ],
          ),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _confirmDiscardIfDirty();
              if (!ok) return;
              if (!mounted) return;
              context.pop(_changed);
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Save',
              onPressed: (_busy || !_isDirty) ? null : _saveEngagement,
              icon: const Icon(Icons.save_outlined),
            ),
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
            if (snap.hasError) return Center(child: Text(snap.error.toString()));

            final vm = snap.data!;
            final e = vm.engagement;

            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: Text('Risk Summary: ${vm.risk.overallLevel()} (${vm.risk.overallScore1to5()}/5)'),
                      subtitle: Text(vm.risk.updated.trim().isEmpty ? 'Not assessed yet' : 'Assessed: ${vm.risk.updated}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openRisk,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ NEW: Planning Summary entry
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: const Text('Audit Planning Summary'),
                      subtitle: const Text('Auto-generated from Risk + editable narrative + mark Final'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openPlanning,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('Client: ${vm.clientName}'),
                          const SizedBox(height: 6),
                          Text('Engagement ID: ${e.id}', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 16),
                          Text('Edit Engagement', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Title'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _status,
                            items: _statusOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: (v) => setState(() => _status = v ?? _status),
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: (_busy || !_isDirty) ? null : _saveEngagement,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Workpapers', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  if (vm.workpapers.isEmpty)
                    const Text('No workpapers yet.')
                  else
                    ...vm.workpapers.map((wp) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _openWorkpaper(wp.id),
                        leading: const Icon(Icons.folder_open_outlined),
                        title: Text(wp.title),
                        subtitle: Text('${wp.type.toUpperCase()} • ${wp.status} • ${wp.updated}'),
                        trailing: const Icon(Icons.chevron_right),
                        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Vm {
  final EngagementModel engagement;
  final String clientName;
  final List<WorkpaperModel> workpapers;
  final RiskAssessmentModel risk;
  const _Vm({
    required this.engagement,
    required this.clientName,
    required this.workpapers,
    required this.risk,
  });
}

class _UnsavedPill extends StatelessWidget {
  const _UnsavedPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.tertiaryContainer,
        border: Border.all(color: cs.tertiary.withOpacity(0.45)),
      ),
      child: Text('Unsaved', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}