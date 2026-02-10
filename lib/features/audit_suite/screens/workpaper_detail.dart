import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/workpaper_models.dart';
import '../data/models/repositories/workpapers_repository.dart';
import '../widgets/attachment_tile.dart';

class WorkpaperDetailScreen extends StatefulWidget {
  const WorkpaperDetailScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.workpaperId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String workpaperId;

  @override
  State<WorkpaperDetailScreen> createState() => _WorkpaperDetailScreenState();
}

class _WorkpaperDetailScreenState extends State<WorkpaperDetailScreen> {
  late final WorkpapersRepository _repo;

  WorkpaperModel? _loaded;
  late Future<void> _future;

  final _titleCtrl = TextEditingController();

  static const _typeValues = <String>['xlsx', 'pdf', 'docx'];
  static const _statusValues = <String>['Open', 'In Progress', 'Complete'];

  String _type = 'xlsx';
  String _status = 'Open';

  bool _busy = false;
  bool _changed = false;

  // Dirty-state
  bool _seeded = false;
  String _seedTitle = '';
  String _seedType = 'xlsx';
  String _seedStatus = 'Open';

  bool get _isDirty {
    if (!_seeded) return false;
    return _titleCtrl.text.trim() != _seedTitle ||
        _type != _seedType ||
        _status != _seedStatus;
  }

  @override
  void initState() {
    super.initState();
    _repo = WorkpapersRepository(widget.store);
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

  Future<void> _load() async {
    final wp = await _repo.getById(widget.workpaperId);
    if (wp == null) throw StateError('Workpaper not found: ${widget.workpaperId}');

    _loaded = wp;

    _seeded = false;
    _seedTitle = wp.title.trim();
    _seedType = _typeValues.contains(wp.type) ? wp.type : 'xlsx';
    _seedStatus = _statusValues.contains(wp.status) ? wp.status : 'Open';

    _titleCtrl.text = _seedTitle;
    _type = _seedType;
    _status = _seedStatus;
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

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;

    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved edits. If you leave now, they will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dc).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dc).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_isDirty) return;

    final base = _loaded;
    if (base == null) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final saved = await _repo.upsert(
        base.copyWith(
          title: title,
          type: _type,
          status: _status,
          updated: '', // repo sets today
        ),
      );

      _loaded = saved;
      _changed = true;

      // reseed to reset dirty
      _seeded = false;
      _seedTitle = saved.title.trim();
      _seedType = _typeValues.contains(saved.type) ? saved.type : 'xlsx';
      _seedStatus = _statusValues.contains(saved.status) ? saved.status : 'Open';

      _titleCtrl.text = _seedTitle;
      _type = _seedType;
      _status = _seedStatus;
      _seeded = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workpaper saved ✅')),
      );

      setState(() {});
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;

    final base = _loaded;
    if (base == null) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Delete workpaper?'),
        content: Text('This will permanently delete:\n\n"${base.title}"'),
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
      await _repo.deleteById(base.id);
      _changed = true;
      if (!mounted) return;
      context.pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachFile() async {
    if (_busy) return;
    final base = _loaded;
    if (base == null) return;

    final result = await FilePicker.platform.pickFiles(
      withData: false,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    final pickedPath = f.path;

    if (pickedPath == null || pickedPath.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file path')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final saved = await _repo.addAttachment(
        workpaperId: base.id,
        sourcePath: pickedPath,
        originalName: f.name,
        sizeBytes: f.size,
      );

      _loaded = saved;
      _changed = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment added ✅')),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attach failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAttachment(WorkpaperAttachmentModel a) async {
    if (_busy) return;
    final base = _loaded;
    if (base == null) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Remove attachment?'),
        content: Text('Remove:\n\n${a.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dc).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dc).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final saved = await _repo.removeAttachment(
        workpaperId: base.id,
        attachmentId: a.id,
      );

      _loaded = saved;
      _changed = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment removed ✅')),
      );

      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showUnsaved = _isDirty && !_busy;

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
              const Text('Workpaper'),
              if (showUnsaved) ...[
                const SizedBox(width: 10),
                _Pill(
                  text: 'Unsaved',
                  bg: cs.tertiaryContainer,
                  border: cs.tertiary.withOpacity(0.45),
                ),
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
              tooltip: 'Attach',
              onPressed: _busy ? null : _attachFile,
              icon: const Icon(Icons.attach_file),
            ),
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
        body: FutureBuilder<void>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return _ErrorState(
                title: 'Failed to load workpaper',
                message: snap.error.toString(),
                onRetry: _busy ? null : _refresh,
              );
            }

            final wp = _loaded!;

            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  _HeaderCard(
                    icon: Icons.folder_open_outlined,
                    title: wp.title,
                    subtitle: 'Engagement: ${wp.engagementId} • Updated ${wp.updated.isEmpty ? "—" : wp.updated}',
                    trailing: _Pill(
                      text: _typeLabel(wp.type),
                      bg: cs.primary.withOpacity(0.14),
                      border: cs.primary.withOpacity(0.35),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Editor
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workpaper Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.15,
                                ),
                          ),
                          const SizedBox(height: 12),

                          Text('Title', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Enter workpaper title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Type', style: Theme.of(context).textTheme.labelLarge),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: _type,
                                      items: _typeValues
                                          .map((v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(_typeLabel(v)),
                                              ))
                                          .toList(),
                                      onChanged: (v) => setState(() => _type = v ?? _type),
                                      decoration: const InputDecoration(border: OutlineInputBorder()),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status', style: Theme.of(context).textTheme.labelLarge),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: _status,
                                      items: _statusValues
                                          .map((v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v),
                                              ))
                                          .toList(),
                                      onChanged: (v) => setState(() => _status = v ?? _status),
                                      decoration: const InputDecoration(border: OutlineInputBorder()),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: (_busy || !_isDirty) ? null : _save,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _delete,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Attachments
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Attachments',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _attachFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Attach'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (wp.attachments.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.inbox_outlined, color: cs.onSurface.withOpacity(0.70)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No attachments yet. Tap Attach to add a file.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurface.withOpacity(0.72),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...wp.attachments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AttachmentTile(
                          attachment: a,
                          onDelete: () => _removeAttachment(a),
                        ),
                      ),
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

/* ======================= UI helpers ======================= */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.primary.withOpacity(0.14),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.70),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
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

String _typeLabel(String raw) {
  final t = raw.trim().toLowerCase();
  if (t == 'xlsx') return 'Excel';
  if (t == 'pdf') return 'PDF';
  if (t == 'docx') return 'Word';
  return raw;
}