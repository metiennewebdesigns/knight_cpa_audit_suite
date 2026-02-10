import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage/local_store.dart';

/// A single activity log entry (stored as JSONL).
class ActivityLogEntry {
  final String kind; // e.g. "letter_export"
  final String title; // e.g. "Letter exported"
  final String engagementId; // may be ""
  final String createdAtIso; // ISO timestamp
  final Map<String, dynamic> meta; // any extra info

  const ActivityLogEntry({
    required this.kind,
    required this.title,
    required this.engagementId,
    required this.createdAtIso,
    required this.meta,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'title': title,
        'engagementId': engagementId,
        'createdAt': createdAtIso,
        'meta': meta,
      };

  static ActivityLogEntry fromJson(Map<String, dynamic> j) {
    return ActivityLogEntry(
      kind: (j['kind'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      engagementId: (j['engagementId'] ?? '').toString(),
      createdAtIso: (j['createdAt'] ?? '').toString(),
      meta: (j['meta'] is Map)
          ? Map<String, dynamic>.from(j['meta'] as Map)
          : <String, dynamic>{},
    );
  }
}

class ActivityLog {
  static Future<String> _docsPath(LocalStore store) async {
    final docs = store.documentsPath;
    if (docs == null || docs.trim().isEmpty) {
      throw StateError('LocalStore.documentsPath is empty');
    }
    return docs;
  }

  static Future<File> _logFile(LocalStore store) async {
    final docsPath = await _docsPath(store);
    final dir = Directory(p.join(docsPath, 'Auditron', 'Activity'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'activity.jsonl'));
  }

  static Future<void> _append(LocalStore store, ActivityLogEntry entry) async {
    final f = await _logFile(store);
    await f.writeAsString('${jsonEncode(entry.toJson())}\n', mode: FileMode.append, flush: true);
  }

  /// ✅ Called by LetterExporter after a successful export.
  static Future<void> logLetterExport({
    required LocalStore store,
    required String engagementId,
    String? clientId, // optional (nice to have)
    required String letterType, // engagement|pbc|mrl
    required String fileName,
    String? filePath,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _append(
      store,
      ActivityLogEntry(
        kind: 'letter_export',
        title: 'Letter exported',
        engagementId: engagementId,
        createdAtIso: now,
        meta: <String, dynamic>{
          'letterType': letterType,
          'fileName': fileName,
          if ((filePath ?? '').trim().isNotEmpty) 'filePath': filePath,
          if ((clientId ?? '').trim().isNotEmpty) 'clientId': clientId,
        },
      ),
    );
  }

  /// Read recent activity. (Dashboard uses this)
  static Future<List<ActivityLogEntry>> readRecent(
    LocalStore store, {
    int limit = 25,
  }) async {
    try {
      final f = await _logFile(store);
      if (!await f.exists()) return const <ActivityLogEntry>[];

      final lines = await f.readAsLines();
      final out = <ActivityLogEntry>[];

      for (final line in lines.reversed) {
        final s = line.trim();
        if (s.isEmpty) continue;

        try {
          final j = jsonDecode(s);
          if (j is Map<String, dynamic>) {
            out.add(ActivityLogEntry.fromJson(j));
          } else if (j is Map) {
            out.add(ActivityLogEntry.fromJson(Map<String, dynamic>.from(j)));
          }
        } catch (_) {
          // skip malformed line
        }

        if (out.length >= limit) break;
      }

      return out;
    } catch (_) {
      return const <ActivityLogEntry>[];
    }
  }
}