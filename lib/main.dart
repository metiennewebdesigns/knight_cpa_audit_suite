import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.create();
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  runApp(
    App(
      store: store,
      themeMode: themeMode,
    ),
  );
}