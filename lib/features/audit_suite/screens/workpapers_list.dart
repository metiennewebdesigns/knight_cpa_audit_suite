import 'package:flutter/material.dart';

import 'workpaper_detail.dart';

class WorkpaperSummary {
  final String id;
  final String title;
  final String area;
  final String status;
  final DateTime updatedAt;

  const WorkpaperSummary({
    required this.id,
    required this.title,
    required this.area,
    required this.status,
    required this.updatedAt,
  });
}

class WorkpapersListScreen extends StatelessWidget {
  const WorkpapersListScreen({
    super.key,
    required this.engagementId,
    required this.engagementName,
  });

  final String engagementId;
  final String engagementName;

  // TEMP demo list (safe + simple)
  List<WorkpaperSummary> _demoWorkpapers() => [
        WorkpaperSummary(
          id: 'wp_planning',
          title: 'Planning Memo',
          area: 'Planning',
          status: 'In Progress',
          updatedAt: DateTime.now().subtract(const Duration(days: 0)),
        ),
        WorkpaperSummary(
          id: 'wp_revenue',
          title: 'Revenue Testing',
          area: 'Revenue',
          status: 'Not Started',
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        WorkpaperSummary(
          id: 'wp_cash',
          title: 'Cash & Bank',
          area: 'Cash',
          status: 'Complete',
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final items = _demoWorkpapers();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Workpapers'),
            const SizedBox(height: 2),
            Text(
              engagementName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final wp = items[i];
          return Card(
            child: ListTile(
              title: Text(wp.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${wp.area} • Updated ${_fmtDate(wp.updatedAt)}'),
              trailing: _StatusChip(status: wp.status),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WorkpaperDetailScreen(
                      engagementId: engagementId,
                      engagementName: engagementName,
                      workpaperId: wp.id,
                      workpaperTitle: wp.title,
                      status: wp.status,
                      area: wp.area,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Complete' => Colors.green,
      'In Progress' => Colors.orange,
      _ => Colors.grey,
    };

    return Chip(
      label: Text(status),
      side: BorderSide(color: color.withOpacity(.35)),
      backgroundColor: color.withOpacity(.10),
    );
  }
}