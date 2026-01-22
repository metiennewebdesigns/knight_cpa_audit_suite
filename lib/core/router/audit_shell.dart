import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuditShell extends StatelessWidget {
  const AuditShell({super.key, required this.child});
  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/clients')) return 1;
    if (location.startsWith('/engagements')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  String _locationForIndex(int index) {
    switch (index) {
      case 0:
        return '/';
      case 1:
        return '/clients';
      case 2:
        return '/engagements';
      case 3:
        return '/reports';
      case 4:
        return '/settings';
      default:
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => context.go(_locationForIndex(i)),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Engagements'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}