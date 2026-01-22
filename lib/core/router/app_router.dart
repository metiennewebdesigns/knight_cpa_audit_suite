import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../storage/local_store.dart';
import 'audit_shell.dart';

import '../../features/audit_suite/screens/dashboard.dart';
import '../../features/audit_suite/screens/clients.dart';
import '../../features/audit_suite/screens/reports.dart';
import '../../features/audit_suite/screens/checklist.dart';
import '../../features/audit_suite/screens/settings.dart';
import '../../features/audit_suite/screens/engagements_list.dart';
import '../../features/audit_suite/screens/engagement_detail.dart';

class AppRouter {
  static GoRouter build({
    required LocalStore store,
    required ValueNotifier<ThemeMode> themeMode,
  }) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AuditShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => DashboardScreen(
                store: store,
                themeMode: themeMode,
              ),
            ),
            GoRoute(
              path: '/clients',
              builder: (context, state) => ClientsScreen(
                store: store,
                themeMode: themeMode,
              ),
            ),
            GoRoute(
              path: '/engagements',
              builder: (context, state) => EngagementsListScreen(
                store: store,
                themeMode: themeMode,
              ),
            ),
            GoRoute(
              path: '/engagements/:id',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return EngagementDetailScreen(
                  store: store,
                  themeMode: themeMode,
                  engagementId: id,
                );
              },
            ),
            GoRoute(
              path: '/reports',
              builder: (context, state) => ReportsScreen(
                store: store,
                themeMode: themeMode,
              ),
            ),
            GoRoute(
              path: '/checklist',
              builder: (context, state) => ChecklistScreen(
                store: store,
                themeMode: themeMode,
              ),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => SettingsScreen(
                store: store,
                themeMode: themeMode,
              ),
            ),
          ],
        ),
      ],
    );
  }
}