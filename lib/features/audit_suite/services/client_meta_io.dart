// lib/features/audit_suite/services/client_meta_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class ClientMeta {
  static Future<File> _file(String clientId) async {
    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }
    final dir = Directory(p.join(docsPath, 'Auditron', 'ClientMeta'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, '$clientId.json'));
  }

  /// Keys: address1,address2,city,state,postal,country
  static Future<Map<String, String>> readAddress(String clientId) async {
    try {
      final f = await _file(clientId);
      if (!await f.exists()) {
        return const {
          'address1': '',
          'address2': '',
          'city': '',
          'state': '',
          'postal': '',
          'country': '',
        };
      }

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) {
        return const {
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

      return {
        'address1': s('address1'),
        'address2': s('address2'),
        'city': s('city'),
        'state': s('state'),
        'postal': s('postal'),
        'country': s('country'),
      };
    } catch (_) {
      return const {
        'address1': '',
        'address2': '',
        'city': '',
        'state': '',
        'postal': '',
        'country': '',
      };
    }
  }

  static Future<void> saveAddress({
    required String clientId,
    required String address1,
    required String address2,
    required String city,
    required String state,
    required String postal,
    required String country,
  }) async {
    try {
      final f = await _file(clientId);
      final data = <String, dynamic>{
        'address1': address1.trim(),
        'address2': address2.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'postal': postal.trim(),
        'country': country.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  static Future<void> resetAddress(String clientId) async {
    try {
      final f = await _file(clientId);
      await f.writeAsString(
        jsonEncode({
          'address1': '',
          'address2': '',
          'city': '',
          'state': '',
          'postal': '',
          'country': '',
          'updatedAt': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (_) {}
  }

  static String formatSingleLine(Map<String, String> a) {
    final a1 = (a['address1'] ?? '').trim();
    final a2 = (a['address2'] ?? '').trim();
    final city = (a['city'] ?? '').trim();
    final state = (a['state'] ?? '').trim();
    final postal = (a['postal'] ?? '').trim();
    final country = (a['country'] ?? '').trim();

    final line = <String>[];
    if (a1.isNotEmpty) line.add(a1);
    if (a2.isNotEmpty) line.add(a2);

    final csz = <String>[];
    if (city.isNotEmpty) csz.add(city);
    if (state.isNotEmpty) csz.add(state);
    if (postal.isNotEmpty) csz.add(postal);

    if (csz.isNotEmpty) line.add(csz.join(', '));
    if (country.isNotEmpty) line.add(country);

    return line.join(' • ');
  }
}