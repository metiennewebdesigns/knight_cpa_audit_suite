// lib/features/audit_suite/services/client_meta_stub.dart
//
// Web implementation: no local filesystem.
// We return defaults and no-op saves.

class ClientMeta {
  static Future<Map<String, String>> readAddress(String clientId) async {
    return const {
      'address1': '',
      'address2': '',
      'city': '',
      'state': '',
      'postal': '',
      'country': '',
    };
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
    // no-op on web
  }

  static Future<void> resetAddress(String clientId) async {
    // no-op on web
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