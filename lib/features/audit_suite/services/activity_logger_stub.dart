// lib/features/audit_suite/services/activity_logger_stub.dart
//
// Web implementation: no local filesystem.
// We no-op writes and return empty reads.

class ActivityEvent {
  final String ts; // ISO8601
  final String kind;
  final String engagementId;
  final String title;
  final String detail;

  const ActivityEvent({
    required this.ts,
    required this.kind,
    required this.engagementId,
    required this.title,
    required this.detail,
  });

  DateTime? get time {
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'kind': kind,
        'engagementId': engagementId,
        'title': title,
        'detail': detail,
      };

  static ActivityEvent? fromJson(Map<String, dynamic> j) {
    final ts = (j['ts'] ?? '').toString();
    final kind = (j['kind'] ?? '').toString();
    final engagementId = (j['engagementId'] ?? '').toString();
    final title = (j['title'] ?? '').toString();
    final detail = (j['detail'] ?? '').toString();
    if (ts.isEmpty || kind.isEmpty || engagementId.isEmpty) return null;
    return ActivityEvent(
      ts: ts,
      kind: kind,
      engagementId: engagementId,
      title: title,
      detail: detail,
    );
  }
}

class ActivityLogger {
  static Future<void> log({
    String? docsPath,
    required String kind,
    required String engagementId,
    required String title,
    required String detail,
  }) async {
    // no-op on web
  }

  static Future<List<ActivityEvent>> readRecent({
    String? docsPath,
    int limit = 10,
  }) async {
    return const <ActivityEvent>[];
  }
}