// lib/features/audit_suite/services/pbc_pdf_exporter_io.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PbcPdfExportResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const PbcPdfExportResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

class PbcPdfExporter {
  static Future<PbcPdfExportResult> export({
    required String engagementId,
    required String clientName,
    required String clientAddressLine,
    required String preparerName,
    required String preparerLine2,
    required List<Map<String, dynamic>> itemsRaw,
  }) async {
    final items = itemsRaw.map(_PbcLine.fromJson).toList();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          _header(
            engagementId: engagementId,
            clientName: clientName,
            clientAddressLine: clientAddressLine,
            preparerName: preparerName,
            preparerLine2: preparerLine2,
          ),
          pw.SizedBox(height: 14),
          _summary(items),
          pw.SizedBox(height: 12),
          _table(items),
          pw.SizedBox(height: 18),
          _footer(preparerName: preparerName),
        ],
      ),
    );

    final bytes = Uint8List.fromList(await doc.save());

    final fileName = 'PBC_${_safeFileChunk(engagementId)}_${_yyyymmdd()}.pdf';
    final savedPath = await _savePdf(fileName: fileName, bytes: bytes);

    bool didOpen = false;
    try {
      final r = await OpenFilex.open(savedPath);
      didOpen = (r.type == ResultType.done);
    } catch (_) {
      didOpen = false;
    }

    return PbcPdfExportResult(
      savedPath: savedPath,
      savedFileName: fileName,
      didOpenFile: didOpen,
    );
  }

  static pw.Widget _header({
    required String engagementId,
    required String clientName,
    required String clientAddressLine,
    required String preparerName,
    required String preparerLine2,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.grey300)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Provided-By-Client (PBC) List',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Engagement: $engagementId', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 2),
                pw.Text('Date: ${_yyyymmdd()}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(preparerName,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (preparerLine2.trim().isNotEmpty)
                  pw.Text(preparerLine2.trim(), style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Text(clientName.isEmpty ? 'Client' : clientName,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right),
                if (clientAddressLine.trim().isNotEmpty)
                  pw.Text(clientAddressLine.trim(),
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summary(List<_PbcLine> items) {
    int c(String s) => items.where((i) => i.status == s).length;
    return pw.Row(
      children: [
        _chip('Requested: ${c('requested')}'),
        pw.SizedBox(width: 8),
        _chip('Received: ${c('received')}'),
        pw.SizedBox(width: 8),
        _chip('Reviewed: ${c('reviewed')}'),
      ],
    );
  }

  static pw.Widget _chip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static pw.Widget _table(List<_PbcLine> items) {
    final headers = ['Category', 'Item', 'Status', 'Requested', 'Received', 'Reviewed', 'Evidence'];

    final data = items.map((i) {
      final ev = (i.attachmentSha256.isNotEmpty && i.attachmentPath.isNotEmpty)
          ? 'SHA ${i.attachmentSha256.substring(0, 10)}…'
          : '';
      return [
        i.category,
        i.title,
        i.statusLabel,
        _shortDate(i.requestedAt),
        _shortDate(i.receivedAt),
        _shortDate(i.reviewedAt),
        ev,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.topLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(3.2),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FlexColumnWidth(1.0),
        6: const pw.FlexColumnWidth(1.6),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
    );
  }

  static pw.Widget _footer({required String preparerName}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Generated by Auditron',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Preparer: $preparerName', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 2),
        pw.Text('Evidence hashes (SHA-256) shown are truncated for readability.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  static Future<String> _savePdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'auditron', 'exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final outPath = p.join(dir.path, safeName);

    final f = File(outPath);
    await f.writeAsBytes(bytes, flush: true);
    return outPath;
  }

  static String _yyyymmdd() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _shortDate(String iso) {
    final t = iso.trim();
    if (t.isEmpty) return '';
    try {
      final d = DateTime.parse(t);
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd';
    } catch (_) {
      return '';
    }
  }

  static String _safeFileChunk(String input) {
    final s = input.trim();
    if (s.isEmpty) return 'engagement';
    final cleaned = s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }
}

class _PbcLine {
  final String title;
  final String category;
  final String status;
  final String requestedAt;
  final String receivedAt;
  final String reviewedAt;
  final String attachmentPath;
  final String attachmentSha256;

  _PbcLine({
    required this.title,
    required this.category,
    required this.status,
    required this.requestedAt,
    required this.receivedAt,
    required this.reviewedAt,
    required this.attachmentPath,
    required this.attachmentSha256,
  });

  String get statusLabel {
    switch (status) {
      case 'received':
        return 'Received';
      case 'reviewed':
        return 'Reviewed';
      default:
        return 'Requested';
    }
  }

  static _PbcLine fromJson(Map<String, dynamic> j) {
    return _PbcLine(
      title: (j['title'] ?? '').toString(),
      category: (j['category'] ?? 'General').toString(),
      status: (j['status'] ?? 'requested').toString(),
      requestedAt: (j['requestedAt'] ?? '').toString(),
      receivedAt: (j['receivedAt'] ?? '').toString(),
      reviewedAt: (j['reviewedAt'] ?? '').toString(),
      attachmentPath: (j['attachmentPath'] ?? '').toString(),
      attachmentSha256: (j['attachmentSha256'] ?? '').toString(),
    );
  }
}