import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../storage/local_store.dart';

import '../../features/audit_suite/screens/audit_shell.dart';
import '../../features/audit_suite/screens/dashboard.dart';
import '../../features/audit_suite/screens/clients.dart';
import '../../features/audit_suite/screens/engagements_list.dart';
import '../../features/audit_suite/screens/engagement_detail.dart';
import '../../features/audit_suite/screens/reports.dart';
import '../../features/audit_suite/screens/checklist.dart';
import '../../features/audit_suite/screens/settings.dart';

class AppRouter {
  static GoRouter build({
    required LocalStore store,
    required ValueNotifier<ThemeMode> themeMode,
  }) {
    return GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return AuditShell(
              store: store,
              themeMode: themeMode,
              location: state.uri.path, // ✅ works in all recent go_router
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => DashboardScreen(
                store: store,
                themeMode: themeMode,
              ),
            ),
            GoRoute(
              path: '/clients',
              builder: (context, state) => ClientsScreen(
                store: store,
              ),
            ),
            GoRoute(
              path: '/engagements',
              builder: (context, state) => EngagementsListScreen(
                store: store,
              ),
            ),
            GoRoute(
              path: '/engagements/:id',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return EngagementDetailScreen(
                  store: store,
                  engagementId: id,
                );
              },
            ),
            GoRoute(
              path: '/reports',
              builder: (context, state) => ReportsScreen(
                store: store,
              ),
            ),
            GoRoute(
              path: '/checklist',
              builder: (context, state) => ChecklistScreen(
                store: store,
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