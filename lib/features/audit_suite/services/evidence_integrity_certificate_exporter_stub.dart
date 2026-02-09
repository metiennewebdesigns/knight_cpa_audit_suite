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
  static Future<EvidenceIntegrityCertificateResult> exportPdf({
    required String engagementId,
    required String engagementTitle,
    required String clientName,
    String engagementStatus = '',
    String clientTaxId = '',
    String clientEmail = '',
    String clientPhone = '',
  }) async {
    throw UnsupportedError('Evidence Integrity Certificate export is not supported in the web demo.');
  }
}