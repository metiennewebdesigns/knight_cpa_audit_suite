import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'file_save_open.dart';

class PbcPdfExporter {
  static Future<SaveOpenResult> export({
    required String engagementId,
    required String clientName,
    required String clientAddressLine,
    required String preparerName,
    required String preparerLine2,
    required List<Map<String, dynamic>> itemsRaw,
  }) async {
    final requested = <Map<String, dynamic>>[];
    final received = <Map<String, dynamic>>[];
    final reviewed = <Map<String, dynamic>>[];

    for (final it in itemsRaw) {
      final s = (it['status'] ?? '').toString().toLowerCase();
      if (s == 'reviewed') {
        reviewed.add(it);
      } else if (s == 'received') {
        received.add(it);
      } else {
        requested.add(it);
      }
    }

    final doc = pw.Document();
    final generatedOn = _todayIso();

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
            if (preparerLine2.trim().isNotEmpty)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(preparerLine2.trim(), style: const pw.TextStyle(fontSize: 9), maxLines: 1),
              ),
            pw.SizedBox(height: 4),
            if (clientName.trim().isNotEmpty)
              pw.Text('Client: $clientName', style: const pw.TextStyle(fontSize: 9), maxLines: 1),
            if (clientAddressLine.trim().isNotEmpty)
              pw.Text(
                'Client Address: $clientAddressLine',
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
        build: (_) => [
          pw.Text(
            'Provided-By-Client (PBC) Request',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Engagement ID: $engagementId', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 14),

          pw.Text('Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Bullet(text: 'Requested: ${requested.length}', style: const pw.TextStyle(fontSize: 11)),
          pw.Bullet(text: 'Received: ${received.length}', style: const pw.TextStyle(fontSize: 11)),
          pw.Bullet(text: 'Reviewed: ${reviewed.length}', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),

          pw.Text('Requested Items', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (requested.isEmpty)
            pw.Paragraph(
              text: 'No outstanding requested items.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            )
          else
            ...requested.map((i) {
              final cat = (i['category'] ?? 'General').toString();
              final title = (i['title'] ?? i['name'] ?? 'PBC Item').toString();
              return pw.Bullet(text: '[$cat] $title', style: const pw.TextStyle(fontSize: 11));
            }),

          pw.SizedBox(height: 14),
          pw.Text('Notes', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Paragraph(
            text:
                'Please provide items through your agreed secure delivery method. If an item is unavailable, notify us with an expected delivery date.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
        ],
      ),
    );

    final bytes = await doc.save();

    final safeId = engagementId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final fileName = 'Auditron_PBC_${safeId}_${_todayIso()}.pdf';

    return savePdfBytesAndMaybeOpen(
      fileName: fileName,
      bytes: bytes,
      subfolder: 'Auditron/PBC',
    );
  }

  static String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}