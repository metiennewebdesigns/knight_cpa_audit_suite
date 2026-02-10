// lib/features/audit_suite/services/pbc_pdf_exporter_stub.dart
//
// Web-safe stub so the app compiles on web without dart:io.
// Your UI already disables export on web demo (kIsWeb / canUseFileSystem).

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
    // Web stub: no filesystem support. Keep call sites working.
    return const PbcPdfExportResult(
      savedPath: '',
      savedFileName: 'pbc_export.pdf',
      didOpenFile: false,
    );
  }
}