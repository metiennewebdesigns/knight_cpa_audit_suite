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
    throw UnsupportedError('PBC PDF export is disabled on web demo.');
  }
}