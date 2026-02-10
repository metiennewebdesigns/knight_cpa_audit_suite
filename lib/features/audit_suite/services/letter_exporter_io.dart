// lib/features/audit_suite/services/letter_exporter_io.dart
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
import '../services/preparer_profile.dart';
import '../services/client_meta.dart';
import 'activity_log.dart';

class LetterExportResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const LetterExportResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

class LetterExporter {
  static String buildLetterTextPreview({
    required String engagementId,
    required String type,
  }) {
    final today = _todayIso();

    switch (type) {
      case 'engagement':
        return _engagementLetterText(today: today, engagementId: engagementId);
      case 'pbc':
        return _pbcLetterText(today: today, engagementId: engagementId);
      case 'mrl':
        return _mrlLetterText(today: today, engagementId: engagementId);
      default:
        return 'Unknown letter type: $type';
    }
  }

  static Future<LetterExportResult> exportPdf({
    required LocalStore store,
    required String engagementId,
    required String type,
  }) async {
    final doc = pw.Document();

    final title = _titleForType(type);
    final body = buildLetterTextPreview(engagementId: engagementId, type: type);

    // Preparer
    final preparer = await PreparerProfile.read();
    final preparerName = preparer['name'] ?? 'Independent Auditor';
    final preparerLine2 = (preparer['line2'] ?? '').trim();

    // Client info
    String clientName = '';
    String clientAddressLine = '';
    String clientId = '';
    try {
      final engRepo = EngagementsRepository(store);
      final clientsRepo = ClientsRepository(store);

      final eng = await engRepo.getById(engagementId);
      if (eng != null) {
        clientId = eng.clientId;
        final client = await clientsRepo.getById(eng.clientId);
        clientName = (client?.name ?? eng.clientId).toString();

        final addr = await ClientMeta.readAddress(eng.clientId);
        clientAddressLine = ClientMeta.formatSingleLine(addr);
      }
    } catch (_) {}

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
                pw.Text(
                  'Auditron',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Prepared by: $preparerName',
                  style: const pw.TextStyle(fontSize: 10),
                ),
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
            if (clientName.trim().isNotEmpty)
              pw.Text(
                'Client: $clientName',
                style: const pw.TextStyle(fontSize: 9),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
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
              pw.Text(
                'Prepared using Auditron • Audit clarity. Automated.',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Generated on $generatedOn • Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),

        build: (_) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Paragraph(
            text: body,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
        ],
      ),
    );

    final bytes = await doc.save();

    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docs.path, 'Auditron', 'Letters'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final safeType = type.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final safeEngagementId = engagementId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final fileName = 'Auditron_${safeType}_${safeEngagementId}_${_todayIso()}.pdf';
    final outPath = p.join(folder.path, fileName);

    final f = File(outPath);
    await f.writeAsBytes(bytes, flush: true);

    bool opened = false;
    try {
      final res = await OpenFilex.open(outPath);
      opened = (res.type == ResultType.done);
    } catch (_) {}

    await _recordLetterExport(
      docsPath: docs.path,
      engagementId: engagementId,
      type: type,
      fileName: fileName,
      filePath: outPath,
    );

    // ✅ NEW: Activity feed entry (IO only)
    try {
      await ActivityLog.logLetterExport(
        store: store,
        engagementId: engagementId,
        clientId: clientId, // ✅ now supported
        letterType: type,
        fileName: fileName,
        filePath: outPath, // optional but recommended
     );
    } catch (_) {}

    return LetterExportResult(
      savedPath: outPath,
      savedFileName: fileName,
      didOpenFile: opened,
    );
  }

  static String _titleForType(String type) {
    switch (type) {
      case 'engagement':
        return 'Engagement Letter';
      case 'pbc':
        return 'PBC Request Letter';
      case 'mrl':
        return 'Management Representation Letter';
      default:
        return 'Letter';
    }
  }

  static String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static Future<void> _recordLetterExport({
    required String docsPath,
    required String engagementId,
    required String type,
    required String fileName,
    required String filePath,
  }) async {
    try {
      final metaDir = Directory(p.join(docsPath, 'Auditron', 'Letters', '_meta'));
      if (!await metaDir.exists()) {
        await metaDir.create(recursive: true);
      }

      final metaFile = File(p.join(metaDir.path, '$engagementId.json'));

      Map<String, dynamic> data = {};
      if (await metaFile.exists()) {
        final raw = await metaFile.readAsString();
        if (raw.trim().isNotEmpty) {
          data = jsonDecode(raw) as Map<String, dynamic>;
        }
      }

      final List<dynamic> exports = (data['exports'] as List<dynamic>?) ?? <dynamic>[];

      exports.add({
        'type': type,
        'fileName': fileName,
        'filePath': filePath,
        'createdAt': DateTime.now().toIso8601String(),
      });

      data['engagementId'] = engagementId;
      data['exports'] = exports;

      await metaFile.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  static Future<int> getLettersGeneratedCount({
    required String docsPath,
    required String engagementId,
  }) async {
    try {
      final metaFile = File(p.join(docsPath, 'Auditron', 'Letters', '_meta', '$engagementId.json'));
      if (!await metaFile.exists()) return 0;

      final raw = await metaFile.readAsString();
      if (raw.trim().isEmpty) return 0;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final exports = (data['exports'] as List<dynamic>?) ?? <dynamic>[];
      return exports.length;
    } catch (_) {
      return 0;
    }
  }

  static String _engagementLetterText({
    required String today,
    required String engagementId,
  }) {
    return '''
$today

RE: Audit Engagement – Engagement ID $engagementId

To Management:

This letter confirms our understanding of the services we will provide to you in connection with the audit of your financial statements for the period to be agreed.

Objective and Scope
We will conduct our audit in accordance with auditing standards generally accepted in the United States of America (GAAS). The objective of an audit is to obtain reasonable assurance about whether the financial statements are free of material misstatement, whether due to fraud or error.

Auditor Responsibilities
Our audit will include performing procedures to assess the risks of material misstatement, examining evidence, and evaluating accounting principles and significant estimates. Because of the inherent limitations of an audit, an unavoidable risk exists that some material misstatements may not be detected, even though the audit is properly planned and performed.

Management Responsibilities
Management is responsible for (a) the preparation and fair presentation of the financial statements in accordance with the applicable financial reporting framework; (b) the design, implementation, and maintenance of internal control relevant to the preparation and fair presentation of financial statements; and (c) providing us with access to all information of which management is aware that is relevant to the preparation of the financial statements.

Deliverables
We will issue an independent auditor’s report upon completion of our audit, subject to the results of our procedures.

Acknowledgement
Please confirm your agreement with the terms of this engagement by signing and returning this letter.

Sincerely,

______________________________
Prepared By: ______________________
Title/Company: ____________________
Date: ____________

Acknowledged and agreed:

______________________________
Client Authorized Representative
Date: ____________
''';
  }

  static String _pbcLetterText({
    required String today,
    required String engagementId,
  }) {
    return '''
$today

RE: Provided-By-Client (PBC) Request – Engagement ID $engagementId

To Management:

As part of our audit planning and fieldwork, we request the following information and documents. Please provide the items through your agreed secure delivery method.

PBC Items (Summary)
• Final trial balance (export)
• Bank statements for all accounts (period under audit)
• Accounts receivable aging and supporting detail
• Significant contracts and related amendments
• Schedule of fixed assets and depreciation
• Debt agreements and covenant calculations
• Revenue support (invoices / contracts / receipts) for sample selections

Timing
To support our planned timeline, please provide the requested items as soon as practical. If any item is unavailable, please notify us promptly with an expected delivery date.

Thank you for your cooperation.

Sincerely,

______________________________
Prepared By: ______________________
Title/Company: ____________________
Date: ____________
''';
  }

  static String _mrlLetterText({
    required String today,
    required String engagementId,
  }) {
    return '''
$today

Management Representation Letter
Engagement ID $engagementId

To the Auditor:

In connection with your audit of our financial statements, we confirm, to the best of our knowledge and belief, the following representations made to you during your audit:

• We have fulfilled our responsibility for the preparation and fair presentation of the financial statements in accordance with the applicable financial reporting framework.
• We have provided you with access to all relevant information and additional information requested.
• All transactions have been recorded and are reflected in the financial statements.
• We acknowledge our responsibility for internal control and for preventing and detecting fraud.

This letter is intended solely for your information in connection with your audit.

Sincerely,

______________________________
Prepared By: ______________________
Title/Company: ____________________
Date: ____________
''';
  }
}