import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuditShell extends StatefulWidget {
  const AuditShell({
    super.key,
    required this.child,
    required this.themeMode,
  });

  final Widget child;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<AuditShell> createState() => _AuditShellState();
}

class _AuditShellState extends State<AuditShell> {
  static const _tabs = <_TabItem>[
    _TabItem(label: 'Home', icon: Icons.home_rounded, route: '/'),
    _TabItem(label: 'Clients', icon: Icons.people_alt_rounded, route: '/clients'),
    _TabItem(label: 'Engagements', icon: Icons.assignment_rounded, route: '/engagements'),
    _TabItem(label: 'Reports', icon: Icons.bar_chart_rounded, route: '/reports'),
    _TabItem(label: 'Settings', icon: Icons.settings_rounded, route: '/settings'),
  ];

  int _locationToIndex(String location) {
    // Match by prefix so /engagements/123 stays on Engagements tab.
    for (var i = 0; i < _tabs.length; i++) {
      final r = _tabs[i].route;
      if (location == r || (r != '/' && location.startsWith(r))) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knight CPA Audit Suite'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: ValueListenableBuilder<ThemeMode>(
              valueListenable: widget.themeMode,
              builder: (context, mode, _) {
                return Icon(
                  mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                );
              },
            ),
            onPressed: () {
              final current = widget.themeMode.value;
              widget.themeMode.value =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_tabs[index].route);
        },
        destinations: [
          for (final t in _tabs) NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
}