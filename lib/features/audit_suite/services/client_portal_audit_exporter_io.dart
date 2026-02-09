import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/local_store.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';

import '../services/client_meta.dart';
import '../services/evidence_ledger.dart';
import '../services/preparer_profile.dart';

class ClientPortalAuditExportResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const ClientPortalAuditExportResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

class ClientPortalAuditExporter {
  static const String reportVersion = '1.0';

  static Future<ClientPortalAuditExportResult> exportPdf({
    required LocalStore store,
    required String engagementId,
  }) async {
    final docs = await getApplicationDocumentsDirectory();

    // Engagement + client
    final engRepo = EngagementsRepository(store);
    final clientRepo = ClientsRepository(store);

    final eng = await engRepo.getById(engagementId);
    if (eng == null) throw StateError('Engagement not found: $engagementId');

    final isFinalized = (eng.status).trim().toLowerCase() == 'finalized';

    final client = await clientRepo.getById(eng.clientId);
    final clientName = (client?.name ?? eng.clientId).toString();
    final clientAddr = ClientMeta.formatSingleLine(await ClientMeta.readAddress(eng.clientId));

    // ✅ NEW: contact fields
    final clientTaxId = (client?.taxId ?? '').toString().trim();
    final clientEmail = (client?.email ?? '').toString().trim();
    final clientPhone = (client?.phone ?? '').toString().trim();

    // Preparer
    final preparer = await PreparerProfile.read();
    final preparerName = (preparer['name'] ?? 'Independent Auditor').toString().trim();
    final preparerLine2 = (preparer['line2'] ?? '').toString().trim();
    final preparerOrg = (preparer['organization'] ??
            preparer['company'] ??
            preparer['firm'] ??
            preparer['businessName'] ??
            '')
        .toString()
        .trim();

    // Portal log events
    final events = await _readPortalLogEvents(docs.path, engagementId);

    // Ledger for integrity lookup
    final ledgerEntries = await EvidenceLedger.readAll(engagementId);
    final ledgerByFileName = <String, EvidenceLedgerEntry>{
      for (final e in ledgerEntries) e.fileName: e,
    };

    // Rows
    final rows = <_AuditRow>[];
    int integrityIssues = 0;

    DateTime? earliest;
    DateTime? latest;

    for (final ev in events) {
      final kind = (ev['kind'] ?? '').toString().toLowerCase();
      if (kind != 'upload') continue;

      final createdAt = (ev['createdAt'] ?? '').toString().trim();
      final when = DateTime.tryParse(createdAt);

      if (when != null) {
        earliest = (earliest == null || when.isBefore(earliest)) ? when : earliest;
        latest = (latest == null || when.isAfter(latest)) ? when : latest;
      }

      final fileName = (ev['fileName'] ?? ev['note'] ?? '—').toString();
      final shaFromLog = (ev['sha256'] ?? '').toString().trim();
      final pbcItemTitle = (ev['pbcItemTitle'] ?? '').toString().trim();

      String integrity = 'UNVERIFIED';
      final ledger = ledgerByFileName[fileName];
      if (ledger != null) {
        final v = await EvidenceLedger.verifyEntry(ledger);
        if (!v.exists) {
          integrity = 'MISSING';
          integrityIssues++;
        } else if (!v.hashMatches) {
          integrity = 'MISMATCH';
          integrityIssues++;
        } else {
          integrity = 'OK';
        }
      }

      rows.add(
        _AuditRow(
          whenIso: createdAt.isEmpty ? '—' : createdAt,
          fileName: fileName,
          pbcItemTitle: pbcItemTitle,
          sha256: shaFromLog.isNotEmpty ? shaFromLog : (ledger?.sha256 ?? ''),
          integrity: integrity,
        ),
      );
    }

    rows.sort((a, b) => b.whenIso.compareTo(a.whenIso));

    final generatedOn = _todayIso();
    final dateRange = (earliest == null || latest == null)
        ? '—'
        : '${_dateOnly(earliest!.toIso8601String())} to ${_dateOnly(latest!.toIso8601String())}';

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(50, 56, 50, 56),
        header: (_) => pw.Column(
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
                child: pw.Text(preparerLine2, style: const pw.TextStyle(fontSize: 9), maxLines: 1),
              ),
            pw.SizedBox(height: 4),

            // ✅ Client block + contact info
            pw.Text('Client: $clientName', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
            if (clientTaxId.isNotEmpty) pw.Text('Tax ID: $clientTaxId', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
            if (clientEmail.isNotEmpty) pw.Text('Email: $clientEmail', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
            if (clientPhone.isNotEmpty) pw.Text('Phone: $clientPhone', style: const pw.TextStyle(fontSize: 9), maxLines: 1),

            if (clientAddr.trim().isNotEmpty)
              pw.Text('Client Address: $clientAddr', style: const pw.TextStyle(fontSize: 9), maxLines: 2, overflow: pw.TextOverflow.clip),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                isFinalized ? 'Prepared With: Auditron • LOCKED (Finalized)' : 'Prepared With: Auditron',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Generated on $generatedOn • v$reportVersion • Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Text('Client Portal Audit Trail', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Engagement: ${eng.title}', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Engagement ID: $engagementId', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Engagement Status: ${eng.status}', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(isFinalized ? 'Trail Status: LOCKED (Finalized)' : 'Trail Status: ACTIVE', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 14),

          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1, color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Date range: $dateRange', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Total uploads: ${rows.length}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Integrity issues flagged: $integrityIssues', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),

          pw.SizedBox(height: 14),
          pw.Text('Audit Log', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          if (rows.isEmpty)
            pw.Text('No portal uploads found in log.', style: const pw.TextStyle(fontSize: 11))
          else ...[
            _tableHeader(),
            for (final r in rows) _tableRow(r),
          ],

          pw.SizedBox(height: 14),
          pw.Text('Notes', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Paragraph(
            text:
                'This report is generated from Auditron portal activity logs and evidence ledger verification. '
                'Integrity status is based on whether the evidence file exists and matches the recorded SHA-256 hash '
                'at the time the report is generated.',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),

          pw.NewPage(),
          pw.Text('Auditor Attestation', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('Client: $clientName', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Engagement: ${eng.title}', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Engagement ID: $engagementId', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Generated on: $generatedOn', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 14),

          pw.Paragraph(
            text:
                'I attest that this Client Portal Audit Trail was generated by Auditron and reflects the portal upload activity '
                'and evidence integrity verification status as of the generation date shown above. '
                'Any uploads or file changes after this date may alter integrity results.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),

          pw.SizedBox(height: 18),
          pw.Text('Prepared By: $preparerName', style: const pw.TextStyle(fontSize: 11)),
          if (preparerLine2.isNotEmpty) pw.Text('Title: $preparerLine2', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Organization: ${preparerOrg.isEmpty ? '—' : preparerOrg}', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Prepared With: Auditron', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 18),

          pw.Text('Prepared By Signature: _______________________________', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 10),
          pw.Text('Reviewed By: _______________________________', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 10),
          pw.Text('Approved By: _______________________________', style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );

    final bytes = await doc.save();

    final outFolder = Directory(p.join(docs.path, 'Auditron', 'AuditTrail'));
    if (!await outFolder.exists()) await outFolder.create(recursive: true);

    final safeEngagementId = engagementId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final fileName = 'Auditron_ClientPortal_AuditTrail_${safeEngagementId}_${_todayIso()}.pdf';
    final outPath = p.join(outFolder.path, fileName);

    await File(outPath).writeAsBytes(bytes, flush: true);

    bool opened = false;
    try {
      final res = await OpenFilex.open(outPath);
      opened = (res.type == ResultType.done);
    } catch (_) {}

    return ClientPortalAuditExportResult(savedPath: outPath, savedFileName: fileName, didOpenFile: opened);
  }

  static Future<List<Map<String, dynamic>>> _readPortalLogEvents(String docsPath, String engagementId) async {
    try {
      final f = File(p.join(docsPath, 'Auditron', 'ClientPortalLogs', '$engagementId.jsonl'));
      if (!await f.exists()) return [];

      final lines = await f.readAsLines();
      final out = <Map<String, dynamic>>[];
      for (final line in lines) {
        final s = line.trim();
        if (s.isEmpty) continue;
        try {
          out.add(jsonDecode(s) as Map<String, dynamic>);
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static pw.Widget _tableHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border.all(width: 1, color: PdfColors.grey400),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 2, child: pw.Text('When', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Expanded(flex: 3, child: pw.Text('File', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Expanded(flex: 3, child: pw.Text('PBC Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Expanded(flex: 2, child: pw.Text('SHA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Expanded(flex: 2, child: pw.Text('Integrity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
        ],
      ),
    );
  }

  static pw.Widget _tableRow(_AuditRow r) {
    final shaShort = r.sha256.length >= 12 ? '${r.sha256.substring(0, 12)}…' : (r.sha256.isEmpty ? '—' : r.sha256);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: const pw.BorderSide(width: 1, color: PdfColors.grey400),
          right: const pw.BorderSide(width: 1, color: PdfColors.grey400),
          bottom: const pw.BorderSide(width: 1, color: PdfColors.grey400),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(flex: 2, child: pw.Text(_dateTimeShort(r.whenIso), style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 3, child: pw.Text(r.fileName, style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 3, child: pw.Text(r.pbcItemTitle.isEmpty ? '—' : r.pbcItemTitle, style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 2, child: pw.Text(shaShort, style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 2, child: pw.Text(r.integrity, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static String _dateTimeShort(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso.isEmpty ? '—' : iso;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd $hh:$mi';
  }

  static String _dateOnly(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso.isEmpty ? '—' : iso;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  static String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

class _AuditRow {
  final String whenIso;
  final String fileName;
  final String pbcItemTitle;
  final String sha256;
  final String integrity;

  const _AuditRow({
    required this.whenIso,
    required this.fileName,
    required this.pbcItemTitle,
    required this.sha256,
    required this.integrity,
  });
}