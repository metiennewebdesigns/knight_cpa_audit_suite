import '../../../core/storage/local_store.dart';

/// Matches the IO API, but does nothing on web.
class ActivityLogEntry {
  final String kind;
  final String title;
  final String engagementId;
  final String createdAtIso;
  final Map<String, dynamic> meta;

  const ActivityLogEntry({
    required this.kind,
    required this.title,
    required this.engagementId,
    required this.createdAtIso,
    required this.meta,
  });
}

class ActivityLog {
  static Future<void> logLetterExport({
    required LocalStore store,
    required String engagementId,
    String? clientId,
    required String letterType,
    required String fileName,
    String? filePath,
  }) async {
    // no-op on web
  }

  static Future<List<ActivityLogEntry>> readRecent(
    LocalStore store, {
    int limit = 25,
  }) async {
    return const <ActivityLogEntry>[];
  }
}