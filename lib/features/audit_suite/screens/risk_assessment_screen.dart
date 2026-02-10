import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/risk_assessment_models.dart';
import '../data/models/repositories/risk_assessments_repository.dart';

class RiskAssessmentScreen extends StatefulWidget {
  const RiskAssessmentScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<RiskAssessmentScreen> createState() => _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState extends State<RiskAssessmentScreen> {
  late final RiskAssessmentsRepository _repo;

  RiskAssessmentModel? _loaded;
  late Future<void> _future;

  bool _busy = false;
  bool _changed = false; // tells parent to refresh
  bool _seeded = false;  // prevents false-dirty

  // editable items (copy of loaded.items)
  List<RiskItemModel> _items = const [];

  // notes controllers by item id
  final Map<String, TextEditingController> _notesCtrls = {};

  // snapshot to compare for dirty state
  String _baseFingerprint = '';

  static const _levelOptions = <String>['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _repo = RiskAssessmentsRepository(widget.store);
    _future = _load();
  }

  @override
  void dispose() {
    for (final c in _notesCtrls.values) {
      c.dispose();
    }
    _notesCtrls.clear();
    super.dispose();
  }

  Future<void> _load() async {
    final ra = await _repo.ensureForEngagement(widget.engagementId);
    _loaded = ra;

    _seeded = false;

    // clone items for local editing
    _items = ra.items.map((e) => e).toList(growable: true);

    // rebuild controllers
    for (final c in _notesCtrls.values) {
      c.dispose();
    }
    _notesCtrls.clear();

    for (final it in _items) {
      final ctrl = TextEditingController(text: it.notes);
      ctrl.addListener(() {
        if (!_seeded) return;
        if (mounted) setState(() {});
      });
      _notesCtrls[it.id] = ctrl;
    }

    // take base fingerprint AFTER seeding
    _baseFingerprint = _fingerprint(_items);

    _seeded = true;
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _isDirty {
    if (!_seeded) return false;
    return _fingerprint(_currentItemsFromControllers()) != _baseFingerprint;
  }

  String _fingerprint(List<RiskItemModel> items) {
    // stable JSON string for comparing changes
    final normalized = items
        .map((e) => {
              'id': e.id,
              'category': e.category,
              'prompt': e.prompt,
              'level': e.level,
              'score1to5': e.score1to5,
              'notes': e.notes,
            })
        .toList();

    // sort by id to be stable
    normalized.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return jsonEncode(normalized);
  }

  List<RiskItemModel> _currentItemsFromControllers() {
    return _items.map((it) {
      final ctrl = _notesCtrls[it.id];
      final notes = (ctrl?.text ?? it.notes).trim();
      return it.copyWith(notes: notes);
    }).toList(growable: false);
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;

    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved edits. If you leave now, they will be lost.',
        ),
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

  Future<void> _save() async {
    if (_busy || !_isDirty) return;

    final base = _loaded;
    if (base == null) return;

    setState(() => _busy = true);
    try {
      final current = _currentItemsFromControllers();

      final draft = base.copyWith(
        items: current,
        updated: '', // repo sets today
      );

      final saved = await _repo.upsert(draft);
      _loaded = saved;
      _changed = true;

      // reseed + reset dirty state
      _seeded = false;
      _items = saved.items.map((e) => e).toList(growable: true);

      for (final c in _notesCtrls.values) {
        c.dispose();
      }
      _notesCtrls.clear();

      for (final it in _items) {
        final ctrl = TextEditingController(text: it.notes);
        ctrl.addListener(() {
          if (!_seeded) return;
          if (mounted) setState(() {});
        });
        _notesCtrls[it.id] = ctrl;
      }

      _baseFingerprint = _fingerprint(_items);
      _seeded = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-Risk Assessment saved ✅')),
      );

      setState(() {});
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setLevel(String itemId, String level) {
    if (!_seeded) return;
    final idx = _items.indexWhere((x) => x.id == itemId);
    if (idx < 0) return;
    setState(() {
      _items[idx] = _items[idx].copyWith(level: level);
    });
  }

  void _setScore(String itemId, int score) {
    if (!_seeded) return;
    final s = score.clamp(1, 5);
    final idx = _items.indexWhere((x) => x.id == itemId);
    if (idx < 0) return;
    setState(() {
      _items[idx] = _items[idx].copyWith(score1to5: s);
    });
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
              const Text('Pre-Risk Assessment'),
              if (showDirty) ...[
                const SizedBox(width: 10),
                const _DirtyPill(label: 'Unsaved'),
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
              tooltip: 'Refresh',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Save',
              onPressed: (_busy || !_isDirty) ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<void>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [
                    SizedBox(height: 90),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
              }

              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 60),
                    const Icon(Icons.error_outline, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      'Failed to load risk assessment.',
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

              final ra = _loaded!;
              final overall = '${ra.overallLevel()} (${ra.overallScore1to5()}/5)';

              return AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Overall: $overall',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              ra.updated.trim().isEmpty ? '—' : ra.updated.trim(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._items.map((it) {
                      final notesCtrl = _notesCtrls[it.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.category,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(it.prompt),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _levelOptions.contains(it.level)
                                            ? it.level
                                            : 'Low',
                                        items: _levelOptions
                                            .map((v) => DropdownMenuItem(
                                                  value: v,
                                                  child: Text(v),
                                                ))
                                            .toList(),
                                        onChanged: (v) =>
                                            _setLevel(it.id, v ?? it.level),
                                        decoration: const InputDecoration(
                                          labelText: 'Level',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 140,
                                      child: DropdownButtonFormField<int>(
                                        initialValue: it.score1to5.clamp(1, 5),
                                        items: const [1, 2, 3, 4, 5]
                                            .map((v) => DropdownMenuItem(
                                                  value: v,
                                                  child: Text('$v'),
                                                ))
                                            .toList(),
                                        onChanged: (v) =>
                                            _setScore(it.id, v ?? it.score1to5),
                                        decoration: const InputDecoration(
                                          labelText: 'Score',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                TextField(
                                  controller: notesCtrl,
                                  maxLines: 3,
                                  textDirection:
                                      TextDirection.ltr, // ✅ fixes backwards typing
                                  decoration: const InputDecoration(
                                    labelText: 'Notes',
                                    border: OutlineInputBorder(),
                                    hintText: 'Add notes…',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: (_busy || !_isDirty) ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DirtyPill extends StatelessWidget {
  const _DirtyPill({required this.label});
  final String label;

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
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}