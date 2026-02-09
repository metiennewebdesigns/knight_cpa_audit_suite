// lib/features/audit_suite/services/pbc_store_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class PbcStore {
  static Future<File> _file(String engagementId) async {
    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }
    final dir = Directory(p.join(docsPath, 'Auditron', 'PBC'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, '$engagementId.json'));
  }

  static Future<List<Map<String, dynamic>>> loadRaw(String engagementId) async {
    try {
      final f = await _file(engagementId);
      if (!await f.exists()) return <Map<String, dynamic>>[];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return <Map<String, dynamic>>[];
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['items'] as List<dynamic>? ?? <dynamic>[]);
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveRaw(String engagementId, List<Map<String, dynamic>> items) async {
    try {
      final f = await _file(engagementId);
      final data = <String, dynamic>{
        'engagementId': engagementId,
        'updatedAt': DateTime.now().toIso8601String(),
        'items': items,
      };
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }
}