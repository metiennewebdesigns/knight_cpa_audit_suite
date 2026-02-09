// lib/features/audit_suite/services/deliverable_pack_exporter_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/local_store.dart';
import '../../../core/utils/doc_path.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';
import '../data/models/repositories/workpapers_repository.dart';

import '../services/preparer_profile.dart';
import '../services/client_meta.dart';
import '../services/letter_exporter.dart';
import '../services/evidence_ledger.dart';

class DeliverablePackResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const DeliverablePackResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

class DeliverablePackExporter {
  static Future<DeliverablePackResult> exportPdf({
    required LocalStore store,
    required String engagementId,
  }) async {
    // ✅ Use doc_path.dart (conditional) instead of path_provider directly
    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }

    final engRepo = EngagementsRepository(store);
    final clientRepo = ClientsRepository(store);
    final wpRepo = WorkpapersRepository(store);
    final riskRepo = RiskAssessmentsRepository(store);

    final eng = await engRepo.getById(engagementId);
    if (eng == null) {
      throw StateError('Engagement not found: $engagementId');
    }

    final client = await clientRepo.getById(eng.clientId);
    final clientName = (client?.name ?? eng.clientId).toString();
    final clientAddr = ClientMeta.formatSingleLine(
      await ClientMeta.readAddress(eng.clientId),
    );

    final preparer = await PreparerProfile.read();
    final preparerName = (preparer['name'] ?? 'Independent Auditor').toString();
    final preparerLine2 = (preparer['line2'] ?? '').toString().trim();

    // PBC stats (+ overdue)
    final pbcStats = await _readPbcStats(docsPath, engagementId);
    final pbcRequested = pbcStats.requested;
    final pbcReceived = pbcStats.received;
    final pbcReviewed = pbcStats.reviewed;
    final pbcOverdue = pbcStats.overdue;

    // Workpapers
    final workpapers = await wpRepo.getByEngagementId(engagementId);
    final totalWps = workpapers.length;
    final completeWps = workpapers.where((w) => w.status.trim().toLowerCase() == 'complete').length;
    final openWps = (totalWps - completeWps).clamp(0, 999999);

    // Risk
    final risk = await riskRepo.ensureForEngagement(engagementId);
    final riskLevel = risk.overallLevel();
    final riskScore = risk.overallScore1to5();
    final riskUpdated = risk.updated.trim();

    // Planning complete (from EngagementMeta json)
    final planningCompleted = await _readPlanningCompleted(docsPath, engagementId);

    // Letters generated count (from Letters meta)
    final lettersGenerated = await LetterExporter.getLettersGeneratedCount(
      docsPath: docsPath,
      engagementId: engagementId,
    );

    // Integrity issues (fast check on last N entries)
    final integrityIssues = await _integrityIssuesForEngagement(
      engagementId: engagementId,
      maxEntriesToCheck: 25,
    );

    // Portal status + PIN set
    final portalClosed = eng.status.trim().toLowerCase() == 'finalized';
    final portalPin = await _readClientPortalPinOrEmpty(docsPath, engagementId);

    // Readiness score (bundle snapshot)
    final readinessPct = _computeReadinessPercentV2(
      riskCompleted: riskUpdated.isNotEmpty,
      planningCompleted: planningCompleted,
      pbcProgress01: _pbcProgress01(pbcRequested, pbcReceived, pbcReviewed),
      totalWorkpapers: totalWps,
      completeWorkpapers: completeWps,
      lettersGenerated: lettersGenerated,
      integrityIssues: integrityIssues,
    );

    final readinessSnapshot = _readinessSnapshotText(
      clientName: clientName,
      engagementTitle: eng.title,
      engagementId: engagementId,
      engagementStatus: eng.status,
      readinessPct: readinessPct,
      portalClosed: portalClosed,
      portalPinSet: portalPin.trim().isNotEmpty,
      riskLevel: riskLevel,
      riskScore: riskScore,
      riskUpdated: riskUpdated,
      planningCompleted: planningCompleted,
      totalWps: totalWps,
      completeWps: completeWps,
      openWps: openWps,
      lettersGenerated: lettersGenerated,
      pbcRequested: pbcRequested,
      pbcReceived: pbcReceived,
      pbcReviewed: pbcReviewed,
      pbcOverdue: pbcOverdue,
      integrityIssues: integrityIssues,
    );

    // Existing letter content
    final engagementLetter = LetterExporter.buildLetterTextPreview(
      engagementId: engagementId,
      type: 'engagement',
    );
    final pbcLetter = LetterExporter.buildLetterTextPreview(
      engagementId: engagementId,
      type: 'pbc',
    );
    final mrlLetter = LetterExporter.buildLetterTextPreview(
      engagementId: engagementId,
      type: 'mrl',
    );

    final planningText = _planningNarrative(
      clientName: clientName,
      engagementTitle: eng.title,
      engagementId: engagementId,
    );

    final packetSummary = _packetSummary(
      clientName: clientName,
      engagementTitle: eng.title,
      engagementId: engagementId,
      status: eng.status,
      riskLevel: riskLevel,
      riskScore: riskScore,
      riskUpdated: riskUpdated,
      totalWps: totalWps,
      completeWps: completeWps,
      pbcRequested: pbcRequested,
      pbcReceived: pbcReceived,
      pbcReviewed: pbcReviewed,
    );

    final doc = pw.Document();
    final generatedOn = _todayIso();

    // ✅ MultiPage safe list (not one giant Column)
    final content = <pw.Widget>[
      // ✅ Readiness Snapshot FIRST
      ..._sectionWidgets('Audit Readiness Snapshot', readinessSnapshot),

      pw.Text(
        'Client Deliverable Pack',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 10),
      pw.Text('Engagement: ${eng.title}', style: const pw.TextStyle(fontSize: 11)),
      pw.Text('Engagement ID: $engagementId', style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 14),

      pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: packetSummary,
        style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
      ),

      pw.SizedBox(height: 14),
      pw.Text('Included Documents', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Bullet(text: 'Readiness Snapshot', style: const pw.TextStyle(fontSize: 11)),
      pw.Bullet(text: 'Engagement Letter', style: const pw.TextStyle(fontSize: 11)),
      pw.Bullet(text: 'PBC Request Letter', style: const pw.TextStyle(fontSize: 11)),
      pw.Bullet(text: 'Management Representation Letter', style: const pw.TextStyle(fontSize: 11)),
      pw.Bullet(text: 'Audit Planning Summary', style: const pw.TextStyle(fontSize: 11)),
      pw.Bullet(text: 'Audit Packet Summary', style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 18),

      ..._sectionWidgets('Engagement Letter', engagementLetter),
      ..._sectionWidgets('PBC Request Letter', pbcLetter),
      ..._sectionWidgets('Management Representation Letter', mrlLetter),
      ..._sectionWidgets('Audit Planning Summary', planningText),
      ..._sectionWidgets('Audit Packet Summary', packetSummary),
    ];

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
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  preparerLine2,
                  style: const pw.TextStyle(fontSize: 9),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            pw.SizedBox(height: 4),
            pw.Text('Client: $clientName', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
            if (clientAddr.trim().isNotEmpty)
              pw.Text(
                'Client Address: $clientAddr',
                style: const pw.TextStyle(fontSize: 9),
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
              ),
            pw.SizedBox(height: 6),
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
        build: (_) => content,
      ),
    );

    final bytes = await doc.save();

    final outFolder = Directory(p.join(docsPath, 'Auditron', 'Deliverables'));
    if (!await outFolder.exists()) {
      await outFolder.create(recursive: true);
    }

    final safeEngagementId = engagementId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final fileName = 'Auditron_DeliverablePack_${safeEngagementId}_${_todayIso()}.pdf';
    final outPath = p.join(outFolder.path, fileName);

    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes, flush: true);

    bool opened = false;
    try {
      final res = await OpenFilex.open(outPath);
      opened = (res.type == ResultType.done);
    } catch (_) {}

    return DeliverablePackResult(
      savedPath: outPath,
      savedFileName: fileName,
      didOpenFile: opened,
    );
  }

  // ✅ IMPORTANT: return multiple widgets (not a Column)
  static List<pw.Widget> _sectionWidgets(String title, String text) {
    return [
      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: text,
        style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  static String _packetSummary({
    required String clientName,
    required String engagementTitle,
    required String engagementId,
    required String status,
    required String riskLevel,
    required int riskScore,
    required String riskUpdated,
    required int totalWps,
    required int completeWps,
    required int pbcRequested,
    required int pbcReceived,
    required int pbcReviewed,
  }) {
    final openWps = (totalWps - completeWps).clamp(0, 999999);
    final riskUpd = riskUpdated.isEmpty ? '—' : riskUpdated;

    return '''
Client: $clientName
Engagement: $engagementTitle
Engagement ID: $engagementId
Status: $status

Risk
• Overall: $riskLevel ($riskScore/5)
• Last assessed: $riskUpd

Workpapers
• Total: $totalWps
• Complete: $completeWps
• Open: $openWps

PBC
• Requested: $pbcRequested
• Received: $pbcReceived
• Reviewed: $pbcReviewed
''';
  }

  static String _planningNarrative({
    required String clientName,
    required String engagementTitle,
    required String engagementId,
  }) {
    return '''
Audit Planning Summary

Client: $clientName
Engagement: $engagementTitle
Engagement ID: $engagementId

Purpose
This planning summary documents the preliminary audit planning approach, including scope, timing, key risks, and core procedures to be performed.

Scope & Timing
• Confirm engagement scope and reporting framework
• Establish timeline for PBC collection, walkthroughs, and fieldwork
• Define deliverable milestones and review points

Risk Assessment (High-Level)
• Identify significant accounts and disclosures
• Consider fraud risk factors and management override
• Evaluate internal control design and implementation (as applicable)

Planned Procedures (Summary)
• Analytical procedures over key balances and trends
• Test of details over material balances and selected transactions
• Confirmations (as applicable)

Note
This is a Phase 1 planning narrative (locked template). Editing and toggles will be added in Phase 2.
''';
  }

  static double _pbcProgress01(int requested, int received, int reviewed) {
    final total = requested + received + reviewed;
    if (total <= 0) return 0.0;
    return (received + reviewed) / total;
  }

  static int _computeReadinessPercentV2({
    required bool riskCompleted,
    required bool planningCompleted,
    required double pbcProgress01,
    required int totalWorkpapers,
    required int completeWorkpapers,
    required int lettersGenerated,
    required int integrityIssues,
  }) {
    // Risk 20, Planning 20, Workpapers 30, Letters 10, PBC 15, Integrity 5
    final risk = riskCompleted ? 20 : 0;
    final planning = planningCompleted ? 20 : 0;

    final wp = totalWorkpapers <= 0 ? 0 : ((completeWorkpapers / totalWorkpapers) * 30).round();
    final letters = lettersGenerated > 0 ? 10 : 0;
    final pbc = (pbcProgress01.clamp(0, 1) * 15).round();
    final integrity = integrityIssues == 0 ? 5 : 0;

    return (risk + planning + wp + letters + pbc + integrity).clamp(0, 99);
  }

  static String _readinessSnapshotText({
    required String clientName,
    required String engagementTitle,
    required String engagementId,
    required String engagementStatus,
    required int readinessPct,
    required bool portalClosed,
    required bool portalPinSet,
    required String riskLevel,
    required int riskScore,
    required String riskUpdated,
    required bool planningCompleted,
    required int totalWps,
    required int completeWps,
    required int openWps,
    required int lettersGenerated,
    required int pbcRequested,
    required int pbcReceived,
    required int pbcReviewed,
    required int pbcOverdue,
    required int integrityIssues,
  }) {
    final status = engagementStatus.trim().isEmpty ? '—' : engagementStatus.trim();
    final riskUpd = riskUpdated.trim().isEmpty ? '—' : riskUpdated.trim();

    final pbcTotal = pbcRequested + pbcReceived + pbcReviewed;
    final pbcProvided = pbcReceived + pbcReviewed;

    final portalLine = portalClosed
        ? 'Portal: CLOSED (finalized)'
        : (portalPinSet ? 'Portal: OPEN (PIN active)' : 'Portal: OPEN (PIN not set)');

    final integrityLine = integrityIssues == 0
        ? 'Evidence Integrity: OK'
        : 'Evidence Integrity: ISSUES ($integrityIssues)';

    return '''
Audit Readiness Snapshot (Phase 1)

Client: $clientName
Engagement: $engagementTitle
Engagement ID: $engagementId
Status: $status

Readiness: $readinessPct%
$portalLine
$integrityLine

Risk
• Overall: $riskLevel ($riskScore/5)
• Last assessed: $riskUpd

Planning
• Completed: ${planningCompleted ? "Yes" : "No"}

PBC
• Provided: $pbcProvided / $pbcTotal
• Overdue (7+ days): $pbcOverdue

Workpapers
• Total: $totalWps
• Complete: $completeWps
• Open: $openWps

Letters
• Generated: $lettersGenerated

Notes
Readiness is a Phase 1 heuristic based on risk assessment completion, planning completion flag, PBC progress, workpaper completion, letter generation, and evidence integrity.
''';
  }

  static Future<bool> _readPlanningCompleted(String docsPath, String engagementId) async {
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

  static Future<String> _readClientPortalPinOrEmpty(String docsPath, String engagementId) async {
    try {
      final f = File(p.join(docsPath, 'Auditron', 'EngagementMeta', '$engagementId.json'));
      if (!await f.exists()) return '';

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return '';

      final data = jsonDecode(raw) as Map<String, dynamic>;
      return (data['clientPortalPin'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  static Future<int> _integrityIssuesForEngagement({
    required String engagementId,
    required int maxEntriesToCheck,
  }) async {
    try {
      final entries = await EvidenceLedger.readAll(engagementId);
      if (entries.isEmpty) return 0;

      final toCheck = entries.length <= maxEntriesToCheck
          ? entries.reversed.toList()
          : entries.reversed.take(maxEntriesToCheck).toList();

      int issues = 0;
      for (final e in toCheck) {
        final res = await EvidenceLedger.verifyEntry(e);
        if (!res.exists || !res.hashMatches) issues++;
      }
      return issues;
    } catch (_) {
      return 0;
    }
  }

  static Future<_PbcStats> _readPbcStats(String docsPath, String engagementId) async {
    try {
      final f = File(p.join(docsPath, 'Auditron', 'PBC', '$engagementId.json'));
      if (!await f.exists()) return const _PbcStats();

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const _PbcStats();

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? <dynamic>[]);

      int requested = 0, received = 0, reviewed = 0, overdue = 0;

      for (final it in items) {
        if (it is! Map) continue;

        final s = (it['status'] ?? '').toString().toLowerCase();
        if (s == 'requested') requested++;
        if (s == 'received') received++;
        if (s == 'reviewed') reviewed++;

        // overdue: requested for 7+ days
        if (s == 'requested') {
          final requestedAt = (it['requestedAt'] ?? '').toString().trim();
          final dt = DateTime.tryParse(requestedAt);
          if (dt != null && DateTime.now().difference(dt).inDays >= 7) overdue++;
        }
      }

      return _PbcStats(
        requested: requested,
        received: received,
        reviewed: reviewed,
        overdue: overdue,
      );
    } catch (_) {
      return const _PbcStats();
    }
  }

  static String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

class _PbcStats {
  final int requested;
  final int received;
  final int reviewed;
  final int overdue;

  const _PbcStats({
    this.requested = 0,
    this.received = 0,
    this.reviewed = 0,
    this.overdue = 0,
  });
}