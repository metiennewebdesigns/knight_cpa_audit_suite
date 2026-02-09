// lib/features/audit_suite/services/activity_logger_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File, FileMode;

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class ActivityEvent {
  final String ts; // ISO8601
  final String kind; // letter_export | workpaper_added | engagement_saved | engagement_finalized | engagement_reopened
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
  static Future<File> _file({String? docsPath}) async {
    final String basePath;
    if (docsPath != null && docsPath.trim().isNotEmpty) {
      basePath = docsPath;
    } else {
      final dp = await getDocumentsPath();
      if (dp == null || dp.isEmpty) {
        throw StateError('Documents directory not available.');
      }
      basePath = dp;
    }

    final dir = Directory(p.join(basePath, 'Auditron', 'Activity'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'activity.jsonl'));
  }

  static Future<void> log({
    String? docsPath,
    required String kind,
    required String engagementId,
    required String title,
    required String detail,
  }) async {
    try {
      final f = await _file(docsPath: docsPath);
      final ev = ActivityEvent(
        ts: DateTime.now().toIso8601String(),
        kind: kind,
        engagementId: engagementId,
        title: title,
        detail: detail,
      );
      await f.writeAsString(
        '${jsonEncode(ev.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // fail silently
    }
  }

  static Future<List<ActivityEvent>> readRecent({
    String? docsPath,
    int limit = 10,
  }) async {
    try {
      final f = await _file(docsPath: docsPath);
      if (!await f.exists()) return const <ActivityEvent>[];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const <ActivityEvent>[];

      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final events = <ActivityEvent>[];

      for (int i = lines.length - 1; i >= 0 && events.length < limit; i--) {
        final line = lines[i].trim();
        try {
          final map = jsonDecode(line) as Map<String, dynamic>;
          final ev = ActivityEvent.fromJson(map);
          if (ev != null) events.add(ev);
        } catch (_) {
          // skip bad line
        }
      }

      events.sort((a, b) {
        final ta = a.time;
        final tb = b.time;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      return events;
    } catch (_) {
      return const <ActivityEvent>[];
    }
  }
}