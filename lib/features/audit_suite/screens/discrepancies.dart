import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/discrepancy_model.dart';
import '../data/models/repositories/discrepancies_repository.dart';


class DiscrepanciesScreen extends StatefulWidget {
  const DiscrepanciesScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<DiscrepanciesScreen> createState() => _DiscrepanciesScreenState();
}

class _DiscrepanciesScreenState extends State<DiscrepanciesScreen> {
  late final DiscrepanciesRepository _repo;
  late Future<List<DiscrepancyModel>> _future;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = DiscrepanciesRepository(widget.store);
    _future = _repo.list(widget.engagementId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.list(widget.engagementId));
  }

  Future<void> _add() async {
    if (_busy) return;

    final created = await showDialog<_CreateDiscrepancyResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateDiscrepancyDialog(),
    );
    if (created == null) return;

    setState(() => _busy = true);
    try {
      final now = DateTime.now().toIso8601String();
      final d = DiscrepancyModel(
        id: 'disc_${DateTime.now().millisecondsSinceEpoch}',
        engagementId: widget.engagementId,
        title: created.title,
        description: created.description,
        amount: created.amount,
        status: 'open',
        assignedTo: created.assignedTo,
        createdAtIso: now,
        resolvedAtIso: '',
      );

      await _repo.upsert(d);
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAssigned(DiscrepancyModel d, String assignedTo) async {
    await _repo.upsert(d.copyWith(assignedTo: assignedTo));
    await _refresh();
  }

  Future<void> _toggleResolved(DiscrepancyModel d) async {
    final isOpen = d.isOpen;
    final next = d.copyWith(
      status: isOpen ? 'resolved' : 'open',
      resolvedAtIso: isOpen ? DateTime.now().toIso8601String() : '',
    );
    await _repo.upsert(next);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discrepancies'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: FutureBuilder<List<DiscrepancyModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <DiscrepancyModel>[];

          final open = list.where((d) => d.isOpen).toList();
          final total = open.fold<double>(0.0, (sum, d) => sum + d.amount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Pill(
                        text: '${open.length} open',
                        bg: cs.surfaceContainerHighest,
                        border: cs.onSurface.withOpacity(0.10),
                      ),
                      _Pill(
                        text: '\$${total.toStringAsFixed(2)} total',
                        bg: cs.surfaceContainerHighest,
                        border: cs.onSurface.withOpacity(0.10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (list.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.rule_folder_outlined),
                    title: const Text('No discrepancies yet'),
                    subtitle: const Text('Tap Add to create your first discrepancy.'),
                    onTap: _add,
                  ),
                )
              else
                ...list.map((d) {
                  final isOpen = d.isOpen;
                  final statusBg = isOpen ? cs.errorContainer : cs.secondaryContainer;
                  final statusBorder = isOpen ? cs.error.withOpacity(0.35) : cs.secondary.withOpacity(0.35);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.title,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                _Pill(
                                  text: isOpen ? 'OPEN' : 'RESOLVED',
                                  bg: statusBg,
                                  border: statusBorder,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.description.isEmpty ? '—' : d.description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withOpacity(0.70),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _Pill(
                                  text: '\$${d.amount.toStringAsFixed(2)}',
                                  bg: cs.surface,
                                  border: cs.onSurface.withOpacity(0.10),
                                ),
                                _Pill(
                                  text: 'Assigned: ${d.assignedTo.isEmpty ? "Unassigned" : d.assignedTo}',
                                  bg: cs.surface,
                                  border: cs.onSurface.withOpacity(0.10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: d.assignedTo.isEmpty ? null : d.assignedTo,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Assigned to',
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'Michael', child: Text('Michael')),
                                      DropdownMenuItem(value: 'Staff 1', child: Text('Staff 1')),
                                      DropdownMenuItem(value: 'Staff 2', child: Text('Staff 2')),
                                    ],
                                    onChanged: (v) => _setAssigned(d, v ?? ''),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: () => _toggleResolved(d),
                                  child: Text(isOpen ? 'Resolve' : 'Reopen'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.border});
  final String text;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CreateDiscrepancyResult {
  final String title;
  final String description;
  final double amount;
  final String assignedTo;

  const _CreateDiscrepancyResult({
    required this.title,
    required this.description,
    required this.amount,
    required this.assignedTo,
  });
}

class _CreateDiscrepancyDialog extends StatefulWidget {
  const _CreateDiscrepancyDialog();

  @override
  State<_CreateDiscrepancyDialog> createState() => _CreateDiscrepancyDialogState();
}

class _CreateDiscrepancyDialogState extends State<_CreateDiscrepancyDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _assignedTo = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

    Navigator.of(context).pop(
      _CreateDiscrepancyResult(
        title: title,
        description: _descCtrl.text.trim(),
        amount: amt < 0 ? -amt : amt,
        assignedTo: _assignedTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Discrepancy'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _assignedTo.isEmpty ? null : _assignedTo,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Assign to'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Unassigned')),
                  DropdownMenuItem(value: 'Michael', child: Text('Michael')),
                  DropdownMenuItem(value: 'Staff 1', child: Text('Staff 1')),
                  DropdownMenuItem(value: 'Staff 2', child: Text('Staff 2')),
                ],
                onChanged: (v) => setState(() => _assignedTo = v ?? ''),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}