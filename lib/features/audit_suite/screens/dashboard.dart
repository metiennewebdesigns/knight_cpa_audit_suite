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
    // Simple “known good” dashboard so your build never breaks
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          SizedBox(height: 12),
          _KpiRow(),
          SizedBox(height: 18),
          Text('Recent Clients', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          Expanded(child: _RecentList()),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _KpiCard(title: 'Clients', value: '12', icon: Icons.people_alt_rounded),
        _KpiCard(title: 'Engagements', value: '5', icon: Icons.assignment_rounded),
        _KpiCard(title: 'Workpapers', value: '34', icon: Icons.folder_rounded),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView(
        children: const [
          ListTile(
            title: Text('The Goddess Collection'),
            subtitle: Text('Kenner, LA • Active'),
            trailing: Text('Open'),
          ),
          Divider(height: 1),
          ListTile(
            title: Text('DSG Luxury Transportation'),
            subtitle: Text('Dayton, TX • Active'),
            trailing: Text('Open'),
          ),
          Divider(height: 1),
          ListTile(
            title: Text('Knight CPA Services'),
            subtitle: Text('New Orleans, LA • Onboarding'),
            trailing: Text('Open'),
          ),
        ],
      ),
    );
  }
}