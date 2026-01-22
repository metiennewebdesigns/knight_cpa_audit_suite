import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore(this.prefs);

  final SharedPreferences prefs;

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }
}