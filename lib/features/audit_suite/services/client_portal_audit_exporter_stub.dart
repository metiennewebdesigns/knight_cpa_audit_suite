import '../../../core/storage/local_store.dart';

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
  static Future<ClientPortalAuditExportResult> exportPdf({
    required LocalStore store,
    required String engagementId,
  }) async {
    throw UnsupportedError('Client Portal Audit Trail export is not supported in the web demo.');
  }
}