// lib/features/audit_suite/services/demo_access.dart
//
// Persistent demo gate using LocalStore.prefs (SharedPreferences).
// Works on web + macOS.

import '../../../core/storage/local_store.dart';

const String _kDemoUnlockedKey = 'demo_gate_unlocked_v1';

class DemoAccess {
  DemoAccess._();

  /// Provide at run time:
  /// flutter run -d chrome --dart-define=DEMO_CODE=1234
  static String demoCode() => const String.fromEnvironment('DEMO_CODE');

  static bool isGateEnabled() => demoCode().trim().isNotEmpty;

  static Future<bool> isUnlocked(LocalStore store) async {
    final v = store.prefs.getString(_kDemoUnlockedKey);
    return v == '1';
  }

  static Future<void> unlock(LocalStore store) async {
    await store.prefs.setString(_kDemoUnlockedKey, '1');
  }

  static Future<void> reset(LocalStore store) async {
    await store.prefs.remove(_kDemoUnlockedKey);
  }

  static bool validate(String entered) {
    final expected = demoCode().trim();
    if (expected.isEmpty) return true;
    return entered.trim() == expected;
  }
}