// lib/features/audit_suite/services/preparer_profile_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class PreparerProfile {
  static Future<File> _file() async {
    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }

    final dir = Directory(p.join(docsPath, 'Auditron', 'Settings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'preparer.json'));
  }

  /// Returns safe defaults if not set.
  /// Keys:
  /// name, line2, address1, address2, city, state, postal, country
  static Future<Map<String, String>> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return const {
          'name': 'Independent Auditor',
          'line2': '',
          'address1': '',
          'address2': '',
          'city': '',
          'state': '',
          'postal': '',
          'country': '',
        };
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const {
          'name': 'Independent Auditor',
          'line2': '',
          'address1': '',
          'address2': '',
          'city': '',
          'state': '',
          'postal': '',
          'country': '',
        };
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;

      String s(String k) => (data[k] ?? '').toString().trim();

      final name = s('preparerName');
      return {
        'name': name.isEmpty ? 'Independent Auditor' : name,
        'line2': s('preparerLine2'),
        'address1': s('preparerAddress1'),
        'address2': s('preparerAddress2'),
        'city': s('preparerCity'),
        'state': s('preparerState'),
        'postal': s('preparerPostal'),
        'country': s('preparerCountry'),
      };
    } catch (_) {
      return const {
        'name': 'Independent Auditor',
        'line2': '',
        'address1': '',
        'address2': '',
        'city': '',
        'state': '',
        'postal': '',
        'country': '',
      };
    }
  }

  static Future<void> save({
    required String preparerName,
    String preparerLine2 = '',
    String preparerAddress1 = '',
    String preparerAddress2 = '',
    String preparerCity = '',
    String preparerState = '',
    String preparerPostal = '',
    String preparerCountry = '',
  }) async {
    final safeName = preparerName.trim().isEmpty ? 'Independent Auditor' : preparerName.trim();

    final data = <String, dynamic>{
      'preparerName': safeName,
      'preparerLine2': preparerLine2.trim(),
      'preparerAddress1': preparerAddress1.trim(),
      'preparerAddress2': preparerAddress2.trim(),
      'preparerCity': preparerCity.trim(),
      'preparerState': preparerState.trim(),
      'preparerPostal': preparerPostal.trim(),
      'preparerCountry': preparerCountry.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // silent
    }
  }

  static Future<void> resetToDefault() async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          'preparerName': 'Independent Auditor',
          'preparerLine2': '',
          'preparerAddress1': '',
          'preparerAddress2': '',
          'preparerCity': '',
          'preparerState': '',
          'preparerPostal': '',
          'preparerCountry': '',
          'updatedAt': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (_) {}
  }
}