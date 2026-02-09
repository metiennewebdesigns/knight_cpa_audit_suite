// lib/features/audit_suite/services/engagement_meta_stub.dart
//
// Web implementation: no local filesystem.
// Treat planningCompleted as false and ignore writes.

class EngagementMeta {
  static Future<void> markPlanningCompleted(String engagementId) async {
    // no-op on web
  }

  static Future<void> clearPlanningCompleted(String engagementId) async {
    // no-op on web
  }

  static Future<bool> isPlanningCompleted(String engagementId) async {
    return false;
  }
}