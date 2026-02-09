// lib/features/audit_suite/services/preparer_profile_stub.dart
//
// Web implementation: no local filesystem.
// Return defaults and ignore saves.

class PreparerProfile {
  /// Returns safe defaults if not set.
  /// Keys:
  /// name, line2, address1, address2, city, state, postal, country
  static Future<Map<String, String>> read() async {
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
    // no-op on web
  }

  static Future<void> resetToDefault() async {
    // no-op on web
  }
}