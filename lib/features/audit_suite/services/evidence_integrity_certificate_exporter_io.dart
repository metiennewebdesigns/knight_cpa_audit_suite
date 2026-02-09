// lib/features/audit_suite/services/evidence_integrity_certificate_exporter_io.dart

import 'dart:io' show Directory, File;
import 'dart:math';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/doc_path.dart';

import 'evidence_ledger.dart';
import 'preparer_profile.dart';

class EvidenceIntegrityCertificateResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const EvidenceIntegrityCertificateResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

class EvidenceIntegrityCertificateExporter {
  static const String certificateVersion = '1.0';

  static Future<EvidenceIntegrityCertificateResult> exportPdf({
    required String engagementId,
    required String engagementTitle,
    required String clientName,
    String engagementStatus = '',
  }) async {
    final generatedOn = _todayIso();
    final safeId = engagementId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }

    final outDir = Directory(p.join(docsPath, 'Auditron', 'Certificates'));
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final preparer = await PreparerProfile.read();
    final preparedBy = (preparer['name'] ?? 'Independent Auditor').toString().trim();
    final preparedTitle = (preparer['line2'] ?? '').toString().trim();
    final organization = (preparer['organization'] ??
            preparer['company'] ??
            preparer['firm'] ??
            preparer['businessName'] ??
            '')
        .toString()
        .trim();

    final entries = await EvidenceLedger.readAll(engagementId);

    int ok = 0;
    int missing = 0;
    int mismatch = 0;

    final rows = <_CertRow>[];
    for (final e in entries) {
      final v = await EvidenceLedger.verifyEntry(e);
      final status = v.exists ? (v.hashMatches ? 'OK' : 'MISMATCH') : 'MISSING';

      if (status == 'OK') ok++;
      if (status == 'MISSING') missing++;
      if (status == 'MISMATCH') mismatch++;

      rows.add(
        _CertRow(
          fileName: e.fileName,
          sha256: e.sha256,
          createdAt: e.ts,
          status: status,
        ),
      );
    }

    final certId = _certificateId(
      engagementId: engagementId,
      generatedOn: generatedOn,
      total: rows.length,
      ok: ok,
      missing: missing,
      mismatch: mismatch,
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(50, 56, 50, 56),
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Opacity(
              opacity: 0.06,
              child: pw.Center(
                child: pw.Transform.rotate(
                  angle: -0.35,
                  child: pw.Text(
                    'CONFIDENTIAL',
                    style: pw.TextStyle(
                      fontSize: 90,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Prepared With: Auditron', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                'Cert v$certificateVersion • ID $certId • Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Text(
            'Evidence Integrity Certificate',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Client: $clientName', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Engagement: $engagementTitle', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Engagement ID: $engagementId', style: const pw.TextStyle(fontSize: 11)),
          if (engagementStatus.trim().isNotEmpty)
            pw.Text('Engagement Status: $engagementStatus', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Generated on: $generatedOn', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Certificate Version: $certificateVersion', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Certificate ID: $certId', style: const pw.TextStyle(fontSize: 11)),
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
                pw.Text('Verification Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Total entries: ${rows.length}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('OK: $ok', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Missing: $missing', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Mismatch: $mismatch', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),

          pw.SizedBox(height: 14),
          pw.Text('Evidence Register', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          if (rows.isEmpty)
            pw.Text('No evidence entries found.', style: const pw.TextStyle(fontSize: 11))
          else ...[
            _tableHeader(),
            for (final r in rows) _tableRow(r),
          ],

          pw.SizedBox(height: 16),
          pw.Text('Statement', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Paragraph(
            text:
                'This certificate summarizes the integrity verification results for the evidence recorded in Auditron. '
                'OK indicates the current file exists and matches the stored SHA-256 hash. '
                'MISSING indicates the file could not be found at the recorded path. '
                'MISMATCH indicates the file exists but does not match the recorded hash.',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),

          pw.SizedBox(height: 18),
          pw.Divider(),
          pw.SizedBox(height: 10),

          pw.Text('Signature Block', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Text('Prepared By: $preparedBy', style: const pw.TextStyle(fontSize: 11)),
          if (preparedTitle.isNotEmpty)
            pw.Text('Title: $preparedTitle', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            'Organization: ${organization.isEmpty ? "—" : organization}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Text('Prepared With: Auditron', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Date: $generatedOn', style: const pw.TextStyle(fontSize: 11)),

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

    // NOTE: keep filename format, but avoid spaces before date if you want.
    final outFileName = 'Auditron_EvidenceIntegrity_${safeId}_v$certificateVersion $generatedOn.pdf';
    final outPath = p.join(outDir.path, outFileName);

    await File(outPath).writeAsBytes(bytes, flush: true);

    bool opened = false;
    try {
      final res = await OpenFilex.open(outPath);
      opened = (res.type == ResultType.done);
    } catch (_) {}

    return EvidenceIntegrityCertificateResult(
      savedPath: outPath,
      savedFileName: outFileName,
      didOpenFile: opened,
    );
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
          pw.Expanded(
            flex: 4,
            child: pw.Text('File', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text('SHA-256', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableRow(_CertRow r) {
    final shaShort = r.sha256.length >= 12 ? '${r.sha256.substring(0, 12)}…' : r.sha256;

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
          pw.Expanded(flex: 4, child: pw.Text(r.fileName, style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shaShort, style: const pw.TextStyle(fontSize: 9)),
                if (r.sha256.isNotEmpty) pw.Text(r.sha256, style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ),
          pw.Expanded(flex: 2, child: pw.Text(_dateOnly(r.createdAt), style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 2, child: pw.Text(r.status, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _dateOnly(String iso) {
    final s = iso.trim();
    if (s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  static String _certificateId({
    required String engagementId,
    required String generatedOn,
    required int total,
    required int ok,
    required int missing,
    required int mismatch,
  }) {
    final rnd = Random().nextInt(9000) + 1000;
    return '${engagementId}_$generatedOn ${total}t_${ok}o_${missing}m_${mismatch}x_$rnd';
  }
}

class _CertRow {
  final String fileName;
  final String sha256;
  final String createdAt;
  final String status;

  const _CertRow({
    required this.fileName,
    required this.sha256,
    required this.createdAt,
    required this.status,
  });
}