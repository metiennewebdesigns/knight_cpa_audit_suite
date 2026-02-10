import 'package:flutter/foundation.dart';

import '../services/evidence_ledger.dart';

class IntegrityQuickCheckResult {
  final int totalChecked;
  final int issues;
  final bool isSupported;

  const IntegrityQuickCheckResult({
    required this.totalChecked,
    required this.issues,
    required this.isSupported,
  });

  const IntegrityQuickCheckResult.unsupported()
      : totalChecked = 0,
        issues = 0,
        isSupported = false;

  bool get hasIssues => issues > 0;
}

class IntegrityQuickCheck {
  /// Fast check: verifies last [maxEntriesToCheck] evidence ledger entries.
  /// Web = unsupported (returns isSupported=false)
  static Future<IntegrityQuickCheckResult> run({
    required String engagementId,
    int maxEntriesToCheck = 20,
  }) async {
    if (kIsWeb) return const IntegrityQuickCheckResult.unsupported();

    try {
      final entries = await EvidenceLedger.readAll(engagementId);
      if (entries.isEmpty) {
        return const IntegrityQuickCheckResult(
          totalChecked: 0,
          issues: 0,
          isSupported: true,
        );
      }

      final toCheck = entries.reversed.take(maxEntriesToCheck).toList();
      int issues = 0;

      for (final e in toCheck) {
        final v = await EvidenceLedger.verifyEntry(e);
        if (!v.exists || !v.hashMatches) issues++;
      }

      return IntegrityQuickCheckResult(
        totalChecked: toCheck.length,
        issues: issues,
        isSupported: true,
      );
    } catch (_) {
      // Fail safe: don't break UI
      return const IntegrityQuickCheckResult(
        totalChecked: 0,
        issues: 0,
        isSupported: true,
      );
    }
  }
}