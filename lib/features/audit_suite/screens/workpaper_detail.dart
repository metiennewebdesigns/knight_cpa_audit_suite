import 'package:flutter/material.dart';

class WorkpaperDetailScreen extends StatelessWidget {
  const WorkpaperDetailScreen({
    super.key,
    required this.engagementId,
    required this.engagementName,
    required this.workpaperId,
    required this.workpaperTitle,
    required this.status,
    required this.area,
  });

  final String engagementId;
  final String engagementName;
  final String workpaperId;
  final String workpaperTitle;
  final String status;
  final String area;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workpaperTitle),
            const SizedBox(height: 2),
            Text(
              engagementName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workpaper Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _kv('Engagement ID', engagementId),
                _kv('Workpaper ID', workpaperId),
                _kv('Area', area),
                _kv('Status', status),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text('Notes (placeholder)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Next step: connect this to Evidence Vault uploads + checklist items.\n'
                  'For now, this is a stable Workpaper Detail page you can open from Engagements.',
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Mark In Progress'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Mark Complete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}