import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final store = LocalStore(prefs);

  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  runApp(App(store: store, themeMode: themeMode));
}