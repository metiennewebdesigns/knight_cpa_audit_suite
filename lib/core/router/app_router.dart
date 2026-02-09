import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../storage/local_store.dart';
import 'audit_shell.dart';

// Screens
import '../../features/audit_suite/screens/splash.dart';
import '../../features/audit_suite/screens/dashboard.dart';
import '../../features/audit_suite/screens/clients.dart';
import '../../features/audit_suite/screens/client_detail.dart';
import '../../features/audit_suite/screens/engagements_list.dart';
import '../../features/audit_suite/screens/engagement_detail.dart';
import '../../features/audit_suite/screens/workpapers_list.dart';
import '../../features/audit_suite/screens/workpaper_detail.dart';
import '../../features/audit_suite/screens/pre_risk_assessment.dart';
import '../../features/audit_suite/screens/audit_planning_summary.dart';
import '../../features/audit_suite/screens/audit_packet.dart';
import '../../features/audit_suite/screens/pbc_list.dart';
import '../../features/audit_suite/screens/settings.dart';

// Letters
import '../../features/audit_suite/screens/letters.dart';
import '../../features/audit_suite/screens/letter_preview.dart';

// ✅ Client Portal
import '../../features/audit_suite/screens/client_portal.dart';

final GlobalKey<NavigatorState> _rootNavKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({
  required LocalStore store,
  required ValueNotifier<ThemeMode> themeMode,
}) {
  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: SplashScreen.route,
    debugLogDiagnostics: true,

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Routing Error')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            'Location: ${state.uri}\n\nError:\n${state.error}',
          ),
        ),
      );
    },

    routes: [
      // Splash (outside shell)
      GoRoute(
        path: SplashScreen.route,
        name: 'splash',
        parentNavigatorKey: _rootNavKey,
        builder: (context, state) => const SplashScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AuditShell(
            store: store,
            themeMode: themeMode,
            navigationShell: navigationShell,
          );
        },
        branches: [
          // TAB 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'dashboard',
                builder: (context, state) => DashboardScreen(
                  store: store,
                  themeMode: themeMode,
                ),
              ),
            ],
          ),

          // TAB 1: Clients
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                name: 'clients',
                builder: (context, state) => ClientsScreen(
                  store: store,
                  themeMode: themeMode,
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'clientDetail',
                    parentNavigatorKey: _rootNavKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ClientDetailScreen(
                        store: store,
                        themeMode: themeMode,
                        clientId: id,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // TAB 2: Engagements
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/engagements',
                name: 'engagements',
                builder: (context, state) => EngagementsListScreen(
                  store: store,
                  themeMode: themeMode,
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'engagementDetail',
                    parentNavigatorKey: _rootNavKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return EngagementDetailScreen(
                        store: store,
                        themeMode: themeMode,
                        engagementId: id,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'risk',
                        name: 'engagementRisk',
                        parentNavigatorKey: _rootNavKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return PreRiskAssessmentScreen(
                            store: store,
                            themeMode: themeMode,
                            engagementId: id,
                          );
                        },
                      ),
                      GoRoute(
                        path: 'planning',
                        name: 'engagementPlanning',
                        parentNavigatorKey: _rootNavKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return AuditPlanningSummaryScreen(
                            store: store,
                            themeMode: themeMode,
                            engagementId: id,
                          );
                        },
                      ),
                      GoRoute(
                        path: 'packet',
                        name: 'engagementPacket',
                        parentNavigatorKey: _rootNavKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return AuditPacketScreen(
                            store: store,
                            themeMode: themeMode,
                            engagementId: id,
                          );
                        },
                      ),

                      // PBC Builder
                      GoRoute(
                        path: 'letter/pbc',
                        name: 'pbcList',
                        parentNavigatorKey: _rootNavKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return PbcListScreen(
                            store: store,
                            themeMode: themeMode,
                            engagementId: id,
                          );
                        },
                      ),

                      // Letters hub + preview
                      GoRoute(
                        path: 'letters',
                        name: 'lettersHub',
                        parentNavigatorKey: _rootNavKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return LettersScreen(
                            store: store,
                            themeMode: themeMode,
                            engagementId: id,
                          );
                        },
                        routes: [
                          GoRoute(
                            path: ':type',
                            name: 'letterPreview',
                            parentNavigatorKey: _rootNavKey,
                            builder: (context, state) {
                              final id = state.pathParameters['id']!;
                              final type = state.pathParameters['type'] ?? 'engagement';
                              return LetterPreviewScreen(
                                store: store,
                                themeMode: themeMode,
                                engagementId: id,
                                type: type,
                              );
                            },
                          ),
                        ],
                      ),

                      // ✅ Client Portal (with ?pin=)
                      GoRoute(
                        path: 'client-portal',
                        name: 'clientPortal',
                        parentNavigatorKey: _rootNavKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final pin = state.uri.queryParameters['pin'];
                          return ClientPortalScreen(
                            store: store,
                            themeMode: themeMode,
                            engagementId: id,
                            initialPin: pin,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // TAB 3: Workpapers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workpapers',
                name: 'workpapers',
                builder: (context, state) => WorkpapersListScreen(
                  store: store,
                  themeMode: themeMode,
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'workpaperDetail',
                    parentNavigatorKey: _rootNavKey,
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
              ),
            ],
          ),

          // TAB 4: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => SettingsScreen(
                  store: store,
                  themeMode: themeMode,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}