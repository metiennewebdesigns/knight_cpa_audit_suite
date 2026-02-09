import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/engagement_models.dart';
import '../data/models/risk_assessment_models.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';

class PreRiskAssessmentScreen extends StatefulWidget {
  const PreRiskAssessmentScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<PreRiskAssessmentScreen> createState() => _PreRiskAssessmentScreenState();
}

class _PreRiskAssessmentScreenState extends State<PreRiskAssessmentScreen> {
  late final RiskAssessmentsRepository _repo;
  late final EngagementsRepository _engRepo;

  RiskAssessmentModel? _loaded;
  EngagementModel? _engagement;

  late Future<void> _future;

  bool _busy = false;
  bool _changed = false;

  // Dirty state
  bool _seeded = false;
  String _seedJson = '';

  static const _levelOptions = <String>['Low', 'Medium', 'High'];
  static const _scoreOptions = <int>[1, 2, 3, 4, 5];

  bool get _isLocked => _engagement?.isFinalized ?? false;

  bool get _isDirty {
    if (!_seeded || _loaded == null) return false;
    final now = _loaded!.toJson().toString();
    return now != _seedJson;
  }

  @override
  void initState() {
    super.initState();
    _repo = RiskAssessmentsRepository(widget.store);
    _engRepo = EngagementsRepository(widget.store);
    _future = _load();
  }

  Future<void> _load() async {
    final eng = await _engRepo.getById(widget.engagementId);
    if (eng == null) {
      throw StateError('Engagement not found: ${widget.engagementId}');
    }

    final a = await _repo.ensureForEngagement(widget.engagementId);

    _engagement = eng;
    _loaded = a;

    _seeded = false;
    _seedJson = a.toJson().toString();
    _seeded = true;
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.clearCache();
      await _engRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Engagement is finalized (read-only).')),
      );
      return;
    }

    final base = _loaded;
    if (base == null) return;

    setState(() => _busy = true);
    try {
      final saved = await _repo.upsert(base.copyWith(updated: ''));
      _loaded = saved;
      _changed = true;

      _seeded = false;
      _seedJson = saved.toJson().toString();
      _seeded = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risk assessment saved ✅')),
      );

      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetToDefaults() async {
    if (_busy) return;
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Engagement is finalized (read-only).')),
      );
      return;
    }

    final base = _loaded;
    if (base == null) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text('This will overwrite your current answers.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dc).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dc).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final reset = RiskAssessmentModel.emptyForEngagement(base.engagementId).copyWith(id: base.id);
      final saved = await _repo.upsert(reset.copyWith(updated: ''));
      _loaded = saved;
      _changed = true;

      _seeded = false;
      _seedJson = saved.toJson().toString();
      _seeded = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset ✅')));

      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _updateItem(RiskItemModel updatedItem) {
    if (_isLocked) return;

    final base = _loaded;
    if (base == null) return;

    final items = base.items.map((it) => it.id == updatedItem.id ? updatedItem : it).toList();

    setState(() {
      _loaded = base.copyWith(items: items);
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showUnsaved = _isDirty && !_busy && !_isLocked;

    return WillPopScope(
      onWillPop: () async {
        context.pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Pre-Risk Assessment'),
              if (_isLocked) ...const [SizedBox(width: 10), _FinalizedPill()]
              else if (showUnsaved) ...const [SizedBox(width: 10), _UnsavedPill()],
            ],
          ),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_changed),
          ),
          actions: [
            IconButton(
              tooltip: 'Reset',
              onPressed: (_busy || _isLocked) ? null : _resetToDefaults,
              icon: const Icon(Icons.restart_alt),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Save',
              onPressed: (_busy || _isLocked) ? null : _save,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: FutureBuilder<void>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text(snap.error.toString()));
            }

            final a = _loaded!;
            final overallScore = a.overallScore1to5();
            final overallLevel = a.overallLevel();

            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Pill(text: 'Overall: $overallLevel', bg: Theme.of(context).colorScheme.surfaceContainerHighest),
                          _Pill(text: 'Score: $overallScore / 5', bg: Theme.of(context).colorScheme.surfaceContainerHighest),
                          _Pill(text: 'Updated: ${a.updated.isEmpty ? '—' : a.updated}', bg: Theme.of(context).colorScheme.surfaceContainerHighest),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLocked)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.lock),
                        title: Text('Finalized engagement (read-only)'),
                        subtitle: Text('Reopen the engagement to edit risk answers.'),
                      ),
                    ),
                  if (_isLocked) const SizedBox(height: 12),

                  ...a.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RiskItemCard(
                        locked: _isLocked,
                        item: item,
                        levelOptions: _levelOptions,
                        scoreOptions: _scoreOptions,
                        onChanged: _updateItem,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  FilledButton.icon(
                    onPressed: (_busy || _isLocked) ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Assessment'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RiskItemCard extends StatelessWidget {
  const _RiskItemCard({
    required this.locked,
    required this.item,
    required this.levelOptions,
    required this.scoreOptions,
    required this.onChanged,
  });

  final bool locked;
  final RiskItemModel item;
  final List<String> levelOptions;
  final List<int> scoreOptions;
  final ValueChanged<RiskItemModel> onChanged;

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: local controller (works fine here)
    final notesCtrl = TextEditingController(text: item.notes);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.category, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(item.prompt),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: levelOptions.contains(item.level) ? item.level : 'Low',
                    items: levelOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: locked ? null : (v) => onChanged(item.copyWith(level: v ?? item.level)),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Level'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: scoreOptions.contains(item.score1to5) ? item.score1to5 : 1,
                    items: scoreOptions.map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                    onChanged: locked ? null : (v) => onChanged(item.copyWith(score1to5: v ?? item.score1to5)),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Score'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              readOnly: locked,
              maxLines: 3,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Notes'),
              onChanged: locked ? null : (v) => onChanged(item.copyWith(notes: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg});
  final String text;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
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

class _FinalizedPill extends StatelessWidget {
  const _FinalizedPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.errorContainer,
        border: Border.all(color: cs.error.withOpacity(0.35)),
      ),
      child: Text('Finalized', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}