import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../storage/local_store.dart';
import '../../features/audit_suite/screens/audit_shell.dart';

class AppRouter {
  static GoRouter build({
    required LocalStore store,
    required ValueNotifier<ThemeMode> themeMode,
  }) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => AuditShell(
            store: store,
            themeMode: themeMode,
          ),
        ),
      ],
    );
  }
}