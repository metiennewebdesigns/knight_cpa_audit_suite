import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  final SharedPreferences prefs;

  LocalStore(this.prefs);

  // Example helpers (safe defaults)
  int getInt(String key, {int defaultValue = 0}) {
    return prefs.getInt(key) ?? defaultValue;
  }

  Future<void> setInt(String key, int value) async {
    await prefs.setInt(key, value);
  }

  String getString(String key, {String defaultValue = ''}) {
    return prefs.getString(key) ?? defaultValue;
  }

  Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }
}