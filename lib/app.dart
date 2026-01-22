import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/storage/local_store.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.build(store: store, themeMode: themeMode);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          routerConfig: router,
        );
      },
    );
  }
}