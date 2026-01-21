import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../storage/local_store.dart';

// Existing screens (you already have these)
import '../../features/audit_suite/screens/dashboard.dart';
import '../../features/audit_suite/screens/clients.dart';
import '../../features/audit_suite/screens/reports.dart';

// We will overwrite these two files below so they match the router
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
          path: '/reports',
          builder: (context, state) => ReportsScreen(
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
              id: id,
              store: store,
              themeMode: themeMode,
            );
          },
        ),
      ],
    );
  }
}