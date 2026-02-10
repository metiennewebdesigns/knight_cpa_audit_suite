import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/workpaper_models.dart';
import '../data/models/repositories/workpapers_repository.dart';


class WorkpapersListScreen extends StatefulWidget {
  const WorkpapersListScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<WorkpapersListScreen> createState() => _WorkpapersListScreenState();
}

class _WorkpapersListScreenState extends State<WorkpapersListScreen> {
  late final WorkpapersRepository _repo;

  late Future<List<WorkpaperModel>> _future;

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = WorkpapersRepository(widget.store);
    _future = _repo.getWorkpapers();

    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.clearCache();
      setState(() => _future = _repo.getWorkpapers());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<WorkpaperModel> _filter(List<WorkpaperModel> list) {
    if (_query.isEmpty) return list;
    return list.where((w) {
      final hay =
          '${w.title} ${w.status} ${w.type} ${w.updated} ${w.engagementId} ${w.id}'
              .toLowerCase();
      return hay.contains(_query);
    }).toList();
  }

  Future<void> _openWorkpaper(WorkpaperModel wp) async {
    if (_busy) return;
    final changed = await context.push<bool>('/workpapers/${wp.id}');
    if (changed == true) await _refresh();
  }

  Future<void> _deleteWorkpaper(WorkpaperModel wp) async {
    if (_busy) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Delete workpaper?'),
        content: Text('This will permanently delete:\n\n"${wp.title}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dc).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dc).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _repo.deleteById(wp.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workpaper deleted ✅')),
      );

      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workpapers'),
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
        child: FutureBuilder<List<WorkpaperModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return _ErrorState(
                title: 'Failed to load workpapers',
                message: snap.error.toString(),
                onRetry: _busy ? null : _refresh,
              );
            }

            final all = snap.data ?? const <WorkpaperModel>[];
            final filtered = _filter(all);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _SearchField(
                  controller: _searchCtrl,
                  hint: 'Search workpapers (title, status, type, engagement, id)…',
                ),
                const SizedBox(height: 12),

                if (all.isEmpty)
                  _EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No workpapers yet',
                    subtitle: 'Create workpapers inside an engagement.',
                    actionLabel: 'Go to Engagements',
                    onAction: () => context.go('/engagements'),
                  )
                else if (filtered.isEmpty)
                  _EmptyState(
                    icon: Icons.search_off,
                    title: 'No results',
                    subtitle: 'Try a different search.',
                    actionLabel: 'Clear search',
                    onAction: () {
                      _searchCtrl.clear();
                      FocusScope.of(context).unfocus();
                    },
                  )
                else
                  ...filtered.map((wp) {
                    final chips = <Widget>[
                      _Chip(text: 'Type: ${_typeLabel(wp.type)}'),
                      _Chip(text: 'Status: ${wp.status}'),
                      _Chip(text: 'Updated: ${_prettyMonth(wp.updated)}'),
                      _Chip(text: 'Eng: ${wp.engagementId}'),
                    ];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey('wp-${wp.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _deleteWorkpaper(wp);
                          return false; // we refresh ourselves
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: cs.onErrorContainer,
                          ),
                        ),
                        child: _LuxuryCard(
                          onTap: () => _openWorkpaper(wp),
                          child: Row(
                            children: [
                              _IconBadge(
                                icon: Icons.folder_open_outlined,
                                tone: cs.primary.withOpacity(0.14),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wp.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: chips,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.chevron_right,
                                  color: cs.onSurface.withOpacity(0.55)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ======================= UI building blocks ======================= */

class _LuxuryCard extends StatelessWidget {
  const _LuxuryCard({
    required this.child,
    this.onTap,
  });

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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.tone,
  });

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
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surface.withOpacity(0.55),
        border: Border.all(color: cs.onSurface.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.72),
            ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
  });

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
                tooltip: 'Clear',
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
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.chevron_right),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

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
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
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

/* ======================= Helpers ======================= */

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

String _typeLabel(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.isEmpty) return 'Unknown';
  if (t == 'xlsx') return 'Excel';
  if (t == 'pdf') return 'PDF';
  if (t == 'docx') return 'Word';
  return raw;
}