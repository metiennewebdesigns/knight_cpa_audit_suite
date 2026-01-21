import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/storage/local_store.dart';

class App extends StatefulWidget {
  const App({super.key, required this.store});

  final LocalStore store;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final ValueNotifier<ThemeMode> _themeMode;
  late final router = AppRouter.build(
    store: widget.store,
    themeMode: _themeMode,
  );

  @override
  void initState() {
    super.initState();
    _themeMode = ValueNotifier(ThemeMode.light);
  }

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Knight CPA Audit Suite',
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: mode,
          routerConfig: router,
        );
      },
    );
  }
}