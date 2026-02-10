// lib/features/audit_suite/services/demo_seeder.dart
//
// One-time demo data seeding for CPA testing.
// Uses LocalStore.prefs (SharedPreferences) so it works on web + macOS.
//
// NOTE: This seeds JSON strings under keys like:
//   demo/clients/<id>, demo/engagements/<id>, demo/pbc/<engagementId>, etc.
// If any of your repositories expect different keys, we can map these in a thin adapter,
// but this file will no longer be "red" and is platform-safe.

import 'dart:convert';

import '../../../core/storage/local_store.dart';

const String _kDemoSeededKey = 'demo_seeded_v1';

class DemoSeeder {
  DemoSeeder._();

  static Future<bool> isSeeded(LocalStore store) async {
    return store.prefs.getBool(_kDemoSeededKey) == true;
  }

  static Future<void> markSeeded(LocalStore store) async {
    await store.prefs.setBool(_kDemoSeededKey, true);
  }

  static Future<void> reset(LocalStore store) async {
    await store.prefs.remove(_kDemoSeededKey);

    // Optional: wipe demo keys
    final keys = store.prefs.getKeys().where((k) => k.startsWith('demo/')).toList();
    for (final k in keys) {
      await store.prefs.remove(k);
    }
  }

  static Future<void> seedIfNeeded(LocalStore store) async {
    if (await isSeeded(store)) return;

    // ---- DEMO IDS ----
    const clientId = 'demo-client';
    const engagementId = 'demo-engagement';

    // ---- CLIENT ----
    await _writeJson(store, 'demo/clients/$clientId', {
      'id': clientId,
      'name': 'Demo Manufacturing LLC',
      'email': 'ap@demomanufacturing.com',
      'phone': '(555) 555-0199',
      'location': 'New Orleans, LA',
      'taxId': 'XX-XXXXXXX',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // ---- ENGAGEMENT ----
    await _writeJson(store, 'demo/engagements/$engagementId', {
      'id': engagementId,
      'clientId': clientId,
      'title': '2025 Financial Statement Audit',
      'status': 'Active',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // ---- PBC LIST (raw items) ----
    await _writeJson(store, 'demo/pbc/$engagementId', [
      {
        'id': 'pbc_1',
        'title': 'Final trial balance',
        'category': 'Financials',
        'status': 'received',
        'requestedAt': _daysAgoIso(20),
        'receivedAt': _daysAgoIso(10),
        'reviewedAt': '',
        'notes': '',
        'attachmentName': '',
        'attachmentPath': '',
        'attachmentSha256': '',
        'attachmentBytes': 0,
      },
      {
        'id': 'pbc_2',
        'title': 'Bank statements (all accounts)',
        'category': 'Cash',
        'status': 'reviewed',
        'requestedAt': _daysAgoIso(25),
        'receivedAt': _daysAgoIso(15),
        'reviewedAt': _daysAgoIso(5),
        'notes': '',
        'attachmentName': 'bank_statements.pdf',
        'attachmentPath': 'demo://bank_statements.pdf',
        'attachmentSha256': 'DEMO_SHA256_ABCDEF0123456789',
        'attachmentBytes': 123456,
      },
      {
        'id': 'pbc_3',
        'title': 'Accounts receivable aging',
        'category': 'Receivables',
        'status': 'requested',
        'requestedAt': _daysAgoIso(7),
        'receivedAt': '',
        'reviewedAt': '',
        'notes': '',
        'attachmentName': '',
        'attachmentPath': '',
        'attachmentSha256': '',
        'attachmentBytes': 0,
      },
    ]);

    // ---- PLANNING SUMMARY (demo) ----
    await _writeJson(store, 'demo/planning/$engagementId', {
      'narrative':
          'Audit planning focused on revenue recognition, AR valuation, and cash existence. '
          'Substantive procedures will be emphasized due to prior-year adjustments.',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // ---- RISK SUMMARY (demo) ----
    await _writeJson(store, 'demo/risk/$engagementId', {
      'overallLevel': 'Moderate',
      'score': 3,
      'notes': 'Revenue recognition and AR valuation identified as key risk areas.',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // ---- WORKPAPERS (demo) ----
    await _writeJson(store, 'demo/workpapers/$engagementId', [
      {'id': 'wp_1', 'title': 'Cash Lead Sheet', 'status': 'Complete'},
      {'id': 'wp_2', 'title': 'Revenue Substantive Testing', 'status': 'In Progress'},
      {'id': 'wp_3', 'title': 'AR Aging Tie-Out', 'status': 'Not Started'},
    ]);

    await markSeeded(store);
  }

  static Future<void> _writeJson(LocalStore store, String key, Object value) async {
    final raw = jsonEncode(value);
    await store.prefs.setString(key, raw);
  }

  static String _daysAgoIso(int days) =>
      DateTime.now().subtract(Duration(days: days)).toIso8601String();
}