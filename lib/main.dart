import 'package:flutter/material.dart';

import 'core/storage/local_store.dart';
import 'app_router.dart'; // provides buildRouter(...)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.init();
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  runApp(AuditronApp(store: store, themeMode: themeMode));
}

class AuditronApp extends StatefulWidget {
  const AuditronApp({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<AuditronApp> createState() => _AuditronAppState();
}

class _AuditronAppState extends State<AuditronApp> {
  late final router = buildRouter(store: widget.store, themeMode: widget.themeMode);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeMode,
      builder: (context, mode, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          routerConfig: router, // ✅ SAME router instance (no reset on theme switch)
        );
      },
    );
  }
}