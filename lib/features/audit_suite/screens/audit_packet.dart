import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/local_store.dart';

import '../data/models/engagement_models.dart';
import '../data/models/workpaper_models.dart';
import '../data/models/risk_assessment_models.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/workpapers_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';

import '../services/preparer_profile.dart';
import '../services/client_meta.dart';
import '../services/client_portal_fs.dart'; // reuse for EngagementMeta write (IO only)
import '../services/file_save_open.dart';

class AuditPacketScreen extends StatefulWidget {
  const AuditPacketScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<AuditPacketScreen> createState() => _AuditPacketScreenState();
}

class _AuditPacketScreenState extends State<AuditPacketScreen> {
  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;
  late final WorkpapersRepository _wpRepo;
  late final RiskAssessmentsRepository _riskRepo;

  late Future<_Vm> _future;
  bool _busy = false;
  bool _changed = false;

  bool get _canExport => !kIsWeb && widget.store.canUseFileSystem;

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
    _wpRepo = WorkpapersRepository(widget.store);
    _riskRepo = RiskAssessmentsRepository(widget.store);
    _future = _load();
  }

  Future<_Vm> _load() async {
    final eng = await _engRepo.getById(widget.engagementId);
    if (eng == null) {
      throw StateError('Engagement not found: ${widget.engagementId}');
    }

    final client = await _clientsRepo.getById(eng.clientId);
    final clientName = client?.name ?? eng.clientId;

    // ✅ NEW: contact fields
    final clientTaxId = (client?.taxId ?? '').toString().trim();
    final clientEmail = (client?.email ?? '').toString().trim();
    final clientPhone = (client?.phone ?? '').toString().trim();

    final addr = await ClientMeta.readAddress(eng.clientId);
    final clientAddressLine = ClientMeta.formatSingleLine(addr);

    final risk = await _riskRepo.ensureForEngagement(eng.id);
    final workpapers = await _wpRepo.getByEngagementId(eng.id);

    return _Vm(
      engagement: eng,
      clientName: clientName,
      clientAddressLine: clientAddressLine,
      clientTaxId: clientTaxId,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      risk: risk,
      workpapers: workpapers,
    );
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _engRepo.clearCache();
      await _clientsRepo.clearCache();
      await _riskRepo.clearCache();
      await _wpRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markPlanningCompleted() async {
    // Web: disabled (no local meta file)
    if (!_canExport) return;

    try {
      // Lightweight signal stored via portal log (IO only)
      await ClientPortalFs.logPortalEvent(
        engagementId: widget.engagementId,
        kind: 'planning_completed',
        note: 'Audit packet export marked planning complete',
        extra: {
          'planningCompleted': true,
          'planningCompletedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  String _packetPreviewText(_Vm vm) {
    final e = vm.engagement;

    final riskLevel = vm.risk.overallLevel();
    final riskScore = vm.risk.overallScore1to5();
    final riskUpdated = vm.risk.updated.trim().isEmpty ? '—' : vm.risk.updated.trim();

    final totalWps = vm.workpapers.length;
    final completeWps = vm.workpapers.where((w) => w.status.trim().toLowerCase() == 'complete').length;
    final openWps = (totalWps - completeWps).clamp(0, 999999);

    final contactLines = <String>[];
    if (vm.clientTaxId.trim().isNotEmpty) contactLines.add('Tax ID: ${vm.clientTaxId.trim()}');
    if (vm.clientEmail.trim().isNotEmpty) contactLines.add('Email: ${vm.clientEmail.trim()}');
    if (vm.clientPhone.trim().isNotEmpty) contactLines.add('Phone: ${vm.clientPhone.trim()}');

    final contactBlock = contactLines.isEmpty ? '' : '\n' + contactLines.join('\n');

    return '''
Audit Packet (Phase 1)

Client: ${vm.clientName}$contactBlock
Engagement: ${e.title}
Engagement ID: ${e.id}
Status: ${e.status}
Updated: ${e.updated.isEmpty ? "—" : e.updated}

Risk Snapshot
• Overall: $riskLevel ($riskScore/5)
• Last assessed: $riskUpdated

Workpapers Snapshot
• Total: $totalWps
• Complete: $completeWps
• Open: $openWps

Included (Phase 1)
• Engagement Summary (header info)
• Risk Snapshot
• Workpapers Index (titles + statuses)

Note:
This is a Phase 1 audit packet export. Attachments and full workpaper content packaging will be added in Phase 2.
''';
  }

  Future<void> _exportPacketPdf(_Vm vm) async {
    if (_busy) return;

    if (!_canExport) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is disabled on web demo. Run desktop/macOS build to export.')),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final preparer = await PreparerProfile.read();
      final preparerName = (preparer['name'] ?? 'Independent Auditor').toString();
      final preparerLine2 = (preparer['line2'] ?? '').toString().trim();
      final generatedOn = _todayIso();

      final preview = _packetPreviewText(vm);
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(50, 56, 50, 56),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Auditron', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Prepared by: $preparerName', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (preparerLine2.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(preparerLine2, style: const pw.TextStyle(fontSize: 9)),
                  ),
                ),
              pw.SizedBox(height: 6),

              // ✅ Client block + contact lines
              pw.Text('Client: ${vm.clientName}', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
              if (vm.clientTaxId.trim().isNotEmpty)
                pw.Text('Tax ID: ${vm.clientTaxId.trim()}', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
              if (vm.clientEmail.trim().isNotEmpty)
                pw.Text('Email: ${vm.clientEmail.trim()}', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
              if (vm.clientPhone.trim().isNotEmpty)
                pw.Text('Phone: ${vm.clientPhone.trim()}', style: const pw.TextStyle(fontSize: 9), maxLines: 1),

              if (vm.clientAddressLine.trim().isNotEmpty)
                pw.Text(
                  'Client Address: ${vm.clientAddressLine}',
                  style: const pw.TextStyle(fontSize: 9),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Prepared using Auditron • Audit clarity. Automated.', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                  'Generated on $generatedOn • Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          build: (_) => [
            pw.Text('Audit Packet', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Engagement: ${vm.engagement.title}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Engagement ID: ${vm.engagement.id}', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 14),
            pw.Paragraph(text: preview, style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
            pw.SizedBox(height: 14),
            pw.Text('Workpapers Index', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...vm.workpapers.map(
              (w) => pw.Bullet(
                text: '${w.title} — ${w.status.isEmpty ? "—" : w.status}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );

      final bytes = await doc.save();

      final safeEngagementId = widget.engagementId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final fileName = 'Auditron_Packet_${safeEngagementId}_${_todayIso()}.pdf';

      final res = await savePdfBytesAndMaybeOpen(
        fileName: fileName,
        bytes: bytes,
        subfolder: 'Auditron/Packets',
      );

      await _markPlanningCompleted();
      _changed = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.didOpenFile ? 'Exported + opened ${res.savedFileName} ✅' : 'Exported ${res.savedFileName} ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        context.pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Audit Packet'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_changed),
          ),
          actions: [
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
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.error_outline, size: 44),
                  const SizedBox(height: 10),
                  Text(
                    'Audit packet failed to load.',
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

            final vm = snap.data!;
            final preview = _packetPreviewText(vm);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                if (!_canExport)
                  Card(
                    color: cs.surfaceVariant,
                    child: const ListTile(
                      leading: Icon(Icons.public),
                      title: Text('Web demo mode'),
                      subtitle: Text('Audit Packet export is disabled on web. Run desktop build to export PDFs.'),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(preview, style: const TextStyle(height: 1.35)),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _exportPacketPdf(vm),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_busy ? 'Exporting…' : 'Export Audit Packet PDF'),
                ),
              ],
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
  final String clientAddressLine;

  // ✅ NEW: contact fields
  final String clientTaxId;
  final String clientEmail;
  final String clientPhone;

  final RiskAssessmentModel risk;
  final List<WorkpaperModel> workpapers;

  const _Vm({
    required this.engagement,
    required this.clientName,
    required this.clientAddressLine,
    required this.clientTaxId,
    required this.clientEmail,
    required this.clientPhone,
    required this.risk,
    required this.workpapers,
  });
}

String _todayIso() {
  final d = DateTime.now();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}