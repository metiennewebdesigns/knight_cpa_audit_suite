import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

class AuditShell extends StatelessWidget {
  const AuditShell({
    super.key,
    required this.store,
    required this.themeMode,
    required this.shell,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final StatefulNavigationShell shell;

  void _toggleTheme() {
    final current = themeMode.value;
    themeMode.value = (current == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knight CPA Audit Suite'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: _toggleTheme,
            icon: const Icon(Icons.dark_mode),
          ),
        ],
      ),
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.work), label: 'Engagements'),
          NavigationDestination(icon: Icon(Icons.description), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Checklist'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}