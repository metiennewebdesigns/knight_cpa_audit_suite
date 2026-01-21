import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:knight_cpa_audit_suite/core/storage/local_store.dart';

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
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              themeMode.value =
                  themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            Row(
              children: [
                _StatCard(
                  label: 'Clients',
                  value: '12',
                  icon: Icons.people_outline,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Engagements',
                  value: '5',
                  icon: Icons.assignment_outlined,
                  onTap: () => context.go('/engagements'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              label: 'Workpapers',
              value: '34',
              icon: Icons.folder_outlined,
              onTap: () {},
            ),

            const SizedBox(height: 24),
            Text('Recent Clients', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: const [
                  _RecentClientTile(name: 'The Goddess Collection', subtitle: 'Kenner, LA • Active'),
                  _RecentClientTile(name: 'DSG Luxury Transportation', subtitle: 'Dayton, TX • Active'),
                  _RecentClientTile(name: 'Knight CPA Services', subtitle: 'New Orleans, LA • Onboarding'),
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
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelLarge),
                    Text(value, style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentClientTile extends StatelessWidget {
  const _RecentClientTile({
    required this.name,
    required this.subtitle,
  });

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: () {}, child: const Text('Open')),
      ),
    );
  }
}