import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

class AuditShell extends StatelessWidget {
  const AuditShell({
    super.key,
    required this.store,
    required this.themeMode,
    required this.location,
    required this.child,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String location;
  final Widget child;

  int _indexForLocation(String loc) {
    if (loc.startsWith('/clients')) return 1;
    if (loc.startsWith('/engagements')) return 2;
    if (loc.startsWith('/reports')) return 3;
    if (loc.startsWith('/settings')) return 4;
    return 0; // dashboard
  }

  void _goForIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
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
      case 4:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => _goForIndex(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Engagements',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}