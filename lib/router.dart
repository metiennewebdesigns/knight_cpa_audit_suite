import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/storage/local_store.dart';

// Screens (match your current folder structure)
import 'features/audit_suite/screens/dashboard.dart';
import 'features/audit_suite/screens/clients.dart';
import 'features/audit_suite/screens/client_detail.dart';
import 'features/audit_suite/screens/engagements_list.dart';
import 'features/audit_suite/screens/engagement_detail.dart';
import 'features/audit_suite/screens/workpaper_detail.dart';
import 'features/audit_suite/screens/pre_risk_assessment.dart';

GoRouter buildRouter({
  required LocalStore store,
  required ValueNotifier<ThemeMode> themeMode,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ---------------- Dashboard ----------------
      GoRoute(
        path: '/',
        builder: (context, state) => DashboardScreen(
          store: store,
          themeMode: themeMode,
        ),
      ),

      // ---------------- Clients ----------------
      GoRoute(
        path: '/clients',
        builder: (context, state) => ClientsScreen(
          store: store,
          themeMode: themeMode,
        ),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientDetailScreen(
            store: store,
            themeMode: themeMode,
            clientId: id,
          );
        },
      ),

      // ---------------- Engagements ----------------
      GoRoute(
        path: '/engagements',
        builder: (context, state) => EngagementsListScreen(
          store: store,
          themeMode: themeMode,
        ),
        routes: [
          // engagement detail: /engagements/:id
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return EngagementDetailScreen(
                store: store,
                themeMode: themeMode,
                engagementId: id,
              );
            },
            routes: [
              // pre-risk assessment: /engagements/:id/risk
              GoRoute(
                path: 'risk',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return PreRiskAssessmentScreen(
                    store: store,
                    themeMode: themeMode,
                    engagementId: id,
                  );
                },
              ),
            ],
          ),
        ],
      ),

      // ---------------- Workpapers ----------------
      GoRoute(
        path: '/workpapers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WorkpaperDetailScreen(
            store: store,
            themeMode: themeMode,
            workpaperId: id,
          );
        },
      ),
    ],

    // Optional: better error page instead of silent crash
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'GoException: no routes for location: ${state.uri}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
  );
}