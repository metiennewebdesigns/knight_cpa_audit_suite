import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/local_store.dart';

import '../data/models/engagement_models.dart';
import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';

import '../services/preparer_profile.dart';
import '../services/client_meta.dart';
import '../services/file_save_open.dart';
import '../services/engagement_detail_fs.dart';

class AuditPlanningSummaryScreen extends StatefulWidget {
  const AuditPlanningSummaryScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<AuditPlanningSummaryScreen> createState() => _AuditPlanningSummaryScreenState();
}

class _AuditPlanningSummaryScreenState extends State<AuditPlanningSummaryScreen> {
  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;

  late Future<_Vm> _future;
  bool _busy = false;
  bool _changed = false;

  bool get _canFile => !kIsWeb && widget.store.canUseFileSystem;
  String get _docsPath => widget.store.documentsPath ?? '';

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
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

    return _Vm(
      engagement: eng,
      clientName: clientName,
      clientAddressLine: clientAddressLine,
      clientTaxId: clientTaxId,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
    );
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _engRepo.clearCache();
      await _clientsRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _planningText({
    required String clientName,
    required String engagementTitle,
    required String taxId,
    required String email,
    required String phone,
  }) {
    final contactLines = <String>[];
    if (taxId.trim().isNotEmpty) contactLines.add('Tax ID: ${taxId.trim()}');
    if (email.trim().isNotEmpty) contactLines.add('Email: ${email.trim()}');
    if (phone.trim().isNotEmpty) contactLines.add('Phone: ${phone.trim()}');

    final contactBlock = contactLines.isEmpty ? '' : '\n' + contactLines.join('\n');

    return '''
Audit Planning Summary

Client: $clientName$contactBlock
Engagement: $engagementTitle
Engagement ID: ${widget.engagementId}

Purpose
This planning summary documents the preliminary audit planning approach, including scope, timing, key risks, and core procedures to be performed.

Scope & Timing
• Confirm engagement scope and reporting framework
• Establish timeline for PBC collection, walkthroughs, and fieldwork
• Define deliverable milestones and review points

Materiality (Preliminary)
• Determine planning materiality using baseline financial metrics
• Consider performance materiality and posting thresholds
• Reassess after trial balance and key adjustments

Risk Assessment (High-Level)
• Identify significant accounts and disclosures
• Consider fraud risk factors and management override
• Evaluate internal control design and implementation (as applicable)
• Update risk ratings after walkthroughs and analytics

Planned Procedures (Summary)
• Analytical procedures over revenue/expense trends
• Test of details over material balances and selected transactions
• Confirmations (as applicable)
• Inquiry, observation, inspection, and reperformance procedures

Staffing & Supervision
• Assign responsibilities and review checkpoints
• Schedule status updates with management
• Maintain documentation standards and sign-offs

Open Items
• Pending PBC items and access confirmations
• Outstanding policies, significant contracts, and approvals

Sign-off
This document is generated as a Phase 1 planning narrative (locked template). Editing and toggles will be added in Phase 2.
''';
  }

  String _metaDirPath() => p.join(_docsPath, 'Auditron', 'EngagementMeta');
  String _metaFilePath() => p.join(_metaDirPath(), '${widget.engagementId}.json');

  Future<void> _markPlanningCompleted() async {
    if (!_canFile) return;
    try {
      await ensureDir(_metaDirPath());

      final fp = _metaFilePath();

      Map<String, dynamic> data = {};
      if (await fileExists(fp)) {
        final raw = await readTextFile(fp);
        if (raw.trim().isNotEmpty) {
          data = jsonDecode(raw) as Map<String, dynamic>;
        }
      }

      if (data['planningCompleted'] == true) return;

      data['planningCompleted'] = true;
      data['planningCompletedAt'] = DateTime.now().toIso8601String();

      await writeTextFile(fp, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _exportPlanningPdf(_Vm vm) async {
    if (_busy) return;

    if (!_canFile) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planning PDF export is disabled on web demo.')),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final preparer = await PreparerProfile.read();
      final preparerName = (preparer['name'] ?? 'Independent Auditor').toString();
      final preparerLine2 = (preparer['line2'] ?? '').toString().trim();

      final generatedOn = _todayIso();
      final text = _planningText(
        clientName: vm.clientName,
        engagementTitle: vm.engagement.title,
        taxId: vm.clientTaxId,
        email: vm.clientEmail,
        phone: vm.clientPhone,
      );

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
            pw.Text('Audit Planning Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Engagement: ${vm.engagement.title}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Engagement ID: ${widget.engagementId}', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 14),
            pw.Paragraph(text: text, style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
          ],
        ),
      );

      final bytes = await doc.save();

      final safeEngagementId = widget.engagementId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final fileName = 'Auditron_Planning_${safeEngagementId}_${_todayIso()}.pdf';

      final res = await savePdfBytesAndMaybeOpen(
        fileName: fileName,
        bytes: bytes,
        subfolder: 'Auditron/Planning',
      );

      await _markPlanningCompleted();
      _changed = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.didOpenFile ? 'Exported + opened ${res.savedFileName} ✅' : 'Exported ${res.savedFileName} ✅',
          ),
        ),
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
          title: const Text('Planning Summary'),
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
                    'Planning summary failed to load.',
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
            final preview = _planningText(
              clientName: vm.clientName,
              engagementTitle: vm.engagement.title,
              taxId: vm.clientTaxId,
              email: vm.clientEmail,
              phone: vm.clientPhone,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                if (!_canFile)
                  Card(
                    color: cs.surfaceVariant,
                    child: const ListTile(
                      leading: Icon(Icons.public),
                      title: Text('Web demo mode'),
                      subtitle: Text('Planning PDF export is disabled on web. Run desktop build to export PDFs.'),
                    ),
                  ),
                if (!_canFile) const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(preview, style: const TextStyle(height: 1.35)),
                  ),
                ),
                const SizedBox(height: 14),

                FilledButton.icon(
                  onPressed: _busy ? null : () => _exportPlanningPdf(vm),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_busy ? 'Exporting…' : 'Export Planning PDF'),
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

  const _Vm({
    required this.engagement,
    required this.clientName,
    required this.clientAddressLine,
    required this.clientTaxId,
    required this.clientEmail,
    required this.clientPhone,
  });
}

String _todayIso() {
  final d = DateTime.now();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}