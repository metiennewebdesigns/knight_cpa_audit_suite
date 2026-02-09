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
    throw UnsupportedError('Deliverable Pack export is not supported in the web demo.');
  }
}