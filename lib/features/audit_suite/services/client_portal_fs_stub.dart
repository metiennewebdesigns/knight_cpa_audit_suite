// lib/features/audit_suite/services/client_portal_fs_stub.dart
//
// Web implementation: file-backed portal features disabled.

class VaultSaveResult {
  final String fileName;
  final String filePath;
  final int bytes;
  final String sha256;

  const VaultSaveResult({
    required this.fileName,
    required this.filePath,
    required this.bytes,
    required this.sha256,
  });
}

class ClientPortalFs {
  static Future<Map<String, dynamic>> readEngagementMeta(String engagementId) async => {};

  static Future<List<Map<String, dynamic>>> readPortalLogEvents(String engagementId, {int limit = 200}) async => const [];

  static Future<void> logPortalEvent({
    required String engagementId,
    required String kind,
    required String note,
    Map<String, dynamic>? extra,
  }) async {
    // no-op
  }

  static Future<List<Map<String, dynamic>>> readPbcItemsRaw(String engagementId) async => const [];

  static Future<void> markPbcItemReceived(String engagementId, String itemId) async {
    // no-op
  }

  static Future<VaultSaveResult> saveToVaultAndLedger({
    required String engagementId,
    required String sourcePath,
    required String originalName,
    required String pbcItemId,
    required String pbcItemTitle,
  }) async {
    throw UnsupportedError('Uploads are disabled on web demo.');
  }
}