import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knight CPA Audit Suite'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.dark_mode),
            onPressed: () {
              final current = themeMode.value;
              themeMode.value =
                  (current == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _StatCard(label: 'Clients', value: '12', icon: Icons.people),
                _StatCard(label: 'Engagements', value: '5', icon: Icons.work),
                _StatCard(label: 'Workpapers', value: '34', icon: Icons.folder),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Recent Clients',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: const [
                  ListTile(
                    title: Text('The Goddess Collection'),
                    subtitle: Text('Kenner, LA • Updated: 2026-01-21 • Active'),
                    trailing: Text('Open'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text('DSG Luxury Transportation'),
                    subtitle: Text('Dayton, TX • Updated: 2026-01-20 • Active'),
                    trailing: Text('Open'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text('Knight CPA Services'),
                    subtitle: Text('New Orleans, LA • Updated: 2026-01-18 • Onboarding'),
                    trailing: Text('Open'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}