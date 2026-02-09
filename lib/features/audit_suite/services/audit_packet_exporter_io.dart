// lib/features/audit_suite/services/audit_packet_exporter_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/local_store.dart';
import '../../../core/utils/doc_path.dart';

import '../data/models/client_models.dart';
import '../data/models/engagement_models.dart';
import '../data/models/risk_assessment_models.dart';
import '../data/models/workpaper_models.dart';

class ExportResultPaths {
  final String pdfPath;
  final String zipPath;

  const ExportResultPaths({
    required this.pdfPath,
    required this.zipPath,
  });
}

class CopyRow {
  final String scope;
  final String parent;
  final String file;
  final String status;

  const CopyRow({
    required this.scope,
    required this.parent,
    required this.file,
    required this.status,
  });
}

class AuditPacketExporter {
  /// Exports:
  /// 1) PDF into Documents/AuditPackets/<engId>/
  /// 2) Copies Workpaper + PBC attachments into Attachments/
  /// 3) Creates ZIP of the whole folder (excluding other zips)
  static Future<ExportResultPaths> exportPacketAndZip({
    required LocalStore store,
    required EngagementModel engagement,
    required ClientModel? client,
    required RiskAssessmentModel risk,
    required List<WorkpaperModel> workpapers,
    required String pbcPrefsKey,
  }) async {
    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }

    final packetDir = Directory(p.join(docsPath, 'AuditPackets', engagement.id));
    final attachmentsDir = Directory(p.join(packetDir.path, 'Attachments'));
    final pbcDir = Directory(p.join(attachmentsDir.path, '_PBC'));

    if (!packetDir.existsSync()) packetDir.createSync(recursive: true);
    if (!attachmentsDir.existsSync()) attachmentsDir.createSync(recursive: true);
    if (!pbcDir.existsSync()) pbcDir.createSync(recursive: true);

    // 1) Copy workpaper attachments
    final copiedWorkpaper = await _copyWorkpaperAttachments(
      attachmentsDir: attachmentsDir,
      workpapers: workpapers,
    );

    // 2) Copy PBC attachments (from prefs)
    final copiedPbc = await _copyPbcAttachments(
      store: store,
      pbcPrefsKey: pbcPrefsKey,
      pbcOutDir: pbcDir,
    );

    // 3) Generate PDF
    final pdfPath = await _writeAuditPacketPdf(
      packetDir: packetDir,
      engagement: engagement,
      client: client,
      risk: risk,
      workpapers: workpapers,
      copiedWorkpaper: copiedWorkpaper,
      copiedPbc: copiedPbc,
    );

    // 4) Zip everything
    final zipPath = await _zipDirectory(packetDir);

    return ExportResultPaths(pdfPath: pdfPath, zipPath: zipPath);
  }

  static Future<List<CopyRow>> _copyWorkpaperAttachments({
    required Directory attachmentsDir,
    required List<WorkpaperModel> workpapers,
  }) async {
    final results = <CopyRow>[];

    for (final wp in workpapers) {
      if (wp.attachments.isEmpty) continue;

      final wpFolder = Directory(p.join(attachmentsDir.path, _safeFolderName(wp.title)));
      if (!wpFolder.existsSync()) wpFolder.createSync(recursive: true);

      for (final a in wp.attachments) {
        final src = a.localPath.trim();
        if (src.isEmpty) {
          results.add(CopyRow(scope: 'Workpaper', parent: wp.title, file: a.name, status: 'missing-path'));
          continue;
        }

        final srcFile = File(src);
        if (!srcFile.existsSync()) {
          results.add(CopyRow(
            scope: 'Workpaper',
            parent: wp.title,
            file: a.name.isEmpty ? p.basename(src) : a.name,
            status: 'missing-file',
          ));
          continue;
        }

        final safeName = _safeFileName(a.name.isEmpty ? p.basename(src) : a.name);
        final dest = p.join(wpFolder.path, safeName);

        try {
          await srcFile.copy(dest);
          results.add(CopyRow(scope: 'Workpaper', parent: wp.title, file: safeName, status: 'copied'));
        } catch (_) {
          results.add(CopyRow(scope: 'Workpaper', parent: wp.title, file: safeName, status: 'copy-failed'));
        }
      }
    }

    if (results.isEmpty) {
      results.add(const CopyRow(scope: 'Workpaper', parent: '—', file: '—', status: 'no-attachments'));
    }

    return results;
  }

  static Future<List<CopyRow>> _copyPbcAttachments({
    required LocalStore store,
    required String pbcPrefsKey,
    required Directory pbcOutDir,
  }) async {
    final results = <CopyRow>[];

    final raw = store.prefs.getString(pbcPrefsKey);
    if (raw == null || raw.trim().isEmpty) {
      results.add(const CopyRow(scope: 'PBC', parent: '—', file: '—', status: 'no-pbc-data'));
      return results;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;

    for (final item in decoded) {
      final map = (item as Map).cast<String, dynamic>();

      final request = (map['request'] ?? '').toString();
      final pbcId = (map['id'] ?? '').toString();
      final atts = (map['attachments'] as List<dynamic>? ?? const []);

      if (atts.isEmpty) continue;

      final reqFolder = Directory(p.join(pbcOutDir.path, _safeFolderName('$request ($pbcId)')));
      if (!reqFolder.existsSync()) reqFolder.createSync(recursive: true);

      for (final a in atts) {
        final aMap = (a as Map).cast<String, dynamic>();

        final name = (aMap['name'] ?? '').toString();
        final localPath = ((aMap['localPath'] ?? aMap['path']) ?? '').toString();

        if (localPath.trim().isEmpty) {
          results.add(CopyRow(scope: 'PBC', parent: request, file: name, status: 'missing-path'));
          continue;
        }

        final srcFile = File(localPath);
        if (!srcFile.existsSync()) {
          results.add(CopyRow(
            scope: 'PBC',
            parent: request,
            file: name.isEmpty ? p.basename(localPath) : name,
            status: 'missing-file',
          ));
          continue;
        }

        final safeName = _safeFileName(name.isEmpty ? p.basename(localPath) : name);
        final dest = p.join(reqFolder.path, safeName);

        try {
          await srcFile.copy(dest);
          results.add(CopyRow(scope: 'PBC', parent: request, file: safeName, status: 'copied'));
        } catch (_) {
          results.add(CopyRow(scope: 'PBC', parent: request, file: safeName, status: 'copy-failed'));
        }
      }
    }

    if (results.isEmpty) {
      results.add(const CopyRow(scope: 'PBC', parent: '—', file: '—', status: 'no-attachments'));
    }

    return results;
  }

  static Future<String> _writeAuditPacketPdf({
    required Directory packetDir,
    required EngagementModel engagement,
    required ClientModel? client,
    required RiskAssessmentModel risk,
    required List<WorkpaperModel> workpapers,
    required List<CopyRow> copiedWorkpaper,
    required List<CopyRow> copiedPbc,
  }) async {
    final pdf = pw.Document();

    final clientName = client?.name ?? engagement.clientId;
    final riskLevel = risk.overallLevel();
    final riskScore = risk.overallScore1to5();

    pw.Widget tableFor(List<CopyRow> rows) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: const {
          0: pw.FlexColumnWidth(1),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _cell('Scope', bold: true),
              _cell('Parent', bold: true),
              _cell('File', bold: true),
              _cell('Status', bold: true),
            ],
          ),
          ...rows.map((r) => pw.TableRow(children: [
                _cell(r.scope),
                _cell(r.parent),
                _cell(r.file),
                _cell(r.status),
              ])),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text('Audit Packet', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Engagement: ${engagement.title}'),
          pw.Text('Engagement ID: ${engagement.id}'),
          pw.Text('Client: $clientName'),
          pw.Text('Status: ${engagement.status}'),
          pw.Text('Updated: ${engagement.updated}'),
          pw.SizedBox(height: 12),
          pw.Text('Risk: $riskLevel ($riskScore/5)'),
          pw.SizedBox(height: 14),
          pw.Text('Workpaper Index', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (workpapers.isEmpty) pw.Text('No workpapers found.') else pw.Bullet(text: 'Total workpapers: ${workpapers.length}'),
          pw.SizedBox(height: 16),
          pw.Text('Attachment Copy Report', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Workpaper attachments → Attachments/<Workpaper Title>'),
          pw.SizedBox(height: 6),
          tableFor(copiedWorkpaper),
          pw.SizedBox(height: 12),
          pw.Text('PBC attachments → Attachments/_PBC/<Request>'),
          pw.SizedBox(height: 6),
          tableFor(copiedPbc),
          pw.SizedBox(height: 18),
          pw.Text('Generated by Knight CPA Audit Suite', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );

    final fileName = 'audit_packet_${engagement.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outPath = p.join(packetDir.path, fileName);
    await File(outPath).writeAsBytes(await pdf.save(), flush: true);
    return outPath;
  }

  static Future<String> _zipDirectory(Directory dir) async {
    final zipName = 'audit_packet_bundle_${p.basename(dir.path)}_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipPath = p.join(dir.path, zipName);

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final entries = dir.listSync(recursive: true);
    for (final e in entries) {
      if (e is File) {
        if (e.path.endsWith('.zip')) continue;
        final rel = p.relative(e.path, from: dir.path);
        encoder.addFile(e, rel);
      }
    }

    encoder.close();
    return zipPath;
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _safeFolderName(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'Folder' : cleaned;
  }

  static String _safeFileName(String input) {
    var cleaned = input.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (cleaned.isEmpty) cleaned = 'attachment';
    if (cleaned.length > 120) {
      final ext = p.extension(cleaned);
      final base = p.basenameWithoutExtension(cleaned);
      cleaned = '${base.substring(0, 110)}$ext';
    }
    return cleaned;
  }
}