import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../storage/local_store.dart';

class AuditShell extends StatelessWidget {
  const AuditShell({
    super.key,
    required this.store,
    required this.themeMode,
    required this.child,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final Widget child;

  int _selectedIndexForLocation(String location) {
    if (location.startsWith('/clients')) return 1;
    if (location.startsWith('/engagements')) return 2;
    if (location.startsWith('/reports')) return 3;
    return 0; // dashboard
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _selectedIndexForLocation(location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Column(
                children: [
                  const Icon(Icons.verified_user, size: 28),
                  const SizedBox(height: 8),
                  const Text(
                    'Knight CPA',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeMode,
                    builder: (context, mode, _) {
                      return IconButton(
                        tooltip: 'Toggle theme',
                        icon: Icon(
                          mode == ThemeMode.dark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                        ),
                        onPressed: () {
                          themeMode.value = mode == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Clients'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: Text('Engagements'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Reports'),
              ),
            ],
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/clients');
                  break;
                case 2:
                  context.go('/engagements');
                  break;
                case 3:
                  context.go('/reports');
                  break;
              }
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}