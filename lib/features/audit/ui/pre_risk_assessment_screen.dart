import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

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
  late final _key = 'pre_risk_assessment_${widget.engagementId}_v1';

  late Future<void> _future;

  bool _busy = false;
  bool _changed = false;

  // Simple demo assessment fields
  final _notesCtrl = TextEditingController();
  final _fraudCtrl = TextEditingController();
  final _controlsCtrl = TextEditingController();

  static const _riskLevels = <String>['Low', 'Moderate', 'High'];
  String _overallRisk = 'Moderate';

  // Optional yes/no toggles
  bool _newClient = false;
  bool _priorIssues = false;
  bool _complexRevenue = false;
  bool _goingConcern = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _fraudCtrl.dispose();
    _controlsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final raw = widget.store.prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return;

    final data = jsonDecode(raw) as Map<String, dynamic>;

    _overallRisk = (data['overallRisk'] ?? 'Moderate').toString();
    if (!_riskLevels.contains(_overallRisk)) _overallRisk = 'Moderate';

    _newClient = (data['newClient'] ?? false) == true;
    _priorIssues = (data['priorIssues'] ?? false) == true;
    _complexRevenue = (data['complexRevenue'] ?? false) == true;
    _goingConcern = (data['goingConcern'] ?? false) == true;

    _fraudCtrl.text = (data['fraudNotes'] ?? '').toString();
    _controlsCtrl.text = (data['controlsNotes'] ?? '').toString();
    _notesCtrl.text = (data['generalNotes'] ?? '').toString();
  }

  Map<String, dynamic> _serialize() => {
        'overallRisk': _overallRisk,
        'newClient': _newClient,
        'priorIssues': _priorIssues,
        'complexRevenue': _complexRevenue,
        'goingConcern': _goingConcern,
        'fraudNotes': _fraudCtrl.text.trim(),
        'controlsNotes': _controlsCtrl.text.trim(),
        'generalNotes': _notesCtrl.text.trim(),
        'updated': _todayIso(),
      };

  Future<void> _save() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await widget.store.prefs.setString(_key, jsonEncode(_serialize()));
      _changed = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-Risk Assessment saved ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset assessment?'),
        content: const Text('This will clear all saved pre-risk assessment data for this engagement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await widget.store.prefs.remove(_key);

      _overallRisk = 'Moderate';
      _newClient = false;
      _priorIssues = false;
      _complexRevenue = false;
      _goingConcern = false;
      _fraudCtrl.clear();
      _controlsCtrl.clear();
      _notesCtrl.clear();

      _changed = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment reset ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pre-Risk Assessment'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_changed),
          ),
          actions: [
            IconButton(
              tooltip: 'Save',
              onPressed: _busy ? null : _save,
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
        body: FutureBuilder<void>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 60),
                  const Icon(Icons.error_outline, size: 44),
                  const SizedBox(height: 10),
                  Text(
                    'Failed to load pre-risk assessment.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionCard(
                    title: 'Overall risk rating',
                    child: DropdownButtonFormField<String>(
                      value: _overallRisk,
                      items: _riskLevels
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _overallRisk = v ?? _overallRisk);
                        _changed = true;
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Risk flags',
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _newClient,
                          onChanged: (v) {
                            setState(() => _newClient = v);
                            _changed = true;
                          },
                          title: const Text('New client / first-year engagement'),
                        ),
                        SwitchListTile(
                          value: _priorIssues,
                          onChanged: (v) {
                            setState(() => _priorIssues = v);
                            _changed = true;
                          },
                          title: const Text('Prior audit issues / restatements'),
                        ),
                        SwitchListTile(
                          value: _complexRevenue,
                          onChanged: (v) {
                            setState(() => _complexRevenue = v);
                            _changed = true;
                          },
                          title: const Text('Complex revenue recognition'),
                        ),
                        SwitchListTile(
                          value: _goingConcern,
                          onChanged: (v) {
                            setState(() => _goingConcern = v);
                            _changed = true;
                          },
                          title: const Text('Going concern indicators'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Fraud considerations',
                    child: TextField(
                      controller: _fraudCtrl,
                      onChanged: (_) => _changed = true,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Notes about fraud risk, incentives/pressures, opportunities, overrides…',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Controls considerations',
                    child: TextField(
                      controller: _controlsCtrl,
                      onChanged: (_) => _changed = true,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Notes about internal controls design, walkthroughs needed, key controls…',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'General notes',
                    child: TextField(
                      controller: _notesCtrl,
                      onChanged: (_) => _changed = true,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Any other planning / risk notes…',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset'),
                      ),
                    ],
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

String _todayIso() {
  final d = DateTime.now();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}