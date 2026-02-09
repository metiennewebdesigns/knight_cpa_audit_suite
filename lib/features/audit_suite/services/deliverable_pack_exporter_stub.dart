// lib/features/audit_suite/services/deliverable_pack_exporter_stub.dart
//
// Web implementation: exporting to local Documents is disabled.
// Keep the class/return types so UI compiles cleanly.

import '../../../core/storage/local_store.dart';

class DeliverablePackResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const DeliverablePackResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

class DeliverablePackExporter {
  static Future<DeliverablePackResult> exportPdf({
    required LocalStore store,
    required String engagementId,
  }) async {
    throw UnsupportedError('Deliverable Pack export is disabled on web demo.');
  }
}