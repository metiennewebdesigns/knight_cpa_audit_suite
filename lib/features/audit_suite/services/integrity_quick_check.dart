import 'package:flutter/foundation.dart';

import '../../../core/storage/local_store.dart';
import 'evidence_ledger.dart';

class IntegrityQuickResult {
  final int checked;
  final int issues;
  final String checkedAtIso;

  const IntegrityQuickResult({
    required this.checked,
    required this.issues,
    required this.checkedAtIso,
  });
}

class IntegrityQuickCheck {
  static String _key(String engagementId) => 'integrity_last_check_$engagementId';

  static Future<IntegrityQuickResult> run({
    required LocalStore store,
    required String engagementId,
    int maxEntriesToCheck = 20,
    Duration minInterval = const Duration(minutes: 10),
  }) async {
    // Web demo: keep it cheap (ledger stub likely returns empty anyway)
    if (kIsWeb) {
      return const IntegrityQuickResult(checked: 0, issues: 0, checkedAtIso: '');
    }

    final lastIso = store.prefs.getString(_key(engagementId)) ?? '';
    final last = DateTime.tryParse(lastIso);
    if (last != null && DateTime.now().difference(last) < minInterval) {
      // Don’t recompute; return “unknown but recent”
      return IntegrityQuickResult(
        checked: 0,
        issues: 0,
        checkedAtIso: last.toIso8601String(),
      );
    }

    final entries = await EvidenceLedger.readAll(engagementId);
    final toCheck = entries.reversed.take(maxEntriesToCheck).toList();

    int issues = 0;
    for (final e in toCheck) {
      final v = await EvidenceLedger.verifyEntry(e);
      if (!v.exists || !v.hashMatches) issues++;
    }

    final nowIso = DateTime.now().toIso8601String();
    await store.prefs.setString(_key(engagementId), nowIso);

    return IntegrityQuickResult(
      checked: toCheck.length,
      issues: issues,
      checkedAtIso: nowIso,
    );
  }
}