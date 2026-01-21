import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';
import 'dashboard.dart';

class AuditShell extends StatefulWidget {
  const AuditShell({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<AuditShell> createState() => _AuditShellState();
}

class _AuditShellState extends State<AuditShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Each tab is a full screen (Scaffold). The bottom nav stays in THIS shell.
    final tabs = <Widget>[
      DashboardScreen(store: widget.store, themeMode: widget.themeMode),
      _ClientsTab(store: widget.store, themeMode: widget.themeMode),
      _EngagementsTab(store: widget.store, themeMode: widget.themeMode),
      _ReportsTab(store: widget.store, themeMode: widget.themeMode),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Engagements'),
          NavigationDestination(icon: Icon(Icons.description), label: 'Reports'),
        ],
      ),
    );
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab({required this.store, required this.themeMode});

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: const Center(child: Text('Clients tab ✅')),
    );
  }
}

class _EngagementsTab extends StatelessWidget {
  const _EngagementsTab({required this.store, required this.themeMode});

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engagements')),
      body: const Center(child: Text('Engagements tab ✅')),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.store, required this.themeMode});

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(child: Text('Reports tab ✅')),
    );
  }
}