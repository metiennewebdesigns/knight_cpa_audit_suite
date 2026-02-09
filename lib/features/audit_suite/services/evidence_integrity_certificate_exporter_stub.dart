// lib/features/audit_suite/services/evidence_integrity_certificate_exporter_stub.dart
//
// Web implementation: exporting to local Documents is disabled.

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
    throw UnsupportedError('Evidence Integrity Certificate export is disabled on web demo.');
  }
}