import 'package:flutter/material.dart';
import 'core/storage/local_store.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Your LocalStore has a static create() (you already confirmed it exists).
  final store = await LocalStore.create();

  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  runApp(App(store: store, themeMode: themeMode));
}