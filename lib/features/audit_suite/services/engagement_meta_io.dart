// lib/features/audit_suite/services/engagement_meta_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class EngagementMeta {
  static Future<File> _metaFile(String engagementId) async {
    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }

    final dir = Directory(p.join(docsPath, 'Auditron', 'EngagementMeta'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, '$engagementId.json'));
  }

  static Future<Map<String, dynamic>> _read(String engagementId) async {
    try {
      final f = await _metaFile(engagementId);
      if (!await f.exists()) return <String, dynamic>{};
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return <String, dynamic>{};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _write(String engagementId, Map<String, dynamic> data) async {
    try {
      final f = await _metaFile(engagementId);
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // silent on purpose (export should still succeed)
    }
  }

  /// Set planningCompleted=true (idempotent)
  static Future<void> markPlanningCompleted(String engagementId) async {
    final data = await _read(engagementId);
    if (data['planningCompleted'] == true) return;

    data['planningCompleted'] = true;
    data['planningCompletedAt'] = DateTime.now().toIso8601String();
    await _write(engagementId, data);
  }

  /// Optional: clear planningCompleted
  static Future<void> clearPlanningCompleted(String engagementId) async {
    final data = await _read(engagementId);
    data.remove('planningCompleted');
    data.remove('planningCompletedAt');
    await _write(engagementId, data);
  }

  /// Read flag (used by dashboard/engagement readiness)
  static Future<bool> isPlanningCompleted(String engagementId) async {
    final data = await _read(engagementId);
    return data['planningCompleted'] == true;
  }
}