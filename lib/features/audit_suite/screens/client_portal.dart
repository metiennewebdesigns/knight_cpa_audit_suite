import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

import '../data/models/repositories/engagements_repository.dart';
import '../services/evidence_ledger.dart';
import '../services/client_portal_fs.dart';

class ClientPortalScreen extends StatefulWidget {
  const ClientPortalScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
    this.initialPin,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  /// pin from query: /engagements/:id/client-portal?pin=123456
  final String? initialPin;

  @override
  State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen> {
  bool _busy = false;
  bool _unlocked = false;

  final _pinCtrl = TextEditingController();

  // Engagement meta
  String _storedPin = '';
  String _dueDateIso = '';

  // Engagement status
  bool _portalClosed = false;

  // PBC view model
  List<_PbcItemVm> _pbcItems = const [];
  int _overdueCount = 0;

  // Recent uploads (from ledger)
  late Future<List<EvidenceLedgerEntry>> _uploadsFuture;

  bool get _uploadsEnabled => !kIsWeb && widget.store.canUseFileSystem;

  @override
  void initState() {
    super.initState();
    _uploadsFuture = EvidenceLedger.readAll(widget.engagementId);
    _boot();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ======================= Boot / Refresh ======================= */

  Future<void> _boot() async {
    // portal closed if engagement finalized
    try {
      final engRepo = EngagementsRepository(widget.store);
      final eng = await engRepo.getById(widget.engagementId);
      _portalClosed = (eng?.status ?? '').trim().toLowerCase() == 'finalized';
    } catch (_) {
      _portalClosed = false;
    }

    final meta = await ClientPortalFs.readEngagementMeta(widget.engagementId);
    _storedPin = (meta['clientPortalPin'] ?? '').toString().trim();
    _dueDateIso = (meta['dueDate'] ?? '').toString().trim();

    // PBC items
    _pbcItems = await _readPbcItems(widget.engagementId);
    _overdueCount = _pbcItems.where((x) => x.isOverdue).length;

    // Autofill pin from query and auto-unlock if matches
    final q = (widget.initialPin ?? '').trim();
    if (q.isNotEmpty) {
      _pinCtrl.text = q;
      if (_storedPin.isNotEmpty && q == _storedPin) {
        _unlocked = true;
        await ClientPortalFs.logPortalEvent(
          engagementId: widget.engagementId,
          kind: 'auto_unlock',
          note: 'Query pin matched',
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _boot();
      setState(() {
        _uploadsFuture = EvidenceLedger.readAll(widget.engagementId);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _pinConfigured => _storedPin.isNotEmpty;

  bool get _isOverdue {
    final due = DateTime.tryParse(_dueDateIso);
    if (due == null) return false;
    final today = DateTime.now();
    final d = DateTime(due.year, due.month, due.day);
    final t = DateTime(today.year, today.month, today.day);
    return t.isAfter(d);
  }

  String get _dueLabel => _dueDateIso.trim().isEmpty ? '—' : _dueDateIso.trim();

  /* ======================= Unlock flow ======================= */

  Future<void> _tryUnlock() async {
    if (_busy) return;
    if (!_pinConfigured) return;

    final entered = _pinCtrl.text.trim();
    if (entered.isEmpty) return;

    if (entered != _storedPin) {
      _snack('Incorrect PIN');
      await ClientPortalFs.logPortalEvent(
        engagementId: widget.engagementId,
        kind: 'unlock_failed',
        note: 'Incorrect pin',
      );
      return;
    }

    setState(() => _unlocked = true);
    await ClientPortalFs.logPortalEvent(
      engagementId: widget.engagementId,
      kind: 'unlock_success',
      note: 'PIN matched',
    );
  }

  /* ======================= Reminder email ======================= */

  Future<void> _copyOverdueReminderEmail() async {
    final pin = _storedPin;
    final link = '/engagements/${widget.engagementId}/client-portal?pin=$pin';

    final subject = 'Reminder: Please upload overdue audit items';
    final body = '''
Hello,

This is a friendly reminder to upload the overdue requested items in your Auditron Client Portal.

Engagement ID: ${widget.engagementId}
Portal link: $link
PIN: $pin

If you have already uploaded the requested items, please disregard this message.

Thank you,
''';

    await Clipboard.setData(ClipboardData(text: 'Subject: $subject\n\n$body'));
    _snack('Overdue reminder email copied ✅');

    await ClientPortalFs.logPortalEvent(
      engagementId: widget.engagementId,
      kind: 'copy_overdue_email',
      note: 'Copied reminder email',
    );
  }

  /* ======================= Upload mapped to PBC item ======================= */

  Future<void> _uploadForItem(_PbcItemVm item) async {
    if (_busy) return;
    if (!_unlocked) return;

    if (_portalClosed) {
      _snack('Portal is closed (engagement finalized).');
      return;
    }

    if (!_uploadsEnabled) {
      _snack('Uploads are disabled in web demo.');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(withData: false);
      if (res == null || res.files.isEmpty) return;

      final picked = res.files.first;
      final srcPath = picked.path;
      if (srcPath == null || srcPath.trim().isEmpty) return;

      final saved = await ClientPortalFs.saveToVaultAndLedger(
        engagementId: widget.engagementId,
        sourcePath: srcPath,
        originalName: picked.name,
        pbcItemId: item.id,
        pbcItemTitle: item.title,
      );

      await ClientPortalFs.markPbcItemReceived(widget.engagementId, item.id);

      await _boot();
      setState(() {
        _uploadsFuture = EvidenceLedger.readAll(widget.engagementId);
      });

      _snack('Uploaded for "${item.title}" ✅');

      await ClientPortalFs.logPortalEvent(
        engagementId: widget.engagementId,
        kind: 'upload',
        note: saved.fileName,
        extra: {
          'fileName': saved.fileName,
          'sha256': saved.sha256,
          'bytes': saved.bytes,
          'pbcItemId': item.id,
          'pbcItemTitle': item.title,
        },
      );
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ======================= PBC read ======================= */

  Future<List<_PbcItemVm>> _readPbcItems(String engagementId) async {
    try {
      final items = await ClientPortalFs.readPbcItemsRaw(engagementId);

      final out = <_PbcItemVm>[];
      for (final it in items) {
        final id = (it['id'] ?? '').toString().trim();
        final title = (it['title'] ?? it['name'] ?? 'Requested item').toString().trim();
        final status = (it['status'] ?? 'requested').toString().trim().toLowerCase();
        final requestedAt = (it['requestedAt'] ?? '').toString().trim();
        final receivedAt = (it['receivedAt'] ?? '').toString().trim();
        final reviewedAt = (it['reviewedAt'] ?? '').toString().trim();

        out.add(
          _PbcItemVm(
            id: id.isEmpty ? _fallbackKey(title) : id,
            title: title.isEmpty ? 'Requested item' : title,
            status: status,
            requestedAt: requestedAt,
            receivedAt: receivedAt,
            reviewedAt: reviewedAt,
          ),
        );
      }

      out.sort((a, b) => a._sortRank.compareTo(b._sortRank));
      return out;
    } catch (_) {
      return const [];
    }
  }

  String _fallbackKey(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  String _prettyWhenIso(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso.isEmpty ? '—' : iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /* ======================= UI ======================= */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final overduePill = (_overdueCount > 0 || _isOverdue)
        ? _Pill(
            text: _overdueCount > 0 ? 'Overdue $_overdueCount' : 'Overdue',
            bg: cs.errorContainer,
            border: cs.error.withOpacity(0.35),
          )
        : null;

    final portalClosedPill = _portalClosed
        ? _Pill(
            text: 'PORTAL CLOSED',
            bg: cs.surfaceVariant,
            border: cs.onSurface.withOpacity(0.12),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Portal'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        children: [
          _InstructionsCard(
            dueDate: _dueLabel,
            overduePill: overduePill,
            portalClosedPill: portalClosedPill,
            pinConfigured: _pinConfigured,
            unlocked: _unlocked,
            overdueCount: _overdueCount,
            uploadsEnabled: _uploadsEnabled,
          ),
          const SizedBox(height: 12),

          if (!_pinConfigured)
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Access not configured'),
                subtitle: const Text('Ask your auditor to generate a Client Portal PIN for this engagement.'),
              ),
            )
          else if (!_unlocked)
            _PinCard(
              pinCtrl: _pinCtrl,
              busy: _busy,
              onUnlock: _tryUnlock,
            )
          else
            _UnlockedPortal(
              busy: _busy,
              portalClosed: _portalClosed,
              uploadsEnabled: _uploadsEnabled,
              onUploadItem: _uploadForItem,
              pbcItems: _pbcItems,
              uploadsFuture: _uploadsFuture,
              prettyWhenIso: _prettyWhenIso,
              overdueCount: _overdueCount,
              onCopyReminder: _copyOverdueReminderEmail,
            ),
        ],
      ),
    );
  }
}

class _PbcItemVm {
  final String id;
  final String title;
  final String status;
  final String requestedAt;
  final String receivedAt;
  final String reviewedAt;

  const _PbcItemVm({
    required this.id,
    required this.title,
    required this.status,
    required this.requestedAt,
    required this.receivedAt,
    required this.reviewedAt,
  });

  bool get isOverdue {
    if (status.toLowerCase() != 'requested') return false;
    final dt = DateTime.tryParse(requestedAt);
    if (dt == null) return false;
    return DateTime.now().difference(dt).inDays >= 7;
  }

  int get _sortRank {
    final s = status.toLowerCase();
    if (s == 'requested') return 0;
    if (s == 'received') return 1;
    if (s == 'reviewed') return 2;
    return 3;
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.pinCtrl,
    required this.busy,
    required this.onUnlock,
  });

  final TextEditingController pinCtrl;
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter PIN',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '6-digit PIN',
              ),
              onSubmitted: (_) => onUnlock(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onUnlock,
              icon: const Icon(Icons.lock_open),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockedPortal extends StatelessWidget {
  const _UnlockedPortal({
    required this.busy,
    required this.portalClosed,
    required this.uploadsEnabled,
    required this.onUploadItem,
    required this.pbcItems,
    required this.uploadsFuture,
    required this.prettyWhenIso,
    required this.overdueCount,
    required this.onCopyReminder,
  });

  final bool busy;
  final bool portalClosed;
  final bool uploadsEnabled;
  final Future<void> Function(_PbcItemVm item) onUploadItem;

  final List<_PbcItemVm> pbcItems;

  final Future<List<EvidenceLedgerEntry>> uploadsFuture;
  final String Function(String) prettyWhenIso;

  final int overdueCount;
  final VoidCallback onCopyReminder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requested Items',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 10),

        if (!uploadsEnabled)
          Card(
            color: cs.surfaceVariant,
            child: const ListTile(
              leading: Icon(Icons.public),
              title: Text('Web demo mode'),
              subtitle: Text('Uploads and local evidence vault are disabled on web.'),
            ),
          ),

        const SizedBox(height: 10),

        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PBC Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 10),

                if (pbcItems.isEmpty)
                  Text(
                    'No requested items found.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.70),
                        ),
                  )
                else
                  ...pbcItems.map((it) {
                    final s = it.status.toLowerCase();
                    final isRequested = s == 'requested';
                    final isReceived = s == 'received';
                    final isReviewed = s == 'reviewed';

                    Color bg = cs.surfaceVariant;
                    Color border = cs.onSurface.withOpacity(0.10);
                    String chip = 'Requested';

                    if (isReviewed) {
                      chip = 'Reviewed';
                      bg = cs.secondaryContainer;
                      border = cs.secondary.withOpacity(0.35);
                    } else if (isReceived) {
                      chip = 'Received';
                      bg = cs.tertiaryContainer;
                      border = cs.tertiary.withOpacity(0.35);
                    } else if (isRequested) {
                      chip = it.isOverdue ? 'Overdue' : 'Requested';
                      bg = it.isOverdue ? cs.errorContainer : cs.surfaceVariant;
                      border = it.isOverdue ? cs.error.withOpacity(0.35) : cs.onSurface.withOpacity(0.10);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.onSurface.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isRequested
                                        ? (it.requestedAt.isEmpty ? '' : 'Requested: ${prettyWhenIso(it.requestedAt)}')
                                        : isReceived
                                            ? (it.receivedAt.isEmpty ? '' : 'Received: ${prettyWhenIso(it.receivedAt)}')
                                            : (it.reviewedAt.isEmpty ? '' : 'Reviewed: ${prettyWhenIso(it.reviewedAt)}'),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: cs.onSurface.withOpacity(0.70),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _Pill(text: chip, bg: bg, border: border),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: (busy || portalClosed || isReviewed || !uploadsEnabled)
                                  ? null
                                  : () => onUploadItem(it),
                              icon: const Icon(Icons.upload_file),
                              label: Text(portalClosed ? 'Closed' : 'Upload'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Recent Uploads',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 10),

        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: FutureBuilder<List<EvidenceLedgerEntry>>(
              future: uploadsFuture,
              builder: (context, snap) {
                final list = (snap.data ?? const <EvidenceLedgerEntry>[]);
                final recent = list.reversed.take(10).toList();

                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (recent.isEmpty) {
                  return Text(
                    'No uploads yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.70),
                        ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in recent) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.onSurface.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${prettyWhenIso(e.ts)} • SHA ${e.sha256.substring(0, e.sha256.length >= 12 ? 12 : e.sha256.length)}…',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: cs.onSurface.withOpacity(0.70),
                                          fontFamily: 'monospace',
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (overdueCount > 0)
          FilledButton.icon(
            onPressed: busy ? null : onCopyReminder,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Copy Overdue Reminder Email'),
          ),
      ],
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({
    required this.dueDate,
    required this.overduePill,
    required this.portalClosedPill,
    required this.pinConfigured,
    required this.unlocked,
    required this.overdueCount,
    required this.uploadsEnabled,
  });

  final String dueDate;
  final Widget? overduePill;
  final Widget? portalClosedPill;
  final bool pinConfigured;
  final bool unlocked;
  final int overdueCount;
  final bool uploadsEnabled;

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
              'Client-friendly instructions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Pill(
                  text: 'Due: $dueDate',
                  bg: cs.surfaceVariant,
                  border: cs.onSurface.withOpacity(0.10),
                ),
                if (overduePill != null) overduePill!,
                if (portalClosedPill != null) portalClosedPill!,
                _Pill(
                  text: pinConfigured ? (unlocked ? 'Unlocked' : 'Locked') : 'PIN not set',
                  bg: cs.surfaceVariant,
                  border: cs.onSurface.withOpacity(0.10),
                ),
                if (!uploadsEnabled)
                  _Pill(
                    text: 'Uploads disabled',
                    bg: cs.surfaceVariant,
                    border: cs.onSurface.withOpacity(0.10),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '1) Enter your 6-digit PIN (if prompted)\n'
              '2) Upload documents for each requested item\n'
              '3) After upload, the item status becomes "Received"\n'
              '4) Your recent uploads appear below instantly\n',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.75),
                  ),
            ),
            if (overdueCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Overdue requested items: $overdueCount (7+ days)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
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