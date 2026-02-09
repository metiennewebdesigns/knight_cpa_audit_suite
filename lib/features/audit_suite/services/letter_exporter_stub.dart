// lib/features/audit_suite/services/letter_exporter_stub.dart
//
// Web implementation: exporting PDFs to local Documents is disabled.
// Keep preview text working so the UI can still render letters.

import '../../../core/storage/local_store.dart';

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
    throw UnsupportedError('Letter export is disabled on web demo.');
  }

  static Future<int> getLettersGeneratedCount({
    required String docsPath,
    required String engagementId,
  }) async {
    // Web has no local letters meta file.
    return 0;
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

  static String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}