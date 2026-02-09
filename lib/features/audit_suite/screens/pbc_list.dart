import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';

import '../services/preparer_profile.dart';
import '../services/client_meta.dart';
import '../services/evidence_ledger.dart';
import '../services/pbc_store.dart';

class PbcListScreen extends StatefulWidget {
  const PbcListScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<PbcListScreen> createState() => _PbcListScreenState();
}

enum _PbcStatus { requested, received, reviewed }

class _PbcItem {
  final String id;
  final String title;
  final String category;
  final _PbcStatus status;
  final String requestedAt;
  final String receivedAt;
  final String reviewedAt;
  final String notes;

  final String attachmentName;
  final String attachmentPath;
  final String attachmentSha256;
  final int attachmentBytes;

  const _PbcItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.requestedAt,
    required this.receivedAt,
    required this.reviewedAt,
    required this.notes,
    required this.attachmentName,
    required this.attachmentPath,
    required this.attachmentSha256,
    required this.attachmentBytes,
  });

  _PbcItem copyWith({
    String? id,
    String? title,
    String? category,
    _PbcStatus? status,
    String? requestedAt,
    String? receivedAt,
    String? reviewedAt,
    String? notes,
    String? attachmentName,
    String? attachmentPath,
    String? attachmentSha256,
    int? attachmentBytes,
  }) {
    return _PbcItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      notes: notes ?? this.notes,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentSha256: attachmentSha256 ?? this.attachmentSha256,
      attachmentBytes: attachmentBytes ?? this.attachmentBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'status': status.name,
        'requestedAt': requestedAt,
        'receivedAt': receivedAt,
        'reviewedAt': reviewedAt,
        'notes': notes,
        'attachmentName': attachmentName,
        'attachmentPath': attachmentPath,
        'attachmentSha256': attachmentSha256,
        'attachmentBytes': attachmentBytes,
      };

  static _PbcItem fromJson(Map<String, dynamic> j) {
    _PbcStatus parseStatus(String s) {
      switch (s) {
        case 'received':
          return _PbcStatus.received;
        case 'reviewed':
          return _PbcStatus.reviewed;
        case 'requested':
        default:
          return _PbcStatus.requested;
      }
    }

    return _PbcItem(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      category: (j['category'] ?? 'General').toString(),
      status: parseStatus((j['status'] ?? 'requested').toString()),
      requestedAt: (j['requestedAt'] ?? '').toString(),
      receivedAt: (j['receivedAt'] ?? '').toString(),
      reviewedAt: (j['reviewedAt'] ?? '').toString(),
      notes: (j['notes'] ?? '').toString(),
      attachmentName: (j['attachmentName'] ?? '').toString(),
      attachmentPath: (j['attachmentPath'] ?? '').toString(),
      attachmentSha256: (j['attachmentSha256'] ?? '').toString(),
      attachmentBytes: (j['attachmentBytes'] is int) ? (j['attachmentBytes'] as int) : int.tryParse('${j['attachmentBytes'] ?? 0}') ?? 0,
    );
  }
}

class _PbcListScreenState extends State<PbcListScreen> {
  static const int _overdueDays = 7;

  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;

  bool _busy = false;
  bool _changed = false;

  String _clientId = '';
  String _clientName = '';
  String _clientAddressLine = '';

  String _preparerName = 'Independent Auditor';
  String _preparerLine2 = '';

  List<_PbcItem> _items = [];
  _PbcStatus? _filter;

  bool get _canFile => !kIsWeb && widget.store.canUseFileSystem;

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
    _init();
  }

  Future<void> _init() async {
    setState(() => _busy = true);
    try {
      final eng = await _engRepo.getById(widget.engagementId);
      if (eng != null) {
        _clientId = eng.clientId;
        final client = await _clientsRepo.getById(eng.clientId);
        _clientName = (client?.name ?? eng.clientId).toString();

        final addr = await ClientMeta.readAddress(eng.clientId);
        _clientAddressLine = ClientMeta.formatSingleLine(addr);
      }

      final preparer = await PreparerProfile.read();
      _preparerName = (preparer['name'] ?? 'Independent Auditor').toString();
      _preparerLine2 = (preparer['line2'] ?? '').toString().trim();

      final rawItems = await PbcStore.loadRaw(widget.engagementId);
      _items = rawItems.map(_PbcItem.fromJson).toList();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persist() async {
    await PbcStore.saveRaw(widget.engagementId, _items.map((e) => e.toJson()).toList());
  }

  String _nowIso() => DateTime.now().toIso8601String();
  String _newId() => 'pbc_${DateTime.now().millisecondsSinceEpoch}';

  List<_PbcItem> get _filtered => _filter == null ? _items : _items.where((i) => i.status == _filter).toList();
  int _count(_PbcStatus s) => _items.where((i) => i.status == s).length;

  DateTime? _parseAnyIso(String s) => DateTime.tryParse(s.trim());
  int _daysSince(String iso) => _parseAnyIso(iso) == null ? 0 : DateTime.now().difference(_parseAnyIso(iso)!).inDays;

  bool _isOverdue(_PbcItem item) => item.status == _PbcStatus.requested && _daysSince(item.requestedAt) >= _overdueDays;
  int _overdueCount() => _items.where(_isOverdue).length;

  Future<_PbcItem> _attachEvidence(_PbcItem item) async {
    if (!_canFile) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evidence attach is disabled on web demo.')));
      }
      return item;
    }

    final res = await FilePicker.platform.pickFiles(allowMultiple: false, withData: false);
    if (res == null || res.files.isEmpty) return item;

    final path = res.files.single.path;
    if (path == null || path.trim().isEmpty) return item;

    final entry = await EvidenceLedger.importAndRecord(
      engagementId: widget.engagementId,
      clientId: _clientId,
      kind: 'pbc_received',
      logicalKey: 'pbc:${item.id}',
      sourcePath: path,
      note: 'PBC received: ${item.title}',
    );

    if (entry == null) return item;

    return item.copyWith(
      attachmentName: entry.fileName,
      attachmentPath: entry.filePath,
      attachmentSha256: entry.sha256,
      attachmentBytes: entry.bytes,
    );
  }

  Future<void> _setStatus(_PbcItem item, _PbcStatus status) async {
    if (_busy) return;

    final idx = _items.indexWhere((x) => x.id == item.id);
    if (idx < 0) return;

    final now = _nowIso();
    _PbcItem updated = item.copyWith(status: status);

    if (status == _PbcStatus.requested) {
      updated = updated.copyWith(
        requestedAt: item.requestedAt.isEmpty ? now : item.requestedAt,
        receivedAt: '',
        reviewedAt: '',
        attachmentName: '',
        attachmentPath: '',
        attachmentSha256: '',
        attachmentBytes: 0,
      );
    } else if (status == _PbcStatus.received) {
      updated = updated.copyWith(receivedAt: item.receivedAt.isEmpty ? now : item.receivedAt, reviewedAt: '');

      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dc) => AlertDialog(
          title: const Text('Attach evidence file?'),
          content: const Text('To support chain-of-custody, attach the client-provided file now.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dc).pop(false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.of(dc).pop(true), child: const Text('Attach')),
          ],
        ),
      );

      if (ok == true) {
        updated = await _attachEvidence(updated);
      }
    } else if (status == _PbcStatus.reviewed) {
      updated = updated.copyWith(reviewedAt: item.reviewedAt.isEmpty ? now : item.reviewedAt);
    }

    setState(() {
      final copy = [..._items];
      copy[idx] = updated;
      _items = copy;
      _changed = true;
    });

    await _persist();
  }

  Future<void> _deleteItem(_PbcItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove:\n\n${item.title}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dc).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dc).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _items = _items.where((x) => x.id != item.id).toList();
      _changed = true;
    });
    await _persist();
  }

  Future<void> _addCustomItem() async {
    if (_busy) return;
    final created = await showDialog<_PbcItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddPbcItemDialog(nowIso: () => DateTime.now().toIso8601String()),
    );
    if (created == null) return;

    setState(() {
      _items = [..._items, created.copyWith(id: _newId())];
      _changed = true;
    });
    await _persist();
  }

  String _singleItemReminderText(_PbcItem item) {
    final who = _clientName.isEmpty ? 'Team' : _clientName;
    final days = _daysSince(item.requestedAt);

    return '''
Subject: PBC Reminder – ${widget.engagementId}

Hello $who,

This is a friendly reminder for the following outstanding PBC item (requested ${days} day(s) ago):

• ${item.title}

If the item is unavailable, please reply with an expected delivery date.

Thank you,
$_preparerName
Powered by Auditron
''';
  }

  Future<void> _copyReminderForItem(_PbcItem item) async {
    await Clipboard.setData(ClipboardData(text: _singleItemReminderText(item)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder copied ✅')));
  }

  Future<void> _copyEmailText() async {
    final requested = _items.where((i) => i.status == _PbcStatus.requested).toList();
    final lines = requested.isEmpty ? 'All PBC items are currently received/reviewed.' : requested.map((i) => '• ${i.title}').join('\n');

    final text = '''
Subject: PBC Request – ${widget.engagementId}

Hello ${_clientName.isEmpty ? 'Team' : _clientName},

As part of our audit planning/fieldwork, please provide the following items (PBC). If an item is unavailable, please reply with an expected delivery date.

$lines

Thank you,
$_preparerName
Powered by Auditron
''';

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email request text copied ✅')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overdue = _overdueCount();

    return WillPopScope(
      onWillPop: () async {
        context.pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PBC Builder'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_changed),
          ),
          actions: [
            IconButton(
              tooltip: 'Copy Email Text',
              onPressed: _busy ? null : _copyEmailText,
              icon: const Icon(Icons.content_copy),
            ),
          ],
        ),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  if (!_canFile)
                    Card(
                      color: cs.surfaceVariant,
                      child: const ListTile(
                        leading: Icon(Icons.public),
                        title: Text('Web demo mode'),
                        subtitle: Text('PBC local storage & evidence attach are disabled on web.'),
                      ),
                    ),
                  if (!_canFile) const SizedBox(height: 12),

                  _HeaderCard(
                    title: 'Provided-By-Client (PBC)',
                    subtitle:
                        'Requested ${_count(_PbcStatus.requested)} • Received ${_count(_PbcStatus.received)} • Reviewed ${_count(_PbcStatus.reviewed)}'
                        '${overdue > 0 ? ' • Overdue $overdue' : ''}',
                    right: _Pill(
                      text: 'General',
                      bg: cs.primary.withOpacity(0.14),
                      border: cs.primary.withOpacity(0.35),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _FilterRow(current: _filter, onChanged: (v) => setState(() => _filter = v)),
                  const SizedBox(height: 12),

                  FilledButton.icon(
                    onPressed: _busy ? null : _addCustomItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add custom PBC item'),
                  ),
                  const SizedBox(height: 12),

                  if (_filtered.isEmpty)
                    _EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No items',
                      subtitle: _filter == null ? 'Add a custom item to begin.' : 'No items match this filter.',
                    )
                  else
                    ..._filtered.map(
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PbcRow(
                          item: i,
                          overdueDays: _daysSince(i.requestedAt),
                          isOverdue: _isOverdue(i),
                          canAttachEvidence: _canFile,
                          onCopyReminder: () => _copyReminderForItem(i),
                          onRequested: () => _setStatus(i, _PbcStatus.requested),
                          onReceived: () => _setStatus(i, _PbcStatus.received),
                          onReviewed: () => _setStatus(i, _PbcStatus.reviewed),
                          onDelete: () => _deleteItem(i),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/* ===================== UI ===================== */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.subtitle, required this.right});
  final String title;
  final String subtitle;
  final Widget right;

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
                color: cs.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: const Icon(Icons.fact_check_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2)),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.70))),
              ]),
            ),
            const SizedBox(width: 10),
            right,
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.current, required this.onChanged});
  final _PbcStatus? current;
  final ValueChanged<_PbcStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterChip(label: 'All', selected: current == null, onTap: () => onChanged(null)),
        _FilterChip(label: 'Requested', selected: current == _PbcStatus.requested, onTap: () => onChanged(_PbcStatus.requested)),
        _FilterChip(label: 'Received', selected: current == _PbcStatus.received, onTap: () => onChanged(_PbcStatus.received)),
        _FilterChip(label: 'Reviewed', selected: current == _PbcStatus.reviewed, onTap: () => onChanged(_PbcStatus.reviewed)),
      ],
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
      color: selected ? cs.primary.withOpacity(0.18) : cs.surfaceVariant,
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
          child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _PbcRow extends StatelessWidget {
  const _PbcRow({
    required this.item,
    required this.overdueDays,
    required this.isOverdue,
    required this.canAttachEvidence,
    required this.onCopyReminder,
    required this.onRequested,
    required this.onReceived,
    required this.onReviewed,
    required this.onDelete,
  });

  final _PbcItem item;
  final int overdueDays;
  final bool isOverdue;
  final bool canAttachEvidence;

  final VoidCallback onCopyReminder;
  final VoidCallback onRequested;
  final VoidCallback onReceived;
  final VoidCallback onReviewed;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String statusLabel;
    switch (item.status) {
      case _PbcStatus.requested:
        statusLabel = 'Requested';
        break;
      case _PbcStatus.received:
        statusLabel = 'Received';
        break;
      case _PbcStatus.reviewed:
        statusLabel = 'Reviewed';
        break;
    }

    final hasAttachment = item.attachmentPath.trim().isNotEmpty && item.attachmentSha256.trim().isNotEmpty;

    return Material(
      color: cs.surfaceVariant,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2))),
              const SizedBox(width: 10),
              _Pill(text: statusLabel, bg: cs.surface, border: cs.onSurface.withOpacity(0.12)),
              IconButton(tooltip: 'Copy reminder', onPressed: onCopyReminder, icon: const Icon(Icons.copy)),
              IconButton(tooltip: 'Remove', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(text: '[${item.category}]', bg: cs.surface, border: cs.onSurface.withOpacity(0.10)),
              if (isOverdue) _Pill(text: 'Overdue (${overdueDays}d)', bg: cs.errorContainer, border: cs.error.withOpacity(0.40)),
              if (!canAttachEvidence) _Pill(text: 'Evidence disabled (web)', bg: cs.surface, border: cs.onSurface.withOpacity(0.10)),
            ],
          ),
          const SizedBox(height: 10),
          if (hasAttachment) ...[
            _Pill(text: 'Evidence attached ✅', bg: cs.secondaryContainer, border: cs.secondary.withOpacity(0.35)),
            const SizedBox(height: 6),
            Text(
              'SHA-256: ${item.attachmentSha256.substring(0, 12)}…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: cs.onSurface.withOpacity(0.70)),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(onPressed: onRequested, child: const Text('Requested')),
              OutlinedButton(onPressed: onReceived, child: const Text('Received')),
              OutlinedButton(onPressed: onReviewed, child: const Text('Reviewed')),
            ],
          ),
        ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 46),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AddPbcItemDialog extends StatefulWidget {
  const _AddPbcItemDialog({required this.nowIso});
  final String Function() nowIso;

  @override
  State<_AddPbcItemDialog> createState() => _AddPbcItemDialogState();
}

class _AddPbcItemDialogState extends State<_AddPbcItemDialog> {
  final _titleCtrl = TextEditingController();
  final _catCtrl = TextEditingController(text: 'General');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _titleCtrl.text.trim();
    if (t.isEmpty) return;

    Navigator.of(context).pop(
      _PbcItem(
        id: '',
        title: t,
        category: _catCtrl.text.trim().isEmpty ? 'General' : _catCtrl.text.trim(),
        status: _PbcStatus.requested,
        requestedAt: widget.nowIso(),
        receivedAt: '',
        reviewedAt: '',
        notes: '',
        attachmentName: '',
        attachmentPath: '',
        attachmentSha256: '',
        attachmentBytes: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add PBC Item'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item', border: OutlineInputBorder()),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _catCtrl,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}