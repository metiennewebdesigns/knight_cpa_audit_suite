// lib/features/audit_suite/services/pbc_store_stub.dart
//
// Web implementation: no local filesystem persistence.
// Return empty list and no-op save.

class PbcStore {
  static Future<List<Map<String, dynamic>>> loadRaw(String engagementId) async {
    return const <Map<String, dynamic>>[];
  }

  static Future<void> saveRaw(String engagementId, List<Map<String, dynamic>> items) async {
    // no-op on web
  }
}