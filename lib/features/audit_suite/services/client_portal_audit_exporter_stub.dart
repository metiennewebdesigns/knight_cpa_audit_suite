// lib/features/audit_suite/services/client_portal_audit_exporter_stub.dart
//
// Web implementation: exporting to local Documents is disabled.

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
  static const String reportVersion = '1.0';

  static Future<ClientPortalAuditExportResult> exportPdf({
    required LocalStore store,
    required String engagementId,
  }) async {
    throw UnsupportedError('Client Portal Audit Trail export is disabled on web demo.');
  }
}