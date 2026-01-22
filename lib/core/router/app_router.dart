import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../storage/local_store.dart';

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
        // Dashboard NEEDS store + themeMode (based on your errors)
        GoRoute(
          path: '/',
          builder: (context, state) => DashboardScreen(
            store: store,
            themeMode: themeMode,
          ),
        ),

        // These screens are const (NO store param)
        GoRoute(
          path: '/clients',
          builder: (context, state) => const ClientsScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/checklist',
          builder: (context, state) => const ChecklistScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),

        // Engagements (these screens should NOT require store)
        GoRoute(
          path: '/engagements',
          builder: (context, state) => const EngagementsListScreen(),
        ),
        GoRoute(
          path: '/engagements/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return EngagementDetailScreen(engagementId: id);
          },
        ),
      ],
    );
  }
}