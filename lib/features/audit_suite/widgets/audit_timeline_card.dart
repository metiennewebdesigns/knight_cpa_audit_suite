import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/evidence_ledger.dart';
import '../services/letter_exporter.dart';

class AuditTimelineCard extends StatefulWidget {
  const AuditTimelineCard({
    super.key,
    required this.engagementId,
    this.onScrollToLedger,
  });

  final String engagementId;

  /// Optional: if you want to scroll to the Evidence Ledger card from engagement_detail.dart
  final VoidCallback? onScrollToLedger;

  @override
  State<AuditTimelineCard> createState() => _AuditTimelineCardState();
}

class _AuditTimelineCardState extends State<AuditTimelineCard> {
  late Future<_TimelineVm> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TimelineVm> _load() async {
    final docs = await getApplicationDocumentsDirectory();
    final docsPath = docs.path;

    final planning = await _readPlanningCompleted(docsPath, widget.engagementId);

    final lettersCount = await LetterExporter.getLettersGeneratedCount(
      docsPath: docsPath,
      engagementId: widget.engagementId,
    );

    final pbc = await _readPbcStats(docsPath, widget.engagementId);
    final overdue = await _readPbcOverdueCount(docsPath, widget.engagementId);

    final portal = await _readPortalUploadsCountAndLatest(docsPath, widget.engagementId);

    final deliverables = await _findLatestExport(
      folder: p.join(docsPath, 'Auditron', 'Deliverables'),
      prefix: 'Auditron_DeliverablePack_${_safeId(widget.engagementId)}_',
    );

    final packet = await _findLatestExport(
      folder: p.join(docsPath, 'Auditron', 'Packets'),
      prefix: 'Auditron_Packet_${_safeId(widget.engagementId)}_',
    );

    final integrity = await _computeIntegrityStatus(widget.engagementId);

    return _TimelineVm(
      planningCompleted: planning,
      lettersGenerated: lettersCount,
      pbcRequested: pbc.requested,
      pbcReceived: pbc.received,
      pbcReviewed: pbc.reviewed,
      pbcOverdue: overdue,
      portalUploads: portal.count,
      portalLastUploadAt: portal.latestIso,
      deliverableLastExportAt: deliverables,
      packetLastExportAt: packet,
      integrityTotalChecked: integrity.totalChecked,
      integrityIssues: integrity.issues,
    );
  }

  Future<bool> _readPlanningCompleted(String docsPath, String engagementId) async {
    try {
      final f = File(p.join(docsPath, 'Auditron', 'EngagementMeta', '$engagementId.json'));
      if (!await f.exists()) return false;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data['planningCompleted'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<_PbcStats> _readPbcStats(String docsPath, String engagementId) async {
    try {
      final f = File(p.join(docsPath, 'Auditron', 'PBC', '$engagementId.json'));
      if (!await f.exists()) return const _PbcStats();

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const _PbcStats();

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const []);

      int requested = 0, received = 0, reviewed = 0;
      for (final it in items) {
        if (it is! Map) continue;
        final s = (it['status'] ?? '').toString().toLowerCase();
        if (s == 'requested') requested++;
        if (s == 'received') received++;
        if (s == 'reviewed') reviewed++;
      }

      return _PbcStats(requested: requested, received: received, reviewed: reviewed);
    } catch (_) {
      return const _PbcStats();
    }
  }

  Future<int> _readPbcOverdueCount(String docsPath, String engagementId) async {
    try {
      final f = File(p.join(docsPath, 'Auditron', 'PBC', '$engagementId.json'));
      if (!await f.exists()) return 0;

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return 0;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const []);

      int overdue = 0;
      for (final it in items) {
        if (it is! Map) continue;

        final status = (it['status'] ?? '').toString().toLowerCase();
        if (status != 'requested') continue;

        final requestedAt = (it['requestedAt'] ?? '').toString().trim();
        final dt = DateTime.tryParse(requestedAt);
        if (dt == null) continue;

        if (DateTime.now().difference(dt).inDays >= 7) overdue++;
      }
      return overdue;
    } catch (_) {
      return 0;
    }
  }

  Future<_CountLatest> _readPortalUploadsCountAndLatest(String docsPath, String engagementId) async {
    try {
      final f = File(p.join(docsPath, 'Auditron', 'ClientPortalLogs', '$engagementId.jsonl'));
      if (!await f.exists()) return const _CountLatest(count: 0, latestIso: '');

      final lines = await f.readAsLines();
      int count = 0;
      String latest = '';

      for (final line in lines) {
        final s = line.trim();
        if (s.isEmpty) continue;
        Map<String, dynamic> m;
        try {
          m = jsonDecode(s) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final kind = (m['kind'] ?? '').toString().toLowerCase();
        if (kind != 'upload') continue;

        count++;
        final createdAt = (m['createdAt'] ?? '').toString().trim();
        if (createdAt.isNotEmpty && createdAt.compareTo(latest) > 0) {
          latest = createdAt;
        }
      }

      return _CountLatest(count: count, latestIso: latest);
    } catch (_) {
      return const _CountLatest(count: 0, latestIso: '');
    }
  }

  Future<String> _findLatestExport({
    required String folder,
    required String prefix,
  }) async {
    try {
      final dir = Directory(folder);
      if (!await dir.exists()) return '';

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(prefix))
          .toList();

      if (files.isEmpty) return '';

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final dt = files.first.lastModifiedSync();
      return dt.toIso8601String();
    } catch (_) {
      return '';
    }
  }

  Future<_IntegrityVm> _computeIntegrityStatus(String engagementId) async {
    try {
      final entries = await EvidenceLedger.readAll(engagementId);
      if (entries.isEmpty) return const _IntegrityVm(totalChecked: 0, issues: 0);

      // Check up to last 20 entries (fast)
      final toCheck = entries.reversed.take(20).toList();
      int issues = 0;

      for (final e in toCheck) {
        final v = await EvidenceLedger.verifyEntry(e);
        if (!v.exists || !v.hashMatches) issues++;
      }

      return _IntegrityVm(totalChecked: toCheck.length, issues: issues);
    } catch (_) {
      return const _IntegrityVm(totalChecked: 0, issues: 0);
    }
  }

  String _prettyWhen(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<_TimelineVm>(
      future: _future,
      builder: (context, snap) {
        final vm = snap.data;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Progress snapshot across planning, PBC, portal uploads, integrity, and exports.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.70),
                      ),
                ),
                const SizedBox(height: 12),

                if (snap.connectionState != ConnectionState.done)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (snap.hasError)
                  Text(
                    'Timeline failed to load: ${snap.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else ...[
                  _TimelineRow(
                    icon: Icons.assignment_outlined,
                    title: 'Planning',
                    subtitle: vm!.planningCompleted ? 'Completed ✅' : 'Not completed',
                    pillText: vm.planningCompleted ? 'Complete' : 'Open',
                    pillBg: vm.planningCompleted ? cs.secondaryContainer : cs.surfaceContainerHighest,
                    pillBorder: vm.planningCompleted ? cs.secondary.withValues(alpha: 0.35) : cs.onSurface.withValues(alpha: 0.10),
                    onTap: () => context.pushNamed('engagementPlanning', pathParameters: {'id': widget.engagementId}),
                  ),
                  const SizedBox(height: 10),

                  _TimelineRow(
                    icon: Icons.fact_check_outlined,
                    title: 'PBC',
                    subtitle: 'Requested ${vm.pbcRequested} • Received ${vm.pbcReceived} • Reviewed ${vm.pbcReviewed}',
                    pillText: vm.pbcOverdue > 0 ? 'Overdue ${vm.pbcOverdue}' : 'OK',
                    pillBg: vm.pbcOverdue > 0 ? cs.errorContainer : cs.surfaceContainerHighest,
                    pillBorder: vm.pbcOverdue > 0 ? cs.error.withValues(alpha: 0.35) : cs.onSurface.withValues(alpha: 0.10),
                    onTap: () => context.pushNamed('pbcList', pathParameters: {'id': widget.engagementId}),
                  ),
                  const SizedBox(height: 10),

                  _TimelineRow(
                    icon: Icons.open_in_new_outlined,
                    title: 'Client Portal Uploads',
                    subtitle: vm.portalUploads == 0
                        ? 'No uploads yet'
                        : '${vm.portalUploads} uploaded • Last ${_prettySafe(vm.portalLastUploadAt, _prettyWhen)}',
                    pillText: vm.portalUploads == 0 ? 'None' : 'Active',
                    pillBg: vm.portalUploads == 0 ? cs.surfaceContainerHighest : cs.tertiaryContainer,
                    pillBorder: vm.portalUploads == 0 ? cs.onSurface.withValues(alpha: 0.10) : cs.tertiary.withValues(alpha: 0.35),
                    onTap: () => context.pushNamed('clientPortal', pathParameters: {'id': widget.engagementId}),
                  ),
                  const SizedBox(height: 10),

                  _TimelineRow(
                    icon: Icons.verified_outlined,
                    title: 'Evidence Integrity',
                    subtitle: vm.integrityTotalChecked == 0
                        ? 'No evidence recorded yet'
                        : 'Checked last ${vm.integrityTotalChecked} • Issues ${vm.integrityIssues}',
                    pillText: vm.integrityIssues > 0 ? 'Issues' : 'OK',
                    pillBg: vm.integrityIssues > 0 ? cs.errorContainer : cs.secondaryContainer,
                    pillBorder: vm.integrityIssues > 0 ? cs.error.withValues(alpha: 0.35) : cs.secondary.withValues(alpha: 0.35),
                    onTap: widget.onScrollToLedger,
                  ),
                  const SizedBox(height: 10),

                  _TimelineRow(
                    icon: Icons.mail_outline,
                    title: 'Letters',
                    subtitle: vm.lettersGenerated == 0 ? 'No letters generated' : '${vm.lettersGenerated} generated',
                    pillText: vm.lettersGenerated == 0 ? '0' : '${vm.lettersGenerated}',
                    pillBg: cs.surfaceContainerHighest,
                    pillBorder: cs.onSurface.withValues(alpha: 0.10),
                    onTap: () => context.pushNamed('lettersHub', pathParameters: {'id': widget.engagementId}),
                  ),
                  const SizedBox(height: 10),

                  _TimelineRow(
                    icon: Icons.inventory_2_outlined,
                    title: 'Deliverable Pack',
                    subtitle: vm.deliverableLastExportAt.isEmpty
                        ? 'Not exported'
                        : 'Last export ${_prettyWhen(vm.deliverableLastExportAt)}',
                    pillText: vm.deliverableLastExportAt.isEmpty ? 'Not yet' : 'Exported',
                    pillBg: vm.deliverableLastExportAt.isEmpty ? cs.surfaceContainerHighest : cs.secondaryContainer,
                    pillBorder: vm.deliverableLastExportAt.isEmpty ? cs.onSurface.withValues(alpha: 0.10) : cs.secondary.withValues(alpha: 0.35),
                    onTap: null,
                  ),
                  const SizedBox(height: 10),

                  _TimelineRow(
                    icon: Icons.picture_as_pdf_outlined,
                    title: 'Audit Packet',
                    subtitle: vm.packetLastExportAt.isEmpty ? 'Not exported' : 'Last export ${_prettyWhen(vm.packetLastExportAt)}',
                    pillText: vm.packetLastExportAt.isEmpty ? 'Not yet' : 'Exported',
                    pillBg: vm.packetLastExportAt.isEmpty ? cs.surfaceContainerHighest : cs.secondaryContainer,
                    pillBorder: vm.packetLastExportAt.isEmpty ? cs.onSurface.withValues(alpha: 0.10) : cs.secondary.withValues(alpha: 0.35),
                    onTap: () => context.pushNamed('engagementPacket', pathParameters: {'id': widget.engagementId}),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String _safeId(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

String _prettySafe(String iso, String Function(String) pretty) {
  if (iso.trim().isEmpty) return '—';
  return pretty(iso);
}

class _TimelineVm {
  final bool planningCompleted;

  final int lettersGenerated;

  final int pbcRequested;
  final int pbcReceived;
  final int pbcReviewed;
  final int pbcOverdue;

  final int portalUploads;
  final String portalLastUploadAt;

  final String deliverableLastExportAt;
  final String packetLastExportAt;

  final int integrityTotalChecked;
  final int integrityIssues;

  const _TimelineVm({
    required this.planningCompleted,
    required this.lettersGenerated,
    required this.pbcRequested,
    required this.pbcReceived,
    required this.pbcReviewed,
    required this.pbcOverdue,
    required this.portalUploads,
    required this.portalLastUploadAt,
    required this.deliverableLastExportAt,
    required this.packetLastExportAt,
    required this.integrityTotalChecked,
    required this.integrityIssues,
  });
}

class _PbcStats {
  final int requested;
  final int received;
  final int reviewed;

  const _PbcStats({
    this.requested = 0,
    this.received = 0,
    this.reviewed = 0,
  });
}

class _IntegrityVm {
  final int totalChecked;
  final int issues;

  const _IntegrityVm({
    required this.totalChecked,
    required this.issues,
  });
}

class _CountLatest {
  final int count;
  final String latestIso;

  const _CountLatest({required this.count, required this.latestIso});
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pillText,
    required this.pillBg,
    required this.pillBorder,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String pillText;
  final Color pillBg;
  final Color pillBorder;
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                ),
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              _Pill(text: pillText, bg: pillBg, border: pillBorder),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.55)),
            ],
          ),
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